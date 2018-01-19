CREATE OR REPLACE PACKAGE BODY DEV_TIMUR.APIGrabber is
    /*
        package gets data from the sources and parse into our tables

        working tables:
        concepts_ext_raw - raw XML values
        current_concepts - our current 11-digit NDC concepts from devv5
        concepts_ext_errors - table for errors
        chunks_errors - table for DBMS_PARALLEL_EXECUTE errors
        
        target and tmp tables:
        ndc_history - target table with parsed NDC-data (job GetAllNDC)
        ndc_history_tmp - tmp table with parsed NDC-data (job GetAllNDC)
        
        rxnorm2ndc_mappings - target table with parsed mappings from RxNorm to NDC (job RxNorm2NDC_Mappings)
        rxnorm2ndc_mappings_tmp - tmp table with parsed mappings from RxNorm to NDC (job RxNorm2NDC_Mappings)
        
        rxnorm2spl_mappings target table with parsed mappings from RxNorm to SPL (job RxNorm2SPL_Mappings)
        rxnorm2spl_mappings_tmp - tmp table with parsed mappings from RxNorm to SPL (job RxNorm2SPL_Mappings)
        
        ------------------HOWTO------------------
        1. Create ACL
        BEGIN
          DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(acl         => 'APIGRABBER',
                                            description => 'API GRABBER',
                                            principal   => USER,
                                            is_grant    => true,
                                            privilege   => 'connect');
         
          DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl       => 'APIGRABBER',
                                               principal => USER,
                                               is_grant  => true,
                                               privilege => 'resolve');
         
          DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(acl  => 'APIGRABBER',
                                            host => '*'); --any host
        COMMIT;
        END;  
        
        2. Create tables
        CREATE TABLE CONCEPTS_EXT_RAW
        (
          CONCEPT_CODE  VARCHAR2(255 BYTE),
          CONCEPT_XML   XMLTYPE
        ) NOLOGGING;
        
        CREATE TABLE CURRENT_CONCEPTS
        (
          CONCEPT_CODE  VARCHAR2(50 BYTE)               NOT NULL
        ) NOLOGGING;
        
        EXECUTE DBMS_ERRLOG.CREATE_ERROR_LOG('CONCEPTS_EXT_RAW', 'CONCEPTS_EXT_ERRORS', SKIP_UNSUPPORTED=>TRUE);

        CREATE TABLE CHUNKS_ERRORS
        (
          CHUNK_ID       NUMBER                         NOT NULL,
          TASK_NAME      VARCHAR2(128 BYTE)             NOT NULL,
          STATUS         VARCHAR2(20 BYTE),
          START_ROWID    ROWID,
          END_ROWID      ROWID,
          START_ID       NUMBER,
          END_ID         NUMBER,
          JOB_NAME       VARCHAR2(128 BYTE),
          START_TS       TIMESTAMP(6),
          END_TS         TIMESTAMP(6),
          ERROR_CODE     NUMBER,
          ERROR_MESSAGE  VARCHAR2(4000 BYTE)
        ) NOLOGGING;
        
        3. Give grant yourself 
        GRANT CREATE JOB TO xxx;
        
        4. Change value of gMailTo to your@email
        
        5. Change params in SendMailHTML (mail_from, wallet_path, smtp, login and password)
        
        6. Create JOB with apigrabber.StartGrabber, for example:
            BEGIN
              begin
                SYS.DBMS_JOB.CHANGE
                  (
                    job        => 83
                   ,what       => 'APIGRABBER.STARTGRABBER;'
                   ,next_date  => TRUNC(SYSDATE+1)
                   ,interval   => 'TRUNC(SYSDATE+1)'
                );
              exception
                when others then
                begin
                  raise;
                end;
              end;
            END;
    */
    gRawTable constant varchar2(100):='concepts_ext_raw';
    gConceptTable constant varchar2(100):='current_concepts';
    gLogTable constant varchar2(100):='concepts_ext_errors';
    gChunkErrTable constant varchar2(100):='chunks_errors';
    crlf varchar2(2) := utl_tcp.crlf;
    gCurrentSchema constant varchar2(50):= sys_context ('userenv', 'CURRENT_SCHEMA');
    gExecCounter number:=0;
    gMailTo constant varchar2(50):= 'timur.vakhitov@firstlinesoftware.com';
    
    procedure SendMailHTML (subject in varchar2, txt_email in varchar2) is
    /*
        procedure sends e-mail, including HTML-version
    */
    mail_from varchar2(30):= 'oraclemailnotify@gmail.com';
    c utl_smtp.connection;
    subj raw(2000) := utl_raw.cast_to_raw(convert('Subject: '||subject,'UTF8')||crlf);
    bod raw(32000) := utl_raw.cast_to_raw(convert(replace(txt_email,crlf,'<br>'),'UTF8')||crlf);
    begin
        utl_tcp.close_all_connections;
        c := utl_smtp.open_connection(
            host => 'smtp.gmail.com',
            port => 587,
            wallet_path => 'file:/home/oracle/wallet',
            wallet_password => 'wallet_password',
            secure_connection_before_smtp => FALSE);        
        utl_smtp.ehlo(c,'smtp.gmail.com');
        utl_smtp.starttls(c);
        utl_smtp.command(c, 'AUTH LOGIN');
        utl_smtp.command(c, 'b3JhY2xlbWFpbG5vdGlmeUBnbWFpbC5jb20=');
        utl_smtp.command(c, 'b3JhY2xlbWFpbG5vdGlmeTEyM29yYWNsZW1haWxub3RpZnk=');
        --utl_smtp.auth(c,mail_from,'passwd', utl_smtp.all_schemes);     
        utl_smtp.mail(c,mail_from);
        utl_smtp.rcpt(c,gMailTo);
        utl_smtp.open_data(c);
        utl_smtp.write_data(c,'From: MailNotifier <'||mail_from||'>'||crlf);
        utl_smtp.write_data(c,'To: '||gMailTo||crlf);
        utl_smtp.write_raw_data(c,subj);   
        utl_smtp.write_data(c, 'Content-Type: text/html; charset=UTF-8'||crlf||crlf);
        utl_smtp.write_raw_data(c,bod);
        utl_smtp.close_data(c);
        utl_smtp.quit(c);
        exception when others then 
            utl_smtp.quit(c);          
            raise;
    end;
    
    function fhttpuritype(url in varchar2) return xmltype is
    /*
        DBMS_PARALLEL_EXECUTE creates another sessions, so can't see our UTL_HTTP.set_wallet
        this is workaround
    */
    begin
        UTL_HTTP.set_wallet ('file:/home/oracle/wallet', 'wallet_password');
        return HTTPURITYPE(url).getXML();
    end;
    procedure RunTask (pTaskName in varchar2, pSQLsrc in varchar2, pSQLurl in varchar2, pResumeTask in boolean default false) is
    /*
        procedure gets aggregated data using HTTPURITYPE and DBMS_PARALLEL_EXECUTE
    */
    l_ParallelLevel number:=10;
    l_SQL_stmt varchar2(2000);
    z number; 
    
    begin
    
        if not pResumeTask then
            execute immediate 'truncate table '||gRawTable;
        end if;
        execute immediate 'truncate table '||gConceptTable;
        execute immediate 'truncate table '||gLogTable;
        execute immediate 'truncate table '||gChunkErrTable;
        execute immediate 'insert /*+ APPEND */ into '||gConceptTable||' '||pSQLsrc;
        commit;
         
        DBMS_PARALLEL_EXECUTE.CREATE_TASK (pTaskName); --create the task
        DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(pTaskName, USER, upper(gConceptTable), by_row => true, chunk_size => 100); --split the gConceptTable by ROWID
                
        l_SQL_stmt:='
            INSERT INTO '||gRawTable||'
            SELECT CONCEPT_CODE, '||pSQLurl||' FROM '||gConceptTable||' WHERE ROWID BETWEEN :start_id AND :end_id
            LOG ERRORS INTO '||gLogTable||' REJECT LIMIT UNLIMITED
        ';
        DBMS_PARALLEL_EXECUTE.RUN_TASK(pTaskName, l_SQL_stmt, DBMS_SQL.NATIVE, parallel_level => l_ParallelLevel); -- execute the DML in parallel
        
        -- done with processing; drop the task
        if DBMS_PARALLEL_EXECUTE.TASK_STATUS(pTaskName)<>DBMS_PARALLEL_EXECUTE.FINISHED then
            execute immediate 'INSERT /*+ APPEND */ INTO '||gChunkErrTable||' SELECT * FROM SYS.user_parallel_execute_chunks t WHERE t.TASK_NAME=:1' using pTaskName;
            commit;
        end if;
        DBMS_PARALLEL_EXECUTE.DROP_TASK(pTaskName);
        
        exception when others then
            select count(*) into z from sys.user_parallel_execute_tasks t where t.task_name=pTaskName;
            if z>0 then
                DBMS_PARALLEL_EXECUTE.DROP_TASK(pTaskName); --if exists then drop task
            end if;
            raise;     
    end;
    
    function GetTaskStatus (pTaskName in varchar2) return number is
    l_chunk_errors number;
    l_sql_errors number;
    l_mail_subj varchar2(100);
    l_mail_body varchar2(1000);
    l_txt_errors varchar2(4000);
    begin
        --execute immediate 'select count(distinct error_message) from '||gChunkErrTable||' where status = ''PROCESSED_WITH_ERROR''' into l_chunk_errors;
        execute immediate 'select count(error_message), listagg(error_message, '''||crlf||''') within group (order by error_message) 
            from (select distinct error_message from '||gChunkErrTable||' where status = ''PROCESSED_WITH_ERROR'')' into l_chunk_errors, l_txt_errors;
        execute immediate 'select count(*) from '||gLogTable into l_sql_errors;
        
        if l_chunk_errors>0 or l_sql_errors>0 then
            l_mail_subj:='JOB "'||pTaskName||'" was finished with errors';
            l_mail_body:='Number of chunk errors: ';
            if l_chunk_errors=0 then 
                l_mail_body:=l_mail_body||l_chunk_errors; 
            else 
                l_mail_body:=l_mail_body||'<b>'||l_chunk_errors||'</b>, see SELECT * FROM '||gCurrentSchema||'.'||gChunkErrTable;
                l_mail_body:=l_mail_body||crlf||l_txt_errors||crlf; 
            end if;
            l_mail_body:=l_mail_body||crlf||'Number of SQL errors: ';
            if l_sql_errors=0 then 
                l_mail_body:=l_mail_body||l_sql_errors; 
            else 
                l_mail_body:=l_mail_body||'<b>'||l_sql_errors||'</b>, see SELECT * FROM '||gCurrentSchema||'.'||gLogTable; 
            end if;
            
            SendMailHTML(l_mail_subj,l_mail_body);
        end if;
        
        return l_chunk_errors+l_sql_errors;
    end;
    
    procedure GetAllNDC (pResumeTask in boolean default false) is
    /*
        gets all NDC statuses from https://rxnav.nlm.nih.gov/REST/ndcstatus?history=1&ndc=xxx
    */
    l_mail_subj varchar2(100);
    l_mail_body varchar2(1000);
    l_error varchar2(1000);
    l_taskname constant varchar2(100):='GetAllNDC';
    l_cnt_old number;
    l_cnt_now number;
    l_SQLsrc varchar2(4000);
    begin
        l_SQLsrc:=
            q'[select c.concept_code from devv5.concept c where c.vocabulary_id='NDC' and c.concept_class_id='11-digit NDC'
                union 
                select rm.ndc_code from rxnorm2ndc_mappings rm
                union
                select sm.ndc_code from devv5.spl2ndc_mappings sm
            ]';
        if pResumeTask then
            l_SQLsrc:='select concept_code from ('||l_SQLsrc||') minus select concept_code from '||gRawTable;
        end if;
        l_mail_subj:='JOB "'||l_taskname||'" was started';
        if gExecCounter<>0 then
            l_mail_subj:=l_mail_subj||' [iteration='||(gExecCounter+1)||']';
        end if;        
        l_mail_body:='Time: '||to_char(sysdate,'YYYYMMDD HH24:MI:SS');
        SendMailHTML(l_mail_subj,l_mail_body);    
        RunTask (
            pTaskName => l_taskname,
            pSQLsrc   => l_SQLsrc,          
            pSQLurl     => q'[APIGrabber.fhttpuritype('https://rxnav.nlm.nih.gov/REST/ndcstatus?history=1&ndc='||concept_code)]',
            pResumeTask => pResumeTask
        );
        commit;
        
        if GetTaskStatus(l_taskname)=0 then
            --parse XML
            gExecCounter:=0;
            execute immediate 'truncate table ndc_history_tmp';
            execute immediate 'insert /*+ APPEND */ into ndc_history_tmp 
            select c.concept_code,
                extractvalue (c.concept_xml, ''rxnormdata/ndcStatus/status'') status,
                extractvalue (value (t), ''ndcHistory/activeRxcui'') activeRxcui,
                to_date(extractvalue (value (t), ''ndcHistory/startDate''),''YYYYMM'') startDate,
                to_date(extractvalue (value (t), ''ndcHistory/endDate''),''YYYYMM'') endDate
            from '||gRawTable||' c, 
                table (xmlsequence(c.concept_xml.extract (''rxnormdata/ndcStatus/ndcHistory'')))(+) t
                ';       
            commit;
            --if no errors occured while parsing - replace the target data
            select count(*) into l_cnt_old from ndc_history;
            execute immediate 'truncate table ndc_history';
            insert /*+ APPEND */ into ndc_history select * from ndc_history_tmp;
            l_cnt_now:=sql%rowcount;
            execute immediate 'truncate table ndc_history_tmp';
                           
            l_mail_subj:='JOB "'||l_taskname||'" was finished successfully';
            l_mail_body:='Parsed concepts: <b>'||l_cnt_old||' -> '||l_cnt_now||'</b>';
            l_mail_body:=l_mail_body||crlf||'Time: '||to_char(sysdate,'YYYYMMDD HH24:MI:SS');
            SendMailHTML(l_mail_subj,l_mail_body);
        else
            --resume task
            if gExecCounter < 5 then
                gExecCounter:=gExecCounter+1;
                GetAllNDC (pResumeTask=>true);
            else
                gExecCounter:=0;
            end if;        
        end if;
        
        exception when others then
            l_error:=substr(sqlerrm,1,1000);
            rollback;
            l_mail_subj:='JOB "'||l_taskname||'" was NOT finished';
            l_mail_body:='Error: <b>'||crlf||l_error||'</b>';
            SendMailHTML(l_mail_subj,l_mail_body);
            --raise;
    end;
    
    procedure GetRxNorm2NDC_Mappings (pResumeTask in boolean default false) is
    /*
        gets all RxNorm to NDC mappings from https://rxnav.nlm.nih.gov/REST/rxcui/xxx/allndcs?history=1
    */
    l_mail_subj varchar2(100);
    l_mail_body varchar2(1000);
    l_error varchar2(1000);
    l_taskname constant varchar2(100):='RxNorm2NDC_Mappings';
    l_cnt_old number;
    l_cnt_now number;
    l_SQLsrc varchar2(4000);
    begin
        l_SQLsrc:= q'[select c.concept_code from devv5.concept c where c.vocabulary_id='RxNorm']';
        if pResumeTask then
            l_SQLsrc:='select concept_code from ('||l_SQLsrc||') minus select concept_code from '||gRawTable;
        end if;
        l_mail_subj:='JOB "'||l_taskname||'" was started';
        if gExecCounter<>0 then
            l_mail_subj:=l_mail_subj||' [iteration='||(gExecCounter+1)||']';
        end if;
        l_mail_body:='Time: '||to_char(sysdate,'YYYYMMDD HH24:MI:SS');
        SendMailHTML(l_mail_subj,l_mail_body);    
        RunTask (
            pTaskName   => l_taskname,
            pSQLsrc     => l_SQLsrc,
            pSQLurl     => q'[APIGrabber.fhttpuritype('https://rxnav.nlm.nih.gov/REST/rxcui/'||concept_code||'/allndcs?history=1')]',
            pResumeTask => pResumeTask
        );
        commit;
        
        if GetTaskStatus(l_taskname)=0 then
            --parse XML
            gExecCounter:=0;
            execute immediate 'truncate table rxnorm2ndc_mappings_tmp';
            execute immediate 'insert /*+ APPEND */ into rxnorm2ndc_mappings_tmp 
            select r.concept_code,
                extractvalue (value (t), ''ndcTime/ndc'') ndc_code,
                to_date(extractvalue (value (t), ''ndcTime/startDate''),''YYYYMM'') startDate,
                to_date(extractvalue (value (t), ''ndcTime/endDate''),''YYYYMM'') endDate
            from '||gRawTable||' r, 
                table (xmlsequence (r.concept_xml.extract (''rxnormdata/ndcConcept/ndcTime''))) t
            ';       
            commit;
            --if no errors occured while parsing - replace the target data
            select count(*) into l_cnt_old from rxnorm2ndc_mappings;
            execute immediate 'truncate table rxnorm2ndc_mappings';
            insert /*+ APPEND */ into rxnorm2ndc_mappings select * from rxnorm2ndc_mappings_tmp;
            l_cnt_now:=sql%rowcount;
            execute immediate 'truncate table rxnorm2ndc_mappings_tmp';
                           
            l_mail_subj:='JOB "'||l_taskname||'" was finished successfully';
            l_mail_body:='Parsed mappings: <b>'||l_cnt_old||' -> '||l_cnt_now||'</b>';
            l_mail_body:=l_mail_body||crlf||'Time: '||to_char(sysdate,'YYYYMMDD HH24:MI:SS');
            SendMailHTML(l_mail_subj,l_mail_body);
        else
            --resume task
            if gExecCounter < 5 then
                gExecCounter:=gExecCounter+1;
                GetRxNorm2NDC_Mappings (pResumeTask=>true);
            else
                gExecCounter:=0;
            end if;        
        end if;
        
        exception when others then
            l_error:=substr(sqlerrm,1,1000);
            rollback;
            l_mail_subj:='JOB "'||l_taskname||'" was NOT finished';
            l_mail_body:='Error: <b>'||crlf||l_error||'</b>';
            SendMailHTML(l_mail_subj,l_mail_body);
            --raise;
    end;    
    
    procedure GetRxNorm2SPL_Mappings (pResumeTask in boolean default false) is
    /*
        gets all RxNorm to NDC mappings from https://rxnav.nlm.nih.gov/REST/rxcui/xxx/property?propName=SPL_SET_ID
    */
    l_mail_subj varchar2(100);
    l_mail_body varchar2(1000);
    l_error varchar2(1000);
    l_taskname constant varchar2(100):='RxNorm2SPL_Mappings';
    l_cnt_old number;
    l_cnt_now number;
    l_SQLsrc varchar2(4000);
    begin
        l_SQLsrc:= q'[select c.concept_code from devv5.concept c where c.vocabulary_id='RxNorm']';
        if pResumeTask then
            l_SQLsrc:='select concept_code from ('||l_SQLsrc||') minus select concept_code from '||gRawTable;
        end if;        
        l_mail_subj:='JOB "'||l_taskname||'" was started';
        if gExecCounter<>0 then
            l_mail_subj:=l_mail_subj||' [iteration='||(gExecCounter+1)||']';
        end if;        
        l_mail_body:='Time: '||to_char(sysdate,'YYYYMMDD HH24:MI:SS');
        SendMailHTML(l_mail_subj,l_mail_body);    
        RunTask (
            pTaskName   => l_taskname,
            pSQLsrc     => l_SQLsrc,
            pSQLurl     => q'[APIGrabber.fhttpuritype('https://rxnav.nlm.nih.gov/REST/rxcui/'||concept_code||'/property?propName=SPL_SET_ID')]',
            pResumeTask => pResumeTask
        );
        commit;
        
        if GetTaskStatus(l_taskname)=0 then
            --parse XML
            gExecCounter:=0;
            execute immediate 'truncate table rxnorm2spl_mappings_tmp';
            execute immediate 'insert /*+ APPEND */ into rxnorm2spl_mappings_tmp 
            select r.concept_code,
                   extractvalue (value (t), ''propConcept/propValue'') spl_code
              from '||gRawTable||' r,
                   table (xmlsequence (r.concept_xml.extract (''rxnormdata/propConceptGroup/propConcept''))) t           
            ';       
            commit;
            --if no errors occured while parsing - replace the target data
            select count(*) into l_cnt_old from rxnorm2spl_mappings;
            execute immediate 'truncate table rxnorm2spl_mappings';
            insert /*+ APPEND */ into rxnorm2spl_mappings select * from rxnorm2spl_mappings_tmp;
            l_cnt_now:=sql%rowcount;
            execute immediate 'truncate table rxnorm2spl_mappings_tmp';
                           
            l_mail_subj:='JOB "'||l_taskname||'" was finished successfully';
            l_mail_body:='Parsed mappings: <b>'||l_cnt_old||' -> '||l_cnt_now||'</b>';
            l_mail_body:=l_mail_body||crlf||'Time: '||to_char(sysdate,'YYYYMMDD HH24:MI:SS');
            SendMailHTML(l_mail_subj,l_mail_body);
        else
            --resume task
            if gExecCounter < 5 then
                gExecCounter:=gExecCounter+1;
                GetRxNorm2SPL_Mappings (pResumeTask=>true);
            else
                gExecCounter:=0;
            end if;        
        end if;
        
        exception when others then
            l_error:=substr(sqlerrm,1,1000);
            rollback;
            l_mail_subj:='JOB "'||l_taskname||'" was NOT finished';
            l_mail_body:='Error: <b>'||crlf||l_error||'</b>';
            SendMailHTML(l_mail_subj,l_mail_body);
            --raise;
    end;        
    procedure StartGrabber is
    iCurrDay number;
    begin
        iCurrDay:= extract (DAY from sysdate);
        if iCurrDay=1 then
            GetRxNorm2NDC_Mappings; --NDC mappings must be before GetAllNDC call
        elsif iCurrDay=2 then
            GetRxNorm2SPL_Mappings;
        elsif iCurrDay=3 then
            GetAllNDC;            
        end if;
        commit;
    end;    
end;
/
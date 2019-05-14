CREATE OR REPLACE FUNCTION vocabulary_download.UpdateAllVocabularies () 
RETURNS void AS
$body$
declare
  cModuleName constant text:='AUTOMATION';
  cVocab devv5.vocabulary_access%rowtype;
  cVocabA devv5.vocabulary_access%rowtype;
  cRet text;
  cRet2 text;
  cOldDate date;
  cNewDate date;
  cSrcDate date;
  cOldVersion varchar(100);
  cNewVersion varchar(100);
  cSrcVersion varchar(100);
  cSessionID int4;
  cLastStatusID int;
  cResult text;
  cFastRecreateScript text;
  cLoadStageURL text;
  cMoveToDevv5 text;
  cLoadStageScript text;
  cScriptFailed boolean;
  cScriptErrorText text;
  pSession int4;
  cMailText text;
  crlf constant varchar(4):='<br>';
  crlfSQL constant varchar(4):=E'\r\n';
  cEmail varchar(1000);
  cHTML_OK constant varchar(100):='<font color=''green''>&#10004;</font> ';
  cHTML_ERROR constant varchar(100):='<font color=''red''>&#10008;</font> ';
  cHTML_WAITING constant varchar(100):='<font color=''e6e600''>&#9650;</font> ';
begin
  select nextval('vocabulary_download.log_seq') into pSession;
  perform vocabulary_download.write_log (
    iVocabularyID=>cModuleName,
    iSessionID=>pSession,
    iVocabulary_operation=>cModuleName||' started',
    iVocabulary_status=>0
  );
  if not pg_try_advisory_xact_lock(hashtext(cModuleName)) then raise exception 'Automation already started'; end if;
  select c.var_value into cEmail from devv5.config$ c where c.var_name='vocabulary_download_email';
  
  for cVocab in (
    select * from devv5.vocabulary_access vc where vc.vocabulary_order=1 and vc.vocabulary_update_after is null and vc.vocabulary_enabled=1
    order by case vc.vocabulary_id when 'UMLS' then 1 when 'SNOMED' then 2 when 'RXNORM' then 3 else 4 end, vc.vocabulary_id
  ) loop
    begin
      select old_date, new_date, old_version, new_version, src_date, src_version 
      into cOldDate, cNewDate, cOldVersion, cNewVersion, cSrcDate, cSrcVersion
      from vocabulary_pack.CheckVocabularyUpdate (cVocab.vocabulary_id);
      cScriptFailed:=false;
      cScriptErrorText:=null;
      
      if coalesce(cSrcDate::varchar,cSrcVersion)<>coalesce(cNewDate::varchar,cNewVersion) then
        --update vocabulary in source-schema
        execute 'select session_id, last_status, result_output from vocabulary_download.get_'||replace(cVocab.vocabulary_id,' ','_')||'()' into cSessionID, cLastStatusID, cResult;
        if cLastStatusID=3 then --the downloading/parsing was successfull
          if cVocab.vocabulary_dev_schema is not null then
            --set dev-schema
            execute 'set local session authorization '||cVocab.vocabulary_dev_schema;
            --parsing the params (json)
            cFastRecreateScript:=cVocab.vocabulary_params->>'fast_recreate_script';
            cLoadStageURL:=cVocab.vocabulary_params->>'load_stage_path';
            cMoveToDevv5:=cVocab.vocabulary_params->>'move_to_devv5';
            
            if cFastRecreateScript is not null then
              begin --use another begin/end block because we don't want to rollback previous changes (fast recreate)
                cFastRecreateScript:='do $AutomationSctipt$ begin perform '||crlfSQL||cFastRecreateScript||crlfSQL||'; end $AutomationSctipt$';
                reset search_path;
                execute cFastRecreateScript;
                perform vocabulary_download.write_log (
                  iVocabularyID=>cModuleName,
                  iSessionID=>pSession,
                  iVocabulary_operation=>'fast_recreate for '||cVocab.vocabulary_dev_schema||' finished',
                  iVocabulary_status=>1
                );
              EXCEPTION WHEN OTHERS THEN
                get stacked diagnostics cRet = pg_exception_context;
                cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                cScriptFailed:=true; --the 'Failed' marker
                cScriptErrorText:='fast_recreate failed: '||SQLERRM;
                perform vocabulary_download.write_log (
                  iVocabularyID=>cModuleName,
                  iSessionID=>pSession,
                  iVocabulary_operation=>'fast_recreate for '||cVocab.vocabulary_dev_schema||' failed',
                  iVocabulary_error=>cRet,
                  iVocabulary_status=>2
                );
              end;
            end if;
            
            --run load_stage
            if cLoadStageURL is not null then 
              if not cScriptFailed then
                begin --use another begin/end block because we don't want to rollback previous changes (fast recreate)
                  select http_content into cLoadStageScript from vocabulary_download.py_http_get(url=>cLoadStageURL,allow_redirects=>true);
                  cLoadStageScript:='do $AutomationSctipt$ begin '||crlfSQL||cLoadStageScript||crlfSQL||' end $AutomationSctipt$';
                  reset search_path;
                  execute cLoadStageScript;
                  perform vocabulary_download.write_log (
                    iVocabularyID=>cModuleName,
                    iSessionID=>pSession,
                    iVocabulary_operation=>'load_stage for '||cVocab.vocabulary_dev_schema||' finished',
                    iVocabulary_status=>1
                  );
                EXCEPTION WHEN OTHERS THEN
                  get stacked diagnostics cRet = pg_exception_context;
                  cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                  cScriptFailed:=true; --the 'Failed' marker
                  cScriptErrorText:='load_stage failed: '||SQLERRM;
                  perform vocabulary_download.write_log (
                    iVocabularyID=>cModuleName,
                    iSessionID=>pSession,
                    iVocabulary_operation=>'load_stage for '||cVocab.vocabulary_dev_schema||' failed',
                    iVocabulary_error=>cRet,
                    iVocabulary_status=>2
                  );
                end;
              end if;
              
              --run generic_update after load_stage
              if not cScriptFailed then
                begin
                  reset search_path;
                  perform devv5.GenericUpdate();
                  perform vocabulary_download.write_log (
                    iVocabularyID=>cModuleName,
                    iSessionID=>pSession,
                    iVocabulary_operation=>'generic_update for '||cVocab.vocabulary_dev_schema||' finished',
                    iVocabulary_status=>1
                  );
                EXCEPTION WHEN OTHERS THEN
                  get stacked diagnostics cRet = pg_exception_context;
                  cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                  cScriptFailed:=true; --the 'Failed' marker
                  cScriptErrorText:='generic_update failed: '||SQLERRM;
                  perform vocabulary_download.write_log (
                    iVocabularyID=>cModuleName,
                    iSessionID=>pSession,
                    iVocabulary_operation=>'generic_update for '||cVocab.vocabulary_dev_schema||' failed',
                    iVocabulary_error=>cRet,
                    iVocabulary_status=>2
                  );
                end;
              end if;
              
              --move to devv5
              if not cScriptFailed and cMoveToDevv5='1' then
                begin
                  reset session authorization;
                  reset search_path;
                  execute cLoadStageScript;
                  perform devv5.GenericUpdate();
                  perform vocabulary_download.write_log (
                    iVocabularyID=>cModuleName,
                    iSessionID=>pSession,
                    iVocabulary_operation=>'moving to devv5 for '||cVocab.vocabulary_dev_schema||' finished',
                    iVocabulary_status=>1
                  );
                EXCEPTION WHEN OTHERS THEN
                  get stacked diagnostics cRet = pg_exception_context;
                  cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                  cScriptFailed:=true; --the 'Failed' marker
                  cScriptErrorText:='moving to devv5 failed: '||SQLERRM;
                  perform vocabulary_download.write_log (
                    iVocabularyID=>cModuleName,
                    iSessionID=>pSession,
                    iVocabulary_operation=>'moving to devv5 for '||cVocab.vocabulary_dev_schema||' failed',
                    iVocabulary_error=>cRet,
                    iVocabulary_status=>2
                  );
                end;
              end if;
            end if;
          end if;
          reset session authorization;
          reset search_path;
          
          --store result
          cRet:=coalesce(to_char(cSrcDate,'yyyymmdd'),cSrcVersion)||' -> '||coalesce(to_char(cNewDate,'yyyymmdd'),cNewVersion);
          if not cScriptFailed then
            if cMoveToDevv5='1' then
              cRet:=cHTML_OK||'<b>'||cVocab.vocabulary_id||'</b> was updated! ['||cRet||'] [devv5]';
            else
              cRet:=cHTML_OK||'<b>'||cVocab.vocabulary_id||'</b> was updated! ['||cRet||']';
            end if;
          else
            cRet:=cHTML_ERROR||'<b>'||cVocab.vocabulary_id||'</b> was updated in sources ['||cRet||'], but '||cScriptErrorText;
          end if;
          cMailText:=concat(cMailText||crlf,cRet);
          
          --update additional (dependent) vocabularies
          for cVocabA in (
            select * from devv5.vocabulary_access vc where vc.vocabulary_order=1 and vc.vocabulary_update_after=cVocab.vocabulary_id and vc.vocabulary_enabled=1
            order by vc.vocabulary_id
          ) loop
            cScriptFailed:=false;
            cScriptErrorText:=null;
            begin
              if cVocabA.vocabulary_dev_schema is not null then
                --set dev-schema
                execute 'set local session authorization '||cVocabA.vocabulary_dev_schema;
                --parsing the params (json)
                cFastRecreateScript:=cVocabA.vocabulary_params->>'fast_recreate_script';
                cLoadStageURL:=cVocabA.vocabulary_params->>'load_stage_path';
                cMoveToDevv5:=cVocabA.vocabulary_params->>'move_to_devv5';
                
                if cFastRecreateScript is not null then
                  begin --use another begin/end block because we don't want to rollback previous changes (fast recreate)
                    cFastRecreateScript:='do $AutomationSctipt$ begin perform '||crlfSQL||cFastRecreateScript||crlfSQL||'; end $AutomationSctipt$';
                    reset search_path;
                    execute cFastRecreateScript;
                    perform vocabulary_download.write_log (
                      iVocabularyID=>cModuleName,
                      iSessionID=>pSession,
                      iVocabulary_operation=>'fast_recreate for '||cVocabA.vocabulary_dev_schema||' finished',
                      iVocabulary_status=>1
                    );
                  EXCEPTION WHEN OTHERS THEN
                    get stacked diagnostics cRet = pg_exception_context;
                    cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                    cScriptFailed:=true; --the 'Failed' marker
                    cScriptErrorText:='fast_recreate failed: '||SQLERRM;
                    perform vocabulary_download.write_log (
                      iVocabularyID=>cModuleName,
                      iSessionID=>pSession,
                      iVocabulary_operation=>'fast_recreate for '||cVocabA.vocabulary_dev_schema||' failed',
                      iVocabulary_error=>cRet,
                      iVocabulary_status=>2
                    );
                  end;
                end if;
                
                --run load_stage
                if cLoadStageURL is not null then
                  if not cScriptFailed then
                    begin
                      select http_content into cLoadStageScript from vocabulary_download.py_http_get(url=>cLoadStageURL,allow_redirects=>true);
                      cLoadStageScript:='do $AutomationSctipt$ begin '||crlfSQL||cLoadStageScript||crlfSQL||' end $AutomationSctipt$';
                      reset search_path;
                      execute cLoadStageScript;
                      perform vocabulary_download.write_log (
                        iVocabularyID=>cModuleName,
                        iSessionID=>pSession,
                        iVocabulary_operation=>'load_stage for '||cVocabA.vocabulary_dev_schema||' finished',
                        iVocabulary_status=>1
                      );
                    EXCEPTION WHEN OTHERS THEN
                      get stacked diagnostics cRet = pg_exception_context;
                      cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                      cScriptFailed:=true; --the 'Failed' marker
                      cScriptErrorText:='load_stage failed: '||SQLERRM;
                      perform vocabulary_download.write_log (
                        iVocabularyID=>cModuleName,
                        iSessionID=>pSession,
                        iVocabulary_operation=>'load_stage for '||cVocabA.vocabulary_dev_schema||' failed',
                        iVocabulary_error=>cRet,
                        iVocabulary_status=>2
                      );
                    end;
                  end if;
                  
                  --run generic_update after load_stage
                  if not cScriptFailed then
                    begin
                      reset search_path;
                      perform devv5.GenericUpdate();
                      perform vocabulary_download.write_log (
                        iVocabularyID=>cModuleName,
                        iSessionID=>pSession,
                        iVocabulary_operation=>'generic_update for '||cVocabA.vocabulary_dev_schema||' finished',
                        iVocabulary_status=>1
                      );
                    EXCEPTION WHEN OTHERS THEN
                      get stacked diagnostics cRet = pg_exception_context;
                      cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                      cScriptFailed:=true; --the 'Failed' marker
                      cScriptErrorText:='generic_update failed: '||SQLERRM;
                      perform vocabulary_download.write_log (
                        iVocabularyID=>cModuleName,
                        iSessionID=>pSession,
                        iVocabulary_operation=>'generic_update for '||cVocabA.vocabulary_dev_schema||' failed',
                        iVocabulary_error=>cRet,
                        iVocabulary_status=>2
                      );
                    end;
                  end if;
                  
                  --move to devv5
                  if not cScriptFailed and cMoveToDevv5='1' then
                    begin
                      reset session authorization;
                      reset search_path;
                      execute cLoadStageScript;
                      perform devv5.GenericUpdate();
                      perform vocabulary_download.write_log (
                        iVocabularyID=>cModuleName,
                        iSessionID=>pSession,
                        iVocabulary_operation=>'moving to devv5 for '||cVocabA.vocabulary_dev_schema||' finished',
                        iVocabulary_status=>1
                      );
                    EXCEPTION WHEN OTHERS THEN
                      get stacked diagnostics cRet = pg_exception_context;
                      cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                      cScriptFailed:=true; --the 'Failed' marker
                      cScriptErrorText:='moving to devv5 failed: '||SQLERRM;
                      perform vocabulary_download.write_log (
                        iVocabularyID=>cModuleName,
                        iSessionID=>pSession,
                        iVocabulary_operation=>'moving to devv5 for '||cVocabA.vocabulary_dev_schema||' failed',
                        iVocabulary_error=>cRet,
                        iVocabulary_status=>2
                      );
                    end;
                  end if;
                end if;
              end if;
              reset session authorization;
              reset search_path;
              
              --store result
              if not cScriptFailed then
                if cMoveToDevv5='1' then
                  cRet:=cHTML_OK||'<b>'||cVocabA.vocabulary_id||'</b> was updated! [based on '||cVocab.vocabulary_id||'] [devv5]';
                else
                  cRet:=cHTML_OK||'<b>'||cVocabA.vocabulary_id||'</b> was updated! [based on '||cVocab.vocabulary_id||']';
                end if;
              else
                cRet:=cHTML_ERROR||'<b>'||cVocabA.vocabulary_id||'</b> was updated [based on '||cVocab.vocabulary_id||'], but '||cScriptErrorText;
              end if;
              cMailText:=concat(cMailText||crlf,cRet);
              
            EXCEPTION WHEN OTHERS THEN
              reset session authorization;
              reset search_path;
              get stacked diagnostics cRet = pg_exception_context;
              cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
              cMailText:=concat(cMailText||crlf,cHTML_ERROR||'<b>'||cVocabA.vocabulary_id||'</b> returns error: '||SQLERRM);
              perform vocabulary_download.write_log (
                iVocabularyID=>cModuleName,
                iSessionID=>pSession,
                iVocabulary_operation=>'update for '||cVocabA.vocabulary_id||' failed',
                iVocabulary_error=>cRet,
                iVocabulary_status=>2
              );
            end;
          end loop;
          reset session authorization;
          reset search_path;
        else
          RAISE EXCEPTION 'sessionID=%, %',cSessionID,cResult;
        end if;
      ELSE
        --vocabulary already updated
        if coalesce(cSrcDate::varchar,cNewDate::varchar,cSrcVersion,cNewVersion) is not null then --if all values are NULL - vocabulary already fully updated (in sources and devv5)
          --inform that vocabulary was updated, but only in sources
          cRet:=coalesce(to_char(cOldDate,'yyyymmdd'),cOldVersion)||' -> '||coalesce(to_char(cNewDate,'yyyymmdd'),cNewVersion);
          cRet:=cHTML_WAITING||'<b>'||cVocab.vocabulary_id||'</b> was already updated in sources ['||cRet||']. Waiting for migration to devv5';
          cMailText:=concat(cMailText||crlf,cRet);
        ELSE --special case for additional (dependent) vocabularies
          for cVocabA in (
            select * from devv5.vocabulary_access vc where vc.vocabulary_order=1 and vc.vocabulary_update_after=cVocab.vocabulary_id and vc.vocabulary_enabled=1
            order by vc.vocabulary_id
          ) loop
            begin
              select old_date, new_date, old_version, new_version, src_date, src_version 
              into cOldDate, cNewDate, cOldVersion, cNewVersion, cSrcDate, cSrcVersion
              from vocabulary_pack.CheckVocabularyUpdate (cVocabA.vocabulary_id);
              
              if coalesce(cSrcDate::varchar,cSrcVersion)<>coalesce(cOldDate::varchar,cOldVersion) then
                --inform that vocabulary was updated, but only in sources
                cRet:=coalesce(to_char(cOldDate,'yyyymmdd'),cOldVersion)||' -> '||coalesce(to_char(cSrcDate,'yyyymmdd'),cSrcVersion);
                cRet:=cHTML_WAITING||'<b>'||cVocabA.vocabulary_id||'</b> was already updated in sources ['||cRet||']. Waiting for migration to devv5';
                cMailText:=concat(cMailText||crlf,cRet);
              end if;
              EXCEPTION WHEN OTHERS THEN
                reset session authorization;
                reset search_path;
                get stacked diagnostics cRet = pg_exception_context;
                cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                cMailText:=concat(cMailText||crlf,cHTML_ERROR||'<b>'||cVocabA.vocabulary_id||'</b> returns error: '||SQLERRM);
                perform vocabulary_download.write_log (
                  iVocabularyID=>cModuleName,
                  iSessionID=>pSession,
                  iVocabulary_operation=>'check for '||cVocabA.vocabulary_id||' failed',
                  iVocabulary_error=>cRet,
                  iVocabulary_status=>2
                );
            end;
          end loop;
        end if;
      end if;
      
    EXCEPTION WHEN OTHERS THEN
      reset session authorization;
      reset search_path;
      get stacked diagnostics cRet = pg_exception_context;
      cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
      cMailText:=concat(cMailText||crlf,cHTML_ERROR||'<b>'||cVocab.vocabulary_id||'</b> returns error: '||SQLERRM);
      perform vocabulary_download.write_log (
        iVocabularyID=>cModuleName,
        iSessionID=>pSession,
        iVocabulary_operation=>'update for '||cVocab.vocabulary_id||' failed',
        iVocabulary_error=>cRet,
        iVocabulary_status=>2
      );
    end;
  end loop;

  --bottom block
  cMailText:=cMailText||crlf||crlf||'<font color=''#8c8c8c''><pre>---------------'||crlf||
  '- ISBT means ISBT and ISBT Attribute'||crlf||
  '- For AMT, BDPM, DPD and GGR only source tables are updated'||crlf||
  '</pre></font>';
  
  --send e-mail
  cMailText:=coalesce(cMailText,'Nothing to update');
  perform devv5.SendMailHTML (cEmail, 'Automation notification service', cMailText);
  
  perform vocabulary_download.write_log (
    iVocabularyID=>cModuleName,
    iSessionID=>pSession,
    iVocabulary_operation=>cModuleName||' all tasks are done',
    iVocabulary_status=>3
  );
  
  EXCEPTION WHEN OTHERS THEN
    get stacked diagnostics cRet = pg_exception_context;
    cRet:='ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
    perform vocabulary_download.write_log (
      iVocabularyID=>cModuleName,
      iSessionID=>pSession,
      iVocabulary_operation=>cModuleName,
      iVocabulary_error=>cRet,
      iError_details=>replace(cMailText,crlf,crlfSQL),
      iVocabulary_status=>2
    );
end;
$body$
LANGUAGE 'plpgsql' SECURITY INVOKER
SET client_min_messages = error;
CREATE OR REPLACE FUNCTION apigrabber.GetAllNDC (
)
RETURNS void AS
$body$
declare
  cCode devv5.concept.concept_code%type;
  cExecCounter int:=0;
  cExecCounterLimit int:=10;
  z int;
  email CONSTANT varchar (1000):=('timur.vakhitov@firstlinesoftware.com');
  cJOBName constant varchar (1000):= 'JOB "GetAllNDC"';
  cPrevMappingsCount int:=0;
  cFreshMappingsCount int:=0;
  cMailBody varchar (1000);
begin
    perform devv5.SendMailHTML (email, cJOBName||' was started', 'Time: '||now()::timestamp(0));
    
    --check for previous errors on other JOBs
    select count(*) into z from apigrabber.api_codes_failed;
    if z>0 then
      cMailBody:='Cannot execute <b>'||cJOBName||'</b> because the apigrabber.api_codes_failed should be empty!<br>Time: '||clock_timestamp()::timestamp(0);
      perform devv5.SendMailHTML (email, cJOBName||' was finished WITH ERRORS', cMailBody);
      return;
    end if;
    
    set local search_path to devv5; --for proper work of devv5.http_get
    set local devv5.http.timeout_msec TO 30000; --set HTTP timeout
    truncate table apigrabber.ndc_history_tmp;
    truncate table apigrabber.api_codes_failed;

    --first iteration
    for cCode in (
      select c.concept_code from devv5.concept c where c.vocabulary_id='NDC' and c.concept_class_id='11-digit NDC'
      union 
      select rm.ndc_code from apigrabber.rxnorm2ndc_mappings rm
      union
      select sm.ndc_code from sources.spl2ndc_mappings sm
    ) loop
      begin
        insert into apigrabber.ndc_history_tmp
          select cCode, l1.status, l2.activeRxcui, l3.startDate, l4.endDate
          from (
            select h.content,
            l.xml_element
            from devv5.http_get('https://rxnav.nlm.nih.gov/REST/ndcstatus?history=1&ndc='||cCode) h
            left join lateral (select unnest(xpath('/rxnormdata/ndcStatus/ndcHistory', h.content::xml)) as xml_element) l on true
          ) as s
          left join lateral (select unnest(xpath('/rxnormdata/ndcStatus/status/text()', s.content::xml))::varchar status) l1 on true
          left join lateral (select unnest(xpath('activeRxcui/text()', xml_element))::varchar activeRxcui) l2 on true
          left join lateral (select to_date(unnest(xpath('startDate/text()', xml_element))::varchar,'YYYYMM') startDate) l3 on true
          left join lateral (select to_date(unnest(xpath('endDate/text()', xml_element))::varchar,'YYYYMM') endDate) l4 on true;
        exception when others then 
        --if we have any exception - writing to the LOG-table
        insert into apigrabber.api_codes_failed values (cCode);
      end;
    end loop;

    --check the LOG-table for errors
    select count(*) into z from apigrabber.api_codes_failed;
    if z>0 then --we have failed concepts
      loop --cycle for each failed concept, maximum successive attempts = cExecCounterLimit
          for cCode in (select f.concept_code from apigrabber.api_codes_failed f order by random()/*if some concept fails, try the following*/) loop
          begin
            insert into apigrabber.ndc_history_tmp
              select cCode, l1.status, l2.activeRxcui, l3.startDate, l4.endDate
              from (
                select h.content,
                l.xml_element
                from devv5.http_get('https://rxnav.nlm.nih.gov/REST/ndcstatus?history=1&ndc='||cCode) h
                left join lateral (select unnest(xpath('/rxnormdata/ndcStatus/ndcHistory', h.content::xml)) as xml_element) l on true
              ) as s
              left join lateral (select unnest(xpath('/rxnormdata/ndcStatus/status/text()', s.content::xml))::varchar status) l1 on true
              left join lateral (select unnest(xpath('activeRxcui/text()', xml_element))::varchar activeRxcui) l2 on true
              left join lateral (select to_date(unnest(xpath('startDate/text()', xml_element))::varchar,'YYYYMM') startDate) l3 on true
              left join lateral (select to_date(unnest(xpath('endDate/text()', xml_element))::varchar,'YYYYMM') endDate) l4 on true;
            delete from apigrabber.api_codes_failed f where f.concept_code=cCode; --delete the concept if the operation was successful
            cExecCounter:=0; --reset the counter if the operation was successful
            exception when others then
                cExecCounter:=cExecCounter+1;
                perform pg_sleep(10); --waiting for 10s
          end;
        end loop;
      exit when cExecCounter>=cExecCounterLimit or cCode is null;
      end loop;
    end if;
    
    if z=0 or cCode is null then  --all ok OR all errors are gone
        select count(*) into cPrevMappingsCount from apigrabber.ndc_history;
        select count(*) into cFreshMappingsCount from apigrabber.ndc_history_tmp;
        truncate apigrabber.ndc_history;
        insert into apigrabber.ndc_history select * from apigrabber.ndc_history_tmp;
        truncate apigrabber.ndc_history_tmp;
        analyze apigrabber.ndc_history;
        cMailBody:='Parsed mappings: <b>'||cPrevMappingsCount||' -> '||cFreshMappingsCount||'</b><br>Time: '||clock_timestamp()::timestamp(0);
        perform devv5.SendMailHTML (email, cJOBName||' was finished successfully', cMailBody);
    else
        select count(*) into z from apigrabber.api_codes_failed;
        cMailBody:='Failed concepts: <b>'||z||'</b><br>Time: '||clock_timestamp()::timestamp(0);
        perform devv5.SendMailHTML (email, cJOBName||' was finished WITH ERRORS', cMailBody);
    end if;
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100;
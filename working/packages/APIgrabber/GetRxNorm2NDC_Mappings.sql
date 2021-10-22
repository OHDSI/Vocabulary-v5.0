CREATE OR REPLACE FUNCTION apigrabber.GetRxNorm2NDC_Mappings (
)
RETURNS void AS
$body$
declare
  cCode devv5.concept.concept_code%type;
  cExecCounter int:=0;
  cExecCounterLimit int:=10;
  z int;
  email CONSTANT varchar (1000):=(SELECT var_value FROM devv5.config$ WHERE var_name='service_email');
  cJOBName constant varchar (1000):= 'JOB "RxNorm2NDC_Mappings"';
  cPrevMappingsCount int:=0;
  cFreshMappingsCount int:=0;
  cMailBody varchar (1000);
begin
    perform devv5.SendMailHTML (email, cJOBName||' was started', 'Time: '||now()::timestamp(0));
    truncate table apigrabber.rxnorm2ndc_mappings_tmp;
    truncate table apigrabber.api_codes_failed;

    --first iteration
    for cCode in (select c.concept_code from devv5.concept c WHERE c.vocabulary_id = 'RxNorm') loop
      begin
        insert into apigrabber.rxnorm2ndc_mappings_tmp
          select cCode, unnest(xpath('//ndc/text()', h.http_content))::varchar ndc_code,
          to_date(unnest(xpath('//startDate/text()', h.http_content))::varchar,'YYYYMM') startDate,
          to_date(unnest(xpath('//endDate/text()', h.http_content))::varchar,'YYYYMM') endDate
          from (select http_content::xml from vocabulary_download.py_http_get(url=>'https://rxnav.nlm.nih.gov/REST/rxcui/'||cCode||'/allhistoricalndcs?history=1',allow_redirects=>true)) as h;
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
            insert into apigrabber.rxnorm2ndc_mappings_tmp
              select cCode, unnest(xpath('//ndc/text()', h.http_content))::varchar ndc_code,
              to_date(unnest(xpath('//startDate/text()', h.http_content))::varchar,'YYYYMM') startDate,
              to_date(unnest(xpath('//endDate/text()', h.http_content))::varchar,'YYYYMM') endDate
              from (select http_content::xml from vocabulary_download.py_http_get(url=>'https://rxnav.nlm.nih.gov/REST/rxcui/'||cCode||'/allhistoricalndcs?history=1',allow_redirects=>true)) as h;
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
        select count(*) into cPrevMappingsCount from apigrabber.rxnorm2ndc_mappings;
        select count(*) into cFreshMappingsCount from apigrabber.rxnorm2ndc_mappings_tmp;
        truncate apigrabber.rxnorm2ndc_mappings;
        insert into apigrabber.rxnorm2ndc_mappings select * from apigrabber.rxnorm2ndc_mappings_tmp;
        truncate apigrabber.rxnorm2ndc_mappings_tmp;
        analyze apigrabber.rxnorm2ndc_mappings;
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
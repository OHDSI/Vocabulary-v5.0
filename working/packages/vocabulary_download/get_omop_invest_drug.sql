CREATE OR REPLACE FUNCTION vocabulary_download.get_omop_invest_drug (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='OMOP INVEST DRUG';
pVocabulary_auth vocabulary_access.vocabulary_auth%type;
pVocabulary_url vocabulary_access.vocabulary_url%type;
pVocabulary_login vocabulary_access.vocabulary_login%type;
pVocabulary_pass vocabulary_access.vocabulary_pass%type;
pVocabularySrcDate date;
pVocabularySrcVersion text;
pVocabularyNewDate date;
pVocabularyNewVersion text;
pCookie text;
pCookie_p1 text;
pCookie_p1_value text;
pCookie_p2 text;
pCookie_p2_value text;
pValueSetID text;
pContent text;
pDownloadURL text;
auth_hidden_param varchar(10000);
pErrorDetails text;
pVocabularyOperation text;
/*
  possible values of pJumpToOperation:
  ALL (default), JUMP_TO_OMOP_INVEST_DRUG_PREPARE, JUMP_TO_OMOP_INVEST_DRUG_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_OMOP_INVEST_DRUG';
  select nextval('vocabulary_download.log_seq') into pSession;
  
  select new_date, new_version, src_date, src_version 
  	into pVocabularyNewDate, pVocabularyNewVersion, pVocabularySrcDate, pVocabularySrcVersion 
  from vocabulary_pack.CheckVocabularyUpdate(pVocabularyID);
  
  set local search_path to vocabulary_download;
  
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>pVocabularyOperation||' started',
    iVocabulary_status=>0
  );
  
  if iOperation is null then pJumpToOperation:='ALL'; else pJumpToOperation:=iOperation; end if;
  if iOperation not in ('ALL', 'JUMP_TO_OMOP_INVEST_DRUG_PREPARE', 'JUMP_TO_OMOP_INVEST_DRUG_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get url for first file (gsrs)
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;
    
    --getting download link from page
/*    select substring(pVocabulary_url,'^(https?://([^/]+))')||s0.arr[1] into pDownloadURL from (
      select regexp_matches(types->>'text',$$<a href = '\.(.+?-([\d-]+)\..+)'><b>Download</b></a>$$) arr from (select http_content::json as jsonfield from vocabulary_download.py_http_get(url=>pVocabulary_url)) i
      cross join json_array_elements(i.jsonfield) types
      where types->>'type'='news'
      and types->>'title'='Newest GSRS Public Data Released'
    ) as s0
    order by s0.arr[2] desc limit 1;*/
    select pVocabulary_url || (regexp_matches(http_content, '<a[^>]*href\s*=\s*["'']\./([^"'']*\.gsrs)["''][^>]*>[^<]*Download latest dataset[^<]*</a>'))[1]
      into pDownloadURL
      from vocabulary_download.py_http_get(url => pVocabulary_url);
    
    --start downloading
    pVocabularyOperation:='GET_OMOP_INVEST_DRUG dump-public.gsrs downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'dump-public.gsrs.gz',
      iDownloadLink => pDownloadURL,
      iParams => '-4' --use IPv4 instead of IPv6
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_OMOP_INVEST_DRUG dump-public.gsrs downloading complete',
      iVocabulary_status=>1
    );
    
    --get url for second file (xlsx)
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=2;
    
    --getting download link from page
    select pVocabulary_url||s0.arr[1] into pDownloadURL from (
      select regexp_matches(http_content,'<td class="indexcolname"><a href="(NCIT_PharmSub_([\d.a-z]+)_([\d]+)\.xlsx)">.*?</a></td>','gn') arr from py_http_get(url=>pVocabulary_url) 
    ) as s0 order by to_date(s0.arr[3],'yyyymmdd') desc limit 1;


    --start downloading
    pVocabularyOperation:='GET_OMOP_INVEST_DRUG NCIT_PharmSub downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'ncit_pharmsub.xlsx',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0,
      iParams=>'-4' --use IPv4 instead of IPv6
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_OMOP_INVEST_DRUG NCIT_PharmSub downloading complete',
      iVocabulary_status=>1
    );
    
    --get url for 3d file (txt)
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=3;
    
    --getting download link from page (use regexp_matches in case the source wants to version the file)
    select pVocabulary_url||s0.arr[1] into pDownloadURL from (
      select regexp_matches(http_content,'<td class="indexcolname"><a href="(Antineoplastic_Agent\.txt)">.*?</a></td>','gn') arr from py_http_get(url=>pVocabulary_url)
    ) as s0 /*order by ... desc*/ limit 1;
    
    --start downloading
    pVocabularyOperation:='GET_OMOP_INVEST_DRUG Antineoplastic_Agent downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'antineoplastic_agent.txt',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0,
      iParams=>'-4' --use IPv4 instead of IPv6
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_OMOP_INVEST_DRUG Antineoplastic_Agent downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_OMOP_INVEST_DRUG_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_OMOP_INVEST_DRUG prepare';
    perform get_omop_invest_drug_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_OMOP_INVEST_DRUG prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_OMOP_INVEST_DRUG_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_OMOP_INVEST_DRUG load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_OMOP_INVEST_DRUG load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_OMOP_INVEST_DRUG all tasks done',
    iVocabulary_status=>3
  );
  
  session_id:=pSession;
  last_status:=3;
  result_output:=to_char(pVocabularySrcDate,'YYYYMMDD')||' -> '||to_char(pVocabularyNewDate,'YYYYMMDD')||', '||pVocabularySrcVersion||' -> '||pVocabularyNewVersion;
  return;
  
  EXCEPTION WHEN OTHERS THEN
    get stacked diagnostics cRet = pg_exception_context;
    cRet:='ERROR: '||SQLERRM||CRLF||'CONTEXT: '||cRet;
    set local search_path to vocabulary_download;
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation,
      iVocabulary_error=>cRet,
      iError_details=>pErrorDetails,
      iVocabulary_status=>2
    );
    
    session_id:=pSession;
    last_status:=2;
    result_output:=cRet;
    return;
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY DEFINER;
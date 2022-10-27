CREATE OR REPLACE FUNCTION vocabulary_download.get_civic (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='CIVIC';
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
pContent text;
pDownloadURL text;
auth_hidden_param varchar(10000);
pErrorDetails text;
pVocabularyOperation text;
/*
  possible values of pJumpToOperation:
  ALL (default), JUMP_TO_CIVIC_PREPARE, JUMP_TO_CIVIC_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
z record;
BEGIN
  pVocabularyOperation:='GET_CIVIC';
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
  if iOperation not in ('ALL', 'JUMP_TO_CIVIC_PREPARE', 'JUMP_TO_CIVIC_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_url
    into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;

    --get JSON content
    select http_content into pContent from vocabulary_download.py_http_post(url=>pVocabulary_url,
      content_type=>'application/json',
      params=>'{"operationName":"DataReleases","variables":{},"query":"query DataReleases {\n  dataReleases {\n    ...Release\n    __typename\n  }\n}\n\nfragment Release on DataRelease {\n  name\n  geneTsv {\n    filename\n    path\n    __typename\n  }\n  variantTsv {\n    filename\n    path\n    __typename\n  }\n  variantGroupTsv {\n    filename\n    path\n    __typename\n  }\n  evidenceTsv {\n    filename\n    path\n    __typename\n  }\n  assertionTsv {\n    filename\n    path\n    __typename\n  }\n  acceptedVariantsVcf {\n    filename\n    path\n    __typename\n  }\n  acceptedAndSubmittedVariantsVcf {\n    filename\n    path\n    __typename\n  }\n  __typename\n}"}'
    );
    
    --parse JSON to get fully download link
    select substring(pVocabulary_url,'^(https?://([^/]+))')||(s0.main_array#>>'{variantTsv,path}') into pDownloadURL from
    (select json_array_elements(pContent::json#>'{data,dataReleases}') main_array) s0
    where s0.main_array#>>'{name}'<>'nightly'
    order by to_date(main_array#>>'{name}','dd-mon-yyyy') desc limit 1;

    --start downloading
    pVocabularyOperation:='GET_CIVIC downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'variantsummaries.tsv',
      iDownloadLink=>pDownloadURL
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CIVIC downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_CIVIC_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_CIVIC prepare';
    perform get_civic_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>'variantsummaries.tsv'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CIVIC prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_CIVIC_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_CIVIC load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CIVIC load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_CIVIC all tasks done',
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
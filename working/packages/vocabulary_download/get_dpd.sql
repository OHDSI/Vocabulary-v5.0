CREATE OR REPLACE FUNCTION vocabulary_download.get_dpd (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='DPD';
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
  ALL (default), JUMP_TO_DPD_PREPARE, JUMP_TO_DPD_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_DPD';
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
  if iOperation not in ('ALL', 'JUMP_TO_DPD_PREPARE', 'JUMP_TO_DPD_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;
    
    --getting fully working download link from page [all_files_active]
    select substring(http_content,'.+<th rowspan="4">ALL FILES</th>.+<a href="(.+?)" title="all files active') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||pDownloadURL;
    if not coalesce(pDownloadURL,'-') ~* '^(https://www.canada.ca/content/)(.+)\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (all_files_active) is not valid'; end if;
    
    --start downloading
    pVocabularyOperation:='GET_DPD All Files Active downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DPD All Files Active downloading complete',
      iVocabulary_status=>1
    );
    
    --getting fully working download link from page [all_files_discontinued]
    select substring(http_content,'.+<th rowspan="4">ALL FILES</th>.+<a href="(.+?_ia.+?\.zip)" title="all files approved.+') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||pDownloadURL;
    if not coalesce(pDownloadURL,'-') ~* '^(https://www.canada.ca/content/)(.+)_ia.+?\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (all_files_discontinued) is not valid'; end if;
    
    --start downloading
    pVocabularyOperation:='GET_DPD All Files Discontinued downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_ia.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DPD All Files Discontinued downloading complete',
      iVocabulary_status=>1
    );
    
    --getting fully working download link from page [all_files_approved]
    select substring(http_content,'.+<th rowspan="4">ALL FILES</th>.+<a href="(.+?_ap\.zip)" title="all files approved') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||pDownloadURL;
    if not coalesce(pDownloadURL,'-') ~* '^(https://www.canada.ca/content/)(.+)_ap\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (all_files_approved) is not valid'; end if;
    
    --start downloading
    pVocabularyOperation:='GET_DPD All Files Approved downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_ap.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DPD All Files Approved downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_DPD_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_DPD prepare';
    perform get_dpd_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DPD prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_DPD_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_DPD load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DPD load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_DPD all tasks done',
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
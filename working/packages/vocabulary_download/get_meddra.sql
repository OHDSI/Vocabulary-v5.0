CREATE OR REPLACE FUNCTION vocabulary_download.get_meddra (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='MEDDRA';
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
pUnzipPassword text;
/*
  possible values of pJumpToOperation:
  ALL (default), JUMP_TO_MEDDRA_PREPARE, JUMP_TO_MEDDRA_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
z record;
BEGIN
  pVocabularyOperation:='GET_MEDDRA';
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
  if iOperation not in ('ALL', 'JUMP_TO_MEDDRA_PREPARE', 'JUMP_TO_MEDDRA_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;
    
    --get hidden param (web-parsing)
    select substring(http_content,'name="form_build_id" value="(.+?)"') into auth_hidden_param from py_http_get(url=>pVocabulary_auth);
    if auth_hidden_param is null then pErrorDetails:=http_content; raise exception 'auth_hidden_param is null'; end if;
    
    --authorization
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), (select value from json_each_text(http_headers) where lower(key)='location') into pCookie, pVocabulary_url
    from py_http_post(url=>pVocabulary_auth, params=>'name='||devv5.urlencode(pVocabulary_login)||'&pass='||devv5.urlencode(pVocabulary_pass)||'&op=Log+in&form_id=user_login&form_build_id='||auth_hidden_param);
    if pCookie not like '%SESS%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%SESS%% not found'; end if;

    pCookie_p1=substring(pCookie,'(SESS.+?)=(.*?);');
    pCookie_p1_value=substring(pCookie,'SESS.+?=(.*?);');
    pCookie_p2=substring(pCookie,'(SSESS.+?)=(.*?);');
    pCookie_p2_value=substring(pCookie,'SSESS.+?=(.*?);');
    
    --getting fully working download link
    select http_content into pContent from py_http_get(url=>pVocabulary_url,cookies=>'{"'||pCookie_p1||'":"'||pCookie_p1_value||'","'||pCookie_p2||'":"'||pCookie_p2_value||'"}');
    pDownloadURL:=substring(pContent,'.+?<a href="(https://www\.meddra\.org/system/files/software_packages/meddra_[\d_]+_english\.zip)" type="application/zip;.+');
    
    --https://www.meddra.org/system/files/software_packages/meddra_21_0_english.zip
    if not pDownloadURL ~* '^https://www.meddra.org/system/files/software_packages/meddra_[\d_]+_english\.zip$' then pErrorDetails:=pDownloadURL; raise exception 'pDownloadURL (full) is not valid'; end if;

    --start downloading
    pVocabularyOperation:='GET_MEDDRA downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL,
      iParams=>'--no-cookies --header "Cookie: '||pCookie_p1||'='||pCookie_p1_value||'; '||pCookie_p2||'='||pCookie_p2_value||'"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_MEDDRA downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_MEDDRA_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_MEDDRA prepare';
    
    select vocabulary_params->>'unzip_password' into pUnzipPassword from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;

    perform get_meddra_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iPassword=>pUnzipPassword--regexp_replace(pUnzipPassword,'([]/_~!#$%^&*()+=,.<>:;''{}[|?`-])','\\\1','g')
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_MEDDRA prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_MEDDRA_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_MEDDRA load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_MEDDRA load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_MEDDRA all tasks done',
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
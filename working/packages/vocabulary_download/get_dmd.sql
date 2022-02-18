CREATE OR REPLACE FUNCTION vocabulary_download.get_dmd (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='DMD';
pVocabulary_auth vocabulary_access.vocabulary_auth%type;
pVocabulary_url vocabulary_access.vocabulary_url%type;
pVocabulary_login vocabulary_access.vocabulary_login%type;
pVocabulary_pass vocabulary_access.vocabulary_pass%type;
pVocabularySrcDate date;
pVocabularySrcVersion text;
pVocabularyNewDate date;
pVocabularyNewVersion text;
pCookie text;
pContent text;
pTicket text;
pDownloadURL text;
pErrorDetails text;
pVocabularyOperation text;
/*
  possible values of pJumpToOperation:
  ALL (default), JUMP_TO_DMD_PREPARE, JUMP_TO_DMD_IMPORT
*/
pJumpToOperation text;
z int;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_DMD';
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
  if iOperation not in ('ALL',
    'JUMP_TO_DMD_PREPARE',
    'JUMP_TO_DMD_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;

  if pVocabularyNewDate is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    
    pVocabularyOperation:='GET_DMD part 1';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=2;
    
    --authorization
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent
    from py_http_post(url=>pVocabulary_auth, params=>'j_username='||devv5.urlencode(pVocabulary_login)||'&j_password='||devv5.urlencode(pVocabulary_pass)||'&commit=LOG%20IN');
    if pCookie not like '%JSESSIONID=%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%JSESSIONID=%% not found'; end if;
    
    --get working download link
    pCookie=substring(pCookie,'JSESSIONID=(.*?);');
    select http_content into pContent from py_http_get(url=>pVocabulary_url,cookies=>'{"JSESSIONID":"'||pCookie||'"}');
    pDownloadURL:=substring(pContent,'<div class="release-details__label">.+?<a href="(.*?)">.+');
    
    --start downloading
    pVocabularyOperation:='GET_DMD part 1 downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_dmd.zip',
      iDownloadLink=>pDownloadURL
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DMD part 1 downloading complete',
      iVocabulary_status=>1
    );
    
    --dm+d bonus
    pVocabularyOperation:='GET_DMD part 2 (bonus)';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=3;
    
    --authorization
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent
    from py_http_post(url=>pVocabulary_auth, params=>'j_username='||devv5.urlencode(pVocabulary_login)||'&j_password='||devv5.urlencode(pVocabulary_pass)||'&commit=LOG%20IN');
    if pCookie not like '%JSESSIONID=%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%JSESSIONID=%% not found'; end if;
    
    --get working download link
    pCookie=substring(pCookie,'JSESSIONID=(.*?);');
    select http_content into pContent from py_http_get(url=>pVocabulary_url,cookies=>'{"JSESSIONID":"'||pCookie||'"}');
    pDownloadURL:=substring(pContent,'<div class="release-details__label">.+?<a href="(.*?)">.+');
    
    --start downloading
    pVocabularyOperation:='GET_DMD part 2 (bonus) downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_dmdbonus.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DMD part 2 (bonus) downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_DMD_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction dm+d
    pVocabularyOperation:='GET_DMD prepare';
    perform get_dmd_prepare_dmd (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_dmd.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DMD prepare complete',
      iVocabulary_status=>1
    );
    
    --extraction dm+d bonus
    pVocabularyOperation:='GET_DMD bonus prepare';
    perform get_dmd_prepare_dmdbonus (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_dmdbonus.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DMD bonus prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_DMD_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_DMD load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_DMD load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_DMD all tasks done',
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
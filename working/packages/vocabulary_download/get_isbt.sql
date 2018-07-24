CREATE OR REPLACE FUNCTION vocabulary_download.get_isbt (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='ISBT';
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
  ALL (default), JUMP_TO_ISBT_PREPARE, JUMP_TO_ISBT_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_ISBT';
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
  if iOperation not in ('ALL', 'JUMP_TO_ISBT_PREPARE', 'JUMP_TO_ISBT_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;
    
    --authorization
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent
    from py_http_post(url=>pVocabulary_auth, params=>'username='||devv5.urlencode(pVocabulary_login)||'&identifier='||devv5.urlencode(pVocabulary_pass)||'&method=login&op=auth');
    if pCookie not like 'wgSession=%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%wgSession=%% not found'; end if;

    --first part, getting raw download link from page
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=2;
    pCookie=substring(pCookie,'wgSession=(.*?);');
    select http_content into pContent from py_http_get(url=>pVocabulary_url,cookies=>'{"wgSession":"'||pCookie||'"}');
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||substring(pContent,'.+<a href="(.*?)" target="_blank">ISBT 128 Product Description Code Database</a>');
    --http://www.iccbba.org/docs/tech-library/database/isbt-128-product-description-code-database.accdb
    if not pDownloadURL ~* '^(https?://www.iccbba.org/docs/tech-library/database/)(.+)\.accdb$' then pErrorDetails:=pDownloadURL; raise exception 'pDownloadURL (raw) is not valid'; end if;
    
    --second part, now we have fully working download link
    select (select value from json_each_text(http_headers) where lower(key)='location'), http_content into pDownloadURL, pContent from py_http_get(url=>pDownloadURL,cookies=>'{"wgSession":"'||pCookie||'"}');
    pDownloadURL:=trim('"' from pDownloadURL); --remove double quotes
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||pDownloadURL;
    --http://www.iccbba.org/uploads/93/f0/93f0a180adac4a580b971d3503ff08ad/ISBT-128-Product-Description-Code-Database.accdb
    if not pDownloadURL ~* '^(https?://www.iccbba.org/uploads/)(.+)\.accdb$' then pErrorDetails:=pDownloadURL; raise exception 'pDownloadURL (full) is not valid'; end if;

    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation||' authorization successful',
      iVocabulary_status=>1
    );

    --start downloading
    pVocabularyOperation:='GET_ISBT downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.accdb',
      iDownloadLink=>pDownloadURL,
      iParams=>'--no-cookies --header "Cookie: wgSession='||pCookie||'"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_ISBT downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_ISBT_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_ISBT prepare';
    perform get_isbt_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_ISBT prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_ISBT_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_ISBT load_input_tables';
    perform sources.load_input_tables(pVocabularyID);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_ISBT load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_ISBT all tasks done',
    iVocabulary_status=>3
  );
  
  session_id:=pSession;
  last_status:=3;
  result_output:=pVocabularySrcVersion||' -> '||pVocabularyNewVersion;
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
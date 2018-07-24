CREATE OR REPLACE FUNCTION vocabulary_download.get_cvx (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='CVX';
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
  ALL (default), JUMP_TO_CVX_PREPARE, JUMP_TO_CVX_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_CVX';
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
  if iOperation not in ('ALL', 'JUMP_TO_CVX_PREPARE', 'JUMP_TO_CVX_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;
    
    --getting raw download link from page
    select s0.cvx_link into pDownloadURL from (
      with t as (select http_content::xml http_content from py_http_get(url=>pVocabulary_url))
      select unnest(xpath ('/rdf:RDF/global:item/dc:date/text()', t.http_content, 
      ARRAY[
        ARRAY['rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'],
        ARRAY['global', 'http://purl.org/rss/1.0/'],
        ARRAY['dc', 'http://purl.org/dc/elements/1.1/']
      ]))::VARCHAR::date cvx_date,
      unnest(xpath ('/rdf:RDF/global:item/global:link/text()', t.http_content, 
      ARRAY[
      ARRAY['rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'],
      ARRAY['global', 'http://purl.org/rss/1.0/']
      ]))::VARCHAR cvx_link
      from t
    ) as s0 order by s0.cvx_date desc limit 1;
    
    --http://phinvads.cdc.gov/vads/ViewValueSet.action?id=FBEE6963-241C-E811-99B0-0017A477041A
    if not coalesce(pDownloadURL,'-') ~* '^(https?://phinvads.cdc.gov/vads/ViewValueSet\.action\?id=)(.+)$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (raw) is not valid'; end if;
    
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent from py_http_get(url=>pDownloadURL,allow_redirects=>true);
    pCookie_p1_value:=substring(pCookie,'JSESSIONID=(.*?);');
    pCookie_p2_value:=devv5.urlencode('cdcgov=&pid=Value Set Details&pidt=1&oid='||pDownloadURL||'#&ot=A');
    pValueSetID:=substring(pDownloadURL,'^https?://[^/]+(.+)');
    
    --CVX is hard to parse vocabulary, many AJAX requests. So hardcode some necessary links and follow step-by-step (vocabBrowser.js)
    --set download format: Excel
    pDownloadURL:='https://phinvads.cdc.gov/vads/dwr/call/plaincall/searchResultsManager.setDownloadFormat.dwr';
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent 
    from py_http_post(
      url=>pDownloadURL, cookies=>'{"JSESSIONID":"'||pCookie_p1_value||'", "s_sq":"'||pCookie_p2_value||'"}', allow_redirects=>true,
      params=>'callCount=1&page='||pValueSetID||'&httpSessionId='||pCookie_p1_value||'&scriptSessionId=1&c0-scriptName=searchResultsManager&c0-methodName=setDownloadFormat&c0-id=0&c0-param0=string:Excel&batchId=0',
      content_type=>'text/plain'
    );
    
    --select all concepts (?)
    pDownloadURL:='https://phinvads.cdc.gov/vads/AJAXSelectAllValueSetConceptDetailResultDownload.action';
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent 
    from py_http_get(url=>pDownloadURL, cookies=>'{"JSESSIONID":"'||pCookie_p1_value||'", "s_sq":"'||pCookie_p2_value||'"}', allow_redirects=>true);
    
    --generate result (?)
    pDownloadURL:='https://phinvads.cdc.gov/vads/AJAXGenerateValueSetConceptDetailResultDownload.action';
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent 
    from py_http_get(url=>pDownloadURL, cookies=>'{"JSESSIONID":"'||pCookie_p1_value||'", "s_sq":"'||pCookie_p2_value||'"}', allow_redirects=>true);
    
    --download link
    pDownloadURL:='https://phinvads.cdc.gov/vads/RetrieveValueSetConceptDetailResultDownload.action';
    
    --start downloading
    pVocabularyOperation:='GET_CVX ValueSetConceptDetailResultSummary downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'ValueSetConceptDetailResultSummary.xls',
      iDownloadLink=>pDownloadURL,
      iParams=>'--no-cookies --header "Cookie: JSESSIONID='||pCookie_p1_value||'; s_sq='||pCookie_p2_value||'"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CVX ValueSetConceptDetailResultSummary downloading complete',
      iVocabulary_status=>1
    );
    
    --get credentials for second file
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=2;
    
    --start downloading
    pVocabularyOperation:='GET_CVX web_cvx downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'web_cvx.xlsx',
      iDownloadLink=>pVocabulary_url,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CVX web_cvx downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_CVX_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_CVX prepare';
    perform get_cvx_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CVX prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_CVX_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_CVX load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CVX load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_CVX all tasks done',
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
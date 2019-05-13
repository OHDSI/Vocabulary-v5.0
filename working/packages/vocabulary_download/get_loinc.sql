CREATE OR REPLACE FUNCTION vocabulary_download.get_loinc (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='LOINC';
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
  ALL (default), JUMP_TO_LOINC_PREPARE, JUMP_TO_LOINC_IMPORT
*/
pJumpToOperation text;
z int;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_LOINC';
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
  if iOperation not in ('ALL', 'JUMP_TO_LOINC_PREPARE', 'JUMP_TO_LOINC_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  /*if pJumpToOperation='ALL' then 
  	if pVocabularyNewDate is null then raise exception '% already updated',pVocabularyID; end if;
  else
  	--if we want to partially update the vocabulary - use old date
    select vocabulary_date, vocabulary_version into pVocabularyNewDate, pVocabularyNewVersion from sources.loinc limit 1;
  end if;*/
  if pVocabularyNewDate is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;

    --authorization
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent
    from py_http_post(url=>pVocabulary_auth, params=>'log='||devv5.urlencode(pVocabulary_login)||'&pwd='||devv5.urlencode(pVocabulary_pass)||'&testcookie=1&rememberme=forever&wp-submit=Log%20In');
    if pCookie not like '%wordpress_logged_in%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%wordpress_logged_in%% not found'; end if;

    --first part, getting raw download link from page
    select substring(http_content,'.+<h3><a href="(.+?)" rel="no-follow">LOINC Table File \(CSV\)</a></h3>') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    if not coalesce(pDownloadURL,'-') ~* '^(https://loinc.org/download/)(.+)csv/*$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (raw) is not valid'; end if;
    
    pCookie_p1=substring(pCookie,'(wordpress_sec_.+?)=(.*?);');
    pCookie_p1_value=substring(pCookie,'wordpress_sec_.+?=(.*?);');
    pCookie_p2=substring(pCookie,'(wordpress_logged_in_.+?)=(.*?);');
    pCookie_p2_value=substring(pCookie,'wordpress_logged_in_.+?=(.*?);');

    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation||' authorization successful',
      iVocabulary_status=>1
    );

    --start downloading
    --LOINC doesn't provide direct link, just the raw binary data after POST-request
    pVocabularyOperation:='GET_LOINC Main Table downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL,
      iParams=>'--no-cookies --header "Cookie: '||pCookie_p1||'='||pCookie_p1_value||'; '||pCookie_p2||'='||pCookie_p2_value||'" --post-data "tc_accepted=1&tc_submit=Download"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC Main Table downloading complete',
      iVocabulary_status=>1
    );

    --we are already logged in, so let's download the next links
    --multiaxial hierarchy
    pVocabularyOperation:='GET_LOINC Multiaxial Hierarchy downloading';
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=2;
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_mh.zip',
      iDownloadLink=>pVocabulary_url,
      iDeleteAll=>0,
      iParams=>'--no-cookies --header "Cookie: '||pCookie_p1||'='||pCookie_p1_value||'; '||pCookie_p2||'='||pCookie_p2_value||'" --post-data "tc_accepted=1&tc_submit=Download"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC Multiaxial Hierarchy downloading complete',
      iVocabulary_status=>1
    );
    
    --panel and forms
    pVocabularyOperation:='GET_LOINC Panels and Forms downloading';
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=3;
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_pf.zip',
      iDownloadLink=>pVocabulary_url,
      iDeleteAll=>0,
      iParams=>'--no-cookies --header "Cookie: '||pCookie_p1||'='||pCookie_p1_value||'; '||pCookie_p2||'='||pCookie_p2_value||'" --post-data "tc_accepted=1&tc_submit=Download"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC Panels and Forms downloading complete',
      iVocabulary_status=>1
    );
    
    --loinc to snomed
    pVocabularyOperation:='GET_LOINC LOINC/SNOMED CT Expression Association downloading';
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=4;
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_ls.zip',
      iDownloadLink=>pVocabulary_url,
      iDeleteAll=>0,
      iParams=>'--no-cookies --header "Cookie: '||pCookie_p1||'='||pCookie_p1_value||'; '||pCookie_p2||'='||pCookie_p2_value||'" --post-data "tc_accepted=1&tc_submit=Download"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC LOINC/SNOMED CT Expression Association downloading complete',
      iVocabulary_status=>1
    );
    
    --loinc answer
    pVocabularyOperation:='GET_LOINC LOINC Answer downloading';
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=5;
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_la.zip',
      iDownloadLink=>pVocabulary_url,
      iDeleteAll=>0,
      iParams=>'--no-cookies --header "Cookie: '||pCookie_p1||'='||pCookie_p1_value||'; '||pCookie_p2||'='||pCookie_p2_value||'" --post-data "tc_accepted=1&tc_submit=Download"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC LOINC Answer downloading complete',
      iVocabulary_status=>1
    );
    
    --loinc document ontology
    pVocabularyOperation:='GET_LOINC LOINC Document Ontology downloading';
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=8;
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_do.zip',
      iDownloadLink=>pVocabulary_url,
      iDeleteAll=>0,
      iParams=>'--no-cookies --header "Cookie: '||pCookie_p1||'='||pCookie_p1_value||'; '||pCookie_p2||'='||pCookie_p2_value||'" --post-data "tc_accepted=1&tc_submit=Download"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC LOINC Document Ontology downloading complete',
      iVocabulary_status=>1
    );
    
    --loinc loinc group file
    pVocabularyOperation:='GET_LOINC LOINC Group File downloading';
    select vocabulary_url into pVocabulary_url from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=9;
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_gf.zip',
      iDownloadLink=>pVocabulary_url,
      iDeleteAll=>0,
      iParams=>'--no-cookies --header "Cookie: '||pCookie_p1||'='||pCookie_p1_value||'; '||pCookie_p2||'='||pCookie_p2_value||'" --post-data "tc_accepted=1&tc_submit=Download"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC LOINC Group File downloading complete',
      iVocabulary_status=>1
    );
    
    --loinc to cpt mapping
    pVocabularyOperation:='GET_LOINC LOINC To CPT Mapping';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=6;
    
    --first part, getting raw download link from page
    select 'https:'||substring(http_content,'<th>LOINC to CPT Mapping Version</th>.+?href="(.+?)">Draft') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    if not coalesce(pDownloadURL,'-') ~* '^(https://download.nlm.nih.gov/)(.+)\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (raw) is not valid'; end if;
    
    --get full working link with proper cookie
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'),
    (select value from json_each_text(http_headers) where lower(key)='location'),http_content
    into pCookie, pDownloadURL, pContent from py_http_umls (pVocabulary_auth,pDownloadURL,devv5.urlencode(pVocabulary_login),devv5.urlencode(pVocabulary_pass));
    if pCookie not like '%MOD_AUTH_CAS=%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%MOD_AUTH_CAS=%% not found'; end if;
    
    pCookie=substring(pCookie,'MOD_AUTH_CAS=(.*?);');

    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation||' authorization successful',
      iVocabulary_status=>1
    );

    --start downloading
    pVocabularyOperation:='GET_LOINC LOINC To CPT Mapping downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_cpt.zip',
      iDownloadLink=>pDownloadURL,
      iParams=>'--no-cookies --header "Cookie: MOD_AUTH_CAS='||pCookie||'"',
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC LOINC To CPT Mapping downloading complete',
      iVocabulary_status=>1
    );
    
    --loinc to cpt mapping
    pVocabularyOperation:='GET_LOINC loinc_class.csv (raw)';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=7;
    
    --start downloading
    pVocabularyOperation:='GET_LOINC loinc_class.csv downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_class.csv',
      iDownloadLink=>pVocabulary_url,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC loinc_class.csv downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_LOINC_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_LOINC prepare';
    perform get_loinc_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_LOINC_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_LOINC load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_LOINC load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_LOINC all tasks done',
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
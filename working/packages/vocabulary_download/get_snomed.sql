CREATE OR REPLACE FUNCTION vocabulary_download.get_snomed (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='SNOMED';
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
  ALL (default), JUMP_TO_SNOMED_INT_PREPARE, 
  JUMP_TO_SNOMED_UK, JUMP_TO_SNOMED_UK_PREPARE, 
  JUMP_TO_SNOMED_US, JUMP_TO_SNOMED_US_PREPARE, 
  JUMP_TO_SNOMED_UK_DE, JUMP_TO_SNOMED_UK_DE_PREPARE, 
  JUMP_TO_DMD, JUMP_TO_DMD_PREPARE, 
  JUMP_TO_SNOMED_IMPORT
*/
pJumpToOperation text;
z int;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_SNOMED';
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
  if iOperation not in ('ALL', 'JUMP_TO_SNOMED_INT_PREPARE', 
    'JUMP_TO_SNOMED_UK', 'JUMP_TO_SNOMED_UK_PREPARE', 
    'JUMP_TO_SNOMED_US' ,'JUMP_TO_SNOMED_US_PREPARE',
    'JUMP_TO_SNOMED_UK_DE', 'JUMP_TO_SNOMED_UK_DE_PREPARE',
    'JUMP_TO_DMD', 'JUMP_TO_DMD_PREPARE',
    'JUMP_TO_SNOMED_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  /*if pJumpToOperation='ALL' then 
  	if pVocabularyNewDate is null then raise exception '% already updated',pVocabularyID; end if;
  else
  	--if we want to partially update the SNOMED (e.g. only UK-part), then we use the old date from the main source (International release), even if it was updated
    select vocabulary_date into pVocabularyNewDate from sources.sct2_concept_full_merged limit 1;
  end if;*/
  if pVocabularyNewDate is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;
    
    --first part, getting raw download link from page
    select substring(http_content,'<a class="btn btn-info" href="(.+?)"><strong>Download RF2 Files Now!</strong></a>') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    if not coalesce(pDownloadURL,'-') ~* '^(https://download.nlm.nih.gov/)(.+)\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (raw) is not valid'; end if;
    
    --get the proper ticket and concatenate it with the pDownloadURL
    pTicket:=get_umls_ticket (pVocabulary_auth,pVocabulary_login);
    pDownloadURL:=pDownloadURL||'?ticket='||pTicket;

    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation||' authorization successful',
      iVocabulary_status=>1
    );

    --start downloading
    pVocabularyOperation:='GET_SNOMED downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_SNOMED_INT_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_SNOMED INT prepare';
    perform get_snomed_prepare_int (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED INT prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_SNOMED_UK') then
    pJumpToOperation:='ALL';
    
    pVocabularyOperation:='GET_SNOMED UK-part';
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
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||substring(pContent,'<a class="download-release" href="(.*?)">Download</a>');
    --https://isd.digital.nhs.uk/trud3/api/v1/keys/xxx/files/SNOMEDCT2/28.0.0/UK_SCT2CL/uk_sct2cl_28.0.0_20191001000001.zip
    if not pDownloadURL ~* '^(https://isd.digital.nhs.uk/)(.+)\.zip$' then pErrorDetails:=pDownloadURL; raise exception 'pDownloadURL (full) is not valid'; end if;
    
    --start downloading
    pVocabularyOperation:='GET_SNOMED UK-part downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED UK-part downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_SNOMED_UK_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_SNOMED UK prepare';
    perform get_snomed_prepare_uk (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED UK prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_SNOMED_US') then
    pJumpToOperation:='ALL';
    
    pVocabularyOperation:='GET_SNOMED US-part';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=3;
    
    --first part, getting raw download link from page
    select substring(http_content,'Current US Edition Release</h3>.+?<p><a href="(.+?)" class="btn btn-info">Download Now!</a></p>') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    if not coalesce(pDownloadURL,'-') ~* '^(https://download.nlm.nih.gov/)(.+)\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (raw) is not valid'; end if;
    
    --get the proper ticket and concatenate it with the pDownloadURL
    pTicket:=get_umls_ticket (pVocabulary_auth,pVocabulary_login);
    pDownloadURL:=pDownloadURL||'?ticket='||pTicket;

    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation||' authorization successful',
      iVocabulary_status=>1
    );

    --start downloading
    pVocabularyOperation:='GET_SNOMED US-part downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED US-part downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_SNOMED_US_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_SNOMED US prepare';
    perform get_snomed_prepare_us (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED US prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_SNOMED_UK_DE') then
    pJumpToOperation:='ALL';
    
    pVocabularyOperation:='GET_SNOMED UK DE-part';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=4;
    
    --authorization
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent
    from py_http_post(url=>pVocabulary_auth, params=>'j_username='||devv5.urlencode(pVocabulary_login)||'&j_password='||devv5.urlencode(pVocabulary_pass)||'&commit=LOG%20IN');
    if pCookie not like '%JSESSIONID=%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%JSESSIONID=%% not found'; end if;       
    
    --get working download link
    pCookie=substring(pCookie,'JSESSIONID=(.*?);');
    select http_content into pContent from py_http_get(url=>pVocabulary_url,cookies=>'{"JSESSIONID":"'||pCookie||'"}');
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||substring(pContent,'<a class="download-release" href="(.*?)">Download</a>');
    if not pDownloadURL ~* '^(https://isd.digital.nhs.uk/)(.+)\.zip$' then pErrorDetails:=pDownloadURL; raise exception 'pDownloadURL (full) is not valid'; end if;
    
    --start downloading
    pVocabularyOperation:='GET_SNOMED UK DE-part downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED UK DE-part downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_SNOMED_UK_DE_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_SNOMED UK DE prepare';
    perform get_snomed_prepare_uk_de (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED UK DE prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_DMD') then
    pJumpToOperation:='ALL';
    
    pVocabularyOperation:='GET_SNOMED dm+d part 1';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=5;
    
    --authorization
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent
    from py_http_post(url=>pVocabulary_auth, params=>'j_username='||devv5.urlencode(pVocabulary_login)||'&j_password='||devv5.urlencode(pVocabulary_pass)||'&commit=LOG%20IN');
    if pCookie not like '%JSESSIONID=%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%JSESSIONID=%% not found'; end if;       
    
    --get working download link
    pCookie=substring(pCookie,'JSESSIONID=(.*?);');
    select http_content into pContent from py_http_get(url=>pVocabulary_url,cookies=>'{"JSESSIONID":"'||pCookie||'"}');
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||substring(pContent,'<a class="download-release" href="(.*?)">Download</a>');
    if not pDownloadURL ~* '^(https://isd.digital.nhs.uk/)(.+)\.zip$' then pErrorDetails:=pDownloadURL; raise exception 'pDownloadURL (full) is not valid'; end if;
    
    --start downloading
    pVocabularyOperation:='GET_SNOMED dm+d part 1 downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_dmd.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED dm+d part 1 downloading complete',
      iVocabulary_status=>1
    );
    
    --dm+d bonus
    pVocabularyOperation:='GET_SNOMED dm+d part 2 (bonus)';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=6;
    
    --authorization
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent
    from py_http_post(url=>pVocabulary_auth, params=>'j_username='||devv5.urlencode(pVocabulary_login)||'&j_password='||devv5.urlencode(pVocabulary_pass)||'&commit=LOG%20IN');
    if pCookie not like '%JSESSIONID=%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie %%JSESSIONID=%% not found'; end if;       
    
    --get working download link
    pCookie=substring(pCookie,'JSESSIONID=(.*?);');
    select http_content into pContent from py_http_get(url=>pVocabulary_url,cookies=>'{"JSESSIONID":"'||pCookie||'"}');
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||substring(pContent,'<a class="download-release" href="(.*?)">Download</a>');
    if not pDownloadURL ~* '^(https://isd.digital.nhs.uk/)(.+)\.zip$' then pErrorDetails:=pDownloadURL; raise exception 'pDownloadURL (full) is not valid'; end if;
    
    --start downloading
    pVocabularyOperation:='GET_SNOMED dm+d part 2 (bonus) downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_dmdbonus.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED dm+d part 2 (bonus) downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_DMD_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction dm+d
    pVocabularyOperation:='GET_SNOMED dm+d prepare';
    perform get_snomed_prepare_dmd (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_dmd.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED dm+d prepare complete',
      iVocabulary_status=>1
    );
    
    --extraction dm+d bonus
    pVocabularyOperation:='GET_SNOMED dm+d bonus prepare';
    perform get_snomed_prepare_dmdbonus (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_dmdbonus.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED dm+d bonus prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_SNOMED_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_SNOMED load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_SNOMED load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_SNOMED all tasks done',
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
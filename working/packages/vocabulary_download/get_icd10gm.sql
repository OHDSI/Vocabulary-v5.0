CREATE OR REPLACE FUNCTION vocabulary_download.get_icd10gm (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='ICD10GM';
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
pDownloadURL text;
auth_hidden_param varchar(10000);
pErrorDetails text;
pVocabularyOperation text;
pJumpToOperation text; --ALL (default), JUMP_TO_ICD10GM_PREPARE, JUMP_TO_ICD10GM_IMPORT
z int;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_ICD10GM';
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
  
  if pVocabularyNewDate is null then raise exception '% already updated',pVocabularyID; end if;
  
  if iOperation is null then pJumpToOperation:='ALL'; else pJumpToOperation:=iOperation; end if;
  if iOperation not in ('ALL', 'JUMP_TO_ICD10GM_PREPARE', 'JUMP_TO_ICD10GM_IMPORT') then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, max(vocabulary_order) over()
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;
    
    --create two AJAX-requests
    select http_content into pContent from py_http_get(url=>pVocabulary_url);
    --pVocabulary_auth contains target page for second AJAX-request
    select substring(http_content,'.*<a class="dl-titlelink" target="_blank" href="(.*)">ICD-10-GM \d{4} Metadaten TXT \(CSV\) </a>.*') into pDownloadURL from py_http_get(url=>pVocabulary_auth||'?folder='||
        substring(pContent,'.*data-folder="(.*?/klassifikationen/icd-10-gm/version\d{4}/)"')||'&sitepath=/dynamic/system/modules/de.dimdi.apollo.template.downloadcenter/pages/&loc=de&rows=25&start=0');
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||pDownloadURL;
    --https://www.dimdi.de/dynamic/.downloads/klassifikationen/icd-10-gm/version2020/icd10gm2020syst-meta.zip
    if not coalesce(pDownloadURL,'-') ~* '^(https://www.dimdi.de/)(.+)meta\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (raw) is not valid'; end if;
    
    --get cookie
    select (select value from json_each_text(http_headers) where lower(key)='set-cookie'), http_content into pCookie, pContent from py_http_get(url=>pDownloadURL);
    if pCookie not like '%JSESSIONID=%' then pErrorDetails:=pCookie||CRLF||CRLF||pContent; raise exception 'cookie JSESSIONID not found'; end if;
    pCookie=substring(pCookie,'JSESSIONID=(.*?);');

    --dummy POST request that we have accepted the terms of use
    perform py_http_post(url=>'https://www.dimdi.de/dynamic/de/klassifikationen/downloads/icd-10-gm-downloadbedingungen/index.html',
        params=>'formaction=submit&InputField-1=Ich+habe+die+Downloadbedingungen+gelesen+und+stimme+diesen+ausdr%FCcklich+zu.',
        cookies=>'{"JSESSIONID":"'||pCookie||'"}',
        allow_redirects=>false);

    --start downloading
    pVocabularyOperation:='GET_ICD10GM downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL,
      iParams=>'--no-cookies --header "Cookie: JSESSIONID='||pCookie||';CookieBannerOK=accepted; apollodisclaimer--de-klassifikationen-downloads-icd-10-gm-downloadbedingungen-index.html=true"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_ICD10GM downloading complete',
      iVocabulary_status=>1
    );
  end if;

  if pJumpToOperation in ('ALL','JUMP_TO_ICD10GM_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_ICD10GM prepare';
    perform get_icd10gm_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_ICD10GM prepare complete',
      iVocabulary_status=>1
    );
  end if;

  if pJumpToOperation in ('ALL','JUMP_TO_ICD10GM_IMPORT') then
  	pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_ICD10GM load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_ICD10GM load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_ICD10GM all tasks done',
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
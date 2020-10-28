CREATE OR REPLACE FUNCTION vocabulary_download.get_ccam (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='CCAM';
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
  ALL (default), JUMP_TO_CCAM_PREPARE, JUMP_TO_CCAM_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
BEGIN
  pVocabularyOperation:='GET_CCAM';
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
  if iOperation not in ('ALL', 'JUMP_TO_CCAM_PREPARE', 'JUMP_TO_CCAM_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;

    --get download link for PART1
    select substring(http_content,'.+<h4>Fichier dbf complet</h4>.+?<a href="(.+?)">Télécharger le document : CCAM DBF PART01</a>') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||pDownloadURL;

    --start downloading
    pVocabularyOperation:='GET_CCAM PART1 downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_PART1.zip',
      iDownloadLink=>pDownloadURL
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CCAM PART1 downloading complete',
      iVocabulary_status=>1
    );

    --get download link for PART3
    select substring(http_content,'.+<h4>Fichier dbf complet</h4>.+<a href="(.+?)">Télécharger le document : CCAM DBF PART03</a>') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    pDownloadURL:=substring(pVocabulary_url,'^(https?://([^/]+))')||pDownloadURL;

    --start downloading
    pVocabularyOperation:='GET_CCAM PART3 downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_PART3.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0

    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CCAM PART3 downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_CCAM_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_CCAM prepare';
    perform get_ccam_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CCAM prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_CCAM_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_CCAM load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CCAM load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_CCAM all tasks done',
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
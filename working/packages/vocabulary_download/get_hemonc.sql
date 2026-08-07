CREATE OR REPLACE FUNCTION vocabulary_download.get_hemonc(
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='HEMONC';
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
pDownloadURL2 text;
auth_hidden_param varchar(10000);
pErrorDetails text;
pVocabularyOperation text;
pJumpToOperation text; --ALL (default), JUMP_TO_HEMONC_PREPARE, JUMP_TO_HEMONC_IMPORT
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
z record;
BEGIN
  pVocabularyOperation:='GET_HEMONC';
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
  if iOperation not in ('ALL', 'JUMP_TO_HEMONC_PREPARE', 'JUMP_TO_HEMONC_IMPORT') then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;

    pDownloadURL := SUBSTRING(pVocabulary_url,'^(https?://([^/]+))')||SUBSTRING(http_content,'.+<a href="(/dataset.xhtml\?persistentId=.+?)"><span style=.+?>HemOnc knowledgebase</span></a>') from py_http_get(url=>pVocabulary_url,allow_redirects=>true);

    pDownloadURL2 := 'https://dataverse.harvard.edu/api/access/datafile/'
                     || SUBSTRING(LOWER(http_content),'.+<a href="/file.xhtml\?fileid=([\d]+).+?">.+?concept_relationship_stage\.tab.+?</a>.+') 
                     from py_http_get(url=>pDownloadURL,allow_redirects=>true);

    --start downloading concept_relationship_stage
    pVocabularyOperation:='GET_HEMONC concept_relationship_stage downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'concept_relationship_stage.tab',
      iDownloadLink=>pDownloadURL2
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_HEMONC downloading complete',
      iVocabulary_status=>1
    );

    pDownloadURL2 := 'https://dataverse.harvard.edu/api/access/datafile/'
                     || SUBSTRING(LOWER(http_content),'.+<a href="/file.xhtml\?fileid=([\d]+).+?">.+?concept_stage\.tab.+?</a>.+') 
                     from py_http_get(url=>pDownloadURL,allow_redirects=>true);
    --start downloading concept_stage
    pVocabularyOperation:='GET_HEMONC concept_stage downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'concept_stage.tab',
      iDownloadLink=>pDownloadURL2,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_HEMONC downloading complete',
      iVocabulary_status=>1
    );

    pDownloadURL2 := 'https://dataverse.harvard.edu/api/access/datafile/'
                     || SUBSTRING(LOWER(http_content),'.+<a href="/file.xhtml\?fileid=([\d]+).+?">.+?concept_synonym_stage\.tab.+?</a>.+') 
                     from py_http_get(url=>pDownloadURL,allow_redirects=>true);
    --start downloading concept_synonym_stage
    pVocabularyOperation:='GET_HEMONC concept_synonym_stage downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>'concept_synonym_stage.tab',
      iDownloadLink=>pDownloadURL2,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_HEMONC downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_HEMONC_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_HEMONC prepare';
    perform get_hemonc_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_HEMONC prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_HEMONC_IMPORT') then
  	pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_HEMONC load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_HEMONC load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_HEMONC all tasks done',
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
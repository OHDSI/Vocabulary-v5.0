CREATE OR REPLACE FUNCTION vocabulary_download.get_cdm (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='CDM';
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
  ALL (default), JUMP_TO_CDM_PREPARE, JUMP_TO_CDM_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
z record;
pVocabularyNewDateTIMESTAMP timestamp;
pVocabularyReleaseID text;
BEGIN
  pVocabularyOperation:='GET_CDM';
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
  if iOperation not in ('ALL', 'JUMP_TO_CDM_PREPARE', 'JUMP_TO_CDM_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;

    --get working download link
    select s1.release_date, s1.release_id, s1.release_url
    into pVocabularyNewDateTIMESTAMP, pVocabularyReleaseID, pDownloadURL
    from (
      select s0.release_date, s0.release_id, coalesce(s0.browser_download_url,s0.release_url) as release_url from (
        with t as (select json_array_elements(http_content::json) as json_content from py_http_get(url=>pVocabulary_url))
        select (t.json_content->>'published_at')::timestamp as release_date,
        t.json_content->>'node_id' as release_id, t.json_content->>'zipball_url' as release_url,
        t.json_content#>>'{assets,0,browser_download_url}' as browser_download_url
        from t
        where (t.json_content->>'prerelease')::boolean = false
        and (t.json_content->>'node_id')<>'MDc6UmVsZWFzZTcxOTY0MDE=' --exclude 5.2.0 due to DDL bugs
        and not exists (select 1 from sources.cdm_tables ct where ct.ddl_release_id=(t.json_content->>'node_id'))
      ) s0 order by release_date limit 1 --first unparsed release
    ) s1;

    --https://api.github.com/repos/OHDSI/CommonDataModel/zipball/v6.0.0
    --https://github.com/OHDSI/CommonDataModel/releases/download/v5.4.0/OMOPCDM_5.4.zip (if browser_download_url is present)

    --start downloading
    pVocabularyOperation:='GET_CDM downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CDM downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_CDM_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_CDM prepare';
    perform get_cdm_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CDM prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_CDM_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_CDM load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,json_build_object('version',pVocabularyNewVersion,'published_at',pVocabularyNewDateTIMESTAMP,'node_id',pVocabularyReleaseID)::text);
    
    set local search_path to vocabulary_download; --for 'CDM' we need to return the search_path due to the use of vocabulary_pack.ParseTables()
    
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_CDM load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_CDM all tasks done',
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
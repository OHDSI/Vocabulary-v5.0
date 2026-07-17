CREATE OR REPLACE FUNCTION vocabulary_download.get_ndc_spl(
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='NDC_SPL';
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
pJumpToOperation text; --ALL (default), JUMP_TO_NDC_SPL_LABELS, JUMP_TO_NDC_SPL_MAPPINGS, JUMP_TO_NDC_SPL_PREPARE, JUMP_TO_NDC_SPL_IMPORT
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
z record;
BEGIN
  pVocabularyOperation:='GET_NDC_SPL';
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
  if iOperation not in ('ALL', 'JUMP_TO_NDC_SPL_LABELS', 'JUMP_TO_NDC_SPL_MAPPINGS', 'JUMP_TO_NDC_SPL_PREPARE', 'JUMP_TO_NDC_SPL_IMPORT') then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;

    --getting fully working download link from page
    select substring(lower(http_content),'.+<a href="(.+?)">ndc database file - text version \(zip format\)</a>') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    if not coalesce(pDownloadURL,'-') ~* '^(https://www.accessdata.fda.gov/cder/)(.+)\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (full) is not valid'; end if;

    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation||' parsing successful',
      iVocabulary_status=>1
    );

    --start downloading
    pVocabularyOperation:='GET_NDC_SPL downloading';
    perform run_curl (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_NDC_SPL downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_NDC_SPL_LABELS') then
    pJumpToOperation:='ALL';
    
    pVocabularyOperation:='GET_NDC_SPL SPL Drug Labels';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=2;
    
    --getting fully working download links from page and downloading
    for z in (
      select
        d_links,
        case when d_links like '%human_rx%' then concat('rx',substring(d_links,'part([\d]+)'))
        when d_links like '%human_otc%' then concat('otc',substring(d_links,'part([\d]+)'))
        when d_links like '%homeopathic%' then concat('hp',substring(d_links,'part([\d]+)'))
        when d_links like '%remainder%' then concat('rm',substring(d_links,'part([\d]+)'))
        end as d_prefix
      from (
        select unnest(regexp_matches ((select http_content from py_http_get(url=>pVocabulary_url)),'<a href="(ftp://public.nlm.nih.gov/nlmdata/.dailymed/.+?\.zip)">','g')) as d_links
      ) as s
      where d_links ~ 'human|homeopathic|remainder'
    )
    loop
      --start downloading
      pVocabularyOperation:='GET_NDC_SPL SPL Drug Labels ('||z.d_prefix||') downloading';
      perform run_wget (
        iPath=>pVocabulary_load_path,
        iFilename=>lower(pVocabularyID)||'_'||z.d_prefix||'.zip',
        iDownloadLink=>z.d_links,
        iDeleteAll=>0
      );
      perform write_log (
        iVocabularyID=>pVocabularyID,
        iSessionID=>pSession,
        iVocabulary_operation=>'GET_NDC_SPL SPL Drug Labels ('||z.d_prefix||') downloading complete',
        iVocabulary_status=>1
      );
    end loop;
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_NDC_SPL_MAPPINGS') then
    pJumpToOperation:='ALL';
    
    pVocabularyOperation:='GET_NDC_SPL SPL Mappings';
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=3;
    
    --getting fully working download link from page
    select substring(http_content,'.+<a href="(.+?)">rxnorm_mappings.zip</a>') into pDownloadURL from py_http_get(url=>pVocabulary_url);
    if not coalesce(pDownloadURL,'-') ~* '^(https://dailymed-data.nlm.nih.gov/)(.+)\.zip$' then pErrorDetails:=coalesce(pDownloadURL,'-'); raise exception 'pDownloadURL (full) is not valid'; end if;

    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation||' parsing successful',
      iVocabulary_status=>1
    );

    --start downloading
    pVocabularyOperation:='GET_NDC_SPL SPL Mappings downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'_mappings.zip',
      iDownloadLink=>pDownloadURL,
      iDeleteAll=>0
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_NDC_SPL SPL Mappings downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_NDC_SPL_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_NDC_SPL prepare';
    perform get_ndc_spl_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_NDC_SPL prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_NDC_SPL_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_NDC_SPL load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_NDC_SPL load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_NDC_SPL all tasks done',
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
CREATE OR REPLACE FUNCTION vocabulary_download.get_amt (
iOperation text default null,
out session_id int4,
out last_status INT,
out result_output text
)
AS
$BODY$
DECLARE
pVocabularyID constant text:='AMT';
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
  ALL (default), JUMP_TO_AMT_PREPARE, JUMP_TO_AMT_IMPORT
*/
pJumpToOperation text;
cRet text;
CRLF constant text:=E'\r\n';
pSession int4;
pVocabulary_load_path text;
z record;
BEGIN
  pVocabularyOperation:='GET_AMT';
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
  if iOperation not in ('ALL', 'JUMP_TO_AMT_PREPARE', 'JUMP_TO_AMT_IMPORT'
  ) then raise exception 'Wrong iOperation %',iOperation; end if;
  
  if pVocabularyNewVersion is null then raise exception '% already updated',pVocabularyID; end if;
  
  if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) then raise exception 'Processing of % already started',pVocabularyID; end if;
  
  select var_value||pVocabularyID into pVocabulary_load_path from devv5.config$ where var_name='vocabulary_load_path';
    
  if pJumpToOperation='ALL' then
    --get credentials
    select vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
    into pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass from devv5.vocabulary_access where vocabulary_id=pVocabularyID and vocabulary_order=1;
    
    --authorization
    select http_content::json->>'access_token' into pCookie from py_http_post(
      url=>pVocabulary_auth,
      params=>'grant_type=client_credentials&client_id='||devv5.urlencode(pVocabulary_login)||'&client_secret='||devv5.urlencode(pVocabulary_pass)
    );

    --get working download link
    select s0.link into pDownloadURL from (
    with t as (select http_content::xml http_content from py_http_get(url=>pVocabulary_url))
    select unnest(xpath ('//xmlns:category/@term', t.http_content,
        ARRAY[ARRAY['xmlns', 'http://www.w3.org/2005/Atom'],
        ARRAY['ncts', 'http://ns.electronichealth.net.au/ncts/syndication/asf/extensions/1.0.0']
      ]))::varchar category,
      to_date(substring(unnest(xpath ('//ncts:contentItemVersion/text()', t.http_content,
        ARRAY[ARRAY['xmlns', 'http://www.w3.org/2005/Atom'],
        ARRAY['ncts', 'http://ns.electronichealth.net.au/ncts/syndication/asf/extensions/1.0.0']
      ]))::varchar,'.+/([\d]{8})$'),'yyyymmdd') amt_date,
	  unnest(xpath ('/xmlns:feed/xmlns:entry/xmlns:link/@href', t.http_content,
        ARRAY[ARRAY['xmlns', 'http://www.w3.org/2005/Atom'],
        ARRAY['ncts', 'http://ns.electronichealth.net.au/ncts/syndication/asf/extensions/1.0.0']
      ]))::varchar link
      from t
    ) s0
    where s0.category='SCT_RF2_FULL' order by s0.amt_date desc limit 1;
            
    --https://api.healthterminologies.gov.au/syndication/v1/au/gov/ehealthterminology/snomedct-au/NCTS_SCT_RF2_DISTRIBUTION_32506021000036107/20180731/NCTS_SCT_RF2_DISTRIBUTION_32506021000036107-20180731-FULL.zip
    if not pDownloadURL ~* '^(https://api.healthterminologies.gov.au/)(.+)\.zip$' then pErrorDetails:=pDownloadURL; raise exception 'pDownloadURL (full) is not valid'; end if;

    --start downloading
    pVocabularyOperation:='GET_AMT downloading';
    perform run_wget (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip',
      iDownloadLink=>pDownloadURL,
      iParams=>'--no-cookies --header "Authorization: Bearer '||pCookie||'"'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_AMT downloading complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_AMT_PREPARE') then
    pJumpToOperation:='ALL';
    --extraction
    pVocabularyOperation:='GET_AMT prepare';
    perform get_amt_prepare (
      iPath=>pVocabulary_load_path,
      iFilename=>lower(pVocabularyID)||'.zip'
    );
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_AMT prepare complete',
      iVocabulary_status=>1
    );
  end if;
  
  if pJumpToOperation in ('ALL','JUMP_TO_AMT_IMPORT') then
    pJumpToOperation:='ALL';
    --finally we have all input tables, we can start importing
    pVocabularyOperation:='GET_AMT load_input_tables';
    perform sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
    perform write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>'GET_AMT load_input_tables complete',
      iVocabulary_status=>1
    );
  end if;
    
  perform write_log (
    iVocabularyID=>pVocabularyID,
    iSessionID=>pSession,
    iVocabulary_operation=>'GET_AMT all tasks done',
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
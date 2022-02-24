CREATE OR REPLACE FUNCTION vocabulary_download.write_log (
  iVocabularyID varchar,
  iSessionID int4,
  iVocabulary_operation text,
  iVocabulary_error text default null,
  iError_details text default null,
  iVocabulary_status int default null
)
RETURNS void as
$BODY$
DECLARE
pQuery text;
BEGIN
  set local search_path to vocabulary_download;
  if iVocabulary_status not in (0,1,2,3) then raise exception 'vocabulary_id=%, bad vocabulary status=%',iVocabularyID,iVocabulary_status; end if;
  if nullif(iVocabularyID,'') is null then raise exception 'vocabulary_id cannot be empty!'; end if;
  if nullif(iVocabulary_operation,'') is null then raise exception 'vocabulary_operation cannot be empty!'; end if;
  pQuery:='
    insert into vocabulary_download.vocabulary_log values ('||
    nextval('log_seq')||',$$'||
    iVocabularyID||'$$,'||
    iSessionID||',
    clock_timestamp(),'||
    coalesce('$$'||iVocabulary_operation||'$$','NULL')||','||
    coalesce('$$'||iVocabulary_error||'$$','NULL')||','||
    coalesce('$$'||iError_details||'$$','NULL')||','||
    iVocabulary_status||')
  ';
  perform * from devv5.pg_background_result(devv5.pg_background_launch (pQuery)) as (result text);
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY DEFINER;
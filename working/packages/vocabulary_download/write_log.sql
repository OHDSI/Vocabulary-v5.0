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
z int4;
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
  z:=devv5.pg_background_launch (pQuery);
  perform pg_sleep(0.1);--don't know how this parameter affects the python module 'requests', but without it py_http_* can return an "Interrupted system call" error
  perform devv5.pg_background_detach(z); --avoid the problem of "too many dynamic shared memory segments"
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY DEFINER;
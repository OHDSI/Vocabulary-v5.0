CREATE OR REPLACE FUNCTION vocabulary_pack.startrelease (
)
RETURNS void AS
$body$
/* Start the release: 
 1. filling concept_ancestor 
 2. v5 to v4 conversion
 3. export base tables
 4. creating copy of PRODV5
*/
DECLARE
  crlf VARCHAR(4) := '<br>';
  email CONSTANT VARCHAR(1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='vocabulary_release_email');
  cRet TEXT;
  cVocabs VARCHAR(4000);
  cVocabsDelim CONSTANT VARCHAR(1000) :=', ';
  z INT4;
BEGIN
  perform vocabulary_pack.pConceptAncestor();
  perform DEVV4.v5_to_v4();
  UPDATE vocabulary SET vocabulary_version = 'v5.0 '||TO_CHAR(CURRENT_DATE,'DD-MON-YY') WHERE vocabulary_id = 'None';
  
  --check for extended columns, drop if any
  SELECT COUNT(*) 
  INTO z
  FROM information_schema.columns tc
  WHERE tc.table_schema = CURRENT_SCHEMA
    AND tc.table_name = 'vocabulary'
    AND tc.column_name IN (
    'latest_update',
    'dev_schema_name'
    );
  IF z>0
    THEN
    ALTER TABLE vocabulary DROP COLUMN latest_update, DROP COLUMN dev_schema_name;
  END IF;
  
  perform vocabulary_pack.pCreateBaseDump();
  
  SELECT string_agg(DISTINCT vocabulary_id, cVocabsDelim ORDER BY vocabulary_id)
  INTO cVocabs
  FROM (
        SELECT *
        FROM devv5.concept
        --WHERE invalid_reason IS NULL
        EXCEPT
        SELECT *
        FROM prodv5.concept
        --WHERE invalid_reason IS NULL
      ) AS s0;

  perform vocabulary_pack.CreateReleaseReport();
  perform vocabulary_pack.CreateWiKiReport();
  perform vocabulary_pack.CreateLocalPROD();
  
  cRet := 'Release completed';

  IF cVocabs IS NOT NULL
    THEN
    cRet := cRet || crlf || 'Affected vocabularies: ' || cVocabs;
    --store result in vocabulary_release_stat (20190207)
    update devv5.vocabulary_release_stat vrs set latest_release_date=clock_timestamp()::date where vrs.vocabulary_id = any (string_to_array(cVocabs,cVocabsDelim));
    insert into devv5.vocabulary_release_stat
    (
      select vocabulary_id, clock_timestamp()::date from (
      select unnest(string_to_array(cVocabs,cVocabsDelim)) as vocabulary_id
      except
      select vocabulary_id from devv5.vocabulary_release_stat
      ) as s0
    );
  END IF;

  perform devv5.SendMailHTML (email, 'Release status [OK]', cRet);
  
  EXCEPTION
  WHEN OTHERS
  THEN
    GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT;
    cRet:='ERROR: '||SQLERRM||crlf||'CONTEXT: '||regexp_replace(cRet, '\r|\n|\r\n', crlf, 'g');
    cRet := SUBSTR ('Release completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 5000);
    perform devv5.SendMailHTML (email, 'Release status [ERROR]', cRet);
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
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
BEGIN
  perform vocabulary_pack.pConceptAncestor();
  perform DEVV4.v5_to_v4();
  UPDATE VOCABULARY SET VOCABULARY_VERSION = 'v5.0 '||TO_CHAR(current_date,'DD-MON-YY') WHERE VOCABULARY_ID = 'None';
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
COST 100;
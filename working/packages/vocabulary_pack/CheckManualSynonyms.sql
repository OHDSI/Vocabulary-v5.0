CREATE OR REPLACE FUNCTION vocabulary_pack.CheckManualSynonyms ()
RETURNS void AS
$body$
DECLARE
  z INT4;
BEGIN
  SELECT COUNT(*)
  INTO z
  FROM concept_synonym_manual csm
       LEFT JOIN concept c ON c.concept_code = csm.synonym_concept_code AND c.vocabulary_id = csm.synonym_vocabulary_id
       LEFT JOIN concept_stage cs ON cs.concept_code = csm.synonym_concept_code AND cs.vocabulary_id = csm.synonym_vocabulary_id
       LEFT JOIN vocabulary v ON v.vocabulary_id = csm.synonym_vocabulary_id
       LEFT JOIN concept c_l ON c_l.concept_id = csm.language_concept_id
  WHERE (c.concept_code IS NULL AND cs.concept_code IS NULL) OR v.vocabulary_id IS NULL OR c_l.concept_id IS NULL;

  IF z > 0
    THEN
    RAISE EXCEPTION  'CheckManualSynonyms: % error(s) found', z;
  END IF;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;
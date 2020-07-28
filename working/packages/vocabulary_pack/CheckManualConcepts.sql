CREATE OR REPLACE FUNCTION vocabulary_pack.CheckManualConcepts ()
RETURNS void AS
$body$
DECLARE
  z INT4;
BEGIN
  SELECT COUNT(*)
  INTO z
  FROM concept_manual cm
       LEFT JOIN concept c ON c.concept_code = cm.concept_code AND c.vocabulary_id = cm.vocabulary_id
       LEFT JOIN concept_stage cs ON cs.concept_code = cm.concept_code AND cs.vocabulary_id = cm.vocabulary_id
       LEFT JOIN vocabulary v ON v.vocabulary_id = cm.vocabulary_id
       LEFT JOIN domain d ON d.domain_id = cm.domain_id
       LEFT JOIN concept_class cc ON cc.concept_class_id = cm.concept_class_id
  WHERE (c.concept_code IS NULL AND cs.concept_code IS NULL)
        OR v.vocabulary_id IS NULL
        OR cm.valid_end_date < cm.valid_start_date
        OR date_trunc('day', (cm.valid_start_date)) <> cm.valid_start_date
        OR date_trunc('day', (cm.valid_end_date)) <> cm.valid_end_date
        OR (cm.invalid_reason IS NULL AND cm.valid_end_date <> TO_DATE('20991231', 'yyyymmdd'))
        OR (cm.invalid_reason IS NOT NULL AND cm.valid_end_date = TO_DATE('20991231', 'yyyymmdd'))
        OR (d.domain_id IS NULL AND cm.domain_id IS NOT NULL)
        OR (cc.concept_class_id IS NULL AND cm.concept_class_id IS NOT NULL)
        OR COALESCE(cm.standard_concept, 'S') NOT IN ('C','S')
        OR COALESCE(cm.invalid_reason, 'D') <> 'D';

  IF z > 0
    THEN
    RAISE EXCEPTION  'CheckManualConcepts: % error(s) found', z;
  END IF;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;
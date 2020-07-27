CREATE OR REPLACE FUNCTION vocabulary_pack.CheckManualRelationships (
)
RETURNS void AS
$body$
DECLARE
  z INT4;
BEGIN
  SELECT COUNT(*)
  INTO z
  FROM concept_relationship_manual crm
       LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
       LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
       LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
       LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2 AND cs2.vocabulary_id = crm.vocabulary_id_2
       LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
       LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
       LEFT JOIN relationship rl ON rl.relationship_id = crm.relationship_id
       LEFT JOIN 
       (
         SELECT crm_int.concept_code_1,
                crm_int.vocabulary_id_1,
                crm_int.concept_code_2,
                crm_int.vocabulary_id_2,
                crm_int.relationship_id
         FROM concept_relationship_manual crm_int
         GROUP BY crm_int.concept_code_1,
                  crm_int.vocabulary_id_1,
                  crm_int.concept_code_2,
                  crm_int.vocabulary_id_2,
                  crm_int.relationship_id
         HAVING COUNT(*) > 1
       ) c_i ON c_i.concept_code_1 = crm.concept_code_1 AND c_i.vocabulary_id_1 = crm.vocabulary_id_1 AND c_i.concept_code_2 = crm.concept_code_2 AND
         c_i.vocabulary_id_2 = crm.vocabulary_id_2 AND c_i.relationship_id = crm.relationship_id
  WHERE (c1.concept_code IS NULL
        AND cs1.concept_code IS NULL)
        OR (c2.concept_code IS NULL
        AND cs2.concept_code IS NULL)
        OR v1.vocabulary_id IS NULL
        OR v2.vocabulary_id IS NULL
        OR rl.relationship_id IS NULL
        OR crm.valid_start_date > CURRENT_DATE
        OR crm.valid_end_date < crm.valid_start_date
        OR date_trunc('day', (crm.valid_start_date)) <> crm.valid_start_date
        OR date_trunc('day', (crm.valid_end_date)) <> crm.valid_end_date
        OR (crm.invalid_reason IS NULL
        AND crm.valid_end_date <> TO_DATE('20991231', 'yyyymmdd'))
        OR c_i.concept_code_1 IS NOT NULL;

  IF z > 0
    THEN
    RAISE EXCEPTION  'CheckManualRelationships: % error(s) found', z;
  END IF;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;
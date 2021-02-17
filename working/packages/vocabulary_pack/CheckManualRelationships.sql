CREATE OR REPLACE FUNCTION vocabulary_pack.CheckManualRelationships ()
RETURNS void AS
$BODY$
DECLARE
	z TEXT;
BEGIN
	SELECT reason INTO z FROM (
		SELECT
			CASE WHEN c1.concept_code IS NULL AND cs1.concept_code IS NULL THEN 'concept_code_1+vocabulary_id_1 not found in the concept/concept_stage: '||crm.concept_code_1||'+'||crm.vocabulary_id_1
				WHEN c2.concept_code IS NULL AND cs2.concept_code IS NULL THEN 'concept_code_2+vocabulary_id_2 not found in the concept/concept_stage: '||crm.concept_code_2||'+'||crm.vocabulary_id_2
				WHEN v1.vocabulary_id IS NULL THEN 'vocabulary_id_1 not found in the vocabulary: '||crm.vocabulary_id_1
				WHEN v2.vocabulary_id IS NULL THEN 'vocabulary_id_2 not found in the vocabulary: '||crm.vocabulary_id_2
				WHEN rl.relationship_id IS NULL THEN 'relationship_id not found in the relationship: '||crm.relationship_id
				WHEN crm.valid_start_date > CURRENT_DATE THEN 'valid_start_date is greater than the current date: '||TO_CHAR(crm.valid_start_date,'YYYYMMDD')
				WHEN crm.valid_end_date < crm.valid_start_date THEN 'valid_end_date < valid_start_date: '||TO_CHAR(crm.valid_end_date,'YYYYMMDD')||'+'||TO_CHAR(crm.valid_start_date,'YYYYMMDD')
				WHEN date_trunc('day', (crm.valid_start_date)) <> crm.valid_start_date THEN 'wrong format for valid_start_date (not truncated): '||TO_CHAR(crm.valid_start_date,'YYYYMMDD HH24:MI:SS')
				WHEN date_trunc('day', (crm.valid_end_date)) <> crm.valid_end_date THEN 'wrong format for valid_end_date (not truncated to YYYYMMDD): '||TO_CHAR(crm.valid_end_date,'YYYYMMDD HH24:MI:SS')
				WHEN ((crm.invalid_reason IS NULL AND crm.valid_end_date <> TO_DATE('20991231', 'yyyymmdd'))
					OR (crm.invalid_reason IS NOT NULL AND crm.valid_end_date = TO_DATE('20991231', 'yyyymmdd'))) THEN 'wrong invalid_reason: '||COALESCE(crm.invalid_reason,'NULL')||' for '||TO_CHAR(crm.valid_end_date,'YYYYMMDD')
				WHEN COALESCE(crm.invalid_reason, 'D') NOT IN ('D','U') THEN 'wrong value for invalid_reason: '||crm.invalid_reason
				WHEN crm.relationship_id IN ('Mapped from','Value mapped from','Concept replaces') THEN 'it is better to use '||rl.reverse_relationship_id||' instead of '||crm.relationship_id
				ELSE NULL
			END AS reason
		FROM concept_relationship_manual crm
			LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
			LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
			LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
			LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2 AND cs2.vocabulary_id = crm.vocabulary_id_2
			LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
			LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
			LEFT JOIN relationship rl ON rl.relationship_id = crm.relationship_id
	) AS s0
	WHERE reason IS NOT NULL LIMIT 1;

	IF z IS NOT NULL THEN
		RAISE EXCEPTION '%', z;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;
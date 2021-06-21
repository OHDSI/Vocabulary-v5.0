CREATE OR REPLACE FUNCTION vocabulary_pack.CheckManualConcepts ()
RETURNS void AS
$BODY$
DECLARE
	z TEXT;
BEGIN
	SELECT reason INTO z FROM (
		SELECT
			CASE WHEN v.vocabulary_id IS NULL THEN 'vocabulary_id not found in the vocabulary: '||cm.vocabulary_id
				WHEN cm.valid_end_date < cm.valid_start_date THEN 'valid_end_date < valid_start_date: '||TO_CHAR(cm.valid_end_date,'YYYYMMDD')||'+'||TO_CHAR(cm.valid_start_date,'YYYYMMDD')
				WHEN date_trunc('day', (cm.valid_start_date)) <> cm.valid_start_date THEN 'wrong format for valid_start_date (not truncated): '||TO_CHAR(cm.valid_start_date,'YYYYMMDD HH24:MI:SS')
				WHEN date_trunc('day', (cm.valid_end_date)) <> cm.valid_end_date THEN 'wrong format for valid_end_date (not truncated to YYYYMMDD): '||TO_CHAR(cm.valid_end_date,'YYYYMMDD HH24:MI:SS')
				WHEN (((cm.invalid_reason IS NULL AND cm.valid_end_date <> TO_DATE('20991231', 'yyyymmdd')) AND cm.vocabulary_id NOT IN (SELECT TRIM(v) FROM UNNEST(STRING_TO_ARRAY((SELECT var_value FROM devv5.config$ WHERE var_name='special_vocabularies'),',')) v))
					OR (cm.invalid_reason IS NOT NULL AND cm.valid_end_date = TO_DATE('20991231', 'yyyymmdd'))) THEN 'wrong invalid_reason: '||COALESCE(cm.invalid_reason,'NULL')||' for '||TO_CHAR(cm.valid_end_date,'YYYYMMDD')
				WHEN d.domain_id IS NULL AND cm.domain_id IS NOT NULL THEN 'domain_id not found in the domain: '||cm.domain_id
				WHEN cc.concept_class_id IS NULL AND cm.concept_class_id IS NOT NULL THEN 'concept_class_id not found in the concept_class: '||cm.concept_class_id
				WHEN COALESCE(cm.standard_concept, 'S') NOT IN ('C','S','X') THEN 'wrong value for standard_concept: '||cm.standard_concept
				WHEN COALESCE(cm.invalid_reason, 'D') NOT IN ('D','U','X') THEN 'wrong value for invalid_reason: '||cm.invalid_reason
				ELSE NULL
			END AS reason
		FROM concept_manual cm
			LEFT JOIN vocabulary v ON v.vocabulary_id = cm.vocabulary_id
			LEFT JOIN domain d ON d.domain_id = cm.domain_id
			LEFT JOIN concept_class cc ON cc.concept_class_id = cm.concept_class_id
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

CREATE OR REPLACE FUNCTION vocabulary_pack.CheckManualSynonyms ()
RETURNS void AS
$BODY$
DECLARE
	z TEXT;
BEGIN

	SELECT reason INTO z FROM (
		SELECT
			CASE WHEN c.concept_code IS NULL AND cs.concept_code IS NULL THEN 'synonym_concept_code+synonym_vocabulary_id not found in the concept/concept_stage: '||csm.synonym_concept_code||'+'||csm.synonym_vocabulary_id
				WHEN v.vocabulary_id IS NULL THEN 'synonym_vocabulary_id not found in the vocabulary: '||csm.synonym_vocabulary_id
				WHEN c_l.concept_id IS NULL THEN 'language_concept_id not found in the concept: '||csm.language_concept_id
				ELSE NULL
			END AS reason
		FROM concept_synonym_manual csm
			LEFT JOIN concept c ON c.concept_code = csm.synonym_concept_code AND c.vocabulary_id = csm.synonym_vocabulary_id
			LEFT JOIN concept_stage cs ON cs.concept_code = csm.synonym_concept_code AND cs.vocabulary_id = csm.synonym_vocabulary_id
			LEFT JOIN vocabulary v ON v.vocabulary_id = csm.synonym_vocabulary_id
			LEFT JOIN concept c_l ON c_l.concept_id = csm.language_concept_id AND c_l.vocabulary_id IN ('SNOMED','Language') AND c_l.domain_id='Language' AND c_l.concept_class_id='Qualifier Value' AND c_l.concept_name ilike '%language'
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
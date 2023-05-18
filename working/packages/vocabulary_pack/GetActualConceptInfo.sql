CREATE OR REPLACE FUNCTION vocabulary_pack.GetActualConceptInfo (pConceptCode TEXT, pVocabularyID TEXT)
RETURNS SETOF concept AS
$BODY$
	/*
	 Get actual information about a concept in the following order: concept_stage, concept
	*/
	SELECT s0.concept_id,
		s0.concept_name,
		s0.domain_id,
		s0.vocabulary_id,
		s0.concept_class_id,
		s0.standard_concept,
		s0.concept_code,
		s0.valid_start_date,
		s0.valid_end_date,
		s0.invalid_reason
	FROM (
		SELECT cs.*
		FROM concept_stage cs
		WHERE cs.concept_code = pConceptCode
			AND cs.vocabulary_id = pVocabularyID
		
		UNION ALL
		
		SELECT c.*
		FROM concept c
		WHERE c.concept_code = pConceptCode
			AND c.vocabulary_id = pVocabularyID
		) AS s0
	LIMIT 1;
$BODY$
LANGUAGE 'sql' STABLE STRICT;
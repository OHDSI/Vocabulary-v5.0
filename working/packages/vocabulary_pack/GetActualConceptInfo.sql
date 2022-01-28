CREATE OR REPLACE FUNCTION vocabulary_pack.GetActualConceptInfo (iConceptCode text, iVocabularyID text)
RETURNS SETOF concept AS
$BODY$
/*
 Get actual information about a concept in the following order: concept_stage, concept
*/
	SELECT DISTINCT ON (s0.concept_code) s0.concept_id,
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
		SELECT 1 table_type,
			cs.*
		FROM concept_stage cs
		WHERE cs.concept_code = iConceptCode
			AND cs.vocabulary_id = iVocabularyID
		
		UNION ALL
		
		SELECT 2 table_type,
			c.*
		FROM concept c
		WHERE c.concept_code = iConceptCode
			AND c.vocabulary_id = iVocabularyID
		) AS s0
	ORDER BY s0.concept_code,
		s0.table_type;--concept_stage first
$BODY$
LANGUAGE 'sql'
STABLE PARALLEL RESTRICTED SECURITY INVOKER RETURNS NULL ON NULL INPUT;
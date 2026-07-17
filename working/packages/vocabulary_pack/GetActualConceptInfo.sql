CREATE OR REPLACE FUNCTION vocabulary_pack.GetActualConceptInfo (pConceptCode TEXT, pVocabularyID TEXT)
--RETURNS concept AS --some customers have their own restrictions on field lengths (ETL projects)
RETURNS TABLE (
	concept_id INT4,
	concept_name TEXT,
	domain_id TEXT,
	vocabulary_id TEXT,
	concept_class_id TEXT,
	standard_concept TEXT,
	concept_code TEXT,
	valid_start_date DATE,
	valid_end_date DATE,
	invalid_reason TEXT
) AS
$BODY$
	/*
	 Get actual information about a concept in the following order: concept_stage, concept
	*/
	SELECT cs.*
	FROM concept_stage cs
	WHERE cs.concept_code = pConceptCode
		AND cs.vocabulary_id = pVocabularyID

	UNION ALL

	SELECT c.*
	FROM concept c
	WHERE c.concept_code = pConceptCode
		AND c.vocabulary_id = pVocabularyID

	LIMIT 1;
$BODY$
LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION vocabulary_pack.GetActualConceptInfo (pConceptCode TEXT, pVocabularyID TEXT)
RETURNS concept AS
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
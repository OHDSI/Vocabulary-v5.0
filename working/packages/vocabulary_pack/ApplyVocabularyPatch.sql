CREATE OR REPLACE FUNCTION vocabulary_pack.ApplyVocabularyPatch (
	pVocabulary VARCHAR[]
)
RETURNS VOID AS
$BODY$
	/*
	The function copies new concepts/synonyms and their mappings to itself from devv5 into the current schema
	Example:
	DO $_$
	BEGIN
		PERFORM vocabulary_pack.ApplyVocabularyPatch(ARRAY['PPI','IQVIA']);
	END $_$;
	*/
BEGIN
	PERFORM FROM vocabulary v
	WHERE v.vocabulary_id = ANY (pVocabulary)
	HAVING COUNT(*) = ARRAY_LENGTH(pVocabulary, 1);

	IF NOT FOUND THEN
		RAISE EXCEPTION 'One or more vocabulary doesn''t exists';
	END IF;

	INSERT INTO concept
	SELECT *
	FROM devv5.concept c
	WHERE c.vocabulary_id = ANY (pVocabulary)
	ON CONFLICT DO NOTHING;

	INSERT INTO concept_synonym
	SELECT cs.*
	FROM devv5.concept_synonym cs
	JOIN devv5.concept c USING (concept_id)
	WHERE c.vocabulary_id = ANY (pVocabulary)
	ON CONFLICT DO NOTHING;

	INSERT INTO concept_relationship
	SELECT cr.*
	FROM devv5.concept_relationship cr
	JOIN devv5.concept c ON c.concept_id = cr.concept_id_1
		AND c.vocabulary_id = ANY (pVocabulary)
	WHERE cr.concept_id_1 = cr.concept_id_2
		AND cr.relationship_id IN (
			'Maps to',
			'Mapped from'
			)
		AND cr.invalid_reason IS NULL
	ON CONFLICT DO NOTHING;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;

REVOKE EXECUTE ON FUNCTION vocabulary_pack.ApplyVocabularyPatch FROM PUBLIC;
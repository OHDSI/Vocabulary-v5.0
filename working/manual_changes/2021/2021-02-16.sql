--https://github.com/OHDSI/Vocabulary-v5.0/issues/437
DELETE
FROM concept_synonym
WHERE concept_synonym_name = ' ';

--https://forums.ohdsi.org/t/concept-synonym-usage-in-concept-searching/11562
DELETE
FROM concept_synonym cs
WHERE EXISTS (
		SELECT 1
		FROM concept c
		WHERE c.concept_id = cs.concept_id
			AND LOWER(c.concept_name) = LOWER(cs.concept_synonym_name)
		);
--fix name duplicates in concept_synonym [AVOF-1782]

DO $$
BEGIN
	DELETE
	FROM concept_synonym cs
	WHERE concept_synonym_name ~ ' {2,}'
		AND EXISTS (
			SELECT 1
			FROM concept_synonym cs_int
			WHERE cs_int.concept_id = cs.concept_id
				AND cs_int.concept_synonym_name = REGEXP_REPLACE(cs.concept_synonym_name, ' {2,}', ' ')
				AND cs.language_concept_id = cs_int.language_concept_id
			);

	DELETE
	FROM concept_synonym cs
	WHERE (
			concept_synonym_name LIKE ' %'
			OR concept_synonym_name LIKE '% '
			)
		AND EXISTS (
			SELECT 1
			FROM concept_synonym cs_int
			WHERE cs_int.concept_id = cs.concept_id
				AND cs_int.concept_synonym_name = TRIM(cs.concept_synonym_name)
				AND cs.language_concept_id = cs_int.language_concept_id
			);

	--remove double spaces, carriage return, newline, vertical tab and form feed
	UPDATE concept_synonym
	SET concept_synonym_name = REGEXP_REPLACE(concept_synonym_name, '[[:cntrl:]]+', ' ')
	WHERE concept_synonym_name ~ '[[:cntrl:]]';

	UPDATE concept_synonym
	SET concept_synonym_name = REGEXP_REPLACE(concept_synonym_name, ' {2,}', ' ')
	WHERE concept_synonym_name ~ ' {2,}';

	--remove leading and trailing spaces
	UPDATE concept_synonym
	SET concept_synonym_name = TRIM(concept_synonym_name)
	WHERE concept_synonym_name <> TRIM(concept_synonym_name)
		AND concept_synonym_name <> ' ';--exclude GPI empty names

	--remove long dashes
	UPDATE concept_synonym
	SET concept_synonym_name = REPLACE(concept_synonym_name, '–', '-')
	WHERE concept_synonym_name LIKE '%–%';
END $$;
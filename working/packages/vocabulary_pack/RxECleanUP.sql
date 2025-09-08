CREATE OR REPLACE FUNCTION vocabulary_pack.RxECleanUP (
)
RETURNS void
    LANGUAGE plpgsql
AS
$$
/*
 Clean up for RxE (create 'Concept replaced by' between RxE and Rx)
 AVOF-1456
 Usage:
 1. update the vocabulary (e.g. RxNorm) with generic_update
 2. run this script like
 DO $_$
 BEGIN
     PERFORM VOCABULARY_PACK.RxECleanUP();
 END $_$;
 3. run generic_update
*/
BEGIN
	--1. Update latest_update field to new date
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.SetLatestUpdate(
		pVocabularyName			=> 'RxNorm Extension',
		pVocabularyDate			=> CURRENT_DATE,
		pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
		pVocabularyDevSchema	=> 'DEV_RXNORM'
	);

	END $_$;

	--2. Truncate all working tables
	TRUNCATE TABLE concept_stage;
	TRUNCATE TABLE concept_relationship_stage;
	TRUNCATE TABLE concept_synonym_stage;
	TRUNCATE TABLE pack_content_stage;
	TRUNCATE TABLE drug_strength_stage;

	--3. Load full list of RxNorm Extension concepts and set 'X' for duplicates
	INSERT INTO concept_stage
	SELECT *
	FROM concept
	WHERE vocabulary_id = 'RxNorm Extension';

	UPDATE concept_stage cs
	SET invalid_reason = 'X',
		standard_concept = NULL,
		valid_end_date = CURRENT_DATE,
		concept_id=c.concept_id
	FROM concept c
	WHERE upper(cs.concept_name) = upper(c.concept_name)
		AND cs.concept_class_id = c.concept_class_id
		AND c.invalid_reason IS NULL
		AND c.vocabulary_id = 'RxNorm'
		AND cs.invalid_reason IS NULL;

	--4. Load full list of RxNorm Extension relationships
	INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT c1.concept_code,
		c2.concept_code,
		c1.vocabulary_id,
		c2.vocabulary_id,
		r.relationship_id,
		r.valid_start_date,
		r.valid_end_date,
		r.invalid_reason
	FROM concept c1,
		concept c2,
		concept_relationship r
	WHERE c1.concept_id = r.concept_id_1
		AND c2.concept_id = r.concept_id_2
		AND (
                (
                    c1.vocabulary_id = 'RxNorm Extension'
                    AND c2.vocabulary_id = 'RxNorm'
                    )
                OR (
                    c1.vocabulary_id = 'RxNorm'
                    AND c2.vocabulary_id = 'RxNorm Extension'
                    )
			)
	    AND (c1.vocabulary_id, c2.vocabulary_id) != ('RxNorm', 'RxNorm')
		AND r.invalid_reason IS NULL;

	--5. Deprecate old relationships
	UPDATE concept_relationship_stage crs
	SET invalid_reason = 'D',
		valid_end_date = CURRENT_DATE
	FROM concept_stage cs
	WHERE cs.concept_code IN (
			crs.concept_code_1,
			crs.concept_code_2
			) --with reverse
		AND cs.invalid_reason = 'X';

	--6. Add new replacements
	INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date
		)
	SELECT cs.concept_code,
		c.concept_code,
		cs.vocabulary_id,
		c.vocabulary_id,
		'Concept replaced by',
		CURRENT_DATE,
		TO_DATE('20991231', 'yyyymmdd')
	FROM concept_stage cs
	JOIN concept c ON c.concept_id = cs.concept_id
	WHERE cs.invalid_reason = 'X';

	--7. Update concept_stage (set 'U' for all 'X')
	UPDATE concept_stage
	SET invalid_reason = 'U'
	WHERE invalid_reason = 'X';

	--8. Working with replacement mappings
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.CheckReplacementMappings();
	END $_$;

	--Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	END $_$;

	--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
	END $_$;

	DO $_$
    BEGIN
    PERFORM vocabulary_pack.addpropagatedhierarchymapsto();
    END $_$;


	--9. AddFreshMAPSTO creates RxNorm(ATC)-RxNorm links that need to be removed
	DELETE
	FROM concept_relationship_stage crs_o
	WHERE (
			crs_o.concept_code_1,
			crs_o.vocabulary_id_1,
			crs_o.concept_code_2,
			crs_o.vocabulary_id_2
			) IN (
			SELECT crs.concept_code_1,
				crs.vocabulary_id_1,
				crs.concept_code_2,
				crs.vocabulary_id_2
			FROM concept_relationship_stage crs
			LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
				AND v1.latest_update IS NOT NULL
			LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2
				AND v2.latest_update IS NOT NULL
			WHERE COALESCE(v1.latest_update, v2.latest_update) IS NULL
			);

	--10. Fill concept_synonym_stage
	INSERT INTO concept_synonym_stage
	SELECT cs.concept_id,
		cs.concept_synonym_name,
		c.concept_code,
		c.vocabulary_id,
		cs.language_concept_id
	FROM concept_synonym cs
	JOIN concept c ON c.concept_id = cs.concept_id
		AND c.vocabulary_id = 'RxNorm Extension';
	END;
$$;

$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;
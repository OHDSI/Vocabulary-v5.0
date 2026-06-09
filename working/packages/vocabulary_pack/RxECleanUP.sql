CREATE or replace FUNCTION rxecleanup() RETURNS void
    LANGUAGE plpgsql
AS
$$

/* Clean up for RxE (create 'Concept replaced by' between RxE and Rx)
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
    -- 1. Update latest_update field to new date
    PERFORM vocabulary_pack.SetLatestUpdate(
        pVocabularyName         => 'RxNorm Extension',
        pVocabularyDate         => CURRENT_DATE,
        pVocabularyVersion      => 'RxNorm Extension ' || CURRENT_DATE,
        pVocabularyDevSchema    => 'DEV_RXNORM'
    );

	--2. Truncate all working tables
	TRUNCATE TABLE concept_stage;
	TRUNCATE TABLE concept_relationship_stage;
	TRUNCATE TABLE concept_synonym_stage;
	TRUNCATE TABLE pack_content_stage;
	TRUNCATE TABLE drug_strength_stage;

	--3. Load full list of RxNorm Extension concepts and mark RxE-vs-RxNorm duplicates as 'X'
	--   Uses semantic name normalization (devv5.compare_custom_english) instead of
	--   plain UPPER() match to catch decimal-zero variants and punctuation differences.
	--   Brand Name and Supplier classes are excluded: they legitimately differ between
	--   RxNorm and RxE and should not be auto-deprecated here.
	INSERT INTO concept_stage
	SELECT *
	FROM concept
	WHERE vocabulary_id = 'RxNorm Extension';

	WITH cs_processed AS (
		SELECT
			cs.concept_id  AS cs_id,
			cs.concept_class_id,
			dev_rxnorm.compare_custom_english(cs.concept_name) AS cs_vector
		FROM concept_stage cs
		WHERE cs.invalid_reason IS NULL
		  AND cs.concept_class_id NOT IN ('Brand Name', 'Supplier')
	),
	c_processed AS (
		SELECT
			c.concept_id   AS c_id,
			c.concept_class_id,
			dev_rxnorm.compare_custom_english(c.concept_name) AS c_vector
		FROM concept c
		WHERE c.invalid_reason IS NULL
		  AND c.vocabulary_id = 'RxNorm'
		  AND c.concept_class_id NOT IN ('Brand Name', 'Supplier')
	)
	UPDATE concept_stage cs
	   SET invalid_reason   = 'X',
	       standard_concept = NULL,
	       valid_end_date   = CURRENT_DATE,
	       concept_id       = cp.c_id   -- points to the RxNorm replacement target
	  FROM cs_processed cs_p
	  JOIN c_processed  cp
	    ON cs_p.cs_vector       = cp.c_vector
	   AND cs_p.concept_class_id = cp.concept_class_id
	 WHERE cs.concept_id = cs_p.cs_id;

	--3b. Find and mark intra-RxE duplicates (RxE concepts that are duplicates of each
	--    other, not of RxNorm concepts).  Survivor preference order:
	--      1. Standard concept ('S') over non-standard
	--      2. Oldest valid_start_date (the original entry)
	--      3. Lowest concept_id (tie-break)
	--    Brand Name and Supplier classes are excluded here as well.
	DROP TABLE IF EXISTS concept_replacements;

	CREATE TABLE concept_replacements AS
	WITH cstage_normalized AS (
		SELECT
			concept_id                                        AS cs_id,
			concept_class_id                                  AS cs_cc_id,
			COALESCE(standard_concept, '')                    AS standard_concept,
			valid_start_date,
			dev_rxnorm.compare_custom_english(concept_name)        AS normalized_name
		FROM concept_stage
		WHERE invalid_reason IS NULL
		  AND concept_class_id NOT IN ('Brand Name', 'Supplier')
	),
	ranked_concepts AS (
		SELECT
			cs.*,
			ROW_NUMBER() OVER (
				PARTITION BY normalized_name, cs_cc_id
				ORDER BY
					CASE WHEN standard_concept = 'S' THEN 0 ELSE 1 END,
					valid_start_date,
					cs_id
			) AS rn,
			COUNT(*) OVER (PARTITION BY normalized_name, cs_cc_id) AS grp_cnt
		FROM cstage_normalized cs
	),
	grouped_replacements AS (
		SELECT
			MIN(cs_id) FILTER (WHERE rn = 1)                   AS main,
			string_agg(cs_id::text, ',') FILTER (WHERE rn > 1) AS for_replacement
		FROM ranked_concepts
		WHERE grp_cnt > 1
		GROUP BY normalized_name, cs_cc_id
	)
	SELECT *
	FROM grouped_replacements
	WHERE for_replacement IS NOT NULL;

	UPDATE concept_stage cs
	   SET invalid_reason   = 'X',
	       standard_concept = NULL,
	       valid_end_date   = CURRENT_DATE,
	       concept_id       = cr.main   -- points to the surviving RxE concept
	  FROM concept_replacements cr,
	       unnest(string_to_array(cr.for_replacement, ',')) AS dup_id
	 WHERE cs.concept_id = dup_id::bigint
	   AND cs.invalid_reason IS NULL;

	DROP TABLE concept_replacements;

	--4. Fill concept_synonym_stage for RxNorm Extension
	INSERT INTO concept_synonym_stage
	SELECT cs.concept_id,
		cs.concept_synonym_name,
		c.concept_code,
		c.vocabulary_id,
		cs.language_concept_id
	FROM concept_synonym cs
	JOIN concept c ON c.concept_id = cs.concept_id
		AND c.vocabulary_id = 'RxNorm Extension';

	--4. Work with relationships
    --4.1. Load the full list of active RxNorm Extension <-> RxNorm (RxNorm Extension) relationships
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
        (c1.vocabulary_id = 'RxNorm Extension' AND c2.vocabulary_id = 'RxNorm')
        OR (c1.vocabulary_id = 'RxNorm'           AND c2.vocabulary_id = 'RxNorm Extension')
        OR (c1.vocabulary_id = 'RxNorm Extension' AND c2.vocabulary_id = 'RxNorm Extension')
    )
		AND r.invalid_reason IS NULL;


	--4.2. Add 'Concept replaced by' for 'X' concepts EXCEPT where a manual
	--    'Maps to' (RxNorm Extension -> RxNorm) already exists in
	--    concept_relationship_manual.  Manual overrides take precedence.
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
	WHERE cs.invalid_reason = 'X'
        AND (cs.concept_code, c.concept_code) NOT IN (
            SELECT concept_code_1, concept_code_2 FROM concept_relationship_manual
        )
        AND NOT EXISTS (
            SELECT 1
            FROM concept_relationship_manual crm
            WHERE cs.concept_code     = crm.concept_code_1
              AND cs.vocabulary_id    = 'RxNorm Extension'
              AND crm.vocabulary_id_1 = 'RxNorm Extension'
              AND crm.vocabulary_id_2 = 'RxNorm'
              AND crm.relationship_id = 'Maps to'
              AND crm.invalid_reason IS NULL
        );

	-- 4.3. For 'X' concepts that DO have a manual 'Maps to' in
	--     concept_relationship_manual, propagate that manual mapping instead
	--     of the auto-generated 'Concept replaced by'.
    INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date
		)
    WITH manual_maps AS (
        SELECT *
        FROM concept_relationship_manual
        WHERE vocabulary_id_1 = 'RxNorm Extension'
          AND vocabulary_id_2 = 'RxNorm'
          AND relationship_id = 'Maps to'
          AND invalid_reason IS NULL
    )
    SELECT cs.concept_code,
        t1.concept_code_2,
        cs.vocabulary_id,
        t1.vocabulary_id_2,
        'Maps to',
        CURRENT_DATE,
        TO_DATE('20991231', 'yyyymmdd')
    FROM concept_stage cs
    JOIN concept c ON c.concept_id = cs.concept_id
    JOIN manual_maps t1 ON cs.concept_code = t1.concept_code_1
    WHERE cs.invalid_reason = 'X'
      AND (cs.concept_code, c.concept_code) NOT IN (
          SELECT concept_code_1, concept_code_2 FROM concept_relationship_manual
      )
      AND EXISTS (
          SELECT 1
          FROM concept_relationship_manual crm
          WHERE cs.concept_code     = crm.concept_code_1
            AND cs.vocabulary_id    = 'RxNorm Extension'
            AND crm.vocabulary_id_1 = 'RxNorm Extension'
            AND crm.vocabulary_id_2 = 'RxNorm'
            AND crm.relationship_id = 'Maps to'
      );

   --5. Apply manual changes:
    DO $_$
    BEGIN
        PERFORM VOCABULARY_PACK.ProcessManualConcepts();
    END $_$;

    DO $_$
    BEGIN
        PERFORM VOCABULARY_PACK.ProcessManualRelationships();
    END $_$;

	--6. Standard mapping pipeline
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.CheckReplacementMappings();
	END $_$;

	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	END $_$;

	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
	END $_$;

    DO $_$
    BEGIN
        PERFORM vocabulary_pack.AddPropagatedHierarchyMapsTo();
    END $_$;

	--7. Deprecate all relationships touching 'X'-marked concepts except for replacements and 'Maps to'
	UPDATE concept_relationship_stage crs
	SET invalid_reason = 'D',
		valid_end_date = CURRENT_DATE
	FROM concept_stage cs
	WHERE cs.concept_code IN (
			crs.concept_code_1,
			crs.concept_code_2
			) --with reverse
		AND cs.invalid_reason = 'X'
	    AND crs.relationship_id NOT IN ('Maps to', 'Concept replaced by');

	--8. Promote 'X' to 'U' (deprecated/upgraded) now that replacement rels are in place
	UPDATE concept_stage
	SET invalid_reason = 'U'
	WHERE invalid_reason = 'X';

	--9. AddFreshMAPSTO may create RxNorm(ATC)-RxNorm links that cross vocabulary
	--   boundaries without the latest_update anchor -- remove them.
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


	END;
$$;
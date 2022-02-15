CREATE OR REPLACE FUNCTION vocabulary_pack.RxECleanUP (
)
RETURNS void AS
$BODY$
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
		pVocabularyDevSchema	=> 'DEV_RXE'
	);
		PERFORM VOCABULARY_PACK.SetLatestUpdate(
		pVocabularyName			=> 'RxNorm',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_RXNORM',
		pAppendVocabulary		=> TRUE
	);
	END $_$;

	--2. Truncate all working tables
	TRUNCATE TABLE concept_stage;
	TRUNCATE TABLE concept_relationship_stage;
	TRUNCATE TABLE concept_synonym_stage;
	TRUNCATE TABLE pack_content_stage;
	TRUNCATE TABLE drug_strength_stage;

	--3. Collect all replacements to be made in a single table
	--3.1. Collect attribute replacement
	DROP TABLE IF EXISTS atom_replacement;
	CREATE UNLOGGED TABLE atom_replacement AS
	SELECT rxe.concept_id AS rxe_id,
		rxe.concept_code AS rxe_code,
		rx.concept_id AS rx_id,
		rx.concept_code AS rx_code
	FROM concept rxe
	JOIN concept rx ON UPPER(rx.concept_name) = UPPER(rxe.concept_name)
		AND rx.concept_class_id = rxe.concept_class_id
		AND rx.invalid_reason IS NULL
		AND rx.vocabulary_id = 'RxNorm'
		AND rx.concept_class_id IN (
			'Brand Name',
			'Ingredient',
			'Dose Form'
			)
	WHERE rxe.vocabulary_id = 'RxNorm Extension'
		AND rxe.invalid_reason IS NULL;

	--3.2. Create attribute portraits of every concept
	DROP TABLE IF EXISTS rx_portrait;
	CREATE UNLOGGED TABLE rx_portrait AS
	WITH broken_ing
	AS (
		--Filter out concepts with more '/' than needed
		SELECT ds.drug_concept_id
		FROM drug_strength ds
		JOIN concept c ON c.concept_id = ds.drug_concept_id
			AND c.vocabulary_id = 'RxNorm'
			AND c.standard_concept = 'S'
		GROUP BY ds.drug_concept_id,
			c.concept_name
		HAVING (LENGTH(c.concept_name) - LENGTH(REPLACE(c.concept_name, ' / ', ''))) / 3 /*slash count*/ > COUNT(ds.ingredient_concept_id) /*ingredient count*/ - 1
		)
	SELECT s0.concept_code,
		s0.concept_class_id,
		s0.concept_name,
		s0.vocabulary_id,
		s0.valid_start_date,
		s0.ingredient_concept_id,
		s0.amount_value,
		s0.amount_unit_concept_id,
		s0.numerator_value,
		s0.numerator_unit_concept_id,
		s0.denominator_value,
		s0.denominator_unit_concept_id,
		s0.i_count,
		--find pairs that match on everything but dosages
		'(' || l.ingredient_list || ')-' || s0.ingredient_concept_id || '-' || s0.dose_code || '-' || s0.brand_code AS portrait
	FROM (
		SELECT c.concept_code,
			c.concept_class_id,
			c.concept_name,
			c.vocabulary_id,
			c.valid_start_date,
			--ingredient and dosage
			COALESCE(ar3.rx_id, ds.ingredient_concept_id) AS ingredient_concept_id,
			ds.amount_value,
			ds.amount_unit_concept_id,
			ds.numerator_value,
			ds.numerator_unit_concept_id,
			ds.denominator_value,
			ds.denominator_unit_concept_id,
			COUNT(ds.ingredient_concept_id) OVER (PARTITION BY ds.drug_concept_id) AS i_count, --todo: replace with list of ingredients
			--dose form info
			COALESCE(ar2.rx_code, cd.concept_code, '0') AS dose_code,
			--brand name info
			COALESCE(ar1.rx_code, cb.concept_code, '0') AS brand_code,
			--list all ingredients per drug
			ARRAY_AGG(ingredient_concept_id) OVER (PARTITION BY c.concept_code) AS ingredient_list
		FROM concept c
		--get ingredients
		JOIN drug_strength ds ON ds.drug_concept_id = c.concept_id
			AND ds.box_size IS NULL --RxN does not have this
			--get df
		LEFT JOIN concept_relationship d ON d.concept_id_1 = c.concept_id
			AND d.invalid_reason IS NULL
			AND d.relationship_id = 'RxNorm has dose form'
		LEFT JOIN concept cd ON cd.concept_id = d.concept_id_2
		--get bn
		LEFT JOIN concept_relationship b ON b.concept_id_1 = c.concept_id
			AND b.invalid_reason IS NULL
			AND b.relationship_id = 'Has brand name'
		LEFT JOIN concept cb ON cb.concept_id = b.concept_id_2
		--filter out broken ingredients
		LEFT JOIN broken_ing x ON x.drug_concept_id = c.concept_id
		--replace BN with new ones
		LEFT JOIN atom_replacement ar1 ON ar1.rxe_code = cb.concept_code
		--replace DF with new ones
		LEFT JOIN atom_replacement ar2 ON ar2.rxe_code = cd.concept_code
		--replace Ingredients
		LEFT JOIN atom_replacement ar3 ON ar3.rxe_id = ds.ingredient_concept_id
		WHERE c.standard_concept = 'S'
			AND c.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND c.concept_class_id <> 'Ingredient'
			AND x.drug_concept_id IS NULL
		) s0
	--we need a sorted list of ingredient_concept_id, but we can't use string_agg(.. order by ..) over (partition by .. ) due to "aggregate ORDER BY is not implemented for window functions"
	--so we use array_agg+unnest in lateral + string_agg (.. order by ..)
	CROSS JOIN LATERAL(SELECT STRING_AGG(s_int.ingredient_concept_id::VARCHAR, '-' ORDER BY s_int.ingredient_concept_id) AS ingredient_list FROM (
			SELECT UNNEST(s0.ingredient_list) AS ingredient_concept_id
			) AS s_int) AS l;

	DROP TABLE IF EXISTS portrait_match;
	CREATE UNLOGGED TABLE portrait_match AS
	SELECT DISTINCT r1.concept_code AS rxe_code,
		r2.concept_code AS rxn_code
	FROM rx_portrait r1
	JOIN rx_portrait r2 ON r2.portrait = r1.portrait
		AND r2.concept_class_id = r1.concept_class_id
	WHERE r1.concept_code <> r2.concept_code
		AND r1.vocabulary_id = 'RxNorm Extension'
		AND r2.vocabulary_id = 'RxNorm';

	CREATE INDEX idx_portrait_match ON portrait_match (rxe_code,rxn_code);
	ANALYZE portrait_match;

	--3.3. Create final replacement table
	DROP TABLE IF EXISTS concept_replacement_full;
	CREATE UNLOGGED TABLE concept_replacement_full AS
		--match simple amount dosages
		WITH any_match_a AS (
				SELECT DISTINCT r1.concept_code AS rxe_code,
					r2.concept_code AS rxn_code,
					r2.concept_name,
					r2.valid_start_date,
					r1.i_count,
					COUNT(pm.rxn_code) OVER (
						PARTITION BY r1.concept_code,
						r2.concept_code
						) AS matches_per_pair,
					CASE 
						WHEN r1.amount_value / r2.amount_value >= 1
							THEN r1.amount_value / r2.amount_value
						ELSE r2.amount_value / r1.amount_value
						END AS imprecision
				FROM rx_portrait r1
				JOIN rx_portrait r2 ON r2.portrait = r1.portrait
					AND r2.concept_class_id = r1.concept_class_id
					AND r2.ingredient_concept_id = r1.ingredient_concept_id
					AND r2.amount_unit_concept_id = r1.amount_unit_concept_id
					AND r2.denominator_unit_concept_id IS NULL
				JOIN portrait_match pm ON pm.rxe_code = r1.concept_code
					AND pm.rxn_code = r2.concept_code
				WHERE r1.amount_value / r2.amount_value BETWEEN 1 / 1.05 AND 1.05
				),
			--match numerator/denominator dosages
			any_match_nd AS (
				SELECT DISTINCT r1.concept_code AS rxe_code,
					r2.concept_code AS rxn_code,
					r2.concept_name,
					r2.valid_start_date,
					r1.i_count,
					COUNT(pm.rxn_code) OVER (
						PARTITION BY r1.concept_code,
						r2.concept_code
						) AS matches_per_pair,
					CASE 
						WHEN (r1.numerator_value / COALESCE(r1.denominator_value, 1)) / (r2.numerator_value / COALESCE(r2.denominator_value, 1)) >= 1
							THEN (r1.numerator_value / COALESCE(r1.denominator_value, 1)) / (r2.numerator_value / COALESCE(r2.denominator_value, 1))
						ELSE (r2.numerator_value / COALESCE(r2.denominator_value, 1)) / (r1.numerator_value / COALESCE(r1.denominator_value, 1))
						END AS imprecision
				FROM rx_portrait r1
				JOIN rx_portrait r2 ON r2.portrait = r1.portrait
					AND r2.concept_class_id = r1.concept_class_id
					AND r2.ingredient_concept_id = r1.ingredient_concept_id
					AND r2.numerator_unit_concept_id = r1.numerator_unit_concept_id
					AND r2.denominator_unit_concept_id = r1.denominator_unit_concept_id
					AND COALESCE(r2.denominator_value, 0) = COALESCE(r1.denominator_value, 0)
				JOIN portrait_match pm ON pm.rxe_code = r1.concept_code
					AND pm.rxn_code = r2.concept_code
				WHERE (r1.numerator_value / COALESCE(r1.denominator_value, 1)) / (r2.numerator_value / COALESCE(r2.denominator_value, 1)) BETWEEN 1 / 1.05 AND 1.05
				)

	SELECT s1.*
	FROM (
		SELECT DISTINCT ON (s0.rxe_code) s0.rxe_code AS concept_code_1,
			'RxNorm Extension' AS vocabulary_id_1,
			s0.rxn_code AS concept_code_2,
			'RxNorm' AS vocabulary_id_2
		FROM (
			SELECT DISTINCT rxe_code,
				rxn_code,
				concept_name,
				valid_start_date,
				i_count,
				MAX(imprecision) OVER (
					PARTITION BY rxe_code,
					rxn_code
					) AS imprecision
			FROM any_match_a
			WHERE i_count = matches_per_pair
			
			UNION ALL
			
			SELECT DISTINCT rxe_code,
				rxn_code,
				concept_name,
				valid_start_date,
				i_count,
				MAX(imprecision) OVER (
					PARTITION BY rxe_code,
					rxn_code
					) AS imprecision
			FROM any_match_nd
			WHERE i_count = matches_per_pair
			) AS s0
		ORDER BY s0.rxe_code, --filter out better matches
			s0.imprecision,
			s0.valid_start_date,
			LENGTH(s0.concept_name),
			s0.concept_name
		) AS s1

	UNION ALL

	SELECT rxe_code AS concept_code_1,
		'RxNorm Extension' AS vocabulary_id_1,
		rx_code AS concept_code_2,
		'RxNorm' AS vocabulary_id_2
	FROM atom_replacement;

	--4. Load full list of RxNorm Extension concepts and set 'X' for duplicates
	INSERT INTO concept_stage
	SELECT *
	FROM concept
	WHERE vocabulary_id = 'RxNorm Extension';
	ANALYZE concept_stage;

	UPDATE concept_stage cs
	SET invalid_reason = 'X',
		standard_concept = NULL,
		valid_end_date = CURRENT_DATE,
		concept_id = c.concept_id
	FROM concept_replacement_full crf
	JOIN concept c ON c.concept_code = crf.concept_code_1
		AND c.vocabulary_id = crf.vocabulary_id_1
	WHERE crf.concept_code_1 = cs.concept_code
		AND crf.vocabulary_id_1 = cs.vocabulary_id;

	--5. Load full list of RxNorm Extension relationships
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
		AND r.invalid_reason IS NULL;

	--6. Deprecate old relationships
	UPDATE concept_relationship_stage crs
	SET invalid_reason = 'D',
		valid_end_date = CURRENT_DATE
	FROM concept_stage cs
	WHERE cs.concept_code IN (
			crs.concept_code_1,
			crs.concept_code_2
			) --with reverse
		AND cs.invalid_reason = 'X';

	--7. Add new replacements
	INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date
		)
	SELECT crf.concept_code_1,
		crf.concept_code_2,
		crf.vocabulary_id_1,
		crf.vocabulary_id_2,
		'Concept replaced by' AS relationship_id,
		CURRENT_DATE AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd')
	FROM concept_replacement_full crf
	--prevent dublicates
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			WHERE crs_int.concept_code_1 IN (
					crf.concept_code_1,
					crf.concept_code_2
					)
				AND crs_int.concept_code_2 IN (
					crf.concept_code_1,
					crf.concept_code_2
					)
				AND crs_int.vocabulary_id_1 IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND crs_int.vocabulary_id_2 IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND crs_int.relationship_id IN (
					'Concept replaced by',
					'Concept replaces'
					)
			);

	--8. Update concept_stage (set 'U' for all 'X')
	UPDATE concept_stage
	SET invalid_reason = 'U'
	WHERE invalid_reason = 'X';

	--9. RxNorm concepts steal all relations from RxE concepts they replace
	WITH full_replace
	AS (
		SELECT concept_code_1,
			vocabulary_id_1,
			concept_code_2,
			vocabulary_id_2
		FROM concept_replacement_full
		
		UNION ALL
		
		SELECT c.concept_code,
			c.vocabulary_id,
			c2.concept_code,
			c2.vocabulary_id
		FROM concept_relationship r
		JOIN concept c ON c.concept_id = r.concept_id_1
			AND c.vocabulary_id = 'RxNorm Extension'
		JOIN concept c2 ON c2.concept_id = r.concept_id_2
			AND c2.vocabulary_id = 'RxNorm'
		LEFT JOIN concept_replacement_full crf ON crf.concept_code_1 = c.concept_code
			AND crf.vocabulary_id_1 = c.vocabulary_id
			AND crf.concept_code_2 = c2.concept_code
			AND crf.vocabulary_id_2 = c2.vocabulary_id
		WHERE crf.concept_code_1 IS NULL
			AND r.relationship_id = 'Concept replaced by'
			AND r.invalid_reason IS NULL
		),
	--replaced RxE concepts lose all relations that are not Maps to or Concept replaced by
	deprecate_old_rxe_rels
	AS (
		UPDATE concept_relationship_stage crs
		SET invalid_reason = 'D',
			valid_end_date = CURRENT_DATE - 1
		FROM full_replace f
		WHERE f.concept_code_1 = crs.concept_code_1
			AND f.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs.invalid_reason IS NULL
			AND crs.relationship_id NOT IN (
				'Maps to',
				'Concept replaced by'
				)
		),
	--same as above, bu reverse
	deprecate_old_rxe_rels2
	AS (
		UPDATE concept_relationship_stage crs
		SET invalid_reason = 'D',
			valid_end_date = CURRENT_DATE - 1
		FROM full_replace f
		WHERE f.concept_code_1 = crs.concept_code_2
			AND f.vocabulary_id_1 = crs.vocabulary_id_2
			AND crs.invalid_reason IS NULL
			AND crs.relationship_id NOT IN (
				'Mapped from',
				'Concept replaces'
				)
		)
	--get and insert all active relations to RxE concepts
	INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date
		)
	SELECT DISTINCT fr.concept_code_2 AS concept_code_1,
		t.concept_code AS concept_code_2,
		fr.vocabulary_id_2 AS vocabulary_id_1,
		t.vocabulary_id AS vocabulary_id_2,
		cr.relationship_id,
		CURRENT_DATE AS valid_start_date,
		cr.valid_end_date
	FROM full_replace fr
	JOIN concept c ON c.vocabulary_id = fr.vocabulary_id_1
		AND c.concept_code = fr.concept_code_1
	JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
		AND cr.invalid_reason IS NULL
	JOIN concept t ON t.concept_id = cr.concept_id_2
	LEFT JOIN full_replace fr2 ON fr2.concept_code_1 = t.concept_code
		AND fr2.vocabulary_id_1 = t.vocabulary_id
	WHERE fr2.concept_code_1 IS NULL
		AND (
			t.vocabulary_id = 'RxNorm Extension'
			--all active mapped from and rx-source eq relations to other vocabs
			OR (
				cr.relationship_id IN (
					'Mapped from',
					'RxNorm - Source eq'
					)
				AND t.vocabulary_id <> 'RxNorm Extension'
				)
			)
		--prevent dublicates
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			WHERE crs_int.concept_code_1 = fr.concept_code_2
				AND crs_int.vocabulary_id_1 = fr.vocabulary_id_2
				AND crs_int.concept_code_2 = t.concept_code
				AND crs_int.vocabulary_id_2 = t.vocabulary_id
				AND crs_int.relationship_id = cr.relationship_id
			)
		--reverse for dublicates
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			JOIN relationship r ON r.relationship_id = cr.relationship_id
			WHERE crs_int.concept_code_1 = t.concept_code
				AND crs_int.vocabulary_id_1 = t.vocabulary_id
				AND crs_int.concept_code_2 = fr.concept_code_2
				AND crs_int.vocabulary_id_2 = fr.vocabulary_id_2
				AND crs_int.relationship_id = r.reverse_relationship_id
			);

	--10. Working with replacement mappings
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.CheckReplacementMappings();
	END $_$;

	--11. Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	END $_$;
	
	--12. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
	END $_$;

	--13. AddFreshMAPSTO creates RxNorm(ATC)-RxNorm links that need to be removed
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

	--14. Fill concept_synonym_stage
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
$BODY$
LANGUAGE 'plpgsql' SECURITY INVOKER;

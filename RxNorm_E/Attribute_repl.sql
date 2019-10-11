--Creating manual table with concept_code_1 representing attribute (Brand Name,Supplier, Dose Form) that you want to replace by another already existing one (concept_code_2)
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT cr1.concept_code_2,
	cr2.concept_code_2,
	cr1.vocabulary_id_2,
	cr2.vocabulary_id_2,
	'Concept replaced by',
	cr1.valid_start_date,
	cr1.valid_end_date
FROM suppliers_to_repl s
JOIN concept_relationship_stage cr1 ON s.concept_code_1 = cr1.concept_code_1
	AND cr1.relationship_id = 'Source - RxNorm eq'
JOIN concept_relationship_stage cr2 ON s.concept_code_2 = cr2.concept_code_1
	AND cr2.relationship_id = 'Source - RxNorm eq';

UPDATE concept_stage
SET invalid_reason = 'U',
	valid_end_date = CURRENT_DATE
WHERE concept_code IN (
		SELECT cr1.concept_code_2
		FROM suppliers_to_repl s
		JOIN concept_relationship_stage cr1 ON s.concept_code_1 = cr1.concept_code_1
			AND cr1.relationship_id = 'Source - RxNorm eq'
		);

--brand
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT cr1.concept_code_2,
	cr2.concept_code_2,
	cr1.vocabulary_id_2,
	cr2.vocabulary_id_2,
	'Concept replaced by',
	cr1.valid_start_date,
	cr1.valid_end_date
FROM bn_to_repl s
JOIN concept_relationship_stage cr1 ON s.concept_code_1 = cr1.concept_code_1
	AND cr1.relationship_id = 'Source - RxNorm eq'
JOIN concept_relationship_stage cr2 ON s.concept_code_2 = cr2.concept_code_1
	AND cr2.relationship_id = 'Source - RxNorm eq';

UPDATE concept_stage
SET invalid_reason = 'U',
	valid_end_date = CURRENT_DATE
WHERE concept_code IN (
		SELECT cr1.concept_code_2
		FROM bn_to_repl s
		JOIN concept_relationship_stage cr1 ON s.concept_code_1 = cr1.concept_code_1
			AND cr1.relationship_id = 'Source - RxNorm eq'
		);
		
--ingredient
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT cr1.concept_code,
	cr2.concept_code,
	'RxNorm Extension',
	cr2.vocabulary_id,
	'Concept replaced by',
	cr1.valid_start_date,
	to_date('20991231','YYYYMMDD')
FROM ingredient_to_replace s -- different way, as there are no Source - RxNorm eq
JOIN devv5.concept cr1 ON s.concept_code_1 = cr1.concept_code and cr1.vocabulary_id like 'Rx%'
JOIN devv5.concept cr2 ON s.concept_code_2 = cr2.concept_code and cr2.vocabulary_id like 'Rx%'
	;

UPDATE concept_stage
SET invalid_reason = 'U',
	valid_end_date = CURRENT_DATE
WHERE concept_code IN (
		SELECT concept_code_1
		FROM ingredient_to_replace  s
		);
		
-- dose form
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT cr1.concept_code_2,
	cr2.concept_code_2,
	cr1.vocabulary_id_2,
	cr2.vocabulary_id_2,
	'Concept replaced by',
	cr1.valid_start_date,
	cr1.valid_end_date
FROM dose_form_to_replace  s
JOIN concept_relationship_stage cr1 ON s.concept_code_1 = cr1.concept_code_1
	AND cr1.relationship_id = 'Source - RxNorm eq'
JOIN concept_relationship_stage cr2 ON s.concept_code_2 = cr2.concept_code_1
	AND cr2.relationship_id = 'Source - RxNorm eq';

UPDATE concept_stage
SET invalid_reason = 'U',
	valid_end_date = CURRENT_DATE
WHERE concept_code IN (
		SELECT cr1.concept_code_2
		FROM dose_form_to_replace  s
		JOIN concept_relationship_stage cr1 ON s.concept_code_1 = cr1.concept_code_1
			AND cr1.relationship_id = 'Source - RxNorm eq'
		);

--create temporary table with old mappings and fresh concepts (after all 'Concept replaced by')
DROP TABLE IF EXISTS rxe_tmp_replaces;
CREATE TABLE rxe_tmp_replaces AS
	WITH src_codes AS (
			--get concepts and all their links, which targets to 'U'
			SELECT crs.concept_code_2 AS src_code,
				crs.vocabulary_id_2 AS src_vocab,
				cs.concept_code upd_code,
				cs.vocabulary_id upd_vocab,
				cs.concept_class_id upd_class_id,
				crs.relationship_id src_rel
			FROM concept_stage cs,
				concept_relationship_stage crs
			WHERE cs.concept_code = crs.concept_code_1
				AND cs.vocabulary_id = crs.vocabulary_id_2
				AND cs.invalid_reason = 'U'
				AND cs.vocabulary_id = 'RxNorm Extension'
				AND crs.invalid_reason IS NULL
				AND crs.relationship_id NOT IN (
					'Concept replaced by',
					'Concept replaces'
					)
			),
		fresh_codes AS (
			--get all fresh concepts (with recursion until the last fresh)
			WITH RECURSIVE hierarchy_concepts(ancestor_concept_code, ancestor_vocabulary_id, descendant_concept_code, descendant_vocabulary_id, root_ancestor_concept_code, root_ancestor_vocabulary_id, full_path) AS (
					SELECT ancestor_concept_code,
						ancestor_vocabulary_id,
						descendant_concept_code,
						descendant_vocabulary_id,
						ancestor_concept_code AS root_ancestor_concept_code,
						ancestor_vocabulary_id AS root_ancestor_vocabulary_id,
						ARRAY [ROW (descendant_concept_code, descendant_vocabulary_id)] AS full_path
					FROM concepts
					
					UNION ALL
					
					SELECT c.ancestor_concept_code,
						c.ancestor_vocabulary_id,
						c.descendant_concept_code,
						c.descendant_vocabulary_id,
						root_ancestor_concept_code,
						root_ancestor_vocabulary_id,
						hc.full_path || ROW(c.descendant_concept_code, c.descendant_vocabulary_id) AS full_path
					FROM concepts c
					JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
						AND hc.descendant_vocabulary_id = c.ancestor_vocabulary_id
					WHERE ROW(c.descendant_concept_code, c.descendant_vocabulary_id) <> ALL (full_path)
					),
				concepts AS (
					SELECT concept_code_1 AS ancestor_concept_code,
						vocabulary_id_1 AS ancestor_vocabulary_id,
						concept_code_2 AS descendant_concept_code,
						vocabulary_id_2 AS descendant_vocabulary_id
					FROM concept_relationship_stage crs
					WHERE crs.relationship_id = 'Concept replaced by'
						AND crs.invalid_reason IS NULL
					)
			SELECT DISTINCT hc.root_ancestor_concept_code AS upd_code,
				hc.root_ancestor_vocabulary_id AS upd_vocab,
				hc.descendant_concept_code AS new_code,
				hc.descendant_vocabulary_id AS new_vocab
			FROM hierarchy_concepts hc
			WHERE NOT EXISTS (
					/*same as oracle's CONNECT_BY_ISLEAF*/
					SELECT 1
					FROM hierarchy_concepts hc_int
					WHERE hc_int.ancestor_concept_code = hc.descendant_concept_code
						AND hc_int.ancestor_vocabulary_id = hc.descendant_vocabulary_id
					)
			)

SELECT src.src_code,
	src.src_vocab,
	src.upd_code,
	src.upd_vocab,
	src.upd_class_id,
	src.src_rel,
	fr.new_code,
	fr.new_vocab
FROM src_codes src,
	fresh_codes fr
WHERE src.upd_code = fr.upd_code
	AND src.upd_vocab = fr.upd_vocab
	AND NOT (
		src.src_vocab = 'RxNorm'
		AND fr.new_vocab = 'RxNorm'
		);

--deprecate old relationships
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		crs.concept_code_2,
		crs.vocabulary_id_2,
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.relationship_id
		) IN (
		SELECT r.src_code,
			r.src_vocab,
			r.upd_code,
			r.upd_vocab,
			r.src_rel
		FROM rxe_tmp_replaces r
		WHERE r.upd_class_id IN (
				'Brand Name',
				'Ingredient',
				'Supplier',
				'Dose Form'
				)
		);

--build new ones relationships or update existing
UPDATE concept_relationship_stage crs
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'YYYYMMDD')
FROM (
	SELECT *
	FROM rxe_tmp_replaces r
	WHERE r.upd_class_id IN (
			'Brand Name',
			'Ingredient',
			'Supplier',
			'Dose Form'
			)
	) i
WHERE i.src_code = crs.concept_code_2
	AND i.src_vocab = crs.vocabulary_id_2
	AND i.new_code = crs.concept_code_1
	AND i.new_vocab = crs.vocabulary_id_1
	AND i.src_rel = crs.relationship_id
	AND crs.invalid_reason IS NOT NULL;

INSERT INTO concept_relationship_stage (
	concept_code_2,
	vocabulary_id_2,
	concept_code_1,
	vocabulary_id_1,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT i.src_code,
	i.src_vocab,
	i.new_code,
	i.new_vocab,
	i.src_rel,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	to_date('20991231', 'YYYYMMDD'),
	NULL
FROM (
	SELECT *
	FROM rxe_tmp_replaces r
	WHERE r.upd_class_id IN (
			'Brand Name',
			'Ingredient',
			'Supplier',
			'Dose Form'
			)
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE i.src_code = crs_int.concept_code_2
			AND i.src_vocab = crs_int.vocabulary_id_2
			AND i.new_code = crs_int.concept_code_1
			AND i.new_vocab = crs_int.vocabulary_id_1
			AND i.src_rel = crs_int.relationship_id
		);

--get duplicates for some reason
DELETE
FROM concept_relationship_stage i
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage i_int
		WHERE i_int.concept_code_1 = i.concept_code_1
			AND i_int.concept_code_2 = i.concept_code_2
			AND i_int.vocabulary_id_1 = i.vocabulary_id_1
			AND i_int.vocabulary_id_2 = i.vocabulary_id_2
			AND i_int.relationship_id = i.relationship_id
			AND i_int.ctid > i.ctid
		);

DROP TABLE rxe_tmp_replaces;

-- Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

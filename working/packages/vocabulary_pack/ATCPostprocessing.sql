CREATE OR REPLACE FUNCTION vocabulary_pack.ATCPostProcessing (
)
RETURNS void AS
$BODY$
BEGIN
	/*
	postprocessing for ATC
	*/
	--1. Create jumps
	--1a. Use sources.class_to_drug, avoid Packs
	DROP TABLE IF EXISTS jump$;
	CREATE UNLOGGED TABLE jump$ as
	SELECT s0.class_id,
		s0.rx_id,
		s0.o
	FROM (
		SELECT DISTINCT c.concept_id AS class_id,
			cd.concept_id AS rx_id,
			rx.vocabulary_id,
			cd.concept_order AS o,
			DENSE_RANK() OVER (
				PARTITION BY cd.concept_id ORDER BY cd.concept_order
				) AS rn
		FROM dev_atc.class_to_drug cd
		JOIN concept c ON cd.class_code = c.concept_code
			AND c.vocabulary_id = 'ATC'
		JOIN concept rx ON rx.concept_id = cd.concept_id
			AND rx.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND rx.concept_class_id <> 'Ingredient'
			AND rx.concept_class_id NOT IN (
				'Ingredient',
				'Clinical Pack',
				'Clinical Pack Box',
				'Branded Pack',
				'Branded Pack Box'
				)
		) AS s0
	WHERE s0.rn = 1;--only pick the records with the lowest order value per concept_id and select jumps arriving on those

	--2. Create steps
	--2a. Start directly from concept_relationship through relationship_id
	DROP TABLE IF EXISTS step$;
	CREATE UNLOGGED TABLE step$ AS
	--Get the explicit relationships first, because the implicit are less reliable - if only one jump classes cannot be distinguished from individual ingredients
	SELECT c.concept_id AS class_id,
		rx.concept_id AS rx_id,
		CASE r.relationship_id --categorical have a step of one, the rest of
			WHEN 'ATC - RxNorm pr up'
				THEN 1
			WHEN 'ATC - RxNorm sec up'
				THEN 1
			ELSE 0
			END AS inc,
		CASE r.relationship_id --if primary
			WHEN 'ATC - RxNorm pr up'
				THEN 1
			WHEN 'ATC - RxNorm pr lat'
				THEN 1
			ELSE 0
			END AS prim
	FROM concept_relationship r
	JOIN concept c ON r.concept_id_1 = c.concept_id
		AND c.vocabulary_id = 'ATC'
	JOIN concept rx ON r.concept_id_2 = rx.concept_id
		AND rx.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			)
		AND rx.concept_class_id = 'Ingredient'
	WHERE r.relationship_id IN (
			'ATC - RxNorm pr lat',
			'ATC - RxNorm pr up',
			'ATC - RxNorm sec lat',
			'ATC - RxNorm sec up'
			)
		AND r.invalid_reason IS NULL;

	--2b. Get all the indirect relationships and their increment. Shouldn't find any, since all ingredients are now in concept_relationship
	INSERT INTO step$
	WITH indirect AS (
			--create all ingredients derived from jumps
			SELECT c.concept_id AS class_id,
				rx.concept_id AS rx_id,
				r.concept_id_2
			FROM concept_relationship r
			JOIN concept c ON r.concept_id_1 = c.concept_id
				AND vocabulary_id = 'ATC'
			JOIN concept_ancestor_rx$ ca ON ca.descendant_concept_id = concept_id_2 --move up the hierarchy to the ingredients
			JOIN concept rx ON ca.ancestor_concept_id = rx.concept_id
				AND rx.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND rx.concept_class_id = 'Ingredient'
			WHERE r.relationship_id = 'ATC - RxNorm'
				AND r.invalid_reason IS NULL
			)
	SELECT DISTINCT i.class_id,
		i.rx_id,
		CASE ii.ings
			WHEN j.jumps
				THEN 0
			ELSE 1
			END AS inc,
		0 AS prim
	FROM indirect i
	JOIN (
		SELECT class_id,
			COUNT(*) AS jumps
		FROM (
			SELECT DISTINCT class_id,
				concept_id_2
			FROM indirect
			) distinct_i
		GROUP BY class_id
		) j ON j.class_id = i.class_id
	JOIN (
		SELECT class_id,
			rx_id,
			COUNT(*) AS ings
		FROM indirect
		GROUP BY class_id,
			rx_id
		) ii ON ii.class_id = i.class_id
		AND ii.rx_id = i.rx_id
	WHERE NOT EXISTS (
			SELECT 1
			FROM step$ s
			WHERE i.class_id = s.class_id
			);--if no explicit steps defined


	/****************************
	Scenarios for various ATCs
	****************************/
	--0. Undefined
	--1. ATC Combination of ingredient A + ingredient B
	--2. ATC Combination of ingredient A + group B
	--3. ATC Combination of group A + group B
	--4. ATC Combinations of ingredients within group A
	--5. ATC Single ingredient A - form exists
	--6. ATC Single ingredient A - default (no form specified or a unique ingredient)

	--3. Collect scenarios
	--3a. Collect defined scenarios

	DROP TABLE IF EXISTS scenario$;
	CREATE UNLOGGED TABLE scenario$ AS
	--Scenario 1
	SELECT c.concept_id AS class_id,
		c.concept_code AS class_code,
		1 AS s
	FROM concept c
	WHERE c.vocabulary_id = 'ATC'
		AND c.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm pr lat'
				AND r.invalid_reason IS NULL
			)
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm sec lat'
				AND r.invalid_reason IS NULL
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id IN (
					'ATC - RxNorm sec up',
					'ATC - RxNorm pr up'
					)
				AND r.invalid_reason IS NULL
			)

	UNION ALL

	--Scenario 2
	SELECT c.concept_id AS class_id,
		c.concept_code AS class_code,
		2 AS s
	FROM concept c
	WHERE c.vocabulary_id = 'ATC'
		AND c.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm pr lat'
				AND r.invalid_reason IS NULL
			)
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm sec up'
				AND r.invalid_reason IS NULL
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id IN (
					'ATC - RxNorm sec lat',
					'ATC - RxNorm pr up'
					)
				AND r.invalid_reason IS NULL
			)

	UNION ALL

	--Scenario 3
	SELECT c.concept_id AS class_id,
		c.concept_code AS class_code,
		3 AS s
	FROM concept c
	WHERE c.vocabulary_id = 'ATC'
		AND c.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm pr up'
				AND r.invalid_reason IS NULL
			)
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm sec up'
				AND r.invalid_reason IS NULL
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id IN (
					'ATC - RxNorm sec lat',
					'ATC - RxNorm pr lat'
					)
				AND r.invalid_reason IS NULL
			)

	UNION ALL

	--Scenario 4
	SELECT c.concept_id AS class_id,
		c.concept_code AS class_code,
		4 AS s
	FROM concept c
	WHERE c.vocabulary_id = 'ATC'
		AND c.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm pr up'
				AND r.invalid_reason IS NULL
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id IN (
					'ATC - RxNorm sec up',
					'ATC - RxNorm sec lat',
					'ATC - RxNorm pr lat'
					)
				AND r.invalid_reason IS NULL
			)

	UNION ALL

	--Scenario 5: ATC with forms
	SELECT c.concept_id AS class_id,
		c.concept_code AS class_code,
		5 AS s
	FROM concept c
	WHERE c.vocabulary_id = 'ATC'
		AND c.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm pr lat'
				AND r.invalid_reason IS NULL
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id IN (
					'ATC - RxNorm sec up',
					'ATC - RxNorm sec lat',
					'ATC - RxNorm pr up'
					)
				AND r.invalid_reason IS NULL
			)
		AND EXISTS (
			SELECT 1
			FROM jump$ j
			WHERE j.class_id = c.concept_id
			) --select only those where real jumps exists, ingredients go to scenario 6

	UNION ALL

	--Scenario 6: default
	SELECT c.concept_id AS class_id,
		c.concept_code AS class_code,
		6 AS s
	FROM concept c
	WHERE c.vocabulary_id = 'ATC'
		AND c.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id = 'ATC - RxNorm pr lat'
				AND r.invalid_reason IS NULL
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.relationship_id IN (
					'ATC - RxNorm sec up',
					'ATC - RxNorm sec lat',
					'ATC - RxNorm pr up'
					)
				AND r.invalid_reason IS NULL
			)
		AND EXISTS (
			SELECT 1
			FROM dev_atc.class_to_drug d
			WHERE d.class_code = c.concept_code
				AND d.concept_class_id = 'Ingredient'
			); --only default where ATC explicitly does not assume a drug form or an ingredient is unique

	--3b. Pick up all the rest: Scenario 0
	INSERT INTO scenario$
	SELECT c.concept_id AS class_id,
		c.concept_code AS class_code,
		0 AS s
	FROM concept c
	WHERE c.concept_class_id = 'ATC 5th'
		AND c.vocabulary_id = 'ATC'
		AND c.invalid_reason IS NULL
		AND NOT EXISTS (
			SELECT 1
			FROM scenario$ s
			WHERE s.class_id = c.concept_id
			);

	--4. Build ancestry. Start building from ATC5 to RxN, then upwards ATC
	--4a. Add steps first: ATC to Ingredients
	DROP TABLE IF EXISTS concept_ancestor_add$; --use separate table to build successively and for speed
	CREATE UNLOGGED TABLE concept_ancestor_add$ AS
	SELECT s.class_id AS ancestor_concept_id,
		s.rx_id AS descendant_concept_id,
		MIN(s.inc) AS min_levels_of_separation,
		MAX(s.inc) AS max_levels_of_separation,
		MAX(s.prim) AS prim --primary ingredient or not. If there are both pick primary
	FROM step$ s
	GROUP BY s.class_id,
		s.rx_id;

	--4b. Connect step to jump including jump, picking up mostly clinical drug forms leading to branded drug forms in addition to jumps
	INSERT INTO concept_ancestor_add$
	SELECT caa.ancestor_concept_id,
		c.concept_id AS descendant_concept_id,
		MIN(caa.min_levels_of_separation + ca1.min_levels_of_separation) AS min_levels_of_separation,
		MAX(caa.max_levels_of_separation + ca1.max_levels_of_separation) AS max_levels_of_separation,
		CASE concept_class_id
			WHEN 'Clinical Drug Comp'
				THEN MAX(prim)
			ELSE 1
			END AS prim -- only relevant for ingredient and clin drug comp
	FROM concept_ancestor_add$ caa --so far only steps
	JOIN concept_ancestor_rx$ ca1 ON caa.descendant_concept_id = ca1.ancestor_concept_id
		AND ca1.ancestor_concept_id <> ca1.descendant_concept_id --first leg
	JOIN concept c ON c.concept_id = ca1.descendant_concept_id
		AND c.concept_class_id NOT IN (
			'Branded Dose Group',
			'Clinical Dose Group'
			)
	JOIN concept_ancestor_rx$ ca2 ON ca1.descendant_concept_id = ca2.ancestor_concept_id --and ca2.ancestor_concept_id<>ca2.descendant_concept_id --second leg
	JOIN jump$ j ON j.class_id = caa.ancestor_concept_id
		AND j.rx_id = ca2.descendant_concept_id --close loop
		--where concept_id=40003695 --doxylamine, combinations; systemic
	GROUP BY caa.ancestor_concept_id,
		c.concept_id;

	--4c. Continue downwards from jump, including directly included packs containing drugs that are direct descendants. Not the ones where combos are formed through a pack only
	INSERT INTO concept_ancestor_add$
	SELECT ancestor_concept_id,
		descendant_concept_id,
		min_levels_of_separation,
		max_levels_of_separation,
		1 AS prim
	FROM (
		SELECT caa.ancestor_concept_id,
			ca.descendant_concept_id,
			o,
			MIN(caa.min_levels_of_separation + ca.min_levels_of_separation) AS min_levels_of_separation,
			MAX(caa.max_levels_of_separation + ca.max_levels_of_separation) AS max_levels_of_separation,
			dense_rank() OVER (
				PARTITION BY ca.descendant_concept_id ORDER BY o
				) AS rn
		FROM jump$ j
		JOIN concept_ancestor_add$ caa ON j.class_id = caa.ancestor_concept_id
			AND rx_id = caa.descendant_concept_id --parallel to jump, but with min and max levels
		JOIN concept_ancestor_rx$ ca ON ca.ancestor_concept_id = caa.descendant_concept_id
			AND ca.ancestor_concept_id <> ca.descendant_concept_id --continue downwards
		GROUP BY caa.ancestor_concept_id,
			ca.descendant_concept_id,
			o
		) AS s0
	WHERE rn = 1;--have the j_ext survive with the lowest o for each descendant

	--4d. Add second road between ATC5 and descendants from above (usually parallel Drug Comps to Drug Forms)
	INSERT INTO concept_ancestor_add$
	SELECT caa.ancestor_concept_id,
		ca1.descendant_concept_id,
		MIN(s.inc + ca1.min_levels_of_separation) AS min_levels_of_separation,
		MIN(s.inc + ca1.max_levels_of_separation) AS max_levels_of_separation,
		CASE concept_class_id
			WHEN 'Clinical Drug Comp'
				THEN MAX(s.prim)
			ELSE 1
			END AS prim --only relevant for ingredient and clin drug comp
	FROM concept_ancestor_add$ caa
	JOIN step$ s ON s.class_id = caa.ancestor_concept_id
	JOIN concept_ancestor_rx$ ca1 ON ca1.ancestor_concept_id = s.rx_id
		AND ca1.ancestor_concept_id <> ca1.descendant_concept_id --first leg
	JOIN concept_ancestor_rx$ ca2 ON ca2.ancestor_concept_id = ca1.descendant_concept_id
		AND ca2.descendant_concept_id = caa.descendant_concept_id --second leg
		AND ca2.ancestor_concept_id <> ca2.descendant_concept_id
	JOIN concept c ON c.concept_id = ca1.descendant_concept_id
		AND c.concept_class_id NOT IN (
			'Clinical Dose Group',
			'Branded Dose Group'
			)
	--triangle exists, but first leg is missing so far
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_ancestor_add$ cae
			WHERE cae.ancestor_concept_id = s.class_id
				AND cae.descendant_concept_id = ca1.descendant_concept_id
			)
	    and not exists
        (
            SELECT 1
            FROM concept_relationship cr
            WHERE  caa.ancestor_concept_id = cr.concept_id_1
                    and cr.relationship_id = 'ATC - RxNorm'
                    and ca1.descendant_concept_id = cr.concept_id_2
                    and cr.invalid_reason is not null
        )
	GROUP BY caa.ancestor_concept_id,
		ca1.descendant_concept_id,
		concept_class_id;

	--4e. Connect step down for scenario 6 (default ingredients) and 0 (missing)
	INSERT INTO concept_ancestor_add$
	SELECT caa.ancestor_concept_id,
		ca.descendant_concept_id,
		MIN(caa.min_levels_of_separation + ca.min_levels_of_separation) AS min_levels_of_separation,
		MAX(caa.max_levels_of_separation + ca.max_levels_of_separation) AS max_levels_of_separation,
		CASE concept_class_id
			WHEN 'Clinical Drug Comp'
				THEN MAX(prim)
			ELSE 1
			END AS prim --only relevant for ingredient and clin drug comp
	FROM concept_ancestor_add$ caa
	JOIN concept_ancestor_rx$ ca ON caa.descendant_concept_id = ca.ancestor_concept_id
		AND ca.ancestor_concept_id <> ca.descendant_concept_id --continue down
	JOIN concept c ON c.concept_id = ca.descendant_concept_id
		AND c.concept_class_id NOT IN (
			'Branded Dose Group',
			'Clinical Dose Group'
			)
	JOIN scenario$ sc ON sc.class_id = caa.ancestor_concept_id
	WHERE NOT EXISTS (
			SELECT 1
			FROM jump$ j
			WHERE j.class_id = caa.ancestor_concept_id
			) --no jumps, only steps.
		AND NOT EXISTS (
			SELECT 1
			FROM concept_ancestor_add$ c
			WHERE c.descendant_concept_id = ca.descendant_concept_id
			) --if already reached through jump
		AND sc.s = 6 --the default scenarios, if no jumps defined then because RxE doesn't have such drugs
	GROUP BY caa.ancestor_concept_id,
		ca.descendant_concept_id,
		concept_class_id;

	--5. Add those combos that result from combining ingredients in pack
	--5a. Create pack-specific jumps
	CREATE INDEX idx_temp_ca_add$ ON concept_ancestor_add$ (ancestor_concept_id,descendant_concept_id);
	ANALYZE concept_ancestor_add$;

	DROP TABLE IF EXISTS jump_pack$;
	CREATE UNLOGGED TABLE jump_pack$ AS
	SELECT s0.class_id,
		s0.rx_id,
		s0.o
	FROM (
		SELECT --for each order of precedence
			DISTINCT c.concept_id AS class_id,
			cd.concept_id AS rx_id,
			cd.concept_order AS o,
			DENSE_RANK() OVER (
				PARTITION BY cd.concept_id ORDER BY cd.concept_order
				) AS rn
		FROM dev_atc.class_to_drug cd
		JOIN concept c ON cd.class_code = c.concept_code
			AND c.vocabulary_id = 'ATC'
		JOIN concept rx ON rx.concept_id = cd.concept_id
			AND rx.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND rx.concept_class_id IN (
				'Clinical Pack',
				'Clinical Pack Box',
				'Branded Pack',
				'Branded Pack Box'
				)
		WHERE NOT EXISTS (
				SELECT 1
				FROM concept_ancestor_add$
				WHERE ancestor_concept_id = c.concept_id
					AND descendant_concept_id = rx.concept_id
				)
		) AS s0
	WHERE s0.rn = 1;--but only pick the records with the lowest order value per concept_id and select jumps arriving on those

	--5b. Add Clinical Drug Comp (which behave like Ingredients), the others don't follow the combo logic
	INSERT INTO concept_ancestor_add$
	SELECT jp.class_id AS ancestor_concept_id,
		ca1.descendant_concept_id,
		MIN(s.inc + ca1.min_levels_of_separation) AS min_levels_of_separation,
		MAX(s.inc + ca1.max_levels_of_separation) AS max_levels_of_separation,
		MAX(s.prim) AS prim
	FROM jump_pack$ jp
	JOIN step$ s ON s.class_id = jp.class_id
	JOIN concept_ancestor_rx$ ca1 ON s.rx_id = ca1.ancestor_concept_id --for min and max
	JOIN concept ON concept_id = ca1.descendant_concept_id
		AND concept_class_id = 'Clinical Drug Comp' --only
	JOIN concept_ancestor_rx$ ca2 ON ca2.ancestor_concept_id = ca1.descendant_concept_id --continue downwards
		AND ca2.descendant_concept_id = jp.rx_id --close the loop
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_ancestor_add$ caa
			WHERE caa.ancestor_concept_id = jp.class_id
				AND caa.descendant_concept_id = ca1.descendant_concept_id
			)
	GROUP BY jp.class_id,
		ca1.descendant_concept_id;

	--5c. Add jump_pack and continue downwards
	INSERT INTO concept_ancestor_add$
	SELECT jp.class_id AS ancestor_concept_id,
		ca2.descendant_concept_id,
		MIN(s.inc + ca1.min_levels_of_separation + ca2.min_levels_of_separation) AS min_levels_of_separation,
		MAX(s.inc + ca1.max_levels_of_separation + ca2.max_levels_of_separation) AS max_levels_of_separation,
		1 AS prim
	FROM jump_pack$ jp
	JOIN step$ s ON s.class_id = jp.class_id --for min and max
	JOIN concept_ancestor_rx$ ca1 ON s.rx_id = ca1.ancestor_concept_id --for min and max
		AND ca1.descendant_concept_id = jp.rx_id --close the loop
	JOIN concept_ancestor_rx$ ca2 ON ca2.ancestor_concept_id = ca1.descendant_concept_id --continue downwards, allow ancestor=descendent so jump is added also
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_ancestor_add$ caa
			WHERE caa.ancestor_concept_id = jp.class_id
				AND caa.descendant_concept_id = ca2.descendant_concept_id
			)
	GROUP BY jp.class_id,
		ca2.descendant_concept_id;

	--6. Add ATCs step by step, using "Subsumes"
	--6a. If ATC4 is also a combination then extend all from ATC5, otherwise only primary Ingredients and Clinical Drug Comps
	INSERT INTO concept_ancestor_add$
	SELECT c.concept_id AS ancestor_concept_id,
		caa.descendant_concept_id,
		MIN(caa.min_levels_of_separation) + 1 AS min_levels_of_separation,
		MAX(caa.max_levels_of_separation) + 1 AS max_levels_of_separation,
		MAX(caa.prim) AS prim --continue upwards, primary trump secondary ingredients (but each should only have one anyway)
	FROM concept c
	JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
		AND r.invalid_reason IS NULL
		AND r.relationship_id = 'Subsumes'
	JOIN concept_ancestor_add$ caa ON caa.ancestor_concept_id = r.concept_id_2
	WHERE c.vocabulary_id = 'ATC'
		AND c.concept_class_id = 'ATC 4th'
		AND c.invalid_reason IS NULL
		AND (
			c.concept_name ~* ' and |comb| with'
			OR caa.prim = 1
			)
	GROUP BY c.concept_id,
		caa.descendant_concept_id;

	ANALYZE concept_ancestor_add$;

	--6b. Add ATC3: Same as the addition of ATC4
	INSERT INTO concept_ancestor_add$
	SELECT c.concept_id AS ancestor_concept_id,
		caa.descendant_concept_id,
		MIN(caa.min_levels_of_separation) + 1 AS min_levels_of_separation,
		MAX(caa.max_levels_of_separation) + 1 AS max_levels_of_separation,
		MAX(caa.prim) AS prim --continue upwards, primary trump secondary ingredients (but each should only have one anyway)
	FROM concept c
	JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
		AND r.invalid_reason IS NULL
		AND r.relationship_id = 'Subsumes'
	JOIN concept_ancestor_add$ caa ON caa.ancestor_concept_id = r.concept_id_2
	WHERE c.vocabulary_id = 'ATC'
		AND c.concept_class_id = 'ATC 3rd'
		AND c.invalid_reason IS NULL
		AND (
			c.concept_name ~* ' and |comb| with'
			OR caa.prim = 1
			)
	GROUP BY c.concept_id,
		caa.descendant_concept_id;

	ANALYZE concept_ancestor_add$;

	--6c. Add ATC2: Same as the addition of ATC4, except no more combos
	INSERT INTO concept_ancestor_add$
	SELECT c.concept_id AS ancestor_concept_id,
		caa.descendant_concept_id,
		MIN(caa.min_levels_of_separation) + 1 AS min_levels_of_separation,
		MAX(caa.max_levels_of_separation) + 1 AS max_levels_of_separation,
		1 AS prim --no more combos left at this level
	FROM concept c
	JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
		AND r.invalid_reason IS NULL
		AND r.relationship_id = 'Subsumes'
	JOIN concept_ancestor_add$ caa ON caa.ancestor_concept_id = r.concept_id_2
		AND caa.prim = 1 --only primary at this level
	WHERE c.vocabulary_id = 'ATC'
		AND c.concept_class_id = 'ATC 2nd'
		AND c.invalid_reason IS NULL
	GROUP BY c.concept_id,
		caa.descendant_concept_id;

	ANALYZE concept_ancestor_add$;

	--6d. Add ATC1
	INSERT INTO concept_ancestor_add$
	SELECT c.concept_id AS ancestor_concept_id,
		caa.descendant_concept_id,
		MIN(caa.min_levels_of_separation) + 1 AS min_levels_of_separation,
		MAX(caa.max_levels_of_separation) + 1 AS max_levels_of_separation,
		1 AS prim
	FROM concept c
	JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
		AND r.invalid_reason IS NULL
		AND r.relationship_id = 'Subsumes'
	JOIN concept_ancestor_add$ caa ON caa.ancestor_concept_id = r.concept_id_2
		AND caa.prim = 1
	WHERE c.vocabulary_id = 'ATC'
		AND c.concept_class_id = 'ATC 1st'
		AND c.invalid_reason IS NULL
	GROUP BY c.concept_id,
		caa.descendant_concept_id;

	ANALYZE concept_ancestor_add$;

	--7. Clearing
	DROP TABLE concept_ancestor_rx$;
	DROP TABLE jump$;
	DROP TABLE step$;
	DROP TABLE scenario$;
	DROP TABLE jump_pack$;
	ALTER TABLE concept_ancestor_add$ DROP COLUMN prim;

END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
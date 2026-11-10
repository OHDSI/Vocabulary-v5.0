CREATE OR REPLACE FUNCTION vocabulary_pack.RxEFillHierarchyGaps (
	pDryRun BOOLEAN DEFAULT TRUE
)
RETURNS void
	LANGUAGE plpgsql
AS
$BODY$

/*
Restores the drug hierarchy (Ingredient > Comp/Form > Drug > Quant/Box > Marketed Product) for "orphan" standard
RxNorm / RxNorm Extension drug concepts, i.e. concepts without a valid Ingredient among their ancestors in concept_ancestor.

Scenarios handled:
 1. A valid parent exists (matched by attribute signature or by name), only the link is missing   -> REPAIR_LINK_ONLY
 2. A valid Ingredient exists, but intermediate levels are missing                               -> CREATE_NODES
 3. No valid Ingredient exists                                                                   -> CREATE_INGREDIENT
 (the Ingredient is replaced via 'Concept replaced by' when a valid replacement exists; otherwise it is replicated in RxE)

No-duplicates guarantees for newly created RxNorm Extension concepts:
 - signature match: ingredients+strengths, dose form, quantity, brand name, box size, supplier (+ class) against all valid RxNorm/RxE concepts
 - name match: same concept_class_id and same compare_custom_english() name (after 'Injectable Solution' -> 'Injection', as in RxECleanUP)
 - within the run: nodes needed by several orphans are created once
Attributes are never invented: every new concept takes its attributes from the orphan (drug_strength, dose form, brand name, supplier).
If a deprecated RxNorm/RxE concept with the same signature exists, its name is replicated; otherwise the name is derived from the
orphan's name by removing the dropped attribute (supplier / box / brand / quantity / dose form), keeping the RxNorm naming convention.

Orphans that cannot be fixed safely are listed in the plan with a MANUAL_* scenario and are NOT touched
(packs, name that cannot be derived, a missing link between two RxNorm concepts, ...).

Usage:
 1. concept_ancestor must be built (devv5.FastRecreateSchema(include_concept_ancestor=>true) or pConceptAncestor)
 2. dry run (default) - only fills the review tables rxe_gap_plan and rxe_gap_new_concept:
    DO $_$ BEGIN PERFORM vocabulary_pack.RxEFillHierarchyGaps(); END $_$;
    SELECT * FROM rxe_gap_plan ORDER BY scenario, orphan_class, orphan_concept_id;
 3. real run - fills the stage tables (they are truncated first, like RxECleanUP):
    DO $_$ BEGIN PERFORM vocabulary_pack.RxEFillHierarchyGaps(pDryRun=>FALSE); END $_$;
 4. devv5.GenericUpdate(); then vocabulary_pack.pConceptAncestor(); then re-run RxNorm/vocab_specific_checks/orphan_drug_concepts.sql
 Review tables stay in the current schema until the next run.
*/

DECLARE
	cDF_REL CONSTANT TEXT := (SELECT reverse_relationship_id FROM relationship WHERE relationship_id = 'RxNorm dose form of');
	cBN_REL CONSTANT TEXT := (SELECT reverse_relationship_id FROM relationship WHERE relationship_id = 'Brand name of');
	cMF_REL CONSTANT TEXT := COALESCE((SELECT reverse_relationship_id FROM relationship WHERE relationship_id = 'Supplier of'), 'Has supplier');
	cEND CONSTANT DATE := TO_DATE('20991231', 'yyyymmdd');
	iter INT := 0;
	n INT;
	iMaxOmop INT;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM concept_ancestor LIMIT 1) THEN
		RAISE EXCEPTION 'concept_ancestor is empty';
	END IF;

	/*****************************************
	* 1. Orphans (standard drug concepts without a valid Ingredient ancestor)
	*****************************************/
	PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 1', FALSE);
	RAISE NOTICE '% step 1', clock_timestamp();
	DROP TABLE IF EXISTS rxegap_orphan;
	CREATE UNLOGGED TABLE rxegap_orphan AS
	SELECT c.concept_id, c.concept_code, c.concept_name, c.concept_class_id, c.vocabulary_id
	FROM concept c
	WHERE c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
		AND c.domain_id = 'Drug'
		AND c.standard_concept = 'S'
		AND c.invalid_reason IS NULL
		AND c.concept_class_id IN (
			'Clinical Drug', 'Branded Drug', 'Quant Clinical Drug', 'Quant Branded Drug',
			'Clinical Drug Box', 'Branded Drug Box', 'Quant Clinical Box', 'Quant Branded Box',
			'Marketed Product', 'Clinical Pack', 'Branded Pack', 'Clinical Pack Box', 'Branded Pack Box'
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_ancestor ca
			JOIN concept ing ON ing.concept_id = ca.ancestor_concept_id
				AND ing.concept_class_id = 'Ingredient'
				AND ing.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
				AND ing.invalid_reason IS NULL
			WHERE ca.descendant_concept_id = c.concept_id
			);
	CREATE UNIQUE INDEX idx_rxegap_orphan ON rxegap_orphan (concept_id);

	/*****************************************
	* 2. Class pairs and relationships (same as rl in BuildRxE / rxnorm_allowed_rel in pConceptAncestor)
	*    parent class, relationship_id (parent -> child), child class
	*****************************************/
	PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 2', FALSE);
	RAISE NOTICE '% step 2', clock_timestamp();
	DROP TABLE IF EXISTS rxegap_rl;
	CREATE UNLOGGED TABLE rxegap_rl AS
	SELECT * FROM (
		VALUES
		('Ingredient', 'RxNorm ing of', 'Clinical Drug Comp'),
		('Ingredient', 'RxNorm ing of', 'Clinical Drug Form'),
		('Clinical Drug Comp', 'Constitutes', 'Clinical Drug'),
		('Clinical Drug Comp', 'Has tradename', 'Branded Drug Comp'),
		('Clinical Drug Form', 'RxNorm inverse is a', 'Clinical Drug'),
		('Clinical Drug Form', 'Has tradename', 'Branded Drug Form'),
		('Branded Drug Comp', 'Constitutes', 'Branded Drug'),
		('Branded Drug Form', 'RxNorm inverse is a', 'Branded Drug'),
		('Clinical Drug', 'Has tradename', 'Branded Drug'),
		('Clinical Drug', 'Has quantified form', 'Quant Clinical Drug'),
		('Clinical Drug', 'Available as box', 'Clinical Drug Box'),
		('Branded Drug', 'Has quantified form', 'Quant Branded Drug'),
		('Branded Drug', 'Available as box', 'Branded Drug Box'),
		('Quant Clinical Drug', 'Has tradename', 'Quant Branded Drug'),
		('Quant Clinical Drug', 'Available as box', 'Quant Clinical Box'),
		('Quant Branded Drug', 'Available as box', 'Quant Branded Box'),
		('Clinical Drug Box', 'Has quantified form', 'Quant Clinical Box'),
		('Clinical Drug Box', 'Has tradename', 'Branded Drug Box'),
		('Branded Drug Box', 'Has quantified form', 'Quant Branded Box'),
		('Quant Clinical Box', 'Has tradename', 'Quant Branded Box'),
		('Clinical Drug', 'Has marketed form', 'Marketed Product'),
		('Branded Drug', 'Has marketed form', 'Marketed Product'),
		('Quant Clinical Drug', 'Has marketed form', 'Marketed Product'),
		('Quant Branded Drug', 'Has marketed form', 'Marketed Product'),
		('Clinical Drug Box', 'Has marketed form', 'Marketed Product'),
		('Branded Drug Box', 'Has marketed form', 'Marketed Product'),
		('Quant Clinical Box', 'Has marketed form', 'Marketed Product'),
		('Quant Branded Box', 'Has marketed form', 'Marketed Product')
	) AS t (parent_class, rel, child_class);

	/*****************************************
	* 3. Attribute resolution: invalid ingredient / dose form / brand name / supplier -> valid replacement
	*    (follow 'Concept replaced by'); if there is none, the attribute is replicated in RxE.
	*****************************************/
	PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 3', FALSE);
	RAISE NOTICE '% step 3', clock_timestamp();
	DROP TABLE IF EXISTS rxegap_ds_raw;
	CREATE UNLOGGED TABLE rxegap_ds_raw AS
	SELECT ds.*
	FROM drug_strength ds
	JOIN concept d ON d.concept_id = ds.drug_concept_id
		AND d.vocabulary_id IN ('RxNorm', 'RxNorm Extension');
	-- (rows of deprecated concepts are kept on purpose: they are the source for replicas)
	CREATE INDEX idx_rxegap_ds_raw ON rxegap_ds_raw (drug_concept_id);

	DROP TABLE IF EXISTS rxegap_attr_ids;
	CREATE UNLOGGED TABLE rxegap_attr_ids AS
	SELECT DISTINCT ingredient_concept_id AS attr_id FROM rxegap_ds_raw
	UNION
	SELECT DISTINCT r.concept_id_2
	FROM concept_relationship r
	JOIN concept d ON d.concept_id = r.concept_id_1
		AND d.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
		AND d.concept_class_id IN (
			'Clinical Drug Form', 'Branded Drug Form', 'Clinical Drug', 'Branded Drug', 'Quant Clinical Drug', 'Quant Branded Drug',
			'Clinical Drug Box', 'Branded Drug Box', 'Quant Clinical Box', 'Quant Branded Box', 'Marketed Product',
			'Branded Drug Comp'
			)
	WHERE r.invalid_reason IS NULL
		AND r.relationship_id IN (cDF_REL, cBN_REL, cMF_REL);

	DROP TABLE IF EXISTS rxegap_res;
	CREATE UNLOGGED TABLE rxegap_res AS
	WITH RECURSIVE chain AS (
		SELECT a.attr_id AS id, a.attr_id AS cur, 0 AS depth
		FROM rxegap_attr_ids a
		UNION ALL
		SELECT ch.id, r.concept_id_2, ch.depth + 1
		FROM chain ch
		JOIN concept c ON c.concept_id = ch.cur AND c.invalid_reason IS NOT NULL
		JOIN concept_relationship r ON r.concept_id_1 = ch.cur
			AND r.relationship_id = 'Concept replaced by'
			AND r.invalid_reason IS NULL
		WHERE ch.depth < 10
		)
	SELECT DISTINCT ON (ch.id) ch.id AS attr_id,
		ch.cur AS resolved_id
	FROM chain ch
	JOIN concept o ON o.concept_id = ch.id
	JOIN concept t ON t.concept_id = ch.cur
		AND t.invalid_reason IS NULL
		AND t.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
		AND t.concept_class_id = o.concept_class_id
	ORDER BY ch.id, ch.depth;
	CREATE UNIQUE INDEX idx_rxegap_res ON rxegap_res (attr_id);

	-- attributes without valid replacement: candidate RxE replicas (deprecated RxNorm attributes are copied as they are)
	DROP TABLE IF EXISTS rxegap_new_attr;
	CREATE UNLOGGED TABLE rxegap_new_attr AS
	SELECT c.concept_id AS attr_id,
		c.concept_name,
		c.concept_class_id,
		dev_rxnorm.compare_custom_english(REGEXP_REPLACE(c.concept_name, '\mInjectable Solution\M', 'Injection', 'gi')) AS norm,
		NULL::INT AS dup_of -- existing valid concept with the same name and class
	FROM rxegap_attr_ids a
	JOIN concept c ON c.concept_id = a.attr_id
		AND c.concept_class_id IN ('Ingredient', 'Dose Form', 'Brand Name', 'Supplier')
	WHERE NOT EXISTS (SELECT 1 FROM rxegap_res r WHERE r.attr_id = a.attr_id);

	-- normalized names of all valid RxNorm/RxE concepts: computed ONCE (the function is slow), indexed, reused below
	DROP TABLE IF EXISTS rxegap_uname;
	CREATE UNLOGGED TABLE rxegap_uname AS
	SELECT c.concept_id,
		c.concept_class_id,
		c.vocabulary_id,
		dev_rxnorm.compare_custom_english(REGEXP_REPLACE(c.concept_name, '\mInjectable Solution\M', 'Injection', 'gi')) AS norm
	FROM concept c
	WHERE c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
		AND c.invalid_reason IS NULL;
	CREATE INDEX idx_rxegap_uname ON rxegap_uname (concept_class_id, norm);
	ANALYZE rxegap_uname;

	-- duplicate guard for attributes: same class and name as an existing valid RxNorm/RxE concept
	UPDATE rxegap_new_attr na
	SET dup_of = u.concept_id
	FROM (
		SELECT concept_class_id, norm, MIN(concept_id) AS concept_id
		FROM rxegap_uname
		GROUP BY concept_class_id, norm
		) u
	WHERE u.concept_class_id = na.concept_class_id
		AND u.norm = na.norm;
	INSERT INTO rxegap_res
	SELECT attr_id, dup_of FROM rxegap_new_attr WHERE dup_of IS NOT NULL;
	DELETE FROM rxegap_new_attr WHERE dup_of IS NOT NULL;

	-- duplicates inside the batch: keep one replica per (class, name)
	DELETE FROM rxegap_new_attr na
	USING rxegap_new_attr k
	WHERE k.concept_class_id = na.concept_class_id
		AND k.norm = na.norm
		AND k.attr_id < na.attr_id;

	-- remaining attributes resolve to themselves (virtual: will become new RxE concepts); batch duplicates -> the kept one
	INSERT INTO rxegap_res
	SELECT a.attr_id,
		COALESCE(k.attr_id, a.attr_id)
	FROM rxegap_attr_ids a
	LEFT JOIN concept c ON c.concept_id = a.attr_id
	LEFT JOIN rxegap_new_attr k ON k.concept_class_id = c.concept_class_id
		AND k.norm = dev_rxnorm.compare_custom_english(REGEXP_REPLACE(c.concept_name, '\mInjectable Solution\M', 'Injection', 'gi'))
	WHERE NOT EXISTS (SELECT 1 FROM rxegap_res r WHERE r.attr_id = a.attr_id);

	/*****************************************
	* 4. Attribute table for every RxNorm/RxE hierarchy concept (valid and invalid: invalid ones are replica sources)
	*****************************************/
	PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 4', FALSE);
	RAISE NOTICE '% step 4', clock_timestamp();
	DROP TABLE IF EXISTS rxegap_ds;
	CREATE UNLOGGED TABLE rxegap_ds AS
	SELECT s.drug_concept_id,
		s.ing_id,
		-- strength token, 3 significant digits (as BuildRxE rounds)
		CASE
			WHEN s.amount_value IS NOT NULL
				THEN 'a' || TRIM(TRAILING '.' FROM TO_CHAR(s.amt3, 'FM9999999999999999999990.999999999999999999999')) || ':' || COALESCE(s.amount_unit_concept_id, 0)
			WHEN s.numerator_value IS NOT NULL
				THEN 'n' || TRIM(TRAILING '.' FROM TO_CHAR(s.num3, 'FM9999999999999999999990.999999999999999999999')) || ':' || COALESCE(s.numerator_unit_concept_id, 0) || '/' || COALESCE(s.denominator_unit_concept_id, 0)
			ELSE ''
			END AS tok,
		CASE
			WHEN s.denominator_value IS NOT NULL
				THEN TRIM(TRAILING '.' FROM TO_CHAR(ROUND(s.denominator_value, GREATEST(0, 2 - FLOOR(LOG(s.denominator_value))::INT)), 'FM9999999999999999999990.999999999999999999999')) || ':' || COALESCE(s.denominator_unit_concept_id, 0)
			ELSE ''
			END AS qtok,
		COALESCE(s.box_size, 0) AS bs
	FROM (
		SELECT ds.drug_concept_id,
			COALESCE(r.resolved_id, ds.ingredient_concept_id) AS ing_id,
			ds.amount_value,
			ds.amount_unit_concept_id,
			ds.numerator_value,
			ds.numerator_unit_concept_id,
			ds.denominator_value,
			ds.denominator_unit_concept_id,
			ds.box_size,
			CASE WHEN ds.amount_value > 0
				THEN ROUND(ds.amount_value, GREATEST(0, 2 - FLOOR(LOG(ds.amount_value))::INT))
				ELSE ds.amount_value END AS amt3,
			CASE
				WHEN ds.numerator_value IS NULL THEN NULL
				WHEN ds.numerator_unit_concept_id IN (8554, 9325, 9324) -- %, D, X: not divided by the denominator
					THEN ROUND(ds.numerator_value, GREATEST(0, 2 - FLOOR(LOG(NULLIF(ds.numerator_value, 0)))::INT))
				WHEN ds.numerator_value / COALESCE(NULLIF(ds.denominator_value, 0), 1) > 0
					THEN ROUND(ds.numerator_value / COALESCE(NULLIF(ds.denominator_value, 0), 1),
						GREATEST(0, 2 - FLOOR(LOG(ds.numerator_value / COALESCE(NULLIF(ds.denominator_value, 0), 1)))::INT))
				ELSE 0
				END AS num3
		FROM rxegap_ds_raw ds
		LEFT JOIN rxegap_res r ON r.attr_id = ds.ingredient_concept_id
		) s;
	CREATE INDEX idx_rxegap_ds ON rxegap_ds (drug_concept_id);

	DROP TABLE IF EXISTS rxegap_attr;
	CREATE UNLOGGED TABLE rxegap_attr AS
	SELECT c.concept_id,
		c.concept_name,
		c.concept_class_id,
		c.vocabulary_id,
		c.standard_concept,
		c.invalid_reason,
		c.valid_end_date,
		d.ing_ids,
		d.comps,
		COALESCE(d.q, '') AS q,
		COALESCE(d.bs, 0) AS bs,
		COALESCE((SELECT COALESCE(rs.resolved_id, r.concept_id_2) FROM concept_relationship r JOIN concept t ON t.concept_id = r.concept_id_2 AND t.concept_class_id = 'Dose Form' LEFT JOIN rxegap_res rs ON rs.attr_id = r.concept_id_2 WHERE r.concept_id_1 = c.concept_id AND r.relationship_id = cDF_REL AND r.invalid_reason IS NULL ORDER BY r.concept_id_2 LIMIT 1), 0) AS df,
		COALESCE((SELECT COALESCE(rs.resolved_id, r.concept_id_2) FROM concept_relationship r JOIN concept t ON t.concept_id = r.concept_id_2 AND t.concept_class_id = 'Brand Name' LEFT JOIN rxegap_res rs ON rs.attr_id = r.concept_id_2 WHERE r.concept_id_1 = c.concept_id AND r.relationship_id = cBN_REL AND r.invalid_reason IS NULL ORDER BY r.concept_id_2 LIMIT 1), 0) AS bn,
		COALESCE((SELECT COALESCE(rs.resolved_id, r.concept_id_2) FROM concept_relationship r JOIN concept t ON t.concept_id = r.concept_id_2 AND t.concept_class_id = 'Supplier' LEFT JOIN rxegap_res rs ON rs.attr_id = r.concept_id_2 WHERE r.concept_id_1 = c.concept_id AND r.relationship_id = cMF_REL AND r.invalid_reason IS NULL ORDER BY r.concept_id_2 LIMIT 1), 0) AS mf
	FROM concept c
	JOIN (
		SELECT drug_concept_id,
			ARRAY_AGG(DISTINCT ing_id ORDER BY ing_id) AS ing_ids,
			ARRAY_AGG(ing_id || '~' || tok ORDER BY ing_id, tok) AS comps,
			MAX(qtok) AS q,
			MAX(bs) AS bs
		FROM rxegap_ds
		GROUP BY drug_concept_id
		) d ON d.drug_concept_id = c.concept_id
	WHERE c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
		AND c.concept_class_id IN (
			'Ingredient', 'Clinical Drug Comp', 'Branded Drug Comp', 'Clinical Drug Form', 'Branded Drug Form',
			'Clinical Drug', 'Branded Drug', 'Quant Clinical Drug', 'Quant Branded Drug',
			'Clinical Drug Box', 'Branded Drug Box', 'Quant Clinical Box', 'Quant Branded Box', 'Marketed Product'
			);
	-- Comps and Forms keep the strength token, but Forms/Ingredients have none: tokens are already '' there
	CREATE UNIQUE INDEX idx_rxegap_attr ON rxegap_attr (concept_id);

	-- attribute names (existing or virtual)
	DROP TABLE IF EXISTS rxegap_attrname;
	CREATE UNLOGGED TABLE rxegap_attrname AS
	SELECT c.concept_id AS id, c.concept_name AS name
	FROM concept c
	WHERE c.concept_id IN (SELECT resolved_id FROM rxegap_res);
	CREATE UNIQUE INDEX idx_rxegap_attrname ON rxegap_attrname (id);

	/*****************************************
	* 5. Hierarchy closure for every orphan: drop one attribute at a time (supplier, box, brand, quantity),
	*    split Drug into Comp / Form, take Ingredients from Comp / Form.
	*****************************************/
	PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 5', FALSE);
	RAISE NOTICE '% step 5', clock_timestamp();
	DROP TABLE IF EXISTS rxegap_node;
	CREATE UNLOGGED TABLE rxegap_node (
		key TEXT PRIMARY KEY,
		concept_class_id TEXT,
		ing_ids INT[],
		comps TEXT[],
		df INT,
		q TEXT,
		bn INT,
		bs INT,
		mf INT,
		name TEXT,
		depth INT,
		concept_id INT, -- matched existing valid concept
		src_concept_id INT, -- deprecated concept replicated
		norm TEXT,
		canon_key TEXT -- batch duplicate -> kept node
		);
	DROP TABLE IF EXISTS rxegap_edge;
	CREATE UNLOGGED TABLE rxegap_edge (
		child_key TEXT,
		parent_key TEXT,
		op TEXT
		);
	DROP TABLE IF EXISTS rxegap_cand;
	CREATE UNLOGGED TABLE rxegap_cand (
		child_key TEXT,
		child_class TEXT,
		op TEXT,
		concept_class_id TEXT,
		ing_ids INT[],
		comps TEXT[],
		df INT,
		q TEXT,
		bn INT,
		bs INT,
		mf INT,
		name TEXT
		);
	DROP TABLE IF EXISTS rxegap_seed;
	CREATE UNLOGGED TABLE rxegap_seed (
		orphan_id INT,
		key TEXT
		);

	-- seeds
	INSERT INTO rxegap_node (key, concept_class_id, ing_ids, comps, df, q, bn, bs, mf, name, depth, concept_id)
	SELECT DISTINCT ON (k.key) k.key, c.concept_class_id, c.ing_ids, c.comps, c.df, c.q, c.bn, c.bs, c.mf, c.concept_name, 0, o.concept_id
	FROM rxegap_orphan o
	JOIN rxegap_attr c ON c.concept_id = o.concept_id
	CROSS JOIN LATERAL (
		SELECT c.concept_class_id || '|' || ARRAY_TO_STRING(c.comps, ',') || '|' || c.df || '|' || c.q || '|' || c.bn || '|' || c.bs || '|' || c.mf AS key
		) k
	WHERE o.concept_class_id NOT LIKE '%Pack%'
	ORDER BY k.key, o.concept_id;

	INSERT INTO rxegap_seed
	SELECT o.concept_id,
		c.concept_class_id || '|' || ARRAY_TO_STRING(c.comps, ',') || '|' || c.df || '|' || c.q || '|' || c.bn || '|' || c.bs || '|' || c.mf
	FROM rxegap_orphan o
	JOIN rxegap_attr c ON c.concept_id = o.concept_id
	WHERE o.concept_class_id NOT LIKE '%Pack%';
	TRUNCATE rxegap_cand;

	LOOP
		PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 5 iter ' || iter, FALSE);
		TRUNCATE rxegap_cand;

		-- drop supplier / box / quantity / brand from drug-type nodes; brand from Comp and Form
		INSERT INTO rxegap_cand
		SELECT c.key, c.concept_class_id, 'MF', NULL, c.ing_ids, c.comps, c.df, c.q, c.bn, c.bs, 0,
			NULLIF(REGEXP_REPLACE(c.name, ' by .*$', ''), c.name)
		FROM rxegap_node c
		WHERE c.depth = iter AND c.mf <> 0
		UNION ALL
		SELECT c.key, c.concept_class_id, 'BS', NULL, c.ing_ids, c.comps, c.df, c.q, c.bn, 0, c.mf,
			NULLIF(REPLACE(c.name, ' Box of ' || c.bs, ''), c.name)
		FROM rxegap_node c
		WHERE c.depth = iter AND c.bs <> 0
		UNION ALL
		SELECT c.key, c.concept_class_id, 'Q', NULL, c.ing_ids, c.comps, c.df, '', c.bn, c.bs, c.mf,
			NULLIF(REGEXP_REPLACE(c.name, '^[0-9]*\.?[0-9]+ [^ ]+ ', ''), c.name)
		FROM rxegap_node c
		WHERE c.depth = iter AND c.q <> ''
		UNION ALL
		SELECT c.key, c.concept_class_id, 'BN', NULL, c.ing_ids, c.comps, c.df, c.q, 0, c.bs, c.mf,
			NULLIF(REPLACE(c.name, ' [' || bn.name || ']', ''), c.name)
		FROM rxegap_node c
		JOIN rxegap_attrname bn ON bn.id = c.bn
		WHERE c.depth = iter AND c.bn <> 0;

		-- Drug -> Drug Form (ingredients + dose form [+ brand])
		INSERT INTO rxegap_cand
		SELECT c.key, c.concept_class_id, 'FORM',
			CASE c.concept_class_id WHEN 'Branded Drug' THEN 'Branded Drug Form' ELSE 'Clinical Drug Form' END,
			c.ing_ids,
			(SELECT ARRAY_AGG(i || '~' ORDER BY i) FROM UNNEST(c.ing_ids) i),
			c.df, '', c.bn, 0, 0,
			(SELECT STRING_AGG(n.name, ' / ' ORDER BY UPPER(n.name) COLLATE "C") FROM UNNEST(c.ing_ids) i JOIN rxegap_attrname n ON n.id = i)
				|| ' ' || dfn.name || COALESCE(' [' || bn.name || ']', '')
		FROM rxegap_node c
		JOIN rxegap_attrname dfn ON dfn.id = c.df
		LEFT JOIN rxegap_attrname bn ON bn.id = NULLIF(c.bn, 0)
		WHERE c.depth = iter AND c.concept_class_id IN ('Clinical Drug', 'Branded Drug') AND c.df <> 0;

		-- Drug -> Drug Comp (one per ingredient component, no dose form)
		INSERT INTO rxegap_cand
		SELECT c.key, c.concept_class_id, 'COMP',
			CASE c.concept_class_id WHEN 'Branded Drug' THEN 'Branded Drug Comp' ELSE 'Clinical Drug Comp' END,
			ARRAY[SPLIT_PART(t.tok, '~', 1)::INT],
			ARRAY[t.tok],
			0, '', c.bn, 0, 0,
			(
				SELECT seg || COALESCE(' [' || bn.name || ']', '')
				FROM REGEXP_SPLIT_TO_TABLE(
					CASE WHEN RIGHT(base.nm, LENGTH(' ' || dfn.name)) = ' ' || dfn.name
						THEN LEFT(base.nm, LENGTH(base.nm) - LENGTH(' ' || dfn.name)) END, ' / ') AS seg
				JOIN rxegap_attrname ing ON ing.id = SPLIT_PART(t.tok, '~', 1)::INT
				WHERE LOWER(seg) LIKE LOWER(ing.name) || ' %'
				LIMIT 1
			)
		FROM rxegap_node c
		CROSS JOIN LATERAL UNNEST(c.comps) AS t (tok)
		JOIN rxegap_attrname dfn ON dfn.id = c.df
		LEFT JOIN rxegap_attrname bn ON bn.id = NULLIF(c.bn, 0)
		CROSS JOIN LATERAL (SELECT REPLACE(c.name, COALESCE(' [' || bn.name || ']', ''), '') AS nm) base
		WHERE c.depth = iter AND c.concept_class_id IN ('Clinical Drug', 'Branded Drug') AND c.df <> 0;

		-- Comp / Form -> Ingredient
		INSERT INTO rxegap_cand
		SELECT c.key, c.concept_class_id, 'ING', 'Ingredient', ARRAY[i], ARRAY[i || '~'], 0, '', 0, 0, 0, n.name
		FROM rxegap_node c
		CROSS JOIN LATERAL UNNEST(c.ing_ids) AS i
		JOIN rxegap_attrname n ON n.id = i
		WHERE c.depth = iter AND c.concept_class_id IN ('Clinical Drug Comp', 'Clinical Drug Form');

		-- classes of the dropped-attribute candidates
		UPDATE rxegap_cand
		SET concept_class_id = CASE
				WHEN child_class = 'Branded Drug Comp' AND op = 'BN' THEN 'Clinical Drug Comp'
				WHEN child_class = 'Branded Drug Form' AND op = 'BN' THEN 'Clinical Drug Form'
				WHEN mf <> 0 THEN 'Marketed Product'
				WHEN bs <> 0 THEN CASE WHEN q <> '' THEN CASE WHEN bn <> 0 THEN 'Quant Branded Box' ELSE 'Quant Clinical Box' END
					ELSE CASE WHEN bn <> 0 THEN 'Branded Drug Box' ELSE 'Clinical Drug Box' END END
				ELSE CASE WHEN q <> '' THEN CASE WHEN bn <> 0 THEN 'Quant Branded Drug' ELSE 'Quant Clinical Drug' END
					ELSE CASE WHEN bn <> 0 THEN 'Branded Drug' ELSE 'Clinical Drug' END END
				END
		WHERE concept_class_id IS NULL;

		iter := iter + 1;

		-- new nodes (name may be NULL = could not be derived; it is resolved later: replica or manual)
		INSERT INTO rxegap_node (key, concept_class_id, ing_ids, comps, df, q, bn, bs, mf, name, depth)
		SELECT DISTINCT ON (k.key) k.key, c.concept_class_id, c.ing_ids, c.comps, c.df, c.q, c.bn, c.bs, c.mf, c.name, iter
		FROM rxegap_cand c
		CROSS JOIN LATERAL (
			SELECT c.concept_class_id || '|' || ARRAY_TO_STRING(c.comps, ',') || '|' || c.df || '|' || c.q || '|' || c.bn || '|' || c.bs || '|' || c.mf AS key
			) k
		ORDER BY k.key, (c.name IS NULL)
		ON CONFLICT (key) DO NOTHING;
		GET DIAGNOSTICS n = ROW_COUNT;

		INSERT INTO rxegap_edge
		SELECT DISTINCT c.child_key, c.concept_class_id || '|' || ARRAY_TO_STRING(c.comps, ',') || '|' || c.df || '|' || c.q || '|' || c.bn || '|' || c.bs || '|' || c.mf, c.op
		FROM rxegap_cand c;

		EXIT WHEN n = 0 OR iter > 12;
	END LOOP;

	/*****************************************
	* 6. Match nodes to existing valid concepts (signature), to deprecated replica sources (signature), then by name
	*****************************************/
	PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 6', FALSE);
	RAISE NOTICE '% step 6', clock_timestamp();
	UPDATE rxegap_node n
	SET concept_id = m.concept_id
	FROM (
		SELECT a.concept_class_id || '|' || ARRAY_TO_STRING(a.comps, ',') || '|' || a.df || '|' || a.q || '|' || a.bn || '|' || a.bs || '|' || a.mf AS key,
			-- RxNorm first, then lowest id
			(ARRAY_AGG(a.concept_id ORDER BY (a.vocabulary_id = 'RxNorm') DESC, a.concept_id))[1] AS concept_id
		FROM rxegap_attr a
		WHERE a.invalid_reason IS NULL
		GROUP BY 1
		) m
	WHERE m.key = n.key
		AND n.concept_id IS NULL;

	UPDATE rxegap_node n
	SET src_concept_id = m.concept_id,
		name = m.concept_name
	FROM (
		SELECT a.concept_class_id || '|' || ARRAY_TO_STRING(a.comps, ',') || '|' || a.df || '|' || a.q || '|' || a.bn || '|' || a.bs || '|' || a.mf AS key,
			(ARRAY_AGG(a.concept_id ORDER BY (a.vocabulary_id = 'RxNorm') DESC, a.valid_end_date DESC, a.concept_id))[1] AS concept_id,
			(ARRAY_AGG(a.concept_name ORDER BY (a.vocabulary_id = 'RxNorm') DESC, a.valid_end_date DESC, a.concept_id))[1] AS concept_name
		FROM rxegap_attr a
		WHERE a.invalid_reason IS NOT NULL
		GROUP BY 1
		) m
	WHERE m.key = n.key
		AND n.concept_id IS NULL;

	-- naming convention check (derived or replicated names must match the class):
	--   Ingredient = ingredient; Comp = ingredient + dose [+ brand]; Form = ingredient + form [+ brand];
	--   Drug = ingredient + dose + form [+ brand]; Quant = volume + Drug; Box = Drug + 'Box of N'; Quant Box = Quant + 'Box of N'.
	--   Brand '[...]' only in Branded classes; 'Box of N' only in Box classes; leading volume only in Quant classes.
	-- A violating name is dropped (the orphan goes to MANUAL_NAME_NOT_DERIVED) and listed in rxe_gap_name_issue.
	DROP TABLE IF EXISTS rxe_gap_name_issue;
	CREATE TABLE rxe_gap_name_issue AS
	SELECT n.key AS node_key, n.concept_class_id, n.name AS concept_name, n.src_concept_id, v.reason
	FROM rxegap_node n
	CROSS JOIN LATERAL (
		SELECT CASE
			WHEN n.concept_class_id NOT LIKE 'Branded%' AND n.concept_class_id NOT LIKE 'Quant Branded%' AND n.concept_class_id <> 'Marketed Product'
				AND n.name ~ '\[[^\]]*\]'
				THEN 'brand in a non-branded name'
			WHEN (n.concept_class_id LIKE 'Branded%' OR n.concept_class_id LIKE 'Quant Branded%')
				AND n.name !~ '\[[^\]]+\]'
				THEN 'brand missing in a branded name'
			WHEN n.concept_class_id IN ('Clinical Drug Box', 'Branded Drug Box', 'Quant Clinical Box', 'Quant Branded Box')
				AND n.name !~ ' Box of [0-9]+'
				THEN 'box quantity missing'
			WHEN n.concept_class_id IN ('Clinical Drug Comp', 'Branded Drug Comp', 'Clinical Drug Form', 'Branded Drug Form', 'Clinical Drug', 'Branded Drug', 'Quant Clinical Drug', 'Quant Branded Drug')
				AND n.name ~ ' Box of [0-9]+'
				THEN 'box quantity in a non-box name'
			WHEN n.concept_class_id LIKE 'Quant%' AND n.name !~ '^[0-9]*\.?[0-9]+ '
				THEN 'volume missing in a quant name'
			WHEN n.concept_class_id IN ('Clinical Drug Comp', 'Branded Drug Comp', 'Clinical Drug Form', 'Branded Drug Form', 'Clinical Drug', 'Branded Drug', 'Clinical Drug Box', 'Branded Drug Box')
				AND n.name ~ '^[0-9]*\.?[0-9]+ [A-Z]+ '
				THEN 'volume in a non-quant name'
			WHEN n.concept_class_id IN ('Clinical Drug Form', 'Branded Drug Form')
				AND n.name ~ '[0-9] (MG|MCG|ML|G|L|UNT|MEQ|MMOL|IU|%)( |/)'
				THEN 'strength in a form name'
			WHEN n.concept_class_id IN ('Clinical Drug Comp', 'Branded Drug Comp')
				AND n.name !~ '[0-9]'
				THEN 'strength missing in a component name'
			WHEN n.concept_class_id = 'Ingredient'
				AND n.name ~ '\[|Box of'
				THEN 'attributes in an ingredient name'
			WHEN n.concept_class_id <> 'Marketed Product'
				AND n.name ~ ' by [^\]]*$'
				THEN 'supplier in a non-marketed name'
			END AS reason
		) v
	WHERE n.concept_id IS NULL
		AND n.name IS NOT NULL
		AND v.reason IS NOT NULL;

	UPDATE rxegap_node n
	SET name = NULL,
		src_concept_id = NULL
	FROM rxe_gap_name_issue i
	WHERE i.node_key = n.key;

	-- duplicate guard by name (same rule as RxECleanUP)
	UPDATE rxegap_node
	SET norm = dev_rxnorm.compare_custom_english(REGEXP_REPLACE(name, '\mInjectable Solution\M', 'Injection', 'gi'))
	WHERE concept_id IS NULL
		AND name IS NOT NULL;

	-- rxegap_uname (built in step 3) is reused here

	UPDATE rxegap_node n
	SET concept_id = (
			SELECT (ARRAY_AGG(u.concept_id ORDER BY (u.vocabulary_id = 'RxNorm') DESC, u.concept_id))[1]
			FROM rxegap_uname u
			WHERE u.concept_class_id = n.concept_class_id
				AND u.norm = n.norm
			)
	WHERE n.concept_id IS NULL
		AND n.norm IS NOT NULL;

	-- duplicates inside the batch: nodes with the same class and name collapse into one
	UPDATE rxegap_node n
	SET canon_key = k.key
	FROM (
		SELECT concept_class_id, norm, MIN(key) AS key
		FROM rxegap_node
		WHERE concept_id IS NULL AND norm IS NOT NULL
		GROUP BY concept_class_id, norm
		) k
	WHERE n.concept_id IS NULL
		AND k.concept_class_id = n.concept_class_id
		AND k.norm = n.norm
		AND k.key <> n.key;

	/*****************************************
	* 7. Which orphans are repairable
	*****************************************/
	PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 7', FALSE);
	RAISE NOTICE '% step 7', clock_timestamp();
	-- closure of every orphan over the edges
	DROP TABLE IF EXISTS rxegap_member;
	CREATE UNLOGGED TABLE rxegap_member AS
	WITH RECURSIVE cl AS (
		SELECT s.orphan_id, s.key FROM rxegap_seed s
		UNION
		SELECT cl.orphan_id, e.parent_key
		FROM cl
		JOIN rxegap_edge e ON e.child_key = cl.key
		)
	SELECT DISTINCT orphan_id, key FROM cl;
	CREATE INDEX idx_rxegap_member ON rxegap_member (orphan_id, key);

	-- existing relationship pairs (valid) and RxNorm-RxNorm pairs that this tool is not allowed to create
	DROP TABLE IF EXISTS rxegap_edge_x;
	CREATE UNLOGGED TABLE rxegap_edge_x AS
	SELECT e.child_key,
		e.parent_key,
		cn.concept_id AS child_id,
		pn.concept_id AS parent_id,
		cn.concept_class_id AS child_class,
		pn.concept_class_id AS parent_class,
		rl.rel,
		CASE
			WHEN cn.concept_id IS NOT NULL AND pn.concept_id IS NOT NULL AND EXISTS (
					SELECT 1 FROM concept_relationship r
					WHERE r.concept_id_1 = pn.concept_id AND r.concept_id_2 = cn.concept_id
						AND r.relationship_id = rl.rel AND r.invalid_reason IS NULL)
				THEN 'EXISTS'
			WHEN cn.concept_id IS NOT NULL AND pn.concept_id IS NOT NULL
				AND (SELECT vocabulary_id FROM concept WHERE concept_id = cn.concept_id) = 'RxNorm'
				AND (SELECT vocabulary_id FROM concept WHERE concept_id = pn.concept_id) = 'RxNorm'
				THEN 'RXN_RXN'
			ELSE 'NEW'
			END AS status
	FROM (SELECT DISTINCT child_key, parent_key FROM rxegap_edge) e
	JOIN (SELECT key, concept_class_id, COALESCE((SELECT concept_id FROM rxegap_node k WHERE k.key = x.canon_key), x.concept_id) AS concept_id FROM rxegap_node x) cn ON cn.key = e.child_key
	JOIN (SELECT key, concept_class_id, COALESCE((SELECT concept_id FROM rxegap_node k WHERE k.key = x.canon_key), x.concept_id) AS concept_id FROM rxegap_node x) pn ON pn.key = e.parent_key
	JOIN rxegap_rl rl ON rl.parent_class = pn.concept_class_id
		AND rl.child_class = cn.concept_class_id;

	DROP TABLE IF EXISTS rxe_gap_plan;
	CREATE TABLE rxe_gap_plan AS
	WITH info AS (
		SELECT o.concept_id AS orphan_concept_id,
			o.concept_code AS orphan_concept_code,
			o.concept_name AS orphan_concept_name,
			o.concept_class_id AS orphan_class,
			o.vocabulary_id AS orphan_vocabulary_id,
			COUNT(*) FILTER (WHERE n.concept_id IS NULL AND n.canon_key IS NULL AND n.name IS NOT NULL) AS nodes_to_create,
			COUNT(*) FILTER (WHERE n.concept_id IS NULL AND n.name IS NULL) AS nodes_unresolved,
			COUNT(*) FILTER (WHERE n.concept_id IS NULL AND n.canon_key IS NULL AND n.concept_class_id = 'Ingredient') AS ingredient_to_create
		FROM rxegap_orphan o
		LEFT JOIN rxegap_member m ON m.orphan_id = o.concept_id
		LEFT JOIN rxegap_node n ON n.key = m.key
		GROUP BY o.concept_id, o.concept_code, o.concept_name, o.concept_class_id, o.vocabulary_id
		),
	edges AS (
		SELECT m.orphan_id,
			COUNT(*) FILTER (WHERE x.status = 'NEW') AS links_to_create,
			COUNT(*) FILTER (WHERE x.status = 'RXN_RXN') AS links_rxn_rxn,
			COUNT(*) FILTER (WHERE x.status = 'EXISTS') AS links_existing
		FROM (SELECT DISTINCT orphan_id, key FROM rxegap_member) m
		JOIN rxegap_edge_x x ON x.child_key = m.key
		GROUP BY m.orphan_id
		)
	SELECT i.orphan_concept_id, i.orphan_concept_code, i.orphan_concept_name, i.orphan_class, i.orphan_vocabulary_id,
		CASE
			WHEN i.orphan_class LIKE '%Pack%' THEN 'MANUAL_PACK'
			WHEN NOT EXISTS (SELECT 1 FROM rxegap_seed s WHERE s.orphan_id = i.orphan_concept_id) THEN 'MANUAL_NO_DRUG_STRENGTH'
			WHEN i.nodes_unresolved > 0 THEN 'MANUAL_NAME_NOT_DERIVED'
			WHEN COALESCE(e.links_rxn_rxn, 0) > 0 THEN 'MANUAL_RXN_RXN_LINK'
			WHEN i.ingredient_to_create > 0 THEN 'CREATE_INGREDIENT'
			WHEN i.nodes_to_create > 0 THEN 'CREATE_NODES'
			WHEN COALESCE(e.links_to_create, 0) > 0 THEN 'REPAIR_LINK_ONLY'
			ELSE 'ANCESTOR_REBUILD_ONLY'
		END AS scenario,
		i.nodes_to_create,
		COALESCE(e.links_to_create, 0) AS links_to_create,
		COALESCE(e.links_rxn_rxn, 0) AS links_rxn_rxn
	FROM info i
	LEFT JOIN edges e ON e.orphan_id = i.orphan_concept_id;

	-- needed nodes: closure of the repairable orphans
	DROP TABLE IF EXISTS rxegap_needed;
	CREATE UNLOGGED TABLE rxegap_needed AS
	SELECT DISTINCT m.key, MIN(m.orphan_id) AS rep_orphan_id
	FROM rxegap_member m
	JOIN rxe_gap_plan p ON p.orphan_concept_id = m.orphan_id
		AND p.scenario IN ('CREATE_INGREDIENT', 'CREATE_NODES', 'REPAIR_LINK_ONLY')
	GROUP BY m.key;

	-- review table: concepts to be created
	DROP TABLE IF EXISTS rxe_gap_new_concept;
	CREATE TABLE rxe_gap_new_concept AS
	SELECT n.key AS node_key,
		n.concept_class_id,
		n.name AS concept_name,
		n.src_concept_id AS replicated_from_concept_id,
		nd.rep_orphan_id AS representative_orphan_id,
		'node'::TEXT AS kind,
		NULL::INT AS attr_id
	FROM rxegap_node n
	JOIN rxegap_needed nd ON nd.key = n.key
	WHERE n.concept_id IS NULL AND n.canon_key IS NULL AND n.name IS NOT NULL
	UNION ALL
	SELECT NULL, na.concept_class_id, na.concept_name, na.attr_id, NULL, 'attribute', na.attr_id
	FROM rxegap_new_attr na
	WHERE na.concept_class_id <> 'Ingredient' -- Ingredients are created as nodes
		AND EXISTS (
			SELECT 1 FROM rxegap_node n JOIN rxegap_needed nd ON nd.key = n.key
			WHERE na.attr_id = ANY (n.ing_ids) OR na.attr_id IN (n.df, n.bn, n.mf)
			);

	IF pDryRun THEN
		RAISE NOTICE 'Dry run: review rxe_gap_plan and rxe_gap_new_concept. Nothing was written to the stage tables.';
		RETURN;
	END IF;

	/*****************************************
	* 8. Write the stage tables (real run)
	*****************************************/
	PERFORM set_config('application_name', 'RxEFillHierarchyGaps step 8', FALSE);
	RAISE NOTICE '% step 8', clock_timestamp();
	PERFORM vocabulary_pack.SetLatestUpdate(
		pVocabularyName => 'RxNorm Extension',
		pVocabularyDate => CURRENT_DATE,
		pVocabularyVersion => 'RxNorm Extension ' || CURRENT_DATE,
		pVocabularyDevSchema => 'DEV_RXNORM'
		);

	TRUNCATE TABLE concept_stage;
	TRUNCATE TABLE concept_relationship_stage;
	TRUNCATE TABLE concept_synonym_stage;
	TRUNCATE TABLE pack_content_stage;
	TRUNCATE TABLE drug_strength_stage;

	SELECT COALESCE(MAX(REPLACE(concept_code, 'OMOP', '')::INT4), 0) INTO iMaxOmop
	FROM concept
	WHERE concept_code ~ '^OMOP[0-9]+$';

	-- codes for new concepts: attributes first, then nodes (deepest levels first)
	DROP TABLE IF EXISTS rxegap_code;
	CREATE UNLOGGED TABLE rxegap_code AS
	SELECT ref, 'OMOP' || (iMaxOmop + ROW_NUMBER() OVER (ORDER BY ord, ref)) AS concept_code
	FROM (
		SELECT 'a' || na.attr_id AS ref, 0 AS ord FROM rxe_gap_new_concept na WHERE na.kind = 'attribute'
		UNION ALL
		SELECT 'n' || nc.node_key, 1 FROM rxe_gap_new_concept nc WHERE nc.kind = 'node'
		) s;
	CREATE UNIQUE INDEX idx_rxegap_code ON rxegap_code (ref);

	-- standard_concept follows the convention of RxNorm for each class (most frequent value among valid RxNorm concepts)
	DROP TABLE IF EXISTS rxegap_std;
	CREATE UNLOGGED TABLE rxegap_std AS
	SELECT concept_class_id,
		NULLIF(MODE() WITHIN GROUP (ORDER BY COALESCE(standard_concept, '-')), '-') AS standard_concept
	FROM concept
	WHERE vocabulary_id = 'RxNorm'
		AND invalid_reason IS NULL
		AND domain_id = 'Drug'
	GROUP BY concept_class_id;

	INSERT INTO concept_stage (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
	SELECT NULL,
		nc.concept_name,
		'Drug',
		'RxNorm Extension',
		nc.concept_class_id,
		s.standard_concept,
		cd.concept_code,
		CURRENT_DATE,
		cEND,
		NULL
	FROM rxe_gap_new_concept nc
	JOIN rxegap_code cd ON cd.ref = CASE nc.kind WHEN 'attribute' THEN 'a' || nc.attr_id ELSE 'n' || nc.node_key END
	LEFT JOIN rxegap_std s ON s.concept_class_id = nc.concept_class_id;

	-- reference table: node / attribute -> concept_code, vocabulary_id
	DROP TABLE IF EXISTS rxegap_ref;
	CREATE UNLOGGED TABLE rxegap_ref AS
	SELECT 'n' || n.key AS ref, c.concept_code, c.vocabulary_id, c.concept_class_id
	FROM rxegap_node n
	JOIN concept c ON c.concept_id = n.concept_id
	UNION ALL
	SELECT 'n' || n.key, cs.concept_code, cs.vocabulary_id, cs.concept_class_id
	FROM rxegap_node n
	JOIN rxegap_code cd ON cd.ref = 'n' || COALESCE(n.canon_key, n.key)
	JOIN concept_stage cs ON cs.concept_code = cd.concept_code
	WHERE n.concept_id IS NULL
	UNION ALL
	SELECT 'i' || c.concept_id, c.concept_code, c.vocabulary_id, c.concept_class_id
	FROM concept c
	WHERE c.concept_id IN (SELECT resolved_id FROM rxegap_res)
		AND c.concept_id NOT IN (SELECT attr_id FROM rxegap_new_attr) -- virtual attributes are replicated, not referenced
	UNION ALL
	SELECT 'i' || na.attr_id, cs.concept_code, cs.vocabulary_id, cs.concept_class_id
	FROM rxe_gap_new_concept na
	JOIN rxegap_code cd ON cd.ref = 'a' || na.attr_id
	JOIN concept_stage cs ON cs.concept_code = cd.concept_code
	WHERE na.kind = 'attribute';

	-- newly created Ingredients are referenced by their (virtual) attribute id as well
	INSERT INTO rxegap_ref
	SELECT 'i' || n.ing_ids[1], r.concept_code, r.vocabulary_id, r.concept_class_id
	FROM rxegap_node n
	JOIN rxegap_ref r ON r.ref = 'n' || n.key
	WHERE n.concept_class_id = 'Ingredient'
		AND n.concept_id IS NULL
		AND n.ing_ids[1] IN (SELECT attr_id FROM rxegap_new_attr);
	CREATE INDEX idx_rxegap_ref ON rxegap_ref (ref);

	-- hierarchy relationships (both directions) for every needed edge that does not exist yet
	INSERT INTO concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
	SELECT DISTINCT a.concept_code, b.concept_code, a.vocabulary_id, b.vocabulary_id, x.rel, CURRENT_DATE, cEND, NULL
	FROM rxegap_edge_x x
	JOIN rxegap_needed n1 ON n1.key = x.child_key
	JOIN rxegap_needed n2 ON n2.key = x.parent_key
	JOIN rxegap_ref a ON a.ref = 'n' || x.parent_key
	JOIN rxegap_ref b ON b.ref = 'n' || x.child_key
	WHERE x.status = 'NEW'
		AND (a.vocabulary_id, b.vocabulary_id) <> ('RxNorm', 'RxNorm') -- never write RxNorm-RxNorm relationships
	UNION
	SELECT DISTINCT b.concept_code, a.concept_code, b.vocabulary_id, a.vocabulary_id, r.reverse_relationship_id, CURRENT_DATE, cEND, NULL
	FROM rxegap_edge_x x
	JOIN rxegap_needed n1 ON n1.key = x.child_key
	JOIN rxegap_needed n2 ON n2.key = x.parent_key
	JOIN rxegap_ref a ON a.ref = 'n' || x.parent_key
	JOIN rxegap_ref b ON b.ref = 'n' || x.child_key
	JOIN relationship r ON r.relationship_id = x.rel
	WHERE x.status = 'NEW'
		AND (a.vocabulary_id, b.vocabulary_id) <> ('RxNorm', 'RxNorm');

	-- attribute links of the NEW concepts: dose form, brand name, supplier (+ reverse)
	INSERT INTO concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
	SELECT DISTINCT dr.concept_code, att.concept_code, dr.vocabulary_id, att.vocabulary_id, v.rel, CURRENT_DATE, cEND, NULL
	FROM rxe_gap_new_concept nc
	JOIN rxegap_node n ON n.key = nc.node_key
	JOIN rxegap_ref dr ON dr.ref = 'n' || n.key
	CROSS JOIN LATERAL (
		VALUES (n.df, cDF_REL), (n.bn, cBN_REL), (n.mf, cMF_REL)
		) v (attr_id, rel)
	JOIN rxegap_ref att ON att.ref = 'i' || v.attr_id
	WHERE nc.kind = 'node'
		AND v.attr_id <> 0
	UNION ALL
	SELECT DISTINCT att.concept_code, dr.concept_code, att.vocabulary_id, dr.vocabulary_id, r.reverse_relationship_id, CURRENT_DATE, cEND, NULL
	FROM rxe_gap_new_concept nc
	JOIN rxegap_node n ON n.key = nc.node_key
	JOIN rxegap_ref dr ON dr.ref = 'n' || n.key
	CROSS JOIN LATERAL (
		VALUES (n.df, cDF_REL), (n.bn, cBN_REL), (n.mf, cMF_REL)
		) v (attr_id, rel)
	JOIN relationship r ON r.relationship_id = v.rel
	JOIN rxegap_ref att ON att.ref = 'i' || v.attr_id
	WHERE nc.kind = 'node'
		AND v.attr_id <> 0;

	-- drug_strength_stage for new Comp / Drug / Quant / Box / Marketed Product nodes,
	-- derived from the drug_strength of the representative orphan (units and values are never invented)
	INSERT INTO drug_strength_stage (drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value, amount_unit_concept_id,
		numerator_value, numerator_unit_concept_id, denominator_value, denominator_unit_concept_id, valid_start_date, valid_end_date, invalid_reason)
	SELECT dr.concept_code,
		dr.vocabulary_id,
		ing.concept_code,
		ing.vocabulary_id,
		ds.amount_value,
		ds.amount_unit_concept_id,
		CASE
			WHEN n.q = '' AND ds.denominator_value IS NOT NULL AND ds.numerator_unit_concept_id NOT IN (8554, 9325, 9324) AND ds.numerator_value > 0
				THEN ROUND(ds.numerator_value / ds.denominator_value, GREATEST(0, 2 - FLOOR(LOG(ds.numerator_value / ds.denominator_value))::INT))
			ELSE ds.numerator_value
		END,
		ds.numerator_unit_concept_id,
		CASE WHEN n.q = '' THEN NULL ELSE ds.denominator_value END,
		ds.denominator_unit_concept_id,
		CURRENT_DATE,
		cEND,
		NULL
	FROM rxe_gap_new_concept nc
	JOIN rxegap_node n ON n.key = nc.node_key
	JOIN rxegap_ref dr ON dr.ref = 'n' || n.key
	JOIN rxegap_ds_raw ds ON ds.drug_concept_id = nc.representative_orphan_id
	JOIN rxegap_ref ing ON ing.ref = 'i' || COALESCE((SELECT resolved_id FROM rxegap_res WHERE attr_id = ds.ingredient_concept_id), ds.ingredient_concept_id)
	WHERE nc.kind = 'node'
		AND n.concept_class_id NOT IN ('Ingredient', 'Clinical Drug Form', 'Branded Drug Form') -- built by pConceptAncestor
		AND COALESCE((SELECT resolved_id FROM rxegap_res WHERE attr_id = ds.ingredient_concept_id), ds.ingredient_concept_id) = ANY (n.ing_ids);

	ANALYZE concept_stage;
	ANALYZE concept_relationship_stage;
	ANALYZE drug_strength_stage;

	-- the usual mapping pipeline for the new concepts
	PERFORM vocabulary_pack.CheckReplacementMappings();
	PERFORM vocabulary_pack.AddFreshMAPSTO();
	PERFORM vocabulary_pack.DeprecateWrongMAPSTO();

	-- clean up
	DROP TABLE rxegap_orphan, rxegap_rl, rxegap_ds_raw, rxegap_attr_ids, rxegap_res, rxegap_new_attr, rxegap_ds, rxegap_attr,
		rxegap_attrname, rxegap_node, rxegap_edge, rxegap_cand, rxegap_seed, rxegap_uname, rxegap_member, rxegap_edge_x,
		rxegap_needed, rxegap_code, rxegap_std, rxegap_ref;
END;
$BODY$;

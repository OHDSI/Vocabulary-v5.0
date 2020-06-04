CREATE OR REPLACE FUNCTION vocabulary_pack.pConceptAncestor (
  is_small BOOLEAN = FALSE
)
RETURNS void AS
$BODY$
DECLARE
  iVocabularies VARCHAR(1000) [ ];
  crlf VARCHAR (4) := '<br>';
  iSmallCA_emails CONSTANT VARCHAR(1000) :=(SELECT var_value FROM devv5.config$ WHERE var_name='concept_ancestor_email');
  cRet TEXT;
  cRet2 TEXT;
  cCAGroups INT:=50;
  cRecord RECORD;
  cStartTime TIMESTAMP;
  cWorkTime NUMERIC;
BEGIN
	cStartTime:=clock_timestamp();

	IF is_small THEN 
		iVocabularies:=ARRAY['RxNorm','RxNorm Extension','ATC','NFC','EphMRA ATC','CVX'];
	END IF;

	--materialize main query
	DROP TABLE IF EXISTS temporary_ca_base$;
	EXECUTE'
		CREATE UNLOGGED TABLE temporary_ca_base$ AS
		SELECT r.concept_id_1 AS ancestor_concept_id,
			r.concept_id_2 AS descendant_concept_id,
			CASE 
				WHEN s.is_hierarchical = 1
					AND c1.standard_concept IS NOT NULL
					THEN 1
				ELSE 0
				END AS levels_of_separation
		FROM concept_relationship r
		JOIN relationship s ON s.relationship_id = r.relationship_id
			AND s.defines_ancestry = 1
		JOIN concept c1 ON c1.concept_id = r.concept_id_1
			AND c1.invalid_reason IS NULL
			AND (
				c1.vocabulary_id = ANY ($1)
				OR $1 IS NULL
				)
		JOIN concept c2 ON c2.concept_id = r.concept_id_2
			AND c2.invalid_reason IS NULL
			AND (
				c2.vocabulary_id = ANY ($1)
				OR $1 IS NULL
				)
		WHERE r.invalid_reason IS NULL' USING iVocabularies;
	CREATE INDEX idx_temp_ca_base$ ON temporary_ca_base$ (ancestor_concept_id,descendant_concept_id,levels_of_separation);
	ANALYZE temporary_ca_base$;

	DROP TABLE IF EXISTS temporary_ca_groups$;
	EXECUTE'
		CREATE TABLE temporary_ca_groups$ AS
		SELECT s1.n,
			COALESCE(LAG(s1.ancestor_concept_id) OVER (
					ORDER BY s1.n
					), - 1) ancestor_concept_id_min,
			ancestor_concept_id ancestor_concept_id_max
		FROM (
			SELECT n,
				MAX(ancestor_concept_id) ancestor_concept_id
			FROM (
				SELECT NTILE($1) OVER (
						ORDER BY ancestor_concept_id
						) n,
					ancestor_concept_id
				FROM temporary_ca_base$
				) AS s0
			GROUP BY n
			) AS s1' USING cCAGroups;

	DROP TABLE IF EXISTS temporary_ca$;
	CREATE UNLOGGED TABLE temporary_ca$ (LIKE concept_ancestor);
	FOR cRecord IN (SELECT * FROM temporary_ca_groups$ ORDER BY n) LOOP
		EXECUTE '
			INSERT INTO temporary_ca$
			WITH recursive hierarchy_concepts(ancestor_concept_id, descendant_concept_id, root_ancestor_concept_id, levels_of_separation, full_path) AS (
					SELECT ancestor_concept_id,
						descendant_concept_id,
						ancestor_concept_id AS root_ancestor_concept_id,
						levels_of_separation,
						ARRAY [descendant_concept_id] AS full_path
					FROM temporary_ca_base$
					WHERE ancestor_concept_id > $1
						AND ancestor_concept_id <= $2
					
					UNION ALL
					
					SELECT c.ancestor_concept_id,
						c.descendant_concept_id,
						root_ancestor_concept_id,
						hc.levels_of_separation + c.levels_of_separation AS levels_of_separation,
						hc.full_path || c.descendant_concept_id AS full_path
					FROM temporary_ca_base$ c
					JOIN hierarchy_concepts hc ON hc.descendant_concept_id = c.ancestor_concept_id
					WHERE c.descendant_concept_id <> ALL (full_path)
					)
			SELECT hc.root_ancestor_concept_id AS ancestor_concept_id,
				hc.descendant_concept_id,
				MIN(hc.levels_of_separation) AS min_levels_of_separation,
				MAX(hc.levels_of_separation) AS max_levels_of_separation
			FROM hierarchy_concepts hc
			JOIN concept c1 ON c1.concept_id = hc.root_ancestor_concept_id
				AND c1.standard_concept IS NOT NULL
			JOIN concept c2 ON c2.concept_id = hc.descendant_concept_id
				AND c2.standard_concept IS NOT NULL
			GROUP BY hc.root_ancestor_concept_id,
				hc.descendant_concept_id' USING cRecord.ancestor_concept_id_min, cRecord.ancestor_concept_id_max;
		--PERFORM devv5.SendMailHTML ('timur.vakhitov@firstlinesoftware.com', '[DEBUG] concept ancestor iteration='||cRecord.n, '[DEBUG] concept ancestor iteration='||cRecord.n||' of '||cCAGroups);
	END LOOP;

	TRUNCATE TABLE concept_ancestor;
	ALTER TABLE concept_ancestor DROP CONSTRAINT IF EXISTS xpkconcept_ancestor;
	DROP INDEX IF EXISTS idx_ca_descendant;
	INSERT INTO concept_ancestor SELECT * FROM temporary_ca$;

	--Cleaning
	DROP TABLE temporary_ca$;
	DROP TABLE temporary_ca_groups$;
	DROP TABLE temporary_ca_base$;

	--Add connections to self for those vocabs having at least one concept in the concept_relationship table
	INSERT INTO concept_ancestor
	SELECT c.concept_id AS ancestor_concept_id,
		c.concept_id AS descendant_concept_id,
		0 AS min_levels_of_separation,
		0 AS max_levels_of_separation
	FROM concept c
	WHERE c.vocabulary_id IN (
			SELECT c_int.vocabulary_id
			FROM concept_relationship cr,
				concept c_int
			WHERE c_int.concept_id = cr.concept_id_1
				AND cr.invalid_reason IS NULL
			)
		AND c.invalid_reason IS NULL
		AND c.standard_concept IS NOT NULL;

	ALTER TABLE concept_ancestor ADD CONSTRAINT xpkconcept_ancestor PRIMARY KEY (
		ancestor_concept_id,
		descendant_concept_id
		);
	CREATE INDEX idx_ca_descendant ON concept_ancestor (descendant_concept_id);
	ANALYZE concept_ancestor;


	--preparing postprocessing (new ATC logic, part 1)
	--Create a local copy only for RxNorm and RxNorm Extension
	DROP TABLE IF EXISTS concept_ancestor_rx$;
	CREATE UNLOGGED TABLE concept_ancestor_rx$ (LIKE concept_ancestor);

	INSERT INTO concept_ancestor_rx$
	SELECT ca.*
	FROM concept_ancestor ca
	JOIN concept an ON an.concept_id = ca.ancestor_concept_id
		AND an.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			)
	JOIN concept de ON de.concept_id = ca.descendant_concept_id
		AND de.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			);

	CREATE INDEX idx_temp_ca_rx$ ON concept_ancestor_rx$ (ancestor_concept_id,descendant_concept_id);
	ANALYZE concept_ancestor_rx$;

	--postprocessing (OLD version)
	DROP TABLE IF EXISTS jump_table;
	CREATE UNLOGGED TABLE jump_table AS
	SELECT DISTINCT /* there are many redundant pairs*/
		dc.concept_id AS class_concept_id,
		rxn.concept_id AS rxn_concept_id
	FROM concept_ancestor class_rxn
	--get all hierarchical relationships between concepts 'C' ...
	JOIN concept dc ON dc.concept_id = class_rxn.ancestor_concept_id
		AND dc.standard_concept = CASE 
			WHEN dc.vocabulary_id = 'CVX'
				THEN 'S'
			ELSE 'C'
			END
		AND dc.domain_id = 'Drug'
		AND dc.concept_class_id NOT IN (
			'Dose Form Group',
			'Clinical Dose Group',
			'Branded Dose Group'
			)
	--... and 'S'
	JOIN concept rxn ON rxn.concept_id = class_rxn.descendant_concept_id
		AND rxn.standard_concept = 'S'
		AND rxn.domain_id = 'Drug'
		AND rxn.vocabulary_id = 'RxNorm';

	CREATE INDEX idx_jump_table ON jump_table (rxn_concept_id,class_concept_id);
	ANALYZE jump_table;

	DROP TABLE IF EXISTS excluded_concepts;
	CREATE UNLOGGED TABLE excluded_concepts AS
	SELECT ca.descendant_concept_id,
		j.class_concept_id
	FROM jump_table j
	--connect all concepts inside the rxn hierachy. Some of them might be above the jump
	JOIN concept_ancestor ca ON ca.ancestor_concept_id = j.rxn_concept_id
		AND ca.ancestor_concept_id <> ca.descendant_concept_id;

	CREATE INDEX idx_excluded_concepts ON excluded_concepts (descendant_concept_id,class_concept_id);
	ANALYZE excluded_concepts;

	DROP TABLE IF EXISTS pair_tbl;
	CREATE UNLOGGED TABLE pair_tbl AS
	SELECT DISTINCT j.class_concept_id,
		rxn_up.concept_id AS rxn_concept_id,
		j.rxn_concept_id AS jump_rxn_concept_id
	FROM jump_table j
	JOIN concept_ancestor in_rxn ON in_rxn.descendant_concept_id = j.rxn_concept_id
	JOIN concept rxn_up ON rxn_up.concept_id = in_rxn.ancestor_concept_id
		AND rxn_up.standard_concept = 'S'
		AND rxn_up.domain_id = 'Drug'
		AND rxn_up.vocabulary_id = 'RxNorm'
	WHERE NOT EXISTS (
			SELECT 1
			FROM excluded_concepts ec
			WHERE ec.descendant_concept_id = j.rxn_concept_id
				AND ec.class_concept_id = j.class_concept_id
			);

	CREATE INDEX idx_pair ON pair_tbl (class_concept_id);
	ANALYZE pair_tbl;

	--Update existing records and add missing relationships between concepts for RxNorm/RxE
	WITH t_bottom
	AS (
		SELECT ca.ancestor_concept_id,
			MAX(ca.min_levels_of_separation) AS min_levels_of_separation,
			MAX(ca.max_levels_of_separation) AS max_levels_of_separation
		FROM concept_ancestor ca
		JOIN concept c ON c.concept_id = ca.descendant_concept_id
			AND c.standard_concept = CASE 
				WHEN c.vocabulary_id = 'CVX'
					THEN 'S'
				ELSE 'C'
				END
			AND c.domain_id = 'Drug'
			AND c.concept_class_id NOT IN (
				'Dose Form Group',
				'Clinical Dose Group',
				'Branded Dose Group'
				)
		GROUP BY ancestor_concept_id
		),
	to_be_upserted
	AS (
		SELECT pair.class_concept_id AS ancestor_concept_id, --concept in drug class
			pair.rxn_concept_id AS descendant_concept_id, --concept in RxNorm hierarchy above cross-over from class to RxNorm (jump)
			--direct relationship from ATC4 to Ingredient and no relationship to corresponding ATC5 gives min_level_of_separation = 0, but should be '1'
			MIN(to_bottom.min_levels_of_separation + CASE 
					WHEN c.concept_class_id = 'ATC 4th'
						THEN 1
					ELSE to_ing.min_levels_of_separation
					END) AS min_levels_of_separation, --levels in class plus the distance from ingredient to RxNorm concept
			MAX(to_bottom.max_levels_of_separation + CASE 
					WHEN c.concept_class_id = 'ATC 4th'
						THEN 1
					ELSE to_ing.max_levels_of_separation
					END) AS max_levels_of_separation
		FROM pair_tbl pair
		--get distance from class concept to lowest possible class concept
		JOIN t_bottom to_bottom ON to_bottom.ancestor_concept_id = pair.class_concept_id
		--get distance from rxn concept to highest possible (Ingredient) rxn concept
		JOIN concept_ancestor to_ing ON to_ing.descendant_concept_id = pair.rxn_concept_id
		JOIN concept c ON c.concept_id = pair.class_concept_id
		JOIN concept ing ON ing.concept_id = to_ing.ancestor_concept_id
			AND ing.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				) --and ing.concept_class_id='Ingredient'
			AND ing.concept_class_id = CASE 
				WHEN c.vocabulary_id IN (
						'ATC',
						'CVX'
						)
					AND (
						SELECT COUNT(*)
						FROM (
							SELECT r.concept_id_1,
								r.concept_id_2
							FROM concept_relationship r
							JOIN concept c_int ON c_int.concept_id = r.concept_id_2
								AND c_int.vocabulary_id LIKE 'RxNorm%'
								AND c_int.concept_class_id = 'Ingredient'
								AND c_int.invalid_reason IS NULL
							WHERE r.invalid_reason IS NULL
								AND r.concept_id_1 = pair.jump_rxn_concept_id
							
							UNION
							
							SELECT ds.drug_concept_id,
								ds.ingredient_concept_id
							FROM drug_strength ds
							WHERE ds.invalid_reason IS NULL
								AND ds.drug_concept_id = pair.jump_rxn_concept_id
							) AS s0
						) > 1
					THEN 'Clinical Drug Form'
				ELSE 'Ingredient'
				END
		GROUP BY pair.class_concept_id,
			pair.rxn_concept_id
		),
	to_be_updated
	AS (
		UPDATE concept_ancestor ca
		SET min_levels_of_separation = up.min_levels_of_separation,
			max_levels_of_separation = up.max_levels_of_separation
		FROM to_be_upserted up
		WHERE ca.ancestor_concept_id = up.ancestor_concept_id
			AND ca.descendant_concept_id = up.descendant_concept_id
		RETURNING ca.*
		)
	INSERT INTO concept_ancestor
	SELECT tpu.*
	FROM to_be_upserted tpu
	WHERE (
			tpu.ancestor_concept_id,
			tpu.descendant_concept_id
			) NOT IN (
			SELECT up.ancestor_concept_id,
				up.descendant_concept_id
			FROM to_be_updated up
			);
	ANALYZE concept_ancestor;

	--postprocessing (new ATC logic, part 2)
	PERFORM vocabulary_pack.ATCPostProcessing();
	--merge results
	--update
	UPDATE concept_ancestor ca
	SET min_levels_of_separation = caa.min_levels_of_separation,
		max_levels_of_separation = caa.max_levels_of_separation
	FROM concept_ancestor_add$ caa
	WHERE caa.ancestor_concept_id = ca.ancestor_concept_id
		AND caa.descendant_concept_id = ca.descendant_concept_id
		AND (
			caa.min_levels_of_separation <> ca.min_levels_of_separation
			OR caa.max_levels_of_separation <> ca.max_levels_of_separation
			);
	--insert
	INSERT INTO concept_ancestor
	SELECT *
	FROM concept_ancestor_add$ caa
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_ancestor ca_int
			WHERE ca_int.ancestor_concept_id = caa.ancestor_concept_id
				AND ca_int.descendant_concept_id = caa.descendant_concept_id
			);

	DROP TABLE concept_ancestor_add$;
	ANALYZE concept_ancestor;

	--replace all RxNorm internal links so only "neighbor" concepts are connected
	--create table with neighbor relationships  
	DROP TABLE IF EXISTS rxnorm_allowed_rel;
	CREATE UNLOGGED TABLE rxnorm_allowed_rel AS
	SELECT * FROM (
		WITH t as (
			SELECT 'Brand Name' c_class_1, 'Brand name of' relationship_id, 'Branded Drug Box' c_class_2 UNION ALL
			SELECT 'Brand Name', 'Brand name of', 'Branded Drug Comp' UNION ALL
			SELECT 'Brand Name', 'Brand name of', 'Branded Drug Form' UNION ALL
			SELECT 'Brand Name', 'Brand name of', 'Branded Drug' UNION ALL
			SELECT 'Brand Name', 'Brand name of', 'Branded Pack' UNION ALL
			SELECT 'Brand Name', 'Brand name of', 'Branded Pack Box' UNION ALL
			SELECT 'Brand Name', 'Brand name of', 'Marketed Product' UNION ALL
			SELECT 'Brand Name', 'Brand name of', 'Quant Branded Box' UNION ALL
			SELECT 'Brand Name', 'Brand name of', 'Quant Branded Drug' UNION ALL
			SELECT 'Branded Drug Box', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Branded Drug Box', 'Has quantified form', 'Quant Branded Box' UNION ALL
			SELECT 'Branded Drug Comp', 'Constitutes', 'Branded Drug' UNION ALL
			SELECT 'Branded Drug Form', 'RxNorm inverse is a', 'Branded Drug' UNION ALL
			SELECT 'Branded Drug', 'Available as box', 'Branded Drug Box' UNION ALL
			SELECT 'Branded Drug', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Branded Drug', 'Has quantified form', 'Quant Branded Drug' UNION ALL
			SELECT 'Clinical Drug Box', 'Has marketed form', 'Marketed Product' union
			SELECT 'Clinical Drug Box', 'Has quantified form', 'Quant Clinical Box' UNION ALL
			SELECT 'Clinical Drug Box', 'Has tradename', 'Branded Drug Box' UNION ALL
			SELECT 'Clinical Drug Comp', 'Constitutes', 'Clinical Drug' UNION ALL
			SELECT 'Clinical Drug Comp', 'Has tradename', 'Branded Drug Comp' UNION ALL
			SELECT 'Clinical Drug Form', 'Has tradename', 'Branded Drug Form' UNION ALL
			SELECT 'Clinical Drug Form', 'RxNorm inverse is a', 'Clinical Drug' UNION ALL
			SELECT 'Clinical Drug', 'Available as box', 'Clinical Drug Box' UNION ALL
			SELECT 'Clinical Drug', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Clinical Drug', 'Has quantified form', 'Quant Clinical Drug' UNION ALL
			SELECT 'Clinical Drug', 'Has tradename', 'Branded Drug' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug Box' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug Form' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Pack' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Box' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Form' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Pack' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Marketed Product' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Branded Box' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Branded Drug' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Box' UNION ALL
			SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Drug' UNION ALL
			SELECT 'Ingredient', 'Has brand name', 'Brand Name' UNION ALL
			SELECT 'Ingredient', 'RxNorm ing of', 'Clinical Drug Comp' UNION ALL
			SELECT 'Ingredient', 'RxNorm ing of', 'Clinical Drug Form' UNION ALL
			SELECT 'Marketed Product', 'Has marketed form', 'Marketed Product' UNION ALL 
			SELECT 'Supplier', 'Supplier of', 'Marketed Product' UNION ALL
			SELECT 'Quant Branded Box', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Quant Branded Drug', 'Available as box', 'Quant Branded Box' UNION ALL
			SELECT 'Quant Branded Drug', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Quant Clinical Box', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Quant Clinical Box', 'Has tradename', 'Quant Branded Box' UNION ALL
			SELECT 'Quant Clinical Drug', 'Available as box', 'Quant Clinical Box' UNION ALL
			SELECT 'Quant Clinical Drug', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Quant Clinical Drug', 'Has tradename', 'Quant Branded Drug' UNION ALL
			--new relationships 20170412
			SELECT 'Branded Dose Group', 'Has brand name', 'Brand Name' UNION ALL
			SELECT 'Branded Dose Group', 'Has dose form group', 'Dose Form Group' UNION ALL
			SELECT 'Branded Dose Group', 'Marketed form of', 'Dose Form Group' UNION ALL
			SELECT 'Branded Dose Group', 'RxNorm has ing', 'Brand Name' UNION ALL
			SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Branded Drug Form' UNION ALL
			SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Branded Drug' UNION ALL
			SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Quant Branded Drug' UNION ALL
			SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Quant Clinical Drug' UNION ALL
			SELECT 'Branded Dose Group', 'Tradename of', 'Clinical Dose Group' UNION ALL
			SELECT 'Clinical Dose Group', 'Has dose form group', 'Dose Form Group' UNION ALL
			SELECT 'Clinical Dose Group', 'Marketed form of', 'Dose Form Group' UNION ALL
			SELECT 'Clinical Dose Group', 'RxNorm has ing', 'Ingredient' UNION ALL
			SELECT 'Clinical Dose Group', 'RxNorm has ing', 'Precise Ingredient' UNION ALL
			SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Clinical Drug Form' UNION ALL
			SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Clinical Drug' UNION ALL
			SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Quant Branded Drug' UNION ALL
			SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Quant Clinical Drug' UNION ALL
			SELECT 'Dose Form Group', 'RxNorm inverse is a', 'Dose Form' UNION ALL
			--added 24.04.2017 (AVOF-341)
			SELECT 'Precise Ingredient', 'Form of', 'Ingredient' UNION ALL
			--added 13.07.2017 (AVOF-468)
			SELECT 'Clinical Drug', 'Contained in', 'Clinical Pack' UNION ALL
			SELECT 'Clinical Drug', 'Contained in', 'Clinical Pack Box' UNION ALL
			SELECT 'Clinical Drug', 'Contained in', 'Branded Pack' UNION ALL
			SELECT 'Clinical Drug', 'Contained in', 'Branded Pack Box' UNION ALL
			SELECT 'Clinical Drug', 'Contained in', 'Marketed Product' UNION ALL
			SELECT 'Branded Drug', 'Contained in', 'Branded Pack' UNION ALL
			SELECT 'Branded Drug', 'Contained in', 'Branded Pack Box' UNION ALL
			SELECT 'Branded Drug', 'Contained in', 'Marketed Product' UNION ALL
			SELECT 'Quant Clinical Drug', 'Contained in', 'Clinical Pack' UNION ALL
			SELECT 'Quant Clinical Drug', 'Contained in', 'Clinical Pack Box' UNION ALL
			SELECT 'Quant Clinical Drug', 'Contained in', 'Branded Pack' UNION ALL
			SELECT 'Quant Clinical Drug', 'Contained in', 'Branded Pack Box' UNION ALL
			SELECT 'Quant Clinical Drug', 'Contained in', 'Marketed Product' UNION ALL
			SELECT 'Quant Branded Drug', 'Contained in', 'Branded Pack' UNION ALL
			SELECT 'Quant Branded Drug', 'Contained in', 'Branded Pack Box' UNION ALL
			SELECT 'Quant Branded Drug', 'Contained in', 'Marketed Product' UNION ALL
			--inner-pack relationship
			SELECT 'Branded Pack', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Branded Pack Box', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Branded Pack', 'Available as box', 'Branded Pack Box' UNION ALL
			SELECT 'Clinical Pack', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Clinical Pack Box', 'Has marketed form', 'Marketed Product' UNION ALL
			SELECT 'Clinical Pack', 'Has tradename', 'Branded Pack' UNION ALL
			SELECT 'Clinical Pack', 'Available as box', 'Clinical Pack Box' UNION ALL
			SELECT 'Clinical Pack Box', 'Has tradename', 'Branded Pack Box'
		) 
	SELECT * FROM t 
	UNION ALL 
	--add reverse
	SELECT c_class_2, r.reverse_relationship_id, c_class_1 FROM t rra, relationship r
	WHERE rra.relationship_id=r.relationship_id
	) AS s1;

--create table with wrong relationships (non-neighbor relationships)
	DROP TABLE IF EXISTS rxnorm_wrong_rel;
	CREATE UNLOGGED TABLE rxnorm_wrong_rel AS
	SELECT c1.concept_class_id,
		r.concept_id_1,
		r.concept_id_2,
		r.relationship_id
	FROM concept c1,
		concept c2,
		concept_relationship r
	WHERE c1.concept_id = r.concept_id_1
		AND c2.concept_id = r.concept_id_2
		AND r.invalid_reason IS NULL
		AND c1.vocabulary_id = 'RxNorm'
		AND c2.vocabulary_id = 'RxNorm'
		AND r.relationship_id NOT IN (
			'Maps to',
			'Precise ing of',
			'Has precise ing',
			'Concept replaces',
			'Mapped from',
			'Concept replaced by'
			)
		AND (
			c1.concept_class_id NOT LIKE '%Pack'
			OR c2.concept_class_id NOT LIKE '%Pack'
			)
		AND (
			c1.concept_class_id,
			c2.concept_class_id
			) NOT IN (
			SELECT c_class_1,
				c_class_2
			FROM rxnorm_allowed_rel
			);

	--add missing neighbor relationships (if not exists)
	WITH neighbor_relationships
	AS (
		SELECT ca1.ancestor_concept_id c_id1,
			ca2.ancestor_concept_id c_id2,
			rra.relationship_id
		FROM rxnorm_wrong_rel wr,
			concept_ancestor ca1,
			concept_ancestor ca2,
			rxnorm_allowed_rel rra,
			concept c_dest
		WHERE ca1.descendant_concept_id = ca2.ancestor_concept_id
			AND ca1.ancestor_concept_id = wr.concept_id_1
			AND ca2.descendant_concept_id = wr.concept_id_2
			AND ca2.ancestor_concept_id <> ca2.descendant_concept_id
			AND ca2.ancestor_concept_id <> ca1.ancestor_concept_id
			AND c_dest.concept_id = ca2.ancestor_concept_id
			AND rra.c_class_1 = wr.concept_class_id
			AND rra.c_class_2 = c_dest.concept_class_id
		)
	INSERT INTO concept_relationship
	SELECT nr.c_id1,
		nr.c_id2,
		nr.relationship_id,
		CURRENT_DATE,
		TO_DATE('20991231', 'YYYYMMDD'),
		NULL AS invalid_reason
	FROM neighbor_relationships nr
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship cr_int
			WHERE cr_int.concept_id_1 = nr.c_id1
				AND cr_int.concept_id_2 = nr.c_id2
				AND cr_int.relationship_id = nr.relationship_id
			);

	--deprecate wrong relationships
	UPDATE concept_relationship cr
	SET valid_end_date = CURRENT_DATE,
		invalid_reason = 'D'
	FROM rxnorm_wrong_rel w
	WHERE cr.concept_id_1 = w.concept_id_1
		AND cr.concept_id_2 = w.concept_id_2
		AND cr.relationship_id = w.relationship_id
		AND cr.invalid_reason IS NULL;

	--create direct links between Branded* and Brand Names
	WITH to_be_upserted
	AS (
		SELECT DISTINCT c1.concept_id AS concept_id_1,
			c2.concept_id AS concept_id_2,
			'Has brand name' AS relationship_id,
			CURRENT_DATE AS valid_start_date,
			TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
			NULL AS invalid_reason
		FROM concept_ancestor ca,
			concept_relationship r,
			concept c1,
			concept c2,
			concept c3
		WHERE ca.ancestor_concept_id = r.concept_id_1
			AND r.invalid_reason IS NULL
			AND relationship_id = 'Has brand name'
			AND ca.descendant_concept_id = c1.concept_id
			AND c1.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND c1.concept_class_id IN (
				'Branded Drug Box',
				'Quant Branded Box',
				'Branded Drug Comp',
				'Quant Branded Drug',
				'Branded Drug Form',
				'Branded Drug',
				'Marketed Product'
				)
			AND r.concept_id_2 = c2.concept_id
			AND c2.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND c2.concept_class_id = 'Brand Name'
			AND c2.invalid_reason IS NULL
			AND c3.concept_id = r.concept_id_1
			AND c3.concept_class_id <> 'Ingredient'
		),
	to_be_updated
	AS (
		UPDATE concept_relationship cr
		SET invalid_reason = NULL,
			valid_end_date = up.valid_end_date
		FROM to_be_upserted up
		WHERE cr.concept_id_1 = up.concept_id_1
			AND cr.concept_id_2 = up.concept_id_2
			AND cr.relationship_id = up.relationship_id 
		RETURNING cr.*
		)
	INSERT INTO concept_relationship
	SELECT tpu.*
	FROM to_be_upserted tpu
	WHERE (
			tpu.concept_id_1,
			tpu.concept_id_2,
			tpu.relationship_id
			) NOT IN (
			SELECT up.concept_id_1,
				up.concept_id_2,
				up.relationship_id
			FROM to_be_updated up
			);

	--reverse
	WITH to_be_upserted
	AS (
		SELECT DISTINCT c1.concept_id AS concept_id_1,
			c2.concept_id AS concept_id_2,
			'Brand name of' AS relationship_id,
			CURRENT_DATE AS valid_start_date,
			TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
			NULL AS invalid_reason
		FROM concept_ancestor ca,
			concept_relationship r,
			concept c1,
			concept c2,
			concept c3
		WHERE ca.ancestor_concept_id = r.concept_id_2
			AND r.invalid_reason IS NULL
			AND relationship_id = 'Brand name of'
			AND ca.descendant_concept_id = c2.concept_id
			AND c2.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND c2.concept_class_id IN (
				'Branded Drug Box',
				'Quant Branded Box',
				'Branded Drug Comp',
				'Quant Branded Drug',
				'Branded Drug Form',
				'Branded Drug',
				'Marketed Product'
				)
			AND r.concept_id_1 = c1.concept_id
			AND c1.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND c1.concept_class_id = 'Brand Name'
			AND c1.invalid_reason IS NULL
			AND c3.concept_id = r.concept_id_2
			AND c3.concept_class_id <> 'Ingredient'
		),
	to_be_updated
	AS (
		UPDATE concept_relationship cr
		SET invalid_reason = NULL,
			valid_end_date = up.valid_end_date
		FROM to_be_upserted up
		WHERE cr.concept_id_1 = up.concept_id_1
			AND cr.concept_id_2 = up.concept_id_2
			AND cr.relationship_id = up.relationship_id
		RETURNING cr.*
		)
	INSERT INTO concept_relationship
	SELECT tpu.*
	FROM to_be_upserted tpu
	WHERE (
			tpu.concept_id_1,
			tpu.concept_id_2,
			tpu.relationship_id
			) NOT IN (
			SELECT up.concept_id_1,
				up.concept_id_2,
				up.relationship_id
			FROM to_be_updated up
			);

--section for units of ingredients and drug forms. this is after the RxNorm and RxNorm Extensions are in there (AVOF-365)
	DELETE
	FROM drug_strength
	WHERE amount_unit_concept_id IS NOT NULL
		AND amount_value IS NULL;

	INSERT INTO drug_strength
	SELECT *
	FROM (
		WITH ingredient_unit AS (
				SELECT DISTINCT
					--pick the most common unit for an ingredient. If there is a draw, pick always the same by sorting by unit_concept_id
					ingredient_concept_id,
					FIRST_VALUE(unit_concept_id) OVER (
						PARTITION BY ingredient_concept_id ORDER BY cnt DESC,
							unit_concept_id
						) AS unit_concept_id
				FROM (
					--sum the counts coming from amount and numerator
					SELECT ingredient_concept_id,
						unit_concept_id,
						SUM(cnt) AS cnt
					FROM (
						--count ingredients, their units and the frequency
						SELECT c2.concept_id AS ingredient_concept_id,
							ds.amount_unit_concept_id AS unit_concept_id,
							COUNT(*) AS cnt
						FROM drug_strength ds
						JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
							AND c1.vocabulary_id IN (
								'RxNorm',
								'RxNorm Extension'
								)
						JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
							AND c2.vocabulary_id IN (
								'RxNorm',
								'RxNorm Extension'
								)
						WHERE ds.amount_value <> 0
							AND ds.amount_unit_concept_id IS NOT NULL
						GROUP BY c2.concept_id,
							ds.amount_unit_concept_id
						
						UNION ALL
						
						SELECT c2.concept_id AS ingredient_concept_id,
							ds.numerator_unit_concept_id AS unit_concept_id,
							COUNT(*) AS cnt
						FROM drug_strength ds
						JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
							AND c1.vocabulary_id IN (
								'RxNorm',
								'RxNorm Extension'
								)
						JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
							AND c2.vocabulary_id IN (
								'RxNorm',
								'RxNorm Extension'
								)
						WHERE ds.numerator_value <> 0
							AND ds.numerator_unit_concept_id IS NOT NULL
						GROUP BY c2.concept_id,
							ds.numerator_unit_concept_id
						
						UNION ALL
						
						--add ingredients that exist in the vocabularies and have no drug_strength record. Default to "mg" (AVOF-1425 20190121)
						SELECT c.concept_id AS ingredient_concept_id,
							8576 AS unit_concept_id,
							1 AS cnt
						FROM concept c
						WHERE c.vocabulary_id IN (
								'RxNorm',
								'RxNorm Extension'
								)
							AND c.concept_class_id = 'Ingredient'
							AND NOT EXISTS (
								SELECT 1
								FROM drug_strength ds
								WHERE ds.drug_concept_id = c.concept_id
								)
						) AS s1
					GROUP BY ingredient_concept_id,
						unit_concept_id
					) AS s2
				)
		--Create drug_strength for ingredients
		SELECT c.concept_id AS drug_concept_id,
			c.concept_id AS ingredient_concept_id,
			NULL::FLOAT AS amount_value,
			iu.unit_concept_id AS amount_unit_concept_id,
			NULL::FLOAT AS numerator_value,
			NULL::INT4 AS numerator_unit_concept_id,
			NULL::FLOAT AS denominator_value,
			NULL::INT4 AS denominator_unit_concept_id,
			NULL::INT4 AS box_size,
			c.valid_start_date,
			c.valid_end_date,
			c.invalid_reason
		FROM ingredient_unit iu
		JOIN concept c ON c.concept_id = iu.ingredient_concept_id
		
		UNION ALL
		
		--Create drug_strength for drug forms
		SELECT de.concept_id AS drug_concept_id,
			an.concept_id AS ingredient_concept_id,
			NULL AS amount_value,
			iu.unit_concept_id AS amount_unit_concept_id,
			NULL AS numerator_value,
			NULL AS numerator_unit_concept_id,
			NULL AS denominator_value,
			NULL AS denominator_unit_concept_id,
			NULL AS box_size,
			an.valid_start_date,
			an.valid_end_date,
			an.invalid_reason
		FROM concept an
		JOIN concept_ancestor a ON a.ancestor_concept_id = an.concept_id
		JOIN concept de ON de.concept_id = a.descendant_concept_id
		JOIN ingredient_unit iu ON iu.ingredient_concept_id = an.concept_id
		WHERE an.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND an.concept_class_id = 'Ingredient'
			AND de.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND de.concept_class_id IN (
				'Clinical Drug Form',
				'Branded Drug Form'
				)
		) AS s3;

	--clean up
	DROP TABLE jump_table;
	DROP TABLE excluded_concepts;
	DROP TABLE pair_tbl;
	DROP TABLE rxnorm_allowed_rel;
	DROP TABLE rxnorm_wrong_rel;
	ANALYZE drug_strength;

	IF is_small THEN
		cWorkTime:=ROUND(EXTRACT(EPOCH FROM clock_timestamp()-cStartTime)::NUMERIC/60,1);
		PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Small concept ancestor in '||UPPER(current_schema)||' [ok]', 'Small concept ancestor in '||UPPER(current_schema)||' completed'||crlf||'Execution time: '||cWorkTime||' min');
	END IF;

	EXCEPTION WHEN OTHERS THEN
	IF is_small THEN
		GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT, cRet2 = PG_EXCEPTION_DETAIL;
		cRet:='ERROR: '||SQLERRM||crlf||'DETAIL: '||cRet2||crlf||'CONTEXT: '||regexp_replace(cRet, '\r|\n|\r\n', crlf, 'g');
		cRet := SUBSTR ('Small concept ancestor completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 5000);
		PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Small concept ancestor in '||upper(current_schema)||' [error]', cRet);
	ELSE
		RAISE;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
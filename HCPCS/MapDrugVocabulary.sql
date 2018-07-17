/**************************************************
* Th  is script takes a drug vocabulary q and     *
* compares it to the existing drug vocabulary r   *
* The new vocabulary must be provided in the same *
* format as for generating a new drug vocabulary: *
* http://www.ohdsi.org/web/wiki/doku.php?id=documentation:international_drugs *
* As a result it creates records in the           *
* concept_relationship_stage table                *
*                                                 *
* To_do: Add quantification factor                *
* Suppport writing amount field                   *
* Authors: Christian Reich, Timur Vakhitov        *
* DATE: 2017                                      *
**************************************************/
CREATE OR REPLACE FUNCTION MapDrugVocabulary()
  RETURNS void
AS
$BODY$
BEGIN
	-- 1. Create lookup tables for existing vocab r (RxNorm and public country-specific ones)
	-- Create table containing ingredients for each drug
	DROP TABLE IF EXISTS r_drug_ing;
	CREATE UNLOGGED TABLE r_drug_ing AS
	SELECT de.concept_id AS drug_id,
		an.concept_id AS ing_id
	FROM concept_ancestor a
	JOIN concept an ON a.ancestor_concept_id = an.concept_id
		AND an.concept_class_id = 'Ingredient'
		AND an.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			) -- to be expanded as new vocabs are added
	JOIN concept de ON de.concept_id = a.descendant_concept_id
		AND de.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			)
	WHERE an.invalid_reason IS NULL
		AND de.concept_id NOT IN (
			19094500,
			19080557
			); -- Remove unparsable Albumin products that have no drug_strength entry: Albumin Human, USP 1 NS

	CREATE INDEX x_r_drug_ing ON r_drug_ing(drug_id, ing_id);
	ANALYZE r_drug_ing;

	-- Count number of ingredients for each drug
	DROP TABLE IF EXISTS r_ing_count;
	CREATE UNLOGGED TABLE r_ing_count AS
	SELECT drug_id AS did,
		count(*) AS cnt
	FROM r_drug_ing
	GROUP BY drug_id;

	-- Set all counts for Ingredient and Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
	UPDATE r_ing_count
	SET cnt = NULL
	WHERE did IN (
			SELECT c_int.concept_id
			FROM concept c_int
			WHERE c_int.concept_class_id IN (
					'Clinical Drug Comp',
					'Ingredient'
					)
				AND c_int.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
			);

	-- Create lookup table for query vocab q (new vocab)
	DROP TABLE IF EXISTS q_drug_ing;
	CREATE UNLOGGED TABLE q_drug_ing AS
	SELECT drug.concept_code AS drug_code,
		coalesce(ing.concept_id, 0) AS ing_id,
		i.concept_code AS ing_code -- if ingredient is not mapped use 0 to still get the right ingredient count
	FROM drug_concept_stage i
	LEFT JOIN relationship_to_concept r1 ON r1.concept_code_1 = i.concept_code
	LEFT JOIN concept ing ON ing.concept_id = r1.concept_id_2 -- link standard ingredients to existing ones
	JOIN internal_relationship_stage r2 ON r2.concept_code_2 = i.concept_code
	JOIN drug_concept_stage drug ON drug.concept_class_id NOT IN (
			'Unit',
			'Ingredient',
			'Brand Name',
			'Non-Drug Prod',
			'Dose Form',
			'Device',
			'Observation'
			)
		AND drug.domain_id = 'Drug' -- include only drug product concept classes
		AND drug.concept_code = r2.concept_code_1
	WHERE i.concept_class_id = 'Ingredient'
		AND ing.invalid_reason IS NULL;

	CREATE INDEX x_q_drug_ing ON q_drug_ing(drug_code, ing_id);
	ANALYZE q_drug_ing;

	-- Count ingredients per drug
	DROP TABLE IF EXISTS q_ing_count;
	CREATE UNLOGGED TABLE q_ing_count AS
	SELECT drug_code AS dcode,
		count(*) AS cnt
	FROM q_drug_ing
	GROUP BY drug_code;

	-- Create table that lists for each ingredient all drugs containing it from q and r
	DROP TABLE IF EXISTS match;
	CREATE UNLOGGED TABLE match AS
	SELECT q.ing_id AS r_iid,
		q.ing_code AS q_icode,
		q.drug_code AS q_dcode,
		r.drug_id AS r_did
	FROM q_drug_ing q
	JOIN r_drug_ing r ON q.ing_id = r.ing_id; -- match query and result drug on common ingredient

	CREATE INDEX x_match ON match(q_dcode, r_did);
	ANALYZE match;

	-- Create table with all drugs in q and r and the number of ingredients they share
	DROP TABLE IF EXISTS shared_ing;
	CREATE UNLOGGED TABLE shared_ing AS
	SELECT r_did,
		q_dcode,
		count(*) AS cnt
	FROM match
	GROUP BY r_did,
		q_dcode;

	-- Set all counts for Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
	UPDATE shared_ing
	SET cnt = NULL
	WHERE r_did IN (
			SELECT c_int.concept_id
			FROM concept c_int
			WHERE c_int.concept_class_id IN (
					'Clinical Drug Comp',
					'Ingredient'
					)
				AND c_int.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
			);

	CREATE INDEX x_shared_ing ON shared_ing (q_dcode, r_did);
	ANALYZE shared_ing;

	DROP TABLE IF EXISTS r_bn;
	CREATE UNLOGGED TABLE r_bn AS
	SELECT DISTINCT ca.descendant_concept_id AS concept_id_1,
		cr.concept_id_2
	FROM concept_relationship cr
	JOIN concept_ancestor ca ON ca.ancestor_concept_id = cr.concept_id_1
	JOIN concept bn ON bn.concept_id = cr.concept_id_2
		AND bn.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			)
		AND bn.concept_class_id = 'Brand Name'
		AND bn.invalid_reason IS NULL
	JOIN concept c ON c.concept_id = cr.concept_id_1
		AND c.concept_class_id <> 'Ingredient'
		AND c.invalid_reason IS NULL
		AND c.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			)
	JOIN concept bd ON bd.concept_id = ca.descendant_concept_id
		AND bd.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			)
		AND bd.concept_class_id IN (
			'Branded Drug Box',
			'Quantified Branded Box',
			'Branded Drug Comp',
			'Quant Branded Drug',
			'Branded Drug Form',
			'Branded Drug',
			'Marketed Product',
			'Branded Pack',
			'Clinical Pack'
			)
		AND bd.invalid_reason IS NULL
	WHERE cr.invalid_reason IS NULL
		AND cr.relationship_id = 'Has brand name';

	CREATE INDEX x_r_bn ON r_bn (concept_id_1);
	ANALYZE r_bn;

	-- create table with all query drug codes q_dcode mapped to standard drug concept ids r_did, irrespective of the correct dose
	DROP TABLE IF EXISTS m;
	CREATE UNLOGGED TABLE m AS(
		SELECT DISTINCT m.*,
			rc.cnt AS rc_cnt,
			r.precedence AS i_prec
		FROM match m
		JOIN q_ing_count qc ON qc.dcode = m.q_dcode -- count number of ingredients on query (left side) drug
		JOIN r_ing_count rc ON rc.did = m.r_did
			AND qc.cnt = coalesce(rc.cnt, qc.cnt) -- count number of ingredients on result (right side) drug. In case of Clinical Drug Comp the number should always match 
		JOIN shared_ing ON shared_ing.r_did = m.r_did
			AND shared_ing.q_dcode = m.q_dcode
			AND coalesce(shared_ing.cnt, qc.cnt) = qc.cnt -- and make sure the number of shared ingredients is the same as the total number of ingredients for both q and r
		JOIN relationship_to_concept r ON r.concept_code_1 = m.q_icode
			AND r.concept_id_2 = m.r_iid
	);
	CREATE INDEX idx_match_r_did ON m (r_did);
	CREATE INDEX idx_match_q_dcode ON m (q_dcode);
	ANALYZE m;

	-- Create table that matches drugs q to r, based on Ingredient, Dose Form and Brand Name (if exist). Dose, box size or quantity are not yet compared
	DROP TABLE IF EXISTS q_to_r_anydose;
	CREATE UNLOGGED TABLE q_to_r_anydose AS
		-- create table with all query drug codes q_dcode mapped to standard drug concept ids r_did, irrespective of the correct dose
		WITH q_df AS (
				SELECT r.concept_code_1,
					m.concept_id_2,
					coalesce(m.precedence, 1) AS precedence
				FROM internal_relationship_stage r -- if Dose Form exists but not mapped use 0
				JOIN drug_concept_stage dcs ON dcs.concept_code = r.concept_code_2
					AND dcs.concept_class_id = 'Dose Form' -- Dose Form of q
				JOIN relationship_to_concept m ON m.concept_code_1 = r.concept_code_2 -- left join if not 
				),
			r_df AS (
				SELECT r.concept_id_1,
					r.concept_id_2
				FROM concept_relationship r
				JOIN concept c1 ON c1.concept_id = r.concept_id_1
					AND c1.vocabulary_id IN (
						'RxNorm',
						'RxNorm Extension'
						)
				JOIN concept c2 ON c2.concept_id = r.concept_id_2
					AND c2.concept_class_id = 'Dose Form'
					AND c2.invalid_reason IS NULL
				WHERE r.invalid_reason IS NULL
					AND r.relationship_id = 'RxNorm has dose form'
				),
			q_bn AS (
				SELECT r.concept_code_1,
					m.concept_id_2,
					coalesce(m.precedence, 1) AS precedence
				FROM internal_relationship_stage r
				JOIN drug_concept_stage dcs ON dcs.concept_code = r.concept_code_2
					AND dcs.concept_class_id = 'Brand Name'
				JOIN relationship_to_concept m ON m.concept_code_1 = r.concept_code_2
				),
			q_sp AS (
				SELECT r.concept_code_1,
					m.concept_id_2,
					coalesce(m.precedence, 1) AS precedence
				FROM internal_relationship_stage r
				JOIN drug_concept_stage dcs ON dcs.concept_code = r.concept_code_2
					AND dcs.concept_class_id = 'Supplier'
				JOIN relationship_to_concept m ON m.concept_code_1 = r.concept_code_2
				),
			r_sp AS (
				SELECT r.concept_id_1,
					r.concept_id_2
				FROM concept_relationship r
				JOIN concept c1 ON c1.concept_id = r.concept_id_1
					AND c1.vocabulary_id IN (
						'RxNorm',
						'RxNorm Extension'
						)
				JOIN concept c2 ON c2.concept_id = r.concept_id_2
					AND c2.concept_class_id = 'Supplier'
				WHERE r.invalid_reason IS NULL
				),
			q_qnt AS (
				SELECT drug_concept_code,
					denominator_value * conversion_factor || ' ' || concept_id_2 AS quant_f
				FROM ds_stage ds
				JOIN relationship_to_concept rc ON denominator_unit = rc.concept_code_1
					AND precedence = 1
				WHERE denominator_value IS NOT NULL
				),
			r_bs AS (
				SELECT ds.drug_concept_id,
					ds.box_size
				FROM drug_strength ds
				JOIN concept c ON c.concept_id = ds.drug_concept_id
					AND c.vocabulary_id IN (
						'RxNorm',
						'RxNorm Extension'
						)
				WHERE ds.box_size IS NOT NULL
				),
			r_qnt AS (
				SELECT ds.drug_concept_id,
					CONCAT (
						ds.denominator_value,
						' ',
						ds.denominator_unit_concept_id
						) AS quant_f
				FROM drug_strength ds
				JOIN concept c ON c.concept_id = ds.drug_concept_id
					AND c.vocabulary_id IN (
						'RxNorm',
						'RxNorm Extension'
						)
				WHERE ds.denominator_value IS NOT NULL
				),
			q_bs AS (
				SELECT drug_concept_code,
					box_size
				FROM ds_stage
				WHERE box_size IS NOT NULL
				)

	SELECT DISTINCT m.q_dcode,
		m.q_icode,
		m.r_did,
		m.r_iid,
		m.i_prec,
		-- remove the iterations of all the different matches to 0
		CASE 
			WHEN r_df.concept_id_2 IS NULL
				THEN NULL
			ELSE q_df.precedence
			END AS df_prec,
		CASE 
			WHEN r_bn.concept_id_2 IS NULL
				THEN NULL
			ELSE q_bn.precedence
			END AS bn_prec,
		CASE 
			WHEN r_sp.concept_id_2 IS NULL
				THEN NULL
			ELSE q_sp.precedence
			END AS sp_prec,
		m.rc_cnt -- get the number of ingredients in the r. It's set to null for ingredients and Clin Drug Comps, and we need that for the next step
		-- get ingredients and their counts to match
	FROM m
	-- get the Dose Forms for each q and r
	LEFT JOIN q_df ON q_df.concept_code_1 = m.q_dcode
	LEFT JOIN r_df ON r_df.concept_id_1 = m.r_did
	-- get Brand Name for q and r
	LEFT JOIN q_bn ON q_bn.concept_code_1 = m.q_dcode
	LEFT JOIN r_bn ON r_bn.concept_id_1 = m.r_did
		AND m.rc_cnt IS NOT NULL -- only take Brand Names if they don't come from Ingredients or Clinical Drug Comps
		-- get Supplier for q and r
	LEFT JOIN q_sp ON q_sp.concept_code_1 = m.q_dcode
	LEFT JOIN r_sp ON r_sp.concept_id_1 = m.r_did
	--try the same with Box_size
	LEFT JOIN q_bs ON q_bs.drug_concept_code = m.q_dcode
	LEFT JOIN r_bs ON r_bs.drug_concept_id = m.r_did
	LEFT JOIN q_qnt ON q_qnt.drug_concept_code = m.q_dcode
	LEFT JOIN r_qnt ON r_qnt.drug_concept_id = m.r_did
	-- remove comments if mapping should be done both upwards (standard) and downwards (to find a possible unique low-granularity solution)
	WHERE coalesce(q_bn.concept_id_2, /* r_bn.concept_id_2, */ 0) = coalesce(r_bn.concept_id_2, q_bn.concept_id_2, 0) -- Allow matching of the same Brand Name or no Brand Name, but not another Brand Name
		AND coalesce(q_df.concept_id_2, /*r_df.concept_id_2, */ 0) = coalesce(r_df.concept_id_2, q_df.concept_id_2, 0) -- Allow matching of the same Dose Form or no Dose Form, but not another Dose Form?
		AND coalesce(q_sp.concept_id_2, /*r_df.concept_id_2, */ 0) = coalesce(r_sp.concept_id_2, q_sp.concept_id_2, 0) -- Allow matching of the same Supplier or no Supplier, but not another Supplier
		AND coalesce(q_bs.box_size, /*q_bs.box_size, */ 0) = coalesce(r_bs.box_size, q_bs.box_size, 0)
		AND coalesce(q_qnt.quant_f, /*r_sp.concept_id_2, */ 'X') = coalesce(r_qnt.quant_f, q_qnt.quant_f, 'X');

	-- Add matching of dose and its units
	DROP TABLE IF EXISTS q_to_r_wdose;
	CREATE UNLOGGED TABLE q_to_r_wdose AS
		-- Create two temp tables with all strength and unit information
		WITH q AS (
				SELECT q_ds.drug_concept_code,
					q_ds.ingredient_concept_code,
					q_ds.amount_value * q_ds_a.conversion_factor AS amount_value,
					q_ds_a.concept_id_2 AS amount_unit_concept_id,
					q_ds.numerator_value * q_ds_n.conversion_factor AS numerator_value,
					q_ds_n.concept_id_2 AS numerator_unit_concept_id,
					coalesce(q_ds.denominator_value, 1) * coalesce(q_ds_d.conversion_factor, 1) AS denominator_value,
					q_ds_d.concept_id_2 AS denominator_unit_concept_id,
					coalesce(q_ds_a.precedence, q_ds_n.precedence, q_ds_d.precedence) AS u_prec,
					box_size
				FROM ds_stage q_ds
				LEFT JOIN relationship_to_concept q_ds_a ON q_ds_a.concept_code_1 = q_ds.amount_unit -- amount units
				LEFT JOIN relationship_to_concept q_ds_n ON q_ds_n.concept_code_1 = q_ds.numerator_unit -- numerator units
				LEFT JOIN relationship_to_concept q_ds_d ON q_ds_d.concept_code_1 = q_ds.denominator_unit -- denominator units
				),
			r AS (
				SELECT r_ds.drug_concept_id,
					r_ds.ingredient_concept_id,
					r_ds.amount_value,
					r_ds.amount_unit_concept_id,
					r_ds.numerator_value,
					r_ds.numerator_unit_concept_id,
					coalesce(r_ds.denominator_value, 1) AS denominator_value, -- Quantified have a value in the denominator, the others haven't.
					r_ds.denominator_unit_concept_id,
					box_size --once we get RxNorm Extension this value will be exist
				FROM drug_strength r_ds
				)
	-- Create variables div as r amount / q amount, and unit as 1 for matching and 0 as non-matching 
	SELECT q_dcode,
		q_icode,
		r_did,
		r_iid,
		coalesce(df_prec, 100) AS df_prec,
		coalesce(bn_prec, 100) AS bn_prec,
		coalesce(u_prec, 100) AS u_prec,
		i_prec,
		CASE 
			WHEN div > 1
				THEN 1 / div
			ELSE div
			END AS div, -- the one the closest to 1 wins, but the range is 0-1, which is the opposite direction of the other ones
		unit AS u_match,
		rc_cnt
	FROM (
		SELECT DISTINCT m.*,
			CASE 
				WHEN r.drug_concept_id IS NULL
					THEN 0
				ELSE q.u_prec
				END AS u_prec,
			CASE 
				WHEN r.drug_concept_id IS NULL
					THEN 1 -- if no drug_strength exist (Drug Forms etc.)
				WHEN q.amount_value IS NOT NULL
					AND r.amount_value IS NOT NULL
					THEN q.amount_value / r.amount_value
				WHEN q.numerator_unit_concept_id = 8554
					AND r.numerator_unit_concept_id = 8576
					AND r.denominator_unit_concept_id = 8587
					THEN (q.numerator_value * 10) / (r.numerator_value / r.denominator_value) -- % vs mg/mL
				WHEN q.numerator_unit_concept_id = 8554
					AND r.numerator_unit_concept_id != 8554
					THEN (q.numerator_value / 100) / (r.numerator_value / r.denominator_value) -- % in one but not in the other
				WHEN q.numerator_unit_concept_id != 8554
					AND r.numerator_unit_concept_id = 8554
					THEN (q.numerator_value / q.denominator_value) / (r.numerator_value / 100) -- % in the other but not in one
				WHEN q.numerator_value IS NOT NULL
					AND r.numerator_value IS NOT NULL
					THEN (q.numerator_value / q.denominator_value) / (r.numerator_value / r.denominator_value) -- denominator empty unless Quant
				ELSE 0
				END AS div,
			CASE 
				WHEN r.drug_concept_id IS NULL
					THEN 1 -- if no drug_strength exist (Drug Forms etc.)
				WHEN q.amount_unit_concept_id = r.amount_unit_concept_id
					THEN 1
				WHEN q.numerator_unit_concept_id = 8554
					AND r.numerator_unit_concept_id = 8576
					AND r.denominator_unit_concept_id = 8587
					THEN 1 -- % vs mg/mL
				WHEN q.numerator_unit_concept_id = 8554
					AND r.numerator_unit_concept_id = r.denominator_unit_concept_id
					THEN 1 -- % vs mg/mg or mL/mL
				WHEN q.numerator_unit_concept_id = q.denominator_unit_concept_id
					AND r.numerator_unit_concept_id = 8554
					THEN 1 -- g/g, mg/mg or mL/mL vs %
				WHEN q.numerator_unit_concept_id = r.numerator_unit_concept_id
					AND q.denominator_unit_concept_id = r.denominator_unit_concept_id
					THEN 1
				ELSE 0
				END AS unit
		FROM q_to_r_anydose m
		-- drug strength for each q ingredient
		LEFT JOIN q ON q.drug_concept_code = m.q_dcode
			AND q.ingredient_concept_code = m.q_icode
		-- drug strength for each r ingredient 
		LEFT JOIN r ON r.drug_concept_id = m.r_did
			AND r.ingredient_concept_id = m.r_iid
		) AS s0;

	-- Remove all multiple mappings with close divs and keep the best
	DELETE
	FROM q_to_r_wdose
	WHERE ctid IN (
			SELECT r
			FROM (
				SELECT ctid AS r,
					rank() OVER (
						PARTITION BY q_dcode,
						q_icode,
						df_prec,
						bn_prec,
						u_prec ORDER BY div DESC,
							i_prec
						) rn
				FROM q_to_r_wdose
				) AS s0
			WHERE rn > 1
			);

	CREATE INDEX q_to_r_wdose_q ON q_to_r_wdose (q_dcode);
	ANALYZE q_to_r_wdose;

	-- Remove all those where not everything fits
	-- The table has to be created separately because both subsequent queries define one field as null
	DROP TABLE IF EXISTS q_to_r;
	CREATE UNLOGGED TABLE q_to_r AS
	SELECT q_dcode,
		r_did,
		r_iid,
		bn_prec,
		df_prec,
		u_prec,
		rc_cnt
	FROM q_to_r_wdose
	WHERE 1 = 0;

	INSERT INTO q_to_r
	SELECT a.q_dcode,
		a.r_did,
		NULL AS r_iid,
		a.bn_prec,
		a.df_prec,
		a.u_prec,
		a.rc_cnt
	FROM (
		-- take the distinct set of drug-drug pairs with the same Brand Name, Dose Form and unit precedence
		-- only for those where multiple ingredients could be contained in the concept (everything but Ingredient and Clin Drug Comp)
		SELECT q_dcode,
			r_did,
			bn_prec,
			df_prec,
			u_prec,
			rc_cnt,
			count(8) AS cnt
		FROM q_to_r_wdose
		WHERE coalesce(rc_cnt, 0) > 1
		GROUP BY q_dcode,
			r_did,
			bn_prec,
			df_prec,
			u_prec,
			rc_cnt
		) a
	-- but make sure there are sufficient amount of components (ingredients) in each group
	WHERE a.cnt = a.rc_cnt
	GROUP BY a.q_dcode,
		a.r_did,
		a.bn_prec,
		a.df_prec,
		a.u_prec,
		a.rc_cnt
	-- not one of the components should miss the match
	HAVING NOT EXISTS (
			SELECT 1
			FROM q_to_r_wdose m -- join the set of the same 
			WHERE a.q_dcode = m.q_dcode
				AND a.r_did = m.r_did
				AND a.bn_prec = m.bn_prec
				AND a.df_prec = m.df_prec
				AND a.u_prec = m.u_prec
				-- Change the factor closer to 1 if matching should be tighter. Currently, anything within 10% amount will be considered a match.
				AND (
					m.div < 0.9
					OR m.u_match = 0
					)
			);

	-- Second step add Ingredients and the correct Clinical Drug Components. Their number may not match the total number of Ingredients in the query drug
	INSERT INTO q_to_r
	SELECT DISTINCT q_dcode,
		r_did,
		r_iid,
		bn_prec,
		df_prec,
		u_prec,
		NULL::INT AS rc_cnt
	FROM q_to_r_wdose
	WHERE coalesce(rc_cnt, 1) = 1 -- process only those that don't have combinations (Ingredients and Clin Drug Components)
		AND div >= 0.9
		AND u_match = 1;

	--possible mapping with different dosages for different ingredient, each ingredient should be unique
	DROP TABLE IF EXISTS poss_map;
	CREATE UNLOGGED TABLE poss_map AS
	SELECT DISTINCT b.*
	FROM (
		SELECT dcs.concept_name AS concept_name_1,
			dcs.concept_code,
			c.concept_name AS concept_name_2,
			c.concept_id,
			RC_CNT,
			ingredient_concept_id,
			count(1) AS cnt
		FROM q_to_r_anydose
		JOIN ds_stage ds1 ON q_dcode = drug_concept_code
		JOIN drug_strength ds2 ON r_did = drug_concept_id
			AND r_iid = ingredient_concept_id
			AND CONCAT (
				'x',
				coalesce(ds1.numerator_value / coalesce(ds1.DENOMINATOR_VALUE, 1), '0')
				) = CONCAT (
				'x',
				coalesce(ds2.numerator_value / coalesce(ds2.DENOMINATOR_VALUE, 1), '0')
				)
			AND CONCAT (
				'x',
				coalesce(ds1.amount_value, '0')
				) = CONCAT (
				'x',
				coalesce(ds2.amount_value, '0')
				)
		JOIN drug_concept_stage dcs ON dcs.concept_code = Q_DCODE
		JOIN concept c ON concept_id = R_DID
			AND c.invalid_reason IS NULL
		WHERE rc_cnt > 1
		GROUP BY dcs.concept_name,
			dcs.concept_code,
			c.concept_name,
			c.concept_id,
			RC_CNT,
			ingredient_concept_id
		) a -- where cnt >= rc_cnt
	JOIN (
		SELECT dcs.concept_name AS concept_name_1,
			dcs.concept_code,
			c.concept_name AS concept_name_2,
			c.concept_id,
			RC_CNT,
			count(1) AS cnt
		FROM q_to_r_anydose
		JOIN ds_stage ds1 ON q_dcode = drug_concept_code
		JOIN drug_strength ds2 ON r_did = drug_concept_id
			AND r_iid = ingredient_concept_id
			AND CONCAT (
				'x',
				coalesce(ds1.numerator_value / coalesce(ds1.DENOMINATOR_VALUE, 1), '0')
				) = CONCAT (
				'x',
				coalesce(ds2.numerator_value / coalesce(ds2.DENOMINATOR_VALUE, 1), '0')
				)
			AND CONCAT (
				'x',
				coalesce(ds1.amount_value, '0')
				) = CONCAT (
				'x',
				coalesce(ds2.amount_value, '0')
				)
		JOIN drug_concept_stage dcs ON dcs.concept_code = Q_DCODE
		JOIN concept c ON concept_id = R_DID
			AND c.invalid_reason IS NULL
		WHERE rc_cnt > 1
		GROUP BY dcs.concept_name,
			dcs.concept_code,
			c.concept_name,
			c.concept_id,
			RC_CNT
		) b ON a.CONCEPT_CODE = b.concept_code
		AND a.concept_id = b.concept_id
	JOIN (
		SELECT dcs.concept_name AS concept_name_1,
			dcs.concept_code,
			c.concept_name AS concept_name_2,
			c.concept_id,
			RC_CNT,
			ingredient_concept_code,
			count(1) AS cnt
		FROM q_to_r_anydose
		JOIN ds_stage ds1 ON q_dcode = drug_concept_code
		JOIN drug_strength ds2 ON r_did = drug_concept_id
			AND r_iid = ingredient_concept_id
			AND CONCAT (
				'x',
				coalesce(ds1.numerator_value / coalesce(ds1.DENOMINATOR_VALUE, 1), '0')
				) = CONCAT (
				'x',
				coalesce(ds2.numerator_value / coalesce(ds2.DENOMINATOR_VALUE, 1), '0')
				)
			AND CONCAT (
				'x',
				coalesce(ds1.amount_value, '0')
				) = CONCAT (
				'x',
				coalesce(ds2.amount_value, '0')
				)
		JOIN drug_concept_stage dcs ON dcs.concept_code = Q_DCODE
		JOIN concept c ON c.concept_id = R_DID
			AND c.invalid_reason IS NULL
		WHERE rc_cnt > 1
		GROUP BY dcs.concept_name,
			dcs.concept_code,
			c.concept_name,
			c.concept_id,
			RC_CNT,
			ingredient_concept_code
		) c ON a.CONCEPT_CODE = c.concept_code
		AND a.concept_id = c.concept_id
	WHERE b.cnt >= b.rc_cnt
		AND a.cnt = 1
		AND c.cnt = 1;

	--insert possible mappings if they are not already present in q_to_r
	INSERT INTO q_to_r (
		Q_DCODE,
		R_DID
		)
	SELECT concept_code,
		concept_id
	FROM poss_map b
	WHERE NOT EXISTS (
			SELECT 1
			FROM q_to_r a
			WHERE a.Q_DCODE = concept_code
				AND R_DID = concept_id
			);

	--define order as combination of attributes number and each attribute weight
	DROP TABLE IF EXISTS attrib_cnt;
	CREATE UNLOGGED TABLE attrib_cnt AS
		WITH cnc_rel_class AS (
				--full relationship with classes within RxNorm
				SELECT ri.*,
					ci.concept_class_id AS concept_class_id_1,
					c2.concept_class_id AS concept_class_id_2
				FROM concept_relationship ri
				JOIN concept ci ON ci.concept_id = ri.concept_id_1
				JOIN concept c2 ON c2.concept_id = ri.concept_id_2
				WHERE ci.vocabulary_id LIKE 'RxNorm%'
					AND ri.invalid_reason IS NULL
					AND ci.invalid_reason IS NULL
					AND c2.vocabulary_id LIKE 'RxNorm%'
					AND c2.invalid_reason IS NULL
				)
	SELECT concept_id_1,
		count(1)::TEXT || max(weight)::TEXT AS weight
	FROM (
		--need to go throught Drug Form / Component to get the Brand Name
		SELECT concept_id_1,
			3 AS weight
		FROM r_bn
		
		UNION
		
		SELECT concept_id_1,
			1
		FROM cnc_rel_class
		WHERE concept_class_id_2 = 'Supplier'
		
		UNION
		
		SELECT concept_id_1,
			5
		FROM cnc_rel_class
		WHERE concept_class_id_2 = 'Dose Form'
		
		UNION
		
		SELECT drug_concept_id,
			6
		FROM drug_strength
		WHERE coalesce(numerator_value, amount_value) IS NOT NULL
		--remove comments when Box_size will be present 
		
		UNION
		
		SELECT drug_concept_id,
			2
		FROM drug_strength
		WHERE Box_size IS NOT NULL
		
		UNION
		
		SELECT drug_concept_id,
			4
		FROM drug_strength
		WHERE DENOMINATOR_VALUE IS NOT NULL
		) AS s0
	GROUP BY concept_id_1

	UNION

	SELECT concept_id,
		'0'
	FROM concept
	WHERE concept_class_id = 'Ingredient'
		AND vocabulary_id LIKE 'RxNorm%';

	DROP TABLE IF EXISTS best_map;
	CREATE UNLOGGED TABLE best_map AS
		WITH Q_DCODE_to_hlc AS (
				SELECT q.Q_DCODE
				FROM q_to_r q
				JOIN concept c ON concept_id = q.R_DID
				WHERE (
						CONCEPT_CLASS_ID IN (
							'Branded Drug Box',
							'Quant Branded Box',
							'Quant Branded Drug',
							'Branded Drug',
							'Marketed Product',
							'Branded Pack',
							'Clinical Pack',
							'Clinical Drug Box',
							'Quant Clinical Box',
							'Clinical Branded Drug',
							'Clinical Drug',
							'Marketed Product'
							)
						OR concept_name LIKE '% / %'
						)
					AND c.standard_concept = 'S'
				),
			dupl AS (
				SELECT st.*,
					c.concept_class_id,
					attrib_cnt.*
				FROM q_to_r q
				JOIN attrib_cnt ON r_did = concept_id_1
				JOIN drug_concept_stage ds ON Q_DCODE = ds.concept_code
				JOIN concept c ON c.concept_id = q.R_DID
				JOIN (
					SELECT drug_concept_code,
						count(1) AS cnt
					FROM ds_stage
					GROUP BY drug_concept_code
					HAVING count(1) > 1
					) st ON drug_concept_code = Q_DCODE
				WHERE Q_DCODE NOT IN (
						SELECT Q_DCODE
						FROM Q_DCODE_to_hlc
						)
				)
	SELECT DISTINCT first_value(concept_id_1) OVER (
			PARTITION BY q_dcode ORDER BY weight DESC
			) AS r_did,
		q_dcode
	FROM attrib_cnt
	JOIN q_to_r ON r_did = concept_id_1
	WHERE Q_DCODE NOT IN (
			SELECT drug_concept_code
			FROM dupl
			)

	UNION

	SELECT concept_id_1,
		drug_concept_code
	FROM dupl
	WHERE WEIGHT = '0';

	-- Write concept_relationship_stage
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
	SELECT q_dcode AS concept_code_1,
		c.concept_code AS concept_code_2,
		(
			SELECT vocabulary_id
			FROM drug_concept_stage limit 1
			) AS vocabulary_id_1,
		c.vocabulary_id AS vocabulary_id_2,
		'Maps to' AS relationship_id,
		(
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = (
					SELECT vocabulary_id
					FROM drug_concept_stage limit 1
					)
			) AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM best_map m
	JOIN concept c ON c.concept_id = m.r_did
		AND c.vocabulary_id LIKE 'RxNorm%';

	--Clean up
	DROP TABLE r_drug_ing;
	DROP TABLE r_ing_count;
	DROP TABLE q_drug_ing;
	DROP TABLE q_ing_count;
	DROP TABLE match;
	DROP TABLE shared_ing;
	DROP TABLE r_bn;
	DROP TABLE q_to_r_anydose;
	DROP TABLE q_to_r_wdose;
	DROP TABLE q_to_r;
	DROP TABLE poss_map;
	DROP TABLE attrib_cnt;
	DROP TABLE best_map;
	DROP TABLE m;
	--from procedure_drug.sql
	DROP TABLE drug_concept_stage;
	DROP TABLE relationship_to_concept;
	DROP TABLE internal_relationship_stage;
	DROP TABLE ds_stage;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY INVOKER
SET client_min_messages = error;
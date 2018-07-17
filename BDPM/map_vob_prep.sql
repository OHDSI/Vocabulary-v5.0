/**************************************************
* This script takes a drug vocabulary q and       *
* compares it to the existing drug vocabulary r   *
* The new vocabulary must be provided in the same *
* format as for generating a new drug vocabulary: *
* http://www.ohdsi.org/web/wiki/doku.php?id=documentation:international_drugs *
* As a result it creates records in the           *
* concept_relationship_stage table                *
*                                                 *
* To_do: Add quantification factor                *
* Suppport writing amount field                   *
**************************************************/
TRUNCATE TABLE concept_relationship_stage;
-- 1. Create lookup tables for existing vocab r (RxNorm and public country-specific ones)
-- Create table containing ingredients for each drug
DROP TABLE IF EXISTS r_drug_ing;
CREATE unlogged TABLE r_drug_ing AS
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
		);

-- Remove unparsable Albumin products that have no drug_strength entry: Albumin Human, USP 1 NS
DELETE
FROM r_drug_ing
WHERE drug_id IN (
		19094500,
		19080557
		);

-- Count number of ingredients for each drug
DROP TABLE IF EXISTS r_ing_count;
CREATE unlogged TABLE r_ing_count AS
SELECT drug_id AS did,
	count(*) AS cnt
FROM r_drug_ing
GROUP BY drug_id;

-- Set all counts for Ingredient and Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
UPDATE r_ing_count r
SET cnt = NULL
FROM concept c
WHERE c.concept_class_id IN (
		'Clinical Drug Comp',
		'Ingredient'
		)
	AND c.concept_id = r.did;

-- Create lookup table for query vocab q (new vocab)
DROP TABLE IF EXISTS  q_drug_ing;
CREATE TABLE q_drug_ing AS
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
WHERE i.concept_class_id = 'Ingredient';

-- Count ingredients per drug
DROP TABLE IF EXISTS q_ing_count;
CREATE TABLE q_ing_count AS
SELECT drug_code AS dcode,
	count(*) AS cnt
FROM q_drug_ing
GROUP BY drug_code;

CREATE INDEX idx_r_ing_id ON r_drug_ing (
	ing_id,
	drug_id
	);

ANALYZE r_drug_ing;

-- Create table that lists for each ingredient all drugs containing it from q and r
DROP TABLE IF EXISTS match;
CREATE unlogged TABLE match AS
SELECT q.ing_id AS r_iid,
	q.ing_code AS q_icode,
	q.drug_code AS q_dcode,
	r.drug_id AS r_did
FROM q_drug_ing q
JOIN r_drug_ing r ON q.ing_id = r.ing_id; -- match query and result drug on common ingredient

-- Create table with all drugs in q and r and the number of ingredients they share
DROP TABLE IF EXISTS shared_ing;
CREATE unlogged TABLE shared_ing AS
SELECT r_did,
	q_dcode,
	count(*) AS cnt
FROM match
GROUP BY r_did,
	q_dcode;

-- Set all counts for Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
UPDATE shared_ing s
SET cnt = NULL
FROM concept c
WHERE c.concept_class_id IN (
		'Clinical Drug Comp',
		'Ingredient'
		)
	AND c.concept_id = s.r_did;

-- Create table that matches drugs q to r, based on Ingredient, Dose Form and Brand Name (if exist). Dose, box size or quantity are not yet compared
CREATE INDEX idx_r_c ON relationship_to_concept (concept_code_1);

ANALYZE relationship_to_concept;

CREATE INDEX x_match ON match (
	q_dcode,
	r_did
	);

ANALYZE match;

DROP TABLE IF EXISTS m;
CREATE unlogged TABLE m AS
SELECT m.*,
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
	AND r.concept_id_2 = m.r_iid;

DROP TABLE IF EXISTS q_to_r_anydose;

CREATE unlogged TABLE q_to_r_anydose AS
-- create table with all query drug codes q_dcode mapped to standard drug concept ids r_did, irrespective of the correct dose
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
LEFT JOIN (
	SELECT r.concept_code_1,
		m.concept_id_2,
		coalesce(m.precedence, 1) AS precedence
	FROM internal_relationship_stage r -- if Dose Form exists but not mapped use 0
	JOIN drug_concept_stage ON concept_code = r.concept_code_2
		AND concept_class_id = 'Dose Form' -- Dose Form of q
	JOIN relationship_to_concept m ON m.concept_code_1 = r.concept_code_2 -- left join if not 
	) q_df ON q_df.concept_code_1 = m.q_dcode
LEFT JOIN (
	SELECT r.concept_id_1,
		r.concept_id_2
	FROM concept_relationship r
	JOIN concept ON concept_id = r.concept_id_2
		AND concept_class_id = 'Dose Form' -- Dose Form of r
	WHERE r.invalid_reason IS NULL
		AND r.relationship_id = 'RxNorm has dose form'
	) r_df ON r_df.concept_id_1 = m.r_did
-- get Brand Name for q and r
LEFT JOIN (
	SELECT r.concept_code_1,
		m.concept_id_2,
		coalesce(m.precedence, 1) AS precedence
	FROM internal_relationship_stage r
	JOIN drug_concept_stage ON concept_code = r.concept_code_2
		AND concept_class_id = 'Brand Name'
	JOIN relationship_to_concept m ON m.concept_code_1 = r.concept_code_2
	) q_bn ON q_bn.concept_code_1 = m.q_dcode
LEFT JOIN (
	SELECT r.concept_id_1,
		r.concept_id_2
	FROM concept_relationship r
	JOIN concept ON concept_id = r.concept_id_2
		AND concept_class_id = 'Brand Name'
	WHERE r.invalid_reason IS NULL
	) r_bn ON r_bn.concept_id_1 = m.r_did
	AND m.rc_cnt IS NOT NULL -- only take Brand Names if they don't come from Ingredients or Clinical Drug Comps
-- get Supplier for q and r
LEFT JOIN (
	SELECT r.concept_code_1,
		m.concept_id_2,
		coalesce(m.precedence, 1) AS precedence
	FROM internal_relationship_stage r
	JOIN drug_concept_stage ON concept_code = r.concept_code_2
		AND concept_class_id = 'Supplier'
	JOIN relationship_to_concept m ON m.concept_code_1 = r.concept_code_2
	) q_sp ON q_sp.concept_code_1 = m.q_dcode
LEFT JOIN (
	SELECT r.concept_id_1,
		r.concept_id_2
	FROM concept_relationship r
	JOIN concept ON concept_id = r.concept_id_2
		AND concept_class_id = 'Supplier'
	WHERE r.invalid_reason IS NULL
	) r_sp ON r_sp.concept_id_1 = m.r_did
--try the same with Box_size
/*
left join (
select drug_concept_code, box_size from ds_stage where box_size is not null) q_bs on q_bs.concept_code_1=m.q_dcode
left join 
(
select drug_concept_id, box_size from drug_strength where box_size is not null) r_bs on r_bs.concept_id_1=m.r_did
*/
LEFT JOIN (
	SELECT drug_concept_code,
		denominator_value AS quant_f
	FROM ds_stage
	WHERE denominator_value IS NOT NULL
	) q_qnt ON q_qnt.drug_concept_code = m.q_dcode
LEFT JOIN (
	SELECT drug_concept_id,
		denominator_value AS quant_f
	FROM drug_strength
	WHERE denominator_value IS NOT NULL
	) r_qnt ON r_qnt.drug_concept_id = m.r_did
-- remove comments if mapping should be done both upwards (standard) and downwards (to find a possible unique low-granularity solution)
WHERE coalesce(q_bn.concept_id_2, /* r_bn.concept_id_2, */ 0) = coalesce(r_bn.concept_id_2, q_bn.concept_id_2, 0) -- Allow matching of the same Brand Name or no Brand Name, but not another Brand Name
	AND coalesce(q_df.concept_id_2, /*r_df.concept_id_2, */ 0) = coalesce(r_df.concept_id_2, q_df.concept_id_2, 0) -- Allow matching of the same Dose Form or no Dose Form, but not another Dose Form?
	AND coalesce(q_sp.concept_id_2, /*r_df.concept_id_2, */ 0) = coalesce(r_sp.concept_id_2, q_sp.concept_id_2, 0) -- Allow matching of the same Dose Form or no Dose Form, but not another Dose Form?
	--and coalesce(q_bs.box_size, /*r_sp.concept_id_2, */0)=coalesce(r_sp.box_sizw, q_sp.box_size, 0) 
	AND coalesce(q_qnt.quant_f, /*r_sp.concept_id_2, */ 0) = coalesce(r_qnt.quant_f, q_qnt.quant_f, 0);

-- Add matching of dose and its units
DROP TABLE IF EXISTS q_to_r_wdose;
CREATE unlogged TABLE q_to_r_wdose AS
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
				coalesce(q_ds_a.precedence, q_ds_n.precedence, q_ds_d.precedence) AS u_prec /*, box_size*/
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
				r_ds.denominator_unit_concept_id /*, box_size*/ --once we get RxNorm Extension this value will be exist
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

-- Remove all those where not everything fits
-- The table has to be created separately because both subsequent queries define one field as null
DROP TABLE IF EXISTS q_to_r;
CREATE TABLE q_to_r AS

SELECT a.q_dcode,
	a.r_did,
	NULL::INT AS r_iid,
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

-- Get the best possible mapping that is unique in its concept class. Try bottom up from the lowest end of the drug hierarchy
DROP TABLE IF EXISTS best_map;
CREATE TABLE best_map AS
	WITH r AS (
			SELECT DISTINCT qr.*,
				cast(c.concept_code AS INTEGER) AS concept_code,
				c.concept_class_id
			FROM q_to_r qr
			JOIN concept c ON c.concept_id = qr.r_did
			)

SELECT DISTINCT rmap.q_dcode,
	first_value(rmap.r_did) OVER (
		PARTITION BY rmap.q_dcode,
		rmap.r_iid ORDER BY rmap.concept_code DESC
		) AS r_did,
	rmap.r_iid,
	rmap.bn_prec,
	rmap.rc_cnt,
	rmap.concept_class_id
FROM (
	-- get the best match within class, with the best brand name, dose form and unit precedence
	SELECT DISTINCT q_dcode,
		r_iid,
		first_value(concept_class_id) OVER (
			PARTITION BY q_dcode,
			r_iid ORDER BY cclass
			) AS concept_class_id
	FROM (
		SELECT q_dcode,
			r_iid,
			concept_class_id,
			CASE concept_class_id
				WHEN 'Quant Branded Box'
					THEN 1
				WHEN 'Quant Clinical Box'
					THEN 2
				WHEN 'Branded Drug Box'
					THEN 3
				WHEN 'Clinical Drug Box'
					THEN 4
				WHEN 'Quant Branded Drug'
					THEN 5
				WHEN 'Quant Clinical Drug'
					THEN 6
				WHEN 'Branded Drug'
					THEN 7
				WHEN 'Clinical Drug'
					THEN 8
				WHEN 'Branded Drug Form'
					THEN 9
				WHEN 'Clinical Drug Form'
					THEN 10
				WHEN 'Branded Drug Comp'
					THEN 11
				WHEN 'Clinical Drug Comp'
					THEN 12
				WHEN 'Ingredient'
					THEN 13
				ELSE 20
				END AS cclass
		FROM (
			SELECT q_dcode,
				r_iid,
				concept_class_id,
				count(8) AS cnt
			FROM (
				SELECT q_dcode,
					r_iid, -- group by ingredient for the concept classes that keep ingredients individually (Ing, Clin Drug Comp)
					concept_class_id
				FROM r
				) AS s0
			GROUP BY q_dcode,
				r_iid,
				concept_class_id
			) AS s1
		WHERE concept_class_id IN (
				'Clinical Drug Comp',
				'Ingredient'
				)
			OR cnt < 2 -- either Ingredient/Clinica Drug Comp or single map
		) AS s2
	) rcnt
JOIN r rmap ON rmap.q_dcode = rcnt.q_dcode
	AND coalesce(rmap.r_iid, 0) = coalesce(rcnt.r_iid, 0)
	AND rmap.concept_class_id = rcnt.concept_class_id
	-- where rmap.q_dcode='C9285'
	;

-- Remove those which have both Ingredient/Drug Comp hits as well as other hits.
DELETE
FROM best_map with_i
WHERE with_i.r_iid IS NOT NULL
	AND EXISTS (
		SELECT 1
		FROM best_map no_i
		WHERE with_i.q_dcode = no_i.q_dcode
			AND no_i.r_iid IS NULL
		);

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
	'RxNorm' AS vocabulary_id_2,
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
	AND c.vocabulary_id = 'RxNorm';


/****************************
* Clean up
*****************************/

DROP INDEX idx_r_c;

--drop table drug_concept_stage purge;
--drop table relationship_to_concept purge;
--drop table internal_relationship_stage purge;
--drop table ds_stage purge;
/*
drop table r_drug_ing purge;
drop table r_ing_count purge;
drop table q_drug_ing purge;
drop table q_ing_count purge;
drop table match purge;
drop table shared_ing purge;
drop table q_to_r_anydose purge;
drop table q_to_r_wdose purge;
drop table q_to_r purge;
drop table best_map purge;
*/

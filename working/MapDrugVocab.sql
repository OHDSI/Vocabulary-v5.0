analyze r_existing;
analyze ex;
analyze concept_relationship_stage;

drop index if exists irs_both;
create index irs_both on internal_relationship_stage (concept_code_1,concept_code_2);
analyze internal_relationship_stage;

DROP TABLE IF EXISTS map_drug;
CREATE TABLE map_drug AS
SELECT s1.from_code,
	s1.to_id,
	s1.map_order
FROM (
	SELECT s0.from_code,
		s0.to_id,
		s0.map_order,
		MIN(s0.map_order) OVER (PARTITION BY s0.from_code) AS min_map_order
	FROM (
		SELECT from_code,
			to_id,
			0 AS map_order
		FROM maps_to
		WHERE to_id > 0
		
		UNION ALL
		
		(
			SELECT DISTINCT ON (cr.concept_code_1) cr.concept_code_1 AS from_code,
				r.concept_id,
				1 -- Map Marketed Form to corresponding Branded/Clinical Drug (save box size and quant factor)
			FROM r_existing r
			JOIN ex e ON r.quant_value = e.r_value
				AND r.quant_unit_id = e.quant_unit_id
				AND r.i_combo = e.ri_combo
				AND r.d_combo = e.rd_combo
				AND r.bn_id = e.bn_id
				AND r.bs = e.bs
				AND r.mf_id = 0
				AND e.mf_id <> 0
				AND e.concept_id < 0
			JOIN relationship_to_concept rc ON rc.concept_id_2 = e.df_id
			JOIN relationship_to_concept rc2 ON rc.concept_code_1 = rc2.concept_code_1
				AND rc2.concept_id_2 = r.df_id
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
			JOIN internal_relationship_stage i ON rc.concept_code_1 = i.concept_code_2
				AND cr.concept_code_1 = i.concept_code_1
			ORDER BY cr.concept_code_1,
				rc2.precedence,
				r.concept_id
			)
		
		UNION ALL
		
		(
			SELECT DISTINCT ON (cr.concept_code_1) cr.concept_code_1 AS from_code,
				r.concept_id,
				2 -- Kick box size out
			FROM r_existing r
			JOIN ex e ON r.quant_value = e.r_value
				AND r.quant_unit_id = e.quant_unit_id
				AND r.i_combo = e.ri_combo
				AND r.d_combo = e.rd_combo
				AND r.bn_id = e.bn_id
				AND r.bs = 0
				AND r.mf_id = 0
				AND e.concept_id < 0
			JOIN relationship_to_concept rc ON rc.concept_id_2 = e.df_id
			JOIN relationship_to_concept rc2 ON rc.concept_code_1 = rc2.concept_code_1
				AND rc2.concept_id_2 = r.df_id
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
			JOIN internal_relationship_stage i ON rc.concept_code_1 = i.concept_code_2
				AND cr.concept_code_1 = i.concept_code_1
			ORDER BY cr.concept_code_1,
				rc2.precedence,
				r.concept_id
			)
		
		UNION ALL
		
		(
			SELECT DISTINCT ON (cr.concept_code_1) cr.concept_code_1 AS from_code,
				r.concept_id,
				3 -- Kick Quant factor out
			FROM r_existing r
			JOIN ex e ON r.i_combo = e.ri_combo
				AND r.d_combo = e.rd_combo
				AND r.bn_id = e.bn_id
				AND r.quant_value = 0
				AND r.quant_unit_id = 0
				AND r.bs = 0
				AND r.mf_id = 0
				AND e.concept_id < 0
			JOIN relationship_to_concept rc ON rc.concept_id_2 = e.df_id
			JOIN relationship_to_concept rc2 ON rc.concept_code_1 = rc2.concept_code_1
				AND rc2.concept_id_2 = r.df_id
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
			JOIN internal_relationship_stage i ON rc.concept_code_1 = i.concept_code_2
				AND cr.concept_code_1 = i.concept_code_1
			ORDER BY cr.concept_code_1,
				rc2.precedence,
				r.concept_id
			)
		
		UNION ALL
		
		(
			SELECT DISTINCT ON (cr.concept_code_1) cr.concept_code_1 AS from_code,
				r.concept_id,
				4 -- Kick BN out, save Quant factor
			FROM r_existing r
			JOIN ex e ON r.i_combo = e.ri_combo
				AND r.d_combo = e.rd_combo
				AND r.quant_value = e.r_value
				AND r.quant_unit_id = e.quant_unit_id
				AND r.bs = 0
				AND r.mf_id = 0
				AND r.bn_id = 0
				AND e.concept_id < 0
			JOIN relationship_to_concept rc ON rc.concept_id_2 = e.df_id
			JOIN relationship_to_concept rc2 ON rc.concept_code_1 = rc2.concept_code_1
				AND rc2.concept_id_2 = r.df_id
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
			JOIN internal_relationship_stage i ON rc.concept_code_1 = i.concept_code_2
				AND cr.concept_code_1 = i.concept_code_1
			ORDER BY cr.concept_code_1,
				rc2.precedence,
				r.concept_id
			)
		
		UNION ALL
		
		(
			SELECT DISTINCT ON (cr.concept_code_1) cr.concept_code_1 AS from_code,
				r.concept_id,
				5 -- Map Branded Drug to corresponding Clinical Drug (save box size)
			FROM r_existing r
			JOIN ex e ON r.i_combo = e.ri_combo
				AND r.d_combo = e.rd_combo
				AND r.bs = e.bs
				AND r.bn_id = 0
				AND r.quant_value = 0
				AND r.quant_unit_id = 0
				AND r.mf_id = 0
				AND e.concept_id < 0
			JOIN relationship_to_concept rc ON rc.concept_id_2 = e.df_id
			JOIN relationship_to_concept rc2 ON rc.concept_code_1 = rc2.concept_code_1
				AND rc2.concept_id_2 = r.df_id
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
			JOIN internal_relationship_stage i ON rc.concept_code_1 = i.concept_code_2
				AND cr.concept_code_1 = i.concept_code_1
			ORDER BY cr.concept_code_1,
				rc2.precedence,
				r.concept_id
			)
		
		UNION ALL
		
		(
			SELECT DISTINCT ON (cr.concept_code_1) cr.concept_code_1 AS from_code,
				r.concept_id,
				6 -- Map Branded Drug to corresponding Clinical Drug
			FROM r_existing r
			JOIN ex e ON r.i_combo = e.ri_combo
				AND r.d_combo = e.rd_combo
				AND r.bn_id = 0
				AND r.quant_value = 0
				AND r.quant_unit_id = 0
				AND r.bs = 0
				AND r.mf_id = 0
				AND e.concept_id < 0
			JOIN relationship_to_concept rc ON rc.concept_id_2 = e.df_id
			JOIN relationship_to_concept rc2 ON rc.concept_code_1 = rc2.concept_code_1
				AND rc2.concept_id_2 = r.df_id
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
			JOIN internal_relationship_stage i ON rc.concept_code_1 = i.concept_code_2
				AND cr.concept_code_1 = i.concept_code_1
			ORDER BY cr.concept_code_1,
				rc2.precedence,
				r.concept_id
			)
		
		UNION ALL
		
		(
			SELECT DISTINCT ON (cr.concept_code_1) cr.concept_code_1 AS from_code,
				r.concept_id,
				7 -- Branded Drug Form
			FROM r_existing r
			JOIN ex e ON r.i_combo = e.ri_combo
				AND r.bn_id = e.bn_id
				AND TRIM(r.d_combo) = '' -- was ' ' in r_existing.d_combo
				AND r.quant_value = 0
				AND r.quant_unit_id = 0
				AND r.bs = 0
				AND r.mf_id = 0
				AND e.concept_id < 0
			JOIN relationship_to_concept rc ON rc.concept_id_2 = e.df_id
			JOIN relationship_to_concept rc2 ON rc.concept_code_1 = rc2.concept_code_1
				AND rc2.concept_id_2 = r.df_id
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
			JOIN internal_relationship_stage i ON rc.concept_code_1 = i.concept_code_2
				AND cr.concept_code_1 = i.concept_code_1
			ORDER BY cr.concept_code_1,
				rc2.precedence,
				r.concept_id
			)
		
		UNION ALL
		
		SELECT DISTINCT cr.concept_code_1 AS from_code,
			r.concept_id,
			8 -- Branded Drug Comp
		FROM r_existing r
		JOIN ex e ON r.i_combo = e.ri_combo
			AND r.d_combo = e.rd_combo
			AND r.bn_id = e.bn_id
			AND r.df_id = 0
			AND r.quant_value = 0
			AND r.quant_unit_id = 0
			AND r.bs = 0
			AND r.mf_id = 0
		--AND e.concept_id LIKE '-%'
		JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
			AND cr.relationship_id = 'Maps to'
			AND cr.vocabulary_id_1 = (
				SELECT vocabulary_id
				FROM drug_concept_stage LIMIT 1
				)
			AND cr.vocabulary_id_2 = 'RxNorm Extension'
		
		UNION ALL
		
		(
			SELECT DISTINCT ON (cr.concept_code_1) cr.concept_code_1 AS from_code,
				r.concept_id,
				9 -- Clinical Drug Form
			FROM r_existing r
			JOIN ex e ON r.i_combo = e.ri_combo
				AND TRIM(r.d_combo) = ''
				AND r.bn_id = 0
				AND r.quant_value = 0
				AND r.quant_unit_id = 0
				AND r.bs = 0
				AND r.mf_id = 0
				AND e.concept_id < 0
			JOIN relationship_to_concept rc ON rc.concept_id_2 = e.df_id
			JOIN relationship_to_concept rc2 ON rc.concept_code_1 = rc2.concept_code_1
				AND rc2.concept_id_2 = r.df_id
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
			JOIN internal_relationship_stage i ON rc.concept_code_1 = i.concept_code_2
				AND cr.concept_code_1 = i.concept_code_1
			ORDER BY cr.concept_code_1,
				rc2.precedence,
				r.concept_id
			)
		
		UNION ALL
		
		(
			WITH e AS (
					SELECT e.concept_id,
						e.concept_code,
						u.rd_combo,
						u.ri_combo,
						COALESCE(LENGTH(e.ri_combo) - LENGTH(REPLACE(e.ri_combo, '-', '')), 0) cnt
					FROM ex e,
						UNNEST((
								SELECT REGEXP_SPLIT_TO_ARRAY(e.rd_combo, '-')
								), (
								SELECT REGEXP_SPLIT_TO_ARRAY(e.ri_combo, '-')
								)) AS u(rd_combo, ri_combo)
					),
				r AS (
					SELECT COUNT(r.concept_id) OVER (PARTITION BY e.concept_id) AS cnt_2,
						e.concept_id,
						r.concept_id AS r_concept_id
					FROM e
					JOIN r_existing r ON r.i_combo = e.ri_combo
						AND r.d_combo = e.rd_combo
						AND concept_class_id = 'Clinical Drug Comp'
					)
			SELECT DISTINCT cr.concept_code_1 AS from_code,
				r_concept_id AS concept_id,
				10 AS map_order -- Clinical Drug Comp
			FROM r
			JOIN e USING (concept_id)
			JOIN concept_relationship_stage cr ON cr.concept_code_2 = e.concept_code
				AND cr.relationship_id = 'Maps to'
				AND cr.vocabulary_id_1 = (
					SELECT vocabulary_id
					FROM drug_concept_stage LIMIT 1
					)
				AND cr.vocabulary_id_2 = 'RxNorm Extension'
				AND r.cnt_2 = e.cnt + 1 -- take only those where components counts are equal
		)
		
		UNION ALL
		
		SELECT DISTINCT i.concept_code_1 AS from_code,
			c.concept_id,
			11 -- Drug to ingredient
		FROM internal_relationship_stage i
		JOIN drug_concept_stage ON i.concept_code_2 = concept_code
			AND concept_class_id = 'Ingredient'
		JOIN concept_relationship_stage cr ON cr.concept_code_1 = concept_code
			AND relationship_id = 'Maps to'
		JOIN concept c ON c.concept_code = cr.concept_code_2
			AND c.vocabulary_id LIKE 'Rx%'
		
		UNION ALL
		
		SELECT DISTINCT i.concept_code_2 AS from_code,
			c.concept_id,
			12 -- add the set of source attributes
		FROM internal_relationship_stage i
		JOIN drug_concept_stage ON i.concept_code_2 = concept_code
			AND concept_class_id IN (
				'Ingredient',
				'Brand Name',
				'Suppier',
				'Dose Form'
				)
		JOIN concept_relationship_stage cr ON cr.concept_code_1 = concept_code
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
		JOIN concept c ON c.concept_code = cr.concept_code_2
			AND c.vocabulary_id LIKE 'Rx%'
		--Proceed packs
		
		UNION ALL
		
		-- existing mapping
		SELECT DISTINCT pack_concept_code AS from_code,
			pack_concept_id,
			13
		FROM q_existing_pack q
		JOIN r_existing_pack USING (
				components,
				cnt,
				bn_id,
				bs,
				mf_id
				)
		
		UNION ALL
		
		-- Map Packs to corresponding Rx Packs without a supplier 
		SELECT DISTINCT pack_concept_code AS from_code,
			pack_concept_id,
			14
		FROM q_existing_pack q
		JOIN r_existing_pack USING (
				components,
				cnt,
				bn_id,
				bs
				)
		
		UNION ALL
		
		-- Map Packs to corresponding Rx Packs without a supplier and box_size
		SELECT DISTINCT pack_concept_code AS from_code,
			pack_concept_id,
			15
		FROM q_existing_pack q
		JOIN r_existing_pack USING (
				components,
				cnt,
				bn_id
				)
		
		UNION ALL
		
		-- Map Packs to corresponding Rx Packs without a supplier, box size and brand name
		SELECT DISTINCT pack_concept_code AS from_code,
			pack_concept_id,
			16
		FROM q_existing_pack q
		JOIN r_existing_pack USING (
				components,
				cnt
				)
		) s0
	) s1
WHERE s1.map_order = s1.min_map_order;


DELETE
FROM map_drug
WHERE from_code LIKE 'OMOP%';--delete newly created concepts not to overload concept table

--delete all unnecessary concepts
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;


INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT from_code,
	c.concept_code,
	dc.vocabulary_id,
	c.vocabulary_id,
	CASE 
		WHEN dc.concept_class_id IN (
				'Brand Name',
				'Suppier',
				'Dose Form'
				)
			THEN 'Source - RxNorm eq'
		ELSE 'Maps to'
		END,
	CURRENT_DATE,
	to_date('20991231', 'yyyymmdd')
FROM map_drug m
JOIN drug_concept_stage dc ON dc.concept_code = m.from_code
JOIN concept c ON to_id = c.concept_id

UNION

SELECT concept_code,
	concept_code,
	vocabulary_id,
	vocabulary_id,
	'Maps to',
	CURRENT_DATE,
	to_date('20991231', 'yyyymmdd')
FROM drug_concept_stage
WHERE domain_id = 'Device';

DELETE
FROM concept_stage
WHERE concept_code LIKE 'OMOP%';--save devices and unmapped drug

UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_code IN (
		SELECT a.concept_code
		FROM concept_stage a
		LEFT JOIN concept_relationship_stage ON concept_code_1 = a.concept_code
			AND vocabulary_id_1 = a.vocabulary_id
		LEFT JOIN concept c ON c.concept_code = concept_code_2
			AND c.vocabulary_id = vocabulary_id_2
		WHERE a.standard_concept = 'S'
			AND c.concept_id IS NULL
		);

drop index if exists irs_both;

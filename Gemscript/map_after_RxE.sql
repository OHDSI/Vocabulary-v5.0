--before generic update was run (not a perfect idea because we can't make the whole script in the devv5 but only copying stage tables)
--run ancestor on the data get with RxE builder
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.pConceptAncestor(is_small=>TRUE);
END $_$;

--choose the closest by hierarchy concept --how will "first value" work with duplicates??
DROP TABLE IF EXISTS anc_lev;
CREATE TABLE anc_lev AS
SELECT c.concept_id,
	min(a.max_levels_of_separation) S_level
FROM concept c
JOIN concept_relationship r ON concept_id = concept_id_1
	AND relationship_id = 'Maps to'
JOIN concept_ancestor a ON a.descendant_concept_id = r.concept_id_2
JOIN concept cr ON a.ancestor_concept_id = cr.concept_id
WHERE cr.vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension'
		)
	AND cr.invalid_reason IS NULL
	AND r.invalid_reason IS NULL
	AND c.invalid_reason IS NULL
	AND c.vocabulary_id = (
		SELECT vocabulary_id
		FROM drug_concept_stage limit 1
		)
	AND cr.valid_start_date < (
		SELECT latest_update
		FROM vocabulary_conversion
		WHERE vocabulary_id_v5 = (
				SELECT vocabulary_id
				FROM drug_concept_stage limit 1
				)
		) --exclude RxNorm concepts made in this release --not a problem because in dev_vocab schema there will be no other vocabularies updated
GROUP BY c.concept_id;

DROP TABLE IF EXISTS rel_anc;
CREATE TABLE rel_anc AS
SELECT c.concept_id AS s_c_1,
	cr.concept_id,
	a.max_levels_of_separation S_level
FROM concept c
JOIN concept_relationship r ON concept_id = concept_id_1
	AND relationship_id = 'Maps to'
JOIN concept_ancestor a ON a.descendant_concept_id = r.concept_id_2
JOIN concept cr ON a.ancestor_concept_id = cr.concept_id
WHERE cr.vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension'
		)
	AND cr.invalid_reason IS NULL
	AND r.invalid_reason IS NULL
	AND c.invalid_reason IS NULL
	AND c.vocabulary_id = (
		SELECT vocabulary_id
		FROM drug_concept_stage limit 1
		)
	AND cr.VALID_START_DATE < (
		SELECT latest_update
		FROM vocabulary_conversion
		WHERE vocabulary_id_v5 = (
				SELECT vocabulary_id
				FROM drug_concept_stage limit 1
				)
		) --exclude RxNorm concepts made in this release --not a problem because in dev_vocab schema there will be no other vocabularies updated
	;

--add codes
DROP TABLE IF EXISTS rel_fin;
CREATE TABLE rel_fin AS
SELECT a.*
FROM rel_anc a
JOIN anc_lev b ON a.s_level = b.s_level
	AND b.concept_id = a.s_c_1;

DROP TABLE IF EXISTS q_to_rn;
CREATE TABLE q_to_rn AS
SELECT c.concept_code AS Q_DCODE,
	f.concept_id AS r_did
FROM rel_fin f
JOIN concept c ON c.concept_id = s_c_1;

--calculate weight
DROP TABLE IF EXISTS cnc_rel_class;
CREATE TABLE cnc_rel_class AS
SELECT ri.*,
	ci.concept_class_id AS concept_class_id_1,
	c2.concept_class_id AS concept_class_id_2
FROM concept_relationSHIp ri
JOIN concept ci ON ci.concept_id = ri.concept_id_1
JOIN concept c2 ON c2.concept_id = ri.concept_id_2
WHERE ci.vocabulary_id LIKE 'RxNorm%'
	AND ri.invalid_reason IS NULL
	AND ci.invalid_reason IS NULL
	AND c2.vocabulary_id LIKE 'RxNorm%'
	AND c2.invalid_reason IS NULL;

--define order as combination of attributes number and each attribute weight
DROP TABLE IF EXISTS attrib_cnt;
CREATE TABLE attrib_cnt AS
SELECT concept_id,
	CONCAT (
		count(*),
		max(weight)
		) AS weight
FROM (
	--need to go throught Drug Form / Component to get the Brand Name
	SELECT DISTINCT concept_id,
		3 AS weight
	FROM r_bn
	
	UNION ALL
	
	SELECT concept_id_1,
		1
	FROM cnc_rel_class
	WHERE concept_class_id_2 IN ('Supplier')
	
	UNION ALL
	
	SELECT concept_id_1,
		5
	FROM cnc_rel_class
	WHERE concept_class_id_2 IN ('Dose Form')
	
	UNION ALL
	
	SELECT DISTINCT drug_concept_id,
		6
	FROM drug_strength
	WHERE coalesce(numerator_value, amount_value) IS NOT NULL
	--remove comments when Box_size will be present 
	
	UNION ALL
	
	SELECT DISTINCT drug_concept_id,
		2
	FROM drug_strength
	WHERE Box_size IS NOT NULL
	
	UNION ALL
	
	SELECT DISTINCT drug_concept_id,
		4
	FROM drug_strength
	WHERE DENOMINATOR_VALUE IS NOT NULL
	) AS s0
GROUP BY concept_id

UNION ALL

SELECT concept_id,
	'0'
FROM concept
WHERE concept_class_id = 'Ingredient'
	AND vocabulary_id LIKE 'RxNorm%';

--duplicates analysis
DROP TABLE IF EXISTS Q_DCODE_to_hlc;
CREATE TABLE Q_DCODE_to_hlc AS
SELECT q.Q_DCODE
FROM q_to_rn q
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
	AND c.standard_concept = 'S';

DROP TABLE IF EXISTS dupl;
CREATE TABLE dupl AS
SELECT st.*,
	c.concept_class_id,
	attrib_cnt.*
FROM q_to_rn q
JOIN attrib_cnt ON r_did = concept_id
JOIN drug_concept_stage ds ON Q_DCODE = ds.concept_code
JOIN concept c ON c.concept_id = q.R_DID
JOIN (
	SELECT drug_concept_code,
		count(*) AS cnt
	FROM ds_stage
	GROUP BY drug_concept_code
	HAVING count(*) > 1
	) st ON drug_concept_code = Q_DCODE
WHERE Q_DCODE NOT IN (
		SELECT Q_DCODE
		FROM Q_DCODE_to_hlc
		);

 --best map
DROP TABLE IF EXISTS best_map;
CREATE TABLE best_map AS
SELECT DISTINCT first_value(concept_id) OVER (
		PARTITION BY q_dcode ORDER BY weight DESC
		) AS r_did,
	q_dcode
FROM attrib_cnt
JOIN q_to_rn ON r_did = concept_id
WHERE Q_DCODE NOT IN (
		SELECT drug_concept_code
		FROM dupl
		)

UNION

SELECT CONCEPT_ID,
	drug_concept_code
FROM dupl
WHERE WEIGHT = '0';
SELECT error_type,
	COUNT(*) AS cnt
FROM (
	-- 1. Hierarchical redundancy
	-- Finds redundant mappings where both parent and child concepts are mapped for the same source code.
	SELECT t.source_code,
		'Hierarchical redundancy' AS error_type
	FROM (
		WITH pairs AS (
			SELECT DISTINCT
				m1.source_code,
				m1.target_concept_id AS parent_id,
				m2.target_concept_id AS child_id
			FROM maps_for_load_stage m1
			JOIN maps_for_load_stage m2
			  ON m1.source_code = m2.source_code AND m1.target_concept_id <> m2.target_concept_id
			JOIN concept_ancestor ca
			  ON ca.ancestor_concept_id = m1.target_concept_id AND ca.descendant_concept_id = m2.target_concept_id
			WHERE m1.rank_num IN (1, 2) AND m2.rank_num IN (1, 2)
		),
		annotated AS (
			SELECT DISTINCT p.source_code, cp.concept_name AS target_concept_name, p.parent_id AS target_concept_id, 'parent'::text AS ancestry, mp.map_type
			FROM pairs p JOIN maps_for_load_stage mp ON mp.source_code = p.source_code AND mp.target_concept_id = p.parent_id
			JOIN concept cp ON cp.concept_id = p.parent_id
			UNION
			SELECT DISTINCT p.source_code, cc.concept_name, p.child_id AS target_concept_id, 'child'::text AS ancestry, mc.map_type
			FROM pairs p JOIN maps_for_load_stage mc ON mc.source_code = p.source_code AND mc.target_concept_id = p.child_id
			JOIN concept cc ON cc.concept_id = p.child_id
		)
		SELECT a.source_code
		FROM annotated a
		WHERE
			(a.ancestry = 'parent' AND (a.target_concept_name !~* '\yAND\y|\yAND/OR\y' OR a.source_code IN ('147000','144969','120495','120405','119027','114686','141945','116666','127739','127738','127737','127736','127735','127733','124533','117072')))
			OR (a.ancestry = 'child' AND a.target_concept_name ~* '\yAND\y|\yAND/OR\y' AND a.source_code NOT IN ('147000','144969','120495','120405','119027','114686','141945','116666','127739','127738','127737','127736','127735','127733','124533','117072'))
	) t
	
	UNION ALL
	-- 2. Unexpected rule combinations
	-- Finds source codes that were mapped by unexpected combinations of rules.
	SELECT u.source_code,
		'Unexpected rule combinations' AS error_type
	FROM (
		SELECT
			source_code,
			STRING_AGG(DISTINCT rule_applied, ' | ' ORDER BY rule_applied) AS applied_rules
		FROM maps_for_load_stage
		WHERE rank_num IN (1, 2)
		GROUP BY source_code
		HAVING COUNT(DISTINCT rule_applied) > 1
	) u
	WHERE
		u.applied_rules NOT IN (
			'2.02: 1 NARROWER-THAN SNOMED alone | 6.04: many non-Standard NARROWER-THAN Drug/Regimen to Standard (OMOP crosswalk)',
			'2.14: Missing SNOMED Regimens | 6.04: many non-Standard NARROWER-THAN Drug/Regimen to Standard (OMOP crosswalk)',
			'2.12: many NARROWER-THAN Drugs and Regimens | 2.13: many NARROWER-THAN SNOMED Regimens'
		)
		AND NOT (u.applied_rules ILIKE '4.01: Missing non-S Combo %') -- 56 - all Drugs and Regimens - it is fine
	UNION ALL
	-- 3. Duplicates
	-- Finds duplicate source_code to target_concept_id mappings.
	SELECT source_code,
		'Duplicates (Source-Target Pairs)' AS error_type
	FROM maps_for_load_stage
	WHERE rank_num IN (1, 2)
	GROUP BY source_code, target_concept_id
	HAVING COUNT(*) > 1 -- fixed in concept_relationship_manual, OMOP mapping crosswalk problem
	UNION ALL
	-- 4 Multiple Domains
	-- Finds source codes mapped to targets belonging to multiple different domains.
	SELECT m.source_code,
		'Multiple Domains' AS error_type
	FROM maps_for_load_stage m
	JOIN concept c ON m.target_concept_id = c.concept_id
	WHERE m.rank_num IN (1, 2)
	GROUP BY m.source_code
	HAVING COUNT(DISTINCT c.domain_id) > 1 -- 731 case - spicifics of the CIEL mappings nature, ok as for this release
	UNION ALL
	-- 5. Different map_type for the same concept
	-- Finds source codes mapped with different map_type to the same concept (Source Code).
	SELECT m.source_code,
		'Different map_type for the same concept' AS error_type
	FROM maps_for_load_stage m
	WHERE m.rank_num IN (1, 2)
	GROUP BY m.source_code
	HAVING COUNT(DISTINCT m.map_type) > 1 -- 6 - not a problem for load stage, but source issue
	UNION ALL
	-- 6. Non-standard target_concept_id
	-- Finds target concept IDs that do not exist in concept.
	SELECT m.source_code,
		'Non-standard target_concept_id (Missing ID)' AS error_type
	FROM maps_for_load_stage m
	LEFT JOIN concept c ON m.target_concept_id = c.concept_id
	WHERE m.rank_num IN (1, 2)
		AND c.concept_id IS NULL
	UNION ALL
	-- 7. Non-standard target_concept_code
	-- Finds target concept codes that do not exist in concept (Less common check, usually ID is used).
	SELECT m.source_code,
		'Non-standard target_concept_code (Missing Code)' AS error_type
	FROM maps_for_load_stage m
	LEFT JOIN concept c ON m.target_concept_code = c.concept_code
	WHERE m.rank_num IN (1, 2)
		AND c.concept_id IS NULL
		
) AS s0
GROUP BY error_type
ORDER BY cnt DESC;

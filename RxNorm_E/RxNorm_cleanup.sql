/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

--create temporary table with new replacement relationships
DROP TABLE IF EXISTS rxe_dupl;
CREATE TABLE rxe_dupl AS
SELECT concept_id_1,
	c1.vocabulary_id AS vocabulary_id_1,
	'Concept replaced by'::VARCHAR AS relationship_id,
	concept_id_2
FROM (
	SELECT first_value(c.concept_id) OVER (
			PARTITION BY lower(c.concept_name) ORDER BY c.vocabulary_id DESC,
				c.concept_name,
				c.concept_id
			) AS concept_id_1,
		c.concept_id AS concept_id_2,
		c.vocabulary_id
	FROM concept c
	JOIN (
		SELECT lower(concept_name) AS concept_name,
			concept_class_id
		FROM concept
		WHERE vocabulary_id LIKE 'RxNorm%'
			AND concept_name NOT LIKE '%...%'
			AND invalid_reason IS NULL
		GROUP BY lower(concept_name),
			concept_class_id
		HAVING count(1) > 1
		
		EXCEPT
		
		SELECT lower(concept_name),
			concept_class_id
		FROM concept
		WHERE vocabulary_id = 'RxNorm'
			AND concept_name NOT LIKE '%...%'
			AND invalid_reason IS NULL
		GROUP BY lower(concept_name),
			concept_class_id
		HAVING count(1) > 1
		) d ON lower(c.concept_name) = lower(d.concept_name)
		AND c.vocabulary_id LIKE 'RxNorm%'
		AND c.invalid_reason IS NULL
	) c_int
JOIN concept c1 ON c1.concept_id = c_int.concept_id_1
JOIN concept c2 ON c2.concept_id = c_int.concept_id_2
WHERE concept_id_1 != concept_id_2
	AND NOT (
		c1.vocabulary_id = 'RxNorm'
		AND c2.vocabulary_id = 'RxNorm'
		);

--make concepts 'U'
UPDATE concept
SET standard_concept = NULL,
	invalid_reason = 'U',
	valid_end_date = CURRENT_DATE
WHERE (
		concept_id,
		vocabulary_id
		) IN (
		SELECT concept_id_1,
			vocabulary_id_1
		FROM rxe_dupl
		);

--insert new replacement relationships
INSERT INTO concept_relationship (
	concept_id_1,
	concept_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT concept_id_1,
	concept_id_2,
	relationship_id,
	CURRENT_DATE,
	to_date('20991231', 'yyyymmdd'),
	NULL
FROM rxe_dupl;

--build new 'Maps to' mappings (or update existing) from deprecated to fresh concept
DROP TABLE IF EXISTS rxe_tmp_replaces;
CREATE TABLE rxe_tmp_replaces AS
SELECT root_concept_id_1,
	concept_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM (
	WITH recursive hierarchy_concepts(ancestor_concept_id, descendant_concept_id, root_ancestor_concept_id, full_path) AS (
			SELECT ancestor_concept_id,
				descendant_concept_id,
				ancestor_concept_id AS root_ancestor_concept_id,
				ARRAY [descendant_concept_id] AS full_path
			FROM concepts
			
			UNION ALL
			
			SELECT c.ancestor_concept_id,
				c.descendant_concept_id,
				root_ancestor_concept_id,
				hc.full_path || c.descendant_concept_id AS full_path
			FROM concepts c
			JOIN hierarchy_concepts hc ON hc.descendant_concept_id = c.ancestor_concept_id
			WHERE c.descendant_concept_id <> ALL (full_path)
			),
		concepts AS (
			SELECT DISTINCT concept_id_1 AS ancestor_concept_id,
				FIRST_VALUE(concept_id_2) OVER (
					PARTITION BY concept_id_1 ORDER BY rel_id ROWS BETWEEN UNBOUNDED PRECEDING
							AND UNBOUNDED FOLLOWING
					) AS descendant_concept_id
			FROM (
				SELECT r.concept_id_1,
					r.concept_id_2,
					CASE 
						WHEN r.relationship_id = 'Concept replaced by'
							THEN 1
						WHEN r.relationship_id = 'Concept same_as to'
							THEN 2
						WHEN r.relationship_id = 'Concept alt_to to'
							THEN 3
						WHEN r.relationship_id = 'Concept poss_eq to'
							THEN 4
						WHEN r.relationship_id = 'Concept was_a to'
							THEN 5
						WHEN r.relationship_id = 'Maps to'
							THEN 6
						END AS rel_id
				FROM concept c1,
					concept c2,
					concept_relationship r
				WHERE (
						r.relationship_id IN (
							'Concept replaced by',
							'Concept same_as to',
							'Concept alt_to to',
							'Concept poss_eq to',
							'Concept was_a to'
							)
						OR (
							r.relationship_id = 'Maps to'
							AND c2.invalid_reason = 'U'
							)
						)
					AND r.invalid_reason IS NULL
					AND c1.concept_id = r.concept_id_1
					AND c2.concept_id = r.concept_id_2
					AND (
						(
							(
								(
									c1.vocabulary_id = c2.vocabulary_id
									AND c1.vocabulary_id NOT IN (
										'RxNorm',
										'RxNorm Extension'
										)
									AND c2.vocabulary_id NOT IN (
										'RxNorm',
										'RxNorm Extension'
										)
									)
								OR (
									c1.vocabulary_id IN (
										'RxNorm',
										'RxNorm Extension'
										)
									AND c2.vocabulary_id IN (
										'RxNorm',
										'RxNorm Extension'
										)
									)
								)
							AND r.relationship_id <> 'Maps to'
							)
						OR r.relationship_id = 'Maps to'
						)
					AND c2.concept_code <> 'OMOP generated'
					AND r.concept_id_1 <> r.concept_id_2
				) AS s0
			)
	SELECT hc.root_ancestor_concept_id AS root_concept_id_1,
		hc.descendant_concept_id AS concept_id_2,
		'Maps to'::VARCHAR(20) AS relationship_id,
		TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
		TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
		NULL::VARCHAR(1) AS invalid_reason
	FROM hierarchy_concepts hc
	WHERE NOT EXISTS (
			/*same as oracle's CONNECT_BY_ISLEAF*/
			SELECT 1
			FROM hierarchy_concepts hc_int
			WHERE hc_int.ancestor_concept_id = hc.descendant_concept_id
			)
	) AS s1
--rule b) from generic_udpate
WHERE NOT EXISTS (
		SELECT 1
		FROM concept c_int
		WHERE c_int.concept_id = concept_id_2
			AND COALESCE(c_int.standard_concept, 'C') = 'C'
		);


UPDATE concept_relationship r
SET invalid_reason = NULL,
	valid_end_date = i.valid_end_date
FROM rxe_tmp_replaces i
WHERE r.concept_id_1 = i.root_concept_id_1
	AND r.concept_id_2 = i.concept_id_2
	AND r.relationship_id = i.relationship_id
	AND r.invalid_reason IS NOT NULL;

INSERT INTO concept_relationship (
	concept_id_1,
	concept_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT *
FROM rxe_tmp_replaces i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship cr_int
		WHERE cr_int.concept_id_1 = i.root_concept_id_1
			AND cr_int.concept_id_2 = i.concept_id_2
			AND cr_int.relationship_id = i.relationship_id
		);

DROP TABLE rxe_tmp_replaces;

--'Maps to' or 'Mapped from' relationships should not exist where 
-- a) the source concept has standard_concept = 'S', unless it is to self
-- b) the target concept has standard_concept = 'C' or NULL
-- c) the target concept has invalid_reason='D' or 'U'
UPDATE concept_relationship
SET valid_end_date = CURRENT_DATE,
	invalid_reason = 'D'
WHERE ctid IN (
		SELECT r.ctid
		FROM concept_relationship r,
			concept c1,
			concept c2
		WHERE r.concept_id_1 = c1.concept_id
			AND r.concept_id_2 = c2.concept_id
			AND (
				(
					c1.standard_concept = 'S'
					AND c1.concept_id != c2.concept_id
					) -- rule a)
				OR COALESCE(c2.standard_concept, 'X') != 'S' -- rule b)
				OR c2.invalid_reason IN (
					'U',
					'D'
					) -- rule c)
				)
			AND r.relationship_id = 'Maps to'
			AND r.invalid_reason IS NULL
		);

--deprecate replacement records if target concept was deprecated
UPDATE concept_relationship cr
SET invalid_reason = 'D',
	valid_end_date = CURRENT_DATE
FROM (
	WITH RECURSIVE hierarchy_concepts(concept_id_1, concept_id_2, relationship_id, full_path) AS (
			SELECT concept_id_1,
				concept_id_2,
				relationship_id,
				ARRAY [concept_id_1] AS full_path
			FROM upgraded_concepts
			WHERE concept_id_2 IN (
					SELECT concept_id_2
					FROM upgraded_concepts
					WHERE invalid_reason = 'D'
					)
			
			UNION ALL
			
			SELECT c.concept_id_1,
				c.concept_id_2,
				c.relationship_id,
				hc.full_path || c.concept_id_1 AS full_path
			FROM upgraded_concepts c
			JOIN hierarchy_concepts hc ON hc.concept_id_1 = c.concept_id_2
			WHERE c.concept_id_1 <> ALL (full_path)
			),
		upgraded_concepts AS (
			SELECT r.concept_id_1,
				r.concept_id_2,
				r.relationship_id,
				c2.invalid_reason
			FROM concept c1,
				concept c2,
				concept_relationship r
			WHERE r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
				AND r.invalid_reason IS NULL
				AND c1.concept_id = r.concept_id_1
				AND c2.concept_id = r.concept_id_2
				AND c1.vocabulary_id = c2.vocabulary_id
				AND c2.concept_code <> 'OMOP generated'
				AND r.concept_id_1 <> r.concept_id_2
			)
	SELECT concept_id_1,
		concept_id_2,
		relationship_id
	FROM hierarchy_concepts
	) i
WHERE cr.concept_id_1 = i.concept_id_1
	AND cr.concept_id_2 = i.concept_id_2
	AND cr.relationship_id = i.relationship_id;

--deprecate concepts if we have no active replacement record in the concept_relationship
UPDATE concept c
SET valid_end_date = CURRENT_DATE,
	invalid_reason = 'D',
	standard_concept = NULL
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship r
		WHERE r.concept_id_1 = c.concept_id
			AND r.invalid_reason IS NULL
			AND r.relationship_id IN (
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept poss_eq to',
				'Concept was_a to'
				)
		)
	AND c.invalid_reason = 'U';

--deprecate 'Maps to' mappings to deprecated and upgraded concepts
UPDATE concept_relationship r
SET valid_end_date = CURRENT_DATE,
	invalid_reason = 'D'
WHERE r.relationship_id = 'Maps to'
	AND r.invalid_reason IS NULL
	AND EXISTS (
		SELECT 1
		FROM concept c
		WHERE c.concept_id = r.concept_id_2
			AND c.invalid_reason IN (
				'U',
				'D'
				)
		);

--reverse (reversing new mappings and deprecate existings)
UPDATE concept_relationship r
SET invalid_reason = i.invalid_reason,
	valid_end_date = i.valid_end_date
FROM (
	SELECT r.*,
		rel.reverse_relationship_id
	FROM concept_relationship r,
		relationship rel
	WHERE r.relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to',
			'Maps to'
			)
		AND r.relationship_id = rel.relationship_id
	) i
WHERE r.concept_id_1 = i.concept_id_2
	AND r.concept_id_2 = i.concept_id_1
	AND r.relationship_id = i.reverse_relationship_id
	AND (
		coalesce(r.invalid_reason, 'X') <> coalesce(i.invalid_reason, 'X')
		OR r.valid_end_date <> i.valid_end_date
		);

INSERT INTO concept_relationship (
	concept_id_1,
	concept_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT i.concept_id_2,
	i.concept_id_1,
	i.reverse_relationship_id,
	i.valid_start_date,
	i.valid_end_date,
	i.invalid_reason
FROM (
	SELECT r.*,
		rel.reverse_relationship_id
	FROM concept_relationship r,
		relationship rel
	WHERE r.relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to',
			'Maps to'
			)
		AND r.relationship_id = rel.relationship_id
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship cr_int
		WHERE cr_int.concept_id_1 = i.concept_id_2
			AND cr_int.concept_id_2 = i.concept_id_1
			AND cr_int.relationship_id = i.reverse_relationship_id
		);

DROP TABLE rxe_dupl;
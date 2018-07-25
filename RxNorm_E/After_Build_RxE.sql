/*****************************************************************************
* Copyright 2016-17 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Christian Reich, Anna Ostropolets
***************************************************************************/

/******************************************************************************
* This script post-processes the result of Build_RxE.sql run against Rxfix    *
* (instead of a real drug database. It needs to be run before                 *
* generic_update.sql. It replaces all newly generated RxNorm Extension codes  *
* with the existing ones. It then new_rxes the few truly new RxNorm          *
* Extension ones                                                              *
******************************************************************************/

/***********************************************************************************************************
* 1. Create table with replacement of RxNorm Extension concept_codes with existing Rxfix/RxO concept_codes *
* and the ones remaining, who's codes need to be new_rxed                                                 *
***********************************************************************************************************/
-- For Rxfix-RxE relationship, pick the best one by name and name length
DROP TABLE IF EXISTS equiv_rxe;
CREATE TABLE equiv_rxe AS
	WITH maps AS (
			SELECT concept_code_1 AS c1_code,
				concept_code_2 AS c2_code,
				CASE 
					WHEN lower(c1.concept_name) = lower(c2.concept_name)
						THEN 1
					ELSE 2
					END AS match,
				length(c1.concept_name) / length(c2.concept_name) AS l
			FROM concept_relationship_stage
			JOIN drug_concept_stage c1 ON c1.concept_code = concept_code_1 -- for name comparison
			JOIN concept_stage c2 ON c2.concept_code = concept_code_2 -- for name comparison
			LEFT JOIN concept rxn ON rxn.concept_code = concept_code_1
				AND rxn.vocabulary_id = 'RxNorm' -- checking it's not a RxNorm
			WHERE relationship_id IN (
					'Maps to',
					'Source - RxNorm eq'
					)
				AND vocabulary_id_1 = 'Rxfix'
				AND vocabulary_id_2 = 'RxNorm Extension'
				AND rxn.concept_id IS NULL
			),
		maps2 AS (
			-- flipping length difference l to be between 0 and 1
			SELECT c1_code,
				c2_code,
				match,
				CASE 
					WHEN l > 1
						THEN 1 / l
					ELSE l
					END AS l
			FROM maps
			)

SELECT DISTINCT first_value(c1_code) OVER (
		PARTITION BY c2_code ORDER BY match,
			l DESC,
			c1_code
		) AS rxf_code,
	c2_code AS rxe_code
FROM maps2;

CREATE INDEX idx_equiv_rxe ON equiv_rxe (rxe_code);
ANALYZE equiv_rxe;

-- create sequence for "tight" OMOP codes
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM (
		SELECT concept_code FROM concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
		UNION ALL
		SELECT concept_code FROM drug_concept_stage where concept_code like 'OMOP%' and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
	) AS s0;
	DROP SEQUENCE IF EXISTS omop_seq;
	EXECUTE 'CREATE SEQUENCE omop_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;


-- new_rxe the new RxE codes, where no traditional will be equiv_rxed
DROP TABLE IF EXISTS new_rxe;
CREATE TABLE new_rxe (
	sparse_code VARCHAR(50),
	tight_code VARCHAR(50)
	);

INSERT INTO new_rxe
SELECT rxe.concept_code AS sparse_code,
	'OMOP' || nextval('omop_seq') AS tight_code
FROM concept_stage rxe
LEFT JOIN concept rxn ON rxn.concept_code = rxe.concept_code
	AND rxn.vocabulary_id = 'RxNorm' -- remove the Rxfix which are really RxNorm
WHERE rxe.vocabulary_id = 'RxNorm Extension'
	AND rxe.concept_code NOT IN (
		SELECT rxe_code
		FROM equiv_rxe
		) -- those will be kept intact
	AND rxn.concept_id IS NULL;

CREATE INDEX idx_new_sparse ON new_rxe (sparse_code);
ANALYZE new_rxe;


-- Invalidate Rxfix records that are not equiv_rxed and rename their link to 'Concept replaced by'
DROP TABLE IF EXISTS inval_rxe;
CREATE TABLE inval_rxe AS
SELECT rxf.concept_code
FROM concept_stage rxf
LEFT JOIN concept rxn ON rxn.concept_code = rxf.concept_code
	AND rxn.vocabulary_id = 'RxNorm' -- remove the Rxfix which are really RxNorm
WHERE rxf.vocabulary_id = 'Rxfix'
	AND rxf.concept_code NOT IN (
		SELECT rxf_code
		FROM equiv_rxe
		) -- those will be gone
	AND rxn.concept_id IS NULL;

-- For Rxfix records that have RxNorm equivalents, rxe_rxn drug_strengh_stage and pack_content_stage records, or replace components with RxNorm
DROP TABLE IF EXISTS rxn_rxn;
CREATE TABLE rxn_rxn AS
SELECT concept_code_1 AS rxf_code,
	concept_code_2 AS rxn_code
FROM concept_relationship_stage
JOIN concept ON concept_code = concept_code_1
	AND vocabulary_id = 'RxNorm' -- remove the Rxfix which are really RxNorm
WHERE relationship_id IN (
		'Maps to',
		'Source - RxNorm eq'
		)
	AND vocabulary_id_1 = 'Rxfix'
	AND vocabulary_id_2 = 'RxNorm';

CREATE INDEX idx_rxn_rxf ON rxn_rxn(rxf_code);
ANALYZE rxn_rxn;

/*******************************************************
* 2. Deal with equivalent rxf-rxe concepts (equiv_rxe) *
*******************************************************/
-- Delete identity relationships 
DELETE
FROM concept_relationship_stage
WHERE concept_code_1 IN (
		SELECT rxf_code
		FROM equiv_rxe
		)
	AND vocabulary_id_1 = 'Rxfix';

-- Delete no longer needed Rxfix concepts 
DELETE
FROM concept_stage
WHERE concept_code IN (
		SELECT rxf_code
		FROM equiv_rxe
		)
	AND vocabulary_id = 'Rxfix';

-- Restore concept_stage: Replace RxNorm Extension concept_codes with the original RxNorm Extension codes from Rxfix
UPDATE concept_stage cs
SET concept_code = e.rxf_code
FROM equiv_rxe e
WHERE cs.concept_code = e.rxe_code
	AND cs.vocabulary_id = 'RxNorm Extension';

-- Restore concept_relationship_stage
UPDATE concept_relationship_stage crs
SET concept_code_1 = e.rxf_code
FROM equiv_rxe e
WHERE crs.concept_code_1 = e.rxe_code
	AND crs.vocabulary_id_1 = 'RxNorm Extension';

UPDATE concept_relationship_stage crs
SET concept_code_2 = e.rxf_code
FROM equiv_rxe e
WHERE crs.concept_code_2 = e.rxe_code
	AND crs.vocabulary_id_1 = 'RxNorm Extension';

-- Restore drug_strength_stage
UPDATE drug_strength_stage ds
SET drug_concept_code = e.rxf_code
FROM equiv_rxe e
WHERE ds.drug_concept_code = e.rxe_code
	AND ds.vocabulary_id_1 = 'RxNorm Extension';

UPDATE drug_strength_stage ds
SET ingredient_concept_code = e.rxf_code
FROM equiv_rxe e
WHERE ds.ingredient_concept_code = e.rxe_code
	AND ds.vocabulary_id_2 = 'RxNorm Extension';

-- Restore pack_concent_stage
UPDATE pack_content_stage pc
SET pack_concept_code = e.rxf_code
FROM equiv_rxe e
WHERE pc.pack_concept_code = e.rxe_code
	AND pc.pack_vocabulary_id = 'RxNorm Extension';

UPDATE pack_content_stage pc
SET drug_concept_code = e.rxf_code
FROM equiv_rxe e
WHERE pc.drug_concept_code = e.rxe_code
	AND pc.drug_vocabulary_id = 'RxNorm Extension';

/*******************************************************************
* 3. Invalidate RxE concepts that are no longer needed (inval_rxe) *
*******************************************************************/
-- Fix the ones with a 'Maps to'
UPDATE concept_stage c
SET vocabulary_id = 'RxNorm Extension',
	valid_end_date = (
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Rxfix'
		) - 1,
	invalid_reason = 'U'
WHERE EXISTS (
		SELECT 1
		FROM inval_rxe i
		WHERE c.concept_code = i.concept_code
		) -- is not slotted for turning into active RxE
	AND EXISTS (
		SELECT 1
		FROM concept_relationship_stage
		WHERE concept_code_1 = c.concept_code
		) -- has a relationship to something
	AND vocabulary_id = 'Rxfix';

-- Obsolete the remaining ones 
UPDATE concept_stage c
SET vocabulary_id = 'RxNorm Extension',
	valid_end_date = (
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Rxfix'
		) - 1,
	invalid_reason = 'D'
WHERE EXISTS (
		SELECT 1
		FROM inval_rxe i
		WHERE c.concept_code = i.concept_code
		) -- is not slotted for turning into active RxE
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage
		WHERE concept_code_1 = c.concept_code
		) -- has a relationship to something
	AND vocabulary_id = 'Rxfix';

-- Change vocabulary_id for all those in concept_relationship_stage
UPDATE concept_relationship_stage c
SET vocabulary_id_1 = 'RxNorm Extension'
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM inval_rxe
		) -- is not slotted for turning into active RxE
	AND vocabulary_id_1 = 'Rxfix';

/***************************************************
* 4. Remove Rxfix that are really RxNorm (rxn_rxn) *
****************************************************/
-- Delete relationships 
DELETE
FROM concept_relationship_stage
WHERE concept_code_1 IN (
		SELECT rxf_code
		FROM rxn_rxn
		)
	AND vocabulary_id_1 = 'Rxfix';

-- Delete concepts 
DELETE
FROM concept_stage
WHERE concept_code IN (
		SELECT rxf_code
		FROM rxn_rxn
		)
	AND vocabulary_id = 'Rxfix';

-- Turn target into RxNorm extension 
UPDATE concept_stage c
SET vocabulary_id = 'RxNorm Extension'
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage
		WHERE concept_code_2 = concept_code
			AND vocabulary_id_1 = 'Rxfix'
		);

-- Add replacement code to new_rxe
insert into new_rxe
select concept_code_2, 'OMOP'||nextval('omop_seq') from concept_relationship_stage where vocabulary_id_1='Rxfix';

-- Turn source into RxNorm
UPDATE concept_stage c
SET vocabulary_id = 'RxNorm',
	valid_end_date = coalesce(nullif(c.valid_end_date, to_date('20991231', 'yyyymmdd')), (
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'Rxfix'
			) - 1),
	invalid_reason = 'U'
WHERE vocabulary_id = 'Rxfix';

-- Fix concept_relationship_stage
UPDATE concept_relationship_stage c
SET vocabulary_id_1 = 'RxNorm'
WHERE vocabulary_id_1 = 'Rxfix';

/**********************************************************************************************
* 5. Condense the remaining RxNorm Extension codes so they don't take up as much number space *
**********************************************************************************************/
-- Fix concept_stage
UPDATE concept_stage cs
SET concept_code = r.tight_code
FROM new_rxe r
WHERE cs.concept_code = r.sparse_code
	AND cs.vocabulary_id = 'RxNorm Extension';

-- Fix concept_relationship_stage
UPDATE concept_relationship_stage crs
SET concept_code_1 = r.tight_code
FROM new_rxe r
WHERE crs.concept_code_1 = r.sparse_code
	AND crs.vocabulary_id_1 = 'RxNorm Extension';

UPDATE concept_relationship_stage crs
SET concept_code_2 = r.tight_code
FROM new_rxe r
WHERE crs.concept_code_2 = r.sparse_code
	AND crs.vocabulary_id_2 = 'RxNorm Extension';

-- Fix drug_strength_stage
UPDATE drug_strength_stage ds
SET drug_concept_code = r.tight_code
FROM new_rxe r
WHERE ds.drug_concept_code = r.sparse_code
	AND ds.vocabulary_id_1 = 'RxNorm Extension';

UPDATE drug_strength_stage ds
SET ingredient_concept_code = r.tight_code
FROM new_rxe r
WHERE ds.ingredient_concept_code = r.sparse_code
	AND ds.vocabulary_id_2 = 'RxNorm Extension';

-- Fix pack_content_stage
UPDATE pack_content_stage pc
SET pack_concept_code = r.tight_code
FROM new_rxe r
WHERE pc.pack_concept_code = r.sparse_code
	AND pc.pack_vocabulary_id = 'RxNorm Extension';

UPDATE pack_content_stage pc
SET drug_concept_code = r.tight_code
FROM new_rxe r
WHERE pc.drug_concept_code = r.sparse_code
	AND pc.drug_vocabulary_id = 'RxNorm Extension';

/******************************************************************************************
* 6. Rename all 'Maps to' and 'Source  RxNorm eq' relationships to 'Concept replaced by' *
******************************************************************************************/
UPDATE concept_relationship_stage
SET relationship_id = 'Concept replaced by'
WHERE relationship_id IN (
		'Maps to',
		'Source - RxNorm eq'
		);

/***************************************************************************************************
* 7. Return all concepts and concept_relationships that were in the base tables but no longer here *
*    The internal RxE will be deprecated, those to ATC will be copied                              *
****************************************************************************************************/
-- Add old RxNorm Extension concepts that no longer are part of the corpus, and deprecate
INSERT INTO concept_stage
SELECT NULL AS concept_id,
	concept_name,
	domain_id,
	'RxNorm Extension',
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Rxfix'
		) - 1 AS valid_end_date,
	'D' AS invalid_reason
FROM concept
WHERE vocabulary_id = 'RxO'
	AND concept_code NOT IN (
		SELECT concept_code
		FROM concept_stage
		WHERE vocabulary_id = 'RxNorm Extension'
		);

-- ... and their relationships
INSERT INTO concept_relationship_stage
SELECT NULL AS concept_id_1,
	NULL AS concept_id_2,
	r.concept_code_1,
	r.concept_code_2,
	r.vocabulary_id_1,
	r.vocabulary_id_2,
	r.relationship_id,
	r.valid_start_date,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Rxfix'
		) - 1 AS valid_end_date,
	'D' AS invalid_reason
FROM (
	SELECT c1.concept_code AS concept_code_1,
		c2.concept_code AS concept_code_2,
		CASE c1.vocabulary_id
			WHEN 'RxO'
				THEN 'RxNorm Extension'
			ELSE c1.vocabulary_id
			END AS vocabulary_id_1,
		CASE c2.vocabulary_id
			WHEN 'RxO'
				THEN 'RxNorm Extension'
			ELSE c2.vocabulary_id
			END AS vocabulary_id_2,
		relationship_id,
		r.valid_start_date,
		rel.reverse_relationship_id
	FROM concept_relationship r
	JOIN concept c1 ON r.concept_id_1 = c1.concept_id
	JOIN concept c2 ON r.concept_id_2 = c2.concept_id
	JOIN relationship rel using (relationship_id)
	-- only within RxE, and but no RxNorm to RxNorm
	WHERE relationship_id NOT IN (
			'Maps to',
			'Mapped from'
			)
		AND (
			c1.vocabulary_id = 'RxO'
			AND c2.vocabulary_id IN (
				'RxNorm',
				'RxO'
				)
			OR c1.vocabulary_id IN (
				'RxNorm',
				'RxO'
				)
			AND c2.vocabulary_id = 'RxO'
			)
	) r
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage s
		WHERE s.concept_code_1 = r.concept_code_1
			AND s.vocabulary_id_1 = r.vocabulary_id_1
			AND s.concept_code_2 = r.concept_code_2
			AND s.vocabulary_id_2 = r.vocabulary_id_2
			AND s.relationship_id = r.relationship_id
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage s1
		WHERE s1.concept_code_1 = r.concept_code_2
			AND s1.vocabulary_id_1 = r.vocabulary_id_2
			AND s1.concept_code_2 = r.concept_code_1
			AND s1.vocabulary_id_2 = r.vocabulary_id_1
			AND s1.relationship_id = r.reverse_relationship_id
		);

-- To ATC etc.
INSERT INTO concept_relationship_stage
SELECT NULL AS concept_id_1,
	NULL AS concept_id_2,
	c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	relationship_id,
	r.valid_start_date,
	r.valid_end_date,
	r.invalid_reason
FROM devv5.concept_relationship r
JOIN devv5.concept c1 ON r.concept_id_1 = c1.concept_id
JOIN devv5.concept c2 ON r.concept_id_2 = c2.concept_id
WHERE c1.vocabulary_id = 'RxNorm Extension'
	AND c2.domain_id = 'Drug'
	AND c2.standard_concept = 'C'
	OR c2.domain_id = 'Drug'
	AND c1.standard_concept = 'C'
	AND c2.vocabulary_id = 'RxNorm Extension';


/**************
* 8. Clean up *
**************/
DROP TABLE equiv_rxe;
DROP TABLE new_rxe;
DROP SEQUENCE omop_seq;
DROP TABLE inval_rxe;
DROP TABLE rxn_rxn;

DO $$
BEGIN
    delete from drug_strength ds where drug_concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from drug_strength ds where ingredient_concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from pack_content ds where pack_concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from pack_content ds where drug_concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from concept_relationship where concept_id_1 in (select concept_id from concept where vocabulary_id='RxO');
    delete from concept_relationship where concept_id_2 in (select concept_id from concept where vocabulary_id='RxO');
    delete from concept_synonym where concept_id in (select concept_id from concept where vocabulary_id='RxO');
    delete from concept where vocabulary_id='RxO';
    delete from vocabulary where vocabulary_id in ('RxO', 'Rxfix'); 
END$$;

/*
drop table drug_concept_stage;
drop pack_content_stage;
drop table ds_stage;
drop table internal_relationship_stage;
drop table pc_stage;
drop table relationship_to_concept;
*/

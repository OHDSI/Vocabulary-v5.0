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
* Date: 2017
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'Read',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.keyv2 LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.keyv2 LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_READ'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. fill CONCEPT_STAGE and concept_relationship_stage from Read
INSERT INTO CONCEPT_STAGE (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT coalesce(kv2.description_long, kv2.description, kv2.description_short) AS concept_name,
	NULL AS domain_id,
	'Read' AS vocabulary_id,
	'Read' AS concept_class_id,
	NULL AS standard_concept,
	kv2.readcode || kv2.termcode AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Read'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.keyv2 kv2;

--Add 'Maps to' from Read to SNOMED
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT RSCCT.ReadCode || RSCCT.TermCode AS concept_code_1,
	-- pick the best map: mapstatus=1, then is_assured=1, then target concept is fresh, then newest date
	FIRST_VALUE(RSCCT.conceptid) OVER (
		PARTITION BY RSCCT.readcode || RSCCT.termcode ORDER BY RSCCT.mapstatus DESC,
			RSCCT.is_assured DESC,
			RSCCT.effectivedate DESC
		) AS concept_code_2,
	'Maps to' AS relationship_id,
	'Read' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Read'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.RCSCTMAP2_UK RSCCT;

--Delete non-existing concepts from concept_relationship_stage
DELETE
FROM concept_relationship_stage crs
WHERE (
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.concept_code_2,
		crs.vocabulary_id_2
		) IN (
		SELECT crm.concept_code_1,
			crm.vocabulary_id_1,
			crm.concept_code_2,
			crm.vocabulary_id_2
		FROM concept_relationship_stage crm
		LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1
			AND c1.vocabulary_id = crm.vocabulary_id_1
		LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1
			AND cs1.vocabulary_id = crm.vocabulary_id_1
		LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2
			AND c2.vocabulary_id = crm.vocabulary_id_2
		LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2
			AND cs2.vocabulary_id = crm.vocabulary_id_2
		WHERE (
				c1.concept_code IS NULL
				AND cs1.concept_code IS NULL
				)
			OR (
				c2.concept_code IS NULL
				AND cs2.concept_code IS NULL
				)
		);

--Add manual sources
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--Add manual 'Maps to' from Read to RxNorm, CVX and SNOMED
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--4. Create mapping to self for fresh concepts
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
SELECT concept_code AS concept_code_1,
	concept_code AS concept_code_2,
	c.vocabulary_id AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c,
	vocabulary v
WHERE c.vocabulary_id = v.vocabulary_id
	AND c.standard_concept = 'S'
	AND NOT EXISTS -- only new mapping we don't already have
	(
		SELECT 1
		FROM concept_relationship_stage i
		WHERE c.concept_code = i.concept_code_1
			AND c.concept_code = i.concept_code_2
			AND c.vocabulary_id = i.vocabulary_id_1
			AND c.vocabulary_id = i.vocabulary_id_2
			AND i.relationship_id = 'Maps to'
		);

--5. Add "subsumes" relationship between concepts where the concept_code is like of another
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
ANALYZE concept_stage;

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
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = c1.vocabulary_id
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c1,
	concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code
	AND NOT EXISTS -- only new mapping we don't already have
	(
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		);
DROP INDEX trgm_idx;

--6. update domain_id for Read from target concepts
--create temporary table read_domain
--if domain_id is empty we use previous and next domain_id or its combination
DROP TABLE IF EXISTS read_domain;
CREATE UNLOGGED TABLE read_domain AS
SELECT concept_code,
	CASE 
		WHEN domain_id IS NOT NULL
			THEN domain_id
		ELSE CASE 
				WHEN prev_domain = next_domain
					THEN prev_domain --prev and next domain are the same (and of course not null both)
				WHEN prev_domain IS NOT NULL
					AND next_domain IS NOT NULL
					THEN CASE 
							WHEN prev_domain < next_domain
								THEN prev_domain || '/' || next_domain
							ELSE next_domain || '/' || prev_domain
							END -- prev and next domain are not same and not null both, with order by name
				ELSE coalesce(prev_domain, next_domain, 'Unknown')
				END
		END domain_id
FROM (
	SELECT concept_code,
		string_agg(domain_id, '/' ORDER BY domain_id) domain_id,
		prev_domain,
		next_domain,
		concept_class_id
	FROM (
		WITH filled_domain AS (
				-- get Read concepts with direct mappings
				SELECT c1.concept_code,
					c2.domain_id
				FROM concept_relationship_stage r,
					concept_stage c1,
					concept c2
				WHERE c1.concept_code = r.concept_code_1
					AND c2.concept_code = r.concept_code_2
					AND c1.vocabulary_id = r.vocabulary_id_1
					AND c2.vocabulary_id = r.vocabulary_id_2
					AND r.vocabulary_id_1 = 'Read'
					AND r.vocabulary_id_2 IN (
							'SNOMED',
							'OMOP Extension',
							'Race',
							'CVX',
							'Gender',
							'Medicare Specialty',
							'NUCC',
							'Type Concept',
							'Visit',
							'CMS Place of Service',
							'Provider'
							)
					AND r.invalid_reason IS NULL
		            AND r.relationship_id = 'Maps to' --Take only Maps to relationships
				)
		SELECT DISTINCT c1.concept_code,
			r1.domain_id,
			c1.concept_class_id,
			(
				SELECT DISTINCT LAST_VALUE(fd.domain_id) OVER (
						ORDER BY fd.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						)
				FROM filled_domain fd
				WHERE fd.concept_code < c1.concept_code
					AND r1.domain_id IS NULL
				) prev_domain,
			(
				SELECT DISTINCT FIRST_VALUE(fd.domain_id) OVER (
						ORDER BY fd.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						)
				FROM filled_domain fd
				WHERE fd.concept_code > c1.concept_code
					AND r1.domain_id IS NULL
				) next_domain
		FROM concept_stage c1
		LEFT JOIN (
			SELECT r.concept_code_1,
				r.vocabulary_id_1,
				c2.domain_id
			FROM concept_relationship_stage r,
				concept c2
			WHERE c2.concept_code = r.concept_code_2
				AND r.vocabulary_id_2 = c2.vocabulary_id
				AND r.relationship_id = 'Maps to' --Take only Maps to relationships
					AND c2.vocabulary_id IN (
						'SNOMED',
						'OMOP Extension',
						'Race',
						'CVX',
						'Gender',
						'Medicare Specialty',
						'NUCC',
						'Type Concept',
						'Visit',
						'CMS Place of Service',
						'Provider'
						)
			) r1 ON r1.concept_code_1 = c1.concept_code
			AND r1.vocabulary_id_1 = c1.vocabulary_id
		WHERE c1.vocabulary_id = 'Read'
		) AS s0
	GROUP BY concept_code,
		prev_domain,
		next_domain,
		concept_class_id
	) AS s1;

-- INDEX was set as UNIQUE to prevent concept_code duplication    
CREATE UNIQUE INDEX idx_read_domain ON read_domain (concept_code);

--7. Simplify the list by removing Observations, Metadata and Type Concept
UPDATE read_domain
SET domain_id = trim('/' FROM replace('/' || domain_id || '/', '/Observation/', '/'))
WHERE '/' || domain_id || '/' LIKE '%/Observation/%'
	AND devv5.instr(domain_id, '/') <> 0;

UPDATE read_domain
SET domain_id = trim('/' FROM replace('/' || domain_id || '/', '/Metadata/', '/'))
WHERE '/' || domain_id || '/' LIKE '%/Metadata/%'
	AND devv5.instr(domain_id, '/') <> 0;

UPDATE read_domain
SET domain_id = trim('/' FROM replace('/' || domain_id || '/', '/Type Concept/', '/'))
WHERE '/' || domain_id || '/' LIKE '%/Type Concept/%'
	AND devv5.instr(domain_id, '/') <> 0;

--reducing some domain_id if his length>20
UPDATE read_domain
SET domain_id = 'Meas/Procedure'
WHERE domain_id = 'Measurement/Procedure';

UPDATE read_domain
SET domain_id = 'Condition/Meas'
WHERE domain_id = 'Condition/Measurement';

UPDATE read_domain
SET domain_id = 'Specimen'
WHERE domain_id = 'Measurement/Specimen';

UPDATE read_domain
SET domain_id = 'Measurement'
WHERE domain_id = 'Measurement/Meas Value';

UPDATE read_domain
SET domain_id = 'Condition'
WHERE domain_id = 'Condition/Measurement/Spec Disease Status';

UPDATE read_domain
SET domain_id = 'Condition'
WHERE domain_id = 'Condition/Spec Disease Status';

UPDATE read_domain
SET domain_id = 'Measurement'
WHERE domain_id = 'Measurement/Spec Disease Status';

UPDATE read_domain
SET domain_id = 'Condition'
WHERE domain_id = 'Condition/Race';

UPDATE read_domain
SET domain_id = 'Procedure'
WHERE domain_id = 'Procedure/Visit';

UPDATE read_domain
SET domain_id = 'Procedure'
WHERE domain_id = 'Condition/Procedure';

UPDATE read_domain
SET domain_id = 'Observation'
WHERE domain_id = 'Metadata';

UPDATE read_domain
SET domain_id = 'Condition'
WHERE domain_id = 'Condition/Drug/Procedure';

UPDATE read_domain
SET domain_id = 'Visit'
WHERE domain_id = 'Provider/Visit';

-- Check that all domain_id are exists in domain table
ALTER TABLE read_domain ADD CONSTRAINT fk_read_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id);

--8. update each domain_id with the domains field from read_domain.
UPDATE concept_stage c
SET domain_id = rd.domain_id
FROM read_domain rd
WHERE rd.concept_code = c.concept_code
	AND c.vocabulary_id = 'Read';

--9. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--10. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--11. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--12. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--13. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--14. fix domain_ids for mappings to RxNorm and CVX
UPDATE concept_stage cs
SET domain_id = rd.domain_id
FROM (
	SELECT DISTINCT first_value(c.domain_id) OVER (
			PARTITION BY crs.concept_code_1 ORDER BY crs.vocabulary_id_2,
				crs.concept_code_2
			) AS domain_id,
		crs.concept_code_1,
		crs.vocabulary_id_1
	FROM concept c,
		concept_relationship_stage crs
	WHERE c.concept_code = crs.concept_code_2
		AND c.vocabulary_id = crs.vocabulary_id_2
		AND crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL
		AND crs.vocabulary_id_2 IN (
			'RxNorm',
			'CVX'
			)
		AND crs.vocabulary_id_1 = 'Read'
	) rd
WHERE rd.concept_code_1 = cs.concept_code
	AND rd.vocabulary_id_1 = cs.vocabulary_id
	AND cs.vocabulary_id = 'Read';

--15. Clean up
DROP TABLE read_domain;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script

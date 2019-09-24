DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'KCD7',
	pVocabularyDate			=> TO_DATE('20170701','yyyymmdd') ,
	pVocabularyVersion		=> '7th revision',
	pVocabularyDevSchema	=> 'dev_kcd7'
);
END $_$;


--  Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- Load into concept_stage
INSERT INTO concept_stage
(
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
SELECT DISTINCT TRIM(english_description),
       NULL,
       'KCD7',
       'KCD7 code',
       NULL,
       CASE
         WHEN kcd_Cd ~ '^\w\d\d$' THEN kcd_Cd
         WHEN kcd_Cd !~ '^\w\d\d$' THEN concat (SUBSTRING(kcd_Cd,'^\w\d\d'),'.',SUBSTRING(kcd_Cd,'^\w\d\d(\d+)$'))
       END,-- insert dot into code 
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'KCD7'),
	   TO_DATE('20991231','yyyymmdd'),
       NULL
FROM sources.kcd7
;



--load into concept_synonym_stage
INSERT INTO concept_synonym_stage
(
  synonym_concept_code,
  synonym_name,
  synonym_vocabulary_id,
  language_concept_id
)
SELECT CASE
         WHEN kcd_Cd ~ '^\w\d\d$' THEN kcd_Cd
         WHEN kcd_Cd !~ '^\w\d\d$' THEN concat (SUBSTRING(kcd_Cd,'^\w\d\d'),'.',SUBSTRING(kcd_Cd,'^\w\d\d(\d+)$'))
       END AS synonym_concept_code,
       korean_description AS synonym_name,
       'KCD7' AS synonym_vocabulary_id,
       4175771 AS language_concept_id -- Korean
       FROM sources.kcd7
;




-- Add mapping through ICD10 
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
  SELECT DISTINCT cs.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	cs.vocabulary_id AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	cr.relationship_id AS relationship_id,
	current_date as valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
  FROM  concept_stage cs
    JOIN concept c
      ON c.concept_code = cs.concept_code
     AND c.vocabulary_id = 'ICD10'
    JOIN concept_relationship cr
      ON c.concept_id = cr.concept_id_1
     AND cr.invalid_reason IS NULL
    JOIN concept c2
      ON c2.concept_id = cr.concept_id_2
     AND c2.vocabulary_id = 'SNOMED'
;



--Add "subsumes" relationship between concepts where the concept_code is like of another
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
	current_date as valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c1,
	concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code
;


--update domain_id for KCD7 from SNOMED
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	SELECT DISTINCT cs1.concept_code,
		first_value(c2.domain_id) OVER (
			PARTITION BY cs1.concept_code ORDER BY CASE c2.domain_id
					WHEN 'Condition'
						THEN 1
					WHEN 'Observation'
						THEN 2
					WHEN 'Procedure'
						THEN 3
					WHEN 'Measurement'
						THEN 4
					WHEN 'Device'
						THEN 5
					ELSE 6
					END
			) AS domain_id
	FROM concept_relationship_stage crs
	JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
		AND cs1.vocabulary_id = 'KCD7'
	JOIN concept c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
		AND c2.vocabulary_id = 'SNOMED'
	WHERE crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL
			) i
WHERE i.concept_code = cs.concept_code
	AND cs.vocabulary_id = 'KCD7'
;

--if domain_id is empty we use previous and next domain_id
DROP TABLE IF EXISTS KCD7_domain;
CREATE UNLOGGED TABLE KCD7_domain AS
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
				ELSE coalesce(prev_domain, next_domain, 'Condition')
				END
		END domain_id
FROM (
	SELECT concept_code,
		string_agg(domain_id, '/' ORDER BY domain_id) domain_id,
		prev_domain,
		next_domain
	FROM (
		SELECT DISTINCT c1.concept_code,
			r1.domain_id,
			(
				SELECT DISTINCT LAST_VALUE(fd.domain_id) OVER (
						ORDER BY fd.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						)
				FROM concept_stage fd
				WHERE fd.concept_code < c1.concept_code
					AND r1.domain_id IS NULL
				) prev_domain,
			(
				SELECT DISTINCT FIRST_VALUE(fd.domain_id) OVER (
						ORDER BY fd.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						)
				FROM concept_stage fd
				WHERE fd.concept_code > c1.concept_code
					AND r1.domain_id IS NULL
				) next_domain
		FROM concept_stage c1
		LEFT JOIN concept_stage r1 ON r1.concept_code = c1.concept_code
		WHERE c1.vocabulary_id = 'KCD7'
		) AS s0
	GROUP BY concept_code,
		prev_domain,
		next_domain
	) AS s1;
	

UPDATE concept_stage c
SET domain_id = rd.domain_id
FROM KCD7_domain rd
WHERE rd.concept_code = c.concept_code
	AND c.vocabulary_id = 'KCD7';
	


--Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;


DROP TABLE KCD7_domain;

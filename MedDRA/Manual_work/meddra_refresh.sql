--7.1. Backup concept_relationship_manual table and concept_manual table.
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE FORMAT('create table %I as select * from concept_relationship_manual',
                       'concept_relationship_manual_backup_' || update);

    END
$body$;


--restore concept_relationship_manual table (run it only if something went wrong)
/*TRUNCATE TABLE dev_meddra.concept_relationship_manual;
INSERT INTO dev_meddra.concept_relationship_manual
SELECT * FROM dev_meddra.concept_relationship_manual_backup_2024_01_09;*/

DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE FORMAT('create table %I as select * from concept_manual',
                       'concept_manual_backup_' || update);

    END
$body$;

--restore concept_manual table (run it only if something went wrong)

/*TRUNCATE TABLE dev_meddra.concept_manual;
INSERT INTO dev_meddra.concept_manual
SELECT * FROM dev_meddra.concept_manual_backup_YYYY_MM_DD;*/


--7.2 Create combined tables with mapping candidates from different sources: meddra_mapped,meddra_snomed / snomed_meddra, meddra_umls, meddra_snomed_eq, meddra_ICD10
--! It's necessary one time to create meddra_environment

CREATE TABLE dev_meddra.meddra_pt_only_081123 AS

WITH tab AS (

-- all MedDRA-SNOMED mappings from manual table (meddra_mapped)

SELECT m.source_code, m.source_code_description, m.to_value, m.target_concept_code, m.target_concept_name,
       m.target_concept_id,m.target_concept_class_id, m.target_standard_concept, m.target_invalid_reason,
       m.target_domain_id, m.target_vocabulary_id, 'meddra_mapped' AS origin_field
FROM dev_meddra.meddra_mapped AS m
INNER JOIN dev_meddra.concept AS c
ON m.source_code = c.concept_code
WHERE c.vocabulary_id='MedDRA' AND c.concept_class_id='PT' -- add LLT if necessary

UNION ALL

-- all MedDRA-SNOMED / inverted SNOMED-MedDRA mappings from MSSO


(SELECT mts.meddra_code AS source_code, mts.meddra_llt AS source_code_description,  '' AS to_value, c.concept_code AS target_concept_code,
       c.concept_name AS target_concept_name, c.concept_id AS target_concept_id,
       c.concept_class_id AS target_concept_class_id, c.standard_concept AS target_standard_concept,
       c.invalid_reason AS target_invalid_reason, c.domain_id AS target_domain_id, c.vocabulary_id AS target_vocabulary_id,
'meddra_snomed' AS origin_field
FROM SOURCES.MEDDRA_MAPSTO_SNOMED AS mts
INNER JOIN dev_meddra.concept AS c
    ON mts.snomed_code = c.concept_code AND c.vocabulary_id='SNOMED' AND c.standard_concept='S'
INNER JOIN devv5.concept AS cc
    ON mts.meddra_code=cc.concept_code AND cc.vocabulary_id='MedDRA' AND cc.concept_class_id='PT' -- add LLT if necessary

UNION

SELECT mts.meddra_code AS source_code, mts.meddra_llt AS source_code_description,  '' AS to_value, c.concept_code AS target_concept_code,
       c.concept_name AS target_concept_name, c.concept_id AS target_concept_id,
       c.concept_class_id AS target_concept_class_id, c.standard_concept AS target_standard_concept,
       c.invalid_reason AS target_invalid_reason, c.domain_id AS target_domain_id, c.vocabulary_id AS target_vocabulary_id,
'snomed_meddra' AS origin_field
FROM SOURCES.MEDDRA_MAPSTO_SNOMED AS mts
INNER JOIN dev_meddra.concept AS c
    ON mts.snomed_code = c.concept_code AND c.vocabulary_id='SNOMED' AND c.standard_concept='S'
INNER JOIN devv5.concept AS cc
    ON mts.meddra_code=cc.concept_code AND cc.vocabulary_id='MedDRA' AND cc.concept_class_id='PT' -- add LLT if necessary
)

UNION ALL

-- all MedDRA-SNOMED mappings from previously existed MedDRA-SNOMED eq

(SELECT c.concept_code AS source_code, c.concept_name AS source_code_description, '' AS to_value,
       cc.concept_code AS target_concept_code,
       cc.concept_name AS target_concept_name, cc.concept_id AS target_concept_id,
       cc.concept_class_id AS target_concept_class_id, cc.standard_concept AS target_standard_concept,
       cc.invalid_reason AS target_invalid_reason, cc.domain_id AS target_domain_id, cc.vocabulary_id AS target_vocabulary_id,
'MedDRA-SNOMED eq' AS origin_field
FROM devv5.concept AS c
INNER JOIN devv5.concept_relationship AS cr
ON c.concept_id = cr.concept_id_1
INNER JOIN devv5.concept AS cc
ON cr.concept_id_2 = cc.concept_id
LEFT JOIN devv5.concept_relationship AS cr2
ON cr.concept_id_1 = cr2.concept_id_1 AND cr2.relationship_id='Maps to'
WHERE c.vocabulary_id='MedDRA' AND cc.vocabulary_id='SNOMED' and cr.relationship_id = 'MedDRA - SNOMED eq' AND cr2.relationship_id IS NULL AND c.concept_class_id='PT' -- add LLT if necessary
AND cc.standard_concept='S'
ORDER BY c.concept_id)

UNION ALL

-- all MedDRA-SNOMED mappings via ICD10

(
    WITH tab AS(
SELECT icd.meddra_llt, icd.meddra_code, ccc.concept_class_id AS meddra_concept_class_id, cc.*
    FROM SOURCES.MEDDRA_MAPPEDFROM_ICD10 AS icd
INNER JOIN devv5.concept AS ccc
        ON ccc.concept_code = icd.meddra_code AND ccc.vocabulary_id='MedDRA'
INNER JOIN devv5.concept AS c
ON icd.icd10_code = c.concept_code
INNER JOIN devv5.concept_relationship AS cr
ON c.concept_id = cr.concept_id_1
INNER JOIN devv5.concept AS cc
ON cr.concept_id_2 = cc.concept_id
WHERE c.vocabulary_id LIKE 'ICD%' AND c.invalid_reason IS NULL AND cr.invalid_reason IS NULL AND cr.relationship_id = 'Maps to'
      AND cc.vocabulary_id = 'SNOMED' AND cc.invalid_reason IS NULL AND cc.standard_concept = 'S' AND ccc.concept_class_id='PT'
ORDER BY meddra_llt)

SELECT DISTINCT tab.meddra_code AS source_code, tab.meddra_llt AS source_code_decription, '' AS to_value,
             cccc.concept_code AS target_concept_code, cccc.concept_name AS target_concept_name, cccc.concept_id AS target_concept_id,
             cccc.concept_class_id AS target_concept_class_id, cccc.standard_concept AS target_standard_concept,
             cccc.invalid_reason AS target_invalid_reason, cccc.domain_id AS target_domain_id, cccc.vocabulary_id AS target_vocabulary_id,
             'meddra-ICD10-SNOMED' AS origin_field
FROM tab
INNER JOIN devv5.concept AS cccc
ON tab.concept_id = cccc.concept_id AND cccc.standard_concept='S'
INNER JOIN devv5.concept AS c5
ON tab.meddra_code=c5.concept_code AND c5.vocabulary_id='MedDRA' AND c5.concept_class_id='PT')


UNION ALL

-- all MedDRA-SNOMED mappings from UMLS

(WITH cte_concept_code AS (
  SELECT concept_code
  FROM dev_meddra.concept
  WHERE vocabulary_id='MedDRA'
    AND concept_class_id='PT'
    AND invalid_reason IS NULL
),
cte_t1_t2 AS (
  SELECT t1.cui AS cui, t1.sab AS source_vocabulary_id, t1.code as source_code, t1.str as source_code_description,
         t2.sab as target_vocabulary_id, t2.code AS target_concept_code, t2.str AS target_concept_name, row_number() over (partition by t1.code ||' '||t2.code) AS sort
  FROM sources.mrconso AS t1
  INNER JOIN sources.mrconso AS t2
    ON t1.cui = t2.cui
  WHERE t1.code IN (SELECT concept_code FROM cte_concept_code)
    AND t1.sab ='MDR'
    AND t2.sab = 'SNOMEDCT_US'
    AND t2.code IN (SELECT concept_code FROM dev_meddra.concept WHERE vocabulary_id='SNOMED' AND invalid_reason IS NULL AND standard_concept='S')
)

SELECT source_code, source_code_description, '' AS to_value, target_concept_code, target_concept_name, c.concept_id AS target_concept_id,
c.concept_class_id AS target_concept_class_id, c.standard_concept AS target_standard_concept,
c.invalid_reason AS target_invalid_reason, c.domain_id AS target_domain_id, c.vocabulary_id AS target_vocabulary_id,
'UMLS' AS origin_field
FROM cte_t1_t2
INNER JOIN dev_meddra.concept AS c ON cte_t1_t2.target_concept_code = c.concept_code AND c.vocabulary_id='SNOMED'
WHERE sort=1)

),

tab2 AS (
SELECT c.concept_code, c.concept_name, c.concept_class_id, string_agg (CONCAT (cc.concept_name,'(', cc.concept_class_id,')'), '-'
    ORDER BY ca.max_levels_of_separation DESC) AS hierarchy
FROM dev_meddra.concept c
JOIN dev_meddra.concept_ancestor ca
    ON c.concept_id = ca.descendant_concept_id
JOIN dev_meddra.concept cc
    ON ca.ancestor_concept_id = cc.concept_id
WHERE
c.vocabulary_id = 'MedDRA'
AND cc.vocabulary_id = 'MedDRA'
AND ca.max_levels_of_separation!=0
GROUP BY c.concept_code, c.concept_name, c.concept_class_id
ORDER BY c.concept_code)


SELECT tab2.hierarchy,
       t.source_code,
 t.source_code_description, c.concept_class_id, c.invalid_reason,  c.domain_id, t.to_value,
 '' AS flag, t.target_concept_id,
       t.target_concept_code, t.target_concept_name, t.target_concept_class_id, t.target_standard_concept,
       t.target_invalid_reason, t.target_domain_id, t.target_vocabulary_id, t.origin_field, '' AS final_decision
FROM tab AS t
INNER JOIN dev_meddra.concept AS c
ON t.source_code=c.concept_code AND c.vocabulary_id='MedDRA'
   AND c.concept_class_id='PT'
INNER JOIN tab2 ON tab2.concept_code=t.source_code
ORDER BY t.source_code;

-- 7.3 Create meddra_environment table
--! It's necessary one time to create meddra_environment

--CREATE TABLE meddra_environment AS
WITH tab AS(
SELECT mpt.hierarchy, mpt.source_code, c.concept_name AS source_code_description, mpt.concept_class_id, mpt.invalid_reason, mpt.domain_id,
       mpt.to_value, mpt.flag, cc.concept_id AS target_concept_id, cc.standard_concept AS target_standard_concept,
       cc.concept_code AS target_concept_code, cc.concept_name AS target_concept_name,
       cc.concept_class_id AS target_concept_class_id, cc.invalid_reason AS target_invalid_reason, cc.domain_id AS target_domain_id,
       cc.vocabulary_id AS target_vocabulary_id,
       mpt.origin_field
FROM dev_meddra.meddra_pt_only_081123 AS mpt
INNER JOIN devv5.concept AS c
    ON mpt.source_code = c.concept_code AND c.vocabulary_id='MedDRA'
INNER JOIN devv5.concept AS cc
ON mpt.target_concept_id = cc.concept_id
ORDER BY mpt.source_code, mpt.to_value, cc.concept_id)


SELECT
    source_code,
    source_code_description,
    hierarchy,
    'MedDRA' AS source_vocabulary_id,
    concept_class_id AS source_concept_class_id,
    domain_id AS source_domain_id,
    string_agg(DISTINCT origin_field, ', ' ORDER BY origin_field) AS origin_of_mapping,
    (LENGTH(string_agg(origin_field, ',' ORDER BY origin_field)) - LENGTH(REPLACE(string_agg(origin_field, ',' ORDER BY origin_field), ',', '')))+1 AS count_aggr,
    '' AS for_review,
    to_value AS relationship_id,
    '' AS relationship_id_predicate,
    '' AS decision_date,
    '' AS decision, -- ставим только 1 для принятого, Null для отклоненного
    '' AS comments,
    target_concept_id,
    target_concept_code,
    target_concept_name,
    target_concept_class_id,
    target_standard_concept,
    target_invalid_reason,
    target_domain_id,
    target_vocabulary_id,
    '' AS mapper_id,
    '' AS reviewer_id
FROM
    tab
GROUP BY
    source_code,
    source_code_description,
    hierarchy,
    concept_class_id,
    domain_id,
    to_value,
    target_concept_id,
    target_concept_code,
    target_concept_name,
    target_concept_class_id,
    target_standard_concept,
    target_invalid_reason,
    target_domain_id,
    target_vocabulary_id
ORDER BY source_code, to_value, count_aggr DESC;

--- 7.4 Create google sheets table meddra_mapped for review/manual mapping

SELECT *
FROM
meddra_environment
ORDER BY source_code, relationship_id, count_aggr DESC;

-- 7.5 Truncate meddra_environment table.

--TRUNCATE TABLE dev_meddra.meddra_environment;

-- 7.6 Save the spreadsheet as the 'meddra_environment_table' and upload it into the working schema. Run manual checks (+ specific checks) for meddra_environment table

-- 7.7 Additional checks

-- Check if rows are uploaded correctly

SELECT * FROM dev_meddra.meddra_environment;

-- Check if field 'decision' doesn't contain value '1' (ideally must be NULL rows)

SELECT DISTINCT source_code, source_code_description
FROM dev_meddra.meddra_environment
WHERE source_code NOT IN (SELECT DISTINCT source_code FROM dev_meddra.meddra_environment WHERE decision = '1');

-- Check if field 'relationship_id_predicate' doesn't contain any value (ideally must be NULL rows)

SELECT DISTINCT source_code, source_code_description
FROM dev_meddra.meddra_environment
WHERE source_code NOT IN (
        SELECT DISTINCT source_code
        FROM dev_meddra.meddra_environment
        WHERE relationship_id_predicate = 'eq'
        OR relationship_id_predicate='up'
        OR relationship_id_predicate='down');

-- Check if any discrepancies between relationship_id_predicate and decision fields (ideally must be NULL rows)
SELECT DISTINCT source_code
FROM dev_meddra.meddra_environment
WHERE (relationship_id_predicate='' AND decision='1')
   OR (relationship_id_predicate!='' AND decision='');

-- 7.8 Change concept_relationship_manual table according to meddra_environment table.

--7.8.1 Insert new and update existing relationships

INSERT INTO dev_meddra.concept_relationship_manual AS mapped
    (concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)

	SELECT source_code,
	       target_concept_code,
	       source_vocabulary_id,
	       target_vocabulary_id,
	       m.relationship_id,
	       current_date AS valid_start_date,
           to_date('20991231','yyyymmdd') AS valid_end_date,
           NULL AS invalid_reason
	FROM dev_meddra.meddra_environment m
	WHERE decision='1'

	ON CONFLICT ON CONSTRAINT unique_manual_relationships
	DO UPDATE
	    --In case of mapping 'resuscitation' use current_date as valid_start_date; in case of mapping deprecation use previous valid_start_date
	SET valid_start_date = CASE WHEN excluded.invalid_reason IS NULL THEN excluded.valid_start_date ELSE mapped.valid_start_date END,
	    --In case of mapping 'resuscitation' use 2099-12-31 as valid_end_date; in case of mapping deprecation use current_date
		valid_end_date = CASE WHEN excluded.invalid_reason IS NULL THEN excluded.valid_end_date ELSE current_date END,
		invalid_reason = excluded.invalid_reason
	WHERE ROW (mapped.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.invalid_reason);

--7.8.2 Correction of valid_start_dates and valid_end_dates for deprecation of existing mappings, existing in base, but not manual tables

UPDATE concept_relationship_manual AS crm
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM meddra_environment AS m
    JOIN concept AS c
        ON c.concept_code = m.source_code
        AND m.source_vocabulary_id = c.vocabulary_id
    JOIN concept_relationship AS cr
        ON cr.concept_id_1 = c.concept_id
        AND cr.relationship_id = m.relationship_id
    JOIN concept AS c1
        ON c1.concept_id = cr.concept_id_2
        AND c1.concept_code = m.target_concept_code
        AND c1.vocabulary_id = m.target_vocabulary_id
    WHERE crm.concept_code_1 = m.source_code
        AND crm.vocabulary_id_1 = m.source_vocabulary_id
        AND crm.concept_code_2 = m.target_concept_code
        AND crm.vocabulary_id_2 = m.target_vocabulary_id
        AND crm.relationship_id = m.relationship_id
        AND m.decision = '1'
) AND crm.vocabulary_id_1 = 'MedDRA';


--- -- 7.8.3 Activate mapping, that became valid again
UPDATE dev_meddra.concept_relationship_manual crm
SET invalid_reason = null,
    valid_end_date = to_date('20991231','yyyymmdd'),
    valid_start_date =current_date

-- SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason = 'D' -- activate only deprecated mappings
AND EXISTS (SELECT 1 -- activate mapping if the same exists in the current manual file
                 FROM dev_meddra.meddra_environment crm_new
                 WHERE crm_new.source_code = crm.concept_code_1 --the same source_code is mapped
                     AND crm_new.target_concept_code = crm.concept_code_2 --to the same concept_code
                     AND crm_new.target_vocabulary_id = crm.vocabulary_id_2 --of the same vocabulary
                     AND crm_new.relationship_id = crm.relationship_id --with the same relationship
     )
;

-- 7.9 Create MedDRA-SNOMED hierarchical relationships

WITH tab AS(
SELECT CASE WHEN relationship_id_predicate='eq' OR relationship_id_predicate = 'down' THEN target_concept_code
			WHEN relationship_id_predicate='up' THEN source_code END AS concept_code_1,
		CASE WHEN relationship_id_predicate='eq' OR relationship_id_predicate = 'down' THEN source_code
			WHEN relationship_id_predicate='up' THEN target_concept_code END AS concept_code_2,
		CASE WHEN relationship_id_predicate='eq' OR relationship_id_predicate = 'down' THEN target_vocabulary_id
			WHEN relationship_id_predicate='up' THEN source_vocabulary_id END AS vocabulary_id_1,
		CASE WHEN relationship_id_predicate='eq' OR relationship_id_predicate= 'down' THEN source_vocabulary_id
			WHEN relationship_id_predicate='up' THEN target_vocabulary_id END AS vocabulary_id_2,
		'Is a' as relationship_id,
	    current_date AS valid_start_date,
        to_date('20991231','yyyymmdd') AS valid_end_date,
        NULL AS invalid_reason
FROM dev_meddra.meddra_environment
WHERE decision='1'
)
INSERT INTO dev_meddra.concept_relationship_manual AS mapped
    (concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)
SELECT *
FROM tab;








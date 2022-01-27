--1. Backup concept_relationship_manual table
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
/*TRUNCATE TABLE dev_ndc.concept_relationship_manual;
INSERT INTO dev_ndc.concept_relationship_manual
SELECT * FROM dev_ndc.concept_relationship_manual_backup_YYYY_MM_DD;*/

--2. Create NDC_manual_mapped table and pre-populate it with the resulting manual table of the previous LOINC refresh
--DROP TABLE dev_ndc.NDC_manual_mapped;
CREATE TABLE dev_ndc.NDC_manual_mapped (
    source_concept_id int,
    source_code varchar(255),
    source_code_description varchar(1000),
    comments varchar,
    --flag varchar,
    target_concept_id int,
    target_concept_code varchar(255),
    target_concept_name varchar(255),
    target_concept_class_id varchar(255),
    target_standard_concept varchar(255),
    target_invalid_reason varchar(255),
    target_domain_id varchar(255),
    target_vocabulary_id varchar(255)
);

--3. Select concepts to map and add them to the manual file in the spreadsheet editor.
SELECT c.concept_id as source_concept_id,
       c.concept_code as source_code,
       c.concept_name as source_code_description,
       null as source_count,
       CASE WHEN cr.concept_id_2 is not null THEN 'check' ELSE null END as comments,
       cr.concept_id_2 as target_concept_id
FROM devv5.concept c
LEFT JOIN devv5.concept_relationship cr
ON cr.concept_id_1 = c.concept_id
WHERE vocabulary_id = 'NDC'
AND cr.invalid_reason is null
AND concept_id in ('1799556', '1799558', '1799562', '1799559', '1799560', '1779597', '1779561', '1799760', '1779550', '1799561');

--4. Truncate the NDC_manual_mapped table. Save the spreadsheet as the NDC_manual_mapped table and upload it into the working schema.
TRUNCATE TABLE dev_ndc.NDC_manual_mapped;

--5. Deprecate all mappings that differ from the new version of resulting mapping file.
UPDATE dev_ndc.concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = current_date
--SELECT*FROM concept_relationship_manual
WHERE (concept_code_1, concept_code_2, relationship_id, vocabulary_id_2) IN
      (SELECT concept_code_1, concept_code_2, relationship_id, vocabulary_id_2
       FROM concept_relationship_manual crm_old

       WHERE NOT exists(SELECT source_code,
                               target_concept_code,
                               'NDC',
                               target_vocabulary_id,
                               CASE
                                   WHEN to_value ~* 'value' THEN 'Maps to value'
                                   WHEN to_value ~* 'Is a' THEN 'Is a'
                                   WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                                   ELSE 'Maps to' END
                        FROM dev_ndc.NDC_manual_mapped crm_new
                        WHERE source_code = crm_old.concept_code_1
                          AND target_concept_code = crm_old.concept_code_2
                          AND target_vocabulary_id = crm_old.vocabulary_id_2
                          AND CASE
                                  WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END = crm_old.relationship_id

    )
    AND invalid_reason IS NULL
    )
;

--6. Insert new and corrected mappings into the concept_relationship_manual table.
with mapping AS
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'NDC' AS vocabulary_id_1,
               target_vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM dev_ndc.NDC_manual_mapped
        WHERE target_concept_id != 0
    )

INSERT INTO dev_ndc.concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
    (SELECT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
     FROM mapping m
        WHERE (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
                  NOT IN (SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM dev_ndc.concept_relationship_manual)
    )
;




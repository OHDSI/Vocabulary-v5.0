--Adapted from non-drug vocabularies (LOINC, SNOMED, etc.)

--3.1. Backup concept_relationship_manual table and concept_manual table.
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
/*TRUNCATE TABLE concept_relationship_manual;
INSERT INTO concept_relationship_manual
SELECT * FROM concept_relationship_manual_backup_YYYY_MM_DD;*/

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
/*TRUNCATE TABLE concept_manual;
INSERT INTO concept_manual
SELECT * FROM concept_manual_backup_YYYY_MM_DD;*/

--3.2. Create dmd_mapped table and pre-populate it with the resulting manual table of the previous dmd refresh.
--cr_invalid_reason was added for the possibility to deprecate relationships in concept_relationship table
--DROP TABLE dmd_mapped;
CREATE TABLE dmd_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(50),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    to_value varchar(50),
    cr_invalid_reason varchar(20),
    source varchar(50),
    target_concept_id int,
    target_concept_code varchar(50),
    target_concept_name varchar(255),
    target_concept_class_id varchar(50),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(50),
    target_vocabulary_id varchar(50)
);

--3.3. Review the previous mappings and manually add new to the dmd_mapped table

--3.4. Truncate the dmd_mapped table. Save the spreadsheet as the dmd_mapped table and upload it into the working schema.
TRUNCATE TABLE dmd_mapped;

--3.5. Perform any mapping checks you have set.

--3.6. Iteratively repeat steps 3.3-3.5 if found any issues.

--3.7. Deprecate all mappings that differ from the new version of resulting mapping file.
UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = current_date
WHERE (concept_code_1, concept_code_2, relationship_id, vocabulary_id_2) IN
      (SELECT concept_code_1, concept_code_2, relationship_id, vocabulary_id_2
       FROM concept_relationship_manual crm_old

       WHERE NOT exists(SELECT source_code,
                               target_concept_code,
                               'dm+d',
                               target_vocabulary_id,
                               CASE
                                   WHEN to_value ~* 'value' THEN 'Maps to value'
                                   WHEN to_value ~* 'Is a' THEN 'Is a'
                                   WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                                   ELSE 'Maps to' END
                        FROM dmd_mapped crm_new
                        WHERE source_code = crm_old.concept_code_1
                          AND target_concept_code = crm_old.concept_code_2
                          AND target_vocabulary_id = crm_old.vocabulary_id_2
                          AND CASE
                                  WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END = crm_old.relationship_id
        AND (crm_new.cr_invalid_reason IS NULL OR crm_new.cr_invalid_reason = '')

    )
    AND invalid_reason IS NULL
    )
;

--3.8. Insert new and corrected mappings into the concept_relationship_manual table.
with mapping AS
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'dm+d' AS vocabulary_id_1,
               target_vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END AS relationship_id,
               current_date AS valid_start_date,
               CASE WHEN (cr_invalid_reason NOT IN ('U', 'D') OR cr_invalid_reason IS NULL) THEN to_date('20991231','yyyymmdd')
                   ELSE current_date END AS valid_end_date,
               CASE WHEN (cr_invalid_reason NOT IN ('U', 'D') OR cr_invalid_reason IS NULL) THEN NULL
                ELSE cr_invalid_reason END AS invalid_reason
        FROM dmd_mapped
        WHERE (target_concept_id != 0 OR target_concept_id IS NULL)
    )

INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
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
                  NOT IN (SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM concept_relationship_manual)
    )
;

-- 3.9 Activate mapping, that became valid again
UPDATE concept_relationship_manual crm
SET invalid_reason = null,
    valid_end_date = to_date('20991231','yyyymmdd'),
    valid_start_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason = 'D' -- activate only deprecated mappings

AND EXISTS (SELECT 1 -- activate mapping if the same exists in the current manual file
                 FROM dmd_mapped crm_new
                 WHERE crm_new.source_code = crm.concept_code_1 --the same source_code is mapped
                     AND crm_new.target_concept_code = crm.concept_code_2 --to the same concept_code
                     AND crm_new.target_vocabulary_id = crm.vocabulary_id_2 --of the same vocabulary
                     AND crm_new.to_value = crm.relationship_id --with the same relationship
                 AND (crm_new.cr_invalid_reason = '' OR crm_new.cr_invalid_reason IS NULL)
     )
;
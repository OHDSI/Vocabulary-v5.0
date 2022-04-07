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

--2. Create NDC_manual_mapped table and pre-populate it with the resulting manual table of the previous NDC refresh
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

--4. Truncate the NDC_manual_mapped table. Save the spreadsheet as the NDC_manual_mapped table and upload it into the working schema.
TRUNCATE TABLE dev_ndc.NDC_manual_mapped;

--5. Perform mapping (NDC_manual_mapped) checks

--6. Deprecate all mappings that differ from the new version of resulting mapping file.

-- Perform UPDATE after review SELECT result
UPDATE dev_ndc.concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = current_date
WHERE (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, coalesce(invalid_reason, '1')) in

--SELECT (try-out for the following UPDATE)
      (SELECT concept_code_1,
              concept_code_2,
              vocabulary_id_1,
              vocabulary_id_2,
              relationship_id,
              valid_start_date,
              valid_end_date,
              coalesce(crm.invalid_reason, '1')
       FROM dev_ndc.concept_relationship_manual crm
       WHERE crm.vocabulary_id_1 = 'NDC'
           AND crm.invalid_reason IS NULL
           AND crm.concept_code_1 IN (SELECT source_code FROM dev_ndc.NDC_manual_mapped WHERE source_code IS NOT NULL)
           AND NOT EXISTS (SELECT 1
                           FROM dev_ndc.NDC_manual_mapped m
                           JOIN dev_ndc.concept c
                               ON  m.target_concept_id = c.concept_id
                               WHERE crm.concept_code_1 = m.source_code
                               AND crm.concept_code_2 = c.concept_code
                               AND crm.vocabulary_id_2 = c.vocabulary_id
                            )
)
;

--7. Insert new and corrected mappings into the concept_relationship_manual table.
--mapping insertion
with tab as (
    SELECT DISTINCT s.*
    FROM dev_ndc.NDC_manual_mapped s
)
INSERT INTO dev_ndc.concept_relationship_manual
      (concept_code_1,
      concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
      invalid_reason)

SELECT DISTINCT m.source_code as concept_code_1,
                c.concept_code as concept_code_2,
                cc.vocabulary_id as vocabulary_id_1,
                c.vocabulary_id as vocabulary_id_2,
                'Maps to' as relationship_id,
                current_date as valid_start_date,
                TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
                NULL as invalid_reason
FROM tab m

LEFT JOIN devv5.concept c
    ON m.target_concept_id = c.concept_id

LEFT JOIN devv5.concept cc
    ON m.source_code = cc.concept_code AND cc.vocabulary_id = 'NDC'

WHERE m.target_concept_id NOT IN (0, 17) AND m.target_concept_id IS NOT NULL AND c.concept_id IS NOT NULL AND cc.concept_code IS NOT NULL

AND (

    (NOT EXISTS (SELECT 1
                FROM devv5.concept_relationship cr
                WHERE cr.concept_id_1 = m.source_concept_id
                    AND cr.relationship_id = 'Maps to'
                    AND cr.invalid_reason IS NULL)
        )

    OR
          (m.source_code, cc.vocabulary_id) IN (SELECT concept_code_1, vocabulary_id_1 FROM dev_ndc.concept_relationship_manual)
        )

AND     (NOT EXISTS (SELECT 1
                FROM dev_ndc.concept_relationship_manual crm
                WHERE m.source_code = crm.concept_code_1
                    AND cc.vocabulary_id = crm.vocabulary_id_1
                    AND c.concept_code = crm.concept_code_2
                    AND c.vocabulary_id = crm.vocabulary_id_2
                    AND crm.relationship_id = 'Maps to'
                    AND crm.invalid_reason IS NULL
                    )
    )

ORDER BY 1,2,3,4,5,6,7,8
;





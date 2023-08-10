--22.3.1. Create loinc_mapped table and pre-populate it with the resulting manual table of the previous LOINC refresh.
--DROP TABLE dev_loinc.loinc_mapped;
CREATE TABLE dev_loinc.loinc_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(50),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    to_value varchar(50),
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

--22.3.2. Select concepts to map (flag shows different reasons for mapping refresh) and add them to the manual file in the spreadsheet editor.
with previous_mappings AS
    (SELECT concept_id_1, c.standard_concept, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS old_maps_to
        FROM devv5.concept_relationship cr
        JOIN devv5.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'LOINC'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1, standard_concept
        ),

     current_mapping AS
         (
        SELECT concept_id_1, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS new_maps_to
        FROM dev_loinc.concept_relationship cr
        JOIN dev_loinc.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'LOINC'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1
         )

SELECT DISTINCT
                replace (c.concept_name, 'Deprecated ', '') AS source_concept_name_clean,
                c.concept_name AS       source_concept_name,
                c.concept_code AS       source_concept_code,
                c.concept_class_id AS   source_concept_class_id,
                c.invalid_reason AS     source_invalid_reason,
                c.domain_id AS          source_domain_id,

                NULL::varchar AS relationship_id,

                CASE WHEN previous_mappings.concept_id_1 IS NOT NULL --mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_loinc.concept_relationship lcr
                          JOIN dev_loinc.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'LOINC'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --concept_id never changes
                              )
                          AND previous_mappings.standard_concept = 'S'
                    THEN 'Was Standard and don''t have mapping now'

                    WHEN previous_mappings.concept_id_1 IS NOT NULL --mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_loinc.concept_relationship lcr
                          JOIN dev_loinc.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'LOINC'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --concept_id never changes
                              )
                          AND previous_mappings.standard_concept != 'S'
                    THEN 'Was non-Standard but mapped and don''t have mapping now'

                WHEN previous_mappings.concept_id_1 IN
                    (SELECT cc.concept_id FROM dev_loinc.concept_relationship_manual crm
                    JOIN devv5.concept c
                    ON crm.concept_code_2 = c.concept_code AND crm.vocabulary_id_2 = c.vocabulary_id
                    JOIN devv5.concept cc
                    ON cc.concept_code = crm.concept_code_1 AND cc.vocabulary_id = 'LOINC'
                    WHERE c.standard_concept IS NULL) THEN 'Mapping changed according to changes in other vocabs'

                --mapping changed
                WHEN previous_mappings.old_maps_to != current_mapping.new_maps_to THEN 'Mapping changed'

                WHEN c.concept_code NOT IN (SELECT concept_code FROM devv5.concept WHERE vocabulary_id = 'LOINC')
                                THEN 'New and not-mapped'
                                ELSE 'Not mapped' END AS flag,
                NULL::int AS target_concept_id,
                NULL::varchar AS target_concept_code,
                NULL::varchar AS target_concept_name,
                NULL::varchar AS target_concept_class_id,
                NULL::varchar AS target_standard_concept,
                NULL::varchar AS target_invalid_reason,
                NULL::varchar AS target_domain_id,
                NULL::varchar AS target_vocabulary_id

FROM dev_loinc.concept c
         LEFT JOIN previous_mappings
                   ON c.concept_id = previous_mappings.concept_id_1
         LEFT JOIN current_mapping
                   ON c.concept_id = current_mapping.concept_id_1
    --new concept_relationship
         LEFT JOIN dev_loinc.concept_relationship cr
                   ON c.concept_id = cr.concept_id_1
                       AND cr.relationship_id IN ('Maps to', 'Maps to value')
                       AND cr.invalid_reason IS NULL

WHERE c.concept_code NOT IN (SELECT source_code FROM loinc_mapped) --exclude codes that are already in the loinc_mapped table
    AND cr.concept_id_2 IS NULL --there's no valid mapping after vocabulary dry run
    AND (c.standard_concept IS NULL)
    AND c.vocabulary_id = 'LOINC'
    AND c.concept_class_id IN ('Lab Test' --options for specific concept classes refreshes --TODO: postponed for now
      --,'Survey'
      --,'Answer'
      --,'Clinical Observation'
      )

ORDER BY replace(c.concept_name, 'Deprecated ', ''), c.concept_code
;

--22.3.3. Select COVID concepts lacking hierarchy and add them to the manual file in the spreadsheet editor (these concepts need 'Is a' relationships).
SELECT * FROM (
SELECT DISTINCT
       replace (long_common_name, 'Deprecated ', '') AS source_concept_name_clean,
       long_common_name AS source_concept_name,
	   loinc AS source_concept_code,
	   'Lab Test' AS source_concept_class_id,
	   NULL as source_invalid_reason,
	'Measurement' AS source_domain_id
FROM vocabulary_pack.GetLoincPrerelease() s

UNION

SELECT DISTINCT
        replace (cs.concept_name, 'Deprecated ', '') AS source_concept_name_clean,
        cs.concept_name AS       source_concept_name,
        cs.concept_code AS       source_concept_code,
        cs.concept_class_id AS   source_concept_class_id,
        cs.invalid_reason AS     source_invalid_reason,
        cs.domain_id AS          source_domain_id

FROM dev_loinc.concept_stage cs
WHERE cs.vocabulary_id = 'LOINC'
    AND cs.concept_name ~* 'SARS-CoV-2|COVID|SARS2|SARS-2'
    AND cs.concept_class_id IN ('Clinical Observation', 'Lab Test')
) as s


WHERE NOT EXISTS (
SELECT
FROM dev_loinc.concept_relationship_manual crm
WHERE s.source_concept_code = crm.concept_code_1
    AND crm.relationship_id = 'Is a'
    AND crm.invalid_reason IS NULL
)
AND NOT EXISTS (SELECT
                FROM dev_loinc.loinc_mapped lm
                WHERE s.source_concept_code = lm.source_code
                AND lm.to_value = 'Is a'
                AND target_concept_id = '0')

ORDER BY replace (s.source_concept_name, 'Deprecated ', ''), s.source_concept_code
;

--22.3.4. Truncate the loinc_mapped table. Save the spreadsheet as the loinc_mapped table and upload it into the working schema.
TRUNCATE TABLE dev_loinc.loinc_mapped;

--22.3.5. Deprecate all mappings that differ from the new version of resulting mapping file.
UPDATE dev_loinc.concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = current_date
WHERE (concept_code_1, concept_code_2, relationship_id, vocabulary_id_2) IN
      (SELECT concept_code_1, concept_code_2, relationship_id, vocabulary_id_2
       FROM concept_relationship_manual crm_old

       WHERE NOT exists(SELECT source_code,
                               target_concept_code,
                               'LOINC',
                               target_vocabulary_id,
                               CASE
                                   WHEN to_value ~* 'value' THEN 'Maps to value'
                                   WHEN to_value ~* 'Is a' THEN 'Is a'
                                   WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                                   ELSE 'Maps to' END
                        FROM dev_loinc.loinc_mapped crm_new
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

--22.3.6. Insert new and corrected mappings into the concept_relationship_manual table.
with mapping AS
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'LOINC' AS vocabulary_id_1,
               target_vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM dev_loinc.loinc_mapped
        WHERE target_concept_id != 0
    )

INSERT INTO dev_loinc.concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
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
                  NOT IN (SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM dev_loinc.concept_relationship_manual)
    )
;

-- 22.3.7 Activate mapping, that became valid again
UPDATE concept_relationship_manual crm
SET invalid_reason = null,
    valid_end_date = to_date('20991231','yyyymmdd'),
    valid_start_date =current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason = 'D' -- activate only deprecated mappings
AND EXISTS(SELECT 1 -- activate mapping if the same exists in the current manual file
           FROM dev_loinc.loinc_mapped crm_new
           WHERE crm_new.source_code = crm.concept_code_1           --the same source_code is mapped
             AND crm_new.target_concept_code = crm.concept_code_2   --to the same concept_code
             AND crm_new.target_vocabulary_id = crm.vocabulary_id_2 --of the same vocabulary
             AND crm_new.to_value = crm.relationship_id --with the same relationship
            )
;
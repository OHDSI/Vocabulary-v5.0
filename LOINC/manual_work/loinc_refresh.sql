--19.3.1. Create loinc_mapped table and pre-populate it with the resulting manual table of the previous LOINC refresh.
--DROP TABLE dev_loinc.loinc_mapped;
CREATE TABLE dev_loinc.loinc_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(50),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    source_vocabulary_id varchar(50),
    relationship_id varchar(50),
    cr_invalid_reason varchar(1),
    source varchar(255),
    target_concept_id int,
    target_concept_code varchar(50),
    target_concept_name varchar(255),
    target_concept_class_id varchar(50),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(50),
    target_vocabulary_id varchar(50)
);

--Format after uploading
UPDATE dev_loinc.loinc_mapped SET cr_invalid_reason = NULL WHERE cr_invalid_reason = '';
UPDATE dev_loinc.loinc_mapped SET source_invalid_reason = NULL WHERE source_invalid_reason = '';

--Adding constraints for unique records
ALTER TABLE dev_loinc.loinc_mapped ADD CONSTRAINT idx_pk_mapped UNIQUE (source_code,target_concept_code,source_vocabulary_id,target_vocabulary_id,relationship_id);

--19.3.2. Select concepts to map (flag shows different reasons for mapping refresh) and add them to the manual file in the spreadsheet editor.
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
                c.vocabulary_id AS      source_vocabulary_id,

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

--19.3.3. Select COVID concepts lacking hierarchy and add them to the manual file in the spreadsheet editor (these concepts need 'Is a' relationships).
SELECT * FROM (
SELECT DISTINCT
       replace (long_common_name, 'Deprecated ', '') AS source_concept_name_clean,
       long_common_name AS source_concept_name,
	   loinc AS source_concept_code,
	   'Lab Test' AS source_concept_class_id,
	   NULL as source_invalid_reason,
	'Measurement' AS source_domain_id,
	'LOINC' AS source_vocabulary_id
FROM vocabulary_pack.GetLoincPrerelease() s

UNION

SELECT DISTINCT
        replace (cs.concept_name, 'Deprecated ', '') AS source_concept_name_clean,
        cs.concept_name AS       source_concept_name,
        cs.concept_code AS       source_concept_code,
        cs.concept_class_id AS   source_concept_class_id,
        cs.invalid_reason AS     source_invalid_reason,
        cs.domain_id AS          source_domain_id,
        cs.vocabulary_id AS      source_vocabulary_id

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
                AND lm.relationship_id = 'Is a'
                AND target_concept_id = '0')

ORDER BY replace (s.source_concept_name, 'Deprecated ', ''), s.source_concept_code
;

--19.3.4. Truncate the loinc_mapped table. Save the spreadsheet as the loinc_mapped table and upload it into the working schema.
TRUNCATE TABLE dev_loinc.loinc_mapped;

--19.3.5 Perform any mapping checks you have set.

--19.3.6 Iteratively repeat steps 19.3.2-19.3.5 if found any issues.

--19.3.7. Change concept_relationship_manual table according to loinc_mapped table.
--Insert new relationships
--Update existing relationships
INSERT INTO dev_loinc.concept_relationship_manual AS mapped 
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
           m.cr_invalid_reason
	FROM dev_loinc.loinc_mapped m
	--Only related to LOINC vocabulary
	WHERE (source_vocabulary_id = 'LOINC' OR target_vocabulary_id = 'LOINC')
	    AND target_concept_id != 0
	
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


--Correction of valid_start_dates and valid_end_dates for deprecation of existing mappings, existing in base, but not manual tables
UPDATE concept_relationship_manual crm 
SET valid_start_date = cr.valid_start_date,
    valid_end_date = current_date
FROM loinc_mapped m 
JOIN concept c 
ON c.concept_code = m.source_code AND m.source_vocabulary_id = c.vocabulary_id 
JOIN concept_relationship cr 
ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = m.relationship_id
JOIN concept c1 
ON c1.concept_id = cr.concept_id_2 AND c1.concept_code = m.target_concept_code AND c1.vocabulary_id = m.target_vocabulary_id
WHERE m.cr_invalid_reason IS NOT NULL
AND crm.concept_code_1 = m.source_code AND crm.vocabulary_id_1 = m.source_vocabulary_id
AND crm.concept_code_2 = m.target_concept_code AND crm.vocabulary_id_2 = m.target_vocabulary_id
AND crm.relationship_id = m.relationship_id
AND crm.invalid_reason IS NOT NULL
;

--19.3.8. Change concept_manual if needed
SELECT *
FROM concept_manual
WHERE vocabulary_id = 'LOINC';
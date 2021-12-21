--03. Mapping result table creation and checks (USE the same DDL for both "_manual" and "_mapped" tables)

--aliases to be replaced:
--manual/mapped (depending on what table you're working on, use one of the names: "_mapped" or "_manual")
--voc_schema (schema containing OMOP vocabularies used)
-- currently dev_meddra.meddra_mapped

--!!!Before uploading the csv, run (open as a file) the following bat script inside the folder with csv (all the files in the folder will be processed):
--https://bitbucket.org/Odysseus/custom_mapping/src/master/scripts/add_sort_to_all_csv_in_folder.bat

--check if everything uploaded correctly and count of uploaded rows
--* We expect this check to return every single row. Please, use sorting within different fields to check extremum of each field
SELECT *
FROM dev_meddra.meddra_mapped;

--check semantics of target concepts (vocabs, domains, classes using sorting)
--* We expect this check to return every single row. Please, use sorting within different fields to check extremum of each field
SELECT *
FROM dev_meddra.meddra_mapped
ORDER BY target_domain_id, target_vocabulary_id, target_concept_class_id, target_concept_code, target_concept_name,
         target_concept_id;


--check if any source code/description are lost
--* We expect this check to return nothing. Return source_code + source_code_description pairs are lost. Consider accidental loosing or modification of the pairs
SELECT *
FROM dev_meddra.meddra_mapped s
WHERE NOT EXISTS(SELECT 1
                 FROM dev_meddra.meddra_mapped m
                 WHERE s.source_code = m.source_code
                   AND s.source_code_description = m.source_code_description
    );


--check for codes that can be lost when creating common environment
--fill _after_review table with old mapping from google doc
--if everything is right you'll see right sorting of id and refresh codes at the bottom
select r.id, r.source_code, s.source_code,
        s.counts
from dev_meddra.meddra_environment_source  s
left join  dev_meddra.meddra_mapped r on
r.source_code = s.source_code
order by r.id asc  nulls last, r.source_code asc;


--check if any source code/description are modified
--when working with custom mapping
--* We expect this check to return nothing. Return source_code + source_code_description pairs are modified in mapped file
SELECT *
FROM dev_meddra.meddra_mapped m
WHERE NOT EXISTS(SELECT 1
                 FROM dev_meddra.meddra_environment_source s
                 WHERE lower(s.source_code_description) = lower (m.source_code_description)
                   AND s.source_code = m.source_code --don't use source_code if there are no code in table
    );

--to-many mapping with mapping to 0 or NULL
----* We expect this check to return nothing. Returned codes have mapping to 0 + normal mapping
WITH descr AS (
    SELECT source_code, --choose sc or scd
           -- source_code_description,
           count(*) AS to_many
    FROM dev_meddra.meddra_mapped
    GROUP BY  source_code
           -- source_code_description
    HAVING count(*) > 1
)

SELECT
case when target_concept_id is NULL then 'CHECK DEVICE MAPPING'
    WHEN target_concept_id = 0 then 'CHECK TO MANY + 0'
    else  null  end as error_comment , *
FROM descr
LEFT JOIN dev_meddra.meddra_mapped b
    USING (source_code --choose sc or scd
           -- source_code_description
           )
WHERE target_concept_id IS NULL
    OR target_concept_id = 0
;


--Check if everything above the threshold is mapped
--Threshold: 0
--* We expect this check to return nothing. Returned codes are not mapped and have greater counts than previously agreed threshold. Note that we exclude mapping to 0
SELECT s.source_code, s.source_code_description, s.counts, m.target_concept_id
FROM dev_meddra.meddra_environment_source s
         LEFT JOIN dev_meddra.meddra_mapped m
                   ON m.source_code = s.source_code
WHERE s.counts >= 0 --add threshold here
  AND (m.target_concept_id IS NULL
    OR m.target_concept_id = 0)
;


--check if target concepts are Standard and exist in the concept table
--* We expect this check to return nothing. Returned rows have differences with concept table of the selected vocabulary version.
--* Consider Non-standard mapping/change in concept: name, domain, concept_class, invalid_reason
SELECT *
FROM dev_meddra.meddra_mapped j1
WHERE NOT EXISTS(SELECT *
                 FROM dev_meddra.meddra_mapped j2
                          JOIN dev_meddra.concept c
                               ON j2.target_concept_id = c.concept_id
                                   AND c.concept_code = j2.target_concept_code
                                   --AND replace(lower(c.concept_name), ' ', '') = replace(lower(j2.target_concept_name), ' ', '')
                                   AND c.vocabulary_id = j2.target_vocabulary_id
                                   AND c.domain_id = j2.target_domain_id
                                   AND c.standard_concept = 'S'
                                   AND c.invalid_reason is NULL
                 WHERE j1.id = j2.id
    )
 AND target_concept_id != 0;

--'Maps to' mapping to abnormal domains/classes
--* We expect this check to return nothing. Returned rows have domains/classes that are for specific cases. Exclude allowed concepts before running this check
--* Consider excluding certain vocabularies from this check if mapping to abnormal domains/classes is expected
with tab as (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
    WHERE target_concept_id != 0
)

SELECT *
FROM tab
WHERE source_code in (
    SELECT source_code
    FROM tab a
    WHERE EXISTS(SELECT 1
                 FROM tab b
                 WHERE a.source_code = b.source_code
                   AND b.target_domain_id not in ('Observation', 'Procedure', 'Condition', 'Drug', 'Measurement')--, 'Device') --add Device if needed
                   AND b.target_concept_id NOT IN (-987654321)                                                   --exclude some allowed concepts
                   AND (b.to_value !~* 'value' OR length(b.to_value) = 0 OR b.to_value IS NULL) --just exclude this line from script if 'to_value' field is not used
        )
       OR EXISTS(SELECT 1
                 FROM tab bb
                 WHERE a.source_code = bb.source_code
                   AND bb.target_concept_class_id IN ('Organism', 'Attribute', 'Answer', 'Qualifier Value')
                   AND bb.target_concept_id NOT IN (-987654321) --exclude some allowed concepts
                   AND (bb.to_value !~* 'value' OR length(bb.to_value) = 0 OR
                        bb.to_value IS NULL) --just exclude this line from script if 'to_value' field is not used
        )
)
ORDER BY source_code_description
;


--check value ambiguous mapping (2 Observation/Measurement for 1 value)
--* We expect this check to return nothing. 1 to_value in mapping simultaneously with 2 Observation/Measurement concepts result in assigning value for both of them. Consider remapping
with tab as (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)

SELECT *
FROM tab t
         LEFT JOIN dev_meddra.concept c
                   ON t.target_concept_id = c.concept_id

WHERE source_code in (
    SELECT source_code
    FROM tab a
    WHERE EXISTS(SELECT 1
                 FROM tab b
                 WHERE a.source_code = b.source_code
                   AND b.target_domain_id in ('Observation', 'Measurement')
                   AND (b.to_value !~* 'value' OR length(b.to_value) = 0 OR b.to_value IS NULL)
                 GROUP BY b.source_code
                 HAVING count(*) > 1
        )

      AND EXISTS(SELECT 1
                 FROM tab bb
                 WHERE a.source_code = bb.source_code
                   AND bb.to_value ~* 'value'
        )
)
ORDER BY source_code
;


--check value ambiguous mapping (2 values for 1 Observation/Measurement)
--* We expect this check to return nothing. 2 to_value in mapping with 1 Observation/Measurement concepts result in creating 2 records with same Observation/Measurement and value. Consider remapping.
--* Less strict than 2 Observation/Measurement for 1 value check
with tab as (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)

SELECT *
FROM tab
WHERE source_code in (
    SELECT source_code
    FROM tab a
    WHERE EXISTS(SELECT 1
                 FROM tab b
                 WHERE a.source_code = b.source_code
                   AND b.target_domain_id in ('Observation', 'Measurement')
                   AND (b.to_value !~* 'value' OR length(b.to_value) = 0 OR b.to_value IS NULL)
        )

      AND EXISTS(SELECT 1
                 FROM tab bb
                 WHERE a.source_code = bb.source_code
                   AND bb.to_value ~* 'value'
                 GROUP BY bb.source_code
                 HAVING count(*) > 1
        )
)
ORDER BY source_code
;


--check value without corresponded Observation/Measurement
--* We expect this check to return nothing. Returned rows lack Observation/Measurement for to_value mapping
with tab as (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)

SELECT *
FROM tab
WHERE source_code in (
    SELECT source_code
    FROM tab a
    WHERE NOT EXISTS(SELECT 1
                     FROM tab b
                     WHERE a.source_code = b.source_code
                       AND b.target_domain_id in ('Observation', 'Measurement')
                       AND (b.to_value !~* 'value' OR length(b.to_value) = 0 OR length(b.to_value) IS NULL)
        )

      AND EXISTS(SELECT 1
                 FROM tab bb
                 WHERE a.source_code = bb.source_code
                   AND bb.to_value ~* 'value'
        )
)
;


--Check 'History of' concepts without to value
--EXCLUDE target_concept_id THAT NOT NEEDED
--* We expect this check to return nothing. History concepts should be used only with values. History concepts themselves are useless
with tab as (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)

SELECT *
FROM tab
WHERE source_code in (
    SELECT source_code
    FROM tab a
    WHERE EXISTS(SELECT 1
                 FROM tab b
                 WHERE a.source_code = b.source_code
                   AND b.target_concept_id IN (4215685 --Past history of procedure
                     , 4214956 --History of clinical finding in subject
                     , 4195979 --H/O: Disorder
                     , 4210989 --Family history with explicit context
                     , 4167217 --Family history of clinical finding
                     , 4175586 --Family history of procedure
                     , 4236282 --Family history unknown
                     , 4051104 --No family history of
                     , 4219847 --Disease suspected
                     , 4199812 --Disorder excluded
                     , 40481925 --No history of clinical finding in subject
                     , 4022772 --Condition severity
                     )
        )

      AND NOT EXISTS(SELECT 1
                     FROM tab c
                     WHERE a.source_code = c.source_code
                       AND c.to_value ~* 'value')
)
;


-- Check maps_to/maps_to_value vocabularies consistency
--* We expect this check to return nothing. Event concept and to_value concept should should have one vocabulary_id.
with tab as (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)

SELECT *
FROM tab
WHERE source_code in (
    SELECT source_code
    FROM tab a
    WHERE EXISTS(SELECT 1
                 FROM tab b
                 WHERE a.source_code = b.source_code
                   AND a.target_vocabulary_id != b.target_vocabulary_id
        )

      AND EXISTS(SELECT 1
                 FROM tab c
                 WHERE a.source_code = c.source_code
                   AND c.to_value ~* 'value'
        )
)
ORDER BY source_code, to_value -- add/replace source_code to source_code_description if needed
;


--1-to-many mapping
--* We expect this check to return all one to many mappings (incl. to_value, to_unit, etc.) for manual review. NB: Some vocabularies can't have one to many (Unit, Provider, etc.)a
with tab as (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)

SELECT *
FROM tab
WHERE source_code in (
    SELECT source_code
    FROM tab
    GROUP BY source_code
    HAVING count(*) > 1)
ORDER BY source_code
;


--1 maps_to mapping and 1 maps_to_value/unit/modifier/qualifier mapping
--* We expect this check to return Maps to and maps to value, modifier, qualifier - not 'real' one to many mapping
WITH tab AS (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)

SELECT *
FROM tab t
WHERE source_code in (
    SELECT source_code
    FROM tab
    GROUP BY source_code
    HAVING count(*) = 2
)
  AND EXISTS(SELECT 1
             FROM tab b
             WHERE t.source_code = b.source_code
               AND b.to_value ~* 'value|modifier|qualifier|unit')
ORDER BY source_code, to_value
;


--all other 1-to-many mappings
--* We expect this check to return 'real' one to many mapping
with tab as (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)

SELECT *
FROM tab
WHERE source_code IN (
    SELECT source_code
    FROM tab
    GROUP BY source_code
    HAVING count(*) > 1)

  AND source_code NOT IN (
    SELECT source_code
    FROM tab t
    WHERE source_code in (
        SELECT source_code
        FROM tab
        GROUP BY source_code
        HAVING count(*) = 2
    )
      AND EXISTS(SELECT 1
                 FROM tab b
                 WHERE t.source_code = b.source_code
                   AND b.to_value ~* 'value|modifier|qualifier|unit')
)
ORDER BY source_code, to_value
;


--check key terms lose
--* We expect this check to return nothing. First you choose key terms and then check if targets have them.
WITH tab AS (
    SELECT DISTINCT s.*
    FROM dev_meddra.meddra_mapped s
)
SELECT *
FROM tab a
WHERE source_code ~* 'acute|chronic|recurrent'                             --choose key terms
  AND NOT EXISTS(SELECT 1
                 FROM tab b
                 WHERE a.source_code = b.source_code
                   AND b.target_concept_name ~* 'acute|chronic|recurrent') --choose same key terms
  --AND target_concept_id != 0 --add if needed
ORDER BY source_code;


--detect duplicates record located far away from each other in the csv file
--Option A (Oleg's)
--* We expect this check to return nothing. Returned rows have identical source_code, but they are located away from each other in manual file. Consider review and reformatting
WITH ordered_source AS (
    SELECT s.*
    FROM dev_meddra.meddra_mapped s
    ORDER BY s.id
),

     numbered_source AS (
         SELECT s.*, row_number() OVER () AS row_num
         FROM ordered_source s
     ),

     source_code_counts AS (
         SELECT source_code,
                count(source_code) AS counts
         FROM numbered_source
         GROUP BY source_code
     ),

     result AS (
         SELECT ns1.source_code,
                (max(ns2.row_num))                                                                    AS init_sum,
                (min(ns2.row_num) + scc.counts - 1)                                                   AS second_sum,
                CASE WHEN (max(ns2.row_num)) != (min(ns2.row_num) + scc.counts - 1) THEN 1 ELSE 0 END AS flag

         FROM numbered_source ns1

                  JOIN numbered_source ns2
                       ON ns1.source_code = ns2.source_code

                  JOIN source_code_counts scc
                       ON ns1.source_code = scc.source_code

         GROUP BY ns1.source_code, scc.counts
     )

SELECT source_code
FROM result
WHERE flag = 1
;

--detect duplicates record located far away from each other in the csv file
--Option B (Artem's)
--* We expect this check to return nothing. Returned rows have identical source_code, but they are located away from each other in manual file. Consider review and reformatting
WITH tab AS (
    WITH tb AS (
        WITH t AS (
            WITH t0 AS (
                SELECT source_code, source_code_description, target_concept_id
                FROM dev_meddra.meddra_mapped
                ORDER BY id
            )
            SELECT source_code, source_code_description, target_concept_id, ROW_NUMBER() OVER () AS r_num
            FROM t0
        )
        SELECT *, ROW_number() OVER (PARTITION BY source_code ORDER BY r_num) AS group_row
        FROM t
    )
    SELECT *,
           max(r_num) OVER (PARTITION BY source_code)     AS max_row,
           min(r_num) OVER (PARTITION BY source_code)     AS min_row,
           max(group_row) OVER (PARTITION BY source_code) AS max_in_group,
           min(group_row) OVER (PARTITION BY source_code) AS min_in_group
    FROM tb t
)

SELECT DISTINCT source_code
FROM tab
WHERE max_in_group - min_in_group <> max_row - min_row
  AND source_code IS NOT NULL
;

--codes count
SELECT DISTINCT source_code
FROM dev_meddra.meddra_mapped;

--codes count diff
--* We expect this check to return nothing. Returned rows' source_code have been changed.
SELECT DISTINCT source_code
FROM dev_meddra.meddra_mapped
    EXCEPT

SELECT DISTINCT source_code
FROM dev_meddra.meddra_mapped
;


--Problem vocabs: stats
--* We expect this check to return stats on used vocabularies. You are not allowed to use License required vocabularies and Never used vocabularies
--* Availability of EULA required vocabularies should be checked with client
--* Not commonly used vocabularies should be double checked
SELECT target_vocabulary_id, error_code, count(1) AS affected_concepts
FROM (
         SELECT c.vocabulary_id                            AS target_vocabulary_id,
                c.concept_id,
                CASE
                    WHEN c.vocabulary_id IN ('ATC', 'CIEL', 'Currency', 'DPD', 'GGR', 'MeSH', 'GCN_SEQNO', 'ICD9CM',
                                             'KCD7', 'MEDRT', 'Multum', 'NDFRT', 'OSM', 'Read', 'Revenue Code', 'OXMIS',
                                             'SMQ', 'PCORNet',
                                             'SPL', 'UB04 Point of Origin', 'UB04 Pt dis status', 'US Census',
                                             'VA Class', 'VA Product', 'UB04 Pri Typ of Adm',
                                             'ICD10', 'ICD10CM', 'Cohort', 'EphMRA ATC', 'NFC', 'CDM', 'Metadata',
                                             'Relationship', 'Vocabulary',
                                             'Death Type', 'Cost Type', 'Obs Period Type', 'Meas Type', 'Visit Type',
                                             'Specimen Type', 'Condition Type', 'Drug Type',
                                             'Episode Type', 'Procedure Type', 'Note Type', 'Observation Type',
                                             'Device Type', 'Concept Class', 'Domain') THEN 'Never used'

                    WHEN c.vocabulary_id IN
                         ('HemOnc', 'NAACCR', 'OPCS4', 'PPI', 'HCPCS', 'ICD10PCS', 'ICD9Proc', 'dm+d', 'APC',
                          'SNOMED Veterinary', 'DRG', 'JMDC', 'NDC', 'AMT', 'MMI', 'BDPM', 'MDC')
                        THEN 'Not commonly used'

                    WHEN c.vocabulary_id IN
                         ('PHDSC', 'CMS Place of Service', 'Plan', 'Ethnicity', 'Episode', 'ABMS', 'HES Specialty',
                          'Cost', 'Visit', 'UCUM',
                          'Sponsor', 'Plan Stop Reason', 'Medicare Specialty', 'Race', 'Provider', 'Gender', 'NUCC',
                          'Supplier', 'UB04 Typ bill') THEN 'Used ONLY in certain types of mapping'

                    WHEN c.vocabulary_id IN
                         ('CDT', 'DA_France', 'ETC', 'GPI', 'GRR', 'Indication', 'LPD_Australia', 'LPD_Belgium',
                          'SUS', 'Multilex', 'Gemscript', 'ISBT', 'ISBT Attribute', 'KDC') THEN 'License required'

                    WHEN c.vocabulary_id IN ('CPT4', 'MedDRA') THEN 'EULA required'

                    WHEN c.vocabulary_id IN ('None') THEN 'Mapped to 0'

                    WHEN c.vocabulary_id IN ('CCS', 'AMIS', 'EU Product')
                        THEN 'Currently not available' END AS error_code

         FROM dev_meddra.meddra_mapped m
                  JOIN dev_meddra.concept c
                       ON c.concept_id = m.target_concept_id) a
WHERE error_code IS NOT NULL
GROUP BY error_code, target_vocabulary_id
ORDER BY error_code, a.target_vocabulary_id
;

--Problem vocabs: mapping list
--* We expect this check to return stats on used vocabularies. You are not allowed to use License required vocabularies and Never used vocabularies
--* Availability of EULA required vocabularies should be checked with client
--* Not commonly used vocabularies should be double checked
SELECT a.source_code,
       a.source_code_description,
       a.counts,
       a.to_value,
       error_code,
       a.concept_id,
       COALESCE(c2.concept_name, mm.source_code_description) as concept_name,
       COALESCE(c2.concept_code, mm.source_code)             as concept_code,
       COALESCE(c2.concept_class_id, '')                     as concept_class_id,
       COALESCE(c2.domain_id, '')                            as domain_id,
       COALESCE(c2.standard_concept, '')                     as standard_concept,
       COALESCE(c2.invalid_reason, '')                       as invalid_reason,
       COALESCE(c2.vocabulary_id, '')                        as vocabulary_id
FROM (
         SELECT m.source_code,
                source_code_description,
                c.vocabulary_id,
                c.concept_id,
                m.counts,
                m.to_value,
                CASE
                    WHEN c.vocabulary_id IN ('ATC', 'CIEL', 'Currency', 'DPD', 'GGR', 'MeSH', 'GCN_SEQNO', 'ICD9CM',
                                             'KCD7', 'MEDRT', 'Multum', 'NDFRT', 'OSM', 'Read', 'Revenue Code', 'OXMIS',
                                             'SMQ', 'PCORNet',
                                             'SPL', 'UB04 Point of Origin', 'UB04 Pt dis status', 'US Census',
                                             'VA Class', 'VA Product', 'UB04 Pri Typ of Adm',
                                             'ICD10', 'ICD10CM', 'Cohort', 'EphMRA ATC', 'NFC', 'CDM', 'Metadata',
                                             'Relationship', 'Vocabulary',
                                             'Death Type', 'Cost Type', 'Obs Period Type', 'Meas Type', 'Visit Type',
                                             'Specimen Type', 'Condition Type', 'Drug Type',
                                             'Episode Type', 'Procedure Type', 'Note Type', 'Observation Type',
                                             'Device Type', 'Concept Class', 'Domain') THEN 'Never used'

                    WHEN c.vocabulary_id IN
                         ('HemOnc', 'NAACCR', 'OPCS4', 'PPI', 'HCPCS', 'ICD10PCS', 'ICD9Proc', 'dm+d', 'APC',
                          'SNOMED Veterinary', 'DRG', 'JMDC', 'NDC', 'AMT', 'MMI', 'BDPM', 'MDC')
                        THEN 'Not commonly used'

                    WHEN c.vocabulary_id IN
                         ('PHDSC', 'CMS Place of Service', 'Plan', 'Ethnicity', 'Episode', 'ABMS', 'HES Specialty',
                          'Cost', 'Visit', 'UCUM',
                          'Sponsor', 'Plan Stop Reason', 'Medicare Specialty', 'Race', 'Provider', 'Gender', 'NUCC',
                          'Supplier', 'UB04 Typ bill', 'Nebraska Lexicon') THEN 'Used ONLY in certain types of mapping'

                    WHEN c.vocabulary_id IN
                         ('CDT', 'DA_France', 'ETC', 'GPI', 'GRR', 'Indication', 'LPD_Australia', 'LPD_Belgium',
                          'SUS', 'Multilex', 'Gemscript', 'ISBT', 'ISBT Attribute', 'KDC') THEN 'License required'

                    WHEN c.vocabulary_id IN ('CPT4', 'MedDRA') THEN 'EULA required'

                    WHEN c.vocabulary_id IN ('None') THEN 'Mapped to 0'

                    WHEN c.vocabulary_id IN ('CCS', 'AMIS', 'EU Product')
                        THEN 'Currently not available' END AS error_code

         FROM dev_meddra.meddra_mapped m
                  JOIN dev_meddra.concept c
                       ON c.concept_id = m.target_concept_id) a
         LEFT JOIN dev_meddra.concept c2
                   ON a.concept_id = c2.concept_id
         LEFT JOIN dev_meddra.meddra_mapped mm
                   ON a.source_code = mm.source_code
WHERE error_code IS NOT NULL
ORDER BY a.error_code, a.source_code
;



--04. Mapping insertion into the whole_project_table (all_mapping_table_schema.customername_datasetname)
--It's universal now for every approach (stage tables, STCM, concept/CR tables)
--* We expect vocabular team member to run select first, use filters, check every column and then run insert twice (second time should insert nothing)

--aliases to be replaced:
--all_mapping_table_schema (schema containing all mapping tables)
--customername_datasetname (all_project_environment table containing all the mappings for the project)
--datasetname_vocabularyname (a combination normally used as source_vocabulary_id)
--Domain needed (for the source_domain_id)
--Class needed (for the source_concept_class_id)


--delete the records of the specific source_vocabulary_id (if needed)
DELETE
FROM all_mapping_table_schema.customername_datasetname_custom_mapping
WHERE source_vocabulary_id IN ('datasetname_vocabularyname', '');



with parameters as (
    SELECT 'datasetname_vocabularyname' as source_vocabulary_id,
           'Domain needed' as source_domain_id,
           'Class needed' as source_concept_class_id
),

mapping as (
SELECT DISTINCT m.source_code_description as source_code_description, --or use source_code here

                --to be used for non-English datasets
                --CASE WHEN COALESCE (length (m.source_code_description_synonym::varchar), 0) = 0 THEN NULL ELSE m.source_code_description_synonym END as source_code_description_synonym,
                --m.synonym_language_concept_id,

                p.source_vocabulary_id as source_vocabulary_id,
                p.source_domain_id as source_domain_id,
                p.source_concept_class_id as source_concept_class_id,
                CASE WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0 AND COALESCE (length (m.target_concept_code::varchar), 0) = 0
                     THEN 'S'
                     ELSE NULL END as source_standard_concept,
                m.source_code as source_code,
                m.counts,
                '1970-01-01'::date as valid_start_date,
                '2099-12-31'::date as valid_end_date,
                NULL as invalid_reason,
                CASE WHEN c.concept_id IS NOT NULL
                     THEN c.concept_id
                     WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0
                     THEN NULL
                     ELSE -9876543210 END as target_concept_id,
                CASE WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0 AND COALESCE (length (m.target_concept_code::varchar), 0) = 0
                     THEN m.source_code
                     WHEN mm.source_code IS NOT NULL
                     THEN m.source_code
                     ELSE COALESCE(c.concept_code, '!!!Wrong parameter') END as target_concept_code,
                CASE WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0 AND COALESCE (length (m.target_concept_code::varchar), 0) = 0
                     THEN m.source_code_description
                     ELSE COALESCE(c.concept_name, mm.source_code_description, '!!!Wrong parameter') END as target_concept_name,
                CASE WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0 AND COALESCE (length (m.target_concept_code::varchar), 0) = 0
                     THEN p.source_concept_class_id
                     ELSE COALESCE(c.concept_class_id, p.source_concept_class_id, '!!!Wrong parameter') END as target_concept_class_id,
                CASE WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0 AND COALESCE (length (m.target_concept_code::varchar), 0) = 0
                     THEN 'S'
                     WHEN mm.source_code IS NOT NULL
                     THEN 'S'
                     WHEN c.concept_id IS NOT NULL AND c.standard_concept = 'S'
                     THEN c.standard_concept
                     WHEN c.concept_id = 0
                     THEN c.standard_concept
                     ELSE '!!!Wrong parameter' END as target_standard_concept,
                CASE WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0 AND COALESCE (length (m.target_concept_code::varchar), 0) = 0
                     THEN NULL
                     WHEN mm.source_code IS NOT NULL
                     THEN NULL
                     WHEN c.concept_id IS NOT NULL AND c.invalid_reason IS NULL
                     THEN NULL
                     ELSE '!!!Wrong parameter' END as target_invalid_reason,
                CASE WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0 AND COALESCE (length (m.target_concept_code::varchar), 0) = 0
                     THEN p.source_domain_id
                     WHEN mm.source_code IS NOT NULL
                     THEN p.source_domain_id
                     ELSE COALESCE(c.domain_id, '!!!Wrong parameter') END as target_domain_id,
                CASE WHEN COALESCE (length (m.target_concept_id::varchar), 0) = 0 AND COALESCE (length (m.target_concept_code::varchar), 0) = 0
                     THEN p.source_vocabulary_id
                     WHEN mm.source_code IS NOT NULL
                     THEN p.source_vocabulary_id
                     ELSE COALESCE(c.vocabulary_id, '!!!Wrong parameter') END as target_vocabulary_id,
                CASE WHEN m.to_value ~* 'value' THEN 'Maps to value'
                     WHEN m.to_value ~* 'unit' THEN 'Maps to unit'
                     WHEN m.to_value ~* 'qualifier' THEN 'Maps to qualifier'
                     WHEN m.to_value ~* 'modifier' THEN 'Maps to modifier'
                     WHEN m.to_value ~* 'status' THEN 'Maps to status'
                     WHEN COALESCE (length (m.to_value::varchar), 0) = 0
                     THEN 'Maps to'
                     ELSE '!!!Wrong parameter' END as relationship_id,
                CASE WHEN m.to_value ~* 'value' THEN 'Value mapped from'
                     WHEN m.to_value ~* 'unit' THEN 'Unit mapped from'
                     WHEN m.to_value ~* 'qualifier' THEN 'Qualifier mapped from'
                     WHEN m.to_value ~* 'modifier' THEN 'Modifier mapped from'
                     WHEN m.to_value ~* 'status' THEN 'Status mapped from'
                     WHEN COALESCE (length (m.to_value::varchar), 0) = 0
                     THEN 'Mapped from'
                     ELSE '!!!Wrong parameter' END as reverse_relationship_id,
                '1970-01-01'::date as valid_start_date_CR,
                '2099-12-31'::date as valid_end_date_CR,
                NULL as invalid_reason_CR
FROM working_schema.customername_datasetname_vocabularyname_mapped m
LEFT JOIN parameters p
    ON TRUE
LEFT JOIN voc_schema.concept c
    ON m.target_concept_id = c.concept_id
LEFT JOIN working_schema.customername_datasetname_vocabularyname_mapped mm
    ON m.target_concept_code = mm.source_code
        AND m.target_vocabulary_id = p.source_vocabulary_id

)

--activate this part to make an actual insertion, BUT test with SELECT before that
/*INSERT INTO all_mapping_table_schema.customername_datasetname_custom_mapping
(source_code_description,
--source_code_description_synonym,
--synonym_language_concept_id,
source_vocabulary_id,
source_domain_id,
source_concept_class_id,
source_standard_concept,
source_code,
counts,
valid_start_date,
valid_end_date,
invalid_reason,
target_concept_id,
target_concept_code,
target_concept_name,
target_concept_class_id,
target_standard_concept,
target_invalid_reason,
target_domain_id,
target_vocabulary_id,
relationship_id,
reverse_relationship_id,
valid_start_date_CR,
valid_end_date_CR,
invalid_reason_CR
)*/


SELECT * FROM mapping

WHERE (
        COALESCE (source_code_description, 'x!x'),
        --COALESCE (source_code_description_synonym, 'x!x'),
       --COALESCE (synonym_language_concept_id, -9876543210),
        COALESCE (source_vocabulary_id, 'x!x'),
        COALESCE (source_domain_id, 'x!x'),
        COALESCE (source_concept_class_id, 'x!x'),
        COALESCE (source_standard_concept, 'x!x'),
        COALESCE (source_code, 'x!x'),
        COALESCE (counts, -9876543210),
        COALESCE (valid_start_date, '2200-01-01'),
        COALESCE (valid_end_date, '2200-01-01'),
        COALESCE (invalid_reason, 'x!x'),
        COALESCE (target_concept_id, -9876543210),
        COALESCE (target_concept_code, 'x!x'),
        COALESCE (target_vocabulary_id, 'x!x'),
        COALESCE (relationship_id, 'x!x'),
        COALESCE (reverse_relationship_id, 'x!x'),
        COALESCE (valid_start_date_CR, '2200-01-01'),
        COALESCE (valid_end_date_CR, '2200-01-01'),
        COALESCE (invalid_reason_CR, 'x!x')
)

    NOT IN (
        SELECT
               COALESCE (source_code_description, 'x!x'),
               --COALESCE (source_code_description_synonym, 'x!x'),
                 --COALESCE (synonym_language_concept_id, -9876543210),
               COALESCE (source_vocabulary_id, 'x!x'),
               COALESCE (source_domain_id, 'x!x'),
               COALESCE (source_concept_class_id, 'x!x'),
               COALESCE (source_standard_concept, 'x!x'),
               COALESCE (source_code, 'x!x'),
               COALESCE (counts, -9876543210),
               COALESCE (valid_start_date, '2200-01-01'),
               COALESCE (valid_end_date, '2200-01-01'),
               COALESCE (invalid_reason, 'x!x'),
               COALESCE (target_concept_id, -9876543210),
               COALESCE (target_concept_code, 'x!x'),
               COALESCE (target_vocabulary_id, 'x!x'),
               COALESCE (relationship_id, 'x!x'),
               COALESCE (reverse_relationship_id, 'x!x'),
               COALESCE (valid_start_date_CR, '2200-01-01'),
               COALESCE (valid_end_date_CR, '2200-01-01'),
               COALESCE (invalid_reason_CR, 'x!x')

        FROM all_mapping_table_schema.customername_datasetname_custom_mapping)

ORDER BY source_code, source_vocabulary_id, relationship_id, target_concept_id
;

--update mapping with standart mapping + non-standart
UPDATE all_mapping_table_schema.customername_datasetname_custom_mapping m
SET source_standard_concept = 'S'

WHERE EXISTS(
              SELECT m1.source_code, m1.source_vocabulary_id
              FROM all_mapping_table_schema.customername_datasetname_custom_mapping m1
              WHERE m1.source_standard_concept = 'S'
                AND m.source_code = m1.source_code
                AND m.source_vocabulary_id = m1.source_vocabulary_id)
and m.source_vocabulary_id = 'datasetname_vocabularyname';

--Check whether the wrong parameters were inserted
--* We expect this check to return nothing. Returned rows have wrong parameters
SELECT *
FROM all_mapping_table_schema.customername_datasetname_custom_mapping
WHERE target_concept_id = -9876543210
   OR target_concept_code = '!!!Wrong parameter'
   OR target_concept_name = '!!!Wrong parameter'
   OR target_concept_class_id = '!!!Wrong parameter'
   OR target_standard_concept = '!!!Wrong parameter'
   OR target_invalid_reason = '!!!Wrong parameter'
   OR target_domain_id = '!!!Wrong parameter'
   OR target_vocabulary_id = '!!!Wrong parameter'
   OR relationship_id = '!!!Wrong parameter'
   OR reverse_relationship_id = '!!!Wrong parameter'
;


--03. Mapping insertion into whole_project_table (all_mapping_table_schema.customername_datasetname)
--03b. When working with concept & concept_relationship (OUTDATED - do NOT use)

--TODO: correct INSERT with COALESCEs
/*with mapping as (
    SELECT DISTINCT m.source_code_description                                                 as concept_name,      --or use source_code here
                    --m.source_code_description_synonym, --to be used for non-English dataset
                    s.source_concept_id                                                       as source_concept_id, --use ONLY when the vocabulary team assigns them
                    'Datasetname'                                                             as source_vocabulary_id,
                    'Domain needed'                                                           as source_domain_id,
                    'Class needed'                                                            as source_concept_class_id,
                    CASE WHEN length(m.target_concept_id::varchar) = 0 THEN 'S' ELSE NULL END as standard_concept,
                    m.source_code                                                             as concept_code,
                    counts,
                    '1970-01-01'::date                                                        as valid_start_date,
                    '2099-12-31'::date                                                        as valid_end_date,
                    NULL                                                                      as invalid_reason,
                    m.target_concept_id                                                       as target_concept_id,
                    m.target_concept_code                                                     as target_concept_code,
                    m.target_vocabulary_id                                                    as target_vocabulary_id,
                    CASE
                        WHEN m.to_value ~* 'value' THEN 'Maps to value'
                        WHEN m.to_value ~* 'unit' THEN 'Maps to unit'
                        WHEN m.to_value ~* 'qualifier' THEN 'Maps to qualifier'
                        WHEN m.to_value ~* 'modifier' THEN 'Maps to modifier'
                        WHEN m.to_value ~* 'status' THEN 'Maps to status'
                        WHEN length(m.to_value) = 0 OR m.to_value IS NULL THEN 'Maps to'
                        ELSE '0' END                                                          as relationship_id,
                    CASE
                        WHEN m.to_value ~* 'value' THEN 'Value mapped from'
                        WHEN m.to_value ~* 'unit' THEN 'Unit mapped from'
                        WHEN m.to_value ~* 'qualifier' THEN 'Qualifier mapped from'
                        WHEN m.to_value ~* 'modifier' THEN 'Modifier mapped from'
                        WHEN m.to_value ~* 'status' THEN 'Status mapped from'
                        WHEN length(m.to_value) = 0 OR m.to_value is NULL THEN 'Mapped from'
                        ELSE '0' END                                                          as reverse_relationship_id,
                    '1970-01-01'::date                                                        as valid_start_date_CR,
                    '2099-12-31'::date                                                        as valid_end_date_CR,
                    NULL                                                                      as invalid_reason_CR

    FROM working_schema.customername_datasetname_vocabularyname_mapped m

             LEFT JOIN working_schema.customername_datasetname_vocabularyname_source s
                       ON m.source_code = s.source_code
)

--activate this part to make an actual insertion, BUT test with SELECT before that
/*INSERT INTO all_mapping_table_schema.customername_datasetname_custom_mapping*/

SELECT *
FROM mapping

WHERE (concept_name,
          --source_code_description_synonym, --to be used for non-English dataset
       source_concept_id, source_vocabulary_id, source_domain_id, source_concept_class_id, standard_concept,
       concept_code, counts, valid_start_date, valid_end_date, invalid_reason, target_concept_id, relationship_id,
       reverse_relationship_id,
       valid_start_date_CR, valid_end_date_CR, invalid_reason_CR)
          NOT IN (SELECT * FROM all_mapping_table_schema.customername_datasetname_custom_mapping)

ORDER BY concept_code, source_vocabulary_id, relationship_id, target_concept_id
;*/


--03. Mapping insertion into whole_project_table (all_mapping_table_schema.customername_datasetname)
--03c. When working with STCM (source_to_concept_map) (OUTDATED - do NOT use)
--TODO: correct INSERT with COALESCEs
/*with mapping as (
    SELECT DISTINCT source_code                                                               as source_code,
                    0                                                                         as source_concept_id,
                    CASE
                        WHEN to_value ~* 'value' THEN 'customername_datasetname_vocabularyname_maps_to_value'
                        WHEN to_value ~* 'unit' THEN 'customername_datasetname_vocabularyname_maps_to_unit'
                        WHEN to_value ~* 'qualifier' THEN 'customername_datasetname_vocabularyname_maps_to_qualifier'
                        WHEN to_value ~* 'modifier' THEN 'customername_datasetname_vocabularyname_maps_to_modifier'
                        WHEN length(to_value) = 0 OR to_value IS NULL
                            THEN 'customername_datasetname_vocabularyname_maps_to'
                        ELSE '0' END                                                          as source_vocabulary_id,
                    source_code_description                                                   as source_code_description, -- or choose source_code here
                    --source_code_description_synonym, --to be used for non-English dataset
                    counts,
                    target_concept_id,
                    target_concept_code,
                    CASE WHEN target_concept_id = 0 THEN 'None' ELSE target_vocabulary_id END as target_vocabulary_id,
                    '1970-01-01'::date                                                        as valid_start_date,
                    '2099-12-31'::date                                                        as valid_end_date,
                    NULL                                                                      as invalid_reason

    FROM working_schema.customername_datasetname_vocabularyname_mapped
)

--activate this part to make an actual insertion, BUT test with SELECT before that
/*INSERT INTO all_mapping_table_schema.customername_datasetname_custom_mapping
(source_code,
 source_concept_id,
 source_vocabulary_id,
 source_code_description,
 counts,
 target_concept_id,
 target_concept_code,
 target_vocabulary_id,
 valid_start_date,
 valid_end_date,
 invalid_reason)*/

SELECT *
FROM mapping
WHERE (source_code,
       source_concept_id,
       source_vocabulary_id,
       source_code_description,
          --COALESCE(source_code_description_synonym, 'x!x'), --to be used for non-English dataset
       COALESCE(counts, -9876543210),
       target_concept_id,
       target_concept_code,
       target_vocabulary_id,
       valid_start_date,
       valid_end_date,
       COALESCE(invalid_reason, 'x!x')
          )
          NOT IN (
          SELECT source_code,
                 source_concept_id,
                 source_vocabulary_id,
                 source_code_description,
                 --COALESCE(source_code_description_synonym, 'x!x'), --to be used for non-English dataset
                 COALESCE(counts, -9876543210),
                 target_concept_id,
                 target_concept_code,
                 target_vocabulary_id,
                 valid_start_date,
                 valid_end_date,
                 COALESCE(invalid_reason, 'x!x')
          FROM all_mapping_table_schema.customername_datasetname_custom_mapping
      )

ORDER BY source_code, source_vocabulary_id, target_concept_id
;*/
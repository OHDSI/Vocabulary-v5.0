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
* Authors: Alexander Davydov, Oleg Zhuk
* Date: 2020
**************************************************************************/

--0. Update a 'latest_update' field to a new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'UK Biobank',
	pVocabularyDate			=> (SELECT max(debut) FROM sources.uk_biobank_field),
	pVocabularyVersion		=> (SELECT 'version ' || max(debut)::varchar FROM sources.uk_biobank_field),
	pVocabularyDevSchema	=> 'dev_ukbiobank'
);
END $_$;

--1. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--2a. Insert categories to concept_stage and create table for all_answers combined
INSERT INTO concept_stage
( concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date)
SELECT DISTINCT
        CASE WHEN category_id = 0 THEN 'UK Biobank Category' ELSE trim(title) END,
        CASE WHEN cat.category_id IN (
            101, --Carotid ultrasound
            104, --ECG at rest, 12-lead
            106, --Task functional brain MRI
            107, --Diffusion brain MRI
            109, --Susceptibility weighted brain MRI
            110, --T1 structural brain MRI
            111, --Resting functional brain MRI
            112, --T2-weighted brain MRI
            124, --Body composition by DXA
            125, --Bone size, mineral and density by DXA
            126, --Liver MRI
            128, --Pulse wave analysis
            133, --Left ventricular size and function
            134, --dMRI skeleton
            135, --dMRI weighted means
            149, --Abdominal composition
            190, --Freesurfer ASEG
            191, --Freesurfer subsegmentation
            192, --Freesurfer desikan white
            193, --Freesurfer desikan pial
            194, --Freesurfer desikan gw
            195, --Freesurfer BA exvivo
            196, --Freesurfer DKT
            197, --Freesurfer a2009s
            265, --Telomeres
            1101, --Regional grey matter volumes (FAST)
            1102, --Subcortical volumes (FIRST)
            1307, --Infectious Disease Antigens
            17518, --Blood biochemistry
            51428, --Infectious Diseases
            100007, --Arterial stiffness
            100009, --Impedance measures
            100010, --Body size measures
            100011, --Blood pressure
            100012, --ECG during exercise
            100014, --Autorefraction
            100015, --Intraocular pressure
            100018, --Bone-densitometry of heel
            100019, --Hand grip strength
            100020, --Spirometry
            100081, --Blood count
            100083, --Urine assays
            100098   --Estimated nutrients yesterday
            )
            THEN 'Measurement' ELSE 'Observation' END AS domain_id,
       'UK Biobank',
       'Category',
       'C',
       CONCAT('c', cat.category_id),
       TO_DATE('19700101','yyyymmdd'),
       TO_DATE('20991231','yyyymmdd')
FROM sources.uk_biobank_category cat
;

--2b. Build category_ancestor
DROP TABLE IF EXISTS category_ancestor;
CREATE UNLOGGED TABLE category_ancestor AS (
	WITH recursive hierarchy_concepts(ancestor_concept_code, descendant_concept_code, root_ancestor_concept_code, full_path) AS (
		SELECT parent_id,
			child_id,
			parent_id AS root_ancestor_concept_code,
			ARRAY [child_id::text] AS full_path
		FROM sources.uk_biobank_catbrowse

		UNION ALL

		SELECT c.ancestor_concept_code,
			c.descendant_concept_code,
			root_ancestor_concept_code,
			hc.full_path || c.descendant_concept_code::TEXT AS full_path
		FROM concepts c
		JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
		WHERE c.descendant_concept_code::TEXT <> ALL (full_path)
		),

	concepts AS (
		SELECT parent_id AS ancestor_concept_code,
			   child_id AS descendant_concept_code
		FROM sources.uk_biobank_catbrowse
		)
	SELECT DISTINCT hc.root_ancestor_concept_code::BIGINT AS ancestor_concept_code, hc.descendant_concept_code::BIGINT
	FROM hierarchy_concepts hc
);

--2c. Make category a Measurement when all the descendant categories are Measurements
UPDATE concept_stage cs
SET domain_id = 'Measurement'
WHERE concept_class_id = 'Category'
    AND EXISTS (SELECT 1
                FROM category_ancestor ca1
                JOIN concept_stage cs1
                    ON concat('c', ca1.descendant_concept_code) = cs1.concept_code
                        AND cs1.concept_class_id = 'Category'
                WHERE concat('c', ca1.ancestor_concept_code) = cs.concept_code
                    AND cs1.domain_id = 'Measurement'
                )
    AND NOT EXISTS (SELECT 1
                FROM category_ancestor ca2
                JOIN concept_stage cs2
                    ON concat('c', ca2.descendant_concept_code) = cs2.concept_code
                        AND cs2.concept_class_id = 'Category'
                WHERE concat('c', ca2.ancestor_concept_code) = cs.concept_code
                    AND cs2.domain_id = 'Observation'
                )
;

--2d. Collect encoding_ids and their possible values together
DROP TABLE IF EXISTS all_answers;
CREATE UNLOGGED TABLE all_answers (
   encoding_id INT,
   meaning TEXT,
   value TEXT,
   not_useful int2
);

INSERT INTO all_answers
SELECT DISTINCT encoding_id,
                meaning,
                value,
                0
FROM
    (SELECT encoding_id, meaning, value FROM sources.uk_biobank_esimpdate
    UNION ALL
    SELECT encoding_id, meaning, value FROM sources.uk_biobank_esimpint
    UNION ALL
    SELECT encoding_id, meaning, value FROM sources.uk_biobank_esimpreal
    UNION ALL
    SELECT encoding_id, meaning, value FROM sources.uk_biobank_esimpstring
    UNION ALL
    SELECT encoding_id, meaning, value FROM sources.uk_biobank_ehierint
    UNION ALL
    SELECT encoding_id, meaning, value FROM sources.uk_biobank_ehierstring) as a
;

--Mark not useful encoding_id (encoding_id marked as not useful when it consists only of a few values without complete meaning. Ex: 'Not known', 'Do not want to answer', etc.)
UPDATE all_answers
SET not_useful = 1
WHERE encoding_id IN (17,28,170,218,222,272,402,485,584,803,805,807,809,811,909,1207,1208,1209,1210,1313,1317,1990,4982,100584,37,42,236,513,100291,100586,13,1205,1206,1211,586)
;

--Mark not useful answers (flavour of NULL)
UPDATE all_answers
SET not_useful = 1
WHERE meaning IN ('Not known', 'Do not know', 'Do not know (group 2)', 'Do not know (group 1)', 'Reason not known', 'unknown', 'Unknown, cannot remember', 'Date uncertain or unknown',
                      'Not specified', 'Prefer not to answer', 'None of the above', 'Not available')
;

--3. Insert Questions/Variables to concept_stage
INSERT INTO concept_stage
( concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date)
SELECT DISTINCT
       trim(title) as concept_name,
       CASE WHEN cs.domain_id = 'Measurement' AND f.units IS NOT NULL THEN 'Measurement'
            WHEN f.main_category IN (1307, --Infectious Disease Antigens
                                     51428, --Infectious Diseases
                                     100083 --Urine assays
                                    ) AND f.field_id NOT IN (23048, --Antigen assay date
                                                             23049 --Antigen assay QC indicator
                                                            ) THEN 'Measurement'
            ELSE 'Observation' END as domain_id,
       'UK Biobank',
       'Undefined' as concept_class_id,
       NULL as standard_concept,
       field_id::varchar as concept_code,
       debut as valid_start_date,
       TO_DATE('20991231','yyyymmdd') as valid_end_date
FROM sources.uk_biobank_field f

LEFT JOIN concept_stage cs
    ON concat ('c', f.main_category) = cs.concept_code
        AND cs.vocabulary_id = 'UK Biobank'
        AND cs.concept_class_id = 'Category'

WHERE f.main_category NOT IN (SELECT DISTINCT descendant_concept_code
                              FROM category_ancestor
                              WHERE ancestor_concept_code IN (100091, --Health-related outcomes
                                                              100314 --Genomics
                                                             )
                                AND descendant_concept_code IS NOT NULL)
    AND f.main_category NOT IN (347 --Cardiac monitoring
        )
    AND f.item_type != 20 --Bulk (raw files, etc.)
;

--Assign concept_class_id to concepts
UPDATE concept_stage cs
SET concept_class_id =
    CASE WHEN cs.domain_id = 'Measurement'
                    THEN 'Variable'
                WHEN cs.domain_id = 'Observation'
                    THEN CASE WHEN notes ~* 'Question asked|ACE touchscreen question|(Participant|Particpant|Participants) asked|Participants were asked|User asked|User was asked' THEN 'Question'
                              WHEN main_category IN (130, --Employment history
                                                     132, --Medical information
                                                     1039, --Food (and other) preferences
                                                     100099 --Eye surgery/complications
                                                    ) AND field_id NOT IN (22617, --Job code - historical
                                                                           20599, --Order of asking questions
                                                                           20750, --When food preferences questionnaire completed
                                                                           20751 --Duration of questionnaire
                                                                          ) THEN 'Question'
                              ELSE 'Variable' END
                END
FROM sources.uk_biobank_field f
WHERE cs.concept_code = f.field_id::varchar
    AND cs.concept_class_id = 'Undefined'
    AND cs.vocabulary_id = 'UK Biobank'
;

--Assign standard_concept to concepts
UPDATE concept_stage cs
SET standard_concept = CASE WHEN f.encoding_id != 0
                                AND f.encoding_id IN (SELECT DISTINCT encoding_id FROM all_answers WHERE not_useful = 0 AND encoding_id IS NOT NULL)
                                AND f.main_category NOT IN ( --Exclude completely mapped categories
                                                            51428, --Infectious Diseases
                                                            100083 --Urine assays
                                                            ) THEN 'S'
                            ELSE NULL END
FROM sources.uk_biobank_field f
WHERE cs.concept_code = f.field_id::varchar
    AND cs.concept_class_id != 'Category'
    AND cs.vocabulary_id = 'UK Biobank'
;

--HESIN tables
INSERT INTO concept_stage
( concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date)
SELECT DISTINCT
       trim(description),
       'Observation',
       'UK Biobank',
       'Variable',
       CASE WHEN data_coding IS NOT NULL
                AND replace (data_coding, 'Coding ', '')::int IN (SELECT DISTINCT encoding_id FROM all_answers WHERE not_useful = 0 AND encoding_id IS NOT NULL)
                AND lower(field) NOT IN ('admisorc_uni', 'disdest_uni', 'tretspef_uni')     --Values of these variables are mapped to specific domains (Visit, Provider, etc.)
           THEN 'S'
           ELSE NULL END,
       field,
       TO_DATE('19700101','yyyymmdd'),
       TO_DATE('20991231','yyyymmdd')
FROM sources.uk_biobank_hesdictionary
WHERE lower(field) IN ('admisorc_uni', 'disdest_uni', 'tretspef_uni', 'mentcat', 'admistat', 'detncat', 'leglstat', 'postdur',
                       'anagest', 'antedur', 'delchang', 'delinten', 'delonset', 'delposan', 'delprean', 'numbaby', 'numpreg',
                       'biresus', 'birordr', 'birstat', 'birweight', 'delmeth', 'delplac', 'delstat', 'gestat', 'sexbaby');

--4. Insert synonyms to concept_synonym_stage
--4a. Category
INSERT INTO concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)
SELECT DISTINCT
       NULL::int,
       trim(regexp_replace(descript, '((?<!www|xnat|sahsu|bioshare|ware v1|USB 6|soft v6|\(i\.e|\(i| )\..*)| ?<(p|ul|li|/li)>', '', 'g')) AS synonym_name,
       CONCAT('c', category_id) as synonym_concept_code,
       'UK Biobank',
       4180186 --English language
FROM sources.uk_biobank_category
WHERE descript IS NOT NULL
    AND descript != ''
    AND trim(descript) != trim(title)
    AND trim(descript) != concat(trim(title), '.')
;

--4b. Fields part I
--TODO: few concepts still left with problems due to source issue -> need to create use cases for them specifically)
INSERT INTO concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)
SELECT DISTINCT
       NULL::int,
       CASE WHEN notes ILIKE 'Participant asked%'
                OR notes ILIKE 'User asked "%'
                OR notes ILIKE 'User asked: "%'
                OR notes ILIKE 'Participants were asked "%'
                OR notes ILIKE 'Participants were asked:"%'
                OR notes ILIKE 'Participants were asked: "%'
                OR notes ILIKE 'Participants were asked: <p> "%'
                OR notes ILIKE 'Participant asked "%'
                OR notes ILIKE 'Participant asked: "%'
           THEN vocabulary_pack.CutConceptSynonymName(substring(notes, '"(.*)"'))
           ELSE vocabulary_pack.CutConceptSynonymName(regexp_replace(regexp_replace(notes, '<.*>|(You can select more than one answer)', ' ', 'g'), '\s{2,}|\.$', '', 'g')) END AS synonym_name,
       field_id AS synonym_concept_code,
       'UK Biobank',
       4180186      --English language
FROM sources.uk_biobank_field
WHERE notes IS NOT NULL
    AND notes != ''
    AND trim(notes) != trim(title)
    AND trim(notes) != concat(trim(title), '.')
    AND notes NOT ILIKE 'ACE touchscreen question%' --Processed below
    AND notes NOT ILIKE 'Question asked%'           --Processed below
    AND notes != '.'
    AND field_id::varchar IN (SELECT DISTINCT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank' AND concept_code IS NOT NULL)
;

--4c. Fields part II (ACE touchscreen question|Question asked)
INSERT INTO concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)
SELECT DISTINCT
       NULL::int,
       CASE WHEN notes NOT ILIKE 'ACE touchscreen question%' AND notes NOT ILIKE 'Question asked:%'   --few concepts with 'Question asked', but not 'Question asked:'
           THEN vocabulary_pack.CutConceptSynonymName(substring(notes, '(^.*(?=<))'))
           ELSE vocabulary_pack.CutConceptSynonymName(substring(regexp_replace(notes, '<.*$', ''), '"(.*)"')) END AS synonym_name,
       field_id AS synonym_concept_code,
       'UK Biobank',
       4180186      --English language
FROM sources.uk_biobank_field
WHERE notes IS NOT NULL
    AND notes != ''
    AND trim(notes) != trim(title)
    AND trim(notes) != concat(trim(title), '.')
    AND (notes ILIKE 'ACE touchscreen question%' OR notes ILIKE 'Question asked%')
    AND notes != '.'
    AND field_id::varchar IN (SELECT DISTINCT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank' AND concept_code IS NOT NULL)
;

--5. Insert answers/values to concept_stage
INSERT INTO concept_stage
( concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date)
SELECT DISTINCT
       trim(meaning),
       CASE WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') IN ('Variable', 'Question Variable')
                AND array_to_string(array_agg (DISTINCT cs.domain_id ORDER BY cs.domain_id), ' ') IN ('Measurement', 'Measurement Observation')
            THEN 'Meas Value'
            ELSE 'Observation'
       END,
       'UK Biobank',
       CASE WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Question' THEN 'Answer'
            WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Variable' THEN 'Value'
            WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Question Variable' THEN 'Value'
            ELSE '?'
       END,
       CASE WHEN a.encoding_id IN (SELECT DISTINCT encoding_id FROM sources.uk_biobank_field WHERE encoding_id IS NOT NULL AND field_id::varchar IN (SELECT DISTINCT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank'
                                                                                                                                                                            AND standard_concept = 'S'
                                                                                                                                                                            AND concept_code IS NOT NULL))
                AND a.encoding_id NOT IN (4, --20003 Treatment/medication code
                                          744) --20199 Antibiotic codes for last 3 months
                AND meaning NOT IN (SELECT DISTINCT meaning FROM all_answers WHERE not_useful = 1 AND meaning IS NOT NULL)
            THEN 'S'
            ELSE NULL END,
       CONCAT(a.encoding_id::varchar, '-', value),
       MIN (f.debut),
       TO_DATE('20991231','yyyymmdd')
FROM all_answers a

LEFT JOIN sources.uk_biobank_field f
    ON a.encoding_id = f.encoding_id

LEFT JOIN concept_stage cs
    ON f.field_id::varchar = cs.concept_code
        AND cs.vocabulary_id = 'UK Biobank'
        AND cs.concept_class_id IN ('Question', 'Variable')

WHERE a.encoding_id IN (SELECT DISTINCT encoding_id FROM sources.uk_biobank_field WHERE encoding_id IS NOT NULL AND field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank' AND concept_code IS NOT NULL))
    AND a.encoding_id NOT IN (1836, --ICD9 to ICD10 mapping
                            196, 197, 198, 199, 123) --values to be parsed in ETL
    AND a.encoding_id NOT IN (SELECT DISTINCT encoding_id FROM sources.uk_biobank_ehierint WHERE encoding_id IS NOT NULL) --Logic differs for these concepts (find the query below)
GROUP BY 1,3,5,6,8
;

--5b. Insert answers/values to concept_stage (uk_biobank_ehierint)
INSERT INTO concept_stage
( concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date)
SELECT DISTINCT
       trim(regexp_replace(meaning, '^\d*\.?\d* ', '')),
       CASE WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') IN ('Variable', 'Question Variable')
                AND array_to_string(array_agg (DISTINCT cs.domain_id ORDER BY cs.domain_id), ' ') IN ('Measurement', 'Measurement Observation')
            THEN 'Meas Value'
            ELSE 'Observation'
       END,
       'UK Biobank',
       CASE WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Question' THEN 'Answer'
            WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Variable' THEN 'Value'
            WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Question Variable' THEN 'Value'
            ELSE '?'
       END,
CASE WHEN ei.encoding_id IN (SELECT DISTINCT encoding_id FROM sources.uk_biobank_field WHERE encoding_id IS NOT NULL AND field_id::varchar IN (SELECT DISTINCT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank'
                                                                                                                                                                                                    AND standard_concept = 'S'
                                                                                                                                                                                                    AND concept_code IS NOT NULL))
        AND ei.encoding_id NOT IN (3, --20001	Cancer code, self-reported
                                   5, --20004 Operation code
                                   6 --20002 Non-cancer illness code, self-reported
        )
        AND meaning NOT IN (SELECT DISTINCT meaning FROM all_answers WHERE not_useful = 1 AND meaning IS NOT NULL)
     THEN 'S'
     ELSE NULL END,
       CONCAT(ei.encoding_id::varchar, '-', value),
       MIN(f.debut),
       TO_DATE('20991231','yyyymmdd')
FROM sources.uk_biobank_ehierint ei

LEFT JOIN sources.uk_biobank_field f
    ON ei.encoding_id = f.encoding_id

LEFT JOIN concept_stage cs
    ON f.field_id::varchar = cs.concept_code
        AND cs.vocabulary_id = 'UK Biobank'
        AND cs.concept_class_id IN ('Question', 'Variable')

WHERE ei.encoding_id NOT IN (19 /*ICD10*/, 87 /*ICD9 or ICD9CM*/, 240 /*OPCS4*/, 2/*SOC2000*/)
    AND ei.encoding_id IN (SELECT DISTINCT encoding_id FROM sources.uk_biobank_field WHERE encoding_id IS NOT NULL AND field_id::varchar IN (SELECT DISTINCT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank'
                                                                                                                                                                                               AND concept_code IS NOT NULL))

    AND selectable = 1      --Only values that can be spotted in the real data

GROUP BY 1,3,5,6,8
;

--5c. Insert answers/values to concept_stage (HESIN uk_biobank_hesdictionary answers/values coming from main metadata)
INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT
       trim(meaning),
       CASE WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') IN ('Variable', 'Question Variable')
                AND array_to_string(array_agg (DISTINCT cs.domain_id ORDER BY cs.domain_id), ' ') IN ('Measurement', 'Measurement Observation')
            THEN 'Meas Value'
            ELSE 'Observation'
       END,
       'UK Biobank',
       CASE WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Question' THEN 'Answer'
            WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Variable' THEN 'Value'
            WHEN array_to_string(array_agg (DISTINCT cs.concept_class_id ORDER BY cs.concept_class_id), ' ') = 'Question Variable' THEN 'Value'
            ELSE '?'
        END,
        --'S',
       CASE WHEN aa.encoding_id IN (SELECT DISTINCT encoding_id FROM sources.uk_biobank_field WHERE encoding_id IS NOT NULL AND field_id::varchar IN (SELECT DISTINCT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank'
                                                                                                                                                                                                        AND standard_concept = 'S'
                                                                                                                                                                                                        AND concept_code IS NOT NULL))
               AND meaning NOT IN (SELECT DISTINCT meaning FROM all_answers WHERE not_useful = 1 AND meaning IS NOT NULL)
            THEN 'S'
            ELSE NULL END,
       CONCAT(aa.encoding_id::varchar, '-', value),
       COALESCE(MIN (f.debut), to_date('19700101', 'yyyymmdd')),
       TO_DATE('20991231','yyyymmdd')
FROM all_answers aa

LEFT JOIN sources.uk_biobank_hesdictionary hes
    ON aa.encoding_id = replace(data_coding, 'Coding ', '')::int

LEFT JOIN concept_stage cs
    ON lower(hes.field) = cs.concept_code
        AND cs.vocabulary_id = 'UK Biobank'
        AND cs.concept_class_id IN ('Question', 'Variable')

LEFT JOIN sources.uk_biobank_field f
    ON aa.encoding_id = f.encoding_id

WHERE aa.encoding_id IN (SELECT DISTINCT replace(data_coding, 'Coding ', '')::int AS encoding_id FROM sources.uk_biobank_hesdictionary
                            WHERE lower(field) IN ('admisorc_uni', 'disdest_uni', 'tretspef_uni', 'mentcat', 'admistat', 'detncat', 'leglstat',
                                                'anagest', 'antedur', 'delchang', 'delinten', 'delonset', 'delposan', 'delprean', 'numbaby', 'numpreg', 'postdur',
                                                      'biresus', 'birordr', 'birstat', 'birweight', 'delmeth', 'delplac', 'delstat', 'gestat', 'sexbaby')
                            AND replace(data_coding, 'Coding ', '') IS NOT NULL)

    AND concat(aa.encoding_id::varchar, '-', value) NOT IN (SELECT DISTINCT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank' AND concept_code IS NOT NULL)

    AND lower(field) IN ('admisorc_uni', 'disdest_uni', 'tretspef_uni', 'mentcat', 'admistat', 'detncat', 'leglstat',
                        'anagest', 'antedur', 'delchang', 'delinten', 'delonset', 'delposan', 'delprean', 'numbaby', 'numpreg', 'postdur',
                              'biresus', 'birordr', 'birstat', 'birweight', 'delmeth', 'delplac', 'delstat', 'gestat', 'sexbaby')
GROUP BY 1,3,5,6,8
;

--6. Building hierarchy for Questions/Variables/Categories
--6a. Hierarchy between Categories
INSERT INTO concept_relationship_stage
( concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason)

--provided by the source
SELECT DISTINCT
       concat('c', child_id) AS concept_code_1,
       concat('c', parent_id) AS concept_code_2,
       'UK Biobank',
       'UK Biobank',
       'Is a',
       TO_DATE('19700101','yyyymmdd'),
       TO_DATE('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_catbrowse cb

UNION ALL

--from top Level Category to Parent UKB Category concept
SELECT DISTINCT
       concat('c', category_id) AS concept_code_1,
       'c0' as concept_code_2,
       'UK Biobank',
       'UK Biobank',
       'Is a',
       TO_DATE('19700101','yyyymmdd'),
       TO_DATE('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_category c
WHERE c.category_id IN ( --from Online browser https://biobank.ctsu.ox.ac.uk/showcase/browse.cgi?id=-2&cd=search
                        1,	--Population characteristics
                        100000,	--UK Biobank Assessment Centre
                        100078,	--Biological samples
                        100088,	--Additional exposures
                        100089,	--Online follow-up
                        100091,	--Health-related outcomes
                        100314	--Genomics
    )
;

--6b. Hierarchy between Categories and Questions/Variables
INSERT INTO concept_relationship_stage
( concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason)
SELECT DISTINCT
       f.field_id AS concept_code_1,
       cs.concept_code AS concept_code_2,
       'UK Biobank',
       'UK Biobank',
       'Has Category',
       f.debut,
       TO_DATE('20991231','yyyymmdd'),
       NULL
FROM concept_stage cs
JOIN sources.uk_biobank_field f
    ON f.main_category::varchar = replace(cs.concept_code, 'c', '')
WHERE vocabulary_id = 'UK Biobank'
    AND concept_class_id = 'Category'
    AND f.field_id::varchar IN (SELECT DISTINCT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank' AND concept_code IS NOT NULL)
;

--7a. Building Has answer/Has Value relationships
--For main dataset
with all_omoped_answers AS
    (   SELECT encoding_id, value, cs.concept_code, cs.concept_class_id
        FROM all_answers
        JOIN concept_stage cs
            ON cs.concept_code = concat(encoding_id::varchar, '-', value)
                AND vocabulary_id = 'UK Biobank'
                AND concept_class_id IN ('Answer', 'Value')
    )
INSERT INTO concept_relationship_stage
( concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason)
SELECT DISTINCT
       cs.concept_code,
       aa.concept_code,
       'UK Biobank',
       'UK Biobank',
       CASE WHEN aa.concept_class_id = 'Answer' THEN 'Has Answer'
            WHEN aa.concept_class_id = 'Value' THEN 'Has Value'
            ELSE '?' END,
       cs.valid_start_date,
       TO_DATE('20991231','yyyymmdd'),
       NULL
FROM concept_stage cs
JOIN sources.uk_biobank_field f
    ON cs.concept_code = f.field_id::varchar AND cs.vocabulary_id = 'UK Biobank'
JOIN all_omoped_answers aa
    ON aa.encoding_id = f.encoding_id
WHERE f.encoding_id != 0
;

--7b. Building Has answer/Has Value relationships
--For HESIN dataset
with all_omoped_answers AS
    (   SELECT encoding_id, value, cs.concept_code, cs.concept_class_id
        FROM all_answers
        JOIN concept_stage cs
            ON cs.concept_code = concat(encoding_id::varchar, '-', value)
                AND vocabulary_id = 'UK Biobank'
                AND concept_class_id IN ('Answer', 'Value')
    )
INSERT INTO concept_relationship_stage
( concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason)
SELECT DISTINCT
       cs.concept_code,
       aa.concept_code,
       'UK Biobank',
       'UK Biobank',
       CASE WHEN aa.concept_class_id = 'Answer' THEN 'Has Answer'
            WHEN aa.concept_class_id = 'Value' THEN 'Has Value'
            ELSE '?' END,
       cs.valid_start_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM concept_stage cs
JOIN sources.uk_biobank_hesdictionary hes
    ON cs.concept_code = hes.field AND cs.vocabulary_id = 'UK Biobank'
JOIN all_omoped_answers aa
    ON aa.encoding_id = replace(hes.data_coding, 'Coding ', '')::int
WHERE replace(hes.data_coding, 'Coding ', '') IS NOT NULL
    AND hes.data_coding LIKE 'Coding%'
;

--8. Processing new precoordinated pairs and mapping for Questions/Variables and Answers/Values through concept_relationship + concept_stage tables
--+ UKB_psychiatry
--Creating concepts for QA pairs
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
       NULL::int,
       concat(trim(dd.description), ': ', trim(aa.meaning)),
       'Observation',
       'UK Biobank',
       'Precoordinated pair',
       NULL,
       concat(dd.field, '-', aa.encoding_id, '-', aa.value),
       COALESCE(c.valid_start_date, current_date),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_hesdictionary dd
JOIN all_answers aa
    ON aa.encoding_id::varchar = substring(data_coding, '[0-9].*')
LEFT JOIN concept c
    ON concat(dd.field, '-', aa.encoding_id, '-', aa.value) = c.concept_code
        AND c.vocabulary_id = 'UK Biobank'
WHERE field IN ('mentcat', 'admistat', 'detncat', 'leglstat')
;

--+ UKB_maternity
--Creating concepts for QA pairs
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
       NULL::int,
       concat(trim(dd.description), ': ', trim(aa.meaning)),
       'Observation',
       'UK Biobank',
       'Precoordinated pair',
       NULL,
       concat(dd.field, '-', aa.encoding_id, '-', aa.value),
       COALESCE(c.valid_start_date, current_date),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_hesdictionary dd
JOIN all_answers aa
    ON aa.encoding_id::varchar = substring(data_coding, '[0-9].*')
LEFT JOIN concept c
    ON concat(dd.field, '-', aa.encoding_id, '-', aa.value) = c.concept_code
        AND c.vocabulary_id = 'UK Biobank'
WHERE field IN ('delchang', 'delinten', 'delonset', 'delposan', 'delprean', 'numbaby')      --anagest, antedur, numpreg, postdur not included --> only QA pairs
;


--+ UKB_delivery
--Creating concepts for QA pairs
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
       NULL::int,
       concat(trim(dd.description), ': ', trim(aa.meaning)),
       'Observation',
       'UK Biobank',
       'Precoordinated pair',
       NULL,
       concat(dd.field, '-', aa.encoding_id, '-', aa.value),
       COALESCE(c.valid_start_date, current_date),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_hesdictionary dd
JOIN all_answers aa
    ON aa.encoding_id::varchar = substring(data_coding, '[0-9].*')
LEFT JOIN concept c
    ON concat(dd.field, '-', aa.encoding_id, '-', aa.value) = c.concept_code
        AND c.vocabulary_id = 'UK Biobank'
WHERE field IN ('biresus', 'birordr', 'birstat', 'birweight', 'delmeth', 'delplac', 'delstat', 'sexbaby') --gestat not included -> only QA pairs
;


--+ All possible precoordinated pairs from the main dataset
--Creating concepts for QA pairs
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
       NULL::int,
       vocabulary_pack.cutconceptname(concat(trim(f.title), ': ', trim(aa.meaning))),
       'Observation',
       'UK Biobank',
       'Precoordinated pair',
       NULL,
       concat(f.field_id, '-', aa.encoding_id, '-', aa.value),
       COALESCE(c.valid_start_date, current_date),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_field f
JOIN all_answers aa
    ON f.encoding_id = aa.encoding_id
LEFT JOIN concept c
    ON concat(f.field_id, '-', aa.encoding_id, '-', aa.value) = c.concept_code
        AND c.vocabulary_id = 'UK Biobank'
;

--9a. Processing manual relationships from concept_relationship_manual to concept_relationship
SELECT vocabulary_pack.ProcessManualRelationships();


--9b. Removing unnecessary precoordinated pairs
DELETE FROM concept_stage
WHERE concept_class_id = 'Precoordinated pair'
    AND concept_code NOT IN (SELECT DISTINCT concept_code_1 FROM concept_relationship_stage WHERE relationship_id = 'Maps to' AND invalid_reason IS NULL AND concept_code_1 IS NOT NULL);

--10. Updates after creating concepts for precoordinated pairs
--10a. Creating relationships from Questions/Variables to Precoordinated pairs
INSERT INTO concept_relationship_stage(concept_id_1, concept_id_2, concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
       NULL::int,
       NULL::int,
        f.field_id,
        cs.concept_code,
       'UK Biobank',
       'UK Biobank',
       'Has precoord pair',
       cs.valid_start_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_field f
JOIN concept_stage cs
    ON f.field_id::varchar = regexp_replace(cs.concept_code, '-.*$', '')
WHERE cs.concept_class_id = 'Precoordinated pair';

--10b. Creating relationships from Questions/Variables to Precoordinated pairs (HES)
INSERT INTO concept_relationship_stage(concept_id_1, concept_id_2, concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
       NULL::int,
       NULL::int,
       s.field,
       cs.concept_code,
       'UK Biobank',
       'UK Biobank',
       'Has precoord pair',
       cs.valid_start_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_hesdictionary s
JOIN concept_stage cs
    ON s.field = regexp_replace(cs.concept_code, '-.*$', '')
WHERE cs.concept_class_id = 'Precoordinated pair';

--10c. Creating relationships from Answers/Variables to Precoordinated pairs
INSERT INTO concept_relationship_stage(concept_id_1, concept_id_2, concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
       NULL::int,
       NULL::int,
        cs1.concept_code,
        cs2.concept_code,
       'UK Biobank',
       'UK Biobank',
       'Has precoord pair',
       cs2.valid_start_date,
       to_date('20991231','yyyymmdd'),
       NULL
FROM concept_stage cs1
JOIN concept_stage cs2
    ON cs1.concept_code = regexp_replace(cs2.concept_code, '^[A-Za-z0-9]*-', '')
        AND cs2.concept_class_id = 'Precoordinated pair'
WHERE cs1.concept_class_id IN ('Answer', 'Value')
;

--11. Making concepts with mapping Non-standard
UPDATE concept_stage
    SET standard_concept = NULL
WHERE standard_concept IS NOT NULL
    AND concept_code IN (SELECT DISTINCT concept_code_1 FROM concept_relationship_stage crs WHERE relationship_id = 'Maps to' AND crs.invalid_reason IS NULL AND concept_code_1 IS NOT NULL);

--Drop temp table
DROP TABLE all_answers;
DROP TABLE category_ancestor;
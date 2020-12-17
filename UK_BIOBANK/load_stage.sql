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
* Date: August 2020
**************************************************************************/


--0. Update a 'latest_update' field to a new date
--TODO: specify the correct version and date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'UK Biobank',
	pVocabularyDate			=> TO_DATE ('2007-03-21' ,'yyyy-mm-dd'),   --From UK Biobank: https://biobank.ctsu.ox.ac.uk/showcase/exinfo.cgi?src=timelines
	pVocabularyVersion		=> 'Version 0.0.1',
	pVocabularyDevSchema	=> 'dev_ukbiobank'
);
END $_$;

--1. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;


--2: Insert categories to concept_stage
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

SELECT trim(title),
        CASE WHEN title ~* 'assay|sampl|meas|ultrasound|MRI|pressure|ECG|tomography|densit|Freesurfer|DXA|Autorefraction|antigens|sample|imaging'
            THEN 'Measurement' ELSE 'Observation' END AS domain_id,
       'UK Biobank',
       'Biobank Category',
       'C',
       concat('c', cat.category_id),
       current_date,  --to_date(last_update,'yyyymmdd'),
       to_date('20991231','yyyymmdd')

FROM sources.uk_biobank_category cat
WHERE category_id != 0;

--3: Insert questions to concept_stage
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

SELECT trim(title),
       CASE WHEN f.main_category::varchar IN (SELECT regexp_replace(concept_code, 'c', '') FROM concept_stage WHERE vocabulary_id = 'UK Biobank' AND concept_class_id = 'Biobank Category'
           AND domain_id = 'Measurement') OR f.main_category IN (148, 1307, 9081, 17518, 18518, 51428, 100078, 100079, 100080, 100081, 100082, 100083, 100084, 100085, 100086, 100087, --Lab tests
                                                                 --Imaging
                                                                100, 102, 103, 105, 106, 107, 108, 109, 110, 111, 112, 124, 125, 126, 128, 131, 133, 134, 135, 149, 190, 191, 192, 193, 194, 195, 196, 197, 1101, 1102, 100003) THEN 'Measurement' ELSE 'Observation' END AS domain_id,
        'UK Biobank',
        CASE WHEN
            f.main_category IN (148, 1307, 9081, 17518, 18518, 51428, 100078, 100079, 100080, 100081, 100082, 100083, 100084, 100085, 100086, 100087) THEN 'Lab Test'
            WHEN f.encoding_id != 0 AND f.main_category NOT IN (148, 1307, 9081, 17518, 18518, 51428, 100078, 100079, 100080, 100081, 100082, 100083, 100084, 100085, 100086, 100087, --Lab tests
                                                                --Physical Measures
                                                               101, 104, 100006, 100007, 100008, 100009, 100010, 100011, 100012, 100013, 100014, 100015, 100016, 100017, 100018, 100019, 100020,
                                                                100049, 100099) THEN 'Question'
            --Portion 2 of surveys:
            --All touchscreen and Verbal interview (UKB Assessment Center) + Online Follow up
            --touchscreen
            WHEN f.main_category IN (54, 100025, 100033, 100034, 100050)
                OR f.main_category BETWEEN 100036 AND 100048
                OR f.main_category BETWEEN 100050 AND 100070
            --Verbal interview
                OR f.main_category BETWEEN 100071 AND 100076
            --Online Follow up
                OR f.main_category IN (116, 117, 118, 120, 121, 122, 123, 130, 132, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 153, 154, 155, 1039, 100089, 100090, 100097, 100098, 100100, 100114)
                OR f.main_category BETWEEN 100101 AND 100112
                THEN 'Question'

            ELSE 'Clinical Observation' END,
        CASE WHEN f.encoding_id != 0 AND f.main_category NOT IN (148, 1307, 9081, 17518, 18518, 51428, 100078, 100079, 100080, 100081, 100082, 100083, 100084, 100085, 100086, 100087)
            THEN 'S' ELSE NULL END,
        field_id,
       debut,
       to_date('20991231','yyyymmdd')
FROM sources.uk_biobank_field f
WHERE f.main_category NOT IN (SELECT child_id FROM sources.uk_biobank_catbrowse WHERE parent_id IN (100091, 2000, 1712))
AND f.main_category NOT IN (SELECT child_id FROM sources.uk_biobank_catbrowse WHERE parent_id IN (100314))
AND f.main_category NOT IN (100091, 43, 44, 45, 46, 47, 48, 49, 50, 2000, 1712, 3000, 3001, 100092, 100093,
                           1017, 100314, 181, 182, 100035, 100313, 100314, 100315, 100316, 100317, 100319, 199001,
                           347
                           )
AND f.item_type != 20
;

--Some codes got mistaken concept_class or domain due to biobank classification
UPDATE concept_stage
    SET domain_id = 'Observation',
        concept_class_id = 'Clinical Observation',
        standard_concept = 'S'
WHERE concept_name ilike '%assay date%'
;

UPDATE concept_stage
    SET domain_id = 'Observation',
        concept_class_id = 'Question',
        standard_concept = 'S'
WHERE concept_name ilike '%reason%' AND concept_class_id != 'Lab Test';

UPDATE concept_stage
    SET domain_id = 'Observation',
        concept_class_id = 'Clinical Observation',
        standard_concept = NULL
WHERE concept_name ilike '%reason%'
AND concept_class_id = 'Lab Test';

UPDATE concept_stage
    SET domain_id = 'Observation',
        concept_class_id = 'Clinical Observation',
        standard_concept = NULL
WHERE concept_name ilike '%device id%'
AND domain_id = 'Measurement';

UPDATE concept_stage
    SET domain_id = 'Observation',
        concept_class_id = 'Clinical Observation',
        standard_concept = 'S'
WHERE standard_concept = 'S'
AND domain_id = 'Measurement';


--Make all Surveys standard
UPDATE concept_stage
    SET standard_concept = 'S'
WHERE concept_class_id = 'Question';

--HESIN tables
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

SELECT description,
        'Observation',
       'UK Biobank',
       'Clinical Observation',
       'S',
       field,
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
       FROM sources.uk_biobank_hesdictionary
    WHERE lower(field) IN ('admisorc_uni', 'disdest_uni', 'tretspef_uni', 'mentcat', 'admistat', 'detncat', 'leglstat',
                    'anagest', 'antedur', 'delchang', 'delinten', 'delonset', 'delposan', 'delprean', 'numbaby', 'numpreg', 'postdur',
                          'biresus', 'birordr', 'birstat', 'birweight', 'delmeth', 'delplac', 'delstat', 'gestat', 'sexbaby');


--4: Insert questions to concept_synonym_stage
INSERT INTO concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)

SELECT NULL,
       vocabulary_pack.CutConceptSynonymName(trim(regexp_replace(regexp_replace(notes, '<.*>|(You can select more than one answer)', ' ', 'g'), '\s{2,}|\.$', '', 'g'))) AS synonym_name,
       field_id AS synonym_concept_code,
       'UK Biobank',
       4180186
FROM sources.uk_biobank_field
WHERE notes IS NOT NULL
AND notes != ''
AND (notes != title OR notes != concat(title, '.'))
AND notes not ilike 'ACE touchscreen question%'
AND notes not ilike 'Question asked%'
AND notes != '.'

AND field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank')
;


INSERT INTO concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)

SELECT NULL,
       vocabulary_pack.CutConceptSynonymName(substring(notes, '"(.*)"')) AS synonym_name,
       field_id AS synonym_concept_code,
       'UK Biobank',
       4180186
FROM field
WHERE notes IS NOT NULL
AND notes != ''
AND (notes != title OR notes != concat(title, '.'))
AND (notes ilike 'ACE touchscreen question%' OR notes ilike 'Question asked%')
AND notes != '.'

AND field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank')
;

--5: Insert answers to concept_stage

--All answers together
CREATE TABLE all_answers AS
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
        SELECT encoding_id, meaning, value FROM sources.uk_biobank_ehierstring);

--TODO: Exclude also 1200?
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

SELECT trim(meaning),
       'Meas Value',
       'UK Biobank',
       'Answer',
       CASE WHEN encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank' AND standard_concept = 'S')) THEN 'S'
           ELSE NULL END,
       concat(encoding_id::varchar, '-', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM all_answers

--Only those encodings that we need
WHERE encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank'))
AND encoding_id NOT IN (1836, 196, 197, 198, 199)
  --Logic differs for these concepts
AND encoding_id NOT IN (SELECT encoding_id FROM sources.uk_biobank_ehierint)
;


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

SELECT trim(regexp_replace(meaning, '^\d*\.?\d* ', '')),
       'Meas Value',
       'UK Biobank',
       'Answer',
CASE WHEN encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank' AND standard_concept = 'S'))
    AND selectable = 1 THEN 'S'
           ELSE NULL END,
       concat(encoding_id::varchar, '-', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM sources.uk_biobank_ehierint
WHERE encoding_id NOT IN (19 /*ICD10*/, 87 /*ICD9 or ICD9CM?*/, 240 /*OPCS4*/)
AND encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank'))
AND selectable = 1
;

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

SELECT meaning,
       'Meas Value',
       'UK Biobank',
       'Answer',
        'S',
       concat(encoding_id::varchar, '-', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM all_answers
WHERE encoding_id IN
(SELECT DISTINCT regexp_replace(data_coding, 'Coding ', '')::int AS encoding_id FROM sources.uk_biobank_hesdictionary
WHERE lower(field) IN ('admisorc_uni', 'disdest_uni', 'tretspef_uni', 'mentcat', 'admistat', 'detncat', 'leglstat',
                    'anagest', 'antedur', 'delchang', 'delinten', 'delonset', 'delposan', 'delprean', 'numbaby', 'numpreg', 'postdur',
                          'biresus', 'birordr', 'birstat', 'birweight', 'delmeth', 'delplac', 'delstat', 'gestat', 'sexbaby')
AND regexp_replace(data_coding, 'Coding ', '') IS NOT NULL)

AND concat(encoding_id::varchar, '-', value) NOT IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank')
;

--HESIN Answers coming from main metadata
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

SELECT meaning,
       'Meas Value',
       'UK Biobank',
       'Answer',
        'S',
       concat(encoding_id::varchar, '-', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM all_answers
WHERE encoding_id IN
(SELECT DISTINCT regexp_replace(data_coding, 'Coding ', '')::int AS encoding_id FROM sources.uk_biobank_hesdictionary
WHERE lower(field) IN ('admisorc_uni', 'disdest_uni', 'tretspef_uni', 'mentcat', 'admistat', 'detncat', 'leglstat',
                    'anagest', 'antedur', 'delchang', 'delinten', 'delonset', 'delposan', 'delprean', 'numbaby', 'numpreg', 'postdur',
                          'biresus', 'birordr', 'birstat', 'birweight', 'delmeth', 'delplac', 'delstat', 'gestat', 'sexbaby')
AND regexp_replace(data_coding, 'Coding ', '') IS NOT NULL)

AND concat(encoding_id::varchar, '-', value) NOT IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'UK Biobank')
;


--6: Building hierarchy for questions
--Hierarchy between Classification concepts
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT concat('c', parent_id),
       concat('c', child_id),
       'UK Biobank',
       'UK Biobank',
       'Subsumes',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_catbrowse cb;

--Hierarchy between classification concepts and questions
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT cs.concept_code AS concept_code_1,
       f.field_id AS concept_code_2,
       'UK Biobank',
       'UK Biobank',
       'Subsumes',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM concept_stage cs
JOIN sources.uk_biobank_field f
ON f.main_category::varchar = regexp_replace(cs.concept_code, 'c', '')
WHERE vocabulary_id = 'UK Biobank'
AND concept_class_id = 'Biobank Category'
AND f.field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE cs.vocabulary_id = 'UK Biobank')
;


--7: Building 'Has answer' relationships
--For main dataset
with all_omoped_answers AS
    (
        SELECT encoding_id, meaning, value, cs.concept_code
        FROM all_answers
        JOIN concept_stage cs
        ON cs.concept_code = concat(encoding_id::varchar, '-', value) AND vocabulary_id = 'UK Biobank' AND concept_class_id = 'Answer'
    )

INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT DISTINCT
       cs.concept_code,
       aa.concept_code,
       'UK Biobank',
       'UK Biobank',
       'Has Answer',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM concept_stage cs
JOIN sources.uk_biobank_field f
ON cs.concept_code = f.field_id::varchar AND cs.vocabulary_id = 'UK Biobank'
JOIN all_omoped_answers aa
ON aa.encoding_id = f.encoding_id

WHERE f.encoding_id != 0
;


--For HESIN dataset
with all_omoped_answers AS
    (
        SELECT encoding_id, meaning, value, cs.concept_code
        FROM all_answers
        JOIN concept_stage cs
        ON cs.concept_code = concat(encoding_id::varchar, '-', value) AND vocabulary_id = 'UK Biobank' AND concept_class_id = 'Answer'
    )

INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT DISTINCT
       cs.concept_code,
       aa.concept_code,
       'UK Biobank',
       'UK Biobank',
       'Has Answer',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM concept_stage cs
JOIN sources.uk_biobank_hesdictionary hes
ON cs.concept_code = hes.field AND cs.vocabulary_id = 'UK Biobank'
JOIN all_omoped_answers aa
ON aa.encoding_id = regexp_replace(hes.data_coding, 'Coding ', '')::int

WHERE regexp_replace(hes.data_coding, 'Coding ', '') IS NOT NULL
;



--8: Processing new Question-answer pairs and mapping for Questions and Answers through concept_relationship_manual + concept_stage tables

--+ UKB_source_of_admission
--Question: Non-standard
--Answers: Standard or mapped to visits
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = 'admisorc_uni';

INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT source_code AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_source_of_admission_mapped
WHERE target_concept_id != 0
;

--Non-standard even without mapping
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code ~* '265-';



--+ UKB_destination_on_discharge
--Question: Non-standard
--Answers: Standard or mapped to visits
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = 'disdest_uni';

INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT source_code AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_destination_on_discharge_mapped
WHERE target_concept_id != 0
;

--Non-standard even without mapping
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code ~* '267-';



--TODO: Corresponding question from main dataset should be non-standard?
--+ UKB_treatment_specialty
--Question: Non-standard
--Answers: Standard or mapped to provider
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = 'tretspef_uni';

INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT source_code AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_treatment_specialty_mapped
WHERE target_concept_id != 0
;

--Non-standard even without mapping
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code ~* '269-';



--+ UKB_psychiatry
--Mapped to standard QA pairs
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat(field_id, '-', source_code) AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value' ELSE 'Maps to' END,
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_psychiatry_mapped
WHERE target_concept_id != 0
;

--Creating concepts for QA pairs
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT NULL,
       concat(dd.description, ': ', aa.meaning),
       'Observation',
       'UK Biobank',
       'Question-Answer pair',
       NULL,
       concat(dd.field, '-', aa.encoding_id, '-', aa.value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_hesdictionary dd
JOIN all_answers aa
ON aa.encoding_id::varchar = substring(data_coding, '[0-9].*')
WHERE field IN ('mentcat', 'admistat', 'detncat', 'leglstat')
AND concat(dd.field, '-', aa.encoding_id, '-', aa.value) IN (SELECT concept_code_1 FROM concept_relationship_manual)
;



--+ UKB_maternity
--Mapped to standard QA pairs
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT CASE WHEN source_code IS NOT NULL AND source_code != '' AND field_id != 'numpreg' THEN concat(field_id, '-', source_code) ELSE field_id END AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value' ELSE 'Maps to' END,
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_maternity_mapped
WHERE target_concept_id != 0
;

--Creating concepts for QA pairs
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT NULL,
       concat(dd.description, ': ', aa.meaning),
       'Observation',
       'UK Biobank',
       'Question-Answer pair',
       NULL,
       concat(dd.field, '-', aa.encoding_id, '-', aa.value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_hesdictionary dd
JOIN all_answers aa
ON aa.encoding_id::varchar = substring(data_coding, '[0-9].*')
WHERE field IN ('delchang', 'delinten', 'delonset', 'delposan', 'delprean', 'numbaby')
AND concat(dd.field, '-', aa.encoding_id, '-', aa.value) IN (SELECT concept_code_1 FROM concept_relationship_manual)
;


--+ UKB_delivery
--Mapped to standard QA pairs
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT CASE WHEN field_id != 'gestat' THEN concat(field_id, '-', source_code) ELSE field_id END AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value'
            WHEN to_value ~* 'unit' THEN 'Maps to unit'
           ELSE 'Maps to' END,
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_delivery_mapped
WHERE target_concept_id != 0
;

--Creating concepts for QA pairs
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT NULL,
       concat(dd.description, ': ', aa.meaning),
       'Observation',
       'UK Biobank',
       'Question-Answer pair',
       NULL,
       concat(dd.field, '-', aa.encoding_id, '-', aa.value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_hesdictionary dd
JOIN all_answers aa
ON aa.encoding_id::varchar = substring(data_coding, '[0-9].*')
WHERE field IN ('biresus', 'birordr', 'birstat', 'birweight', 'delmeth', 'delplac', 'delstat', 'sexbaby') --gestat not included -> only QA pairs
AND concat(dd.field, '-', aa.encoding_id, '-', aa.value) IN (SELECT concept_code_1 FROM concept_relationship_manual)
;


--+ UKB_cancer
--Question: Non-standard with mapping to 'history of clinical finding in subject'
--Answers: Standard or mapped to conditions
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = '20001' AND vocabulary_id = 'UK Biobank';

INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat('3-', source_code) AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_cancer_mapped
WHERE target_concept_id != 0

UNION

SELECT '20001' AS concept_code_1,
       '417662000' AS concept_code_2,
       'UK Biobank',
       'SNOMED',
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
;


--+ UKB_noncancer
--Question: Non-standard with mapping to 'history of clinical finding in subject'
--Answers: Standard or mapped to conditions
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = '20002' AND vocabulary_id = 'UK Biobank';

INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat('6-', source_code) AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_noncancer_mapped
WHERE target_concept_id != 0

UNION

SELECT '20002' AS concept_code_1,
       '417662000' AS concept_code_2,
       'UK Biobank',
       'SNOMED',
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
;

--TODO: Maybe non-standard answers?
--+ UKB_treatment_medication
--Question: Non-standard with mapping to 'history of drug therapy'
--Answers: Standard or mapped to drugs
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = '20003' AND vocabulary_id = 'UK Biobank';

INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat('4-', source_code) AS concept_code_1,
       concept_code AS concept_code_2,
       'UK Biobank',
       vocabulary_id,
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_treatment_medication_validated_mapping
WHERE concept_id != 0

UNION

SELECT '20003' AS concept_code_1,
       '428961000124106' AS concept_code_2,
       'UK Biobank',
       'SNOMED',
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
;



--TODO: Done till this point
--+ UKB_units
--Maps to unit relationships from tests to units
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT f.field_id AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       'Maps to unit',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.UKB_units_mapped m
JOIN sources.uk_biobank_field f
    ON f.units = m.source_code
WHERE target_concept_id != 0
AND target_concept_id != 32912 --General unit for indivisible things
;


--+ UKB_health_and_medical_history
--Mapped to standard QA pairs
INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT CASE WHEN flag != 'Q' THEN concat(field_id, '-', source_code) ELSE field_id END AS concept_code_1,  --Separated mapping for questions
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value'
           ELSE 'Maps to' END,
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_health_and_medical_history_mapped
WHERE target_concept_id != 0
;

--Creating concepts for QA pairs
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT NULL,
       concat(f.title, ': ', aa.meaning),
       'Observation',
       'UK Biobank',
       'Question-Answer pair',
       NULL,
       concat(f.field_id, '-', aa.encoding_id, '-', aa.value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_field f
JOIN all_answers aa
ON f.encoding_id = aa.encoding_id
WHERE main_category
IN (100041, 100046, 100042, 100037, 100038, 100048, 100039, 100040, 100047, 100044, 100045, 100043)
AND concat(f.field_id, '-', aa.encoding_id, '-', aa.value) IN (SELECT concept_code_1 FROM concept_relationship_manual)
;


--+ UKB_operations
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code = '20004' AND vocabulary_id = 'UK Biobank';

INSERT INTO concept_relationship_manual(concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT concat('5-', source_code) AS concept_code_1,
       target_concept_code AS concept_code_2,
       'UK Biobank',
       target_vocabulary_id,
       CASE WHEN to_value ~* 'value' THEN 'Maps to value' ELSE 'Maps to' END,
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM dev_oleg.ukb_operations_mapped
WHERE target_concept_id != 0

UNION

SELECT '20004' AS concept_code_1,
       '416940007' AS concept_code_2,
       'UK Biobank',
       'SNOMED',
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
;


--Creating concept relationships from Questions to Question - Answer pairs
INSERT INTO concept_relationship_stage(concept_id_1, concept_id_2, concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT NULL,
       NULL,
        f.field_id,
        cs.concept_code,
       'UK Biobank',
       'UK Biobank',
        'Has QA pair',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM sources.uk_biobank_field f
JOIN concept_stage cs
ON f.field_id::varchar = regexp_replace(cs.concept_code, '-.*$', '')
WHERE cs.concept_class_id = 'Question-Answer pair';

--Making concepts with mapping Non-standard
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_code IN (SELECT concept_code_1 FROM concept_relationship_manual WHERE relationship_id = 'Maps to');

--Making non-valid answers non-standard
UPDATE concept_stage
    SET standard_concept = NULL
WHERE concept_name IN ('Not known', 'Do not know', 'Do not know (group 2)', 'Do not know (group 1)', 'Reason not known', 'unknown', 'Unknown, cannot remember', 'Date uncertain or unknown',
                      'Not specified', 'Prefer not to answer', 'None of the above')
AND domain_id = 'Meas Value';

--Processing manual relationships from concept_relationship_manual to concept_relationship
SELECT vocabulary_pack.ProcessManualRelationships();

SELECT * FROM concept_relationship_manual;

--Drop temp table
DROP TABLE all_answers;
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
* Authors: Medical Team
* Date: 2020
   */
--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'NCIt',
	pVocabularyDate			=> TO_DATE ('20180101', 'yyyymmdd'),
	pVocabularyVersion		=> 'NCIt 2018-01-01',
	pVocabularyDevSchema	=> 'DEV_NCI'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--source code extaction for every version of AJCC book
CREATE TABLE AJCC_variables_draft WITH OIDS AS
    (
        with source as (
            SELECT distinct * -- выбираем все сущности, относящиеся к солидным опухолям,описыващие категории TNM
            from sources.mrconso a
            where sab = 'NCI'
              AND lower
                      (
                          str
                      ) ~* '.*\s[c,p]{1}[T,N,M]{1}[\d{1},X,is,insitu,in situ,a,b,c].*v[6,7,8]$'
        )
                ,
             version as
                 (
                     SELECT cui,
                            lat,
                            ts,
                            lui,
                            stt,
                            sui,
                            ispref,
                            aui,
                            saui,
                            scui,
                            sdui,
                            sab,
                            tty,
                            code,
                            str,
                            srl,
                            suppress,
                            cvf,
                            filler_column,
                            regexp_replace(
                                    array_to_string(
                                            regexp_matches
                                                (
                                                    str,
                                                    'v\d',
                                                    'g'
                                                ), '|'), '\D', '', 'g') as version
                     FROM source
                     WHERE tty = 'PT'
                 ),
             shemas_with_find as
                 (
                     SELECT distinct regexp_replace
                                         (
                                             str,
                                             '\s[c,p]{1}[T,N,M]{1}[\d{1},X,is,insitu,in situ,a,b,c].*v[6,7,8]$',
                                             '',
                                             'g'
                                         ) as replaced,
                                     version,
                                     str
                     FROM version
                 )
                ,
             preliminary_done as
                 (
                     SELECT replaced            as
                                                   schema,
                            version,
                            regexp_replace(
                                    str,
                                    'Finding v\d.*',
                                    concat
                                        (
                                            'Finding by ',
                                            'AJCC/UICC',
                                            ' ',
                                            version,
                                            'th',
                                            ' edition'
                                        ), 'g') as staging_finding,
                            concat
                                (
                                    replaced,
                                    ' by AJCC/UICC',
                                    ' ',
                                    version,
                                    'th',
                                    ' edition'
                                )               as versionized_schema
                     FROM shemas_with_find)
                ,
             alphaversion as
                 (
                     SELECT distinct schema,
                                     CASE
                                         WHEN schema =
                                                 'Head and Neck Cancer'
                                             then
                                             '5'
                                         WHEN
                                                 schema =
                                                 'Unknown Primary Tumor'
                                             then
                                             '6'
                                         WHEN
                                                 schema =
                                                 'Lip and Oral Cavity Cancer'
                                             then
                                             '7'
                                         WHEN
                                                 schema =
                                                 'Major Salivary Gland Cancer'
                                             then
                                             '8'
                                         WHEN
                                                 schema =
                                                 'Nasopharyngeal Cancer'
                                             then
                                             '9'
                                         WHEN
                                                 schema in (
                                                 'HPV-Mediated (p16-Positive) Oropharyngeal Cancer')
                                             then
                                             '10'
                                         WHEN
                                                 schema in
                                                 ('Oropharyngeal (p16-Negative) Cancer')
                                             then
                                             '11.1'
                                           WHEN
                                                 schema in
                                                 ( 'Hypopharyngeal Cancer')
                                             then
                                             '11.2'
                                         WHEN
                                                 schema
                                                 IN
                                                 (
                                                  'Nasal Cavity and Paranasal Sinuses Cancer'
                                                 )
                                             then '12'
                                         WHEN
                                                 schema
                                                 IN
                                                 (
                                                  'Nasal Cavity and Ethmoid Sinus Cancer'
                                                )
                                             then '12.2'
                                         WHEN
                                                 schema
                                                 IN
                                                 (
                                                  'Maxillary Sinus Cancer')
                                             then '12.1'
                                         WHEN schema IN ('Laryngeal Cancer') then '13'
                                            WHEN schema IN ('Supraglottic Cancer') then '13.1'
                                            WHEN schema IN ('Glottic Cancer') then '13.2'
                                            WHEN schema IN ('Subglottic Cancer') then '13.3'
                                         WHEN schema = 'Mucosal Melanoma of the Head and Neck' then '14'
                                         WHEN schema = 'Cutaneous Squamous Cell Carcinoma of the Head and Neck'
                                             then '15'
                                         WHEN schema = 'Esophagus and Esophagogastric Junction Cancer' then '16'
                                         WHEN schema = 'Gastric Cancer' then '17'
                                         WHEN schema = 'Small Intestine Cancer' then '18'
                                         WHEN schema in( 'Appendiceal Carcinoma','Low-Grade Appendiceal Mucinous Neoplasm (LAMN)') then '19'
                                         WHEN schema = 'Colorectal Cancer' then '20'
                                         WHEN schema = 'Anal Cancer' then '21'
                                         WHEN schema IN
                                              ('Liver Cancer',
                                               'Hepatocellular Carcinoma'
                                                  ) then '22'
                                         WHEN schema = 'Intrahepatic Bile Duct Cancer' then '23'
                                         WHEN schema = 'Gallbladder Cancer' then '24'
                                         WHEN schema = 'Perihilar Bile Duct Cancer' then '25'
                                         WHEN schema = 'Distal Bile Duct Cancer' then '26'
                                         WHEN schema = 'Ampulla of Vater Cancer' then '27'
                                         WHEN schema = 'Exocrine Pancreatic Cancer' then '28'
                                         WHEN schema = 'Gastric Neuroendocrine Tumor' then '29'
                                         WHEN schema = 'Duodenum and Ampulla of Vater Neuroendocrine Tumor' then '30'
                                         WHEN schema = 'Jejunum and Ileum Neuroendocrine Tumor' then '31'
                                         WHEN schema iN
                                              (
                                               'Appendix Neuroendocrine Tumor',
                                               'Appendiceal Carcinoid'
                                                  ) then '32'
                                         WHEN schema IN
                                              (
                                               'Colon or Rectum Neuroendocrine Tumor',
                                               'Colorectal Neuroendocrine Tumor'
                                                  )
                                             then '33' -- 33 is only for Neuroendocrine Tumors of the Colon and Rectum , Colon or Rectum Neuroendocrine Tumo is 7th editin chapter
                                         WHEN schema = 'Pancreatic Neuroendocrine Tumor' then '34'
                                         WHEN schema = 'Thymic Tumor' then '35'
                                         WHEN schema = 'Lung Cancer' then '36'
                                         WHEN schema IN
                                              (
                                               'Pleural Mesothelioma',
                                               'Pleural Malignant Mesothelioma'
                                                  ) then '37' -- Pleural Malignant Mesothelioma is 8th
                                         WHEN schema IN ('Bone Cancer')
                                             then '38'
                                         WHEN schema IN (
                                                         'Appendicular Skeleton, Trunk, Skull, and Facial Bones Cancer')
                                             then '38.1'
                                           WHEN
                                                 schema =
                                                 'Spine Cancer'
                                             then
                                             '38.2'
                                         WHEN schema IN ('Pelvis Cancer')
                                             then '38.3'

                                         WHEN schema = 'Soft Tissue Sarcoma of the Head and Neck' then '40'
                                         WHEN schema = 'Soft Tissue Sarcoma of the Trunk and Extremities' then '41'
                                         WHEN schema = 'Soft Tissue Sarcoma of the Abdomen and Thoracic Visceral Organs'
                                             then '42'
                                         WHEN schema = 'Gastrointestinal Stromal Tumor' then '43'
                                         WHEN schema = 'Soft Tissue Sarcoma of the Retroperitoneum' then '44'
                                         WHEN schema = 'Soft Tissue Sarcoma'
                                             then '45' -- poor the exact schema is not 8th edition
                                         WHEN schema = 'Merkel Cell Carcinoma' then '46'
                                         WHEN schema = 'Cutaneous Melanoma' then '47'
                                         WHEN schema = 'Breast Cancer' then '48'
                                         WHEN schema = 'Vulvar Cancer' then '50'
                                         WHEN schema = 'Vaginal Cancer' then '51'
                                         WHEN schema = 'Cervical Cancer' then '52'
                                         WHEN schema IN
                                              (
                                               'Uterine Corpus Carcinoma',
                                               'Uterine Corpus Cancer',
                                               'Uterine Corpus Carcinoma and Carcinosarcoma'
                                                  ) then '53'
                                         WHEN schema IN
                                              (
                                               'Uterine Corpus Adenosarcoma'
                                                  ) then '54.2'
                                         WHEN schema IN
                                              (
                                               'Uterine Corpus Leiomyosarcoma and Endometrial Stromal Sarcoma'
                                                  ) then '54.1'
                                         WHEN schema IN
                                              (
                                               'Ovarian Cancer',
                                               'Ovarian Cancer and Primary Peritoneal Carcinoma',
                                               'Ovarian, Fallopian Tube, and Primary Peritoneal Carcinoma'
                                                  ) then '55'
                                         WHEN schema IN
                                              (
                                               'Gestational Trophoblastic Tumor',
                                               'Gestational Trophoblastic Neoplasm'
                                                  ) then '56'
                                         WHEN schema = 'Penile Cancer' then '57'
                                         WHEN schema IN
                                              (
                                               'Prostate Cancer',
                                               'Urothelial (Transitional Cell) Carcinoma of the Prostate'
                                                  ) then '58'
                                         WHEN schema = 'Testicular Cancer' then '59'
                                         WHEN schema = 'Kidney Cancer' then '60'
                                         WHEN schema = 'Renal Pelvis and Ureter Cancer' then '61'
                                         WHEN schema = 'Bladder Cancer' then '62'
                                         WHEN schema IN
                                              (
                                               'Urethral Cancer'
                                                  ) then '63'
                                         WHEN schema IN
                                              (
                                               'Male Penile Urethra and Female Urethra Cancer'
                                                  ) then '63.1'
                                         WHEN schema IN
                                              (
                                               'Prostatic Urethra Cancer'
                                                  ) then '63.3'
                                         WHEN schema IN
                                              (
                                               'Carcinoma of the Eyelid',
                                               'Eyelid Carcinoma'
                                                  ) then '64'
                                         WHEN schema IN
                                              (
                                               'Carcinoma of the Conjunctiva',
                                               'Conjunctival Carcinoma'
                                                  ) then '65'
                                         WHEN schema IN
                                              (
                                               'Melanoma of the Conjunctiva',
                                               'Conjunctival Melanoma'
                                                  ) then '66'
                                            WHEN schema IN
                                              (
                                               'Uveal Melanoma',
                                               'Melanoma of the Uvea'
                                                  ) then '67'
                                            WHEN schema IN
                                              (

                                               'Choroidal and Ciliary Body Melanoma',
                                               'Melanoma of the Ciliary Body and Choroid'

                                                  ) then '67.2'
                                            WHEN schema IN
                                              (
                                               'Iris Melanoma',
                                               'Melanoma of the Iris'

                                                  ) then '67.1'
                                            WHEN schema IN
                                              (
                                               'Uveal Melanoma',
                                               'Iris Melanoma',
                                               'Choroidal and Ciliary Body Melanoma',
                                               'Melanoma of the Ciliary Body and Choroid',
                                               'Melanoma of the Iris',
                                               'Melanoma of the Uvea'
                                                  ) then '67'
                                         WHEN schema IN
                                              (
                                                  'Retinoblastoma'
                                                  ) then '68'
                                         WHEN schema IN
                                              (
                                               'Carcinoma of the Lacrimal Gland',
                                               'Lacrimal Gland Carcinoma'
                                                  ) then '69'
                                         WHEN schema IN
                                              (
                                               'Sarcoma of the Orbit',
                                               'Orbital Sarcoma'
                                                  ) then '70'
                                         WHEN schema IN
                                              (
                                                  'Ocular Adnexal Lymphoma'
                                                  ) then '71'


                                         WHEN schema IN
                                              (
                                                  'Papillary, Follicular, Hurthle Cell, Poorly Differentiated, and Anaplastic Thyroid Carcinoma'
                                                  ) then '73'
                                         WHEN schema IN
                                              (
                                                  'Medullary Thyroid Carcinoma'
                                                  ) then '74'
                                         WHEN schema IN
                                              (
                                                  'Parathyroid Carcinoma'
                                                  ) then '75'
                                         WHEN schema IN
                                              (
                                                  'Adrenal Cortical Carcinoma'
                                                  ) then '76'
                                         WHEN schema IN
                                              (
                                               'Pheochromocytoma and Paraganglioma',
                                               'Pheochromocytoma'
                                                  ) then '77'
                                         ELSE 'not_selected' END as schema_chapter_code,
                                     split_part
                                         (
                                             staging_finding,
                                             ' TNM',
                                             1
                                         )                       as stage_without_version,
                                     version,
                                     staging_finding,
                                     versionized_schema
                     FROM preliminary_done
                 )
                ,
             alpha2ver as
                 (
                     SELECT schema,
                            schema_chapter_code,
                            alphaversion
                                .
                                stage_without_version,
                            version,
                            staging_finding,
                            versionized_schema,
                            CASE
                                WHEN
                                        stage_without_version
                                        IN
                                        ( 'Urothelial (Transitional Cell) Carcinoma of the Prostate pTis pd',
                                         'Urothelial (Transitional Cell) Carcinoma of the Prostate pTis pu'
                                            ) then 'pTis'
                                WHEN stage_without_version = 'Melanoma of the Conjunctiva cN0a (Biopsy)' then 'cN0a'
                                WHEN stage_without_version IN  ( 'Breast Cancer pTis (Paget)','Breast Cancer pTis Paget') then 'pTis (Paget)'
                                WHEN stage_without_version = 'Breast Cancer pTis (DCIS)' then 'pTis (DCIS)'
                                WHEN stage_without_version = 'Breast Cancer pTis (LCIS)' then 'pTis (LCIS)'
                                WHEN stage_without_version = 'Low-Grade Appendiceal Mucinous Neoplasm (LAMN) pTis' then 'pTis (LAMN)'
                                WHEN stage_without_version = 'Melanoma of the Conjunctiva cN0b (No Biopsy)' then 'cN0b'
                                WHEN stage_without_version = 'Thyroid Cancer pT4a Anaplastic Carcinoma' then 'pT4a'
                                WHEN stage_without_version = 'Thyroid Cancer pT4b Anaplastic Carcinoma' then 'pT4b'
                                ELSE
                                    (
                                        regexp_split_to_array
                                            (
                                                stage_without_version,
                                                ' '
                                            ))[array_upper
                                        (
                                            regexp_split_to_array
                                                (
                                                    stage_without_version,
                                                    ' '
                                                ), 1)] END as short_category
                     FROm alphaversion
                 )
        SELECT schema,

               schema_chapter_code,
               versionized_schema,
               CASE
                   WHEN schema_chapter_code = 'not_selected' THEN concat
                       (
                           regexp_replace
                               (
                                   schema,
                                   '\s|[[:punct:]]',
                                   '',
                                   'g'
                               ), '-', version)
                   ELSE concat
                       (
                           schema_chapter_code,
                           '-',
                           version
                       ) END          as versionized_schema_chapter_code,
               stage_without_version,
               CASE
                   WHEN schema_chapter_code = 'not_selected' THEN concat
                       (short_category, '-',
                        regexp_replace
                            (
                                schema,
                                '\s|[[:punct:]]',
                                '',
                                'g'
                            ))
                   ELSE concat
                       (short_category,
                        '-',
                        schema_chapter_code
                       ) END          as stage_without_version_code,
               version                as ajcc_version,
               staging_finding,
               CASE
                   WHEN schema_chapter_code = 'not_selected' THEN concat
                       (short_category,
                       '-', regexp_replace
                            (
                                schema,
                                '\s|[[:punct:]]',
                                '',
                                'g'
                            ), '-', version)
                   ELSE concat
                       (
                           short_category,
                           '-',
                           schema_chapter_code,
                           '-',
                           version
                       ) END          as staging_finding_code,
               CASE
                   WHEN schema_chapter_code = 'not_selected' THEN length
                       (concat(
                                   regexp_replace
                                       (
                                           schema,
                                           '\s|[[:punct:]]',
                                           '',
                                           'g'
                                       ), '-', short_category, '-', version))
                   ELSE length
                       (
                           concat
                               (
                                   short_category,
                                   '-', schema_chapter_code,
                                   '-',
                                   version
                               )) END as length_staging_finding_code,
               short_category
        FROM alpha2ver
    )
;



--4 Insert into concept_stage
INSERT INTO concept_stage (
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
with staging_finding as (SELECT distinct staging_finding_code as concept_code,
                                             staging_finding      as concept_name,
                                             'AJCC Category'   as concept_class,
                                             'Measurement' as domain_id,
                                             'NCIt'            as vocabulary_id,
                                             NULL           as standard_concept,
                                             TO_DATE('20180101', 'yyyymmdd')         as valid_start_date,
                                             '2099-12-31'::date   as valid_end_date,
                                             NULL                 as invalid_reason
                             FROM  AJCC_variables_draft
                             WHERE ajcc_version = '8')
            ,
         chapter as (SELECT distinct versionized_schema_chapter_code as concept_code,
                                     CASE
                                         WHEN versionized_schema_chapter_code = '19-8'
                                             THEN 'Appendiceal Carcinoma by AJCC/UICC 8th edition'
                                         WHEN versionized_schema_chapter_code = '77-8'
                                             THEN 'Pheochromocytoma and Paraganglioma by AJCC/UICC 8th edition'
                                         ELSE versionized_schema END as concept_name,
                                     'AJCC Chapter'              as concept_class,
                                     'Measurement'                   as domain_id,
                                     'NCIt'                       as vocabulary_id,
                                     NULL                            as standard_concept,
                                     TO_DATE('20180101', 'yyyymmdd')                    as valid_start_date,
                                     '2099-12-31'::date              as valid_end_date,
                                     NULL                            as invalid_reason
                     FROM  AJCC_variables_draft
                     WHERE ajcc_version = '8')
SELECT
     concept_name,
	domain_id,
	vocabulary_id,
	concept_class,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM  chapter WHERE concept_code IN (SELECT concept_code FROM chapter group by 1 having count(distinct concept_name)=1)
UNION ALL
    SELECT   concept_name,
	domain_id,
	vocabulary_id,
	concept_class,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
    FROM staging_finding
    WHERE concept_code IN (SELECT concept_code FROM staging_finding group by 1 having count(distinct concept_name) = 1);

ANALYZE concept_stage;


--5 Insert into concept_relationship_stage
--5.1 Category in Chapter relationship creation
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT null as concept_id_1,
       null as concept_id_2,
       staging_finding_code as concept_code_1,
       versionized_schema_chapter_code as concept_code_2,
       'NCIt' as vocabulary_id_1,
              'NCIt' as vocabulary_id_2,
       'Category in Chapter' as relationship_id,
             TO_DATE('20180101', 'yyyymmdd') as valid_start_date,
                '2099-12-31'::date as valid_end_date,
                NULL as invalid_reason
FROM  AJCC_variables_draft
WHERE ajcc_version='8'
;

--5.2.0 Provisional table with chapter_to_icdo3_conditions;
-- NOT PERFECT solution due to random linkage of Category to Conditin by this approach ( eg; In Situ carcinoma in condition may have permissible attributes fro invasive cancer)
CREATE TABLE chapter_to_icdo3_conditions AS (
    WITH concept_stage_1 as (SELECT *,
                                    concept_code                                  as ajcc_chapter_code,
                                    CASE
                                        WHEN concept_code like '%.%' then split_part(concept_code, '.', 1)
                                        ELSE split_part(concept_code, '-', 1) end as chapter_code
                             FROM concept_stage
                             where concept_class_id = 'AJCC Chapter'),
         permissible_pairs AS (SELECT m.chaptercode, m.chapterdescription, m.morphocode, t.topocode
                               FROM dev_nci.ajcc8_permissible_chapter_to_morphocode m
                                        JOIN dev_nci.ajcc8_permissible_chapter_to_topocode t
                                             ON m.ChapterCode = t.ChapterCode),
         primary_combos as (
             SELECT ChapterCode,
                    chapterdescription,
                    concat(concat(regexp_replace(morphocode, '\*', '', 'g'), '/1'), '-',
                           regexp_replace(topocode, '\*', '', 'g')) as condcode
             FROM permissible_pairs --bordreline
             UNION ALL
             SELECT ChapterCode,
                    chapterdescription,
                    concat(concat(regexp_replace(morphocode, '\*', '', 'g'), '/2'), '-',
                           regexp_replace(topocode, '\*', '', 'g')) as condcode
             FROM permissible_pairs --insitu
             UNION ALL
             SELECT ChapterCode,
                    chapterdescription,
                    concat(concat(regexp_replace(morphocode, '\*', '', 'g'), '/3'), '-',
                           regexp_replace(topocode, '\*', '', 'g')) as condcode
             FROM permissible_pairs --malignant
         )
    SELECT distinct NULL               as concept_id_1,
                    c.concept_id       as concept_id_2,
                    cs.concept_code    as concept_code_1,
                    c.concept_code     as concept_code_2,
                    cs.vocabulary_id   as vocabulary_id_1,
                    c.vocabulary_id    as vocabulary_id_2,
                    'Chapter to ICDO'      as relationship_id,
                    NULL               AS invalid_reason,
                    current_date       as valid_start_date,
                    '2099-12-31'::date as valid_end_date
    FROM concept_stage_1 cs
             JOIN primary_combos pc
                  ON cs.chapter_code = pc.ChapterCode
             JOIN devv5.concept c
                  ON pc.condcode = c.concept_code
                      AND c.concept_class_id = 'ICDO Condition'
                      AND c.invalid_reason IS NULL
)
;
--5.2.1
--chapter to ICD0 CRS
INSERT INTO concept_relationship_stage (
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT  -- id_of NCIt chapter
       concept_id_2, -- id of ICD03 cond
       concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
         invalid_reason
FROM chapter_to_icdo3_conditions
;

--6. Add manual source
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--7. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--8. Add mapping from deprecated to fresh concepts (necessary for the next step)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

DROP TABLE AJCC_variables_draft;
DROP TABLE chapter_to_icdo3_conditions;



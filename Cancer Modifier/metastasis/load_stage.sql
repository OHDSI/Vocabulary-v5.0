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
* Authors: Medical team
* Date: 2021
**************************************************************************/

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'Cancer Modifier',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'Cancer Modifier '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'DEV_CANCER_MODIFIER'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3.1 CS Insert of Full Name Equivalence between SNOMED and CM Metastasis
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
SELECT distinct
                c.concept_id,
                c.concept_name,
                c.domain_id,
                c.vocabulary_id,
                c.concept_class_id,
                c.standard_concept,
                c.concept_code,
                c.valid_start_date,
                c.valid_end_date,
                c.invalid_reason
FROM concept c
JOIN concept_relationship cr
ON concept_id=cr.concept_id_1
AND  vocabulary_id='Cancer Modifier'
and  concept_class_id = 'Metastasis'
JOIN  concept cc
on cr.concept_id_2=cc.concept_id
and cc.vocabulary_id='SNOMED'
WHERE lower(regexp_replace(cc.concept_name,'Secondary malignant neoplasm of','Metastasis to the','g'))=lower(c.concept_name)
;

--3.2 CS Insert of non-Full Name Equivalence between SNOMED and CM Metastasis
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
SELECT distinct
                c.concept_id,
           CASE WHEN      c.concept_name ilike '%ofe' then regexp_replace(regexp_replace(regexp_replace(c.concept_name,'Secondary malignant neoplasm of','Metastasis to the','g'),'ofe','Nose','g'),' NOS$','','g') else regexp_replace(c.concept_name,'Secondary malignant neoplasm of','Metastasis to the','g') end as concept_name,
                c.domain_id,
                c.vocabulary_id,
                c.concept_class_id,
                c.standard_concept,
                c.concept_code,
                c.valid_start_date,
                c.valid_end_date,
                c.invalid_reason
FROM concept c
JOIN concept_relationship cr
ON concept_id=cr.concept_id_1
AND  vocabulary_id='Cancer Modifier'
and  concept_class_id = 'Metastasis'
JOIN  concept cc
on cr.concept_id_2=cc.concept_id
and cc.vocabulary_id='SNOMED'
WHERE lower(regexp_replace(cc.concept_name,'Secondary malignant neoplasm of','Metastasis to the','g'))<>lower(c.concept_name)
AND c.concept_id  NOT IN (
    SELECT concept_id from concept_stage
    )
;

--3.3 CS Insert of CM Metastasis Codes not existing in SNOMED
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
SELECT distinct
                c.concept_id,
                 CASE WHEN      c.concept_name ilike '%ofe' then regexp_replace(regexp_replace(c.concept_name,'Secondary malignant neoplasm of','Metastasis to the','g'),'ofe','Nose','g') else regexp_replace(c.concept_name,'Secondary malignant neoplasm of','Metastasis to the','g') end as concept_name,
                c.domain_id,
                c.vocabulary_id,
                c.concept_class_id,
                c.standard_concept,
                c.concept_code,
                c.valid_start_date,
                c.valid_end_date,
                c.invalid_reason
FROM concept c
WHERE  vocabulary_id='Cancer Modifier'
and  concept_class_id = 'Metastasis'
/* AND c.concept_id  NOT IN (
    SELECT concept_id from concept_stage
    )*/
  --LIST OF CODES TO BE DEPRECATED AS DUPLICATES and REMAPPED
AND c.concept_id NOT IN (
                                          35225652, --Metastasis to the Mammary Gland maps to 35225556 Metastasis to the Breast
                                          36769181,-- Metastases Maps TO 36769180 Metastasis
                                          36768964,--	Distant Metastasis Maps TO 36769180 Metastasis
                                          35226153,	--  Metastasis to the Genital Organs Maps to 35226152	Metastasis to the Genital Organs
                                          36769170,	--Non-Malignant Ascites Maps to 200528	389026000	Ascites
                                          36769789, --	Non-malignant Pleural Effusion Maps to 254061	60046008	Pleural effusion
                                          36769415,	--Pleural Effusion Maps to 254061	60046008	Pleural effusion
                                          36768514, -- 	Suspicious Ascites Maps to 200528	389026000	Ascites
                                          36768818,--	Ascites Maps to 200528	389026000	Ascites
                                           36770091-- Metastasis to the Contralateral Lobe LOBE OF WHAT???

    )
;

--CRS insert of Anatomic Sites
SELECT distinct
                cs.concept_id as concept_id_1,
                cs.concept_code as concept_concept_code_1,
                cs.concept_name as concept_concept_name_1,
                cs.vocabulary_id as concept_vocabulary_id_1,
                'Has finding site' as relationship_id,
                NULL as invalid_reason,
                c2.concept_id  as concept_concept_id_2,
                c2.concept_name  as concept_concept_name_2,
                c2.concept_code as concept_concept_code_2,
                c2.vocabulary_id as concept_vocabulary_id_2
FROM concept_stage cs
JOIN concept_relationship cr on cs.concept_id = cr.concept_id_1
JOIN concept c
on cr.concept_id_2=c.concept_id
and c.vocabulary_id='SNOMED'
JOIN concept_relationship cr2 on c.concept_id = cr2.concept_id_1
JOIN concept c2
on c2.concept_id=cr2.concept_id_2
and c2.concept_class_id= 'Body Structure'
and cr2.invalid_reason is null
;


--obvious SNOMED codes to be used as Metastasis
with obviuos_snomed_mts as (
    SELECT distinct
                    c2.concept_name as site_name,
                    c2.concept_id as site_id,
                    cc.concept_id,
                    cc.concept_name,
                    cc.domain_id,
                    cc.vocabulary_id,
                    cc.concept_class_id,
                    cc.standard_concept,
                    cc.concept_code,
                    cc.valid_start_date,
                    cc.valid_end_date,
                    cc.invalid_reason
    FROM concept cc
             JOIN concept_relationship cr
                  on cc.concept_id = cr.concept_id_1
                      and cc.vocabulary_id = 'SNOMED'
             JOIN concept c
                  on c.concept_id = cr.concept_id_2
                      and c.concept_id = 4032806 -- Neoplasm, metastatic
             JOIN concept_relationship cr1
                  on cr1.concept_id_1 = cc.concept_id
             JOIN concept c2
                  on cr1.concept_id_2 = c2.concept_id
                      and cr1.invalid_reason is null
                      AND c2.concept_class_id = 'Body Structure'
    WHERE cc.concept_id NOT IN
          (
              SELECT distinct cc.concept_id
              FROM concept c
                       JOIN concept_relationship cr
                            ON concept_id = cr.concept_id_1
                                AND vocabulary_id = 'Cancer Modifier'
                                and concept_class_id = 'Metastasis'
                       JOIN concept cc
                            on cr.concept_id_2 = cc.concept_id
                                and cc.vocabulary_id = 'SNOMED'
          )
      and cc.domain_id = 'Condition'
      and cc.standard_concept = 'S'
      AND cc.concept_id NOT IN
          (
              SELECT distinct cc.concept_id
              FROM concept cc
                       JOIN concept_relationship cr
                            on cc.concept_id = cr.concept_id_1
                                and cc.vocabulary_id = 'SNOMED'
                       JOIN concept c
                            on c.concept_id = cr.concept_id_2
                                and c.concept_id = 4032806 -- Neoplasm, metastatic
                       JOIN concept_relationship cr1
                            on cr1.concept_id_1 = cc.concept_id
                       JOIN concept c2
                            on cr1.concept_id_2 = c2.concept_id
                                and cr1.invalid_reason is null
                                AND c2.concept_class_id = 'Body Structure'
              WHERE (cc.concept_id, 'Has asso morph') NOT IN -- TO exclude codes with definitve information about both primary+spread site
                    (
                        SELECT distinct cc.concept_id,
                                        cr.relationship_id
                        FROM concept c
                                 JOIN concept_relationship cr
                                      ON concept_id = cr.concept_id_1
                                          AND vocabulary_id = 'Cancer Modifier'
                                          and concept_class_id = 'Metastasis'
                                 JOIN concept cc
                                      on cr.concept_id_2 = cc.concept_id
                                          and cc.vocabulary_id = 'SNOMED'
                    )
                and cc.domain_id = 'Condition'
                and cc.standard_concept = 'S'
                and cr.relationship_id = 'Has asso morph'
              group by 1
              having count(*) > 1
          )
      AND cc.concept_name not ilike '%Metastatic%' -- as they are Both describes Primary Site and Site of Spread (SNOMED treats it with LOGIC GROUPS)
      AND cc.concept_name not ilike '%lymph node%' -- they have to be LN Concept Class
      and c2.concept_name not ilike '%lymph node%' -- they have to be LN Concept Class)
      AND cc.concept_name not ilike '%Leukemic%'   -- likely Primaries Neither than Metastasis
      AND cc.concept_name not ilike '%Lymphoma%'   -- likely Primaries Neither than Metastasis
      AND cc.concept_name not ilike '%by direct%'  -- the are Invasions more likely
      AND cc.concept_name not ilike '%underlying%' -- the are Invasions more likely
)
,
crs as
    (
        SELECT distinct
                cs.concept_id as concept_id_1,
                cs.concept_code as concept_concept_code_1,
                cs.concept_name as concept_concept_name_1,
                cs.vocabulary_id as concept_vocabulary_id_1,
                'Has finding site' as relationship_id,
                NULL as invalid_reason,
                c2.concept_id  as concept_concept_id_2,
                c2.concept_name  as concept_concept_name_2,
                c2.concept_code as concept_concept_code_2,
                c2.vocabulary_id as concept_vocabulary_id_2
FROM concept_stage cs
JOIN concept_relationship cr on cs.concept_id = cr.concept_id_1
JOIN concept c
on cr.concept_id_2=c.concept_id
and c.vocabulary_id='SNOMED'
JOIN concept_relationship cr2 on c.concept_id = cr2.concept_id_1
JOIN concept c2
on c2.concept_id=cr2.concept_id_2
and c2.concept_class_id= 'Body Structure'
and cr2.invalid_reason is null
    )
    ,
similarity as (
SELECT
       devv5.similarity(concept_name,concept_concept_name_1) as similarity,
    concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    concept_id_1 as concept_id_2,
    concept_concept_code_1 as concept_concept_code_2,
    concept_concept_name_1 as concept_concept_name_2,
    concept_vocabulary_id_1  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is not null)

, similarity_result as (
SELECT     row_number() OVER (PARTITION BY concept_concept_id_1 ORDER BY similarity DESC)  AS rating_in_section,

       concept_concept_id_1,
       concept_code_1,
       concept_concept_name_1,
       concept_vocabulary_id_1,
       invalid_reason,
       relationship_id,
       concept_id_2,
       concept_concept_code_2,
       concept_concept_name_2,
       concept_vocabulary_id_2
FROM similarity)
SELECT
       concept_concept_id_1,
       concept_code_1,
       concept_concept_name_1,
       concept_vocabulary_id_1,
       invalid_reason,
       relationship_id,
       concept_id_2,
       concept_concept_code_2,
       concept_concept_name_2,
       concept_vocabulary_id_2
FROM similarity_result
where CASE WHEN concept_code_1 = '285634003' then rating_in_section=3 else rating_in_section=1 end

UNION ALL

SELECT
    concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    36768130 as concept_id_2,
    'OMOP4997805' as concept_concept_code_2,
    'Generalized Metastases' as concept_concept_name_2,
    'Cancer Modifier'  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name ilike '%Carcinomatosis%'
or concept_name ilike '%Disseminated%')

UNION ALL

SELECT
     concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    concept_id_1 as concept_id_2,
    concept_concept_code_1 as concept_concept_code_2,
    concept_concept_name_1 as concept_concept_name_2,
    concept_vocabulary_id_1  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name not ilike '%Carcinomatosis%'
and concept_name not ilike '%Disseminated%')
;

SELECT *
FROM concept_stage


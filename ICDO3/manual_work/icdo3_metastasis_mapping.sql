--Interim Table with Mappings
DROP TABLE icdo3_to_cm_metastasis;
--ICDO3 /6 codes mappings to Cancer Modifier
CREATE TABLE icdo3_to_cm_metastasis as
WITH getherd_mts_codes as (
     --aggregate the source
    SELECT DISTINCT
                          concept_name,
                          concept_code,
                          split_part(concept_code,'-',2) as tumor_site_code,
                          vocabulary_id
          FROM concept_stage c
         WHERE c.vocabulary_id = 'ICDO3'
           and c.concept_class_id = 'ICDO Condition'
           and c.concept_code ILIKE '%/6%'
)

   , tabb as (SELECT distinct
                              tumor_site_code,
                              s.vocabulary_id,
                              cc.concept_id    as snomed_id,
                              cc.concept_name  as snomed_name,
                              cc.vocabulary_id as snomed_voc,
                              cc.concept_code  as snomed_code
              FROM getherd_mts_codes s
                       LEFT JOIN concept c
                                 ON s.tumor_site_code = c.concept_code
                                     and c.concept_class_id = 'ICDO Topography'
                       LEFT JOIN concept_relationship cr
                                 ON c.concept_id = cr.concept_id_1
                                     and cr.invalid_reason is null
                                     and cr.relationship_id = 'Maps to'
                       LEFT JOIN concept cc
                                 on cr.concept_id_2 = cc.concept_id
                                     and cr.invalid_reason is null
                                     and cc.standard_concept = 'S'
)
,
tabbc as (SELECT tumor_site_code,
                 tabb.vocabulary_id as icd_voc,
                 snomed_id,
                 snomed_name,
                 snomed_voc,
                 snomed_code,
                 concept_id,
                 concept_name,
                 domain_id,
                 c.vocabulary_id,
                 concept_class_id,
                 standard_concept,
                 concept_code,
                 c.valid_start_date,
                 c.valid_end_date,
                 c.invalid_reason

          FROM TABB -- table with SITEtoSNOMED mappngs
JOIN concept_relationship cr
ON tabb.snomed_id=cr.concept_id_1
JOIN concept c
ON c.concept_id=cr.concept_id_2
and c.concept_class_id='Metastasis')
,
similarity_tab as (
SELECT distinct
            CASE WHEN tumor_site_code=   'C38.4' then row_number() OVER (PARTITION BY tumor_site_code ORDER BY devv5.similarity(snomed_name,concept_name) asc)  else row_number() OVER (PARTITION BY tumor_site_code ORDER BY devv5.similarity(snomed_name,concept_name) desc)  end as similarity,
                tumor_site_code,
                icd_voc,
                snomed_id,
                snomed_name,
                snomed_voc,
                snomed_code,
                concept_id,
                concept_name,
                domain_id,
                tabbc.vocabulary_id,
                concept_class_id,
                standard_concept,
                concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM tabbc)

SELECT distinct
                a.concept_name as icd_name,
                a.concept_code as icd_code,
                a.tumor_site_code,
                a.vocabulary_id as icd_vocab,
                concept_id,
                s.concept_code,
                s.concept_name,
                s.vocabulary_id
FROM
similarity_tab s
JOIN getherd_mts_codes a
ON s.tumor_site_code=a.tumor_site_code
where similarity=1
;

--Assumption MTS
INSERT INTO icdo3_to_cm_metastasis
(icd_name,
 icd_code,
 tumor_site_code,
 icd_vocab,
 concept_id,
 concept_code,
 concept_name,
 vocabulary_id)
SELECT distinct
                s.concept_name as icd_name,
                s.concept_code as icd_code,
              split_part(s.concept_code,'-',2) as tumor_site_code,
                icd_code,
               m. concept_id,
               m.concept_code,
                m.concept_name,
                m.vocabulary_id
FROM concept_stage s
JOIN icdo3_to_cm_metastasis  m
on split_part(split_part(s.concept_code,'-',2),'.',1)||'.9'=m.tumor_site_code
WHERE s.concept_code not in (select icd_code from icdo3_to_cm_metastasis);

-- Pathologically confirmed metastasis
INSERT INTO icdo3_to_cm_metastasis
(icd_name,
 icd_code,
 tumor_site_code,
 icd_vocab,
 concept_id,
 concept_code,
 concept_name,
 vocabulary_id)
SELECT distinct s.concept_name as icd_name,
                s.concept_code as icd_code,
                   split_part(s.concept_code,'-',2),
                s.vocabulary_id as icd_vocab,
               c. concept_id,
               c.concept_code,
                c.concept_name,
                c.vocabulary_id
FROM concept_stage s,concept  c
WHERE c.concept_code = 'OMOP4998770'
and c.vocabulary_id ='Cancer Modifier'
and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
and    split_part(s.concept_code,'-',2) IN ('NULL','C80.9','C76.7')
;

--Assumption that the codes represent CTC
INSERT INTO icdo3_to_cm_metastasis
(icd_name,
 icd_code,
 tumor_site_code,
 icd_vocab,
 concept_id,
 concept_code,
 concept_name,
 vocabulary_id)
SELECT distinct s.concept_name as icd_name,
                s.concept_code as icd_code,
               split_part(s.concept_code,'-',2),
                s.vocabulary_id as icd_vocab,
               c. concept_id,
               c.concept_code,
                c.concept_name,
                c.vocabulary_id
FROM concept_stage s, concept  c
WHERE c.concept_code = 'OMOP4999341'
and c.vocabulary_id ='Cancer Modifier'
and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
and    split_part(s.concept_code,'-',2) ='C42.0'
;

--Hardcoded values (mostly LN stations)
INSERT INTO icdo3_to_cm_metastasis
(icd_name,
 icd_code,
 tumor_site_code,
 icd_vocab,
 concept_id,
 concept_code,
 concept_name,
 vocabulary_id)
SELECT icd_name,
       icd_code,
       tumor_site_code,
       icd_vocab,
       concept_id,
       concept_code,
       concept_name,
       vocabulary_id
FROM (
         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                       split_part(s.concept_code,'-',2) as tumor_site_code,
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP5031980'
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C40.0', 'C47.1')

         UNION ALL

                    SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP5031483'--	Metastasis to the Anal Canal
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C21')
         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP5031707'
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) = 'C40.2'

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
            concept  c
         WHERE c.concept_code = 'OMOP5031839'--	Metastasis to the Retroperitoneum And Peritoneum'
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) = 'C48.8'

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP5031916'--	Metastasis to the Soft Tissues
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) = 'C49.9'

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP5031618'--	Metastasis to the Female Genital Organ
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C57', 'C57.7')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
            concept  c
         WHERE c.concept_code = 'OMOP5031819'--	Metastasis to the Prostate
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C61.9')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP5031716'--	Metastasis to the Male Genital Organ
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C63')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP5117515'--	Metastasis to meninges NEW CONCEPT
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C70', 'C70.9')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP5117516'--	Metastasis to abdomen --new concept
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C76.2')


         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
          concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
            concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77.0')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77.1')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
          concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77.2')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77.2')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
            concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77.3')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
           concept  c
         WHERE c.concept_code = 'OMOP5000384'--	Inguinal Lymph Nodes
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77.4')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP4999638'--	Pelvic Lymph Nodes
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77.5')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
           concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)
           and split_part(s.concept_code,'-',2) in ('C77.9')
     ) as  map
where   icd_code not in (select icd_code from icdo3_to_cm_metastasis)
;

--Check Evth is Mapped
SELECT count(*)
FROM concept_stage
where   concept_code not in (select icd_code from icdo3_to_cm_metastasis)
;

--Insert into Concept_manual
INSERT INTO concept_relationship_manual
(concept_code_1,
 concept_code_2,
 vocabulary_id_1,
 vocabulary_id_2,
 relationship_id,
 valid_start_date,
 valid_end_date,
 invalid_reason)

SELECT distinct
       icd_code as concept_code_1 ,
       concept_code as concept_code_2,
       icd_vocab as vocabulary_id_1,
      vocabulary_id as vocabulary_id_2,
                                  'Maps to'     relationship_id,
                CURRENT_DATE as valid_start_date,
                    TO_DATE('20991231', 'yyyymmdd')  as valid_end_date

FROM icdo3_to_cm_metastasis
;
--CleanUp
DROP TABLE icdo3_to_cm_metastasis;




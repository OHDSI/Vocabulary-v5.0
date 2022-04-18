-- The scripot was used only ones to initially create the scope for clean Stagin/Gradings
--All subsequent work - is manual/semi-automated.
drop table stage_attribute_concept_stage;
CREATE TABLE stage_attribute_concept_stage
(
    cui       varchar(255),
    name      varchar(512),
    attribute varchar(55)
)
;
drop table stage_attribute_relationship_stage
CREATE TABLE stage_attribute_relationship_stage
(
    cui1         varchar(255),
    name1        varchar(512),
    attribute1   varchar(55),
    relationship varchar(255),
    cui2         varchar(255),
    name2        varchar(512),
    attribute2   varchar(55)
)
;


-- 1
--Initial table creation
DROP TABLE parental_stage_attributes
CREATE TABLE parental_stage_attributes as
SELECT distinct cui, str as name, attribute
from (
         SELECT distinct cc.cui,
                         cc.str,
                         CASE
                             WHEN cc.str IN ( -- Stage Atom
                                             'Limited Stage',
                                             'Occult Stage',
                                             'Extensive Stage',
                                             'Advanced Stage',
                                             'Stage 0',
                                             'Stage A',
                                             'Stage B',
                                             'Stage C',
                                             'Stage D',
                                             'Stage I',
                                             'Stage IE',
                                             'Stage II',
                                             'Stage IIE',
                                             'Stage III',
                                             'Stage IV',
                                             'Stage Is',
                                             'Stage R',
                                             'Stage Unspecified',
                                             'Stage Unknown',
                                             'Stage V',
                                             'Stage X'
                                 ) then 'Stage'
                             ELSE 'Staging system' end as attribute
         FROM sources.mrconso c
                  JOIN sources.mrrel r
                       ON c.cui = r.cui1
                           AND c.cui = 'C1511987'
                           and r.rel = 'CHD'
                  JOIN sources.mrconso cc
                       ON cc.cui = r.cui2
                           and cc.sab = 'NCI'
                           and cc.tty = 'PT'
                           and cc.cui <> 'C1515169' -- TNM Staging System

         UNION ALL

         SELECT distinct cc.cui, cc.str, 'Staging system' as attribute
         FROM sources.mrconso cc
         WHERE cc.cui IN ('C2827648', --Pediatric Oncology Group Neuroblastoma Staging System
                          'C4682824',-- SIOP/COG/NWTSG Staging System
                          'C1512090', -- Dukes' Classification
                          'C4528206' --Plasma Cell Myeloma by DS Stage
             )
           and cc.sab = 'NCI'
           and cc.tty = 'PT'

         UNION ALL

         SELECT distinct cc.cui, cc.str, 'Staging system' as attribute
         FROM sources.mrconso c
                  JOIN sources.mrrel r
                       ON c.cui = r.cui1
                           AND c.cui = 'C0449394' -- Staging System
                           and r.rel = 'CHD'
                  JOIN sources.mrconso cc
                       ON cc.cui = r.cui2
                           and cc.sab = 'NCI'
                           and cc.tty = 'PT'
                           and cc.cui <> 'C1515169' -- TNM Staging System
     ) as tab
;

INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT distinct cui, name, attribute
FROM parental_stage_attributes
where (cui, name) not in (select cui, name from stage_attribute_concept_stage)
;


--CHD (children) relationships INSERTS
--INSERT INTO concept_relationship_stage of first degree children concepts for all the Parental stages retrieved
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui, cs.name, attribute, 'Subsumes' as relationship, c.cui, c.str, 'Stage' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682821' --Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and c.cui <> 'C4553144'--	Intergroup Rhabdomyosarcoma Clinical Group Extent of Disease

UNION ALL

SELECT distinct cs.cui, cs.name, attribute, 'Subsumes' as relationship, c.cui, c.str, 'Staging system' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682821' --Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and c.cui = 'C4553144'--	Intergroup Rhabdomyosarcoma Clinical Group Extent of Disease
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental stages retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)

--INSERT INTO concept_relationship_stage of first degree children concepts for all the inserted  stages
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui, cs.name, attribute, 'Subsumes' as relationship, c.cui, c.str, 'Stage' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis

                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental stages retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;

--INSERT INTO concept_relationship_stage of first degree children concepts for all the inserted  stages
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui, cs.name, attribute, 'Subsumes' as relationship, c.cui, c.str, 'Stage' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental stages retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;

--INSERT INTO concept_relationship_stage of first degree children concepts for all the inserted  stages
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui, cs.name, attribute, 'Subsumes' as relationship, c.cui, c.str, 'Stage' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental stages retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;

SELECT distinct *
FROM stage_attribute_relationship_stage
;

--STAGING SCHEMAS for AJCC INSERTION
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui, cs.name, attribute, 'Has schema' as relationship, c.cui, c.str, 'Schema' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'RO'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and cs.cui <> c.cui
  and c.str ilike '%stage%'
  and c.str not ilike '%terminology%'
  and c.cui IN (
    SELECT distinct c.cui
    FROM stage_attribute_concept_stage cs
             JOIN sources.mrrel r
                  ON cs.cui = r.cui1
             JOIN sources.mrconso c
                  ON r.cui2 = c.cui
                      and r.rel = 'RO'
                      and c.sab = 'NCI'
                      and c.tty = 'PT'
    where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
      and cs.cui <> c.cui
      and c.str ilike '%stage%'
      and c.str not ilike '%terminology%'
    group by 1
    having count(distinct cs.cui) = 1
)
  and cs.name ilike '%ajcc%'
  and c.str !~* 'clinical|Pathologic|Postneoadjuvant'
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental stages retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;
--STAGING SCHEMAS hierarchy renewal for AJCC
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui, cs.name, cs.attribute, 'Subsumes' as relationship, c.cui, c.str, s.attribute as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis
                      )
         JOIN stage_attribute_concept_stage s
              ON s.cui = c.cui
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
;

-- Insertion of Stages
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui,
                cs.name,
                cs.attribute,
                'Subsumes'        as relationship,
                c.cui,
                c.str,
                'Staging/Grading' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental staging/gradings retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;
-- Insertion of Stages
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui,
                cs.name,
                cs.attribute,
                'Subsumes'        as relationship,
                c.cui,
                c.str,
                'Staging/Grading' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and c.str ilike '%stage%'
;


--INSERT INTO concept_stage of first degree children concepts for all the Parental staging/gradings retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;
-- Insertion of Stages
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui,
                cs.name,
                cs.attribute,
                'Subsumes'        as relationship,
                c.cui,
                c.str,
                'Staging/Grading' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and c.str ilike '%stage%'
  and c.cui <> cs.cui
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental staging/gradings retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;

-- Insertion of Stages
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui,
                cs.name,
                cs.attribute,
                'Subsumes'        as relationship,
                c.cui,
                c.str,
                'Staging/Grading' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and c.str ilike '%stage%'
  and c.cui <> cs.cui
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental staging/gradings retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;

-- Insertion of Staging/Grading
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui,
                cs.name,
                cs.attribute,
                'Subsumes'        as relationship,
                c.cui,
                c.str,
                'Staging/Grading' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'CHD'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
                  AND c.cui not IN ('C3272668',-- Stage II Cervix
                                    'C4683413', --	Differentiated Thyroid Gland Carcinoma Under 55 Years AJCC v8 Stage
                                    'C4683415', -- Differentiated Thyroid Gland Carcinoma 55 Years and Older AJCC v8 Stage
                                    'C4683412', --Differentiated Thyroid Gland Carcinoma Under 45 Years AJCC v7 Stage
                                    'C4683414',--	Differentiated Thyroid Gland Carcinoma 45 Years and Older AJCC v7 Stage
                                    'C4682818', --Enneking Surgical Grade
                                    'C4682819', --Enneking Tumor Type
                                    'C4682819', --Enneking Tumor Type
                                    'C3272667', --Stage IB Cervix
                                    'C3272669', --Stage IIA Cervix
                                    'C4682821' -- Enneking Metastasis
                      )
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and c.str ilike '%stage%'
  and c.cui <> cs.cui
;

--INSERT INTO concept_stage of first degree children concepts for all the Parental staging/gradings retrieved
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;
--INSERTION OF STAGING BASIS
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui,
                cs.name,
                attribute,
                'Has staging basis' as relationship,
                c.cui,
                c.str,
                'Staging Basis'     as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'RO'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and cs.cui <> c.cui
  and (cs.attribute = 'Staging/Grading'
    and c.str ~* 'Postneoadjuvant.*TNM|Prognostic|clinical.*TNM|Pathologic.*TNM|Anatomic Stag')
  and cs.name ilike '%stage'
;
--INSERTION OF STAGING BASIS
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT distinct cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;

-- All other relationships to Stages/Staging Grading
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui, cs.name, cs.attribute, 'Subsumes' as relationship, c.cui, c.str, s.attribute as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'RO'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
         JOIN stage_attribute_concept_stage s
              ON s.cui = c.cui
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and cs.cui <> c.cui
  and c.str ilike '%stage%'
  and c.str not ilike '%Terminology%'
  and cs.name !~* '^FIGO|^Ann Arbor|^INRG|^INSS|Stage Is'
  and cs.attribute NOT IN ('Staging/Grading', 'Schema', 'Staging Basis')
  and (c.cui, cs.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
;


--INSERTION OF STAGING/gradin (uncoverd in previous steps)
INSERT INTO stage_attribute_relationship_stage (cui1, name1, attribute1, relationship, cui2, name2, attribute2)
SELECT distinct cs.cui, cs.name, attribute, 'Subsumes' as relationship, c.cui, c.str, 'Staging/Grading' as attribute
FROM stage_attribute_concept_stage cs
         JOIN sources.mrrel r
              ON cs.cui = r.cui1
         JOIN sources.mrconso c
              ON r.cui2 = c.cui
                  and r.rel = 'RO'
                  and c.sab = 'NCI'
                  and c.tty = 'PT'
where (cs.cui, c.cui) NOT IN (SELECT cui1, cui2 from stage_attribute_relationship_stage)
  and cs.attribute = 'Stage'
  and c.str ilike '%stage%'
  and c.str not ilike '%terminology%'
  and c.cui NOT IN (select cui from stage_attribute_concept_stage)
;

--INSERTION OF STAGING/gradin (uncoverd in previous steps)
INSERT INTO stage_attribute_concept_stage(cui, name, attribute)
SELECT distinct cui2, name2, attribute2
FROM stage_attribute_relationship_stage
where (cui2, name2) NOT IN (SELECT cui, name from stage_attribute_concept_stage)
;


ALTER TABLE stage_attribute_concept_stage
    add column normalized_name varchar(512);
UPDATE stage_attribute_concept_stage
set normalized_name =null;

-- DROP TABLE stage_attribute_concept_stage_with_correct_names
CREATE TABLE stage_attribute_concept_stage_with_correct_names as
with v6v7 as (
    SELECT cui,
           name,
           attribute,
           split_part(name, 'AJCC', 1) || 'by AJCC 6th edition' as romanname,
           '6'                                                  as version
    FROM stage_attribute_concept_stage
    where name like '%v6 and v7%'

    UNION
    SELECT cui,
           name,
           attribute,
           split_part(name, 'AJCC', 1) || 'by AJCC 7th edition' as romanname,
           '7'                                                  as version
    FROM stage_attribute_concept_stage
    where name like '%v6 and v7%')
        ,
     v6v7v8 as (
         SELECT cui,
                name,
                attribute,
                split_part(name, 'AJCC', 1) || 'by AJCC 6th edition' as romanname,
                '6'                                                  as version
         FROM stage_attribute_concept_stage
         where name ilike '%v6, v7, and v8%'

         UNION
         SELECT cui,
                name,
                attribute,
                split_part(name, 'AJCC', 1) || 'by AJCC 7th edition' as romanname,
                '7'                                                  as version
         FROM stage_attribute_concept_stage
         where name ilike '%v6, v7, and v8%'
         UNION
         SELECT cui,
                name,
                attribute,
                split_part(name, 'AJCC', 1) || 'by AJCC 8th edition' as romanname,
                '8'                                                  as version
         FROM stage_attribute_concept_stage
         where name ilike '%v6, v7, and v8%'
     ),
     v6 as (
         SELECT distinct cui,
                         name,
                         attribute,
                         split_part(name, 'AJCC', 1) || 'by AJCC 6th edition' as romanname,
                         '6'                                                  as version
         FROM stage_attribute_concept_stage a
         WHERE cui not in (select cui from v6v7 union all select cui from v6v7v8)
           and a.name like '%v6'
         UNION ALL
         SELECT distinct cui,
                         name,
                         attribute,
                         split_part(name, 'AJCC', 1) || 'by AJCC 6th edition' ||
                         split_part(name, 'AJCC v6', 2) as romanname,
                         '6'                            as version
         FROM stage_attribute_concept_stage a
         WHERE cui not in (select cui from v6v7 union all select cui from v6v7v8)
           and a.name like '%v6%'
     )
        ,
     v7 as (
         SELECT distinct cui,
                         name,
                         attribute,
                         split_part(name, 'AJCC', 1) || 'by AJCC 7th edition' as romanname,
                         '7'                                                  as version
         FROM stage_attribute_concept_stage a
         WHERE cui not in (select cui from v6v7 union all select cui from v6v7v8)
           and a.name like '%v7'
         UNION ALL
         SELECT distinct cui,
                         name,
                         attribute,
                         split_part(name, 'AJCC', 1) || 'by AJCC 7th edition' ||
                         split_part(name, 'AJCC v7', 2) as romanname,
                         '7'                            as version
         FROM stage_attribute_concept_stage a
         WHERE cui not in (select cui from v6v7 union all select cui from v6v7v8)
           and a.name like '%v7%'
     )
        ,
     v8 as (
         SELECT distinct cui,
                         name,
                         attribute,
                         split_part(name, 'AJCC', 1) || 'by AJCC 8th edition' as romanname,
                         '8'                                                  as version
         FROM stage_attribute_concept_stage a
         WHERE cui not in (select cui from v6v7 union all select cui from v6v7v8)
           and a.name like '%v8'
         UNION ALL
         SELECT distinct cui,
                         name,
                         attribute,
                         split_part(name, 'AJCC', 1) || 'by AJCC 8th edition' ||
                         split_part(name, 'AJCC v8', 2) as romanname,
                         '8'                            as version
         FROM stage_attribute_concept_stage a
         WHERE cui not in (select cui from v6v7 union all select cui from v6v7v8)
           and a.name like '%v8%'
     )
        ,
     ajcc as (
         select distinct cui, name, attribute, romanname, version
         from v6v7
         union
         select distinct cui, name, attribute, romanname, version
         from v6v7v8
         union
         select distinct cui, name, attribute, romanname, version
         from v6
         union
         select distinct cui, name, attribute, romanname, version
         from v7
         union
         select distinct cui, name, attribute, romanname, version
         from v8
     )
        ,
     romannames as (
         SELECT distinct cui,
                         name,
                         attribute,
                         regexp_replace(romanname, ' by by ', ' by ') as romanname,
                         version
         from ajcc
         where cui not in (
                           'C2983725',---	AJCC v6 Stage
                           'C2983726', --AJCC v7 Stage
                           'C4329225' --AJCC v8 Stage
             )

         union all

         SELECT distinct cui,
                         name,
                         attribute,
                         CASE
                             WHEN name ilike '%6%' then regexp_replace(name, ' v6', ' 6th edition')
                             WHEN name ilike '%7%' then regexp_replace(name, ' v7', ' 7th edition')
                             WHEN name ilike '%8%' then regexp_replace(name, ' v8', ' 8th edition')
                             end as romanname,
                         version
         from ajcc
         where cui in (
                       'C2983725',---	AJCC v6 Stage
                       'C2983726', --AJCC v7 Stage
                       'C4329225' --AJCC v8 Stage
             )
     ),
     ajcc_corrected as (
         SELECT distinct cui, name, attribute, regexp_replace(romanname, 'IV', '4') as name2, version
         FROM romannames
         where romanname like '% IV%'
         UNION ALL
         SELECT distinct cui, name, attribute, regexp_replace(romanname, 'III', '3') as name2, version
         FROM romannames
         where romanname like '% III%'
         UNION ALL
         SELECT distinct cui, name, attribute, regexp_replace(romanname, 'II', '2') as name2, version
         FROM romannames
         where romanname like '% II%'
           and romanname not like '% III%'
         UNION ALL
         SELECT distinct cui, name, attribute, regexp_replace(romanname, 'I', '1') as name2, version
         FROM romannames
         where romanname like '%Stage I%' --last upda
           and romanname not like '% II%'
           and romanname not like '% IV%'

         UNION ALL
         SELECT distinct cui, name, attribute, romanname, version
         FROM romannames
         where romanname like '% 0%'
            or cui in (
                       'C2983725',---	AJCC v6 Stage
                       'C2983726', --AJCC v7 Stage
                       'C4329225' --AJCC v8 Stage
             )
     )
        ,
     ajcc_result as (
         SELECT distinct cui, name, attribute, romanname, version
         from ajcc
         where cui NOT IN (select cui from ajcc_corrected)
         UNION ALL
         SELECT distinct cui, name, attribute, name2, version
         from ajcc_corrected)
        ,
     leftover as (
         SELECT distinct *
         from stage_attribute_concept_stage
         where cui NOT IN (select cui from ajcc_result)
     )
        ,
     non_Ajcc_result as (
         SELECT distinct cui, name, attribute, regexp_replace(name, 'IV', '4') as name2
         FROM leftover
         where name like '% IV%'
         UNION ALL
         SELECT distinct cui, name, attribute, regexp_replace(name, 'III', '3', 'g') as name2
         FROM leftover
         where name like '% III%'
         UNION ALL
         SELECT distinct cui, name, attribute, regexp_replace(name, 'II', '2') as name2
         FROM leftover
         where name like '% II%'
           and name not like '% III%'
         UNION ALL
         SELECT distinct cui,
                         name,
                         attribute,
                         CASE
                             when name not ilike '%iss%' then regexp_replace(name, ' I', ' 1')
                             else regexp_replace(name, ' I ', ' 1 ') end as name2
         FROM leftover
         where name like '% I%'
           and name not like '% II%'
           and name not like '% IV%'
         UNION ALL
         SELECT distinct cui, name, attribute, name
         FROM leftover
         where name like '% 0%'
         UNION ALL
         SELECT distinct cui, name, attribute, regexp_replace(name, 'Stage V', 'Stage 5') as name2
         FROM leftover
         where name like '%Stage V%'
         UNION ALL
         SELECT distinct cui, name, attribute, regexp_replace(name, 'Group V', 'Group 5') as name2
         FROM leftover
         where name like '%Group V%')
        ,

     result as (
         SELECT cui, name, attribute, name as normalized_name
         FROM stage_attribute_concept_stage
         where cui NOT IN (
             select distinct cui
             from non_Ajcc_result
             union all
             select distinct cui
             from Ajcc_result
         )
         UNION ALL

         select distinct cui, name, attribute, name2
         from non_Ajcc_result
         union all
         select distinct cui, name, attribute, romanname
         from Ajcc_result
     )
SELECT distinct a.cui,
                a.name,
                a.attribute,
                r.normalized_name,
                CASE
                    WHEN (r.normalized_name ~* 'Stage \d\s' or r.normalized_name ~* 'Stage \d$')
                        then substring(r.normalized_name, '.*Stage .{1}')
                    WHEN r.normalized_name ~* 'Stage \d\S*$' then substring(r.normalized_name, '.*Stage \d\S*$')
                    else substring(r.normalized_name, '.*Stage \S*\s') end as last_part
from result r
         JOIN stage_attribute_concept_stage a
              on r.cui = a.cui
;



ALTER TABLE stage_attribute_concept_stage_with_correct_names
    ADD column first_part varchar(512);

UPDATE stage_attribute_concept_stage_with_correct_names a
set first_part = tab.first_part
FROM (
         SELECT distinct cui,
                         name,
                         attribute,
                         normalized_name,
                         last_part,
                         trim(replace(normalized_name, coalesce(last_part, ''), '')) as first_part
         FROM stage_attribute_concept_stage_with_correct_names) as tab
where a.cui = tab.cui
  and a.normalized_name = tab.normalized_name
;
ALTER TABLE stage_attribute_concept_stage_with_correct_names
    ADD column name_resulted varchar(512);
ALTER TABLE stage_attribute_concept_stage_with_correct_names
    ADD column name_qa_flag varchar(55);
UPDATE stage_attribute_concept_stage_with_correct_names a
set name_resulted = tab.name_resulted,
    name_qa_flag  = tab.name_qa_flag
FROM (
         SELECT distinct cui,
                         name,
                         attribute,
                         normalized_name,
                         trim(regexp_replace(concat(first_part, ' ', coalesce(last_part, '')), ' by by ', ' by ',
                                             'g')) as name_resulted,
                         CASE
                             WHEN (last_part is null or length(first_part) = 0) then 'non clear name'
                             else null end         as name_qa_flag
         FROM stage_attribute_concept_stage_with_correct_names)
         as tab
where a.cui = tab.cui
  and a.normalized_name = tab.normalized_name
;

SELECT DISTINCT *
FROM stage_attribute_concept_stage_with_correct_names
where attribute = 'Staging/Grading'
  and attribute <> 'Schema'
;


SELECT distinct cui1,
                a.name            as nci_name1,
                a.name_resulted   as modifier_name1,
                a.attribute       as attribute1,
                relationship,
                cui2,
                aa.name           as nci_name2,
                aa.name_resulted  as modifier_name2,
                aa.attribute      as attribute2,
                CASE
                    WHEN substring(a.name_resulted, 'AJCC \d') <> substring(aa.name_resulted, 'AJCC \d') then 'drop'
                    else null end as correct_relationship_flag
FROM stage_attribute_concept_stage_with_correct_names a
         JOIN stage_attribute_relationship_stage b
              ON a.cui = b.cui1
         JOIN stage_attribute_concept_stage_with_correct_names aa
              ON aa.cui = b.cui2
order by 2, 7
;

--ToDO:
--resuscitation fro ann arbor staging system (rel not in rel
/*SIB
SIB
SY)*/
SELECT distinct s2.name_resulted, rel, s.name_resulted
FROM stage_attribute_concept_stage_with_correct_names s
         JOIN sources.mrrel r
              ON s.cui = r.cui2
         JOIN stage_attribute_concept_stage_with_correct_names s2
              ON s2.cui = r.cui1
                  and s2.attribute = 'Staging system'
WHERE (s2.name, s.name) NOT IN (SELECT distinct name1, name2 from stage_attribute_relationship_stage)
--and s.name_resulted ~* 'ann arbor'
  and rel <> 'SIB'
  and s2.cui <> s.cui
  and substring(s2.name_resulted, 'AJCC \d') = substring(s.name_resulted, 'AJCC \d')
  AND (s2.name ilike '%ajcc%' or s.name ilike '%ajcc%')

UNION ALL

SELECT distinct s2.name_resulted, rel, s.name_resulted
FROM stage_attribute_concept_stage_with_correct_names s
         JOIN sources.mrrel r
              ON s.cui = r.cui2
         JOIN stage_attribute_concept_stage_with_correct_names s2
              ON s2.cui = r.cui1
                  and s2.attribute = 'Staging system'
WHERE (s2.name, s.name) NOT IN (SELECT distinct name1, name2 from stage_attribute_relationship_stage)
--and s.name_resulted ~* 'ann arbor'
  and rel <> 'SIB'
  and s2.cui <> s.cui
  AND (s2.name not ilike '%ajcc%' or s.name not ilike '%ajcc%')
;

CREATE TABLE staging_atoms_cr
(
    cui1            varchar(255),
    name1           varchar(255),
    synonym_name1   varchar(255),
    nci_name1       varchar(255),
    relationship_id varchar(255),
    nci_rel         varchar(255),
    cui2            varchar(255),
    name2           varchar(255),
    synonym_name2   varchar(255),
    nci_name2       varchar(255)
)
;

--INSERT INTO staging_atoms_cr
SELECT distinct cui1, cs.name_resulted, name1, relationship, cui2, cs2.name_resulted, name2
FROM stage_attribute_relationship_stage crs
         JOIN stage_attribute_concept_stage_with_correct_names cs
              ON crs.cui1 = cs.cui
         JOIN stage_attribute_concept_stage_with_correct_names cs2
              ON crs.cui2 = cs2.cui
where cs.name_resulted not ilike '%AJCC%'
   or cs2.name_resulted not ilike '%AJCC%'

UNION ALL

SELECT distinct cui1, cs.name_resulted, name1, relationship, cui2, cs2.name_resulted, name2
FROM stage_attribute_relationship_stage crs
         JOIN stage_attribute_concept_stage_with_correct_names cs
              ON crs.cui1 = cs.cui
         JOIN stage_attribute_concept_stage_with_correct_names cs2
              ON crs.cui2 = cs2.cui
where (cs.name_resulted ilike '%AJCC%'
    or cs2.name_resulted ilike '%AJCC%')
  and substring(cs.name_resulted, 'AJCC \d') = substring(cs2.name_resulted, 'AJCC \d');





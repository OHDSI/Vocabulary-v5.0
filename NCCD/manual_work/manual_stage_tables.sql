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
* Authors: Polina Talapova, Daryna Ivakhnenko, Dmitry Dymshyts
* Date: 2020
**************************************************************************/
/**********************************
********* CONCEPT MANUAL **********
***********************************/
truncate concept_manual;
INSERT INTO concept_manual
(
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
SELECT  DISTINCT  trim(regexp_replace(initcap (t_nm), '\s+', ' ', 'g')),
c.domain_id AS domain_id,
       'NCCD' AS vocabulary_id,
       case when c.domain_id = 'Drug' then 'Drug Product' else 'Device' end AS concept_class_id,
       NULL AS standard_concept,
       nccd_code AS concept_code,
       TO_DATE('20200313','yyyymmdd') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
       FROM nccd_manual a
       join devv5.concept c on a.concept_Id = c.concept_id and c.standard_concept = 'S'; --353
/***************************************
***** CONCEPT RELATIONSHIP MANUAL ******
****************************************/
truncate concept_relationship_manual;
INSERT INTO concept_relationship_manual
(concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
SELECT DISTINCT  nccd_code AS concept_code_1,
        c.concept_code AS concept_code_2,
       'NCCD' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date
       FROM nccd_manual a
       join devv5.concept c on a.concept_Id = c.concept_id and c.standard_concept = 'S'; --415 
       
/******************************************
********* CONCEPT SYNONYM MANUAL **********
*******************************************/
truncate concept_synonym_manual;
INSERT INTO concept_synonym_manual
(synonym_name,synonym_concept_code,synonym_vocabulary_id, language_concept_id)
SELECT DISTINCT nccd_name as synonym_name,
       nccd_code as synonym_concept_code,
       'NCCD' as synonym_vocabulary_id,
       4180186 as language_concept_id
FROM nccd_manual
where concept_id != 0; --353

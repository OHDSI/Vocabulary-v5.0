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
* Authors: Dmitry Dymshyts, Timur Vakhitov
* Date: 2022
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=>'OMOP Invest Drug',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.ncit_pharmsub LIMIT 1), -- use the date of ixgiht
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.ncit_pharmsub LIMIT 1),  -- use the version of ixgiht
	pVocabularyDevSchema	=> 'DEV_INVDRUG'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'DEV_INVDRUG',
	pAppendVocabulary		=> TRUE
);
END $_$;

--2. create tables from inxight JSON file
--2.1 relationship table: added names, so it's easier to review
create table inxight_rel as
select distinct 
  i.jsonfield->>'uuid' root_uuid,
  names->>'name' nm,
  names->>'type' tp,
  names->>'displayName' display_name,
  rel_json->>'type' as relationship_type,
  rel_json->'relatedSubstance'->>'refuuid' as target_id,
  rel_json->'relatedSubstance'->>'name' as target_name
from dev_mkallfelz.inxight i
cross join json_array_elements(i.jsonfield#>'{names}') names
cross join json_array_elements(i.jsonfield#>'{relationships}') rel_json
where   names->>'displayName'  = 'true'
;
--2.2 synonyms AND names, display_name = 'true' considered to be concept_name, display_name = 'false' - synonym_name
create table inxight_syn as
select
  i.jsonfield->>'uuid' root_uuid,
 -- names->>'uuid' name_uuid,
  names->>'name' nm,
  names->>'type' tp,
  names->>'displayName' display_name
from dev_mkallfelz.inxight i
cross join json_array_elements(i.jsonfield#>'{names}') names
;
--2.3. references to different codesystems, will be used to match with NCI, RxNorm and potentially Drubank
create table inxight_codes as
select
  i.jsonfield->>'uuid' root_uuid,
  codes->>'codeSystem' codeSystem,
  codes->>'code' code
from dev_mkallfelz.inxight i
cross join json_array_elements(i.jsonfield#>'{codes}') codes
where codes->>'type' ='PRIMARY'
;
--3. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--4. fill concept_stage with OMOP Invest drugs (INXIGHT only in this case)
--only those having display_name = true and relationship_id ='ACTIVE MOIETY' on the left OR on the right side in inxight rel are considered as drugs
--left side
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT   nm AS concept_name,
	'Drug' AS domain_id,
	'OMOP Invest Drug' AS vocabulary_id,
case 
when root_uuid = target_id then 'Ingredient' 
else 'Precise Ingredient' end
AS concept_class_id,
	NULL AS standard_concept,
	r.root_uuid as concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inxight_rel r
WHERE relationship_type = 'ACTIVE MOIETY'
and root_uuid not in ( -- can't identify the active substance if it has several 
select   root_uuid   from inxight_rel where relationship_type = 'ACTIVE MOIETY'
group by root_uuid having count(1)>1 )
and root_uuid !='c066f70b-2f7f-9cc2-fe50-66c963eaea68' --CIMDELIRSEN, has mistakenly built relationship to precise ingredient, so it's excluded from the left side, but will appear in the right side 
order by root_uuid
;
--right side
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT distinct coalesce( s.nm, r.target_name) AS concept_name, -- if name absent with display_name ='true' (seems to be bug of a database), use the target_name from relationship table
	'Drug' AS domain_id,
	'OMOP Invest Drug' AS vocabulary_id,
'Ingredient' AS concept_class_id,
	NULL AS standard_concept,
	r.target_id as concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inxight_rel r
left join inxight_syn s on r.target_id = s.root_uuid and s.display_name ='true'
WHERE relationship_type = 'ACTIVE MOIETY'
and r.target_id not in (select concept_code from concept_stage)
ORDER BY  r.target_id
;
--5. build mappings to RxNorm by name match or by string match

--5.1. match by RXCUI
Create table inx_to_rx  as 
select distinct  root_uuid, c2.concept_code as concept_code_2, c2.vocabulary_Id as vocabulary_id_2 from inxight_codes i
join concept c on c.concept_code = i.code and codesystem ='RXCUI' and c.vocabulary_id ='RxNorm'
-- Precise ingredients and updated concepts to be mapped to standard
join concept_relationship r on c.concept_id = r.concept_id_1 and relationship_id='Maps to' and r.invalid_reason is null
join concept c2 on c2.concept_id = r.concept_id_2
;
--5.2 match by synonyms OR names
insert into inx_to_rx
	WITH rx_names AS (
			--do we have nice synonyms in RxNorm?
			SELECT c2.concept_code,
				c2.vocabulary_id,
				cs.concept_synonym_name AS concept_name
			FROM concept_synonym cs
			JOIN concept c ON c.concept_id = cs.concept_id
			join concept_relationship r on c.concept_id = r.concept_id_1 and relationship_id='Maps to' and r.invalid_reason is null-- Precise ingredients and updated concepts
join concept c2 on c2.concept_id = r.concept_id_2
			WHERE c.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND c.concept_class_id IN (
					'Ingredient',
					'Precise Ingredient'
					)
			UNION ALL
			SELECT c2.concept_code,
				c2.vocabulary_id,
				c2.concept_name
			FROM concept c
			join concept_relationship r on c.concept_id = r.concept_id_1 and relationship_id='Maps to' and r.invalid_reason is null-- Precise ingredients and updated concepts
join concept c2 on c2.concept_id = r.concept_id_2
			WHERE c.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND c.concept_class_id IN (
					'Ingredient',
					'Precise Ingredient'
					) -- non stated whether it's standard or not as we will Map them in the future steps
			)
select distinct cs.concept_code,n.concept_code as concept_code_2, n.vocabulary_id as vocabulary_id_2 
from inxight_syn 
join rx_names n on replace (nm,' CATION' ,'') = upper (concept_name)
--to get the drugs only
join concept_Stage cs on cs.concept_code = root_uuid and concept_class_id ='Ingredient'
and root_uuid not in (select root_uuid from inx_to_rx)
;
--5.3 add mappings to  RxNOrm or existing RxNorm Extension to concept_relationship_stage
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT  root_uuid AS concept_code_1,
	concept_code_2,
	'OMOP Invest Drug' AS vocabulary_id_1,
	vocabulary_id_2,
	'Maps to' AS relationship_id,
	TO_DATE('20220208', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inx_to_rx
join concept_Stage on concept_code = root_uuid
;
--6. build relationships from precise ingredients to INX ingredients
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT  r.root_uuid AS concept_code_1,
coalesce (r2.target_id, r.target_id) as concept_code_2, -- in case target ingredient is still a precise ingredient, we add one more step of mapping
	'OMOP Invest Drug' AS vocabulary_id_1,
		'OMOP Invest Drug' AS vocabulary_id_2,
		'Form of' as relationship_id,
			TO_DATE('20220208', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
 from  inxight_rel r
 -- in case target ingredient is still a precise ingredient, we add one more step of mapping
 left join  inxight_rel r2 on r2.root_uuid = r.target_id and r2.relationship_type = 'ACTIVE MOIETY' and r2.root_uuid != r2.target_id
--mistakenly built relationship from Inredient to PI (other way around) 
 and r2.root_uuid !='c066f70b-2f7f-9cc2-fe50-66c963eaea68'
 where r.root_uuid in (select concept_code from concept_stage)
--mistakenly built relationship from Inredient to PI (other way around) 
 and r.root_uuid !='c066f70b-2f7f-9cc2-fe50-66c963eaea68'
and r.relationship_type = 'ACTIVE MOIETY' and r.root_uuid != r.target_id 
;
--7. Add mappings to new RxE
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT cs.concept_code AS concept_code_1,
	'OMOP' || ROW_NUMBER() OVER (ORDER BY cs.concept_code) + l.max_omop_concept_code AS concept_code_2,
	'OMOP Invest Drug' AS vocabulary_id_1,
	'RxNorm Extension' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage cs
--don't have mapping to RxNorm(E)
LEFT JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS null
CROSS JOIN LATERAL(SELECT MAX(REPLACE(concept_code, 'OMOP', '')::INT4) AS max_omop_concept_code FROM concept WHERE concept_code LIKE 'OMOP%'
		AND concept_code NOT LIKE '% %' --last valid value of the OMOP123-type codes
	) l
WHERE crs.concept_code_1 IS null 
and cs.concept_class_id ='Ingredient' -- filter out Precise ingerients	
;
--7.1 Add these RxE concepts to the concept_stage table
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT cs.concept_name,
	'Drug' AS domain_id,
	'RxNorm Extension' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	'S' AS standard_concept,
	crs.concept_code_2 AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage cs
JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id = 'Maps to'
	AND crs.vocabulary_id_2 = 'RxNorm Extension'
	AND crs.invalid_reason IS NULL
--and RxNorm extension concept shouldn't exist already as a part of a mapping to existing concepts 
LEFT JOIN concept c ON c.concept_code = crs.concept_code_2
	AND c.vocabulary_id = 'RxNorm Extension'
WHERE c.concept_code IS NULL
;
--8. build links from Precise ingredient to Rx(E) INgredient through IND ingredient
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
	select a.concept_Code_1, 
	b.concept_code_2,
	a.vocabulary_id_1,
	b.vocabulary_id_2,
	'Maps to',
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
	from concept_relationship_stage a
join concept_relationship_stage b on a.concept_code_2 = b.concept_code_1 and a.vocabulary_Id_2 = b.vocabulary_Id_1
left join concept_relationship_stage c on c.concept_Code_1 = a.concept_code_1 and c.relationship_id='Maps to'
where a.relationship_id ='Form of' and b.relationship_Id ='Maps to'
and a.vocabulary_id_1 ='OMOP Invest Drug' and a.vocabulary_id_2= 'OMOP Invest Drug' 
and c.concept_code_1 is null -- in case concepts have the mapping already
;
--9. build synonyms

INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT cs.concept_code,
	trim (substr (i.nm, 1,1000)) , -- the description is longet than 1000 symbols is cut
	'OMOP Invest Drug',
	4180186 -- English language
FROM inxight_syn i
 JOIN concept_stage cs ON cs.concept_code = i.root_uuid
where i.display_name !='true'
;
--10. add NCIt hierarchy to antineopls drug
--create table with INXIGHT to NCIT crosswalks

Create table inx_to_ncidb as 
/* -- remove comment if you decide to use the drug bank in a future
select  root_uuid, d.drugbank_id as inv_code from inxight_codes c
join dev_mkallfelz.drugbank d on c.code = drugbank_id and codesystem ='DRUG BANK'
union
select  root_uuid, d.drugbank_id from inxight_codes c
join dev_mkallfelz.drugbank d on c.code = d.cas and codesystem ='CAS' 
union
select  root_uuid, d.drugbank_id from inxight_codes c
join dev_mkallfelz.drugbank d on c.code = d.unii and codesystem ='FDA UNII' 
union
*/
--match by CAS code
select  root_uuid, p.concept_id as inv_code  from inxight_codes c
join sources.ncit_pharmsub p on c.code = p.cas_registry and codesystem ='CAS' 
union
--match by FDA UNII code
select  root_uuid, p.concept_id from inxight_codes c
join sources.ncit_pharmsub p on c.code = p.fda_unii_code and codesystem ='FDA UNII'
union
--match by NCI code
select  root_uuid, p.concept_id from inxight_codes c
join sources.ncit_pharmsub p on c.code = p.concept_id and codesystem ='NCI_THESAURUS'
union
--match by name or synonym (in ncit_pharmsub table PT is present in SY)
select  root_uuid, p.concept_id from inxight_syn c
join sources.ncit_pharmsub p on c.nm = upper (p.sy) 
;
--10.1 Build hierarchical relationships from new RxEs to the ATC 'L01' using the ncit_antineopl - table containing antineoplastic agents only
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT distinct -- various NCI codes can belong to the same root_uuid
 crs.concept_code_2 AS concept_code_1,
	'L01' AS concept_code_2,
	'RxNorm Extension' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_relationship_stage crs
--exclude already existing RxEs
LEFT JOIN concept c ON c.concept_code = crs.concept_code_2
	AND c.vocabulary_id = 'RxNorm Extension'
JOIN inx_to_ncidb i on i.root_uuid = crs.concept_code_1
join sources.ncit_antineopl n on n.code = i.inv_code
WHERE c.concept_code IS NULL
	-- Investigational drugs mapped to RxE we have to build the hiearchy for
	AND crs.vocabulary_id_2 = 'RxNorm Extension'
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL
	;
	--11. clean up
drop table if exists inxight_rel;
drop table inxight_syn;
drop table inxight_codes;
drop table if exists inx_to_rx;
drop table inx_to_ncidb;

--At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script

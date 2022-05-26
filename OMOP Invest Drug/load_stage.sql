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
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.invdrug_pharmsub LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.invdrug_pharmsub LIMIT 1),
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

--3. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create tables from inxight JSON file
--3.1 relationship table: added names, so it's easier to review
CREATE UNLOGGED TABLE inxight_rel AS
SELECT *
FROM (
	SELECT DISTINCT i.jsonfield->>'uuid' root_uuid,
		names->>'name' nm,
		names->>'displayName' display_name,
		rel_json->>'type' AS relationship_type,
		rel_json->'relatedSubstance'->>'refuuid' AS target_id,
		rel_json->'relatedSubstance'->>'name' AS target_name
	FROM sources.invdrug_inxight i
	CROSS JOIN json_array_elements(i.jsonfield#>'{names}') names
	CROSS JOIN json_array_elements(i.jsonfield#>'{relationships}') rel_json
	WHERE names->>'displayName' = 'true'
	) s0
WHERE NOT (
		s0.root_uuid = 'c066f70b-2f7f-9cc2-fe50-66c963eaea68'
		AND s0.relationship_type = 'ACTIVE MOIETY'
		AND s0.target_id = '8994b13a-6254-4966-a14f-453d9b3c8254' --mistakenly built relationship
		);

--3.2 synonyms AND names, display_name = 'true' considered to be concept_name, display_name = 'false' - synonym_name
CREATE UNLOGGED TABLE inxight_syn AS
SELECT i.jsonfield->>'uuid' root_uuid,
	names->>'name' nm,
	names->>'displayName' display_name
FROM sources.invdrug_inxight i
CROSS JOIN json_array_elements(i.jsonfield#>'{names}') names;

--3.3 references to different codesystems, will be used to match with NCI, RxNorm and potentially Drubank
CREATE UNLOGGED TABLE inxight_codes AS
SELECT i.jsonfield->>'uuid' root_uuid,
	codes->>'codeSystem' codesystem,
	codes->>'code' code
FROM sources.invdrug_inxight i
CROSS JOIN json_array_elements(i.jsonfield#>'{codes}') codes
WHERE codes->>'type' = 'PRIMARY';

--4. Fill concept_stage with OMOP Invest drugs (INXIGHT only in this case)
--only those having display_name = true and relationship_id ='ACTIVE MOIETY' on the left OR on the right side in inxight rel are considered as drugs
--4.1 left side
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
SELECT nm AS concept_name,
	'Drug' AS domain_id,
	'OMOP Invest Drug' AS vocabulary_id,
	CASE WHEN root_uuid = target_id THEN 'Ingredient' ELSE 'Precise Ingredient' END AS concept_class_id,
	NULL AS standard_concept,
	r.root_uuid AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inxight_rel r
WHERE relationship_type = 'ACTIVE MOIETY'
	AND root_uuid NOT IN (
		--can't identify the active substance if it has several
		SELECT r_int.root_uuid
		FROM inxight_rel r_int
		WHERE r_int.relationship_type = 'ACTIVE MOIETY'
		GROUP BY r_int.root_uuid
		HAVING COUNT(*) > 1
		);

--4.2 right side
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
SELECT DISTINCT COALESCE(s.nm, r.target_name) AS concept_name, --if name absent with display_name ='true' (seems to be bug of a database), use the target_name from relationship table
	'Drug' AS domain_id,
	'OMOP Invest Drug' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS standard_concept,
	r.target_id AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inxight_rel r
LEFT JOIN inxight_syn s ON s.root_uuid = r.target_id
	AND s.display_name = 'true'
LEFT JOIN concept_stage cs ON cs.concept_code = r.target_id
WHERE r.relationship_type = 'ACTIVE MOIETY'
	AND cs.concept_code IS NULL;

ANALYZE concept_stage;

--5. Build mappings to RxNorm by name match or by string match
--5.1 match by RXCUI
CREATE UNLOGGED TABLE inx_to_rx AS
SELECT DISTINCT i.root_uuid,
	c2.concept_code AS concept_code_2,
	c2.vocabulary_id AS vocabulary_id_2
FROM inxight_codes i
JOIN concept c ON c.concept_code = i.code
	AND c.vocabulary_id = 'RxNorm'
--precise ingredients and updated concepts to be mapped to standard
JOIN concept_relationship r ON c.concept_id = r.concept_id_1
	AND relationship_id = 'Maps to'
	AND r.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_id = r.concept_id_2
WHERE i.codesystem = 'RXCUI';

--5.2 match by synonyms OR names
INSERT INTO inx_to_rx
WITH rx_names AS (
		--do we have nice synonyms in RxNorm?
		SELECT c2.concept_code,
			c2.vocabulary_id,
			cs.concept_synonym_name AS concept_name
		FROM concept_synonym cs
		JOIN concept c ON c.concept_id = cs.concept_id
		JOIN concept_relationship r ON c.concept_id = r.concept_id_1
			AND r.relationship_id = 'Maps to'
			AND r.invalid_reason IS NULL --Precise ingredients and updated concepts
		JOIN concept c2 ON c2.concept_id = r.concept_id_2
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
		JOIN concept_relationship r ON c.concept_id = r.concept_id_1
			AND r.relationship_id = 'Maps to'
			AND r.invalid_reason IS NULL --precise ingredients and updated concepts
		JOIN concept c2 ON c2.concept_id = r.concept_id_2
		WHERE c.vocabulary_id IN (
				'RxNorm',
				'RxNorm Extension'
				)
			AND c.concept_class_id IN (
				'Ingredient',
				'Precise Ingredient'
				) --non stated whether it's standard or not as we will Map them in the future steps
		)
SELECT DISTINCT cs.concept_code,
	n.concept_code AS concept_code_2,
	n.vocabulary_id AS vocabulary_id_2
FROM inxight_syn s
JOIN rx_names n ON REPLACE(s.nm, ' CATION', '') = UPPER(n.concept_name)
--to get the drugs only
JOIN concept_stage cs ON cs.concept_code = s.root_uuid
	AND cs.concept_class_id = 'Ingredient'
WHERE s.root_uuid NOT IN (
		SELECT root_uuid
		FROM inx_to_rx
		);

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
SELECT i.root_uuid AS concept_code_1,
	i.concept_code_2,
	'OMOP Invest Drug' AS vocabulary_id_1,
	i.vocabulary_id_2,
	'Maps to' AS relationship_id,
	TO_DATE('20220208', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inx_to_rx i
WHERE EXISTS (
		SELECT 1
		FROM concept_stage cs
		WHERE cs.concept_code = i.root_uuid
		);

--6. Build relationships from precise ingredients to INX ingredients
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT r.root_uuid AS concept_code_1,
	COALESCE(r2.target_id, r.target_id) AS concept_code_2, --in case target ingredient is still a precise ingredient, we add one more step of mapping
	'OMOP Invest Drug' AS vocabulary_id_1,
	'OMOP Invest Drug' AS vocabulary_id_2,
	'Form of' AS relationship_id,
	TO_DATE('20220208', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inxight_rel r
--in case target ingredient is still a precise ingredient, we add one more step of mapping
LEFT JOIN inxight_rel r2 ON r2.root_uuid = r.target_id
	AND r2.relationship_type = 'ACTIVE MOIETY'
	AND r2.root_uuid <> r2.target_id
WHERE EXISTS (
		SELECT 1
		FROM concept_stage cs
		WHERE cs.concept_code = r.root_uuid
		)
	AND r.relationship_type = 'ACTIVE MOIETY'
	AND r.root_uuid <> r.target_id;

ANALYZE concept_relationship_stage;

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
	AND crs.invalid_reason IS NULL
CROSS JOIN LATERAL(SELECT MAX(REPLACE(concept_code, 'OMOP', '')::INT4) AS max_omop_concept_code FROM concept WHERE concept_code LIKE 'OMOP%'
		AND concept_code NOT LIKE '% %' --last valid value of the OMOP123-type codes
	) l
WHERE crs.concept_code_1 IS NULL
	AND cs.concept_class_id = 'Ingredient'; --filter out Precise ingerients

--7.1 add these RxE concepts to the concept_stage table
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
WHERE c.concept_code IS NULL;

--8. Build links from Precise ingredient to Rx(E) INgredient through IND ingredient
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT a.concept_code_1,
	b.concept_code_2,
	a.vocabulary_id_1,
	b.vocabulary_id_2,
	'Maps to' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_relationship_stage a
JOIN concept_relationship_stage b ON b.concept_code_1 = a.concept_code_2
	AND b.vocabulary_id_1 = a.vocabulary_id_2
LEFT JOIN concept_relationship_stage c ON c.concept_code_1 = a.concept_code_1
	AND c.vocabulary_id_1 = a.vocabulary_id_1
	AND c.relationship_id = 'Maps to'
WHERE a.relationship_id = 'Form of'
	AND b.relationship_id = 'Maps to'
	AND a.vocabulary_id_1 = 'OMOP Invest Drug'
	AND a.vocabulary_id_2 = 'OMOP Invest Drug'
	AND c.concept_code_1 IS NULL; --in case concepts have the mapping already

--9. Build synonyms
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT cs.concept_code AS synonym_concept_code,
	vocabulary_pack.CutConceptSynonymName(i.nm) AS synonym_name, --the description is longet than 1000 symbols is cut
	cs.vocabulary_id AS synonym_vocabulary_id,
	4180186 AS language_concept_id --English language
FROM inxight_syn i
JOIN concept_stage cs ON cs.concept_code = i.root_uuid
WHERE i.display_name <> 'true';

--10. Add NCIt hierarchy to antineopls drug
--build hierarchical relationships from new RxEs to the ATC 'L01' using the invdrug_antineopl - table containing antineoplastic agents only
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
WITH inx_to_ncidb AS (
		--create table with INXIGHT to NCIT crosswalks
		/* --remove comment if you decide to use the drug bank in a future
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
		SELECT c.root_uuid,
			p.concept_id AS inv_code
		FROM inxight_codes c
		JOIN sources.invdrug_pharmsub p ON p.cas_registry = c.code
		WHERE c.codesystem = 'CAS'
		
		UNION
		
		--match by FDA UNII code
		SELECT c.root_uuid,
			p.concept_id
		FROM inxight_codes c
		JOIN sources.invdrug_pharmsub p ON p.fda_unii_code = c.code
		WHERE c.codesystem = 'FDA UNII'
		
		UNION
		
		--match by NCI code
		SELECT c.root_uuid,
			p.concept_id
		FROM inxight_codes c
		JOIN sources.invdrug_pharmsub p ON p.concept_id = c.code
		WHERE c.codesystem = 'NCI_THESAURUS'
		
		UNION
		
		--match by name or synonym (in invdrug_pharmsub table PT is present in SY)
		SELECT c.root_uuid,
			p.concept_id
		FROM inxight_syn c
		JOIN sources.invdrug_pharmsub p ON UPPER(p.sy) = c.nm
		)
SELECT DISTINCT --various NCI codes can belong to the same root_uuid
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
JOIN inx_to_ncidb i ON i.root_uuid = crs.concept_code_1
JOIN sources.invdrug_antineopl n ON n.code = i.inv_code
WHERE c.concept_code IS NULL
	--Investigational drugs mapped to RxE we have to build the hiearchy for
	AND crs.vocabulary_id_2 = 'RxNorm Extension'
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL;

--11. Clean up
DROP TABLE inxight_rel,
	inxight_syn,
	inxight_codes,
	inx_to_rx;

--At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
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
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'OMOP Invest Drug '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
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

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. We can try to map not only new concepts but all of them using synonyms
--Add parent_child relat, fill antineopl_code if it belongs to the antineopls category
DROP TABLE IF EXISTS inv_syn;
CREATE UNLOGGED TABLE inv_syn AS
	WITH ncit_antineopl AS (
			SELECT DISTINCT /*somehow the source table has duplicates of synonyms*/ code,
				TRIM(UNNEST(string_to_array(synonyms, ' || '))) AS synonym_name
			FROM sources.ncit_antineopl a
			),
		nci_drb_syn AS (
			--add synonyms from UMLS and NCIt
			SELECT mr.sab,
				mr.code,
				mr.str
			FROM sources.mrconso mr
			WHERE mr.sab = 'DRUGBANK'
				AND mr.suppress = 'N'
			
			UNION ALL
			
			SELECT DISTINCT 'NCI',
				p.concept_id,
				p.sy
			FROM sources.ncit_pharmsub p
			),
		nci_drb AS (
			--DRUGBANK and NCI taken from mrconso
			SELECT mr1.cui,
				mr1.sab,
				mr1.tty,
				mr1.code,
				mr1.str
			FROM sources.mrconso mr1
			WHERE mr1.sab = 'DRUGBANK'
				AND mr1.tty = 'IN'
				AND mr1.suppress = 'N'
			
			UNION ALL
			
			SELECT DISTINCT mr2.cui,
				'NCI',
				'PT',
				p.concept_id,
				p.pt
			FROM sources.ncit_pharmsub p
			LEFT JOIN sources.mrconso mr2 ON mr2.code = p.concept_id
				AND mr2.sab = 'NCI'
				AND mr2.tty = 'PT'
				AND mr2.suppress = 'N'
			)
SELECT a.*,
	t.parent_code,
	c.code AS antineopl_code,
	s.str AS synonym_name
FROM nci_drb a
--get the hierarchy indicators
LEFT JOIN (
	SELECT code,
		UNNEST(string_to_array(parents, '|')) AS parent_code
	FROM sources.genomic_nci_thesaurus
	) t ON t.code = a.code
--get the antineoplastic drugs
LEFT JOIN ncit_antineopl c ON c.code = a.code
--get synonyms !!! nci_drb_syn - to review the logic of this query!
LEFT JOIN nci_drb_syn s ON s.sab = a.sab
	AND s.code = a.code;

--4. Add mappings to RxNorm (E)
--So basically this table now should have everything -- all mappings and synonyms
DROP TABLE IF EXISTS inv_rx_map;
CREATE UNLOGGED TABLE inv_rx_map AS
	WITH rx_names AS (
			--do we have nice synonyms in RxNorm?
			SELECT c.concept_code,
				c.vocabulary_id,
				cs.concept_synonym_name AS concept_name
			FROM concept_synonym cs
			JOIN concept c ON c.concept_id = cs.concept_id
			WHERE c.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND c.concept_class_id IN (
					'Ingredient',
					'Precise Ingredient'
					)
			
			UNION ALL
			
			SELECT c.concept_code,
				c.vocabulary_id,
				c.concept_name
			FROM concept c
			WHERE c.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND c.concept_class_id IN (
					'Ingredient',
					'Precise Ingredient'
					) -- non stated whether it's standard or not as we will Map them in the future steps
			),
		mappings AS (
			SELECT DISTINCT syn.*,
				COALESCE(mr.code, rx1.concept_code, rx2.concept_code) AS concept_code_2,
				COALESCE(mr.str, rx1.concept_name, rx2.concept_name) AS concept_name_2,
				COALESCE(REPLACE(mr.sab, 'RXNORM', 'RxNorm'), rx1.vocabulary_id, rx2.vocabulary_id) AS vocabulary_id_2
			FROM inv_syn syn
			LEFT JOIN sources.mrconso mr ON mr.cui = syn.cui
				AND mr.sab = 'RXNORM'
				AND mr.suppress = 'N'
				AND mr.tty IN (
					'PIN',
					'IN'
					)
			LEFT JOIN rx_names rx1 ON LOWER(rx1.concept_name) = LOWER(syn.str) -- str corresponds to the source preffered name
			LEFT JOIN rx_names rx2 ON LOWER(rx2.concept_name) = LOWER(syn.synonym_name) -- synonym_name
			)
--adding replacement mappings for updated RxNorms or being non-standard by other reasons
SELECT m.cui,
	m.sab,
	m.tty,
	m.code,
	m.str,
	m.parent_code,
	m.antineopl_code,
	m.synonym_name,
	c2.concept_code AS concept_code_2,
	c2.concept_name AS concept_name_2,
	c2.vocabulary_id AS vocabulary_id_2
FROM mappings m
LEFT JOIN concept c1 ON c1.concept_code = m.concept_code_2
	AND c1.vocabulary_id = m.vocabulary_id_2
LEFT JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
	AND r.relationship_id = 'Maps to'
	AND r.invalid_reason IS NULL
LEFT JOIN concept c2 ON c2.concept_id = r.concept_id_2;

--5. Assing concatenated codes (that will be used in concept_stage) to our table
DROP TABLE IF EXISTS inv_master;
CREATE UNLOGGED TABLE inv_master AS
	WITH cui_to_code AS (
			SELECT REPLACE(l.codes_list, 'C', 'NCITC') AS concept_code,
				s0.code
			FROM (
				SELECT ARRAY_AGG(codes.code) OVER (PARTITION BY COALESCE(codes.cui, codes.code)) AS codes_list,
					codes.code
				FROM (
					SELECT DISTINCT cui,
						code
					FROM inv_rx_map
					) codes
				) s0
			CROSS JOIN LATERAL(SELECT STRING_AGG(s_int.codes_list, '-' ORDER BY s_int.codes_list) AS codes_list FROM (
					SELECT UNNEST(s0.codes_list) AS codes_list
					) AS s_int) AS l
			)
SELECT c.concept_code,
	m.*
FROM inv_rx_map m
JOIN cui_to_code c ON c.code = m.code
--manual step (occurrs only due to problem with existing RxE that same drugs have different concepts)
WHERE NOT (
		c.concept_code = 'NCITC171815'
		AND m.concept_code_2 = 'OMOP4873903'
		);

CREATE INDEX idx_invmaster ON inv_master (concept_code);
ANALYZE inv_master;

--6. Insert into concept_stage
--Let drugbank be a primary name since it should have a better coverage, it has not only antineoplastics as NCIt
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
SELECT DISTINCT ON (im.concept_code) im.str AS concept_name,
	'Drug' AS domain_id,
	'OMOP Invest Drug' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS standard_concept,
	im.concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inv_master im
WHERE LENGTH(im.concept_code) <= 50
ORDER BY im.concept_code,
	im.sab,
	im.str;

--7. Insert into concept_synonym_stage
--Take the synonyms from inv_master
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT im.concept_code,
	im.synonym_name,
	'OMOP Invest Drug',
	4180186 -- English language
FROM inv_master im
--doesn't make sense to create a separate synonym entity if it differs by registry only
LEFT JOIN concept_stage cs ON cs.concept_code = im.concept_code
	AND LOWER(cs.concept_name) = LOWER(im.synonym_name)
WHERE LENGTH(im.concept_code) <= 50
	AND cs.concept_code IS NULL;

--8. Insert into concept_relationship_stage
--8.1 Add the mappings to RxNorm or RxE
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT concept_code AS concept_code_1,
	concept_code_2,
	'OMOP Invest Drug' AS vocabulary_id_1,
	vocabulary_id_2,
	'Maps to' AS relationship_id,
	TO_DATE('20220208', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM inv_master
WHERE LENGTH(concept_code) <= 50
	AND concept_code_2 IS NOT NULL;

--8.2 Add the mappings to RxE
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
	'OMOP' || ROW_NUMBER() OVER (/*order by cs.concept_code*/) + l.max_omop_concept_code AS concept_code_2,
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
	--RxE concepts shouldn't be created out of parent concepts 
	AND EXISTS (
		SELECT 1
		FROM inv_master im_int
		LEFT JOIN inv_master im_int2 ON im_int2.parent_code = im_int.code
		WHERE im_int.concept_code = cs.concept_code
			AND im_int2.concept_code IS NULL
		);

--8.3 Add these RxE concepts to the concept_stage table
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
--and RxNorm extension concept shouldn't exist already as a part of a routine RxE build
LEFT JOIN concept c ON c.concept_code = crs.concept_code_2
	AND c.vocabulary_id = 'RxNorm Extension'
WHERE c.concept_code IS NULL;

--9. Hierarchy
--9.1 Build hierarchical relationships from new RxEs to the ATC 'L01' concept using the ncit_antineopl 
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT crs.concept_code_2 AS concept_code_1,
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
WHERE c.concept_code IS NULL
	-- Investigational drugs mapped to RxE we have to build the hiearchy for
	AND crs.vocabulary_id_2 = 'RxNorm Extension'
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL
	AND EXISTS (
		SELECT 1
		FROM inv_master im_int
		WHERE im_int.concept_code = crs.concept_code_1
			AND im_int.antineopl_code IS NOT NULL --NCI code
		);

--9.2 Built internal hierarchy given by NCIt
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT cs1.concept_code AS concept_code_1,
	cs2.concept_code AS concept_code_2,
	cs1.vocabulary_id AS vocabulary_id_1,
	cs2.vocabulary_id AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage cs1
JOIN inv_master im1 ON im1.concept_code = cs1.concept_code
JOIN inv_master im2 ON im2.code = im1.parent_code
JOIN concept_stage cs2 ON cs2.concept_code = im2.concept_code;

--10. Cleanup
DROP TABLE inv_syn;
DROP TABLE inv_rx_map;
DROP TABLE inv_master;

--At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
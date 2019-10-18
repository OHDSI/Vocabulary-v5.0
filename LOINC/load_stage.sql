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
* Authors: Polina Talapova, Dmitry Dymshyts, Timur Vakhitov, Christian Reich
* Date: 2019
**************************************************************************/


/*
 Latest update: new concept_class_id added (Has system (LOINC) instead of SNOMED 'Has finding site'
 */

--1. Update a 'latest_update' field to a new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'LOINC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.loinc LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.loinc LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_LOINC'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--Prepare tables
--TODO: Add relationships instead of SNOMED concepts
--Some concepts should be inserted before other load_stage
INSERT INTO concept(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES
       (2100000000, 'LOINC System', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000001, 'LOINC Component', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000002, 'LOINC Scale', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000003, 'LOINC Time', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000004, 'LOINC Method', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000005, 'LOINC Property', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000006, 'LOINC Attribute', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000007, 'Has system (LOINC)', 'Metadata', 'Relationship', 'Relationship', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL);


INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id) VALUES
('LOINC System', 'LOINC System', 2100000000),
('LOINC Component', 'LOINC Component', 2100000001),
('LOINC Scale', 'LOINC Scale', 2100000002),
('LOINC Time', 'LOINC Time', 2100000003),
('LOINC Method', 'LOINC Method', 2100000004),
('LOINC Property', 'LOINC Property', 2100000005),
('LOINC Attribute', 'LOINC Attribute', 2100000006)
;

INSERT INTO relationship(relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id) VALUES
('Has system', 'Has system (LOINC)', 0, 0, 'System of', 2100000007),
('System of', 'System of (LOINC)', 0, 0, 'Has system', 2100000008);

--3. Load LOINC concepts indicating Measurements or Observations from a source table of 'sources.loinc' into the CONCEPT_STAGE
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
SELECT CASE
		WHEN loinc_num = '66678-4'
			AND property = 'Hx'
			THEN 'History of Diabetes (regardless of treatment) [PhenX]'
		WHEN loinc_num = '82312-0'
			THEN 'History of ' || REPLACE(long_common_name, 'andor', 'and/or')
		WHEN property = 'Hx'
			AND long_common_name !~* 'hx|histor|reported|status|narrative|^do you|^have you|^does|^has |education|why you|timing|virtuoso|maestro|grade|received|cause|allergies|in the past'
			THEN 'History of ' || long_common_name
		ELSE long_common_name -- AVOF-819
		END AS concept_name,
	CASE
		WHEN CLASSTYPE IN (
				'1',
				'2'
				)
			AND (
				survey_quest_text ~ '\?' -- manually defined source attributes indicating the 'Observation' domain
				OR scale_typ = 'Set'
				OR property IN (
					'Hx',
					'Addr',
					'Anat',
					'ClockTime',
					'Date',
					'DateRange',
					'Desc',
					'EmailAddr',
					'Instrct',
					'Loc',
					'Pn',
					'Tele',
					'TmStp',
					'TmStpRange',
					'Txt',
					'URI',
					'Xad',
					'Bib'
					)
				OR (
					property = 'ID'
					AND system IN (
						'^BPU',
						'^Patient',
						'Vaccine'
						)
					)
				OR system IN (
					'^Family member',
					'^Neighborhood',
					'^Brother',
					'^Daughter',
					'^Sister',
					'^Son',
					'^CCD',
					'^Census tract',
					'^Clinical trial protocol',
					'^Community',
					'*',
					'?',
					'^Contact',
					'^Donor',
					'^Emergency contact',
					'^Event',
					'^Facility',
					'Provider',
					'Report',
					'Repository',
					'School',
					'Surgical procedure'
					)
				OR (
					system IN (
						'^Patient',
						'*^Patient'
						)
					AND (
						scale_typ IN (
							'Doc',
							'Nar',
							'Nom',
							'Ord',
							'OrdQn'
							)
						AND (
							method_typ NOT IN ('Apgar')
							OR method_typ IS NULL
							)
						OR property IN (
							'Arb',
							'Imp',
							'NRat',
							'Num',
							'PrThr',
							'RelRto',
							'Time',
							'Type',
							'Find'
							)
						AND class NOT IN (
							'COAG',
							'PULM'
							)
						)
					)
				)
			AND (
				long_common_name !~* 'scale|score'
				OR long_common_name ~* 'interpretation|rose dyspnea scale'
				)
			AND (
				method_typ != 'Measured'
				OR method_typ IS NULL
				)
			AND loinc_num NOT IN (
				'65712-2',
				'65713-0'
				)
			THEN 'Observation' -- AVOF-1579
		WHEN CLASSTYPE = '1'
			THEN 'Measurement'
		WHEN CLASSTYPE = '2'
			THEN 'Measurement'
		WHEN CLASSTYPE = '3'
			THEN 'Observation'
		WHEN CLASSTYPE = '4'
			THEN 'Observation'
		END AS domain_id,
	v.vocabulary_id,
	CASE
		WHEN CLASSTYPE IN (
				'1',
				'2'
				)
			AND (
				survey_quest_text ~ '\?' -- manually defined source attributes indicating the 'Clinical Observation' concept class
				OR scale_typ = 'Set'
				OR property IN (
					'Hx',
					'Addr',
					'Anat',
					'ClockTime',
					'Date',
					'DateRange',
					'Desc',
					'EmailAddr',
					'Instrct',
					'Loc',
					'Pn',
					'Tele',
					'TmStp',
					'TmStpRange',
					'Txt',
					'URI',
					'Xad',
					'Bib'
					)
				OR (
					property = 'ID'
					AND system IN (
						'^BPU',
						'^Patient',
						'Vaccine'
						)
					)
				OR system IN (
					'^Family member',
					'^Neighborhood',
					'^Brother',
					'^Daughter',
					'^Sister',
					'^Son',
					'^CCD',
					'^Census tract',
					'^Clinical trial protocol',
					'^Community',
					'*',
					'?',
					'^Contact',
					'^Donor',
					'^Emergency contact',
					'^Event',
					'^Facility',
					'Provider',
					'Report',
					'Repository',
					'School',
					'Surgical procedure'
					)
				OR (
					system IN (
						'^Patient',
						'*^Patient'
						)
					AND (
						scale_typ IN (
							'Doc',
							'Nar',
							'Nom',
							'Ord',
							'OrdQn'
							)
						AND (
							method_typ NOT IN ('Apgar')
							OR method_typ IS NULL
							)
						OR property IN (
							'Arb',
							'Imp',
							'NRat',
							'Num',
							'PrThr',
							'RelRto',
							'Time',
							'Type',
							'Find'
							)
						AND class NOT IN (
							'COAG',
							'PULM'
							)
						)
					)
				)
			AND (
				long_common_name !~* 'scale|score'
				OR long_common_name ~* 'interpretation|rose dyspnea scale'
				)
			AND (
				method_typ != 'Measured'
				OR method_typ IS NULL
				)
			AND loinc_num NOT IN (
				'65712-2',
				'65713-0'
				)
			THEN 'Clinical Observation' -- AVOF-1579
		WHEN CLASSTYPE = '1'
			THEN 'Lab Test'
		WHEN CLASSTYPE = '2'
			THEN 'Clinical Observation'
		WHEN CLASSTYPE = '3'
			THEN 'Claims Attachment'
		WHEN CLASSTYPE = '4'
			THEN 'Survey'
		END AS concept_class_id,
	'S' AS standard_concept,
	LOINC_NUM AS concept_code,
	COALESCE(c.valid_start_date, v.latest_update) AS valid_start_date,
	CASE
		WHEN STATUS IN (
				'DISCOURAGED',
				'DEPRECATED'
				)
			THEN CASE
					WHEN C.VALID_END_DATE > V.LATEST_UPDATE
						OR C.VALID_END_DATE IS NULL
						THEN V.LATEST_UPDATE
					ELSE C.VALID_END_DATE
					END
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE
		WHEN EXISTS (
				SELECT 1
				FROM sources.map_to m
				WHERE m.loinc = l.loinc_num
				)
			THEN 'U'
		WHEN STATUS = 'DISCOURAGED'
			THEN 'D'
		WHEN STATUS = 'DEPRECATED'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason
FROM sources.loinc l
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
LEFT JOIN concept c ON c.concept_code = l.LOINC_NUM
	AND c.vocabulary_id = 'LOINC';


--4. Add LOINC Classes from a manual table of 'sources.loinc_class' into the CONCEPT_STAGE
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
SELECT concept_name,
	CASE
		WHEN concept_name ~* 'history|report|document|miscellaneous|public health' -- manually defined word patterns indicating the 'Observation' domain
			THEN 'Observation'
		ELSE domain_id
		END, -- AVOF-1579
	vocabulary_id,
	concept_class_id,
	'C',
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM sources.loinc_class -- 300

UNION ALL

-- add missed 'Document Ontology' LOINC Class (AVOF-757)
SELECT 'Document Ontology' AS concept_name,
	'Observation' AS domain_id,
	'LOINC' AS vocabulary_id,
	'LOINC Class' AS concept_class_id,
	'C' AS standard_concept,
	'DOC.ONTOLOGY' AS concept_code,
	'1970-01-01' AS valid_start_date,
	'2099-12-31' AS valid_end_date,
	NULL AS invalid_reason;

--5. Add LOINC Parts concepts
--First part of LOINC parts going from loinc_partlink
--TODO: Define concept classes we want to use. Possible actions:
/*
   1) Define concept classes according to parttypename (there are more than 6 actually)
   2) Let it be LOINC Hierarchy for concepts coming from sources.loinc_hierarchy table and according to parttypename for the rest
*/
with s AS (
SELECT DISTINCT pl.PartNumber, p.PartDisplayName, pl.parttypename, p.status
FROM sources.loinc_partlink pl
JOIN sources.loinc_part p
ON pl.PartNumber = p.PartNumber
WHERE pl.LinkTypeName IN ('Primary')    --or any other too if required
  AND pl.PartTypeName IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')

    UNION ALL

--The rest is from loinc_hierarchy
SELECT DISTINCT p.partnumber, p.partdisplayname, p.parttypename, p.status
FROM sources.loinc_hierarchy lh
JOIN sources.loinc_part p
ON lh.code = p.partnumber
WHERE code LIKE 'LP%'
AND p.parttypename != 'CLASS'

    UNION ALL

--427 codes not found in loinc_part, but present in loinc_hierarchy
--TODO: We need special concept_class_id for these concepts cause we an't retrieve any from loinc_partlink
SELECT lh.code, lh.code, 'LOINC Hierarchy','ACTIVE'
FROM sources.loinc_hierarchy lh
WHERE code LIKE 'LP%'
  AND code_text !~ ' \| '
AND trim(code) NOT IN (SELECT trim(partnumber) FROM sources.loinc_part)
)

INSERT INTO concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT trim(s.PartDisplayName) AS concept_name,
                CASE
		WHEN (
				PartDisplayName ~* 'directive|^age\s+|lifetime risk|alert|attachment|\s+date|comment|\s+note|consent|identifier|\s+time|\s+number' -- manually defined word patterns indicating the 'Observation' domain
				OR PartDisplayName ~* 'date and time|coding system|interpretation|status|\s+name|\s+report|\s+id$|s+id\s+|version|instruction|known exposure|priority|ordered|available|requested|issued|flowsheet|\s+term'
				OR PartDisplayName ~* 'reported|not yet categorized|performed|risk factor|device|administration|\s+route$|suggestion|recommended|narrative|ICD code|reference'
				OR PartDisplayName ~* 'reviewed|information|intention|^Reason for|^Received|Recommend|provider|subject|summary|time\s+'
				)
			AND PartDisplayName !~* 'thrombin time|clotting time|bleeding time|clot formation|kaolin activated time|closure time|protein feed time|Recalcification time|reptilase time|russell viper venom time'
			AND PartDisplayName !~* 'implanted device|dosage\.vial|isolate|within lymph node|cancer specimen|tumor|chromosome|inversion|bioavailable'
			THEN 'Observation'
		ELSE 'Measurement'                              --Implementing the same logic
		END AS domain_id,
                'LOINC' AS vocabulary_id,
--TODO: Add following concept classes for LOINC Parts
                CASE WHEN s.parttypename = 'SYSTEM' THEN 'LOINC System'
                     WHEN s.parttypename = 'METHOD' THEN 'LOINC Method'
                     WHEN s.parttypename = 'PROPERTY' THEN 'LOINC Property'
                     WHEN s.parttypename = 'TIME' THEN 'LOINC Time'
                     WHEN s.parttypename = 'COMPONENT' THEN 'LOINC Component'
                     WHEN s.parttypename = 'SCALE' THEN 'LOINC Scale'
                     ELSE 'LOINC Hierarchy'             --To use for 427 concepts that can't be found in loinc_part
                     END AS concept_class_id,
                'C' AS standard_concept,                --Classification
                s.PartNumber AS concept_code,
                '1970-01-01'::date as valid_start_date, --Valid start date should be the date of last update
                CASE WHEN s.status != 'ACTIVE' THEN '2019-12-31'::date ELSE '2099-12-31' END as valid_end_date, --TODO: Define valid_end_date
                CASE WHEN s.status != 'ACTIVE' THEN 'D' ELSE NULL END AS invalid_reason    --For deprecated concepts
FROM s
;
select * from sources.loinc_hierarchy where code LIKE 'LP%' and code_text !~ ' \| '
and trim (code) not in (select trim (partnumber) from sources.loinc_part );
--6. Build 'Subsumes' relationships from LOINC Ancestors to Descendants using a source table of 'sources.loinc_hierarchy'
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT immediate_parent AS concept_code_1, -- LOINC Ancestor
	code AS concept_code_2, -- LOINC Descendant
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_hierarchy
WHERE immediate_parent IS NOT NULL;-- when immediate parent is null then there is no Ancestor

--7. Build 'Subsumes' relationships between LOINC Classes using a source table of 'sources.loinc_class' and a similarity of a class name beginning (ancestor class_name LIKE descendant class_name || '%').
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT l2.concept_code AS concept_code_1, -- LOINC Class Ancestor
	l1.concept_code AS concept_code_2, -- LOINC Class Descendant
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_class l1,
	sources.loinc_class l2
WHERE l1.concept_code LIKE l2.concept_code || '%'
	AND l1.concept_code <> l2.concept_code

UNION ALL

--add 'Subsumes' relationship from 'Document' ('DOC') to 'Document Ontology' Class ('DOC.ONTOLOGY') manually to embed the 'Document Ontology' hierarchical branch to the Document Hierarchy (AVOF-757)
SELECT 'DOC' AS concept_code_1,
	'DOC.ONTOLOGY' AS concept_code_2,
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason;

--8. Build 'Subsumes' relationships from LOINC Classes to LOINC concepts indicating Measurements or Observations with the use of source tables of 'sources.loinc_class' and  'sources.loinc' to create Multiaxial Hierarchy
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT l.class AS concept_code_1, -- LOINC Class concept
	l.loinc_num AS concept_code_2, -- LOINC Observation/Measurement concept
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_class lc,
	sources.loinc l
WHERE lc.concept_code = l.class;

--8.1 Delete wrong relationship between ‘PANEL.H' class (History & Physical order set) and 38213-5 'FLACC pain assessment panel' (AVOF-352)
DELETE
FROM concept_relationship_stage
WHERE concept_code_1 = 'PANEL.H' || chr(38) || 'P' -- '&' = chr(38)
	AND concept_code_2 = '38213-5'
	AND relationship_id = 'Subsumes';



--ADD concept_relationships FOR NEW LOINC ATTRIBUTES
--TODO: Make sure we are able to use SNOMED relationship or new relationship_id required
--TODO: Maybe add relationships for concepts from loinc_hierarchy table also?
WITH s AS (SELECT DISTINCT loincnumber, p.PartNumber, p.PartTypeName
           FROM sources.loinc_partlink pl
           JOIN sources.loinc_part p
           ON pl.PartNumber = p.PartNumber
           WHERE pl.LinkTypeName IN ('Primary')
           AND pl.PartTypeName IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
           AND pl.PartNumber IN (SELECT DISTINCT concept_code FROM concept_stage)
           AND loincnumber IN (SELECT DISTINCT concept_code FROM concept_stage)
           )

INSERT INTO concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT s.loincnumber AS concept_code_1,
                partnumber AS concept_code_2,
                'LOINC' AS vocabulary_id_1,
                'LOINC' AS vocabulary_id_2,
                CASE WHEN s.parttypename = 'SYSTEM' THEN 'Has system'
                     WHEN s.parttypename = 'METHOD' THEN 'Has method'
                     WHEN s.parttypename = 'PROPERTY' THEN 'Has property'
                     WHEN s.parttypename = 'TIME' THEN 'Has time aspect'
                     WHEN s.parttypename = 'COMPONENT' THEN 'Has component'
                     WHEN s.parttypename = 'SCALE' THEN 'Has scale type'
                     END AS relationship_id,
                '1970-01-01'::date as valid_start_date, --Valid start date should be the date of last update
                '2099-12-31'::date as valid_end_date,
                NULL AS invalid_reason
FROM s
ORDER BY concept_code_1;


--9. Add to the CONCEPT_SYNONYM_STAGE all synonymic names from a source table of 'sources.loinc'
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	) (
	--values of a 'RelatedNames2' field
	SELECT loinc_num AS synonym_concept_code,
	SUBSTR(relatednames2, 1, 1000) AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc WHERE relatednames2 IS NOT NULL

UNION

	-- values of a 'consumer_name' field that were previously used as preferred name (in 195 cases)
	SELECT LOINC_NUM AS synonym_concept_code,
	consumer_name AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc WHERE consumer_name IS NOT NULL

UNION

	-- values of the 'ShortName' field
	SELECT loinc_num AS synonym_concept_code,
	shortname AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc WHERE shortname IS NOT NULL

UNION

	--  'long_common_name' field  values which were changed ('History of')
	SELECT loinc_num AS synonym_concept_code,
	long_common_name AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc WHERE long_common_name NOT IN (
		SELECT concept_name
		FROM concept_stage
		)
	);-- NB! We do not add synonyms for LOINC Answers (a 'description' field) due to their vague formulation


--Inserting synonyms for concepts where PartName != PartDisplayName
with s AS (SELECT DISTINCT pl.PartNumber, p.PartName
FROM sources.loinc_partlink pl
JOIN sources.loinc_part p
ON pl.PartNumber = p.PartNumber
WHERE pl.LinkTypeName IN ('Primary')
  AND pl.PartTypeName IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
AND pl.PartNumber IN (SELECT DISTINCT concept_code FROM concept_stage WHERE concept_code IS NOT NULL)
AND pl.PartName != p.PartDisplayName
and p.partnumber NOT IN (SELECT DISTINCT synonym_concept_code FROM concept_synonym_stage WHERE synonym_concept_code IS NOT NULL))

INSERT INTO concept_synonym_stage (synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id)
SELECT DISTINCT s.PartName AS synonym_name,
    s.PartNumber AS synonym_concept_code,
    'LOINC' AS synonym_vocabulary_id,
    4180186 AS language_concept_id      --English language
FROM s
;

--10. Add LOINC Answers from 'sources.loinc_answerslist' and 'sources.loinc_answerslistlink' source tables to the CONCEPT_STAGE
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
SELECT DISTINCT trim(ans_l.displaytext) AS concept_name,
	'Meas Value' AS domain_id,
	'LOINC' AS vocabulary_id,
	'Answer' AS concept_class_id,
	'S' AS standard_concept,
	ans_l.answerstringid AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_answerslist ans_l -- Answer containing table
JOIN sources.loinc_answerslistlink ans_l_l ON ans_l_l.answerlistid = ans_l.answerlistid -- 'AnswerListID' field unites Answers with Questions
JOIN sources.loinc l ON l.loinc_num = ans_l_l.loincnumber -- to confirm the connection of 'AnswerListID' with LOINC concepts indicating Measurements and Observations (currently all of them are connected)
WHERE ans_l.answerstringid IS NOT NULL;--'AnswerStringID' value may be null

--11.  Build 'Has Answer' relationships from LOINC Questions to Answers with the use of such source tables as 'sources.loinc_answerslist' and 'sources.loinc_answerslistlink'
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT ans_l_l.loincnumber AS concept_code_1, -- LOINC Question code
	ans_l.answerstringid AS concept_code_2, -- LOINC Answer code
	'Has Answer' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_answerslist ans_l -- Answer containing table
JOIN sources.loinc_answerslistlink ans_l_l ON ans_l_l.answerlistid = ans_l.answerlistid -- 'AnswerListID' field unites Answers with Questions
WHERE ans_l.answerstringid IS NOT NULL;-- 'AnswerStringID' may be empty

--12. Build 'Panel contains' relationships from LOINC Panels to their descendants with the use of 'sources.loinc_forms' table
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT parentloinc AS concept_code_1, -- LOINC Panel code
	loinc AS concept_code_2, -- LOINC Descendant code
	'Panel contains' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_forms -- Panel containing table
WHERE loinc <> parentloinc;-- to exclude cases when parents and children are represented by the same concepts

--13. Build 'LOINC - SNOMED eq' relationships from LOINC Measurements to '45767644 LOINC Code System' SNOMED concept with the use of a 'sources.scccrefset_expressionassociation_int' table (mappings)
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT l.maptarget AS concept_code_1, -- LOINC code
	l.referencedcomponentid AS concept_code_2, -- SNOMED code
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'LOINC - SNOMED eq' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.scccrefset_expressionassociation_int l,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC';

--14. Build 'LOINC - CPT4 eq' relationships (mappings) from LOINC Measurements to CPT4 Measurements or Procedures with the use of a 'sources.cpt_mrsmap' table (mappings)
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT l.fromexpr AS concept_code_1, -- LOINC code
	UNNEST(STRING_TO_ARRAY(l.toexpr, ',')) AS concept_code_2, -- CPT4 code
	'LOINC' AS vocabulary_id_1,
	'CPT4' AS vocabulary_id_2,
	'LOINC - CPT4 eq' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.cpt_mrsmap l,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC';

--15. Build 'Concept replaced by' relationships for updated LOINC concepts and deprecate already existing replacing mappings with the use of a 'sources.map_to' table
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT l.loinc AS concept_code_1, -- updated LOINC concept
	l.map_to AS concept_code_2, -- replacing LOINC concept
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	'Concept replaced by' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.map_to l,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC'

UNION ALL

--for some pairs of concepts LOINC gives us a reverse mapping 'Concept replaced by' so we need to deprecate such old mappings
SELECT c1.concept_code,
	c2.concept_code,
	c1.vocabulary_id,
	c2.vocabulary_id,
	r.relationship_id,
	r.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'LOINC'
			AND latest_update IS NOT NULL
		),
	'D'
FROM concept c1,
	concept c2,
	concept_relationship r,
	sources.map_to mt
WHERE c1.concept_id = r.concept_id_1
	AND c2.concept_id = r.concept_id_2
	AND c1.vocabulary_id = 'LOINC'
	AND c2.vocabulary_id = 'LOINC'
	AND r.relationship_id IN (
		'Concept replaced by',
		'Maps to'
		)
	AND r.invalid_reason IS NULL
	AND mt.map_to = c1.concept_code
	AND mt.loinc = c2.concept_code;

--16. Add LOINC Document Ontology concepts with the use of a 'sources.loinc_documentontology' table to the CONCEPT_STAGE
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
SELECT DISTINCT d.partname AS concept_name, -- LOINC Document name
	'Meas Value' AS domain_id,
	'LOINC' AS vocabulary_id,
	CASE d.parttypename
		WHEN 'Document.TypeOfService'
			THEN 'Doc Type of Service'
		WHEN 'Document.SubjectMatterDomain'
			THEN 'Doc Subject Matter'
		WHEN 'Document.Role'
			THEN 'Doc Role'
		WHEN 'Document.Setting'
			THEN 'Doc Setting'
		WHEN 'Document.Kind'
			THEN 'Doc Kind'
		END AS concept_class_id,
	'S' AS standard_concept, -- LOINC Document code
	d.partnumber AS concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_documentontology d,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC'
	AND d.partname NOT LIKE '{%}';-- decision to exclude  LP173061-5 '{Settings}' and LP187187-2 '{Role}' PartNames was probably made due to vague reverse relationship formulations: Concept X 'Has setting' '{Setting}' or Concept Y 'Has role' {Role}.

--17. Build ‘Has type of service’, ‘Has subject matter', 'Has role’, ‘Has setting', 'Has kind’ reverse relationships from LOINC concepts indicating Measurements or Observations to LOINC Document Ontology concepts
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT d.loincnumber AS concept_code_1, -- LOINC Meas/Obs code
	d.partnumber AS concept_code_2, -- LOINC Document code
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	CASE d.parttypename
		WHEN 'Document.TypeOfService'
			THEN 'Has type of service'
		WHEN 'Document.SubjectMatterDomain'
			THEN 'Has subject matter'
		WHEN 'Document.Role'
			THEN 'Has role'
		WHEN 'Document.Setting'
			THEN 'Has setting'
		WHEN 'Document.Kind'
			THEN 'Has kind'
		END AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_documentontology d,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC'
	AND d.partname NOT LIKE '{%}';

--18. Add hierarchical LOINC Group Category and Group concepts to the CONCEPT_STAGE
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
--add LOINC Group Categories
SELECT DISTINCT lgt.category AS concept_name, -- LOINC Category name from sources.loinc_grouploincterms
	'Measurement' AS domain_id,
	v.vocabulary_id AS vocabulary_id,
	'LOINC Group' AS concept_class_id,
	'C' AS standard_concept,
	lg.parentgroupid AS concept_code, -- LOINC Category code from sources.loinc_group
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_group lg -- table with codes of LOINC Category concepts
JOIN sources.loinc_grouploincterms lgt ON lg.groupid = lgt.groupid -- table with names of LOINC Category concepts
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
WHERE lgt.category IS NOT NULL

UNION ALL

--add LOINC Groups
SELECT trim(lg.lgroup) AS concept_name, -- LOINC Group name
	'Measurement' AS domain_id,
	v.vocabulary_id AS vocabulary_id,
	'LOINC Group' AS concept_class_id,
	'C' AS standard_concept,
	lg.groupid AS concept_code, -- LOINC Group code
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_group lg
JOIN vocabulary v ON v.vocabulary_id = 'LOINC';

--19. Build 'Is a' relationships to create a hierarchy for LOINC Group Categories and Groups
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
-- from LOINC concepts indicating Measurements and Observations to LOINC Groups using sources.loinc_grouploincterms
SELECT lgt.loincnumber AS concept_code_1, -- LOINC Observation or Measurement concepts
	lgt.groupid AS concept_code_2, --LOINC Group code
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_grouploincterms lgt
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
JOIN concept_stage cs1 ON cs1.concept_code = lgt.groupid --LOINC Group code
JOIN concept_stage cs2 ON cs2.concept_code = lgt.loincnumber -- LOINC Observation or Measurement concepts

UNION ALL

--from LOINC Groups to LOINC Group Categories using sources.loinc_group
SELECT lg.groupid AS concept_code_1, -- LOINC Group code as a descendant
	lg.parentgroupid AS concept_code_2, -- LOINC Group Category code as an ancestor
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_group lg
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
JOIN concept_stage cs1 ON cs1.concept_code = lg.parentgroupid -- LOINC Group Category code
JOIN concept_stage cs2 ON cs2.concept_code = lg.groupid;-- LOINC Group code

--20. Add LOINC Group Categories and Groups to the CONCEPT_SYNONYM_STAGE
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
-- add proper name of LOINC Group Categories and Groups (probably to simplify perception of their long descriptions)
SELECT cs.concept_code AS synonym_concept_code, -- proper name of LOINC Group Categories and Groups
	cs.concept_name AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM concept_stage cs
WHERE cs.concept_class_id = 'LOINC Group'

UNION

-- add long descriptions of LOINC Group Categories and Groups
SELECT lpga.parentgroupid AS synonym_concept_code, -- LOINC Group Category code
	SUBSTR(lpga.lvalue, 1, 1000) AS synonym_name, -- long description of LOINC Group Categories
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM sources.loinc_parentgroupattributes lpga;-- table with descriptions of LOINC Group Categories

--21. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--22. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--23. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--24. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script

--*******************************************
--**********RUN CHECKS FROM QA FILE**********
--*******************************************

--GenericUpdate; devv5 - static variable
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

select * from QA_TESTS.GET_CHECKS();
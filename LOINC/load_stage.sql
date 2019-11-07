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
* Authors: Oleg Zhuk, Polina Talapova, Dmitry Dymshyts, Alexander Davydov, Timur Vakhitov, Christian Reich
* Date: 2019
**************************************************************************/

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
--RUN PRELOAD_STAGE

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
FROM sources.loinc_class

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

--5. Add LOINC Attributes ('Parts') and LOINC Hierarchy concepts into the CONCEPT_STAGE
-- pick Primary LOINC Parts
INSERT INTO concept_stage
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
WITH s AS
(
SELECT DISTINCT pl.PartNumber, p.PartDisplayName, pl.parttypename, p.status
FROM sources.loinc_partlink pl -- contains links between LOINC Measurements/Observations AND LOINC Parts
JOIN sources.loinc_part p -- contains LOINC Parts and defines their validity ('status' field)
ON pl.PartNumber = p.PartNumber
WHERE pl.LinkTypeName IN ('Primary')
  AND pl.PartTypeName IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE') -- list of Primary LOINC Parts

    UNION ALL
-- pick LOINC Hierarchy concepts (Attributive Panels, non-primary Parts and 427 Undefined attributes)
SELECT DISTINCT code,
       COALESCE(p.partdisplayname,code_text) AS PartDisplayName,
       'LOINC Hierarchy' AS parttypename,
       CASE
         WHEN p.status IS NOT NULL THEN p.status
         ELSE 'ACTIVE'
       END AS status
FROM sources.loinc_hierarchy lh
  LEFT JOIN sources.loinc_part p --  to get a validity of concept ( a 'status' field)
ON lh.code = p.partnumber -- LOINC Attribute
WHERE code LIKE 'LP%' -- all LOINC Hierсrchy concepts have 'LP' at the beginning of the names (including 427 undefined concepts and LOINC panels)
AND   TRIM(code) NOT IN (SELECT TRIM(partnumber)
                         FROM sources.loinc_partlink pl
                         WHERE pl.LinkTypeName = 'Primary'
                         AND   pl.PartTypeName IN ('SYSTEM','METHOD','PROPERTY','TIME','COMPONENT','SCALE')) --  pick non-primary Parts and 427 Undefined attributes (excluding Primary LOINC Parts)
)
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
		ELSE 'Measurement'  -- AVOF-1579
		END AS domain_id,
                'LOINC' AS vocabulary_id,
                CASE WHEN s.parttypename = 'SYSTEM' THEN 'LOINC System'
                     WHEN s.parttypename = 'METHOD' THEN 'LOINC Method'
                     WHEN s.parttypename = 'PROPERTY' THEN 'LOINC Property'
                     WHEN s.parttypename = 'TIME' THEN 'LOINC Time'
                     WHEN s.parttypename = 'COMPONENT' THEN 'LOINC Component'
                     WHEN s.parttypename = 'SCALE' THEN 'LOINC Scale'
                     ELSE 'LOINC Hierarchy'
                     END AS concept_class_id,
  		CASE WHEN s.parttypename = 'LOINC Hierarchy' THEN 'C' ELSE NULL END AS standard_concept, --  LOINC Hierarchy concepts should be 'Classification', LOINC Attributes - 'Non-standard'
                s.PartNumber AS concept_code, -- LOINC Attribute or Hierarchy concept
                COALESCE(c.valid_start_date, v.latest_update) AS valid_start_date,-- preserve the 'devv5.valid_start_date' for already existing concepts
                CASE WHEN s.status = 'DEPRECATED' THEN CASE WHEN c.valid_end_date < latest_update THEN c.valid_end_date -- preserve 'devv5.valid_end_date' for already existing DEPRECATED concepts
                     ELSE GREATEST(COALESCE(c.valid_start_date, v.latest_update),   -- assign LOINC 'latest_update' as 'valid_end_date' for new concepts which have to be deprecated in the current release
                     latest_update-1) END   -- assign LOINC 'latest_update-1' as 'valid_end_date' for already existing concepts, which have to be deprecated in the current release
                     ELSE to_date('20991231', 'yyyymmdd') END as valid_end_date,-- default value of 31-Dec-2099 for the rest
                CASE WHEN s.status = 'ACTIVE' THEN NULL  -- define concept validity according to the 'status' field
                     WHEN s.status = 'DEPRECATED' THEN 'D'
                    ELSE 'X' END AS invalid_reason    --IF there are any changes in LOINC source we don't know about. GenericUpdate() will fail in case of 'X' in invalid_reason field
FROM s
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
LEFT JOIN concept c ON c.concept_code = s.PartNumber -- already existing LOINC concepts
	AND c.vocabulary_id = 'LOINC';

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
WHERE immediate_parent IS NOT NULL; -- when immediate parent is null then there is no Ancestor

--7. Build 'Has system', 'Has method', 'Has property', 'Has time aspect', 'Has component', and 'Has scale type' relationships from LOINC Measurements/Observations to Primary LOINC Parts (attributes)
-- assign specific links using a TYPE of LOINC Part using 'sources.loinc_partlink'
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
WITH s AS
(
  SELECT DISTINCT loincnumber, -- LOINC Measurement/Observation
         p.PartNumber,-- Primary LOINC Part
         p.status,
         CASE
           WHEN p.parttypename = 'SYSTEM' THEN 'Has system'
           WHEN p.parttypename = 'METHOD' THEN 'Has method'
           WHEN p.parttypename = 'PROPERTY' THEN 'Has property'
           WHEN p.parttypename = 'TIME' THEN 'Has time aspect'
           WHEN p.parttypename = 'COMPONENT' THEN 'Has component'
           WHEN p.parttypename = 'SCALE' THEN 'Has scale type'
         END AS relationship_id
  FROM sources.loinc_partlink pl
    JOIN sources.loinc_part p ON pl.PartNumber = p.PartNumber -- Primary LOINC Part
  WHERE pl.LinkTypeName IN ('Primary')
),
-- pick already existing relationships between LOINC Measurements/Observations and Primary LOINC Parts
    cr
AS
(SELECT DISTINCT c.concept_code AS concept_code_1, -- LOINC Measurement/Observation
       c.vocabulary_id,
       relationship_id,
       cc.concept_code AS concept_code_2, -- -- Primary LOINC Part ?
       cc.vocabulary_id,
       cr.valid_start_date,
       cr.valid_end_date,
       cr.invalid_reason
FROM concept_relationship cr
  JOIN concept c ON cr.concept_id_1 = c.concept_id
  JOIN concept cc ON cr.concept_id_2 = cc.concept_id
WHERE c.vocabulary_id = 'LOINC'
AND   cc.vocabulary_id = 'LOINC')
SELECT DISTINCT s.loincnumber AS concept_code_1,
                partnumber AS concept_code_2,
                'LOINC' AS vocabulary_id_1,
                'LOINC' AS vocabulary_id_2,
                s.relationship_id AS relationship_id,
                COALESCE (cr.valid_start_date, --  preserve 'devv5.valid_start_date' for already existing relationships
                LEAST (c.valid_end_date, cc.valid_end_date,   v.latest_update)) AS valid_start_date,  -- compare and assign earliest date of  'valid_end_date' of a LOINC concept AS 'valid_start_date' for NEW relationships of concepts deprecated in the current release OR  'latest update' for the rest of the codes
                CASE WHEN cr.valid_end_date < v.latest_update THEN cr.valid_end_date -- preserve 'devv5.valid_end_date' for already existing relationships
                WHEN (c.invalid_reason IS NOT NULL) OR (cc.invalid_reason IS NOT NULL) THEN LEAST(c.valid_end_date, cc.valid_end_date)  -- compare and assign earliest date of 'valid_end_date' of a LOINC concept as 'valid_end_date' for NEW relationships of concepts deprecated in the current release
                ELSE '2099-12-31'::date END as valid_end_date, -- for the rest of the codes
                CASE WHEN (c.invalid_reason IS NOT NULL) OR (cc.invalid_reason IS NOT NULL) THEN 'D'
                ELSE NULL END AS invalid_reason
FROM s
  LEFT JOIN concept_stage c -- to define deprecated LOINC Observations/Measurements in the current release
         ON c.concept_code = s.loincnumber --  LOINC Observation/Measurement in the current release
        AND c.vocabulary_id = 'LOINC'
  LEFT JOIN concept_stage cc -- to define deprecated LOINC Parts
  ON cc.concept_code = s.partnumber -- LOINC Part
  LEFT JOIN cr ON (cr.concept_code_1,cr.relationship_id,cr.concept_code_2) = (s.loincnumber,s.relationship_id,s.partnumber) -- already existing relationships between LOINC concepts
  JOIN vocabulary v ON v.vocabulary_id = 'LOINC';

--8. Build 'Subsumes' relationships between LOINC Classes using a source table of 'sources.loinc_class' and a similarity of a class name beginning (ancestor class_name LIKE descendant class_name || '%').
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

--9. Build 'Subsumes' relationships from LOINC Classes to LOINC concepts indicating Measurements or Observations with the use of source tables of 'sources.loinc_class' and  'sources.loinc' to create Multiaxial Hierarchy
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

--9.1 Delete wrong relationship between 'PANEL.H' class (History & Physical order set) and 38213-5 'FLACC pain assessment panel' (AVOF-352)
DELETE
FROM concept_relationship_stage
WHERE concept_code_1 = 'PANEL.H' || chr(38) || 'P' -- '&' = chr(38)
	AND concept_code_2 = '38213-5'
	AND relationship_id = 'Subsumes';

--9.2 Mark wrong relationships between updated or deprecated concepts
--TODO: For updated concepts check if there are concept_relationships
DROP TABLE a;

CREATE TABLE a AS (SELECT DISTINCT concept_code_1,
                           concept_code_2,
                           relationship_id,
                           least(cs.valid_end_date, css.valid_end_date) AS valid_end_date
           FROM concept_relationship_stage cr
                    JOIN concept_stage cs
                         ON cr.concept_code_1 = cs.concept_code
                    JOIN concept_stage css
                         ON cr.concept_code_2 = css.concept_code
           WHERE (cr.invalid_reason IS NULL AND (cs.invalid_reason IS NOT NULL OR css.invalid_reason IS NOT NULL)));

with a AS (SELECT DISTINCT concept_code_1,
                           concept_code_2,
                           relationship_id,
                           least(cs.valid_end_date, css.valid_end_date) AS valid_end_date
           FROM concept_relationship_stage cr
                    JOIN concept_stage cs
                         ON cr.concept_code_1 = cs.concept_code
                    JOIN concept_stage css
                         ON cr.concept_code_2 = css.concept_code
           WHERE (cr.invalid_reason IS NULL AND (cs.invalid_reason IS NOT NULL OR css.invalid_reason IS NOT NULL))
)

UPDATE concept_relationship_stage cr
    SET invalid_reason = 'D', valid_end_date = a.valid_end_date
FROM a
WHERE (cr.concept_code_1, cr.concept_code_2, cr.relationship_id) = (a.concept_code_1, a.concept_code_2, a.relationship_id);


SELECT * FROM concept_relationship_stage cr
    JOIN a
        ON (cr.concept_code_1, cr.concept_code_2, cr.relationship_id) = (a.concept_code_1, a.concept_code_2, a.relationship_id);

--10.1 Add to the CONCEPT_SYNONYM_STAGE all synonymic names from a source table of 'sources.loinc'
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
	SELECT loinc_num AS synonym_concept_code,
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
	)-- NB! We do not add synonyms for LOINC Answers (a 'description' field) due to their vague formulation
UNION
--  'PartName' field values which are synonyms for 'PartDisplayName' field values in sources.loinc_part
	SELECT DISTINCT
   	 pl.PartNumber AS synonym_concept_code,
	p.PartName AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
    	4180186 AS language_concept_id      --English language
	FROM sources.loinc_partlink pl
	JOIN sources.loinc_part p
	ON pl.PartNumber = p.PartNumber
	WHERE pl.PartNumber IN (SELECT concept_code FROM concept_stage)
	AND pl.PartName != p.PartDisplayName;  -- pick only different names
;

--11. Add LOINC Answers from 'sources.loinc_answerslist' and 'sources.loinc_answerslistlink' source tables to the CONCEPT_STAGE
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

--12.  Build 'Has Answer' relationships from LOINC Questions to Answers with the use of such source tables as 'sources.loinc_answerslist' and 'sources.loinc_answerslistlink'
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

--13. Build 'Panel contains' relationships from LOINC Panels to their descendants with the use of 'sources.loinc_forms' table
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

--14.1 Build 'LOINC - SNOMED eq' relationships between LOINC Attributes and SNOMED Attributes
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
SELECT DISTINCT maptarget AS concept_code_1, -- LOINC Attribute code
	referencedcomponentid AS concept_code_2, -- SNOMED Attribute code
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'LOINC - SNOMED eq' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
	FROM sources.scccrefset_mapcorrorfull_int
	JOIN devv5.concept c  ON maptarget = c.concept_code   -- LOINC Attribute
  JOIN devv5.concept d  ON referencedcomponentid = d.concept_code -- SNOMED  Attribute
  JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id -- valid_start_date
  WHERE c.vocabulary_id = 'LOINC' AND c.standard_concept = 'C' and c.invalid_reason is null
  AND d.vocabulary_id = 'SNOMED' AND d.invalid_reason IS NULL
;

-- 14.2 Build relationships between LOINC Measurements and respective SNOMED attributes given by the table of 'sources.scccrefset_expressionassociation_int'
-- Note, that some suggested by LOINC relationship_ids ('Characterizes', 'Units', 'Relative to', 'Process agent' 'Inherent location') are useless in the context of a mapping to SNOMED.
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
-- extract LOINC Measurement codes, LOINC-to-SNOMED relationship_id identifiers and related SNOMED Attributes from sources.scccrefset_expressionassociation_int
WITH t1 AS
(SELECT maptarget, -- LOINC Measurement code
       SPLIT_PART(REGEXP_REPLACE(REGEXP_SPLIT_TO_TABLE(expression,','),'^\d+:',''),'=',1) AS sn_comp2, -- LOINC to SNOMED relationship_id identifier
       SPLIT_PART(REGEXP_REPLACE(REGEXP_SPLIT_TO_TABLE(expression,','),'^\d+:',''),'=',2) AS sn_comp3 -- related SNOMED Attribute
FROM sources.scccrefset_expressionassociation_int)

SELECT DISTINCT maptarget AS concept_code_1,-- LOINC Measurement code
c3.concept_code AS concept_code_2, -- SNOMED Attribute code
'LOINC' AS vocabulary_id_1,
'SNOMED' AS vocabulary_id_2,
CASE WHEN c2.concept_name in ( 'Time aspect', 'Process duration')  THEN 'Has time aspect'
WHEN c2.concept_name in ('Component','Process output') THEN 'Has component'
WHEN c2.concept_name = 'Direct site' THEN 'Has dir proc site'
WHEN c2.concept_name = 'Inheres in' THEN 'Inheres in'
WHEN c2.concept_name = 'Property type' THEN 'Has property type'
WHEN c2.concept_name = 'Scale type' THEN 'Has scale type'
WHEN c2.concept_name = 'Technique' THEN 'Has technique'
WHEN c2.concept_name = 'Precondition' THEN 'Has precondition'
END  AS relationship_Id,
v.latest_update AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM t1 a
  JOIN devv5.concept c1 ON maptarget = c1.concept_code -- LOINC Lab test
  JOIN devv5.concept c2 ON sn_comp2 = c2.concept_code -- LOINC to SNOMED relationship_id identifier
  JOIN devv5.concept c3 ON c3.concept_code = sn_comp3  -- SNOMED Attribute
  JOIN vocabulary v ON c1.vocabulary_id = v.vocabulary_id
WHERE  c1.invalid_reason IS NULL AND c1.vocabulary_id = 'LOINC'
  AND c2.vocabulary_id = 'SNOMED'
  AND c3.vocabulary_id = 'SNOMED'
AND c3.invalid_reason IS NULL AND c2.concept_name IN ('Time aspect','Process duration','Component','Process output','Direct site','Inheres in','Property type','Scale type','Technique', 'Precondition')
;

-- 14.3 Build 'Is a' from LOINC Measurements to SNOMED Measurements in CONCEPT_RELATIONSHIP_STAGE to create a hierarchical cross-walks;
-- 14.3.1 create temporary tables with SNOMED and LOINC attribute pools
---- 'sn_attr' contains normalized set of SNOMED Measurements and respective attributes, taking into account useful relationship_ids and STATUS of SNOMED concepts (pick only Fully defined ones)
DROP TABLE IF EXISTS sn_attr;
CREATE TABLE sn_attr
AS
(WITH t1
AS
((SELECT *
FROM (SELECT c.concept_code AS sn_code,
             c.concept_name AS sn_name,
             r.relationship_id,
             d.concept_code AS attr_code,
             d.concept_name AS attr_name,
             COUNT(1) OVER (PARTITION BY c.concept_code,r.relationship_id) AS cnt
      FROM concept c
        JOIN concept_relationship r
          ON c.concept_id = concept_id_1
         AND r.invalid_reason IS NULL
        JOIN concept d ON d.concept_id = concept_id_2
      WHERE c.vocabulary_id = 'SNOMED'
      AND   c.domain_id = 'Measurement'
      AND   c.standard_concept = 'S'
      AND   d.vocabulary_id = 'SNOMED'
      AND   r.concept_id_1 NOT IN (SELECT concept_id_1
                                   FROM concept_relationship
                                   WHERE relationship_id IN ('Has intent','Has measurement'))
      AND   relationship_id IN ('Has component','Has scale type','Has specimen','Has dir proc site','Inheres in')) kk
WHERE cnt = 1)),-- exclude concepts with multiple attributes from one category
-- get a list of Fully defined SNOMED concepts, using sources.sct2_concept_full_merged, to weed out Primitive SNOMED Measurements composed of inadequate attribute set
def_status AS
(SELECT DISTINCT c.concept_code,
       FIRST_VALUE(f.statusid) OVER (PARTITION BY f.id ORDER BY f.effectivetime DESC) AS statusid -- the 'statusid' field may be both Fully define and Primitive at the same time, to distinguish Fully define ones use 'effectivetime' field
       FROM sources.sct2_concept_full_merged f -- the source table indicating 'definition status' of SNOMED concepts
  JOIN concept c ON c.vocabulary_id = 'SNOMED' AND c.standard_concept = 'S'
   AND c.concept_code = CAST (f.id AS VARCHAR)),
snomed_concept AS (SELECT * FROM def_status WHERE statusid = 900000000000073002)
SELECT zz.*  FROM t1 zz
 JOIN snomed_concept kk ON kk.concept_code = zz.sn_code
 WHERE zz.sn_code not in ('104193001','104194007','104178000','370990004','401298000','399177007','399193003','115253009','395129003','409613001',
                          '399143002','115340009','430925007','104568008','121806006','445132000', '104326007', '104323004', '697001', '413058006') -- SNOMED concepts with wrong sets of attributes
AND sn_name !~* 'screening'
);

-- create an index for the temporary table of 'sn_attr' to speed up next table creation
DROP INDEX if exists l_attr_name;
CREATE index l_attr_name ON sn_attr (LOWER (attr_name));
ANALYZE sn_attr;

-- 'LC_ATTR' contains normalized set of relationships between LOINC Measurements and SNOMED Attributes
DROP TABLE IF EXISTS lc_attr;
CREATE TABLE lc_attr
AS
 (
-- AXIS 1: build links between TOP-6 LOINC Systems or 'Quantitative'/'Qualitative' Scales AND respective SNOMED Attributes
WITH lc_attr_add AS
(
 SELECT
    c.concept_code as lc_code,
    c.concept_name as lc_name,
     CASE  WHEN r1.concept_code_2 not in ( 'LP7753-9', 'LP7751-3') THEN 'Has dir proc site' ELSE 'Has scale type' END AS relationship_id,
     CASE WHEN r1.concept_code_2 IN ('LP7057-5', 'LP21304-8', 'LP7068-2', 'LP185760-8', 'LP7536-8', 'LP7576-4', 'LP7578-0',  'LP7579-8', 'LP7067-4', 'LP7073-2') --  'Bld', 'Bld.dot', 'BldC', 'Plas/Bld', 'Ser/Plas/Bld',  'Ser/Plas', 'Ser/Plas.ultracentrifugate', 'RBC'
      THEN '119297000' -- 	Blood specimen
WHEN r1.concept_code_2 = 'LP7567-3' THEN '119364003' -- Serum specimen
WHEN r1.concept_code_2 = 'LP7681-2' THEN '122575003' -- Urine specimen
WHEN r1.concept_code_2 = 'LP7156-5' THEN '258450006' --  Cerebrospinal fluid sample
WHEN r1.concept_code_2 = 'LP7479-1' THEN '119361006' -- Plasma specimen
WHEN r1.concept_code_2 = 'LP7604-4' THEN '119339001' -- Stool specimen
WHEN r1.concept_code_2 = 'LP7753-9' THEN '30766002' -- Quantitative
WHEN r1.concept_code_2 = 'LP7751-3' THEN '26716007' -- Qualitative
END AS attr_code
FROM concept_stage c
  JOIN concept_relationship_stage r1 ON (concept_code_1,vocabulary_id_1) = (c.concept_code,c.vocabulary_id) -- LOINC Measurement
 AND c.vocabulary_id = 'LOINC' and c.domain_id = 'Measurement' and c.invalid_reason is null and c.standard_concept = 'S'
 AND concept_code_2 IN ('LP7057-5','LP21304-8','LP7068-2','LP185760-8','LP7536-8','LP7576-4','LP7578-0','LP7579-8','LP7567-3','LP7681-2','LP7156-5','LP7479-1','LP7604-4', 'LP7753-9', 'LP7067-4', 'LP7073-2', 'LP7751-3') -- list of needful LOINC Parts (System and Scale)
 AND r1.relationship_id in ( 'Has system', 'Has scale type')
),
-- AXIS 2: get links given by the source between LOINC Measurements and SNOMED Attributes
lc_sn AS
(SELECT concept_code_1 AS lc_code,
       lc.concept_name AS lc_name,
       r1.relationship_id,
       concept_code_2 AS attr_code
FROM concept_relationship_stage r1
  JOIN concept lc  ON (lc.concept_code,lc.vocabulary_id) = (r1.concept_code_1,r1.vocabulary_id_1) -- LOINC Measurement
   AND r1.vocabulary_id_1 = 'LOINC' and lc.standard_concept = 'S' and lc.invalid_reason is null and lc.domain_id = 'Measurement'
  JOIN concept la ON (la.concept_code,la.vocabulary_id) = (r1.concept_code_2,r1.vocabulary_id_2) -- SNOMED Attribute
   AND r1.vocabulary_id_2 = 'SNOMED' and la.invalid_reason is null
     AND r1.relationship_id IN ('Has component', 'Has dir proc site', 'Inheres in', 'Has scale type') -- list of useful relationship_ids
   WHERE (concept_code_1, r1.relationship_id) not in (select lc_code, relationship_id from lc_attr_add) -- to exclude duplicates
   ),
-- AXIS 3: build links between LOINC Measurements and SNOMED Attributes using given by the source mappings of LOINC Attributes to SNOMED Attributes
lc_attr_1 AS
(
SELECT DISTINCT l2.concept_code AS lc_code,
       l2.concept_name AS lc_name,
       'Has component' AS relationship_id,
       la.concept_code AS attr_code
FROM concept_relationship_stage r1
  JOIN concept_stage lc
    ON (lc.concept_code,lc.vocabulary_id) = (r1.concept_code_1,r1.vocabulary_id_1) -- LOINC Component
   AND r1.vocabulary_id_1 = 'LOINC' and concept_class_id = 'LOINC Component'
   JOIN concept la
    ON (la.concept_code,la.vocabulary_id) = (r1.concept_code_2,r1.vocabulary_id_2) -- SNOMED Attribute
   AND r1.vocabulary_id_2 = 'SNOMED'
      AND r1.relationship_id = 'LOINC - SNOMED eq' and la.concept_class_id  = 'Substance'
 JOIN concept_relationship_stage x1
   ON (x1.concept_code_1,x1.vocabulary_id_1) = (lc.concept_code,lc.vocabulary_id)-- LOINC Component
   AND x1.relationship_id = 'Subsumes' --  LOINC Component 'Subsumes' LOINC Panel
 JOIN concept_relationship_stage x2
    ON (x2.concept_code_1,x2.vocabulary_id_1) = (x1.concept_code_2,x1.vocabulary_id_2) -- LOINC Panel
    AND x2.relationship_id = 'Subsumes' -- LOINC Panel 'Subsumes' LOINC Measurement
 JOIN concept_stage l2  on (l2.concept_code, l2.vocabulary_id) = (x2.concept_code_2, x2.vocabulary_id_2) -- LOINC Measurement
   AND l2.vocabulary_id = 'LOINC'
   AND l2.standard_concept = 'S' and  l2.standard_concept = 'S' and l2.invalid_reason is null
   AND l2.domain_id = 'Measurement'
   WHERE (l2.concept_code, 'Has component') not in (select lc_code, relationship_id from lc_sn)
   ),
-- AXIS 4: build links between LOINC Measurements and SNOMED Attributes using Components of LOINC Measurements and name similarity of SNOMED Attributes
lc_attr_2 AS (
SELECT DISTINCT r1.concept_code_1 AS lc_code,
       lc.concept_name AS lc_name, -- preserved for word-pattern filtering
       r1.relationship_id,
       x1.attr_code AS attr_code
FROM concept_relationship_stage r1
  JOIN concept_stage lc
    ON (lc.concept_code,lc.vocabulary_id) = (r1.concept_code_1,r1.vocabulary_id_1) -- LOINC Measurement
   AND r1.vocabulary_id_1 = 'LOINC' and lc.standard_concept = 'S' AND lc.invalid_reason IS NULL AND lc.domain_id = 'Measurement'
  JOIN concept_stage la
    ON (la.concept_code,la.vocabulary_id) = (r1.concept_code_2,r1.vocabulary_id_2) -- LOINC Component
   AND r1.vocabulary_id_2 = 'LOINC'
   AND r1.relationship_id = 'Has component'
   JOIN sn_attr x1 on (
   LOWER (SPLIT_PART (la.concept_name,'.',1)) = LOWER (x1.attr_name)
   OR LOWER (SPLIT_PART (la.concept_name,'^',1)) = LOWER (x1.attr_name)) -- SNOMED Attribute
   WHERE  (r1.concept_code_1, r1.relationship_id) not in (select lc_code, relationship_id from lc_sn)
AND  (r1.concept_code_1, r1.relationship_id) not in  (select lc_code, relationship_id from lc_attr_1) -- exclude duplicates
)
-- get input
SELECT DISTINCT lc_code, lc_name, relationship_id, attr_code
FROM (SELECT * FROM lc_attr_add
UNION ALL
SELECT * FROM lc_sn
UNION ALL
SELECT * FROM lc_attr_1
UNION ALL
SELECT * FROM lc_attr_2) lc
-- weed out LOINC Measurements with inapplicable properties in the SNOMED architecture context
 JOIN sources.loinc j
    ON j.loinc_num = lc.lc_code
   AND j.property !~ 'Rto|Ratio|^\w.Fr|Imp|Prid|Zscore|Susc|^-$'-- exclude ratio/interpretation/identifier/z-score/susceptibility-related concepts
WHERE lc_name !~* 'susceptibility|protein\.monoclonal') -- susceptibility may have property other than 'Susc'
;

DROP INDEX if exists sn_attr_idx;
CREATE index sn_attr_idx ON sn_attr (attr_code);
ANALYZE sn_attr;

DROP INDEX if exists sn_code_1;
create index sn_code_1 on sn_attr (sn_code);
ANALYZE sn_attr;

DROP INDEX if exists lc_code_1;
create index lc_code_1 on lc_attr (lc_code);
ANALYZE lc_attr;

--14.3.2 Build hierarchical links of 'Is a' from LOINC Measurements to SNOMED Measurements in CONCEPT_RELATIONSHIP_STAGE using common attribute combinations (top-down)
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
	-- AXIS 1: get 3-attribute Measurements (Component+Specimen+Scale)
WITH ax_1 AS
(
  SELECT DISTINCT z4.lc_code,
       z4.lc_name, -- to preserve names for word-pattern filtering
       x3.sn_code,
       x3.sn_name
FROM sn_attr x1 -- X1 - SNOMED attribute pool
  JOIN lc_attr z1 -- Z1 - LOINC attribute pool
    ON x1.attr_code = z1.attr_code -- common Component
   AND x1.relationship_id = 'Has component'
   AND z1.relationship_id =  'Has component'
  JOIN sn_attr x2
  ON x2.sn_code = x1.sn_code -- common 2-attribute SNOMED Measurement
  JOIN lc_attr z2
    ON x2.attr_code = z2.attr_code -- common Site
   AND z2.relationship_id IN ('Has dir proc site', 'Inheres in') -- given by the source relationships indicating SNOMED Specimens
   AND x2.relationship_id = 'Has specimen'
  JOIN sn_attr x3
  ON x3.sn_code = x2.sn_code -- common 3-attribute SNOMED Measurement
  JOIN lc_attr z3
    ON z3.attr_code = x3.attr_code -- common Scale
   AND z3.relationship_id = 'Has scale type'
   AND x3.relationship_id = 'Has scale type'
  JOIN lc_attr z4
    ON z4.lc_code = z3.lc_code
   AND z4.lc_code = z2.lc_code
   AND z4.lc_code = z1.lc_code -- common 3-attribute LOINC Measurement
WHERE x1.sn_code IN (SELECT sn_code
                     FROM sn_attr
                     GROUP BY sn_code
                     HAVING COUNT(1) = 3) -- to restrict SNOMED attribute pool
),
-- AXIS 2: get 2-attribute Measurements (Component+Specimen)
ax_2
AS
(SELECT DISTINCT z3.lc_code,
       z3.lc_name,
       x2.sn_code,
       x2.sn_name
FROM sn_attr x1 -- X1 - SNOMED attribute pool
  JOIN lc_attr z1 -- Z1 - LOINC attribute pool
    ON x1.attr_code = z1.attr_code -- common Component
   AND x1.relationship_id = 'Has component'
   AND z1.relationship_id = 'Has component'
  JOIN sn_attr x2 ON x2.sn_code = x1.sn_code -- common 2-attribute SNOMED Measurement
  JOIN lc_attr z2
    ON x2.attr_code = z2.attr_code -- common Site
   AND z2.relationship_id IN ('Has dir proc site', 'Inheres in') -- given by the source relationships indicating SNOMED Specimens
   AND x2.relationship_id IN ('Has specimen')
  JOIN lc_attr z3
    ON z3.lc_code = z2.lc_code
   AND z3.lc_code = z1.lc_code  -- common 2-attribute LOINC Measurement
WHERE x1.sn_code IN (SELECT sn_code
                     FROM sn_attr
                     GROUP BY sn_code
                     HAVING COUNT(1) = 2) -- to restrict SNOMED attribute pool
AND   z3.lc_code NOT IN (SELECT lc_code FROM ax_1) -- exclude duplicates
),
-- AXIS 3: get 2-attribute Measurements (Component+Scale)
ax_3 AS (
SELECT DISTINCT z3.lc_code,
       z3.lc_name,
       x2.sn_code,
       x2.sn_name
FROM sn_attr x1 --X1 - SNOMED attribute pool
  JOIN lc_attr z1 -- Z1 - LOINC attribute pool
    ON  x1.attr_code = z1.attr_code -- common Component
   AND x1.relationship_id = 'Has component'
   AND z1.relationship_id = 'Has component'
  JOIN sn_attr x2 ON x2.sn_code = x1.sn_code -- common 2-attribute SNOMED Measurement
  JOIN lc_attr z2
    ON x2.attr_code = z2.attr_code -- common Scale
   AND z2.relationship_id = 'Has scale type'
   AND x2.relationship_id = 'Has scale type'
  JOIN lc_attr z3
    ON z3.lc_code = z2.lc_code
   AND z3.lc_code = z1.lc_code  -- common 2-attribute LOINC Measurement
WHERE x1.sn_code IN (SELECT sn_code
                     FROM sn_attr
                     GROUP BY sn_code
                     HAVING COUNT(1) = 2) -- to restrict SNOMED attribute pool
AND   z3.lc_code NOT IN (SELECT lc_code FROM ax_1) -- exclude duplicates
),
-- AXIS 4: get 1-attribute Measurements (Component)
ax_4
AS
(SELECT DISTINCT z1.lc_code,
       z1.lc_name,
       x1.sn_code,
       x1.sn_name
FROM sn_attr x1 --X1 - SNOMED attribute pool
  JOIN lc_attr z1 -- Z1 - LOINC attribute pool
    ON x1.attr_code = z1.attr_code-- common Component
   AND x1.relationship_id = 'Has component'
   AND z1.relationship_id = 'Has component'
WHERE x1.sn_code IN (SELECT sn_code
                     FROM sn_attr
                     GROUP BY sn_code
                     HAVING COUNT(1) = 1) -- to restrict SNOMED attribute pool
AND   z1.lc_code NOT IN (SELECT lc_code FROM ax_1)
AND   z1.lc_code NOT IN (SELECT lc_code FROM ax_2)
AND   z1.lc_code NOT IN (SELECT lc_code FROM ax_3) -- exclude duplicates
 ),
-- unite all AXES
 all_ax
AS
(SELECT * FROM ax_1
UNION
SELECT * FROM ax_2
UNION
SELECT * FROM ax_3
UNION
SELECT * FROM ax_4)
-- get input for CONCEPT_RELATIONSHIP_STAGE
SELECT lc_code AS concept_code_1,
--lc_name,
       sn_code AS concept_code_2,
--   sn_name,
       'LOINC' AS vocabulary_id_1,
       'SNOMED' AS vocabulary_id_2,
       'Is a'  AS relationship_id,
       v.latest_update AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM all_ax
JOIN vocabulary v ON 'LOINC' = v.vocabulary_id -- to get latest update
 -- get rid of wrong SNOMED concepts with the same sets of attributes
WHERE (lc_code,sn_code) NOT IN (
        SELECT lc_code, sn_code FROM all_ax
        WHERE sn_name ~* 'dipstick' AND lc_name !~* 'test strip'
        OR (lc_name ~* 'titer|presence' AND sn_name ~* ' level')
        OR (lc_name !~* 'titer' AND sn_name ~* ' titer')
        OR (lc_name ~* '\/' AND sn_name ~* ' titer')
        OR (lc_name !~* 'count|100|#' AND sn_name ~* 'count')
        OR  (lc_name ~* 'morpholog|presence' AND sn_name ~* 'count')
        OR (lc_name !~* 'fasting glucose' AND sn_name ~* 'fasting glucose')
        OR  (lc_name !~* 'microscop' AND sn_name ~* 'microscop')
        OR (lc_name !~* 'culture|isolate' AND sn_name ~* 'culture')
 )
-- note, some LOINC Measurements may be mapped to 2 SNOMED Measurements
AND (lc_code,sn_code) NOT  IN (SELECT lc_code,sn_code
                            FROM all_ax
                            WHERE lc_code IN (SELECT lc_code FROM all_ax GROUP BY lc_code HAVING COUNT(1) > 1)
                            AND   (lc_name ~* 'fasting glucose' AND sn_name !~* 'fasting glucose' OR lc_name ~* 'test strip' AND sn_name !~* 'dipstick')
                            AND   (lc_code,sn_code) NOT IN (SELECT lc_code,sn_code FROM all_ax WHERE sn_name ~* 'quantitative')
				)
;

--14.4 Build hierarchical links 'Is a' from LOINC Lab Tests to SNOMED Measurements with the use of LOINC Component - SNOMED Attribute name similarity in CONCEPT_RELATIONSHIP_STAGE
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
SELECT DISTINCT l1.concept_code AS concept_code_1,
                s1.concept_code AS concept_code_2,
                'LOINC' AS vocabulary_id_1,
                'SNOMED' AS vocabulary_id_2,
                'Is a' AS relationship_id,
                v.latest_update AS valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                NULL AS invalid_reason
-- get LOINC Components for all LOINC Measurements
FROM concept_relationship_stage r
JOIN concept_stage l1 ON (r.concept_code_1, r.vocabulary_id_1) = (l1.concept_code, l1.vocabulary_id)  -- LOINC Measurement
AND l1.vocabulary_id = 'LOINC' AND l1.standard_concept = 'S' AND l1.invalid_reason is null
JOIN concept_stage l2 ON (r.concept_code_2, r.vocabulary_id_2) = (l2.concept_code, l2.vocabulary_id) -- LOINC Component
AND r.relationship_id = 'Has component' AND r.vocabulary_id_1 = 'LOINC'
AND r.vocabulary_id_2 = 'LOINC'
-- get SNOMED Measurements using name similarity (LOINC Component||' measurement' = SNOMED Measurement)
JOIN concept s1 ON
COALESCE (
LOWER (SPLIT_PART (l2.concept_name,'^',1))||' measurement', LOWER (SPLIT_PART (l2.concept_name,'.',1))||' measurement', lower (l2.concept_name)||' measurement'
          )  = lower (s1.concept_name) -- SNOMED Measurement
AND s1.vocabulary_id = 'SNOMED' AND s1.domain_id = 'Measurement' AND s1.standard_concept = 'S'
JOIN vocabulary v ON 'LOINC' = v.vocabulary_id -- get valid_start_date
-- weed out LOINC Measurements with inapplicable properties in the SNOMED architecture context
JOIN sources.loinc j ON l1.concept_code = j.loinc_num
   AND j.property !~ 'Rto|Ratio|^\w.Fr|Imp|Prid|Zscore|Susc|^-$'-- ratio/interpretation/identifier/z-score/susceptibility-related concepts
WHERE l1.concept_name !~* 'susceptibility|protein\.monoclonal' -- susceptibility may have property other than 'Susc'
AND s1.concept_code NOT IN ('16298007', '24683000') -- 'Rate measurement', 'Uptake measurement'
AND l1.concept_code NOT IN (SELECT concept_code_1 FROM concept_relationship_stage WHERE relationship_id = 'Is a' and vocabulary_id_2 = 'SNOMED'); -- exclude duplicates

--14.5 drop temporary tables
DROP TABLE if exists sn_attr;
DROP TABLE if exists lc_attr;

--15. Build 'LOINC - CPT4 eq' relationships (mappings) from LOINC Measurements to CPT4 Measurements or Procedures with the use of a 'sources.cpt_mrsmap' table (mappings)
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

--16. Build 'Concept replaced by' relationships for updated LOINC concepts and deprecate already existing replacing mappings with the use of a 'sources.map_to' table
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

--17. Add LOINC Document Ontology concepts with the use of a 'sources.loinc_documentontology' table to the CONCEPT_STAGE
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

--18. Build 'Has type of service', 'Has subject matter', 'Has role', 'Has setting', 'Has kind' reverse relationships from LOINC concepts indicating Measurements or Observations to LOINC Document Ontology concepts
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

--19. Add hierarchical LOINC Group Category and Group concepts to the CONCEPT_STAGE
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
SELECT DISTINCT trim (lgt.category) AS concept_name, -- LOINC Category name from sources.loinc_grouploincterms
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
SELECT trim (lg.lgroup) AS concept_name, -- LOINC Group name
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

--20. Build 'Is a' relationships to create a hierarchy for LOINC Group Categories and Groups
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

--21. Add LOINC Group Categories and Groups to the CONCEPT_SYNONYM_STAGE
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

--22. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--23. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--24. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--25. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
-----------------------------------------
-----------------------------------------
/*
--  Add NEW concept_classes and relationships into the CONCEPT table  (Is it correct to do it in this way?)
INSERT INTO concept(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES
       (2100000000, 'LOINC System', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000001, 'LOINC Component', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000002, 'LOINC Scale', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000003, 'LOINC Time', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000004, 'LOINC Method', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000005, 'LOINC Property', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
     (2100000006, 'Has system', 'Metadata', 'Relationship', 'Relationship', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
     (2100000007, 'System of', 'Metadata', 'Relationship', 'Relationship', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL);

INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id) VALUES
('LOINC System', 'LOINC System', 2100000000),
('LOINC Component', 'LOINC Component', 2100000001),
('LOINC Scale', 'LOINC Scale', 2100000002),
('LOINC Time', 'LOINC Time', 2100000003),
('LOINC Method', 'LOINC Method', 2100000004),
('LOINC Property', 'LOINC Property', 2100000005)
;

INSERT INTO relationship(relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
VALUES ( 'Has system', 'Has system', 0, 0, 'System of', 2100000006),
('System of', 'System of', 0, 0, 'Has system', 2100000007);*/

--NOT THIS ONE
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

--checks
select * from QA_TESTS.GET_CHECKS();

SELECT devv5.FastRecreateSchema(include_concept_ancestor=>true,include_deprecated_rels=>true,include_synonyms=>true);

WITH t1 AS
(
  SELECT concept_code
  FROM devv5.concept
  WHERE vocabulary_id = 'LOINC'
  AND   concept_code ~ '^LP|^LA' EXCEPT SELECT concept_code FROM dev_loinc.concept_stage WHERE vocabulary_id = 'LOINC'
  AND   concept_code ~ '^LP|^LA'
)
SELECT concept_id_1,
       c.concept_name AS lc_name_1,
       r.relationship_id,
       concept_id_2,
       d.concept_name AS lc_name_2,
       d.invalid_reason AS lc_inv_reas,
       r.invalid_reason AS cr_inv_reas
FROM t1 x
  JOIN devv5.concept c
    ON x.concept_code = c.concept_code
   AND c.vocabulary_id = 'LOINC'
  LEFT JOIN devv5.concept_relationship r ON c.concept_id = r.concept_id_1
  LEFT JOIN devv5.concept d
         ON d.concept_id = r.concept_id_2
        AND d.vocabulary_id = 'LOINC'
--and d.invalid_reason is not null
WHERE r.relationship_id IN ('Is a','Subsumes')
AND   r.invalid_reason IS NULL;



select c1.concept_code, c1.concept_name , c1.concept_class_id, c1.invalid_reason , r.relationship_id, r.invalid_reason as cr_inv_reas, c2.concept_code, c2.concept_name ,
c2.concept_class_id , c2.invalid_reason
from concept_relationship r
join concept c1 on r.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'LOINC' and c1.concept_class_id in ( 'LOINC Hierarchy', 'LOINC System', 'LOINC Component')
join concept c2 on r.concept_id_2 = c2.concept_id and c2.vocabulary_id = 'LOINC' and c2.concept_class_id in ( 'Claims Attachment', 'Clinical Observation', 'Lab Test', 'LOINC Hierarchy', 'Survey' ,'LOINC Component', 'LOINC System')
and relationship_id = 'Subsumes'
where (c1.concept_code, c2.concept_code) not in (select immediate_parent, code from sources.loinc_hierarchy)
;


SELECT * FROM concept_relationship_stage
WHERE concept_code_2 = 'LP124604-2' AND concept_code_2 = '48176-2';











































DO $_$
	BEGIN
		PERFORM QA_TESTS.Check_Stage_Tables();
	END $_$;

	-- Update concept_id in concept_stage from concept for existing concepts
	UPDATE concept_stage cs
		SET concept_id = c.concept_id
	FROM concept c
	WHERE cs.concept_code = c.concept_code
		AND cs.vocabulary_id = c.vocabulary_id;

	-- ANALYSING
	ANALYSE concept_stage;
	ANALYSE concept_relationship_stage;
	ANALYSE concept_synonym_stage;

	-- 1. Clearing

	-- 1.1 Clearing the concept_name
	--remove double spaces, carriage return, newline, vertical tab and form feed
	UPDATE concept_stage
	SET concept_name = REGEXP_REPLACE(concept_name, '[[:cntrl:]]+', ' ')
	WHERE concept_name ~ '[[:cntrl:]]';

	UPDATE concept_stage
	SET concept_name = REGEXP_REPLACE(concept_name, ' {2,}', ' ')
	WHERE concept_name ~ ' {2,}';

	--remove leading and trailing spaces
	UPDATE concept_stage
	SET concept_name = TRIM(concept_name)
	WHERE concept_name <> TRIM(concept_name)
		AND NOT (
			concept_name = ' '
			AND vocabulary_id = 'GPI'
			);--exclude GPI empty names

	--remove long dashes
	UPDATE concept_stage
	SET concept_name = REPLACE(concept_name, '–', '-')
	WHERE concept_name LIKE '%–%';

	-- 1.2 Clearing the synonym_name
	--remove double spaces, carriage return, newline, vertical tab and form feed
	UPDATE concept_synonym_stage
	SET synonym_name = REGEXP_REPLACE(synonym_name, '[[:cntrl:]]+', ' ')
	WHERE synonym_name ~ '[[:cntrl:]]';

	UPDATE concept_synonym_stage
	SET synonym_name = REGEXP_REPLACE(synonym_name, ' {2,}', ' ')
	WHERE synonym_name ~ ' {2,}';

	--remove leading and trailing spaces
	UPDATE concept_synonym_stage
	SET synonym_name = TRIM(synonym_name)
	WHERE synonym_name <> TRIM(synonym_name)
		AND NOT (
			synonym_name = ' '
			AND synonym_vocabulary_id = 'GPI'
			);--exclude GPI empty names

	--remove long dashes
	UPDATE concept_synonym_stage
	SET synonym_name = REPLACE(synonym_name, '–', '-')
	WHERE synonym_name LIKE '%–%';

	/***************************
	* Update the concept table *
	****************************/

	-- 2. Update existing concept details from concept_stage.
	-- All fields (concept_name, domain_id, concept_class_id, standard_concept, valid_start_date, valid_end_date, invalid_reason) are updated

	-- 2.1. For 'concept_name'
	UPDATE concept c
	SET concept_name = cs.concept_name
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND c.concept_name <> cs.concept_name;

	-- 2.2. For 'domain_id'
	UPDATE concept c
	SET domain_id = cs.domain_id
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND c.domain_id <> cs.domain_id;

	-- 2.3. For 'concept_class_id'
	UPDATE concept c
	SET concept_class_id = cs.concept_class_id
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND c.concept_class_id <> cs.concept_class_id;

	-- 2.4. For 'standard_concept'
	UPDATE concept c
	SET standard_concept = cs.standard_concept
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND COALESCE(c.standard_concept, 'X') <> COALESCE(cs.standard_concept, 'X');

	-- 2.5. For 'valid_start_date'
	UPDATE concept c
	SET valid_start_date = cs.valid_start_date
	FROM concept_stage cs,
		vocabulary v
	WHERE c.concept_id = cs.concept_id
		AND v.vocabulary_id = cs.vocabulary_id
		AND c.valid_start_date <> cs.valid_start_date
		AND cs.valid_start_date <> v.latest_update; -- if we have a real date in concept_stage, use it. If it is only the release date, use the existing

	-- 2.6. For 'valid_end_date'
	UPDATE concept c
	SET valid_end_date = cs.valid_end_date
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND c.valid_end_date <> cs.valid_end_date;

	-- 2.7. For 'invalid_reason'
	UPDATE concept c
	SET invalid_reason = cs.invalid_reason
	FROM concept_stage cs
	WHERE c.concept_id = cs.concept_id
		AND COALESCE(c.invalid_reason, 'X') <> COALESCE(cs.invalid_reason, 'X');

	-- 3. Deprecate concepts missing from concept_stage and are not already deprecated.
	-- This only works for vocabularies where we expect a full set of active concepts in concept_stage.
	-- If the vocabulary only provides changed concepts, this should not be run, and the update information is already dealt with in step 1.
	-- 23-May-2018: new rule for CPT4, ICD9Proc and HCPCS: http://forums.ohdsi.org/t/proposal-to-keep-outdated-standard-concepts-active-and-standard/3695/22 and AVOF-981
	-- 3.1. Update the concept for non-CPT4, non-ICD9Proc and non-HCPCS vocabularies
	UPDATE concept c SET
		invalid_reason = 'D',
		valid_end_date = (SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = c.vocabulary_id)
	WHERE NOT EXISTS (SELECT 1 FROM concept_stage cs WHERE cs.concept_id = c.concept_id AND cs.vocabulary_id = c.vocabulary_id) -- if concept missing from concept_stage
	AND c.vocabulary_id IN (SELECT vocabulary_id FROM vocabulary WHERE latest_update IS NOT NULL) -- only for current vocabularies
	AND c.invalid_reason IS NULL -- not already deprecated
	AND CASE -- all vocabularies that give us a full list of active concepts at each release we can safely assume to deprecate missing ones (THEN 1)
		WHEN c.vocabulary_id = 'SNOMED' THEN 1
		WHEN c.vocabulary_id = 'LOINC' AND c.concept_class_id = 'LOINC Answers' THEN 1 -- Only LOINC answers are full lists
		WHEN c.vocabulary_id = 'LOINC' THEN 1 -- LOINC gives full account of all concepts
		WHEN c.vocabulary_id = 'ICD9CM' THEN 1
		WHEN c.vocabulary_id = 'ICD10' THEN 1
		WHEN c.vocabulary_id = 'RxNorm' THEN 1
		WHEN c.vocabulary_id = 'NDFRT' THEN 1
		WHEN c.vocabulary_id = 'VA Product' THEN 1
		WHEN c.vocabulary_id = 'VA Class' THEN 1
		WHEN c.vocabulary_id = 'ATC' THEN 1
		WHEN c.vocabulary_id = 'NDC' THEN 0
		WHEN c.vocabulary_id = 'SPL' THEN 0
		WHEN c.vocabulary_id = 'MedDRA' THEN 1
		WHEN c.vocabulary_id = 'Read' THEN 1
		WHEN c.vocabulary_id = 'ICD10CM' THEN 1
		WHEN c.vocabulary_id = 'GPI' THEN 1
		WHEN c.vocabulary_id = 'OPCS4' THEN 1
		WHEN c.vocabulary_id = 'MeSH' THEN 1
		WHEN c.vocabulary_id = 'GCN_SEQNO' THEN 1
		WHEN c.vocabulary_id = 'ETC' THEN 1
		WHEN c.vocabulary_id = 'Indication' THEN 1
		WHEN c.vocabulary_id = 'DA_France' THEN 0
		WHEN c.vocabulary_id = 'DPD' THEN 1
		WHEN c.vocabulary_id = 'NFC' THEN 1
		WHEN c.vocabulary_id = 'ICD10PCS' THEN 1
		WHEN c.vocabulary_id = 'EphMRA ATC' THEN 1
		WHEN c.vocabulary_id = 'dm+d' THEN 1
		WHEN c.vocabulary_id = 'RxNorm Extension' THEN 0
		WHEN c.vocabulary_id = 'Gemscript' THEN 1
		WHEN c.vocabulary_id = 'Cost Type' THEN 1
		WHEN c.vocabulary_id = 'BDPM' THEN 1
		WHEN c.vocabulary_id = 'AMT' THEN 1
		WHEN c.vocabulary_id = 'GRR' THEN 0
		WHEN c.vocabulary_id = 'CVX' THEN 1
		WHEN c.vocabulary_id = 'LPD_Australia' THEN 0
		WHEN c.vocabulary_id = 'PPI' THEN 1
		WHEN c.vocabulary_id = 'ICDO3' THEN 1
		WHEN c.vocabulary_id = 'CDT' THEN 1
		WHEN c.vocabulary_id = 'ISBT' THEN 0
		WHEN c.vocabulary_id = 'ISBT Attributes' THEN 0
		WHEN c.vocabulary_id = 'GGR' THEN 1
		WHEN c.vocabulary_id = 'LPD_Belgium' THEN 1
		WHEN c.vocabulary_id = 'APC' THEN 1
		WHEN c.vocabulary_id = 'KDC' THEN 1
		WHEN c.vocabulary_id = 'SUS' THEN 1
		WHEN c.vocabulary_id = 'CDM' THEN 0
		WHEN c.vocabulary_id = 'SNOMED Veterinary' THEN 1
		WHEN c.vocabulary_id = 'OSM' THEN 1
		WHEN c.vocabulary_id = 'US Census' THEN 1
		WHEN c.vocabulary_id = 'HemOnc' THEN 1
		WHEN c.vocabulary_id = 'NAACCR' THEN 1
		WHEN c.vocabulary_id = 'JMDC' THEN 1
		WHEN c.vocabulary_id = 'KCD7' THEN 1
		ELSE 0 -- in default we will not deprecate
	END = 1
	AND c.vocabulary_id NOT IN ('CPT4', 'HCPCS', 'ICD9Proc');

	-- 3.2. Update the concept for CPT4, ICD9Proc and HCPCS
	UPDATE concept c SET
		valid_end_date = (SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = c.vocabulary_id)
	WHERE NOT EXISTS (SELECT 1 FROM concept_stage cs WHERE cs.concept_id = c.concept_id AND cs.vocabulary_id = c.vocabulary_id) -- if concept missing from concept_stage
	AND c.vocabulary_id IN (SELECT vocabulary_id FROM vocabulary WHERE latest_update IS NOT NULL) -- only for current vocabularies
	AND c.valid_end_date = TO_DATE('20991231', 'YYYYMMDD') -- not already deprecated
	AND c.vocabulary_id IN ('CPT4', 'HCPCS', 'ICD9Proc'); /*new rule for these vocabularies: http://forums.ohdsi.org/t/proposal-to-keep-outdated-standard-concepts-active-and-standard/3695/22 and AVOF-981*/

	-- 4. Add new concepts from concept_stage
	-- Create sequence after last valid one
	DO $$
	DECLARE
		ex INTEGER;
	BEGIN
		--SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id<500000000; -- Last valid below HOI concept_id
		DROP SEQUENCE IF EXISTS v5_concept;
		SELECT concept_id + 1 INTO ex FROM (
			SELECT concept_id, next_id, next_id - concept_id - 1 free_concept_ids
			FROM (SELECT concept_id, LEAD (concept_id) OVER (ORDER BY concept_id) next_id FROM concept where concept_id >= 581480 and concept_id < 500000000) AS t
			WHERE concept_id <> next_id - 1 AND next_id - concept_id > (SELECT COUNT (*) FROM concept_stage WHERE concept_id IS NULL)
			ORDER BY next_id - concept_id
			FETCH FIRST 1 ROW ONLY
		) AS sq;
		EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
	END$$;

	INSERT INTO concept (
		concept_id,
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
	SELECT NEXTVAL('v5_concept'),
		cs.concept_name,
		cs.domain_id,
		cs.vocabulary_id,
		cs.concept_class_id,
		cs.standard_concept,
		cs.concept_code,
		cs.valid_start_date,
		cs.valid_end_date,
		cs.invalid_reason
	FROM concept_stage cs
	WHERE cs.concept_id IS NULL;-- new because no concept_id could be found for the concept_code/vocabulary_id combination

	DROP SEQUENCE v5_concept;

	ANALYZE concept;

	-- 5. Make sure that invalid concepts are standard_concept = NULL
	-- 5.1. For non-CPT4, non-ICD9Proc and non-HCPCS vocabularies
	UPDATE concept c
	SET standard_concept = NULL
	WHERE c.invalid_reason IS NOT NULL
		AND c.standard_concept IS NOT NULL
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			) -- only for current vocabularies
		AND c.vocabulary_id NOT IN (
			'CPT4',
			'HCPCS',
			'ICD9Proc'
			);

	-- 5.2. For CPT4, ICD9Proc and HCPCS
	UPDATE concept c
	SET standard_concept = NULL
	WHERE c.invalid_reason IN (
			'D',
			'U'
			)
		AND c.standard_concept IS NOT NULL
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			) -- only for current vocabularies
		AND c.vocabulary_id IN (
			'CPT4',
			'HCPCS',
			'ICD9Proc'
			);

	/****************************************
	* Update the concept_relationship table *
	****************************************/

	-- 6. Turn all relationship records so they are symmetrical if necessary
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
	SELECT crs.concept_code_2,
		crs.concept_code_1,
		crs.vocabulary_id_2,
		crs.vocabulary_id_1,
		r.reverse_relationship_id,
		crs.valid_start_date,
		crs.valid_end_date,
		crs.invalid_reason
	FROM concept_relationship_stage crs
	JOIN relationship r ON r.relationship_id = crs.relationship_id
	WHERE NOT EXISTS (
			-- the inverse record
			SELECT 1
			FROM concept_relationship_stage i
			WHERE crs.concept_code_1 = i.concept_code_2
				AND crs.concept_code_2 = i.concept_code_1
				AND crs.vocabulary_id_1 = i.vocabulary_id_2
				AND crs.vocabulary_id_2 = i.vocabulary_id_1
				AND r.reverse_relationship_id = i.relationship_id
			);

	-- 7. Update all relationships existing in concept_relationship_stage, including undeprecation of formerly deprecated ones
	ANALYZE concept_relationship_stage;

	WITH crs
	AS (
		SELECT c1.concept_id c_id1,
			c2.concept_id c_id2,
			crs.relationship_id,
			crs.valid_end_date,
			crs.invalid_reason
		FROM concept_relationship_stage crs
		JOIN concept c1 ON c1.concept_code = crs.concept_code_1
			AND c1.vocabulary_id = crs.vocabulary_id_1
		JOIN concept c2 ON c2.concept_code = crs.concept_code_2
			AND c2.vocabulary_id = crs.vocabulary_id_2
		)
	UPDATE concept_relationship cr
	SET valid_end_date = crs.valid_end_date,
		invalid_reason = crs.invalid_reason
	FROM crs
	WHERE cr.concept_id_1 = crs.c_id1
		AND cr.concept_id_2 = crs.c_id2
		AND cr.relationship_id = crs.relationship_id
		AND cr.valid_end_date <> crs.valid_end_date;

	-- 8. Deprecate missing relationships, but only if the concepts are fresh. If relationships are missing because of deprecated concepts, leave them intact.
	-- Also, only relationships are considered missing if the combination of vocabulary_id_1, vocabulary_id_2 AND relationship_id is present in concept_relationship_stage
	-- The latter will prevent large-scale deprecations of relationships between vocabularies where the relationship is defined not here, but together with the other vocab

	-- Do the deprecation
	WITH relationships AS (
	SELECT * FROM UNNEST(ARRAY[
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept poss_eq to',
		'Concept was_a to',
		'Maps to']) AS relationship_id
	),
	vocab_combinations as (
		-- Create a list of vocab1, vocab2 and relationship_id existing in concept_relationship_stage, except 'Maps' to and replacement relationships
		-- Also excludes manual mappings from concept_relationship_manual
		SELECT vocabulary_id_1, vocabulary_id_2, relationship_id
		FROM (
			SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM concept_relationship_stage
			EXCEPT
			(
				SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM concept_relationship_manual
				UNION ALL
				--add reverse mappings for exclude
				SELECT concept_code_2, concept_code_1, vocabulary_id_2, vocabulary_id_1, reverse_relationship_id
				FROM concept_relationship_manual JOIN relationship USING (relationship_id)
			)
		) AS s1
		WHERE vocabulary_id_1 NOT IN ('SPL','RxNorm Extension','CDM')
		AND vocabulary_id_2 NOT IN ('SPL','RxNorm Extension','CDM')
		AND relationship_id NOT IN (
			SELECT relationship_id FROM relationships
			UNION ALL
			SELECT reverse_relationship_id FROM relationships JOIN relationship USING (relationship_id)
		)
		GROUP BY vocabulary_id_1, vocabulary_id_2, relationship_id
	)
	UPDATE concept_relationship d
	SET valid_end_date = (SELECT MAX(v.latest_update)-1 FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id),
		invalid_reason = 'D'
	-- Whether the combination of vocab1, vocab2 and relationship exists (in subquery)
	-- (intended to be covered by this particular vocab udpate)
	-- And both concepts exist (don't deprecate relationships of deprecated concepts)
	FROM concept c1, concept c2
	WHERE c1.concept_id = d.concept_id_1 AND c2.concept_id = d.concept_id_2
	AND (c1.vocabulary_id,c2.vocabulary_id,d.relationship_id) IN (SELECT vocabulary_id_1,vocabulary_id_2,relationship_id FROM vocab_combinations)
	AND c1.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
	AND c2.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
	-- And the record is currently fresh and not already deprecated
	AND d.invalid_reason IS NULL
	-- And it was started before or equal the release date
	AND d.valid_start_date <= (
		-- One of latest_update (if we have more than one vocabulary in concept_relationship_stage) may be NULL, therefore use aggregate function MAX() to get one non-null date
		SELECT MAX(v.latest_update) FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id --take both concept ids to get proper latest_update
	)
	-- And it is missing from the new concept_relationship_stage
	AND NOT EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_1=c1.concept_code
		AND crs.vocabulary_id_1=c1.vocabulary_id
		AND crs.concept_code_2=c2.concept_code
		AND crs.vocabulary_id_2=c2.vocabulary_id
		AND crs.relationship_id = d.relationship_id
	);

	--9. Deprecate old 'Maps to', 'Maps to value' and replacement records, but only if we have a new one in concept_relationship_stage with the same source concept
	--part 1 (direct mappings)
	WITH relationships AS (
		SELECT relationship_id FROM relationship
		WHERE relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to',
			'Maps to',
			'Maps to value'
		)
	)
	UPDATE concept_relationship r
	SET valid_end_date  =
			GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update) -1 -- one of latest_update (if we have more than one vocabulary in concept_relationship_stage) may be NULL, therefore use aggregate function MAX() to get one non-null date
				FROM vocabulary v
			WHERE v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id) --take both concept ids to get proper latest_update
			)),
			invalid_reason = 'D'
	FROM concept c1, concept c2, relationships rel
	WHERE r.concept_id_1=c1.concept_id
	AND r.concept_id_2=c2.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id=rel.relationship_id
	AND r.concept_id_1<>r.concept_id_2
	AND EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_1=c1.concept_code
		AND crs.vocabulary_id_1=c1.vocabulary_id
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
		AND (
			crs.vocabulary_id_2=c2.vocabulary_id
			OR (/*AVOF-459*/
				crs.vocabulary_id_2 IN ('RxNorm','RxNorm Extension') AND c2.vocabulary_id IN ('RxNorm','RxNorm Extension')
			)
			OR (/*AVOF-1439*/
				crs.vocabulary_id_2 IN ('SNOMED','SNOMED Veterinary') AND c2.vocabulary_id IN ('SNOMED','SNOMED Veterinary')
			)
		)
	)
	AND NOT EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_1=c1.concept_code
		AND crs.vocabulary_id_1=c1.vocabulary_id
		AND crs.concept_code_2=c2.concept_code
		AND crs.vocabulary_id_2=c2.vocabulary_id
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
	);

	--part 2 (reverse mappings)
	WITH relationships AS (
		SELECT reverse_relationship_id FROM relationship
		WHERE relationship_id in (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to',
			'Maps to',
			'Maps to value'
		)
	)
	UPDATE concept_relationship r
	SET valid_end_date  =
			GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update) -1 -- one of latest_update (if we have more than one vocabulary in concept_relationship_stage) may be NULL, therefore use aggregate function MAX() to get one non-null date
				FROM vocabulary v
			WHERE v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id) --take both concept ids to get proper latest_update
			)),
		invalid_reason = 'D'
	FROM concept c1, concept c2, relationships rel
	WHERE r.concept_id_1=c1.concept_id
	AND r.concept_id_2=c2.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id=rel.reverse_relationship_id
	AND r.concept_id_1<>r.concept_id_2
	AND EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_2=c2.concept_code
		AND crs.vocabulary_id_2=c2.vocabulary_id
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
		AND (
			crs.vocabulary_id_1=c1.vocabulary_id
			OR (/*AVOF-459*/
				crs.vocabulary_id_1 IN ('RxNorm','RxNorm Extension') AND c1.vocabulary_id IN ('RxNorm','RxNorm Extension')
			)
			OR (/*AVOF-1439*/
				crs.vocabulary_id_1 IN ('SNOMED','SNOMED Veterinary') AND c1.vocabulary_id IN ('SNOMED','SNOMED Veterinary')
			)
		)
	)
	AND NOT EXISTS (
		SELECT 1 FROM concept_relationship_stage crs
		WHERE crs.concept_code_1=c1.concept_code
		AND crs.vocabulary_id_1=c1.vocabulary_id
		AND crs.concept_code_2=c2.concept_code
		AND crs.vocabulary_id_2=c2.vocabulary_id
		AND crs.relationship_id=r.relationship_id
		AND crs.invalid_reason IS NULL
	);

	-- 10. Insert new relationships if they don't already exist
	INSERT INTO concept_relationship
	SELECT c1.concept_id AS concept_id_1,
		c2.concept_id AS concept_id_2,
		crs.relationship_id,
		crs.valid_start_date,
		crs.valid_end_date,
		crs.invalid_reason
	FROM concept_relationship_stage crs
	JOIN concept c1 ON c1.concept_code = crs.concept_code_1 AND c1.vocabulary_id = crs.vocabulary_id_1
	JOIN concept c2 ON c2.concept_code = crs.concept_code_2 AND c2.vocabulary_id = crs.vocabulary_id_2
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship cr_int
			WHERE cr_int.concept_id_1 = c1.concept_id
				AND cr_int.concept_id_2 = c2.concept_id
				AND cr_int.relationship_id = crs.relationship_id
			);

	/*********************************************************
	* Update the correct invalid reason in the concept table *
	* This should rarely happen                              *
	*********************************************************/

	-- 11. Make sure invalid_reason = 'U' if we have an active replacement record in the concept_relationship table
	UPDATE concept c
	SET valid_end_date = v.latest_update - 1, -- day before release day
		invalid_reason = 'U',
		standard_concept = NULL
	FROM concept_relationship cr, vocabulary v
	WHERE c.vocabulary_id = v.vocabulary_id
		AND cr.concept_id_1 = c.concept_id
		AND cr.invalid_reason IS NULL
		AND cr.relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to'
			)
		AND v.latest_update IS NOT NULL -- only for current vocabularies
		AND (c.invalid_reason IS NULL OR c.invalid_reason = 'D'); -- not already upgraded

	-- 12. Make sure invalid_reason = 'D' if we have no active replacement record in the concept_relationship table for upgraded concepts
	UPDATE concept c
	SET valid_end_date = (
			SELECT v.latest_update
			FROM vocabulary v
			WHERE c.vocabulary_id = v.vocabulary_id
			) - 1, -- day before release day
		invalid_reason = 'D',
		standard_concept = NULL
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.invalid_reason IS NULL
				AND r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
			)
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			) -- only for current vocabularies
		AND c.invalid_reason = 'U';-- not already deprecated

	-- The following are a bunch of rules for Maps to and Maps from relationships.
	-- Since they work outside the _stage tables, they will be restricted to the vocabularies worked on

	-- 13. 'Maps to' and 'Mapped from' relationships from concepts to self should exist for all concepts where standard_concept = 'S'
	WITH to_be_upserted AS (
		SELECT c.concept_id, v.latest_update, lat.relationship_id
		FROM concept c,	vocabulary v, LATERAL (SELECT case when generate_series=1 then 'Maps to' ELSE 'Mapped from' END AS relationship_id FROM generate_series(1,2)) lat
		WHERE v.vocabulary_id = c.vocabulary_id AND v.latest_update IS NOT NULL AND c.standard_concept = 'S' AND invalid_reason IS NULL
	),
	to_be_updated AS (
		UPDATE concept_relationship cr
		SET invalid_reason = NULL, valid_end_date = TO_DATE ('20991231', 'yyyymmdd')
		FROM to_be_upserted up
		WHERE cr.invalid_reason IS NOT NULL
		AND cr.concept_id_1 = up.concept_id AND cr.concept_id_2 = up.concept_id AND cr.relationship_id = up.relationship_id
		RETURNING cr.*
	)
		INSERT INTO concept_relationship
		SELECT tpu.concept_id, tpu.concept_id, tpu.relationship_id, tpu.latest_update, TO_DATE ('20991231', 'yyyymmdd'), NULL
		FROM to_be_upserted tpu
		WHERE (tpu.concept_id, tpu.concept_id, tpu.relationship_id)
		NOT IN (
			SELECT up.concept_id_1, up.concept_id_2, up.relationship_id FROM to_be_updated up
			UNION ALL
			SELECT cr_int.concept_id_1, cr_int.concept_id_2, cr_int.relationship_id FROM concept_relationship cr_int
			WHERE cr_int.concept_id_1=cr_int.concept_id_2 AND cr_int.relationship_id IN ('Maps to','Mapped from')
		);

	-- 14. 'Maps to' or 'Maps to value' relationships should not exist where
	-- a) the source concept has standard_concept = 'S', unless it is to self
	-- b) the target concept has standard_concept = 'C' or NULL
	-- c) the target concept has invalid_reason='D' or 'U'

	UPDATE concept_relationship r
	SET valid_end_date = GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update)-1 FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id)), -- day before release day or valid_start_date
		invalid_reason = 'D'
	FROM concept c1, concept c2, vocabulary v
	WHERE r.concept_id_1 = c1.concept_id
	AND r.concept_id_2 = c2.concept_id
	AND (
		(c1.standard_concept = 'S' AND c1.concept_id != c2.concept_id) -- rule a)
		OR COALESCE (c2.standard_concept, 'X') != 'S' -- rule b)
		OR c2.invalid_reason IN ('U', 'D') -- rule c)
	)
	AND v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id)
	AND v.latest_update IS NOT NULL -- only the current vocabularies
	AND r.relationship_id IN ('Maps to','Maps to value')
	AND r.invalid_reason IS NULL;

	-- And reverse
	UPDATE concept_relationship r
	SET valid_end_date = GREATEST(r.valid_start_date, (SELECT MAX(v.latest_update)-1 FROM vocabulary v WHERE v.vocabulary_id=c1.vocabulary_id OR v.vocabulary_id=c2.vocabulary_id)), -- day before release day or valid_start_date
		invalid_reason = 'D'
	FROM concept c1, concept c2, vocabulary v
	WHERE r.concept_id_1 = c1.concept_id
	AND r.concept_id_2 = c2.concept_id
	AND (
		(c2.standard_concept = 'S' AND c1.concept_id != c2.concept_id) -- rule a)
		OR COALESCE (c1.standard_concept, 'X') != 'S' -- rule b)
		OR c1.invalid_reason IN ('U', 'D') -- rule c)
	)
	AND v.vocabulary_id IN (c1.vocabulary_id, c2.vocabulary_id)
	AND v.latest_update IS NOT NULL -- only the current vocabularies
	AND r.relationship_id IN ('Mapped from','Value mapped from')
	AND r.invalid_reason IS NULL;

	-- 15. Make sure invalid_reason = null if the valid_end_date is 31-Dec-2099
	UPDATE concept
		SET invalid_reason = NULL
	WHERE valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') -- deprecated date
	AND vocabulary_id IN (SELECT vocabulary_id FROM vocabulary WHERE latest_update IS NOT NULL) -- only for current vocabularies
	AND invalid_reason IS NOT NULL; -- if wrongly deprecated

	--16 Post-processing (some concepts might be deprecated when they missed in source, so load_stage doesn't know about them and DO NOT deprecate relationships proper)
	--Deprecate replacement records if target concept was deprecated
	UPDATE concept_relationship cr
		SET invalid_reason = 'D',
		valid_end_date = (SELECT MAX (v.latest_update) FROM concept c JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id WHERE c.concept_id IN (cr.concept_id_1, cr.concept_id_2))-1
	FROM (
			WITH RECURSIVE hierarchy_concepts (concept_id_1, concept_id_2, relationship_id, full_path) AS
			(
				SELECT concept_id_1, concept_id_2, relationship_id, ARRAY [concept_id_1] AS full_path
				FROM upgraded_concepts
				WHERE concept_id_2 IN (SELECT concept_id_2 FROM upgraded_concepts WHERE invalid_reason = 'D')
				UNION ALL
				SELECT c.concept_id_1, c.concept_id_2, c.relationship_id, hc.full_path || c.concept_id_1 AS full_path
				FROM upgraded_concepts c
				JOIN hierarchy_concepts hc on hc.concept_id_1=c.concept_id_2
				WHERE c.concept_id_1 <> ALL (full_path)
			),
			upgraded_concepts AS (
				SELECT r.concept_id_1,
				r.concept_id_2,
				r.relationship_id,
				c2.invalid_reason
				FROM concept c1, concept c2, concept_relationship r
				WHERE r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
				)
				AND r.invalid_reason IS NULL
				AND c1.concept_id = r.concept_id_1
				AND c2.concept_id = r.concept_id_2
				AND EXISTS (SELECT 1 FROM vocabulary WHERE latest_update IS NOT NULL AND vocabulary_id IN (c1.vocabulary_id,c2.vocabulary_id))
				AND c2.concept_code <> 'OMOP generated'
				AND r.concept_id_1 <> r.concept_id_2
			)
			SELECT concept_id_1, concept_id_2, relationship_id FROM hierarchy_concepts
	) i
	WHERE cr.concept_id_1 = i.concept_id_1 AND cr.concept_id_2 = i.concept_id_2 AND cr.relationship_id = i.relationship_id;

	--Deprecate concepts if we have no active replacement record in the concept_relationship
	UPDATE concept c
	SET valid_end_date = (
			SELECT v.latest_update
			FROM vocabulary v
			WHERE c.vocabulary_id = v.vocabulary_id
			) - 1, -- day before release day
		invalid_reason = 'D',
		standard_concept = NULL
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship r
			WHERE r.concept_id_1 = c.concept_id
				AND r.invalid_reason IS NULL
				AND r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
			)
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			) -- only for current vocabularies
		AND c.invalid_reason = 'U';-- not already deprecated

	--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
	UPDATE concept_relationship r
	SET valid_end_date = (
			SELECT MAX(v.latest_update)
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE c.concept_id IN (
					r.concept_id_1,
					r.concept_id_2
					)
			) - 1,
		invalid_reason = 'D'
	WHERE r.relationship_id = 'Maps to'
		AND r.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept c
			WHERE c.concept_id = r.concept_id_2
				AND c.invalid_reason IN (
					'U',
					'D'
					)
			)
		AND EXISTS (
			SELECT 1
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE c.concept_id IN (
					r.concept_id_1,
					r.concept_id_2
					)
				AND v.latest_update IS NOT NULL
			);

	--Reverse for deprecating
	UPDATE concept_relationship r
	SET invalid_reason = r1.invalid_reason,
		valid_end_date = r1.valid_end_date
	FROM concept_relationship r1
	JOIN relationship rel ON r1.relationship_id = rel.relationship_id
	WHERE r1.relationship_id IN (
			'Concept replaced by',
			'Concept same_as to',
			'Concept alt_to to',
			'Concept poss_eq to',
			'Concept was_a to',
			'Maps to'
			)
		AND EXISTS (
			SELECT 1
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE c.concept_id IN (
					r1.concept_id_1,
					r1.concept_id_2
					)
				AND v.latest_update IS NOT NULL
			)
		AND r.concept_id_1 = r1.concept_id_2
		AND r.concept_id_2 = r1.concept_id_1
		AND r.relationship_id = rel.reverse_relationship_id
		AND r.valid_end_date <> r1.valid_end_date;

	--17. fix valid_start_date for incorrect concepts (bad data in sources)
	UPDATE concept c
	SET valid_start_date = valid_end_date - 1
	WHERE c.valid_end_date < c.valid_start_date
		AND c.vocabulary_id IN (
			SELECT vocabulary_id
			FROM vocabulary
			WHERE latest_update IS NOT NULL
			);-- only for current vocabularies

	/***********************************
	* Update the concept_synonym table *
	************************************/

	-- 18. Add all missing synonyms
	INSERT INTO concept_synonym_stage (
		synonym_concept_id,
		synonym_concept_code,
		synonym_name,
		synonym_vocabulary_id,
		language_concept_id
		)
	SELECT NULL AS synonym_concept_id,
		c.concept_code AS synonym_concept_code,
		c.concept_name AS synonym_name,
		c.vocabulary_id AS synonym_vocabulary_id,
		4180186 AS language_concept_id
	FROM concept_stage c
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_synonym_stage css
			WHERE css.synonym_concept_code = c.concept_code
				AND css.synonym_vocabulary_id = c.vocabulary_id
			);

	-- 19. Remove all existing synonyms for concepts that are in concept_stage
	-- Synonyms are built from scratch each time, no life cycle

	ANALYZE concept_synonym_stage;

	DELETE
	FROM concept_synonym csyn
	WHERE csyn.concept_id IN (
			SELECT c.concept_id
			FROM concept c,
				concept_stage cs
			WHERE c.concept_code = cs.concept_code
				AND cs.vocabulary_id = c.vocabulary_id
			);

	-- 20. Add new synonyms for existing concepts
	INSERT INTO concept_synonym (
		concept_id,
		concept_synonym_name,
		language_concept_id
		)
	SELECT DISTINCT c.concept_id,
		REGEXP_REPLACE(TRIM(synonym_name), '[[:space:]]+', ' '),
		css.language_concept_id
	FROM concept_synonym_stage css,
		concept c,
		concept_stage cs
	WHERE css.synonym_concept_code = c.concept_code
		AND css.synonym_vocabulary_id = c.vocabulary_id
		AND cs.concept_code = c.concept_code
		AND cs.vocabulary_id = c.vocabulary_id
		AND REGEXP_REPLACE(TRIM(synonym_name), '[[:space:]]+', ' ') IS NOT NULL; --fix for empty GPI names

	-- 21. Fillig drug_strength
	-- Special rules for RxNorm Extension: same as 'Maps to' rules, but records from deprecated concepts will be deleted
	DELETE
	FROM drug_strength
	WHERE drug_concept_id IN (
			SELECT c.concept_id
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE latest_update IS NOT NULL
				AND v.vocabulary_id <> 'RxNorm Extension'
			);

	-- Replace with fresh records (only for 'RxNorm Extension')
	DELETE
	FROM drug_strength ds
	WHERE EXISTS (
			SELECT 1
			FROM drug_strength_stage dss
			JOIN concept c1 ON c1.concept_code = dss.drug_concept_code
				AND c1.vocabulary_id = dss.vocabulary_id_1
				AND ds.drug_concept_id = c1.concept_id
			JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
			WHERE v.latest_update IS NOT NULL
				AND v.vocabulary_id = 'RxNorm Extension'
			);

	-- Insert new records
	INSERT INTO drug_strength (
		drug_concept_id,
		ingredient_concept_id,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		box_size,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT c1.concept_id,
		c2.concept_id,
		ds.amount_value,
		ds.amount_unit_concept_id,
		ds.numerator_value,
		ds.numerator_unit_concept_id,
		ds.denominator_value,
		ds.denominator_unit_concept_id,
		regexp_replace(bs.concept_name, '.+Box of ([0-9]+).*', '\1')::INT AS box_size,
		ds.valid_start_date,
		ds.valid_end_date,
		ds.invalid_reason
	FROM drug_strength_stage ds
	JOIN concept c1 ON c1.concept_code = ds.drug_concept_code
		AND c1.vocabulary_id = ds.vocabulary_id_1
	JOIN concept c2 ON c2.concept_code = ds.ingredient_concept_code
		AND c2.vocabulary_id = ds.vocabulary_id_2
	JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
	LEFT JOIN concept bs ON bs.concept_id = c1.concept_id
		AND bs.vocabulary_id = 'RxNorm Extension'
		AND bs.concept_name LIKE '%Box of%'
	WHERE v.latest_update IS NOT NULL;

	-- Delete drug if concept is deprecated (only for 'RxNorm Extension')
	DELETE
	FROM drug_strength ds
	WHERE EXISTS (
			SELECT 1
			FROM concept c1
			JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
			WHERE ds.drug_concept_id = c1.concept_id
				AND v.latest_update IS NOT NULL
				AND v.vocabulary_id = 'RxNorm Extension'
				AND c1.invalid_reason IS NOT NULL
			);

	-- 22. Fillig pack_content
	-- Special rules for RxNorm Extension: same as 'Maps to' rules, but records from deprecated concepts will be deleted
	DELETE
	FROM pack_content
	WHERE pack_concept_id IN (
			SELECT c.concept_id
			FROM concept c
			JOIN vocabulary v ON c.vocabulary_id = v.vocabulary_id
			WHERE latest_update IS NOT NULL
				AND v.vocabulary_id <> 'RxNorm Extension'
			);

	-- Replace with fresh records (only for 'RxNorm Extension')
	DELETE
	FROM pack_content pc
	WHERE EXISTS (
			SELECT 1
			FROM pack_content_stage pcs
			JOIN concept c1 ON c1.concept_code = pcs.pack_concept_code
				AND c1.vocabulary_id = pcs.pack_vocabulary_id
				AND pc.pack_concept_id = c1.concept_id
			JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
			WHERE v.latest_update IS NOT NULL
				AND v.vocabulary_id = 'RxNorm Extension'
			);

	INSERT INTO pack_content (
		pack_concept_id,
		drug_concept_id,
		amount,
		box_size
		)
	SELECT c1.concept_id,
		c2.concept_id,
		ds.amount,
		ds.box_size
	FROM pack_content_stage ds
	JOIN concept c1 ON c1.concept_code = ds.pack_concept_code
		AND c1.vocabulary_id = ds.pack_vocabulary_id
	JOIN concept c2 ON c2.concept_code = ds.drug_concept_code
		AND c2.vocabulary_id = ds.drug_vocabulary_id
	JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
	WHERE v.latest_update IS NOT NULL;

	-- Delete if concept is deprecated (only for 'RxNorm Extension')
	DELETE
	FROM pack_content pc
	WHERE EXISTS (
			SELECT 1
			FROM concept c1
			JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
			WHERE pc.pack_concept_id = c1.concept_id
				AND v.latest_update IS NOT NULL
				AND v.vocabulary_id = 'RxNorm Extension'
				AND c1.invalid_reason IS NOT NULL
			);

	-- 23. check if current vocabulary exists in vocabulary_conversion table
	INSERT INTO vocabulary_conversion (
		vocabulary_id_v4,
		vocabulary_id_v5
		)
	SELECT rownum + (
			SELECT MAX(vocabulary_id_v4)
			FROM vocabulary_conversion
			) AS rn,
		a [rownum] AS vocabulary_id
	FROM (
		SELECT a,
			generate_series(1, array_upper(a, 1)) AS rownum
		FROM (
			SELECT ARRAY(SELECT vocabulary_id FROM vocabulary

				EXCEPT

					SELECT vocabulary_id_v5 FROM vocabulary_conversion) AS a
			) AS s1
		) AS s2;

	-- 24. update latest_update on vocabulary_conversion
	UPDATE vocabulary_conversion vc
	SET latest_update = v.latest_update
	FROM vocabulary v
	WHERE v.latest_update IS NOT NULL
		AND v.vocabulary_id = vc.vocabulary_id_v5;

	-- 25. drop column latest_update
	ALTER TABLE vocabulary DROP COLUMN latest_update;
	ALTER TABLE vocabulary DROP COLUMN dev_schema_name;

	-- 26. Final ANALYSING for base tables
	ANALYZE concept;
	ANALYZE concept_relationship;
	ANALYZE concept_synonym;
	-- QA (should return NULL)
	-- select * from QA_TESTS.GET_CHECKS();
END;
$fun$;
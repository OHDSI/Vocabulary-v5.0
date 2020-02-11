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

--3.1. Update Domains for concepts representing Imaging procedures based on hierarchy
update concept_stage
set domain_id = 'Procedure'
WHERE
	concept_code in
		(
			select code
			from sources.loinc_hierarchy
			where
				path_to_root ~ ('^(LP7787\-7\.LP29684\-5|LP7787\-7\.LP7797\-6\.LP29680\-3)\.') --LP29684-5 Radiology LP29680-3 Eye ultrasound
		)

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
-- pick Primary LOINC Parts
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
  LEFT JOIN sources.loinc_part p --  to get a validity of concept (a 'status' field)
ON lh.code = p.partnumber -- LOINC Attribute
WHERE code LIKE 'LP%' -- all LOINC Hierсrchy concepts have 'LP' at the beginning of the names (including 427 undefined concepts and LOINC panels)
    AND TRIM(code) NOT IN (SELECT TRIM(partnumber)
                         FROM sources.loinc_partlink pl
                         WHERE pl.LinkTypeName = 'Primary'
                         AND   pl.PartTypeName IN ('SYSTEM','METHOD','PROPERTY','TIME','COMPONENT','SCALE')) --  pick non-primary Parts and 427 Undefined attributes (excluding Primary LOINC Parts)
)

SELECT DISTINCT
    trim(s.PartDisplayName) AS concept_name,
    CASE WHEN PartDisplayName ~* ('directive|^age\s+|lifetime risk|alert|attachment|\s+date|comment|\s+note|consent|identifier|\s+time|\s+number|' ||
                                    'date and time|coding system|interpretation|status|\s+name|\s+report|\s+id$|s+id\s+|version|instruction|known exposure|priority|ordered|available|requested|issued|flowsheet|\s+term|' ||
                                    'reported|not yet categorized|performed|risk factor|device|administration|\s+route$|suggestion|recommended|narrative|ICD code|reference|' ||
                                    'reviewed|information|intention|^Reason for|^Received|Recommend|provider|subject|summary|time\s+') -- manually defined word patterns indicating the 'Observation' domain
        AND PartDisplayName !~* ('thrombin time|clotting time|bleeding time|clot formation|kaolin activated time|closure time|protein feed time|Recalcification time|reptilase time|russell viper venom time|' ||
                                 'implanted device|dosage\.vial|isolate|within lymph node|cancer specimen|tumor|chromosome|inversion|bioavailable')
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

        --not needed for now since: 1) primary LOINC parts still have relationships going from sources.loinc_hierarchy; 2) primary LOINC parts are not mapped to Standard.
  		--CASE WHEN s.parttypename = 'LOINC Hierarchy' THEN 'C' ELSE NULL END AS standard_concept, --  LOINC Hierarchy concepts should be 'Classification', LOINC Attributes - 'Non-standard'

    'C' AS standard_concept,
    s.PartNumber AS concept_code, -- LOINC Attribute or Hierarchy concept
    COALESCE(c.valid_start_date, v.latest_update) AS valid_start_date,-- preserve the 'devv5.valid_start_date' for already existing concepts
    CASE WHEN s.status = 'DEPRECATED'
         THEN CASE WHEN c.valid_end_date <= latest_update
                   THEN c.valid_end_date -- preserve 'devv5.valid_end_date' for already existing DEPRECATED concepts
                   ELSE GREATEST(COALESCE(c.valid_start_date, v.latest_update), -- assign LOINC 'latest_update' as 'valid_end_date' for new concepts which have to be deprecated in the current release
                                          latest_update - 1) END -- assign LOINC 'latest_update-1' as 'valid_end_date' for already existing concepts, which have to be deprecated in the current release
         ELSE to_date('20991231', 'yyyymmdd') END as valid_end_date, -- default value of 31-Dec-2099 for the rest
    CASE WHEN s.status IN ('ACTIVE', 'INACTIVE') THEN NULL  -- define concept validity according to the 'status' field
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
                          LEAST (c.valid_end_date, cc.valid_end_date, v.latest_update)) AS valid_start_date,  -- compare and assign earliest date of  'valid_end_date' of a LOINC concept AS 'valid_start_date' for NEW relationships of concepts deprecated in the current release OR  'latest update' for the rest of the codes
                CASE WHEN cr.valid_end_date <= v.latest_update THEN cr.valid_end_date -- preserve 'devv5.valid_end_date' for already existing relationships
                     WHEN (c.invalid_reason IS NOT NULL) OR (cc.invalid_reason IS NOT NULL) THEN LEAST(c.valid_end_date, cc.valid_end_date)  -- compare and assign earliest date of 'valid_end_date' of a LOINC concept as 'valid_end_date' for NEW relationships of concepts deprecated in the current release
                     ELSE TO_DATE('20991231', 'yyyymmdd') END as valid_end_date, -- for the rest of the codes
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

--14.1 Build 'LOINC - SNOMED eq' relationships between LOINC Attributes and SNOMED Attributes (as long as LOINC Parts are classification, we cannot not use 'Maps to') 
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
-- note, there are 39 LOINC Parts which have more than one link to SNOMED due to different representation of Systems and Components in vocabularies
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
  AND attributeid in ('246093002', '704319004', '704327008', '718497002') --  'Component', 'Inheres in' (Component-like),  'Direct site' (System-like), 'Inherent location'  (Component-like)
/* Excluded attributeIDs:
Process output - reduplicate a Component
Process agent - link from a LOINCComponent to a possible SNOMED System, useless in mapping ('Kidney structure')
Property type - links from a LOINC Component to a possible SNOMED Property (useless, non-SNOMED logic)
Technique - link from a LOINC Component to SNOMED Technique (useless, non-SNOMED logic)
Characterizes - senseless 'Excretory process' */
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
CASE WHEN c2.concept_name in ('Time aspect', 'Process duration')  THEN 'Has time aspect'
WHEN c2.concept_name in ('Component','Process output') THEN 'Has component'
WHEN c2.concept_name = 'Direct site' THEN 'Has dir proc site'
WHEN c2.concept_name = 'Inheres in' THEN 'Inheres in'
WHEN c2.concept_name = 'Property type' THEN 'Has property'
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
 AND r1.relationship_id in ('Has system', 'Has scale type')
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

--25. Build reverse relationships. This is necessary for the next point.
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

--26. Add to the concept_relationship_stage and deprecate all relationships which do not exist there
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
SELECT a.concept_code,
	b.concept_code,
	a.vocabulary_id,
	b.vocabulary_id,
	relationship_id,
	r.valid_start_date,
	CURRENT_DATE,
	'D'
FROM concept a
JOIN concept_relationship r ON a.concept_id = concept_id_1
	AND r.invalid_reason IS NULL
	AND r.relationship_id NOT IN (
		'Concept replaced by',
		'Concept replaces'
		)
JOIN concept b ON b.concept_id = concept_id_2
WHERE 
		a.vocabulary_id = 'LOINC'
		AND b.vocabulary_id = 'LOINC'
		AND a.concept_id <> b.concept_id 
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = a.concept_code
			AND crs_int.concept_code_2 = b.concept_code
			AND crs_int.vocabulary_id_1 = a.vocabulary_id
			AND crs_int.vocabulary_id_2 = b.vocabulary_id
			AND crs_int.relationship_id = r.relationship_id
		);
	
-- 27. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;
	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script

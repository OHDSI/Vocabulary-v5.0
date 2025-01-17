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
* Authors: Maria Rogozhkina, Oleg Zhuk, Polina Talapova, Dmitry Dymshyts, Alexander Davydov, Timur Vakhitov, Christian Reich
* Date: 2021
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

--3. Load LOINC concepts indicating Measurements or Observations from a source table of 'sources.loinc' into the concept_stage
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
		WHEN classtype IN (
				'1',
				'2'
				)
			AND (
				survey_quest_text LIKE '%?%' -- manually defined source attributes indicating the 'Observation' domain
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
							method_typ <> 'Apgar'
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
				OR class IN (
					'ADMIN',
					'VACCIN',
					'PANEL.SURG',
					'DOC.ONTOLOGY',
					'PANEL.ADMIN'
					)
				OR loinc_num IN (
						'98740-4',
						'99958-1',
						'71579-7',
						'63518-5',
						'98371-8',
						'97504-5',
						'96749-7',
						'98075-5',
						'100218-7',
						'100219-5',
						'100220-3',
						'100221-1',
						'100222-9',
						'100223-7',
						'100282-3',
						'100302-9',
						'100878-8',
						'100967-9',
						'100875-4',
						'100876-2',
						'101969-4',
						'101974-4',
						'101580-9',
						'101687-2',
						'100970-3',
						'101437-2',
						'101579-1'
						)
				OR (long_common_name ~* 'note|summary|notification|Letter|Checklist|instructions')
				)
			AND (
				long_common_name !~* 'scale|score'
				OR long_common_name ~* 'interpretation|rose dyspnea scale'
				)
			AND (
				method_typ <> 'Measured'
				OR method_typ IS NULL
				)
			AND loinc_num NOT IN (
				'65712-2',
				'65713-0'
				)
			THEN 'Observation' -- AVOF-1579
		WHEN classtype = '1'
			THEN 'Measurement'
		WHEN classtype = '2'
			THEN 'Measurement'
		WHEN classtype = '3'
			THEN 'Observation'
		WHEN classtype = '4'
			THEN 'Observation'
		END AS domain_id,
	v.vocabulary_id,
	CASE 
		WHEN classtype IN (
				'1',
				'2'
				)
			AND (
				survey_quest_text LIKE '%?%' -- manually defined source attributes indicating the 'Clinical Observation' concept class
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
				method_typ <> 'Measured'
				OR method_typ IS NULL
				)
			AND loinc_num NOT IN (
				'65712-2',
				'65713-0'
				)
			THEN 'Clinical Observation' -- AVOF-1579
		WHEN classtype = '1'
			THEN 'Lab Test'
		WHEN classtype = '2'
			THEN 'Clinical Observation'
		WHEN classtype = '3'
			THEN 'Claims Attachment'
		WHEN classtype = '4'
			THEN 'Survey'
		END AS concept_class_id,
	CASE 
		WHEN l.STATUS IN ('DEPRECATED')
			THEN NULL
		WHEN l.STATUS IN ('DISCOURAGED')
			AND (
				l.loinc_num = ANY (cj_1map.arr_loinc)
				OR l.loinc_num = ANY (cj_part.arr_loincnumber)
				OR l.class = 'PANEL.HEDIS'
				OR l.classtype IN (
					'3',
					'4'
					)
				) --Discouraged concepts that shouldn't be Standard: 1) have only one link in the sources.map_to 2) have Mass or Substance Concentration Loinc property 3) have the class "PANEL.HEDIS" 4) have classtype 3 (Survey) or 4 (Claims Attachment)
			THEN NULL
		ELSE 'S'
		END AS standard_concept,
	LOINC_NUM AS concept_code,
	v.latest_update AS valid_start_date,
	CASE 
		WHEN l.STATUS IN ('DEPRECATED')
			THEN CASE 
					WHEN c.valid_end_date > v.latest_update
						OR c.valid_end_date IS NULL
						THEN v.latest_update
					ELSE c.valid_end_date
					END
		WHEN l.STATUS IN ('DISCOURAGED')
			AND (
				l.loinc_num = ANY (cj_1map.arr_loinc)
				OR l.loinc_num = ANY (cj_part.arr_loincnumber)
				OR l.class = 'PANEL.HEDIS'
				OR l.classtype IN (
					'3',
					'4'
					)
				) --Discouraged concepts that shouldn't be Standard: 1) have only one link in the sources.map_to 2) have Mass or Substance Concentration Loinc property 3) have the class "PANEL.HEDIS" 4) have classtype 3 (Survey) or 4 (Claims Attachment)
			THEN CASE 
					WHEN c.valid_end_date > v.latest_update
						OR c.valid_end_date IS NULL
						THEN v.latest_update
					ELSE c.valid_end_date
					END
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN (
				l.STATUS IN ('DISCOURAGED')
				AND (
					(
						l.loinc_num = ANY (cj_map.arr_loinc)
						AND (
							l.class = 'PANEL.HEDIS'
							OR l.loinc_num = ANY (cj_part.arr_loincnumber)
							)
						) --Discouraged concepts that should be Updated: 1) have Mass or Substance Concentration Loinc property and with mapping in the sources.to_map 3) have the class "PANEL.HEDIS" and with mapping in the sources.to_map
					OR l.loinc_num = ANY (cj_1map.arr_loinc)
					)
				) --Discouraged concepts that should be Updated: 1) have only one link in the sources.map_to
			OR (
				l.STATUS IN ('DEPRECATED')
				AND l.loinc_num = ANY (cj_map.arr_loinc)
				)
			THEN 'U'
		WHEN l.STATUS = 'DEPRECATED'
			OR (
				l.STATUS = 'DISCOURAGED'
				AND (
					l.class = 'PANEL.HEDIS'
					OR l.loinc_num = ANY (cj_part.arr_loincnumber)
					OR l.classtype IN (
						'3',
						'4'
						)
					)
				) --Discouraged concepts that should be Deprecated: 1) have Mass or Substance Concentration Loinc property without mapping in the sources.map_to 2) have the class "PANEL.HEDIS" without mapping in the sources.map_to 3) have classtype 3 (Survey) or 4 (Claims Attachment) without mapping in the sources.map_to
			THEN 'D'
		ELSE NULL
		END AS invalid_reason
FROM sources.loinc l
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
CROSS JOIN (
	SELECT ARRAY(SELECT DISTINCT m.loinc FROM sources.map_to m) arr_loinc
	) cj_map
CROSS JOIN (
	SELECT ARRAY(SELECT m.loinc FROM sources.map_to m GROUP BY m.loinc HAVING COUNT(DISTINCT m.map_to) = 1) arr_loinc
	) cj_1map
CROSS JOIN (
	SELECT ARRAY(SELECT lp.loincnumber FROM sources.loinc_partlink_primary lp WHERE lp.partnumber = 'LP33032-1') arr_loincnumber
	) cj_part
LEFT JOIN concept c ON c.concept_code = l.LOINC_NUM
	AND c.vocabulary_id = 'LOINC';

--3.1. Update Domains for concepts representing Imaging procedures
UPDATE concept_stage cs
SET domain_id = 'Procedure'
FROM sources.loinc l
WHERE cs.concept_code = l.loinc_num
	AND (
		l.class = 'RAD' --Radiology concepts
		OR l.loinc_num IN (
			'100877-0',
			'101581-7'
			)
		)
	--Concept code doesn't have parts like "Qn", "Densitometry", "Calcium score"
	AND NOT EXISTS (
		SELECT 1
		FROM sources.loinc_partlink_primary lp
		WHERE lp.partnumber IN (
				'LP7753-9',
				'LP200093-5',
				'LP200395-4'
				)
			AND lp.loincnumber = cs.concept_code
		);

--4. Add LOINC Classes from a manual table of 'sources.loinc_class' into the concept_stage
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
FROM sources.loinc_class;

--5. Add LOINC Attributes ('Parts') and LOINC Hierarchy concepts into the concept_stage
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
WITH s AS (
		-- pick LOINC Parts of 6 classes (classes that have links in 'Primary' linktypename)
		SELECT p.partnumber,
			p.partdisplayname,
			p.parttypename,
			p.status
		FROM sources.loinc_part p -- contains LOINC Parts and defines their validity ('status' field)
		WHERE p.parttypename IN (
				'SYSTEM',
				'METHOD',
				'PROPERTY',
				'TIME',
				'COMPONENT',
				'SCALE'
				) -- list of Primary LOINC Parts

		UNION ALL

		-- pick LOINC Hierarchy concepts (Attributive Panels, non-primary Parts and ~400 Undefined attributes)
		SELECT DISTINCT code,
			COALESCE(p.partdisplayname, code_text) AS partdisplayname,
			'LOINC Hierarchy' AS parttypename,
			CASE
				WHEN p.status IS NOT NULL
					THEN p.status
				ELSE 'ACTIVE'
				END AS status
		FROM sources.loinc_hierarchy lh
		LEFT JOIN sources.loinc_part p --to get a validity of concept (a 'status' field)
			ON lh.code = p.partnumber -- LOINC Attribute
		WHERE lh.code LIKE 'LP%' -- all LOINC Hierсrchy concepts have 'LP' at the beginning of the names (including ~400 undefined concepts and LOINC panels)
			AND NOT EXISTS (
				SELECT 1
				FROM sources.loinc_part p_int
				WHERE p_int.parttypename IN (
						'SYSTEM',
						'METHOD',
						'PROPERTY',
						'TIME',
						'COMPONENT',
						'SCALE'
						)
					AND p_int.partnumber = lh.code
				) --excluding Primary LOINC Parts added above
		)
SELECT DISTINCT TRIM(s.partdisplayname) AS concept_name,
	CASE
		WHEN partdisplayname ~* ('directive|^age\s+|lifetime risk|alert|attachment|\s+date|comment|\s+note|consent|identifier|\s+time|\s+number|' || 'date and time|coding system|interpretation|status|\s+name|\s+report|\s+id$|s+id\s+|version|instruction|known exposure|priority|ordered|available|requested|issued|flowsheet|\s+term|' || 'reported|not yet categorized|performed|risk factor|device|administration|\s+route$|suggestion|recommended|narrative|ICD code|reference|' || 'reviewed|information|intention|^Reason for|^Received|Recommend|provider|subject|summary|time\s+|document') -- manually defined word patterns indicating the 'Observation' domain
			AND partdisplayname !~* ('thrombin time|clotting time|bleeding time|clot formation|kaolin activated time|closure time|protein feed time|Recalcification time|reptilase time|russell viper venom time|' || 'implanted device|dosage\.vial|isolate|within lymph node|cancer specimen|tumor|chromosome|inversion|bioavailable')
			THEN 'Observation'
		ELSE 'Measurement' --AVOF-1579 --will be corrected below (5.1) for 6 Primary LOINC Parts
		END AS domain_id,
	'LOINC' AS vocabulary_id,
	CASE
		WHEN s.parttypename = 'SYSTEM'
			THEN 'LOINC System'
		WHEN s.parttypename = 'METHOD'
			THEN 'LOINC Method'
		WHEN s.parttypename = 'PROPERTY'
			THEN 'LOINC Property'
		WHEN s.parttypename = 'TIME'
			THEN 'LOINC Time'
		WHEN s.parttypename = 'COMPONENT'
			THEN 'LOINC Component'
		WHEN s.parttypename = 'SCALE'
			THEN 'LOINC Scale'
		ELSE 'LOINC Hierarchy'
		END AS concept_class_id,
	CASE s.status
		WHEN 'DEPRECATED'
			THEN NULL
		ELSE 'C' --will be corrected below (5.1) for 6 Primary LOINC Parts
		END AS standard_concept,
	s.partnumber AS concept_code, -- LOINC Attribute or Hierarchy concept
	v.latest_update AS valid_start_date,
	CASE
		WHEN s.status = 'DEPRECATED'
			THEN CASE
					WHEN c.valid_end_date <= latest_update
						THEN c.valid_end_date -- preserve valid_end_date for already existing DEPRECATED concepts
					ELSE GREATEST(COALESCE(c.valid_start_date, v.latest_update), -- assign LOINC 'latest_update' as 'valid_end_date' for new concepts which have to be deprecated in the current release
							latest_update - 1)
					END -- assign LOINC 'latest_update-1' as 'valid_end_date' for already existing concepts, which have to be deprecated in the current release
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date, -- default value of 31-Dec-2099 for the rest
	CASE
		WHEN s.status IN (
				'ACTIVE',
				'INACTIVE'
				)
			THEN NULL -- define concept validity according to the 'status' field
		WHEN s.status = 'DEPRECATED'
			THEN 'D'
		ELSE 'X'
		END AS invalid_reason --IF there are any changes in LOINC source we don't know about. GenericUpdate() will fail in case of 'X' in invalid_reason field
FROM s
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
LEFT JOIN concept c ON c.concept_code = s.partnumber -- already existing LOINC concepts
	AND c.vocabulary_id = 'LOINC';

--prerelease fix
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
SELECT long_common_name AS concept_name,
	'Measurement' AS domain_id,
	'LOINC' AS vocabulary_id,
	'Lab Test' AS concept_class_id,
	'S' AS standard_concept,
	loinc AS concept_code,
	created_on AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM vocabulary_pack.GetLoincPrerelease();

--5.1 Update Radiology Hierarchy Domains
UPDATE concept_stage cs
SET domain_id = 'Procedure'
FROM sources.loinc_hierarchy lh
WHERE (
		lh.path_to_root LIKE '%LP29684-5%' --Radiology (LOINC Hierarchy)
		AND cs.concept_class_id = 'LOINC Hierarchy'
		AND cs.concept_name LIKE '%Radiology%'
		AND lh.code = cs.concept_code
		)
	OR cs.concept_code = 'LP29684-5';

--5.2 Update Note-related concepts Domains
UPDATE concept_stage cs
SET domain_id = 'Note'
FROM sources.loinc_hierarchy lh
WHERE (
		lh.path_to_root LIKE 'LP432695-7.LP7787-7.LP32519-8%'
		AND lh.code = cs.concept_code
		)
	OR cs.concept_code IN (
		'101577-5',
		'101578-3',
		'101468-7',
		'100971-1',
		'103140-0',
		'102044-5',
		'102043-7',
		'102047-8',
		'102045-2',
		'102046-0'
		);

--6. Insert missing codes from manual extraction
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--7. Update Domain = 'Observation' and standard_concept = NULL for attributes that are not part of Hierarchy (AVOF-2222)
WITH hierarchy
AS (
	SELECT lh.code
	FROM sources.loinc_hierarchy lh
	WHERE (
			NOT EXISTS (
				SELECT 1
				FROM sources.loinc_partlink_primary lpp
				WHERE lh.code = lpp.partnumber
					AND lpp.parttypename <> 'CLASS'
				)
			AND NOT EXISTS (
				SELECT 1
				FROM sources.loinc_partlink_supplementary lps
				WHERE lh.code = lps.partnumber
					AND lps.parttypename <> 'CLASS'
				)
			)
		AND lh.code !~ '^\d'
	)
UPDATE concept_stage cs
SET domain_id = 'Observation',
	standard_concept = NULL
WHERE NOT EXISTS (
		SELECT 1
		FROM hierarchy h
		WHERE h.code = cs.concept_code
		)
	--currently hierarchy does not overlap with 6 LP classes, but this might be helpful in further development
	AND cs.concept_class_id ~ 'LOINC (System|Method|Property|Time|Component|Scale)';

--8. Build 'Subsumes' relationships from LOINC Ancestors to Descendants using a source table of 'sources.loinc_hierarchy'
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
SELECT DISTINCT lh.immediate_parent AS concept_code_1, -- LOINC Ancestor
	lh.code AS concept_code_2, -- LOINC Descendant
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_hierarchy lh
WHERE lh.immediate_parent IS NOT NULL;-- when immediate parent is null then there is no Ancestor

--9. Build 'Has system', 'Has method', 'Has property', 'Has time aspect', 'Has component', and 'Has scale type' relationships from LOINC Measurements/Observations to Primary LOINC Parts (attributes)
--assign specific links using a TYPE of LOINC Part using 'sources.loinc_partlink_primary'
ANALYZE concept_stage;
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
WITH s AS (
		SELECT pl.loincnumber, -- LOINC Measurement/Observation
			p.partnumber, -- Primary LOINC Part
			p.status,
			CASE
				WHEN p.parttypename = 'SYSTEM'
					THEN 'Has system'
				WHEN p.parttypename = 'METHOD'
					THEN 'Has method'
				WHEN p.parttypename = 'PROPERTY'
					THEN 'Has property'
				WHEN p.parttypename = 'TIME'
					THEN 'Has time aspect'
				WHEN p.parttypename = 'COMPONENT'
					THEN 'Has component'
				WHEN p.parttypename = 'SCALE'
					THEN 'Has scale type'
				END AS relationship_id
		FROM sources.loinc_partlink_primary pl
		JOIN sources.loinc_part p ON pl.partnumber = p.partnumber -- Primary LOINC Part
		WHERE pl.linktypename = 'Primary'
		),
	-- pick already existing relationships between LOINC Measurements/Observations and Primary LOINC Parts (it's needed to pull the validity dates from basic tables)
	cr AS (
		SELECT c1.concept_code AS concept_code_1, -- LOINC Measurement/Observation
			c1.vocabulary_id,
			relationship_id,
			c2.concept_code AS concept_code_2, -- Primary LOINC Part ?
			c2.vocabulary_id,
			cr.valid_start_date,
			cr.valid_end_date,
			cr.invalid_reason
		FROM concept_relationship cr
		JOIN concept c1 ON c1.concept_id = cr.concept_id_1
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		WHERE c1.vocabulary_id = 'LOINC'
			AND c2.vocabulary_id = 'LOINC'
		)
SELECT s.loincnumber AS concept_code_1,
	partnumber AS concept_code_2,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	s.relationship_id AS relationship_id,
	COALESCE(cr.valid_start_date, -- preserve valid_start_date for already existing relationships
		LEAST(cs1.valid_end_date, cs2.valid_end_date, v.latest_update)) AS valid_start_date, -- compare and assign earliest date of 'valid_end_date' of a LOINC concept AS 'valid_start_date' for NEW relationships of concepts deprecated in the current release OR  'latest update' for the rest of the codes
	CASE
		WHEN cr.valid_end_date <= v.latest_update --preserve valid_end_date for already existing relationships
		AND (cs1.invalid_reason IS NOT NULL OR cs2.invalid_reason IS NOT NULL OR cs1.concept_code IS NULL OR cs2.concept_code IS NULL) --only if they're still deprecated
			THEN cr.valid_end_date
		WHEN cs1.invalid_reason IS NOT NULL OR cs2.invalid_reason IS NOT NULL
			THEN LEAST(cs1.valid_end_date, cs2.valid_end_date) -- compare and assign earliest date of 'valid_end_date' of a LOINC concept as 'valid_end_date' for NEW relationships of concepts deprecated in the current release
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date, -- for the rest of the codes
	CASE
		WHEN cs1.invalid_reason IS NOT NULL
		OR cs2.invalid_reason IS NOT NULL
		OR cs1.concept_code IS NULL
		OR cs2.concept_code IS NULL
			THEN 'D'
		ELSE NULL
		END AS invalid_reason
FROM s
LEFT JOIN concept_stage cs1 -- to define deprecated LOINC Observations/Measurements in the current release
	ON cs1.concept_code = s.loincnumber --LOINC Observation/Measurement in the current release
	AND cs1.vocabulary_id = 'LOINC'
LEFT JOIN concept_stage cs2 -- to define deprecated LOINC Parts
	ON cs2.concept_code = s.partnumber -- LOINC Part
LEFT JOIN cr ON (
		cr.concept_code_1,
		cr.relationship_id,
		cr.concept_code_2
		) = (
		s.loincnumber,
		s.relationship_id,
		s.partnumber
		) -- already existing relationships between LOINC concepts
JOIN vocabulary v ON v.vocabulary_id = 'LOINC';

--10. Build 'Subsumes' relationships between LOINC Classes using a source table of 'sources.loinc_class' and a similarity of a class name beginning (ancestor class_name LIKE descendant class_name || '%')
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
SELECT l2.concept_code AS concept_code_1, -- LOINC Class Ancestor
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
	AND l1.concept_code <> l2.concept_code;

--11. Build 'Subsumes' relationships from LOINC Classes to LOINC concepts indicating Measurements or Observations with the use of source tables of 'sources.loinc_class' and 'sources.loinc' to create Multiaxial Hierarchy
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

--12. Delete wrong relationship between 'PANEL.H' class (History & Physical order set) and 38213-5 'FLACC pain assessment panel' (AVOF-352)
DELETE
FROM concept_relationship_stage
WHERE concept_code_1 = 'PANEL.H' || CHR(38) || 'P' -- '&' = CHR(38)
	AND concept_code_2 = '38213-5'
	AND relationship_id = 'Subsumes';

--13. Add to the concept_synonym_stage all synonymic names from a source table of 'sources.loinc'
-- NB! We do not add synonyms for LOINC Answers (a 'description' field) due to their vague formulation
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	) (
	--values of a 'RelatedNames2' field
	SELECT l.loinc_num AS synonym_concept_code,
	vocabulary_pack.CutConceptSynonymName(l.relatednames2) AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc l WHERE l.relatednames2 IS NOT NULL

UNION

	-- values of a 'consumer_name' field that were previously used as preferred name (in 195 cases)
	SELECT l.loinc_num AS synonym_concept_code,
	l.consumer_name AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc l WHERE l.consumer_name IS NOT NULL

UNION

	-- values of the 'ShortName' field
	SELECT l.loinc_num AS synonym_concept_code,
	l.shortname AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc l WHERE l.shortname IS NOT NULL

UNION

	--'long_common_name' field values which were changed ('History of')
	SELECT l.loinc_num AS synonym_concept_code,
	l.long_common_name AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc l WHERE NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_name = l.long_common_name
		)

UNION

	--'PartName' field values which are synonyms for 'partdisplayname' field values in sources.loinc_part
	SELECT pl.partnumber AS synonym_concept_code,
		p.partname AS synonym_name,
		'LOINC' AS synonym_vocabulary_id,
		4180186 AS language_concept_id --English language
	FROM sources.loinc_partlink_primary pl
	JOIN sources.loinc_part p ON p.partnumber = pl.partnumber
	WHERE EXISTS (
			SELECT 1
			FROM concept_stage cs_int
			WHERE cs_int.concept_code = pl.partnumber
			)
		AND pl.partname <> p.partdisplayname


UNION

	SELECT pl.partnumber AS synonym_concept_code,
		p.partname AS synonym_name,
		'LOINC' AS synonym_vocabulary_id,
		4180186 AS language_concept_id --English language
	FROM sources.loinc_partlink_supplementary pl
	JOIN sources.loinc_part p ON p.partnumber = pl.partnumber
	WHERE EXISTS (
			SELECT 1
			FROM concept_stage cs_int
			WHERE cs_int.concept_code = pl.partnumber
			)
		AND pl.partname <> p.partdisplayname
);-- pick only different names

--14. Add LOINC Answers from 'sources.loinc_answerslist' and 'sources.loinc_answerslistlink' source tables to the concept_stage
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
SELECT DISTINCT TRIM(ans_l.displaytext) AS concept_name,
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

--15. Build 'Has Answer' relationships from LOINC Questions to Answers with the use of such source tables as 'sources.loinc_answerslist' and 'sources.loinc_answerslistlink'
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
WHERE ans_l.answerstringid IS NOT NULL;-- 'AnswerStringID' may be null

--16. Build 'Panel contains' relationships from LOINC Panels to their descendants with the use of 'sources.loinc_forms' table
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
SELECT DISTINCT lf.parentloinc AS concept_code_1, -- LOINC Panel code
	lf.loinc AS concept_code_2, -- LOINC Descendant code
	'Panel contains' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_forms lf -- Panel containing table
WHERE lf.loinc <> lf.parentloinc;-- to exclude cases when parents and children are represented by the same concepts

--17. Build temporary 'LOINC - SNOMED eq' relationships between LOINC Attributes and SNOMED Attributes (will be dropped in 20). Afterward 'Maps to' may be built instead.
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
SELECT DISTINCT s.maptarget AS concept_code_1, -- LOINC Attribute code
	s.referencedcomponentid AS concept_code_2, -- SNOMED Attribute code
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'LOINC - SNOMED eq' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.scccrefset_mapcorrorfull_int s
JOIN concept_stage cs ON cs.concept_code = s.maptarget --LOINC Attribute
	AND cs.vocabulary_id = 'LOINC'
	AND cs.invalid_reason IS NULL
JOIN concept c ON c.concept_code = s.referencedcomponentid --SNOMED Attribute
	AND c.vocabulary_id = 'SNOMED'
	AND c.invalid_reason IS NULL
JOIN vocabulary v ON cs.vocabulary_id = v.vocabulary_id --valid_start_date
WHERE s.attributeid IN (
		'246093002',
		'704319004',
		'704327008',
		'718497002'
		);--'Component', 'Inheres in' (Component-like), 'Direct site' (System-like), 'Inherent location' (Component-like)

/* Excluded attribute IDs:
Process output - reduplicate a Component
Process agent - link from a LOINC Component to a possible SNOMED System, useless in mapping ('Kidney structure')
Property type - links from a LOINC Component to a possible SNOMED Property (useless, non-SNOMED logic)
Technique - link from a LOINC Component to SNOMED Technique (useless, non-SNOMED logic)
Characterizes - senseless 'Excretory process' */

--18. Build temporary relationships between LOINC Measurements and respective SNOMED attributes given by the table of 'sources.scccrefset_expressionassociation_int' (will be dropped in 20).
--Note, that some suggested by LOINC relationship_ids ('Characterizes', 'Units', 'Relative to', 'Process agent' 'Inherent location') are useless in the context of a mapping to SNOMED.
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
-- extract LOINC Measurement codes, LOINC-to-SNOMED relationship_id identifiers and related SNOMED Attributes from sources.scccrefset_expressionassociation_int
WITH t1 AS (
		SELECT s0.maptarget, -- LOINC Measurement code
			s0.tuples [1] AS sn_key, -- LOINC to SNOMED relationship_id identifier
			s0.tuples [2] AS sn_value -- related SNOMED Attribute
		FROM (
			SELECT ea.maptarget,
				STRING_TO_ARRAY(UNNEST(STRING_TO_ARRAY(SUBSTRING(ea.expression, devv5.instr(ea.expression, ':') + 1), ',')), '=') AS tuples
			FROM sources.scccrefset_expressionassociation_int ea
			) AS s0
		)
SELECT DISTINCT a.maptarget AS concept_code_1, -- LOINC Measurement code
	c2.concept_code AS concept_code_2, -- SNOMED Attribute code
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	CASE
		WHEN c1.concept_name IN (
				'Time aspect',
				'Process duration'
				)
			THEN 'Has time aspect'
		WHEN c1.concept_name IN (
				'Component',
				'Process output'
				)
			THEN 'Has component'
		WHEN c1.concept_name = 'Direct site'
			THEN 'Has dir proc site'
		WHEN c1.concept_name = 'Inheres in'
			THEN 'Inheres in'
		WHEN c1.concept_name = 'Property type'
			THEN 'Has property'
		WHEN c1.concept_name = 'Scale type'
			THEN 'Has scale type'
		WHEN c1.concept_name = 'Technique'
			THEN 'Has technique'
		WHEN c1.concept_name = 'Precondition'
			THEN 'Has precondition'
		END AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM t1 a
JOIN concept_stage cs ON cs.concept_code = a.maptarget -- LOINC Lab test
	AND cs.invalid_reason IS NULL
	AND cs.vocabulary_id = 'LOINC'
JOIN concept c1 ON c1.concept_code = a.sn_key -- LOINC to SNOMED relationship_id identifier
	AND c1.vocabulary_id = 'SNOMED'
	AND c1.concept_name IN (
		'Time aspect',
		'Process duration',
		'Component',
		'Process output',
		'Direct site',
		'Inheres in',
		'Property type',
		'Scale type',
		'Technique',
		'Precondition'
		)
JOIN concept c2 ON c2.concept_code = a.sn_value -- SNOMED Attribute
	AND c2.vocabulary_id = 'SNOMED'
	AND (
		c2.invalid_reason IS NULL
		OR c2.concept_code = '41598000'
		) --Estrogen. This concept is invalid, but is used as component
JOIN vocabulary v ON cs.vocabulary_id = v.vocabulary_id;

--19. Build 'Is a' from LOINC Measurements to SNOMED Measurements in concept_relationship_stage to create a hierarchical cross-walks;
--create temporary tables with SNOMED and LOINC attribute pools
--'sn_attr' contains normalized set of SNOMED Measurements and respective attributes, taking into account useful relationship_ids and STATUS of SNOMED concepts (pick only Fully defined ones)
DROP TABLE IF EXISTS sn_attr;
CREATE UNLOGGED TABLE sn_attr AS
	WITH t1 AS (
			SELECT *
			FROM (
				SELECT c1.concept_code AS sn_code,
					c1.concept_name AS sn_name,
					cr.relationship_id,
					c2.concept_code AS attr_code,
					c2.concept_name AS attr_name,
					COUNT(*) OVER (
						PARTITION BY c1.concept_code,
						cr.relationship_id
						) AS cnt
				FROM concept c1
				JOIN concept_relationship cr ON cr.concept_id_1 = c1.concept_id
					AND cr.invalid_reason IS NULL
				JOIN concept c2 ON c2.concept_id = cr.concept_id_2
				WHERE c1.vocabulary_id = 'SNOMED'
					AND c1.domain_id = 'Measurement'
					AND c1.standard_concept = 'S'
					AND c2.vocabulary_id = 'SNOMED'
					AND NOT EXISTS (
						SELECT 1
						FROM concept_relationship cr_int
						WHERE cr_int.concept_id_1 = cr.concept_id_1
							AND cr_int.relationship_id IN (
								'Has intent',
								'Has measurement'
								)
							AND cr_int.invalid_reason IS NULL
						)
					AND cr.relationship_id IN (
						'Has component',
						'Has scale type',
						'Has specimen',
						'Has dir proc site',
						'Inheres in'
						)
				) kk
			WHERE /*kk.cnt = 1
				AND*/ --Take concepts only with one component/scale and ect, so not all concepts have right hierarchy
				kk.sn_name NOT ILIKE '%screening%'
				AND kk.sn_code NOT IN (
					'104193001',
					'104194007',
					'104178000',
					'370990004',
					'401298000',
					'399177007',
					'399193003',
					'115253009',
					'395129003',
					'409613001',
					'399143002',
					'115340009',
					'430925007',
					'104568008',
					'121806006',
					'445132000',
					'104326007',
					'104323004',
					'697001',
					'413058006',
					'432883005'
					) -- SNOMED concepts with wrong sets of attributes
			), -- exclude concepts with multiple attributes from one category
		-- get a list of Fully defined SNOMED concepts, using sources.sct2_concept_full_merged, to weed out Primitive SNOMED Measurements composed of inadequate attribute set
		snomed_concept AS (
			SELECT *
			FROM (
				SELECT DISTINCT ON (f.id) c.concept_code,
					f.statusid
				FROM sources.sct2_concept_full_merged f -- the source table indicating 'definition status' of SNOMED concepts
				JOIN concept c ON c.vocabulary_id = 'SNOMED'
					AND c.standard_concept = 'S'
					AND c.concept_code = f.id::VARCHAR
				ORDER BY f.id,
					f.effectivetime DESC -- the 'statusid' field may be both Fully define and Primitive at the same time, to distinguish Fully define ones use 'effectivetime' field
				) AS s0
			WHERE statusid = '900000000000073002'
			
			UNION ALL
			
			SELECT '41598000' AS concept_code,
				'900000000000073002' AS statusid --This union is needed to take Estrogen component
			)

SELECT zz.*
FROM t1 zz
JOIN snomed_concept sc ON sc.concept_code = zz.sn_code;

--create an index for the temporary table of 'sn_attr' to speed up next table creation
CREATE INDEX idx_sa_name ON sn_attr (LOWER(attr_name));
CREATE INDEX idx_sa_sncode ON sn_attr (sn_code);
ANALYZE sn_attr;

--'LC_ATTR' contains normalized set of relationships between LOINC Measurements and SNOMED Attributes
DROP TABLE IF EXISTS lc_attr;
CREATE UNLOGGED TABLE lc_attr AS
	-- AXIS 1: build links between TOP-6 LOINC Systems or 'Quantitative'/'Qualitative' Scales AND respective SNOMED Attributes
	WITH lc_attr_add AS (
			SELECT cs.concept_code AS lc_code,
				cs.concept_name AS lc_name,
				CASE 
					WHEN crs.concept_code_2 NOT IN (
							'LP7753-9',
							'LP7751-3'
							)
						THEN 'Has dir proc site'
					ELSE 'Has scale type'
					END AS relationship_id,
				CASE 
					WHEN crs.concept_code_2 IN (
							'LP7057-5',
							'LP21304-8',
							'LP7068-2',
							'LP185760-8',
							'LP7536-8',
							'LP7576-4',
							'LP7578-0',
							'LP7579-8',
							'LP7067-4',
							'LP7073-2'
							) --'Bld', 'Bld.dot', 'BldC', 'Plas/Bld', 'Ser/Plas/Bld', 'Ser/Plas', 'Ser/Plas.ultracentrifugate', 'RBC'
						THEN '119297000' -- Blood specimen
					WHEN crs.concept_code_2 = 'LP7567-3'
						THEN '119364003' -- Serum specimen
					WHEN crs.concept_code_2 = 'LP7681-2'
						THEN '122575003' -- Urine specimen
					WHEN crs.concept_code_2 = 'LP7156-5'
						THEN '258450006' -- Cerebrospinal fluid sample
					WHEN crs.concept_code_2 = 'LP7479-1'
						THEN '119361006' -- Plasma specimen
					WHEN crs.concept_code_2 = 'LP7604-4'
						THEN '119339001' -- Stool specimen
					WHEN crs.concept_code_2 = 'LP7753-9'
						THEN '30766002' -- Quantitative
					WHEN crs.concept_code_2 = 'LP7751-3'
						THEN '26716007' -- Qualitative
					END AS attr_code
			FROM concept_stage cs
			JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
				AND crs.vocabulary_id_1 = cs.vocabulary_id -- LOINC Measurement
				AND crs.concept_code_2 IN (
					'LP7057-5',
					'LP21304-8',
					'LP7068-2',
					'LP185760-8',
					'LP7536-8',
					'LP7576-4',
					'LP7578-0',
					'LP7579-8',
					'LP7567-3',
					'LP7681-2',
					'LP7156-5',
					'LP7479-1',
					'LP7604-4',
					'LP7753-9',
					'LP7067-4',
					'LP7073-2',
					'LP7751-3'
					) -- list of needful LOINC Parts (System and Scale)
				AND crs.relationship_id IN (
					'Has system',
					'Has scale type'
					)
				AND crs.invalid_reason IS NULL
			WHERE cs.vocabulary_id = 'LOINC'
				AND cs.domain_id = 'Measurement'
				AND cs.invalid_reason IS NULL
				AND cs.standard_concept = 'S'
			),
		-- AXIS 2: get links given by the source between LOINC Measurements and SNOMED Attributes
		lc_sn AS (
			SELECT concept_code_1 AS lc_code,
				cs.concept_name AS lc_name,
				crs.relationship_id,
				concept_code_2 AS attr_code
			FROM concept_relationship_stage crs
			JOIN concept_stage cs ON cs.concept_code = crs.concept_code_1
				AND cs.vocabulary_id = crs.vocabulary_id_1 -- LOINC Measurement
				AND cs.standard_concept = 'S'
				AND cs.invalid_reason IS NULL
				AND cs.domain_id = 'Measurement'
			JOIN concept c ON c.concept_code = crs.concept_code_2
				AND c.vocabulary_id = crs.vocabulary_id_2 -- SNOMED Attribute
				AND (
					c.invalid_reason IS NULL
					OR c.concept_code = '41598000'
					) --To take Estrogen component
			WHERE (
					crs.concept_code_1,
					crs.relationship_id
					) NOT IN (
					SELECT lca_int.lc_code,
						lca_int.relationship_id
					FROM lc_attr_add lca_int
					) -- to exclude duplicates
				AND crs.vocabulary_id_1 = 'LOINC'
				AND crs.vocabulary_id_2 = 'SNOMED'
				AND crs.invalid_reason IS NULL
				AND crs.relationship_id IN (
					'Has component',
					'Has dir proc site',
					'Inheres in',
					'Has scale type'
					) -- list of useful relationship_ids
			),
		-- AXIS 3: build links between LOINC Measurements and SNOMED Attributes using given by the source mappings of LOINC Attributes to SNOMED Attributes
		lc_attr_1 AS (
			SELECT cs2.concept_code AS lc_code,
				cs2.concept_name AS lc_name,
				'Has component' AS relationship_id,
				c.concept_code AS attr_code
			FROM concept_relationship_stage crs1
			JOIN concept_stage cs1 ON cs1.concept_code = crs1.concept_code_1
				AND cs1.vocabulary_id = crs1.vocabulary_id_1 -- LOINC Component
				AND cs1.concept_class_id = 'LOINC Component'
			JOIN concept c ON c.concept_code = crs1.concept_code_2
				AND c.vocabulary_id = crs1.vocabulary_id_2 -- SNOMED Attribute
				AND c.concept_class_id = 'Substance'
			JOIN concept_relationship_stage crs2 ON crs2.concept_code_1 = cs1.concept_code
				AND crs2.vocabulary_id_1 = cs1.vocabulary_id -- LOINC Component
				AND crs2.relationship_id = 'Subsumes' -- LOINC Component 'Subsumes' LOINC Panel
				AND crs2.invalid_reason IS NULL
			JOIN concept_relationship_stage crs3 ON crs3.concept_code_1 = crs2.concept_code_2
				AND crs3.vocabulary_id_1 = crs2.vocabulary_id_2 -- LOINC Panel
				AND crs3.relationship_id = 'Subsumes' -- LOINC Panel 'Subsumes' LOINC Measurement
				AND crs3.invalid_reason IS NULL
			JOIN concept_stage cs2 ON cs2.concept_code = crs3.concept_code_2
				AND cs2.vocabulary_id = crs3.vocabulary_id_2 -- LOINC Measurement
				AND cs2.vocabulary_id = 'LOINC'
				AND cs2.standard_concept = 'S'
				AND cs2.standard_concept = 'S'
				AND cs2.invalid_reason IS NULL
				AND cs2.domain_id = 'Measurement'
			WHERE cs2.concept_code NOT IN (
					SELECT lc_int.lc_code
					FROM lc_sn lc_int
					WHERE lc_int.relationship_id = 'Has component'
					)
				AND crs1.vocabulary_id_1 = 'LOINC'
				AND crs1.vocabulary_id_2 = 'SNOMED'
				AND crs1.relationship_id = 'LOINC - SNOMED eq'
				AND crs1.invalid_reason IS NULL
			),
		-- AXIS 4: build links between LOINC Measurements and SNOMED Attributes using Components of LOINC Measurements and name similarity of SNOMED Attributes
		lc_attr_2 AS (
			SELECT crs.concept_code_1 AS lc_code,
				cs1.concept_name AS lc_name, -- preserved for word-pattern filtering
				crs.relationship_id,
				x1.attr_code AS attr_code
			FROM concept_relationship_stage crs
			JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
				AND cs1.vocabulary_id = crs.vocabulary_id_1 -- LOINC Measurement
				AND cs1.standard_concept = 'S'
				AND cs1.invalid_reason IS NULL
				AND cs1.domain_id = 'Measurement'
			JOIN concept_stage cs2 ON cs2.concept_code = crs.concept_code_2
				AND cs2.vocabulary_id = crs.vocabulary_id_2 -- LOINC Component
			JOIN sn_attr x1 ON (
					LOWER(SPLIT_PART(cs2.concept_name, '.', 1)) = LOWER(x1.attr_name)
					OR LOWER(SPLIT_PART(cs2.concept_name, '^', 1)) = LOWER(x1.attr_name)
					) -- SNOMED Attribute
			WHERE (
					crs.concept_code_1,
					crs.relationship_id
					) NOT IN (
					SELECT lc_int.lc_code,
						lc_int.relationship_id
					FROM lc_sn lc_int
					)
				AND (
					crs.concept_code_1,
					crs.relationship_id
					) NOT IN (
					SELECT lca_int.lc_code,
						lca_int.relationship_id
					FROM lc_attr_1 lca_int
					) -- exclude duplicates
				AND crs.vocabulary_id_1 = 'LOINC'
				AND crs.vocabulary_id_2 = 'LOINC'
				AND crs.relationship_id = 'Has component'
				AND crs.invalid_reason IS NULL
			)

-- get input
SELECT DISTINCT lc_code,
	lc_name,
	relationship_id,
	attr_code
FROM (
	SELECT *
	FROM lc_attr_add
	
	UNION ALL
	
	SELECT *
	FROM lc_sn
	
	UNION ALL
	
	SELECT *
	FROM lc_attr_1
	
	UNION ALL
	
	SELECT *
	FROM lc_attr_2
	) lc
-- weed out LOINC Measurements with inapplicable properties in the SNOMED architecture context
JOIN sources.loinc j ON j.loinc_num = lc.lc_code
	AND j.property !~ 'Rto|Ratio|^\w.Fr|Imp|Prid|Zscore|Susc|^-$' -- exclude ratio/interpretation/identifier/z-score/susceptibility-related concepts
WHERE lc_name !~* 'susceptibility|protein\.monoclonal';-- susceptibility may have property other than 'Susc'

CREATE INDEX idx_la_lccode ON lc_attr (lc_code);
ANALYZE lc_attr;

--20. Build hierarchical links of 'Is a' from LOINC Measurements to SNOMED Measurements in concept_relationship_stage using common attribute combinations (top-down)
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
WITH ax_1 AS (
		SELECT DISTINCT z4.lc_code,
			z4.lc_name, -- to preserve names for word-pattern filtering
			x3.sn_code,
			x3.sn_name
		FROM sn_attr x1 -- X1 - SNOMED attribute pool
		JOIN lc_attr z1 -- Z1 - LOINC attribute pool
			ON z1.attr_code = x1.attr_code -- common Component
			AND z1.relationship_id = 'Has component'
		JOIN sn_attr x2 ON x2.sn_code = x1.sn_code -- common 2-attribute SNOMED Measurement
		JOIN lc_attr z2 ON z2.attr_code = x2.attr_code -- common Site
			AND z2.relationship_id IN (
				'Has dir proc site',
				'Inheres in'
				) -- given by the source relationships indicating SNOMED Specimens
		JOIN sn_attr x3 ON x3.sn_code = x2.sn_code -- common 3-attribute SNOMED Measurement
		JOIN lc_attr z3 ON z3.attr_code = x3.attr_code -- common Scale
			AND z3.relationship_id = 'Has scale type'
		JOIN lc_attr z4 ON z4.lc_code = z3.lc_code
			AND z4.lc_code = z2.lc_code
			AND z4.lc_code = z1.lc_code -- common 3-attribute LOINC Measurement
		WHERE x1.relationship_id = 'Has component'
			AND x2.relationship_id = 'Has specimen'
			AND x3.relationship_id = 'Has scale type'
			AND x1.sn_code IN (
				SELECT sn_attr_int.sn_code
				FROM sn_attr sn_attr_int
				GROUP BY sn_attr_int.sn_code
				HAVING COUNT(*) = 3
				) -- to restrict SNOMED attribute pool
		),
	-- AXIS 2: get 2-attribute Measurements (Component+Specimen)
	ax_2 AS (
		SELECT DISTINCT z3.lc_code,
			z3.lc_name,
			x2.sn_code,
			x2.sn_name
		FROM sn_attr x1 -- X1 - SNOMED attribute pool
		JOIN lc_attr z1 -- Z1 - LOINC attribute pool
			ON z1.attr_code = x1.attr_code -- common Component
			AND z1.relationship_id = 'Has component'
		JOIN sn_attr x2 ON x2.sn_code = x1.sn_code -- common 2-attribute SNOMED Measurement
		JOIN lc_attr z2 ON z2.attr_code = x2.attr_code -- common Site
			AND z2.relationship_id IN (
				'Has dir proc site',
				'Inheres in'
				) -- given by the source relationships indicating SNOMED Specimens
		JOIN lc_attr z3 ON z3.lc_code = z2.lc_code
			AND z3.lc_code = z1.lc_code -- common 2-attribute LOINC Measurement
		WHERE x1.relationship_id = 'Has component'
			AND x2.relationship_id = 'Has specimen'
			AND (
				x1.sn_code IN (
					SELECT sn_attr_int.sn_code
					FROM sn_attr sn_attr_int
					GROUP BY sn_attr_int.sn_code
					HAVING COUNT(*) = 2
					) /*to restrict SNOMED attribute pool*/
				OR x1.attr_code = '41598000'
				) --To take Estrogen component
			AND x1.sn_code NOT IN (
				'401020005' --Urinary cortisol analysis
				) --to exclude additional codes
	        AND z3.lc_code NOT IN (
	            '51540-3', --Cladosporium herbarum IgG Ab [Presence] in Serum
	            '19726-9', --Aspergillus fumigatus IgG Ab [Presence] in Serum
	            '51538-7', --Cladosporium herbarum IgG Ab [Presence] in Serum
	            '55837-9', --Chloride [Moles/volume] in 24 hour Stool
	            '51539-5' --Candida albicans IgG Ab [Presence] in Serum
            )
			AND z3.lc_code NOT IN (
				SELECT ax_1_int.lc_code
				FROM ax_1 ax_1_int
				) -- exclude duplicates
		),
	-- AXIS 2.1: get 2-attribute Measurements (Component+Specimen) ONLY for DIALYSAT specimen
	ax_21 AS (
			SELECT DISTINCT z3.lc_code,
				z3.lc_name,
				x2.sn_code,
				x2.sn_name
			FROM sn_attr x1 -- X1 - SNOMED attribute pool
			JOIN lc_attr z1 -- Z1 - LOINC attribute pool
				ON z1.attr_code = x1.attr_code -- common Component
				AND z1.relationship_id = 'Has component'
			JOIN sn_attr x2 ON x2.sn_code = x1.sn_code -- common 2-attribute SNOMED Measurement
			JOIN lc_attr z2 ON z2.attr_code = '418377002'
				AND x2.attr_code = '258454002' -- common Site -- DIALYSIS only
				AND z2.relationship_id IN (
					'Has dir proc site',
					'Inheres in'
					) -- given by the source relationships indicating SNOMED Specimens
			JOIN lc_attr z3 ON z3.lc_code = z2.lc_code
				AND z3.lc_code = z1.lc_code -- common 2-attribute LOINC Measurement
			WHERE x1.relationship_id = 'Has component'
				AND x2.relationship_id = 'Has specimen'
				AND x1.sn_code IN (
					SELECT sn_attr_int.sn_code
					FROM sn_attr sn_attr_int
					WHERE sn_attr_int.sn_code IN (
							SELECT sn_code
							FROM sn_attr
							WHERE attr_code IN (
									'258454002', --Dialysate specimen
									'119360007' --Dialysis fluid specimen
									)
							)
					GROUP BY sn_attr_int.sn_code
					HAVING COUNT(*) > 1
					) /*to restrict SNOMED attribute pool*/
				AND x1.sn_code NOT IN (
					'401020005' --Urinary cortisol analysis
					)
				AND z3.lc_code NOT IN (
					SELECT ax_1_int.lc_code
					FROM ax_1 ax_1_int
					)
				AND z3.lc_code NOT IN (
					SELECT ax_2_int.lc_code
					FROM ax_2 ax_2_int
					) -- exclude duplicates
			),
	-- AXIS 3: get 2-attribute Measurements (Component+Specimen) ONLY for Acellular blood (serum or plasma) specimen
	ax_3 AS (
		SELECT DISTINCT z2.lc_code,
			z2.lc_name,
			x2.sn_code,
			x2.sn_name
		FROM sn_attr x1 -- X1 - SNOMED attribute pool
		JOIN lc_attr z1 -- Z1 - LOINC attribute pool
			ON z1.attr_code = x1.attr_code -- common Component
			AND z1.relationship_id = 'Has component'
		JOIN sn_attr x2 ON x2.sn_code = x1.sn_code -- common 2-attribute SNOMED Measurement
		JOIN lc_attr z2 ON z2.lc_code = z1.lc_code -- common Site
			AND z2.relationship_id IN (
				'Has dir proc site',
				'Inheres in'
				) -- given by the source relationships indicating SNOMED Specimens
			AND x2.attr_code = '122592007' --Acellular blood (serum or plasma) specimen
			AND z2.attr_code = '119364003' --Serum specimen
			AND x1.sn_code IN (
				SELECT sn_attr_int.sn_code
				FROM sn_attr sn_attr_int
				GROUP BY sn_attr_int.sn_code
				HAVING COUNT(*) = 2
				) /*to restrict SNOMED attribute pool*/
			AND x1.sn_code NOT IN (
				'401093002', --Haemophilus influenzae B IgG measurement
				'9954002' --Serologic test for rubella
				) --to exclude additional codes
			AND z2.lc_code NOT IN (
				SELECT ax_1_int.lc_code
				FROM ax_1 ax_1_int
				)
			AND z2.lc_code NOT IN (
				SELECT ax_2_int.lc_code
				FROM ax_2 ax_2_int
				)
			AND z2.lc_code NOT IN (
				SELECT ax_21_int.lc_code
				FROM ax_21 ax_21_int
				) -- exclude duplicates
		),
	-- AXIS 4: get 2-attribute Measurements (Component+Scale)
	ax_4 AS (
		SELECT DISTINCT z3.lc_code,
			z3.lc_name,
			x2.sn_code,
			x2.sn_name
		FROM sn_attr x1 --X1 - SNOMED attribute pool
		JOIN lc_attr z1 -- Z1 - LOINC attribute pool
			ON z1.attr_code = x1.attr_code -- common Component
			AND z1.relationship_id = 'Has component'
		JOIN sn_attr x2 ON x2.sn_code = x1.sn_code -- common 2-attribute SNOMED Measurement
		JOIN lc_attr z2 ON z2.attr_code = x2.attr_code -- common Scale
			AND z2.relationship_id = 'Has scale type'
		JOIN lc_attr z3 ON z3.lc_code = z2.lc_code
			AND z3.lc_code = z1.lc_code -- common 2-attribute LOINC Measurement
		WHERE x1.relationship_id = 'Has component'
			AND x2.relationship_id = 'Has scale type'
			AND x1.sn_code IN (
				SELECT sn_attr_int.sn_code
				FROM sn_attr sn_attr_int
				GROUP BY sn_attr_int.sn_code
				HAVING COUNT(*) = 2
				) -- to restrict SNOMED attribute pool
			AND z3.lc_code NOT IN (
				SELECT ax_1_int.lc_code
				FROM ax_1 ax_1_int
				) -- exclude duplicates
		),
	-- AXIS 5: get 1-attribute Measurements (Component)
	ax_5 AS (
		SELECT DISTINCT z1.lc_code,
			z1.lc_name,
			x1.sn_code,
			x1.sn_name
		FROM sn_attr x1 --X1 - SNOMED attribute pool
		JOIN lc_attr z1 -- Z1 - LOINC attribute pool
			ON z1.attr_code = x1.attr_code -- common Component
			AND z1.relationship_id = 'Has component'
		WHERE x1.relationship_id = 'Has component'
			AND x1.sn_code IN (
				SELECT sn_attr_int.sn_code
				FROM sn_attr sn_attr_int
				GROUP BY sn_attr_int.sn_code
				HAVING COUNT(*) = 1
				) -- to restrict SNOMED attribute pool
			AND x1.sn_code NOT IN (
				'250663008', --Unconjugated estriol measurement
				'269932004', --Fluid sample lipase measurement
				'271232007', --Serum lipase measurement
				'281105001', --Fecal lipase measurement
				'166776003', --Serum/plasma protein test
				'166809004', --Electrophoresis: paraprotein
				'54381000237109', --Sodium molar concentration in blood
				'791921000000101', --Partial pressure of oxygen in umbilical cord venous blood
				'791911000000107', --pH of umbilical cord venous blood
				'791971000000102', --pH of umbilical cord arterial blood
				'736730002', --Partial pressure of carbon dioxide in umbilical cord arterial blood
				'736785003', --Partial pressure of carbon dioxide in umbilical cord venous blood
				'55701000237103', --Potassium molar concentration in blood
				'54661000237106', --Magnesium molar concentration in blood
				'143431000237107', --Clinical chemistry electrolyte observable
			     '1285329004', --Lactate in umbilical cord blood
			    '372461000119109', --Lactate in blood
			    '372451000119107', --Lactate in whole blood
			    '364321000119106', --Detection of Legionella pneumophila antigen in urine
			    '364351000119103', --Detection of Streptococcus pneumoniae antigen in urine
			    '364301000119102', --Detection of Helicobacter pylori antigen in stool
			    '373211000119100', --Giardia lamblia antigen by enzyme immunoassay
			    '374451000119101', --Rheumatoid factor in serum
			    '364061000119103', --Presence of Streptococcus agalactiae in genital system by organism specific culture
			    '364571000119101', --Alanine transaminase in serum
			    '11461000237104', --Alkaline phosphatase enzyme activity in fluid
			    '364681000119104', --Benzodiazepine in urine by confirmatory technique
			    '372361000119104', --Low density lipoprotein cholesterol by direct assay
			    '365451000119108', --Smooth muscle actin immunoglobulin G antibody
			    '408591000', --HBA1c target
			    '780836005', --Target serum high density lipoprotein cholesterol level
			    '780837001', --Target serum low density lipoprotein cholesterol level
			    '780838006', --Target serum non high density lipoprotein cholesterol level
			    '390896004', --Target cholesterol level
			    '780835009', --Target serum triglyceride level
			    '999551000000108', --Prolymphocyte count
			    '1015481000000107', --Percentage lymphocytes
			    '1015521000000107', --Percentage blast cells
			    '1304152003' --Partial pressure of carbon dioxide in arterial blood
				) -- to exclude codes with additional axises
		  AND z1.lc_code NOT IN (
	            '2077-6', --Chloride [Moles/volume] in Sweat
	            '56448-4', --Chloride [Moles/volume] in Sweat by Screen method
	            '44506-4', --Herpes simplex virus Ab [Presence] in Cerebral spinal fluid
	            '16942-5', --Herpes simplex virus Ab [Presence] in Serum by Immunoblot
	            '22339-6', --Herpes simplex virus Ab [Presence] in Serum
		        '55837-9' --Chloride [Moles/volume] in 24 hour Stool
            )
			AND z1.lc_code NOT IN (
				SELECT ax_1_int.lc_code
				FROM ax_1 ax_1_int
				)
			AND z1.lc_code NOT IN (
				SELECT ax_2_int.lc_code
				FROM ax_2 ax_2_int
				)
			AND z1.lc_code NOT IN (
				SELECT ax_21_int.lc_code
				FROM ax_21 ax_21_int
			)
			AND z1.lc_code NOT IN (
				SELECT ax_3_int.lc_code
				FROM ax_3 ax_3_int
				)
			AND z1.lc_code NOT IN (
				SELECT ax_4_int.lc_code
				FROM ax_4 ax_4_int
				) -- exclude duplicates
		),
	-- unite all AXES
	all_ax AS (
		SELECT *
		FROM ax_1
		
		UNION ALL
		
		SELECT *
		FROM ax_2

		UNION ALL

		SELECT *
		FROM ax_21
		
		UNION ALL
		
		SELECT *
		FROM ax_3
		
		UNION ALL
		
		SELECT *
		FROM ax_4
		
		UNION ALL
		
		SELECT *
		FROM ax_5
		)
-- get input for concept_relationship_stage
SELECT lc_code AS concept_code_1,
	--lc_name,
	sn_code AS concept_code_2,
	--sn_name,
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM all_ax a_x
JOIN vocabulary v ON v.vocabulary_id = 'LOINC' -- to get latest update
	-- get rid of wrong SNOMED concepts with the same sets of attributes
WHERE NOT (
		a_x.sn_name ILIKE '%dipstick%'
		AND a_x.lc_name NOT ILIKE '%test strip%'
		OR (
			a_x.lc_name ~* 'titer|presence'
			AND a_x.sn_name ILIKE '% level%'
			)
		OR (
			a_x.lc_name NOT ILIKE '%titer%'
			AND a_x.sn_name ILIKE '% titer%'
			)
		OR (
			a_x.lc_name LIKE '%/%'
			AND a_x.sn_name ILIKE '% titer%'
			)
		OR (
			a_x.lc_name !~* 'count|100|#'
			AND a_x.sn_name ILIKE '%count%'
			)
		OR (
			a_x.lc_name ~* 'morpholog|presence'
			AND a_x.sn_name ILIKE '%count%'
			)
		OR (
			a_x.lc_name NOT ILIKE '%fasting glucose%'
			AND a_x.sn_name ILIKE '%fasting glucose%'
			)
		OR (
			a_x.lc_name NOT ILIKE '%microscop%'
			AND a_x.sn_name ILIKE '%microscop%'
			)
		OR (
			a_x.lc_name !~* 'culture|isolate'
			AND a_x.sn_name ILIKE '%culture%'
			)
		)
	-- note, some LOINC Measurements may be mapped to 2 SNOMED Measurements
	AND NOT (
		a_x.lc_code IN (
			SELECT ax_int.lc_code
			FROM all_ax ax_int
			GROUP BY ax_int.lc_code
			HAVING COUNT(*) > 1
			)
		AND (
			a_x.lc_name ILIKE '%fasting glucose%'
			AND a_x.sn_name NOT ILIKE '%fasting glucose%'
			OR a_x.lc_name ILIKE '%test strip%'
			AND a_x.sn_name NOT ILIKE '%dipstick%'
			)
		AND sn_name NOT ILIKE '%quantitative%'
		);

--21. Build hierarchical links 'Is a' from LOINC Lab Tests to SNOMED Measurements with the use of the LOINC Ontology source (2024.02)
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
WITH resulting_table AS (
		--table with snomed measurements with attributes
		WITH snomed_attr AS (
				SELECT DISTINCT si.alternateidentifier AS loinc_code, --loinc_code of the real concept
					c.concept_name, --loinc name of the real concept
					c2.concept_id AS snomed_id,
					--potential target
					c2.concept_code AS snomed_code,
					c2.concept_name AS snomed_name,
					--attributes of the potential target
					c1.concept_code AS component_code,
					c1.concept_name AS component_name,
					c3.concept_code AS specimen_code,
					c3.concept_name AS specimen_name,
					c4.concept_code AS method_code,
					c4.concept_name AS method_name,
					c5.concept_code AS property_code,
					c5.concept_name AS property_name,
					c6.concept_code AS scale_code,
					c6.concept_name AS scale_name,
					c7.concept_code AS time_code,
					c7.concept_name AS time_name
				FROM dev_loinc.snomed_relationship_full sr
				JOIN dev_loinc.snomed_identifier_full si ON si.referencedcomponentid = sr.sourceid
				LEFT JOIN concept_stage c ON c.concept_code = si.alternateidentifier
					AND c.vocabulary_id = 'LOINC'
				LEFT JOIN concept c1 ON c1.concept_code = sr.destinationid
					AND c1.vocabulary_id = 'SNOMED'
				JOIN concept_relationship cr ON cr.concept_id_1 = c1.concept_id
					AND cr.relationship_id = 'Component of'
					AND cr.invalid_reason IS NULL
				JOIN concept c2 ON c2.concept_id = cr.concept_id_2
					AND c2.vocabulary_id = 'SNOMED'
					AND c2.invalid_reason IS NULL
				LEFT JOIN concept_relationship cr1 ON cr1.concept_id_1 = c2.concept_id
					AND cr1.relationship_id IN (
						'Has specimen',
						'Has direct site'
						)
					AND cr1.invalid_reason IS NULL
				LEFT JOIN concept c3 ON c3.concept_id = cr1.concept_id_2
					AND c3.vocabulary_id = 'SNOMED'
				LEFT JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
					AND cr2.relationship_id = 'Has method'
					AND cr2.invalid_reason IS NULL
				LEFT JOIN concept c4 ON c4.concept_id = cr2.concept_id_2
					AND c4.vocabulary_id = 'SNOMED'
				LEFT JOIN concept_relationship cr3 ON cr3.concept_id_1 = c2.concept_id
					AND cr3.relationship_id = 'Has property'
					AND cr3.invalid_reason IS NULL
				LEFT JOIN concept c5 ON c5.concept_id = cr3.concept_id_2
					AND c5.vocabulary_id = 'SNOMED'
				LEFT JOIN concept_relationship cr4 ON cr4.concept_id_1 = c2.concept_id
					AND cr4.relationship_id = 'Has scale type'
					AND cr4.invalid_reason IS NULL
				LEFT JOIN concept c6 ON c6.concept_id = cr4.concept_id_2
					AND c6.vocabulary_id = 'SNOMED'
				LEFT JOIN concept_relationship cr5 ON cr5.concept_id_1 = c2.concept_id
					AND cr5.relationship_id = 'Has time aspect'
					AND cr5.invalid_reason IS NULL
				LEFT JOIN concept c7 ON c7.concept_id = cr5.concept_id_2
					AND c7.vocabulary_id = 'SNOMED'
				WHERE sr.typeid <> '116680003' --Is a
					AND c.concept_code NOT IN (
						SELECT concept_code_1
						FROM concept_relationship_stage
						WHERE relationship_id = 'Is a'
							AND invalid_reason IS NULL
							AND vocabulary_id_2 = 'SNOMED'
						)
				),
			--table with loinc measurements with attributes
			loinc_attr AS (
				SELECT DISTINCT si.alternateidentifier AS loinc_code, --loinc_code of the real concept
					c.concept_name, --loinc name of the real concept
					--loinc attributes
					c1.concept_code AS component_code,
					c1.concept_name AS component_name,
					c2.concept_code AS specimen_code,
					c2.concept_name AS specimen_name,
					c3.concept_code AS method_code,
					c3.concept_name AS method_name,
					c4.concept_code AS property_code,
					c4.concept_name AS property_name,
					c5.concept_code AS scale_code,
					c5.concept_name AS scale_name,
					c6.concept_code AS time_code,
					c6.concept_name AS time_name
				FROM dev_loinc.snomed_relationship_full sr
				JOIN dev_loinc.snomed_identifier_full si ON si.referencedcomponentid = sr.sourceid
					AND sr.typeid = '246093002' --Component
				LEFT JOIN concept_stage c ON c.concept_code = si.alternateidentifier
					AND c.vocabulary_id = 'LOINC'
				LEFT JOIN concept c1 ON c1.concept_code = sr.destinationid
					AND c1.vocabulary_id = 'SNOMED'
				LEFT JOIN dev_loinc.snomed_relationship_full sr1 ON sr1.sourceid = sr.sourceid
					AND sr1.typeid IN (
						'370133003',
						'704319004',
						'704327008'
						) --Specimen
				LEFT JOIN concept c2 ON c2.concept_code = sr1.destinationid
					AND c2.vocabulary_id = 'SNOMED'
				LEFT JOIN dev_loinc.snomed_relationship_full sr2 ON sr2.sourceid = sr.sourceid
					AND sr2.typeid = '246501002' --Method
				LEFT JOIN concept c3 ON c3.concept_code = sr2.destinationid
					AND c3.vocabulary_id = 'SNOMED'
				LEFT JOIN dev_loinc.snomed_relationship_full sr3 ON sr3.sourceid = sr.sourceid
					AND sr3.typeid = '370130000' --Property
				LEFT JOIN concept c4 ON c4.concept_code = sr3.destinationid
					AND c4.vocabulary_id = 'SNOMED'
				LEFT JOIN dev_loinc.snomed_relationship_full sr4 ON sr4.sourceid = sr.sourceid
					AND sr4.typeid = '370132008' --Scale
				LEFT JOIN concept c5 ON c5.concept_code = sr4.destinationid
					AND c5.vocabulary_id = 'SNOMED'
				LEFT JOIN dev_loinc.snomed_relationship_full sr5 ON sr5.sourceid = sr.sourceid
					AND sr5.typeid = '370134009'
				LEFT JOIN concept c6 ON c6.concept_code = sr5.destinationid
					AND c6.vocabulary_id = 'SNOMED'
				WHERE sr.typeid <> '116680003' --Is a
					--take Lab Test that don't have 'Is a' link to SNOMED
					AND c.concept_code NOT IN (
						SELECT concept_code_1
						FROM concept_relationship_stage
						WHERE relationship_id = 'Is a'
							AND invalid_reason IS NULL
							AND vocabulary_id_2 = 'SNOMED'
						)
				),
			--full attributes match
			ax1 AS (
				SELECT t.loinc_code AS concept_code,
					t.concept_name AS concept_name,
					t.snomed_code AS target_concept_code,
					t.snomed_name AS target_concept_name,
					t.component_code AS target_component_code,
					t.component_name AS target_component_name,
					t.specimen_code AS target_specimen_code,
					t.specimen_name AS target_specimen_name,
					t.method_code AS target_method_code,
					t.method_name AS target_method_name,
					t.property_code AS target_property_code,
					t.property_name AS target_property_name,
					t.scale_code AS target_scale_code,
					t.scale_name AS target_scale_name,
					t.time_code AS target_time_code,
					t.time_name AS target_time_name,
					t1.component_code,
					t1.component_name,
					t1.specimen_code,
					t1.specimen_name,
					t1.method_code,
					t1.method_name,
					t1.property_code,
					t1.property_name,
					t1.scale_code,
					t1.scale_name,
					t1.time_code,
					t1.time_name
				FROM snomed_attr t
				JOIN loinc_attr t1 USING (
						loinc_code,
						component_code,
						specimen_code,
						method_code,
						property_code,
						scale_code,
						time_code
						)
				),
			--Component + Specimen + Scale
			ax2 AS (
				SELECT t.loinc_code AS concept_code,
					t.concept_name AS concept_name,
					t.snomed_code AS target_concept_code,
					t.snomed_name AS target_concept_name,
					t.component_code AS target_component_code,
					t.component_name AS target_component_name,
					t.specimen_code AS target_specimen_code,
					t.specimen_name AS target_specimen_name,
					t.method_code AS target_method_code,
					t.method_name AS target_method_name,
					t.property_code AS target_property_code,
					t.property_name AS target_property_name,
					t.scale_code AS target_scale_code,
					t.scale_name AS target_scale_name,
					t.time_code AS target_time_code,
					t.time_name AS target_time_name,
					t1.component_code,
					t1.component_name,
					t1.specimen_code,
					t1.specimen_name,
					t1.method_code,
					t1.method_name,
					t1.property_code,
					t1.property_name,
					t1.scale_code,
					t1.scale_name,
					t1.time_code,
					t1.time_name
				FROM snomed_attr t
				JOIN loinc_attr t1 USING (
						loinc_code,
						component_code,
						specimen_code,
						scale_code
						)
				--prevent wrong matching based on Property
				WHERE (
						t.property_code IS NULL
						OR t1.property_code IS NULL
						OR t.property_code = t1.property_code
						)
					AND t.snomed_code NOT IN
                        ('444264005', --Quantitative measurement of gastrin in fasting serum or plasma specimen
                        '443833006' --Quantitative measurement of cannabinoids in urine using GC-MS
                            )
				),
			--Component + Specimen + Property + Time
			ax3 AS (
				SELECT t.loinc_code AS concept_code,
					t.concept_name AS concept_name,
					t.snomed_code AS target_concept_code,
					t.snomed_name AS target_concept_name,
					t.component_code AS target_component_code,
					t.component_name AS target_component_name,
					t.specimen_code AS target_specimen_code,
					t.specimen_name AS target_specimen_name,
					t.method_code AS target_method_code,
					t.method_name AS target_method_name,
					t.property_code AS target_property_code,
					t.property_name AS target_property_name,
					t.scale_code AS target_scale_code,
					t.scale_name AS target_scale_name,
					t.time_code AS target_time_code,
					t.time_name AS target_time_name,
					t1.component_code,
					t1.component_name,
					t1.specimen_code,
					t1.specimen_name,
					t1.method_code,
					t1.method_name,
					t1.property_code,
					t1.property_name,
					t1.scale_code,
					t1.scale_name,
					t1.time_code,
					t1.time_name
				FROM snomed_attr t
				JOIN loinc_attr t1 USING (
						loinc_code,
						component_code,
						specimen_code,
						property_code,
						time_code
						)
				),
			--loinc_code + Method
			ax4 AS (
				SELECT t.loinc_code AS concept_code,
					t.concept_name AS concept_name,
					t.snomed_code AS target_concept_code,
					t.snomed_name AS target_concept_name,
					t.component_code AS target_component_code,
					t.component_name AS target_component_name,
					t.specimen_code AS target_specimen_code,
					t.specimen_name AS target_specimen_name,
					t.method_code AS target_method_code,
					t.method_name AS target_method_name,
					t.property_code AS target_property_code,
					t.property_name AS target_property_name,
					t.scale_code AS target_scale_code,
					t.scale_name AS target_scale_name,
					t.time_code AS target_time_code,
					t.time_name AS target_time_name,
					t1.component_code,
					t1.component_name,
					t1.specimen_code,
					t1.specimen_name,
					t1.method_code,
					t1.method_name,
					t1.property_code,
					t1.property_name,
					t1.scale_code,
					t1.scale_name,
					t1.time_code,
					t1.time_name
				FROM snomed_attr t
				JOIN loinc_attr t1 USING (
						loinc_code,
						method_code
						)
				),
			--Property + Component + Specimen
			ax5 AS (
				SELECT DISTINCT ON (s0.concept_code) s0.*
				FROM (
					SELECT t.loinc_code AS concept_code,
						t.concept_name AS concept_name,
						t.snomed_code AS target_concept_code,
						t.snomed_name AS target_concept_name,
						t.component_code AS target_component_code,
						t.component_name AS target_component_name,
						t.specimen_code AS target_specimen_code,
						t.specimen_name AS target_specimen_name,
						t.method_code AS target_method_code,
						t.method_name AS target_method_name,
						t.property_code AS target_property_code,
						t.property_name AS target_property_name,
						t.scale_code AS target_scale_code,
						t.scale_name AS target_scale_name,
						t.time_code AS target_time_code,
						t.time_name AS target_time_name,
						t1.component_code,
						t1.component_name,
						t1.specimen_code,
						t1.specimen_name,
						t1.method_code,
						t1.method_name,
						t1.property_code,
						t1.property_name,
						t1.scale_code,
						t1.scale_name,
						t1.time_code,
						t1.time_name,
						--to choose concept with the more SNOMED Subsumes than others
						COUNT(cr.concept_id_2) OVER (
							PARTITION BY t.loinc_code,
							t.concept_name,
							t.snomed_code,
							t.snomed_name,
							t.component_code,
							t.component_name,
							t.specimen_code,
							t.specimen_name,
							t.method_code,
							t.method_name,
							t.property_code,
							t.property_name,
							t.scale_code,
							t.scale_name,
							t.time_code,
							t.time_name,
							t1.component_code,
							t1.component_name,
							t1.specimen_code,
							t1.specimen_name,
							t1.method_code,
							t1.method_name,
							t1.property_code,
							t1.property_name,
							t1.scale_code,
							t1.scale_name,
							t1.time_code,
							t1.time_name
							) AS snomed_subsumes_cnt,
						t.snomed_id
					FROM snomed_attr t
					JOIN loinc_attr t1 USING (
							loinc_code,
							component_code,
							specimen_code,
							property_code
							)
					LEFT JOIN concept_relationship cr ON cr.concept_id_1 = t.snomed_id
						AND cr.relationship_id = 'Subsumes'
						AND cr.invalid_reason IS NULL
					--exclude rows that already have hierarchy
					WHERE t.loinc_code NOT IN (
							SELECT concept_code
							FROM ax2
							)
						--prevent wrong matching based on Method
						AND (
							t1.method_code IS NOT NULL
							OR (
								t1.method_code IS NULL
								AND t.snomed_name !~* 'automated|immunoassay|immunoflourescence|immunosorbent'
								)
							)
						AND snomed_code NOT IN
                            ('444264005', --Quantitative measurement of gastrin in fasting serum or plasma specimen
                             '364301000119102', --Detection of Helicobacter pylori antigen in stool
                            '443833006' --Quantitative measurement of cannabinoids in urine using GC-MS
                                )
				    AND loinc_code NOT IN
                            ('805-2' --Leukocytes [#/volume] in Cerebral spinal fluid by Automated count
                                )
					) s0
				ORDER BY s0.concept_code,
					s0.snomed_subsumes_cnt DESC,
					s0.snomed_id
				),
			-- Component + Specimen
			ax6 AS (
				SELECT DISTINCT ON (s0.concept_code) s0.*
				FROM (
					SELECT t.loinc_code AS concept_code,
						t.concept_name AS concept_name,
						t.snomed_code AS target_concept_code,
						t.snomed_name AS target_concept_name,
						t.component_code AS target_component_code,
						t.component_name AS target_component_name,
						t.specimen_code AS target_specimen_code,
						t.specimen_name AS target_specimen_name,
						t.method_code AS target_method_code,
						t.method_name AS target_method_name,
						t.property_code AS target_property_code,
						t.property_name AS target_property_name,
						t.scale_code AS target_scale_code,
						t.scale_name AS target_scale_name,
						t.time_code AS target_time_code,
						t.time_name AS target_time_name,
						t1.component_code,
						t1.component_name,
						t1.specimen_code,
						t1.specimen_name,
						t1.method_code,
						t1.method_name,
						t1.property_code,
						t1.property_name,
						t1.scale_code,
						t1.scale_name,
						t1.time_code,
						t1.time_name,
						--to choose concept with the more SNOMED Subsumes than others
						COUNT(cr.concept_id_2) OVER (
							PARTITION BY t.loinc_code,
							t.concept_name,
							t.snomed_code,
							t.snomed_name,
							t.component_code,
							t.component_name,
							t.specimen_code,
							t.specimen_name,
							t.method_code,
							t.method_name,
							t.property_code,
							t.property_name,
							t.scale_code,
							t.scale_name,
							t.time_code,
							t.time_name,
							t1.component_code,
							t1.component_name,
							t1.specimen_code,
							t1.specimen_name,
							t1.method_code,
							t1.method_name,
							t1.property_code,
							t1.property_name,
							t1.scale_code,
							t1.scale_name,
							t1.time_code,
							t1.time_name
							) AS snomed_subsumes_cnt,
						t.snomed_id
					FROM snomed_attr t
					JOIN loinc_attr t1 ON t.loinc_code = t1.loinc_code
						AND t.component_code = t1.component_code
						AND t.specimen_code = t1.specimen_code
					LEFT JOIN concept_relationship cr ON cr.concept_id_1 = t.snomed_id
						AND relationship_id = 'Subsumes'
						AND invalid_reason IS NULL
					--exclude rows that already have hierarchy
					WHERE t.loinc_code NOT IN (
							SELECT concept_code
							FROM ax2
							)
						AND t.loinc_code NOT IN (
							SELECT concept_code
							FROM ax5
							)
						--prevent wrong matching based on Property
						AND (
							t.property_code IS NULL
							OR t1.property_code IS NULL
							OR t.property_code = t1.property_code
							)
						--prevent wrong matching based on Scale
						AND (
							t.scale_code IS NULL
							OR t1.scale_code IS NULL
							OR t.scale_code = t1.scale_code
							)
						--prevent wrong matching based on Method
						AND (
							t1.method_code IS NOT NULL
							OR (
								t1.method_code IS NULL
								AND snomed_name !~* 'automated|immunoassay|immunoflourescence|immunosorbent'
								)
							)
						AND t.snomed_code NOT IN (
							'104193001', --Bacterial culture, urine, with colony count
							'104230007', --Bacterial culture, urine, by commercial kit
							'104194007', --Bacterial culture, urine, with organism identification
							'395030005', --Skin biopsy C3 level
							'104309001', --Cytomegalovirus IgM antibody assay
							'313604004', --Cytomegalovirus IgG antibody measurement
							'57321000237104', --Fractional TRP (tubular reabsorption of phosphate)
							'444264005', --Quantitative measurement of gastrin in fasting serum or plasma specimen
						    '993431000000100', --Haemoglobin electrophoresis
						    '392372009' --Norway spruce specific IgE antibody measurement
							)
						AND snomed_name !~* 'C3c|C3a|C3d|C3b|C4d|C4a|C4b|C5a'
					  AND t.loinc_code NOT IN
                            ('805-2' --Leukocytes [#/volume] in Cerebral spinal fluid by Automated count
                                )
						AND regexp_replace(t.concept_name, '[^0-9]', '', 'g') = regexp_replace(t.snomed_name, '[^0-9]', '', 'g')
					) s0
				ORDER BY s0.concept_code,
					s0.snomed_subsumes_cnt DESC,
					s0.snomed_id
				),
			-- Component + Property
			ax7 AS (
				SELECT t.loinc_code AS concept_code,
					t.concept_name AS concept_name,
					snomed_code AS target_concept_code,
					snomed_name AS target_concept_name,
					t.component_code AS target_component_code,
					t.component_name AS target_component_name,
					t.specimen_code AS target_specimen_code,
					t.specimen_name AS target_specimen_name,
					t.method_code AS target_method_code,
					t.method_name AS target_method_name,
					t.property_code AS target_property_code,
					t.property_name AS target_property_name,
					t.scale_code AS target_scale_code,
					t.scale_name AS target_scale_name,
					t.time_code AS target_time_code,
					t.time_name AS target_time_name,
					t1.component_code,
					t1.component_name,
					t1.specimen_code,
					t1.specimen_name,
					t1.method_code,
					t1.method_name,
					t1.property_code,
					t1.property_name,
					t1.scale_code,
					t1.scale_name,
					t1.time_code,
					t1.time_name
				FROM snomed_attr t
				JOIN loinc_attr t1 USING (
						loinc_code,
						component_code,
						property_code
						)
				--exclude rows that already have hierarchy
				WHERE t.loinc_code NOT IN (
						SELECT concept_code
						FROM ax2
						)
					AND t.loinc_code NOT IN (
						SELECT concept_code
						FROM ax5
						)
					AND t.loinc_code NOT IN (
						SELECT concept_code
						FROM ax6
						)
					--prevent wrong matching based on Specimen and match similar Specimens
					AND (
						t.specimen_code IS NULL
						OR t1.specimen_code IS NULL
						OR t.specimen_code = t1.specimen_code
						OR (
							t.specimen_code ILIKE '%serum%'
							AND t1.specimen_code ILIKE '%serum%'
							)
						OR (
							t.specimen_code ~* 'phar|Sputum|Bronchoalveolar'
							AND t1.specimen_code ~* 'throat|respiratory|phar'
							)
						OR (
							t.specimen_code ILIKE '%blood%'
							AND t1.specimen_code ILIKE '%blood%'
							)
						OR (
							t.specimen_code ILIKE '%urine%'
							AND t1.specimen_code ILIKE '%urine%'
							)
						OR (
							t.specimen_code ILIKE '%plasma%'
							AND t1.specimen_code ILIKE '%plasma%'
							)
						OR (
							t.specimen_code ILIKE '%fluid%'
							AND t1.specimen_code ILIKE '%fluid%'
							)
						OR (
							t.specimen_code ILIKE '%Naso%'
							AND t1.specimen_code ILIKE '%nose%'
							)
						OR (
							t.specimen_code ~* 'Serum|Plasma'
							AND t1.specimen_code ILIKE '%spot%'
							)
						OR (
							t.specimen_code ~* 'dial|fluid'
							AND t1.specimen_code ILIKE '%Dialysate%'
							)
					    OR (
							t.specimen_code ~* 'semen'
							AND t1.specimen_code ILIKE '%semen%'
							)
						)
					AND snomed_code NOT IN (
						'50271000237107', --HCV (hepatitis C virus) antibody in oral fluid qualitative result
						'444264005', --Quantitative measurement of gastrin in fasting serum or plasma specimen
					    '2341000237100', --Leucocyte number concentration in semen
					    '4851000237100' --Neutrophil number concentration in semen
					    )
			    AND snomed_name !~* 'by deoxyribonucleic acid microarray analysis'
				)/*,
			--Component
			--TODO: can be implemented. Also only match on the loinc_code level can be done
			ax8 AS (
				SELECT t.loinc_code AS concept_code,
					t.concept_name AS concept_name,
					t.snomed_code AS target_concept_code,
					t.snomed_name AS target_concept_name,
					t.component_code AS target_component_code,
					t.component_name AS target_component_name,
					t.specimen_code AS target_specimen_code,
					t.specimen_name AS target_specimen_name,
					t.method_code AS target_method_code,
					t.method_name AS target_method_name,
					t.property_code AS target_property_code,
					t.property_name AS target_property_name,
					t.scale_code AS target_scale_code,
					t.scale_name AS target_scale_name,
					t.time_code AS target_time_code,
					t.time_name AS target_time_name,
					t1.component_code,
					t1.component_name,
					t1.specimen_code,
					t1.specimen_name,
					t1.method_code,
					t1.method_name,
					t1.property_code,
					t1.property_name,
					t1.scale_code,
					t1.scale_name,
					t1.time_code,
					t1.time_name -- com
				FROM snomed_attr t
				JOIN loinc_attr t1 USING (
						loinc_code,
						component_code
						)
				--exclude rows that already have hierarchy
				WHERE t.loinc_code NOT IN (
						SELECT concept_code
						FROM ax2
						)
					AND t.loinc_code NOT IN (
						SELECT concept_code
						FROM ax5
						)
					AND t.loinc_code NOT IN (
						SELECT concept_code
						FROM ax6
						)
					AND t.loinc_code NOT IN (
						SELECT concept_code
						FROM ax7
						)
				)*/
		SELECT *
		FROM ax1
		
		UNION ALL
		
		SELECT *
		FROM ax2
		
		UNION ALL
		
		SELECT *
		FROM ax3
		
		UNION ALL
		
		SELECT *
		FROM ax4
		
		UNION ALL
		
		SELECT concept_code,
			concept_name,
			target_concept_code,
			target_concept_name,
			target_component_code,
			target_component_name,
			target_specimen_code,
			target_specimen_name,
			target_method_code,
			target_method_name,
			target_property_code,
			target_property_name,
			target_scale_code,
			target_scale_name,
			target_time_code,
			target_time_name,
			component_code,
			component_name,
			specimen_code,
			specimen_name,
			method_code,
			method_name,
			property_code,
			property_name,
			scale_code,
			scale_name,
			time_code,
			time_name
		FROM ax5
		
		UNION ALL
		
		SELECT concept_code,
			concept_name,
			target_concept_code,
			target_concept_name,
			target_component_code,
			target_component_name,
			target_specimen_code,
			target_specimen_name,
			target_method_code,
			target_method_name,
			target_property_code,
			target_property_name,
			target_scale_code,
			target_scale_name,
			target_time_code,
			target_time_name,
			component_code,
			component_name,
			specimen_code,
			specimen_name,
			method_code,
			method_name,
			property_code,
			property_name,
			scale_code,
			scale_name,
			time_code,
			time_name
		FROM ax6
		--exlude wrong matching
		WHERE target_concept_code NOT IN (
				SELECT target_concept_code
				FROM ax6
				WHERE property_name = 'Presence'
					AND target_concept_name ILIKE '%level%'
				)
			AND target_concept_code NOT IN (
				SELECT target_concept_code
				FROM ax6
				WHERE property_name <> 'Presence'
					AND target_concept_name ILIKE '%screening%'
				)
			AND (
				concept_name,
				target_concept_name
				) NOT IN (
				SELECT concept_name,
					target_concept_name
				FROM ax6
				WHERE concept_name ILIKE '%manual%'
					AND target_concept_name ILIKE '%automated%'
				)
			AND (
				concept_name,
				target_concept_name
				) NOT IN (
				SELECT concept_name,
					target_concept_name
				FROM ax6
				WHERE concept_name NOT ILIKE '%automated%'
					AND target_concept_name ILIKE '%automated%'
				)
		
		UNION ALL
		
		SELECT *
		FROM ax7
		/*UNION ALL

		SELECT *
		FROM ax8*/
		)
SELECT rt.concept_code AS concept_code_1,
	rt.target_concept_code AS concept_code_2,
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM resulting_table rt
JOIN vocabulary v ON v.vocabulary_id = 'LOINC' -- get valid_start_date
--TODO: to-many comes from ax7, can be improved by window function + maybe something else
WHERE rt.concept_code NOT IN (
		SELECT rt_int.concept_code
		FROM resulting_table rt_int
		GROUP BY rt_int.concept_code
		HAVING COUNT(*) > 1
		)
ON CONFLICT DO NOTHING;

--22. Build hierarchical links 'Is a' from LOINC Lab Tests to SNOMED Measurements with the use of LOINC Component - SNOMED Attribute name similarity in concept_relationship_stage
ANALYZE concept_relationship_stage;
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
SELECT cs1.concept_code AS concept_code_1,
	c.concept_code AS concept_code_2,
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
-- get LOINC Components for all LOINC Measurements
FROM concept_relationship_stage crs
JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
	AND cs1.vocabulary_id = crs.vocabulary_id_1 -- LOINC Measurement
	AND cs1.vocabulary_id = 'LOINC'
	AND cs1.standard_concept = 'S'
	AND cs1.invalid_reason IS NULL
	AND cs1.concept_name !~* 'susceptibility|protein\.monoclonal' -- susceptibility may have property other than 'Susc'
	AND cs1.concept_code NOT IN ('26760-9', '70144-1', '70145-8', '20413-1', '42860-7', '70143-3',
	                            '26760-9', '70144-1', '70145-8', '16243-8', '16542-3', '16543-1',
                                '26856-5', '27024-9', '33282-5', '33561-2', '48942-7', '50338-3',
                                '59160-2', '8170-3', '8176-0')
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.relationship_id = 'Is a'
			AND crs_int.vocabulary_id_2 = 'SNOMED'
			AND crs_int.concept_code_1 = cs1.concept_code
		) -- exclude duplicates
JOIN concept_stage cs2 ON cs2.concept_code = crs.concept_code_2
	AND cs2.vocabulary_id = crs.vocabulary_id_2 -- LOINC Component
-- get SNOMED Measurements using name similarity (LOINC Component||' measurement' = SNOMED Measurement)
JOIN concept c ON LOWER(c.concept_name) = COALESCE(LOWER(SPLIT_PART(cs2.concept_name, '^', 1)) || ' measurement', LOWER(SPLIT_PART(cs2.concept_name, '.', 1)) || ' measurement', LOWER(cs2.concept_name) || ' measurement') -- SNOMED Measurement
	AND c.vocabulary_id = 'SNOMED'
	AND c.domain_id = 'Measurement'
	AND c.standard_concept = 'S'
	AND c.concept_code NOT IN (
		'16298007',
		'24683000'
		) -- 'Rate measurement', 'Uptake measurement'
JOIN vocabulary v ON v.vocabulary_id = 'LOINC' -- get valid_start_date
	-- weed out LOINC Measurements with inapplicable properties in the SNOMED architecture context
JOIN sources.loinc j ON j.loinc_num = cs1.concept_code
	AND j.property !~ 'Rto|Ratio|^\w.Fr|Imp|Prid|Zscore|Susc|^-$' -- ratio/interpretation/identifier/z-score/susceptibility-related concepts
WHERE crs.relationship_id = 'Has component'
	AND crs.vocabulary_id_1 = 'LOINC'
	AND crs.vocabulary_id_2 = 'LOINC'
	AND crs.invalid_reason IS NULL;

--23. Drop temporary links (currently, the source does not support the LOINC-SNOMED refsets, so we do not have to add such links to CDM)
DELETE
FROM concept_relationship_stage
WHERE vocabulary_id_1 = 'LOINC'
	AND vocabulary_id_2 = 'SNOMED'
	AND relationship_id <> 'Is a';

--24. Build 'LOINC - CPT4 eq' relationships (mappings) from LOINC Measurements to CPT4 Measurements or Procedures with the use of a 'sources.cpt_mrsmap' table (mappings)
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
SELECT UNNEST(STRING_TO_ARRAY(l.toexpr, ',')) AS concept_code_1, -- CPT4 code
	l.fromexpr AS concept_code_2, -- LOINC code
	'CPT4' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	'CPT4 - LOINC eq' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.cpt_mrsmap l,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC';

--25. Build 'Concept replaced by' relationships for updated LOINC concepts and deprecate already existing replacing mappings with the use of a 'sources.map_to' table
--TODO: Consider using 1-to-many source mappings as "Maps to"
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

--26. Add LOINC Document Ontology concepts with the use of a 'sources.loinc_documentontology' table to the concept_stage
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
	AND d.partname NOT LIKE '{%}';-- decision to exclude LP173061-5 '{Settings}' and LP187187-2 '{Role}' PartNames was probably made due to vague reverse relationship formulations: Concept X 'Has setting' '{Setting}' or Concept Y 'Has role' {Role}.

--27. Makes deprecated "Maps to" relationships for concepts that was Non-Standard and became Standard
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
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	r.relationship_id,
	r.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'LOINC'
			AND latest_update IS NOT NULL
		),
	'D'
FROM concept c1
JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
	AND r.relationship_id = 'Concept replaced by'
	AND r.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_id = r.concept_id_2
WHERE c1.vocabulary_id = 'LOINC'
	AND c2.vocabulary_id = 'LOINC'
	AND NOT EXISTS (
		SELECT 1
		FROM sources.map_to m
		WHERE c1.concept_code IN (
				m.loinc,
				m.map_to
				)
		);

--28. Build 'Has type of service', 'Has subject matter', 'Has role', 'Has setting', 'Has kind' reverse relationships from LOINC concepts indicating Measurements or Observations to LOINC Document Ontology concepts
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

--29. Add hierarchical LOINC Group Category and Group concepts to the concept_stage
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
--add LOINC Groups
WITH gr_tab AS (
		--fix LOINC Groups names
		WITH tab_splitted AS (
				SELECT DISTINCT SPLIT_PART(lgroup, '|', 1) AS test_name,
					CASE 
						WHEN SPLIT_PART(lgroup, '|', 2) = 'MCnt'
							THEN 'Mass Content'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Temp'
							THEN 'Temperature'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'ACnc'
							THEN 'Arbitrary Concentration'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Imp'
							THEN 'Impression/interpretation of study'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'CRto'
							THEN 'Catalytic Ratio'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'NCncRange'
							THEN 'Number Concentration (count/vol) Range'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'MRat'
							THEN 'Mass Rate'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'MFr.DF'
							THEN 'Mass Decimal Fraction'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'SRat'
							THEN 'Substance Rate'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'MFr'
							THEN 'Mass Fraction'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'ThreshNum'
							THEN 'Threshold Number'
						WHEN SPLIT_PART(lgroup, '|', 2) = '12H'
							THEN '12 hours'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'PrThr'
							THEN 'Presence or Threshold'
						WHEN SPLIT_PART(lgroup, '|', 2) = '24H'
							THEN '24 hours'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Pt'
							THEN 'Moment in time'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'NFr'
							THEN 'Number Fraction'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'ANYTypeofService'
							THEN 'Any Type of Service'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Prid'
							THEN 'Presence or Identity'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'VRat'
							THEN 'Volume Rate'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Pres'
							THEN 'Pressure'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'ANYRole'
							THEN 'Any Role'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'MCnc'
							THEN 'Mass Concentration'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Vol'
							THEN 'Volume'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'CCnc'
							THEN 'Catalytic Concentration'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'MRto'
							THEN 'Mass Ratio'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'ANYProp'
							THEN 'Any Property'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'XXX'
							THEN 'Not specified'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'ANYTypeOfService'
							THEN 'Any Type Of Service'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Naric'
							THEN 'Number Aeric'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'MSCnc'
							THEN 'Mass or Substance Concentration'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'LnCnc'
							THEN 'Log Number Concentration'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'CRat'
							THEN 'Catalytic Rate'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'SCnc'
							THEN 'Substance Concentration'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'CCnt'
							THEN 'Catalytic Content'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'CFr'
							THEN 'Catalytic Fraction'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'SRto'
							THEN 'Substance Ratio'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'LsCnc'
							THEN 'Log Substance Concentration'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'ArVRat'
							THEN 'Volume Rate/Area'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'SCnt'
							THEN 'Substance Content'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'NCnc'
							THEN 'Number Concentration (count/vol)'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'NRat'
							THEN 'Number=Count/Time'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Len'
							THEN 'Length'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'PPres'
							THEN 'Pressure (partial)'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Titr'
							THEN 'Titer'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Rden'
							THEN 'Relative Density'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Num'
							THEN 'Number'
						WHEN SPLIT_PART(lgroup, '|', 2) = 'Osmol'
							THEN 'Osmolality'
						ELSE SPLIT_PART(lgroup, '|', 2)
						END AS property,
					CASE 
						WHEN SPLIT_PART(lgroup, '|', 3) = 'TPN'
							THEN 'Total parental nutrition'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'ANYKindOfNote'
							THEN 'Any Kind Of Note'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Plr fld'
							THEN 'Pleural fluid'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Bld'
							THEN 'Blood'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Plas'
							THEN 'Plasma'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'BldV'
							THEN 'Blood venous'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Vitr fld'
							THEN 'Vitreous Fluid'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'BldA'
							THEN 'Blood arterial'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'BldC'
							THEN 'Blood capillary'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Amnio fld'
							THEN 'Amniotic fluid'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Bld.dot'
							THEN 'Blood filter paper'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Dial fld'
							THEN 'Dialysis fluid'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Ser/Plas/Bld'
							THEN 'Blood, Serum or Plasma'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Dial fld prt'
							THEN 'Peritoneal dialysis fluid'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Sys:ANYResp'
							THEN 'Any Respiratory specimen'
						WHEN SPLIT_PART(lgroup, '|', 3) = '24H'
							THEN '24 hours'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Gast fld'
							THEN 'Gastric fluid'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Asp'
							THEN 'Aspirate'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Pt'
							THEN 'Moment in time'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Synv fld'
							THEN 'Synovial fluid'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'ANYTm'
							THEN 'Any Time'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'BldCo'
							THEN 'Blood – cord'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'ANYSetting'
							THEN 'Any Setting'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Sys:ANYEYE'
							THEN 'Any Eye specimen'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Flu.nonbiological'
							THEN 'Nonbiological fluid'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Body fld'
							THEN 'Body fluid, unspecified'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Sys:ANYGU'
							THEN 'Any Genital specimen'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'PPP'
							THEN 'Platelet poor plasma'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Ser/Plas'
							THEN 'Serum or Plasma'
						WHEN SPLIT_PART(lgroup, '|', 3) = 'Ser'
							THEN 'Serum'
						ELSE SPLIT_PART(lgroup, '|', 3)
						END AS TIME,
					CASE 
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Chal:None'
							THEN 'Without specimen'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Plr fld'
							THEN 'Pleural fluid'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'ANYMethod'
							THEN 'Any Method'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'BAL'
							THEN 'Bronchoalveolar lavage'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Bld'
							THEN 'Blood'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Plas'
							THEN 'Plasma'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Bld.dot'
							THEN 'Blood filter paper'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Laterality:ANY'
							THEN 'Any Laterality'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Dial fld'
							THEN 'Dialysis fluid'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Dial fld prt'
							THEN 'Peritoneal dialysis fluid'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Amnio fld'
							THEN 'Amniotic fluid'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'ANYSys'
							THEN 'Any System'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Gast fld'
							THEN 'Gastric fluid'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'RIA'
							THEN 'Radioimmunoassay'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'ANYUrine'
							THEN 'Any Urine specimen'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Synv fld'
							THEN 'Synovial fluid'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'BldCo'
							THEN 'Blood – cord'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'BCG'
							THEN 'Bromocresol green'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'ANYRole'
							THEN 'Any Role'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Tiss'
							THEN 'Tissue'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'ANYSetting'
							THEN 'Any Setting'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'HPLC'
							THEN 'High-performance liquid chromatography'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'IA'
							THEN 'Immunoassay'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'BCP'
							THEN 'Bromocresol purple'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Body fld'
							THEN 'Body fluid, unspecified'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'ANYBldSerPl'
							THEN 'Blood, Serum or Plasma'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'ISE'
							THEN 'Ion-selective membrane electrode'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Urine+Ser/Plas'
							THEN 'Urine and Serum or Plasma'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'RBC'
							THEN 'Erythrocytes'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Pericard fld'
							THEN 'Pericardial fluid'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Periton fld'
							THEN 'Peritoneal fluid /ascites'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'Bone mar'
							THEN 'Bone Marrow'
						WHEN SPLIT_PART(lgroup, '|', 4) = 'CSF'
							THEN 'Cerebral spinal fluid'
						ELSE SPLIT_PART(lgroup, '|', 4)
						END AS specimen,
					CASE 
						WHEN SPLIT_PART(lgroup, '|', 5) = 'ANYSubjectMatterDomain'
							THEN 'Any Subject Matter Domain'
						WHEN SPLIT_PART(lgroup, '|', 5) = 'ANYMeth'
							THEN 'Any Method'
						ELSE SPLIT_PART(lgroup, '|', 5)
						END AS method,
					groupid AS concept_code
				FROM sources.loinc_group
				WHERE parentgroupid <> 'LG85-3'
				) --Groups non-related to Radiology
		SELECT TRIM(REGEXP_REPLACE(CONCAT (
						test_name,
						'|',
						property,
						'|',
						TIME,
						'|',
						specimen,
						'|',
						method
						), '\|+$', '')) AS concept_name, -- LOINC Group name
			concept_code -- LOINC Group code
		FROM tab_splitted
		
		UNION ALL
		
		SELECT TRIM(lgroup) AS concept_name, -- LOINC Group name
			groupid AS concept_code -- LOINC Group code
		FROM sources.loinc_group
		WHERE parentgroupid = 'LG85-3' --Groups related to Radiology
		)
SELECT concept_name,
	'Measurement' AS domain_id,
	v.vocabulary_id AS vocabulary_id,
	'LOINC Group' AS concept_class_id,
	'C' AS standard_concept,
	concept_code, -- LOINC Group code
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM gr_tab
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'

UNION ALL

--add LOINC Group Categories
SELECT DISTINCT TRIM(lgt.category) AS concept_name, -- LOINC Category name from sources.loinc_grouploincterms
	'Measurement' AS domain_id,
	v.vocabulary_id AS vocabulary_id,
	'LOINC Group' AS concept_class_id,
	'C' AS standard_concept,
	lg.parentgroupid AS concept_code, -- LOINC Category code from sources.loinc_group
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_group lg -- table with codes of LOINC Category concepts
JOIN sources.loinc_grouploincterms lgt ON lgt.groupid = lg.groupid -- table with names of LOINC Category concepts
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
WHERE lgt.category IS NOT NULL;

--30 Update radiology Group Domains
UPDATE concept_stage cs
SET domain_id = 'Procedure'
FROM sources.loinc_group lg
WHERE cs.concept_code = lg.groupid
	AND lg.parentgroupid = 'LG85-3';

UPDATE concept_stage cs
SET domain_id = 'Procedure'
WHERE cs.concept_code IN (
		'LG85-3', --Radiology
		'LG41849-7', --Region imaged: Lower extremity
		'LG41814-1', --Radiology
		'LG51408-9', --US|Breast|Guidance for cryoablation|Any Laterality
		'LG51409-7' --MR|Kidney|Guidance for percutaneous biopsy|Any Laterality
		);

--31. Build 'Is a' relationships to create a hierarchy for LOINC Group Categories and Groups
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

--32. Add LOINC Group Categories and Groups to the concept_synonym_stage
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
	vocabulary_pack.CutConceptSynonymName(lpga.lvalue) AS synonym_name, -- long description of LOINC Group Categories
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM sources.loinc_parentgroupattributes lpga;-- table with descriptions of LOINC Group Categories

--33. Add Chinese language synonyms (AVOF-2231) from UMLS
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT m.str,
	cs.concept_code,
	'LOINC',
	4182948 --Chinese language
FROM concept_stage cs
JOIN sources.mrconso m ON m.code = cs.concept_code
	AND m.sab = 'LNC-ZH-CN';

--34. Working with manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--35. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--36. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--37. Add mapping (to value) from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--38. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--39. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--40. Build reverse relationships. This is necessary for the next point.
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

--41. Add to the concept_relationship_stage and deprecate all relationships which do not exist there
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
WHERE a.vocabulary_id = 'LOINC'
	AND b.vocabulary_id IN (
		'LOINC',
		'SNOMED'
		)
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

--42. Clean up
DROP TABLE sn_attr, lc_attr;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
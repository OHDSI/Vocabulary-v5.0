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
* Date: 2020
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
			    OR (
		        long_common_name ~* 'note|Note'
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
        WHEN l.status IN (
				'DEPRECATED'
				) THEN NULL
        WHEN l.status IN (
	        'DISCOURAGED'
            ) AND l.loinc_num IN (SELECT DISTINCT loinc FROM sources.map_to GROUP BY 1 HAVING COUNT(DISTINCT map_to) = 1)
	        THEN NULL
        WHEN l.status IN (
	        'DISCOURAGED'
            ) AND l.loinc_num in (select distinct loincnumber from sources.loinc_partlink_primary where partnumber = 'LP33032-1')
	        THEN NULL
        ELSE 'S'
        END AS standard_concept,
	LOINC_NUM AS concept_code,
	v.latest_update AS valid_start_date,
	CASE
		WHEN l.status IN (
				'DEPRECATED'
				)
			THEN CASE
					WHEN c.valid_end_date > v.latest_update
						OR c.valid_end_date IS NULL
						THEN v.latest_update
					ELSE c.valid_end_date
					END
	    WHEN l.status IN (
	        'DISCOURAGED'
            ) AND l.loinc_num IN (SELECT DISTINCT loinc FROM sources.map_to GROUP BY 1 HAVING COUNT(DISTINCT map_to) = 1)
	        THEN CASE
					WHEN c.valid_end_date > v.latest_update
						OR c.valid_end_date IS NULL
						THEN v.latest_update
					ELSE c.valid_end_date
					END
	    WHEN l.status IN (
	        'DISCOURAGED'
            ) AND l.loinc_num in (select distinct loincnumber from sources.loinc_partlink_primary where partnumber = 'LP33032-1')
	        THEN CASE
					WHEN c.valid_end_date > v.latest_update
						OR c.valid_end_date IS NULL
						THEN v.latest_update
					ELSE c.valid_end_date
					END
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE
	    WHEN l.loinc_num IN (select distinct loinc from sources.map_to group by 1 having count(distinct map_to) = 1)
	                    AND l.status IN ('DISCOURAGED')
	    THEN 'U'
	    WHEN l.loinc_num IN (select distinct loinc from sources.map_to)
	                    AND l.status IN ('DEPRECATED')
	    THEN 'U'
		WHEN l.status IN (
				'DEPRECATED'
				)
			THEN 'D'
	    WHEN l.status IN (
				'DISCOURAGED'
				) AND l.loinc_num IN (SELECT DISTINCT loinc FROM sources.map_to GROUP BY 1 HAVING COUNT(DISTINCT map_to) = 1)
			THEN 'D'
	    WHEN l.status IN (
				'DISCOURAGED'
				) AND l.loinc_num in (select distinct loincnumber from sources.loinc_partlink_primary where partnumber = 'LP33032-1') AND l.loinc_num not in (SELECT DISTINCT loinc FROM sources.map_to)
			THEN 'D'
		ELSE NULL
		END AS invalid_reason
FROM sources.loinc l
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
LEFT JOIN concept c ON c.concept_code = l.LOINC_NUM
	AND c.vocabulary_id = 'LOINC';


--todo: confirm that these concepts are not expected to be Measurements storing the result
--todo: define concept_class_id
--3.1. Update Domains for concepts representing Imaging procedures based on hierarchy
UPDATE concept_stage
SET domain_id = 'Procedure'
WHERE concept_code IN (SELECT DISTINCT loinc_num
                       FROM sources.loinc
                       WHERE class = 'RAD')
  AND concept_code NOT IN (select loincnumber
                           from sources.loinc_partlink_primary
                           where partnumber in ('LP7753-9', 'LP200093-5', 'LP200395-4'));

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
	WHERE (NOT EXISTS (
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
				))
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
	AND c2.invalid_reason IS NULL
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
				JOIN concept_relationship cr ON cr.concept_id_1=c1.concept_id
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
			WHERE kk.cnt = 1
				AND kk.sn_name NOT ilike '%screening%'
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
					'413058006'
					) -- SNOMED concepts with wrong sets of attributes
			), -- exclude concepts with multiple attributes from one category
		-- get a list of Fully defined SNOMED concepts, using sources.sct2_concept_full_merged, to weed out Primitive SNOMED Measurements composed of inadequate attribute set
		snomed_concept AS (
			SELECT *
			FROM (
				SELECT DISTINCT c.concept_code,
					FIRST_VALUE(f.statusid) OVER (
						PARTITION BY f.id ORDER BY f.effectivetime DESC
						) AS statusid -- the 'statusid' field may be both Fully define and Primitive at the same time, to distinguish Fully define ones use 'effectivetime' field
				FROM sources.sct2_concept_full_merged f -- the source table indicating 'definition status' of SNOMED concepts
				JOIN concept c ON c.vocabulary_id = 'SNOMED'
					AND c.standard_concept = 'S'
					AND c.concept_code = f.id::VARCHAR
				) AS s0
			WHERE statusid = 900000000000073002
			)

SELECT zz.*
FROM t1 zz
JOIN snomed_concept sc ON sc.concept_code = zz.sn_code;

--create an index for the temporary table of 'sn_attr' to speed up next table creation
CREATE INDEX idx_sa_name ON sn_attr (LOWER (attr_name));
CREATE INDEX idx_sa_sncode ON sn_attr (sn_code);
ANALYZE sn_attr;

--'LC_ATTR' contains normalized set of relationships between LOINC Measurements and SNOMED Attributes
DROP TABLE IF EXISTS lc_attr;
CREATE UNLOGGED TABLE lc_attr AS (
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
					THEN '119297000' -- 	Blood specimen
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
			AND c.invalid_reason IS NULL
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
	attr_code FROM (
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
	WHERE lc_name !~* 'susceptibility|protein\.monoclonal'
	);-- susceptibility may have property other than 'Susc'

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
	-- AXIS 3: get 2-attribute Measurements (Component+Scale)
	ax_3 AS (
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
	-- AXIS 4: get 1-attribute Measurements (Component)
	ax_4 AS (
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
			AND z1.lc_code NOT IN (
				SELECT ax_1_int.lc_code
				FROM ax_1 ax_1_int
				)
			AND z1.lc_code NOT IN (
				SELECT ax_2_int.lc_code
				FROM ax_2 ax_2_int
				)
			AND z1.lc_code NOT IN (
				SELECT ax_3_int.lc_code
				FROM ax_3 ax_3_int
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
		FROM ax_3

		UNION ALL

		SELECT *
		FROM ax_4
		)
-- get input for concept_relationship_stage
SELECT lc_code AS concept_code_1,
	--lc_name,
	sn_code AS concept_code_2,
	--   sn_name,
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
		a_x.sn_name ilike '%dipstick%'
		AND a_x.lc_name NOT ilike '%test strip%'
		OR (
			a_x.lc_name ~* 'titer|presence'
			AND a_x.sn_name ilike '% level%'
			)
		OR (
			a_x.lc_name NOT ilike '%titer%'
			AND a_x.sn_name ilike '% titer%'
			)
		OR (
			a_x.lc_name LIKE '%/%'
			AND a_x.sn_name ilike '% titer%'
			)
		OR (
			a_x.lc_name !~* 'count|100|#'
			AND a_x.sn_name ilike '%count%'
			)
		OR (
			a_x.lc_name ~* 'morpholog|presence'
			AND a_x.sn_name ilike '%count%'
			)
		OR (
			a_x.lc_name NOT ilike '%fasting glucose%'
			AND a_x.sn_name ilike '%fasting glucose%'
			)
		OR (
			a_x.lc_name NOT ilike '%microscop%'
			AND a_x.sn_name ilike '%microscop%'
			)
		OR (
			a_x.lc_name !~* 'culture|isolate'
			AND a_x.sn_name ilike '%culture%'
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
			a_x.lc_name ilike '%fasting glucose%'
			AND a_x.sn_name NOT ilike '%fasting glucose%'
			OR a_x.lc_name ilike '%test strip%'
			AND a_x.sn_name NOT ilike '%dipstick%'
			)
		AND sn_name NOT ilike '%quantitative%'
		);

--21. Build hierarchical links 'Is a' from LOINC Lab Tests to SNOMED Measurements with the use of LOINC Component - SNOMED Attribute name similarity in CONCEPT_RELATIONSHIP_STAGE
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

--22. drop temporary links (currently, the source does not support the LOINC-SNOMED refsets, so we do not have to add such links to CDM)
DELETE
FROM concept_relationship_stage
WHERE vocabulary_id_1 = 'LOINC'
	AND vocabulary_id_2 = 'SNOMED'
	AND relationship_id <> 'Is a';

--23. Build 'LOINC - CPT4 eq' relationships (mappings) from LOINC Measurements to CPT4 Measurements or Procedures with the use of a 'sources.cpt_mrsmap' table (mappings)
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

--24. Build 'Concept replaced by' relationships for updated LOINC concepts and deprecate already existing replacing mappings with the use of a 'sources.map_to' table
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

--25. Add LOINC Document Ontology concepts with the use of a 'sources.loinc_documentontology' table to the concept_stage
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

--26. Makes deprecated "Maps to" relationships for concepts that was Non-Standard and became Standard
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


--27. Build 'Has type of service', 'Has subject matter', 'Has role', 'Has setting', 'Has kind' reverse relationships from LOINC concepts indicating Measurements or Observations to LOINC Document Ontology concepts
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

--28. Add hierarchical LOINC Group Category and Group concepts to the concept_stage
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
JOIN sources.loinc_grouploincterms lgt ON lgt.groupid = lg.groupid-- table with names of LOINC Category concepts
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
WHERE lgt.category IS NOT NULL

UNION ALL

--add LOINC Groups
SELECT TRIM(lg.lgroup) AS concept_name, -- LOINC Group name
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

--29. Build 'Is a' relationships to create a hierarchy for LOINC Group Categories and Groups
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

--30. Add LOINC Group Categories and Groups to the concept_synonym_stage
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

--31. Add Chinese language synonyms (AVOF-2231) from UMLS
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

--32. Working with manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--33. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--34. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--35. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--36. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--37. Build reverse relationships. This is necessary for the next point.
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

--38. Add to the concept_relationship_stage and deprecate all relationships which do not exist there
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

--39. Clean up
DROP TABLE sn_attr, lc_attr;
-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script

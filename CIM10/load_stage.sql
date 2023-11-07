/**************************************************************************
* Copyright 2020 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Timur Vakhitov, Dmitry Dymshyts
* Date: 2022
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CIM10',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.cim10 LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.cim10 LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CIM10'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Fill the concept_stage
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
SELECT vocabulary_pack.CutConceptName(lib_complet) AS concept_name,
	NULL AS domain_id,
	'CIM10' AS vocabulary_id,
	CASE 
		WHEN LENGTH(code) = 3
			THEN 'ICD10 Hierarchy'
		ELSE 'ICD10 code'
		END AS concept_class_id,
	NULL AS standard_concept,
	REGEXP_REPLACE(code, '(.{3})(.+)', '\1.\2') AS concept_code, --add a dot after the 3d position
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CIM10'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.cim10;

--4. Inherit external relations from international ICD10 whenever possible
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT c.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'CIM10' AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	r.relationship_id AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CIM10'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage cs
JOIN concept c ON c.concept_code = cs.concept_code
	AND c.vocabulary_id = 'ICD10'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id IN (
		'Maps to',
		'Maps to value'
		)
JOIN concept c2 ON c2.concept_id = r.concept_id_2;

--5. Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--6. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--7. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--8. Add mapping from deprecated to fresh concepts for 'Maps to value'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--10. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--11. Add "subsumes" relationship between concepts where the concept_code is like of another
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
ANALYZE concept_stage;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CIM10'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage c1
JOIN concept_stage c2 ON c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code;

DROP INDEX trgm_idx;

--12. Update domain_id for ICD10 from target concepts domains
ANALYZE concept_relationship_stage;

UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	(
		SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
			c2.domain_id
		FROM concept_relationship_stage crs
		JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
			AND cs1.vocabulary_id = crs.vocabulary_id_1
			AND cs1.vocabulary_id = 'CIM10'
		JOIN concept c2 ON c2.concept_code = crs.concept_code_2
			AND c2.vocabulary_id = crs.vocabulary_id_2
		WHERE crs.relationship_id = 'Maps to'
			AND crs.invalid_reason IS NULL
		ORDER BY cs1.concept_code,
			CASE c2.domain_id
				WHEN 'Condition'
					THEN 1
				WHEN 'Observation'
					THEN 2
				WHEN 'Procedure'
					THEN 3
				WHEN 'Measurement'
					THEN 4
				WHEN 'Device'
					THEN 5
				END
		)
	
	UNION ALL
	
	(
		SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
			c2.domain_id
		FROM concept_relationship cr
		JOIN concept c1 ON c1.concept_id = cr.concept_id_1
			AND c1.vocabulary_id = 'CIM10'
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		JOIN concept_stage cs1 ON cs1.concept_code = c1.concept_code
			AND cs1.vocabulary_id = c1.vocabulary_id
		WHERE cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
			AND NOT EXISTS (
				SELECT 1
				FROM concept_relationship_stage crs_int
				WHERE crs_int.concept_code_1 = cs1.concept_code
					AND crs_int.vocabulary_id_1 = cs1.vocabulary_id
					AND crs_int.relationship_id = cr.relationship_id
				)
		ORDER BY cs1.concept_code,
			CASE c2.domain_id
				WHEN 'Condition'
					THEN 1
				WHEN 'Observation'
					THEN 2
				WHEN 'Procedure'
					THEN 3
				WHEN 'Measurement'
					THEN 4
				WHEN 'Device'
					THEN 5
				END
		)
	) i
WHERE i.concept_code = cs.concept_code;

--13. Manual fix for concepts without mapping
UPDATE concept_stage
SET domain_id = 'Observation'
WHERE domain_id IS NULL;

--14. Fill synonyms
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT lib_complet AS synonym_name,
	REGEXP_REPLACE(code, '(.{3})(.+)', '\1.\2') AS synonym_concept_code,
	'CIM10' AS synonym_vocabulary_id,
	4180190 AS language_concept_id -- French language
FROM sources.cim10;

--15. Update concept_stage, set english names from ICD10
UPDATE concept_stage cs
SET concept_name = c.concept_name
FROM concept c
WHERE c.concept_code = cs.concept_code
	AND c.vocabulary_id = 'ICD10';

--16. Translate the rest of names
DROP TABLE cim10_translated_source;
TRUNCATE TABLE cim10_translated_source;
CREATE TABLE cim10_translated_source
(concept_code text,
concept_name  text,
concept_name_translated text);

INSERT INTO  cim10_translated_source
    SELECT concept_code,
           concept_name,
           null as concept_name_translated
    FROM concept_stage
where concept_code not in (SELECT concept_code FROM concept c where c.vocabulary_id = 'ICD10')
;

--Translation
DO $_$
BEGIN
	PERFORM google_pack.GTranslate(
		pInputTable    =>'cim10_translated_source',
		pInputField    =>'concept_name',
		pOutputField   =>'concept_name_translated',
		pDestLang      =>'en',
	    pSrcLang       =>'fr'
	);
END $_$;

UPDATE cim10_translated_source
SET concept_name_translated = cim10_translated_source.concept_name_translated ||' (machine translation)';

WITH cut as (
SELECT
       ts.concept_name,
       CASE WHEN LENGTH(TRIM(concept_name_translated)) > 255
			THEN TRIM(SUBSTR(TRIM(concept_name_translated), 1, 252)) || '...'
		ELSE TRIM(concept_name_translated) END as cut_name
FROM cim10_translated_source ts)

UPDATE concept_stage cs
SET concept_name = cut.cut_name
FROM cut
WHERE cs.concept_name = cut.concept_name;

--Manual fix for names with '!ERROR: %' patterns
UPDATE concept_stage
SET concept_name = 'Passenger of a car injured in a collision with a cycle, non-traffic accident, while participating in an unspecified activity (machine translation)'
WHERE concept_code = 'V41.19';

UPDATE concept_stage
SET concept_name = 'Van driver injured in collision with train or rail vehicle, traffic accident, while resting, sleeping, eating or participating in other essential activities (machine translation)'
WHERE concept_code = 'V55.54';

UPDATE concept_stage
SET concept_name = 'Occupant of a bus injured in a transport accident, without collision, going up or down, while participating in other specified activities (machine translation)'
WHERE concept_code = 'V78.48';

UPDATE concept_stage
SET concept_name = 'Accident of other motorboats causing other traumatic injuries, while practicing a sport (machine translation)'
WHERE concept_code = 'V91.30';

UPDATE concept_stage
SET concept_name = 'Accident of other private fixed-wing aircraft injuring an occupant, while participating in an unspecified activity (machine translation)'
WHERE concept_code = 'V95.29';

UPDATE concept_stage
SET concept_name = 'Fall from a chair, industrial premises and construction site, while carrying out work for profit (machine translation)'
WHERE concept_code = 'W07.62';

UPDATE concept_stage
SET concept_name = 'Fall from a chair, farm (machine translation)'
WHERE concept_code = 'W07.7';

UPDATE concept_stage
SET concept_name = 'Falling from the top of a building or other structure, street or road, while resting, sleeping, eating or participating in other essential activities (machine translation)'
WHERE concept_code = 'W13.44';

UPDATE concept_stage
SET concept_name = 'Occupant, unspecified, of a heavy vehicle, injured in a collision with motor vehicles, other and unspecified, non-traffic accident, while participating in an unspecified activity (machine translation)'
WHERE concept_code = 'V69.29';

UPDATE concept_stage
SET concept_name = 'Water transport accident involving a passenger liner, other and unspecified, while participating in other specified activities (machine translation)'
WHERE concept_code = 'V94.18';

UPDATE concept_stage
SET concept_name = 'Dementia of Alzheimer''s disease, atypical or mixed form G30.8, with other symptoms, mostly depressive, severe (machine translation)'
WHERE concept_code = 'F00.232';

UPDATE concept_stage
SET concept_name = 'Compression, crushing or blocking in objects or between objects, collective establishment (machine translation)'
WHERE concept_code = 'W23.1';

UPDATE concept_stage
SET concept_name = 'Compression, crushing or jamming in or between objects, area of commerce, while participating in play and leisure activities (machine translation)'
WHERE concept_code = 'W23.51';

UPDATE concept_stage
SET concept_name = 'Contact with sharp glass, home, while participating in other specified activities (machine translation)'
WHERE concept_code = 'W25.08';

UPDATE concept_stage
SET concept_name = '*** SU17 *** Contact with a knife, sword or dagger, agricultural operation (machine translation)'
WHERE concept_code = 'W26.7';

UPDATE concept_stage
SET concept_name = 'Exposure to a high pressure jet, industrial premises and construction site, by participating in a game and leisure activities (machine translation)'
WHERE concept_code = 'W41.61';

UPDATE concept_stage
SET concept_name = 'Drowning and submersion in a bathtub, collective establishment, while practicing a sport (machine translation)'
WHERE concept_code = 'W65.10';

UPDATE concept_stage
SET concept_name = 'Drowning and submersion following a fall into natural waters, home, while participating in play and leisure activities (machine translation)'
WHERE concept_code = 'W70.01';

UPDATE concept_stage
SET concept_name = 'Exposure to ignition of a highly flammable substance, street or road (machine translation)'
WHERE concept_code = 'X04.4';

UPDATE concept_stage
SET concept_name = 'Exposure to other specified smoke, fires and flames, other specified locations, while practicing sport (machine translation)'
WHERE concept_code = 'X08.80';

UPDATE concept_stage
SET concept_name = 'Contact with boiling water from a tap, industrial premises and construction site (machine translation)'
WHERE concept_code = 'X11.6';

UPDATE concept_stage
SET concept_name = 'Accidental poisoning by analgesics, antipyretics and antirheumatic drugs, non-opiates and exposure to these products, industrial premises and construction site, while participating in an unspecified activity (machine translation)'
WHERE concept_code = 'X40.69';

UPDATE concept_stage
SET concept_name = 'Accidental poisoning by non-opioid analgesics, antipyretics and antirheumatic drugs and exposure to these products, farming, while carrying out other forms of work (machine translation)'
WHERE concept_code = 'X40.73';

UPDATE concept_stage
SET concept_name = 'Accidental poisoning by other gases and vapors while working for profit (machine translation)'
WHERE concept_code = 'X47.8+2';

UPDATE concept_stage
SET concept_name = 'Self-intoxication with and exposure to non-opioid analgesics, antipyretics, and antirheumatic drugs, at home, while participating in other specified activities (machine translation)'
WHERE concept_code = 'X60.08';

UPDATE concept_stage
SET concept_name = 'Self-inflicted injury by use of explosive material, collective establishment, while performing work for profit (machine translation)'
WHERE concept_code = 'X75.12';

UPDATE concept_stage
SET concept_name = 'Self-inflicted injury by use of blunt object, industrial premises and construction site, while resting, sleeping, eating or participating in other essential activities (machine translation)'
WHERE concept_code = 'X79.64';

UPDATE concept_stage
SET concept_name = 'Assault by carbon monoxide from domestic gas, industrial premises and construction sites, while working for profit (machine translation)'
WHERE concept_code = 'X88.162';

UPDATE concept_stage
SET concept_name = 'Attack by other specified chemicals and harmful products, home (machine translation)'
WHERE concept_code = 'X89.0';

UPDATE concept_stage
SET concept_name = 'Assault by explosive material, other specified locations (machine translation)'
WHERE concept_code = 'X96.8';

UPDATE concept_stage
SET concept_name = 'Carbon monoxide poisoning from unspecified source, undetermined intent, industrial premises and construction site, while resting, sleeping, eating or participating in other essential activities (machine translation)'
WHERE concept_code = 'Y17.464';

UPDATE concept_stage
SET concept_name = 'Discharge of a handgun, intent undetermined, location unspecified, while practicing a sport (machine translation)'
WHERE concept_code = 'Y22.90';

UPDATE concept_stage
SET concept_name = 'Contact with water vapor, gases and burning objects, intention not determined, other places specified, while participating in a game and leisure activities (machine translation)'
WHERE concept_code = 'Y27.81';

--concept_synonym_stage update
UPDATE concept_synonym_stage
SET synonym_name = css.synonym_name ||', ' || ts.concept_name_translated
FROM concept_synonym_stage css LEFT JOIN cim10_translated_source ts on css.synonym_concept_code = ts.concept_code
WHERE LENGTH(TRIM(ts.concept_name_translated)) > 255;

--16. Working with concept_manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
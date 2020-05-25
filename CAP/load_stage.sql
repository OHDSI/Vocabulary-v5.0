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
* Authors: Medical Team
* Date: 2020
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CAP',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.cap_xml_raw LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.cap_xml_raw LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CAP'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create parsed table
DROP TABLE IF EXISTS cap_hierarchy;
CREATE UNLOGGED TABLE cap_hierarchy AS
	select s_done.filename,s_done.officialname,s_done.cap_protocolversion,s_done.variable_code,s_done.var_concept_class,s_done.variable_description,s_done.variable_alt,s_done.value_code,s_done.val_concept_class,
	s_done.value_description,s_done.value_alt, case when s_done.item_depth=0 then 0 else row_number() over (partition by s_done.value_code order by s_done.item_depth) end as level_of_separation from (
		select s_all.filename, s_all.officialname, s_all.cap_protocolversion, substring(s_all.section_name,'_(.*)') as variable_code, s_all.item_depth, substring(s_all.section_name,'(.*)_') as var_concept_class,
		trim(regexp_replace(devv5.py_unescape(s_all.section_title), '[[:cntrl:]]+', ' ', 'g')) as variable_description,
		trim(regexp_replace(devv5.py_unescape(s_all.section_alt), '[[:cntrl:]]+', ' ', 'g')) as variable_alt,
		substring(s_all.item,'_(.*)') as value_code, substring(s_all.item,'(.*)_') as val_concept_class,
		trim(regexp_replace(devv5.py_unescape(s_all.item_title), '[[:cntrl:]]+', ' ', 'g')) as value_description,
		trim(regexp_replace(devv5.py_unescape(s_all.item_alt), '[[:cntrl:]]+', ' ', 'g')) as value_alt
		from (
			with xml_source as (
			select src0.filename, src0.officialname, src0.cap_protocolversion, src0.section_name, src0.section_position, src0.section_title, src0.section_alt, src0.sections,xmlfield from (
				select filename::text as filename,
				officialname::text as officialname,
				cap_protocolversion::text as cap_protocolversion,
				unnest(xpath('./@name',sections))::text as section_name,
				unnest(xpath('./@order',sections))::text::int section_position, --double cast due to xml->text->int
				unnest(xpath('./@title',sections))::text as section_title,
				unnest(xpath('./xmlns:Property/@val',sections,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']]))::text as section_alt,
				sections,i.xmlfield
				from sources.cap_xml_raw i,
				unnest(xpath('/xmlns:FormDesign/@filename', i.xmlfield,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']])) filename,
				unnest(xpath('/xmlns:FormDesign/xmlns:Property[@name="OfficialName"]/@val', i.xmlfield,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']])) officialname,
				unnest(xpath('/xmlns:FormDesign/xmlns:Property[@name="CAP_ProtocolVersion"]/@val', i.xmlfield,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']])) cap_protocolversion,
				unnest(xpath('/xmlns:FormDesign/xmlns:Body//*', i.xmlfield,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']])) sections
				) as src0
			where src0.section_name not like '%\_%\_%' and src0.section_name <>'ch_Body'
			)
			select filename,
			officialname,
			cap_protocolversion,
			section_name,
			section_title,
			section_alt,
			unnest(xpath('./@name',items))::text item,
			unnest(xpath('./@order',items))::text::int-section_position item_depth,
			unnest(xpath('./@title',items))::text item_title,
			unnest(xpath('./xmlns:Property/@val',items,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']]))::text item_alt
			from xml_source,
			unnest(xpath('.//xmlns:ListField/xmlns:List/xmlns:*',sections,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']])) items

			union all
			select filename,
			officialname,
			cap_protocolversion,
			section_name,
			section_title,
			section_alt,
			unnest(xpath('./@name',subitems))::text item,
			unnest(xpath('./@order',subitems))::text::int-section_position item_depth,
			unnest(xpath('./@title',subitems))::text item_title,
			unnest(xpath('./xmlns:Property/@val',subitems,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']]))::text item_alt
			from xml_source,
			unnest(xpath('.//xmlns:ChildItems/xmlns:*',sections,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']])) subitems
			
			--root elements without children
			union all
			select filename,
			officialname,
			cap_protocolversion,
			section_name,
			section_title,
			section_alt,
			null::text item,
			0::int item_depth,
			null::text item_title,
			null::text item_alt
			from xml_source
			left join lateral (select unnest(xpath('./xmlns:ListField/xmlns:List',sections,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']])) subitems) l on true
			left join lateral (select unnest(xpath('./xmlns:ChildItems',sections,ARRAY[ARRAY['xmlns', 'urn:ihe:qrph:sdc:2016']])) subitems) l1 on true
			where l.subitems is null and l1.subitems is null
		) as s_all
	) as s_done;

--4. Source table preparation
DROP TABLE IF EXISTS cap_cs_preliminary;
CREATE UNLOGGED TABLE cap_cs_preliminary AS
SELECT source_code AS concept_code,
	source_description AS concept_name,
	alt_source_description AS alternative_concept_name,
	CASE 
		WHEN source_class = 'CAP Protocol'
			OR (
				source_class = 'S'
				AND source_description NOT ILIKE 'Distance%'
				)
			THEN 'Observation' --todo How to treat 'CAP Protocol' in domain_id?
		WHEN source_class = 'LI' /*AND source_description !~* '^\.*other|^\.*specif.*'*/
			THEN 'Meas Value' --decided to leave them as values
		ELSE 'Measurement'
		END AS domain_id,
	'CAP' AS vocabulary_id,
	CASE 
		WHEN source_class = 'S'
			AND source_description NOT ILIKE 'Distance%'
			THEN 'CAP Header' --or 'CAP section'
		WHEN source_class = 'LI' /*AND source_description !~* '^\.*other|^\.*specif.*'*/
			THEN 'CAP Value' --^.*expla.* todo do we need them to be variables, decided to leave them as values
		WHEN source_class = 'CAP Protocol'
			THEN 'CAP Protocol'
		ELSE 'CAP Variable'
		END AS concept_class_id,
	NULL AS standard_concept,
	NULL AS invalid_reason,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CAP'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	source_filename,
	source_class
FROM (
	--primary step - full hierarchical names represented from bottom item (stated in source as value) to the top item with step_size=1 (for level_of_separation)
	WITH tab_val AS (
			SELECT value_code AS source_code,
				val_concept_class AS source_class,
				COALESCE(value_description, value_alt) AS alt_source_description,
				TRIM(CONCAT (
						COALESCE(value_description, value_alt),
						'|',
						STRING_AGG(COALESCE(variable_description, variable_alt), '|' ORDER BY level_of_separation)
						)) AS source_description, --full hierarchical explanation of source_code
				LEFT(filename, - 4) AS source_filename
			FROM cap_hierarchy
			WHERE value_code IS NOT NULL --used to exclude rows which are aggregation of all source_concepts in one for each  protocol
			GROUP BY value_code,
				COALESCE(value_description, value_alt),
				LEFT(filename, - 4),
				val_concept_class
			),
		--tab_var is created 'cause of some codes (with S,DI,Q classes) are not stated as values, they are 1)headers or 2)not conjugated with other source_codes as parent-child
		tab_var AS (
			SELECT DISTINCT variable_code AS source_code,
				var_concept_class AS source_class,
				COALESCE(variable_description, variable_alt) AS alt_source_description,
				TRIM(COALESCE(variable_description, variable_alt)) AS source_description,
				LEFT(filename, - 4) AS source_filename
			FROM cap_hierarchy
			WHERE variable_code NOT IN (
					SELECT source_code
					FROM tab_val
					)
			),
		tab_filename AS (
			SELECT DISTINCT LEFT(filename, - 4) AS source_code,
				'CAP Protocol' AS source_class,
				officialname || '. Version ' || cap_protocolversion AS source_description,
				officialname || '. Version ' || cap_protocolversion AS alt_source_description,
				LEFT(filename, - 4) AS source_filename
			FROM cap_hierarchy
			)
	SELECT source_code,
		source_class,
		source_description,
		alt_source_description,
		source_filename
	FROM tab_var
	
	UNION ALL
	
	SELECT source_code,
		source_class,
		source_description,
		alt_source_description,
		source_filename
	FROM tab_val
	
	UNION ALL
	
	SELECT source_code,
		source_class,
		source_description,
		alt_source_description,
		source_filename
	FROM tab_filename
	) AS s0
WHERE source_class <> 'DI' --to exclude them from concept_stage because of lack of sense(note section signature)
AND alt_source_description IS NOT NULL; -- --to exclude them from concept_stage because of lack of sense(still participate in hierarchy building);

--5. Load into concept stage
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
SELECT  CASE WHEN length(alternative_concept_name)>255 then concat(substring(alternative_concept_name from '.{1,251}\s'),'...') -- to get 255 length names
             ELSE alternative_concept_name END as alternative_concept_name,
	    domain_id,
	    vocabulary_id,
	    concept_class_id,
	    standard_concept,
	    CASE WHEN  length(concept_code)>50 THEN substr(concept_code,1,50) -- to get 50chars length codes
	      ELSE concept_code END AS cocnept_code,
	    valid_start_date,
	    valid_end_date,
	    invalid_reason
FROM cap_cs_preliminary;
ANALYZE concept_stage;

--6. Load into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT concept_name,
	   CASE WHEN  length(concept_code)>50 THEN substr(concept_code,1,50)
	        ELSE concept_code END AS concept_code,
	   vocabulary_id,
	   4180186 AS language_concept_id --for english language
FROM cap_cs_preliminary;

--7. Load into concept_relationship_stage
--7.1. 'CAP value of'
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
SELECT cs.concept_code AS concept_code_1,
	cs2.concept_code AS concept_code_2,
	'CAP' AS vocabulary_id_1,
	'CAP' AS vocabulary_id_2,
	'CAP value of' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CAP'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM cap_hierarchy e --put name the initial source_table with levels_of_separation (originated from xml file)
JOIN concept_stage cs
	ON e.value_code = cs.concept_code
JOIN concept_stage cs2
	ON e.variable_code = cs2.concept_code
WHERE e.level_of_separation = 1
	AND cs.concept_class_id = 'CAP Value'
	AND cs2.concept_class_id = 'CAP Variable';

--7.2. STEP1 'Has CAP parent item' INSERT
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
SELECT cs.concept_code AS concept_code_1,
	cs2.concept_code AS concept_code_2,
	'CAP' AS vocabulary_id_1,
	'CAP' AS vocabulary_id_2,
	'Has CAP parent item' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CAP'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM cap_hierarchy e --put name the initial source_table with levels_of_separation (originated from xml file)
JOIN concept_stage cs
	ON e.value_code = cs.concept_code
JOIN concept_stage cs2
	ON e.variable_code = cs2.concept_code
WHERE  e.level_of_separation = 1
	AND cs.concept_class_id = 'CAP Variable'
	AND cs2.concept_class_id = 'CAP Variable'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = cs.concept_code
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_2 = cs2.concept_code
		);

--7.3. STEP2 'Has CAP parent item' INSERT
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
SELECT cs.concept_code AS concept_code_1,
	cs2.concept_code AS concept_code_2,
	'CAP' AS vocabulary_id_1,
	'CAP' AS vocabulary_id_2,
	'Has CAP parent item' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CAP'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM cap_hierarchy e --put name the initial source_table with levels_of_separation (originated from xml file)
JOIN concept_stage cs
	ON e.value_code = cs.concept_code
JOIN concept_stage cs2
	ON e.variable_code = cs2.concept_code
WHERE e.level_of_separation = 1
	AND cs.concept_class_id = 'CAP Variable'
	AND cs2.concept_class_id = 'CAP Header'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = cs.concept_code
			AND crs_int.concept_code_2 = cs2.concept_code
		);

--7.4. STEP3 'Has CAP parent item' INSERT
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
SELECT cs.concept_code AS concept_code_1,
	cs2.concept_code AS concept_code_2,
	'CAP' AS vocabulary_id_1,
	'CAP' AS vocabulary_id_2,
	'Has CAP parent item' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CAP'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM cap_hierarchy e --put name the initial source_table with levels_of_separation (originated from xml file)
JOIN concept_stage cs
	ON e.value_code = cs.concept_code
JOIN concept_stage cs2
	ON e.variable_code = cs2.concept_code
WHERE e.level_of_separation = 1
	AND cs.concept_class_id = 'CAP Variable'
	AND cs2.concept_class_id = 'CAP Value'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = cs.concept_code
			AND crs_int.concept_code_2 = cs2.concept_code
		);

--7.5. STEP4 'Has CAP parent item' INSERT
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
SELECT cs.concept_code AS concept_code_1,
	cs2.concept_code AS concept_code_2,
	'CAP' AS vocabulary_id_1,
	'CAP' AS vocabulary_id_2,
	'Has CAP parent item' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CAP'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM cap_hierarchy e --put name the initial source_table with levels_of_separation (originated from xml file)
JOIN concept_stage cs
	ON e.value_code = cs.concept_code
JOIN concept_stage cs2
	ON e.variable_code = cs2.concept_code
WHERE e.level_of_separation = 1
	AND cs.concept_class_id = 'CAP Header'
	AND cs2.concept_class_id = 'CAP Value'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = cs.concept_code
			AND crs_int.concept_code_2 = cs2.concept_code
		);

--7.6. STEP5 'Has CAP parent item' INSERT
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
SELECT cs.concept_code AS concept_code_1,
	cs2.concept_code AS concept_code_2,
	'CAP' AS vocabulary_id_1,
	'CAP' AS vocabulary_id_2,
	'Has CAP parent item' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CAP'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM cap_hierarchy e --put name the initial source_table with levels_of_separation (originated from xml file)
JOIN concept_stage cs
	ON e.value_code = cs.concept_code
JOIN concept_stage cs2
	ON e.variable_code = cs2.concept_code
WHERE  e.level_of_separation = 1
	AND cs.concept_class_id IN (
		'CAP Variable',
		'CAP Header'
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = cs.concept_code
			AND crs_int.concept_code_2 = cs2.concept_code
		);

--7.7. 'Has CAP protocol'
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
SELECT concept_code AS concept_code_1,
	 CASE WHEN  length(source_filename)>50 THEN substr(source_filename,1,50) -- to get 50chars length codes
	      ELSE source_filename END AS concept_code_2,
	'CAP' AS vocabulary_id_1,
	'CAP' AS vocabulary_id_2,
	'Has CAP protocol' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CAP'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM cap_cs_preliminary
WHERE concept_code <> source_filename;

--8. Add manual source
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--9. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--10. Add mapping from deprecated to fresh concepts (necessary for the next step)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--11. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--12. Clean up
DROP TABLE cap_hierarchy;
DROP TABLE cap_cs_preliminary;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
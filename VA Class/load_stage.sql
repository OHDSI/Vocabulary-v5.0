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
* Date: 2021
**************************************************************************/

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'VA Class',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_VACLASS'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
INSERT INTO concept_stage (
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
SELECT rx.rxaui::INT4, --store rxaui as concept_id, this field is needed below for relationships
	vocabulary_pack.CutConceptName(rx.str) AS concept_name,
	'Drug' AS domain_id,
	'VA Class' AS vocabulary_id,
	'VA Class' AS concept_class_id,
	NULL AS standard_concept,
	rxs.atv AS concept_code,
	CASE 
		WHEN v.latest_update = TO_DATE('20211101', 'yyyymmdd')
			THEN TO_DATE('19700101', 'yyyymmdd')
		ELSE v.latest_update
		END AS valid_start_date, --for the first time we put concepts as 1970
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.rxnconso rx
JOIN sources.rxnsat rxs ON rxs.rxaui = rx.rxaui
	AND rxs.rxcui = rx.rxcui
	AND rxs.sab = 'VANDF'
	AND rxs.atn = 'VAC'
JOIN vocabulary v ON v.vocabulary_id = 'VA Class'
WHERE rx.sab = 'VANDF'
	AND rx.tty = 'PT'
	AND NOT (
		rxs.atv = 'AM114'
		AND rx.str LIKE '(%'
		); --fix for names of AM114

--4. Fill relationships
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
SELECT rx_vandf.code AS concept_code_1,
	cs.concept_code AS concept_code_2,
	'VANDF' AS vocabulary_id_1,
	'VA Class' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	CASE 
		WHEN v.latest_update = TO_DATE('20211101', 'yyyymmdd')
			THEN TO_DATE('19700101', 'yyyymmdd')
		ELSE v.latest_update
		END AS valid_start_date, --for the first time we put relationships as 1970
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage cs
JOIN sources.rxnrel rxn ON rxn.rxaui1 = cs.concept_id::TEXT
	AND rxn.sab = 'VANDF'
	AND rxn.rela = 'isa'
JOIN sources.rxnconso rx_vandf ON rx_vandf.rxaui = rxn.rxaui2
	AND rx_vandf.sab = 'VANDF'
	AND rx_vandf.tty = 'CD'
JOIN vocabulary v ON v.vocabulary_id = 'VA Class'
WHERE EXISTS ( --make sure we are working with current VANDF concepts, e.g. if RXNORM was updated in the sources after we loaded VANDF
		SELECT 1
		FROM concept c_int
		WHERE c_int.concept_code = rx_vandf.code
			AND c_int.vocabulary_id = 'VANDF'
		);

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
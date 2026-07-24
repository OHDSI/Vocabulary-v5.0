/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
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
* Authors: Masha Khitrun
* Date: 2026
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ORPHAcode',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.mrsmap LIMIT 1),
	pVocabularyVersion		=> (SELECT EXTRACT (YEAR FROM vocabulary_date)||' Release' FROM sources.mrsmap LIMIT 1),
	pVocabularyDevSchema	=> 'dev_orphanet'
);
END $_$;

TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE concept_relationship_stage;

-- 2. Populate concept_stage table
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
SELECT DISTINCT vocabulary_pack.CutConceptName(str) AS concept_name,
       'Condition' AS domain_id,
       'ORPHAcode' AS vocabulary_id,
       'Disorder' AS concept_class_id,
       NULL AS standard_concept,
       m.code as concept_code,
       (SELECT latest_update
         FROM vocabulary
         WHERE vocabulary_id = 'ORPHAcode'
       ) AS valid_start_date,
        TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	    NULL AS invalid_reason
FROM sources.mrconso m
JOIN sources.mrsty s USING (cui)
WHERE sab = 'ORPHANET'
AND suppress = 'N'
AND tty = 'PT'
AND EXISTS (
    SELECT 1
    FROM cc_submission ccs
    WHERE ccs.concept_code_1 = m.code
)
;


-- 3. Populate concept_synonym table:
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT m.code,
	            'ORPHAcode',
	            vocabulary_pack.CutConceptSynonymName(m.str),
	            4180186
FROM sources.mrconso m
WHERE sab = 'ORPHANET'
AND tty = 'SY'
AND EXISTS (
    SELECT 1
    FROM concept_stage cs
    WHERE cs.concept_code = m.code
    AND cs.vocabulary_id = 'ORPHAcode'
);

INSERT INTO concept_synonym_manual (
    synonym_name,
    synonym_concept_code,
    synonym_vocabulary_id,
    language_concept_id
)
SELECT DISTINCT synonym_name,
       concept_code_1,
       vocabulary_id_1,
       language_concept_id
FROM dev_orphanet.cc_submission sub
WHERE NOT EXISTS(
        SELECT 1
        FROM concept_synonym_stage css
        WHERE css.synonym_concept_code = sub.synonym_name
        AND css.synonym_name = sub.synonym_name
        AND css.synonym_vocabulary_id = sub.vocabulary_id_1
        AND css.language_concept_id = sub.language_concept_id
)
    AND synonym_name IS NOT NULL;

/*-- 4. Create hierarchical relationships: -- POSTPONED
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
SELECT DISTINCT c1.code AS concept_code_1,
	c2.code AS concept_code_2,
	'Is a' AS relationship_id,
	'ORPHAcode' AS vocabulary_id_1,
	'ORPHAcode' AS vocabulary_id_2,
	(SELECT latest_update
	 FROM vocabulary
	 WHERE vocabulary_id = 'ORPHAcode') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrrel r
    JOIN sources.mrconso c1 on c1.cui = r.cui2
    JOIN sources.mrconso c2 on c2.cui = r.cui1
    WHERE r.sab = 'ORPHANET'
        AND rela = 'isa'
        AND c1.sab = 'ORPHANET'
        AND c2.sab = 'ORPHANET'
        AND c1.tty = 'PT'
        AND c2.tty = 'PT'
        AND c1.code != c2.code
        AND c2.ts = 'P'
;*/

--5. Add everything from the Manual tables
--Working with manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--Working with manual synonyms
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--Working with manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the concept_stage, concept_relationship_stage and concept_synonym_stage tables are ready to be fed into the generic_update script
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
* Authors: Timur Vakhitov
* Date: 2023
**************************************************************************/

--1. Update latest_update field to new date
DO $LATESTUPDATE$
DECLARE
	pVocabs CONSTANT VARCHAR[]:=ARRAY['SNOMED']; --ARRAY['NDC','SPL']
	pSchemaName CONSTANT TEXT:='dev_xyz';

	pVocab concept.vocabulary_id%TYPE;
	pLatestUpdate vocabulary_conversion.latest_update%TYPE;
	pVocabVersion vocabulary.vocabulary_version%TYPE;
	pGeneratedStmt TEXT;
	i INT;
BEGIN
	pGeneratedStmt:='DO $_$ BEGIN';

	FOR i IN 1..ARRAY_UPPER(pVocabs,1) LOOP
		SELECT COALESCE(vc.latest_update, CURRENT_DATE),
			COALESCE(v.vocabulary_version, v.vocabulary_id || ' ' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD'))
		INTO pLatestUpdate,
			pVocabVersion
		FROM vocabulary v
		JOIN vocabulary_conversion vc ON vc.vocabulary_id_v5 = v.vocabulary_id
		WHERE v.vocabulary_id = pVocabs[i];

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Vocabulary with id=% not found', pVocabs[i];
		END IF;

		pGeneratedStmt:=pGeneratedStmt||FORMAT($$
			PERFORM VOCABULARY_PACK.SetLatestUpdate(
			pVocabularyName=>%1$L,
			pVocabularyDate=>%4$L,
			pVocabularyVersion=>%5$L,
			pVocabularyDevSchema=>%2$L,
			pAppendVocabulary=>%3$L
		);
		$$,pVocabs[i],pSchemaName,(i>1),pLatestUpdate,pVocabVersion);
	END LOOP;

	pGeneratedStmt:=pGeneratedStmt||'END $_$;';

	EXECUTE pGeneratedStmt;
END $LATESTUPDATE$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load full list of concepts
INSERT INTO concept_stage
SELECT c.*
FROM concept c
JOIN vocabulary v ON v.vocabulary_id=c.vocabulary_id
WHERE v.latest_update IS NOT NULL;--load only updatable vocabularies

--4. Load full list of relationships
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
SELECT c1.concept_code,
	c2.concept_code,
	c1.vocabulary_id,
	c2.vocabulary_id,
	cr.relationship_id,
	cr.valid_start_date,
	cr.valid_end_date,
	cr.invalid_reason
FROM concept_relationship cr
JOIN concept c1 ON c1.concept_id = cr.concept_id_1
JOIN vocabulary v1 ON v1.vocabulary_id = c1.vocabulary_id
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
JOIN vocabulary v2 ON v2.vocabulary_id = c2.vocabulary_id
WHERE cr.invalid_reason IS NULL
	AND (
		--load only updatable vocabularies 
		v1.latest_update IS NOT NULL
		OR v2.latest_update IS NOT NULL
		)
	/*
	put only 'direct' versions of relationships
	this will protect us from cases where some function, for example, DeleteAmbiguousMapsTo, will update the old 'Maps to' relationship, and its reverse version will remain unaffected
	*/
	AND cr.relationship_id = devv5.GetPrimaryRelationshipID(cr.relationship_id);

--5. Load full list of synonyms
INSERT INTO concept_synonym_stage
SELECT cs.concept_id,
	cs.concept_synonym_name,
	c.concept_code,
	c.vocabulary_id,
	cs.language_concept_id
FROM concept_synonym cs
JOIN concept c ON c.concept_id = cs.concept_id
JOIN vocabulary v ON v.vocabulary_id=c.vocabulary_id
WHERE v.latest_update IS NOT NULL;

--6. Load full list of pc
INSERT INTO pack_content_stage
SELECT c1.concept_code AS pack_concept_code,
	c1.vocabulary_id AS pack_vocabulary_id,
	c2.concept_code AS drug_concept_code,
	c2.vocabulary_id AS drug_vocabulary_id,
	pc.amount,
	pc.box_size
FROM pack_content pc
JOIN concept c1 ON c1.concept_id = pc.pack_concept_id
JOIN concept c2 ON c2.concept_id = pc.drug_concept_id
JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
WHERE v.latest_update IS NOT NULL;--load only updatable vocabularies

--7. Load full list of ds
INSERT INTO drug_strength_stage
SELECT c1.concept_code AS drug_concept_code,
	c1.vocabulary_id AS vocabulary_id_1,
	c2.concept_code AS ingredient_concept_code,
	c2.vocabulary_id AS vocabulary_id_2,
	ds.amount_value,
	ds.amount_unit_concept_id,
	ds.numerator_value,
	ds.numerator_unit_concept_id,
	ds.denominator_value,
	ds.denominator_unit_concept_id,
	ds.valid_start_date,
	ds.valid_end_date,
	ds.invalid_reason
FROM drug_strength ds
JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
WHERE v.latest_update IS NOT NULL;--load only updatable vocabularies

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;
ANALYZE drug_strength_stage;

--8. Manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--9. Manual synonyms
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--10. Manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--11. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--12. Add mapping (Maps to) from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--13. Add mapping (Maps to value) from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--14. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--15. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
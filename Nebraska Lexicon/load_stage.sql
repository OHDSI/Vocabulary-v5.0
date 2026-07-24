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
* Authors: Medical team
* Date: 2026
**************************************************************************/

--1. Update latest_update field to new date
DO $LATESTUPDATE$
DECLARE
	pVocabs CONSTANT VARCHAR[]:=ARRAY['Nebraska Lexicon'];
	pSchemaName CONSTANT TEXT:='dev_lexicon';

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
WHERE v.latest_update IS NOT NULL;

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
WHERE /*cr.invalid_reason IS NULL
	AND */COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL
	AND (
			CASE
				WHEN COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL
					THEN devv5.GetPrimaryRelationshipID(cr.relationship_id)
				END
			) = cr.relationship_id;

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

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

--8. Add mappings between Nebraska and SNOMED:
    INSERT INTO concept_relationship_stage
    (concept_code_1,
     concept_code_2,
     vocabulary_id_1,
     vocabulary_id_2,
     relationship_id,
     valid_start_date,
     valid_end_date,
     invalid_reason
    )
    SELECT distinct cs.concept_code,
           c.concept_code,
           cs.vocabulary_id,
           c.vocabulary_id,
           'Maps to',
           current_date as valid_start_date,
        '2099-12-31'::date as valid_end_date,
           null
    FROM concept_stage cs, concept c
    WHERE cs.vocabulary_id = 'Nebraska Lexicon'
    AND c.vocabulary_id = 'SNOMED'
    AND cs.concept_code = c.concept_code
    and not exists(select 1
                   from concept_relationship_stage crs
           where crs.relationship_id in ('Maps to')
           and crs.invalid_reason is null
           and (cs.concept_code, cs.vocabulary_id) = (crs.concept_code_1, crs.vocabulary_id_1))
    ON CONFLICT ON CONSTRAINT idx_pk_crs DO UPDATE SET valid_end_date = excluded.valid_end_date, invalid_reason = excluded.invalid_reason
    ;

--9. Deprecate hierarchical and attribute rels between SNOMED and Nebraska:
    UPDATE concept_relationship_stage
        SET invalid_reason = 'D',
            valid_end_date = current_date
    WHERE vocabulary_id_1 = 'Nebraska Lexicon'
    AND vocabulary_id_2 = 'SNOMED'
    AND relationship_id not in ('Maps to', 'Maps to value', 'Concept alt_to to', 'Concept replaced by', 'Concept same_as to')
    AND invalid_reason is null;


--10. Invalidate all Nebraska Lexicon concepts:
UPDATE concept_stage cs
SET invalid_reason = (CASE WHEN EXISTS(SELECT 1
                                       FROM concept_relationship_stage crs
                                       WHERE (cs.concept_code, cs.vocabulary_id) = (crs.concept_code_1, crs.vocabulary_id_1)
                                         AND crs.relationship_id in ('Concept alt_to to', 'Concept replaced by', 'Concept same_as to')
                                         AND crs.invalid_reason is null)
    THEN 'U' ELSE 'D' END),
    valid_end_date = current_date
WHERE cs.vocabulary_id = 'Nebraska Lexicon'
and cs.invalid_reason is null
;

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

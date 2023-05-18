-- 1. Set latest update
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT',
    pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'CO-CONNECT '||TO_CHAR(CURRENT_DATE,'YYYY-MM-DD'),
	pVocabularyDevSchema	=> 'dev_co_connect'
	);
	END $_$;

DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT MIABIS',
    pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'CO-CONNECT MIABIS '||TO_CHAR(CURRENT_DATE,'YYYY-MM-DD'),
	pVocabularyDevSchema	=> 'dev_co_connect',
    pAppendVocabulary		=> TRUE
	);
	END $_$;


DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT TWINS',
    pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'CO-CONNECT TWINS '||TO_CHAR(CURRENT_DATE,'YYYY-MM-DD'),
	pVocabularyDevSchema	=> 'dev_co_connect',
	pAppendVocabulary		=> TRUE
	);
	END $_$;


-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;


--3. Manual concepts
--Append manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--4. Manual mappings
--Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--6. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--7. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
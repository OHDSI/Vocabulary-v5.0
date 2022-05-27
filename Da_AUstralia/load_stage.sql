-- 1. Set latest update
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=>'LPD_Australia',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> CONCAT('LPD_Australia ', CURRENT_DATE ),
	pVocabularyDevSchema	=> 'dev_aus'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--4. Manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;
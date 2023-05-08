SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);

-- 0. Add New Vocabularies
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CO-CONNECT',
	pVocabulary_name		=> 'IQVIA CO-CONNECT',
	pVocabulary_reference	=> 'To be populated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CO-CONNECT MIABIS',
	pVocabulary_name		=> 'IQVIA CO-CONNECT MIABIS',
	pVocabulary_reference	=> 'To be populated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CO-CONNECT TWINS',
	pVocabulary_name		=> 'IQVIA CO-CONNECT TWINS',
	pVocabulary_reference	=> 'To be populated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;


-- 1. Set latest update
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT',
    pVocabularyDate			=> to_date ('2018-03-02', 'yyyy-mm-dd'),
	pVocabularyVersion		=> 'CO-CONNECT test',
	pVocabularyDevSchema	=> 'dev_co_connect'
	);
	END $_$;

DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT MIABIS',
    pVocabularyDate			=> to_date ('2018-03-02', 'yyyy-mm-dd'),
	pVocabularyVersion		=> 'CO-CONNECT test',
	pVocabularyDevSchema	=> 'dev_co_connect',
    pAppendVocabulary		=> TRUE
	);
	END $_$;


DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT TWINS',
    pVocabularyDate			=> to_date ('2018-03-02', 'yyyy-mm-dd'),
	pVocabularyVersion		=> 'CO-CONNECT test',
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

--6. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script


DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

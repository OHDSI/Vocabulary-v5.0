--Schema preparation
--SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);

--Final realisation consists of 3 separate vocabularies, coming in one pack: CO-CONNECT, CO-CONNECT MIABIS, CO-CONNECT TWINS

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


--Truncating manual tables
--TRUNCATE concept_manual, concept_relationship_manual, concept_synonym_manual;

--Preprocessing of manual tables
--Bad format in source data, dates for relationships are lost
DROP TABLE IF EXISTS concept_relationship_manual_iqvia;
CREATE TABLE concept_relationship_manual_iqvia AS
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id
FROM concept_relationship_manual;


INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       TO_DATE ('19700101', 'YYYYMMDD'),
       TO_DATE ('20991231', 'YYYYMMDD'),
       NULL
FROM concept_relationship_manual_iqvia;

UPDATE concept_manual SET standard_concept = NULL
WHERE standard_concept = '';




--Processing manual concepts
--Append manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;


--Automatic QA of stage tables
SELECT * FROM qa_tests.check_stage_tables();


--Clean up
DROP TABLE concept_relationship_manual_iqvia;


DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;


--Automatic QA  of basic tables
SELECT * FROM QA_TESTS.GET_CHECKS();

--Manual checks after generic
--(other files)
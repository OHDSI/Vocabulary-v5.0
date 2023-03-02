--Schema preparation
--SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5');

--Potential Vocabulary released through Athena

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CO-CONNECT',
	pVocabulary_name		=> 'IQVIA CO-CONNECT',
	pVocabulary_reference	=> 'To be populated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
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

--concept_stage
--Modification of the table to fit the data:
ALTER TABLE concept_stage
ALTER COLUMN concept_code TYPE varchar(255);
ALTER TABLE concept_stage
ALTER COLUMN concept_class_id TYPE varchar(255);
ALTER TABLE concept_stage
ALTER COLUMN vocabulary_id TYPE varchar(255);
ALTER TABLE concept_relationship_stage
ALTER COLUMN vocabulary_id_1 TYPE varchar(255);

--Modification of the data to fit into OMOP CDM
UPDATE concept_stage SET invalid_reason = NULL WHERE invalid_reason = '';
UPDATE concept_stage SET standard_concept = NULL WHERE standard_concept = 'N';

--concept_relationship_stage
--Modification of the table to fit the data:
ALTER TABLE concept_relationship_stage
ALTER COLUMN concept_code_1 TYPE varchar(255);
ALTER TABLE concept_relationship_stage
ALTER COLUMN vocabulary_id_1 TYPE varchar(255);


--Automatic QA of stage tables
SELECT * FROM qa_tests.check_stage_tables();


--Fixes to run a generic update to check basic tables
--Concept_stage
UPDATE concept_stage SET vocabulary_id = 'CO-CONNECT';
UPDATE concept_relationship_stage SET vocabulary_id_1 = 'CO-CONNECT';
UPDATE concept_stage SET concept_class_id = 'Precoordinated pair' WHERE concept_class_id = 'precoordinated pair';
UPDATE concept_stage SET standard_concept = NULL WHERE standard_concept IS NOT NULL;
UPDATE concept_stage SET concept_name = vocabulary_pack.cutconceptname(concept_name);

--Concept_relationship_stage
--quick deduplication
CREATE TABLE concept_relationship_stage_dedup AS (SELECT DISTINCT * FROM concept_relationship_stage);
TRUNCATE concept_relationship_stage;
INSERT INTO concept_relationship_stage (SELECT * FROM concept_relationship_Stage_dedup);
DROP TABLE concept_relationship_stage_dedup;



DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;


--Automatic QA  of basic tables
SELECT * FROM QA_TESTS.GET_CHECKS();

--Manual checks after generic
--(other files)
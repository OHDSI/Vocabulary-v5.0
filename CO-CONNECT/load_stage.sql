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

--Modification of the data to fit into OMOP CDM
UPDATE concept_stage SET invalid_reason = NULL WHERE invalid_reason = '';
UPDATE concept_stage SET standard_concept = NULL WHERE standard_concept = 'N';

--concept_relationship_stage
--Modification of the table to fit the data:
ALTER TABLE concept_relationship_stage
ALTER COLUMN concept_code_1 TYPE varchar(255);
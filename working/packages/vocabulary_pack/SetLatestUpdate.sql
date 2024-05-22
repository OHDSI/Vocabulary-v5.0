CREATE OR REPLACE FUNCTION vocabulary_pack.SetLatestUpdate (
	pVocabularyName VARCHAR,
	pVocabularyDate DATE,
	pVocabularyVersion VARCHAR,
	pVocabularyDevSchema VARCHAR,
	pAppendVocabulary BOOLEAN = FALSE
)
RETURNS VOID AS
$BODY$
	/*
	Any manipulations with stage tables must begin with a call to SetLatestUpdate.
	This function globally sets the vocabulary update date (and the name of the dev-schema where development is taking place), so that other queries participating in load_stage can see this information and process it accordingly.
	For example, it is very convenient to use the query SELECT latest_update FROM vocabulary WHERE vocabulary_id='xyz' to automatically obtain the start date of the concept. A similar approach can be used for valid_end_date.
	As for the dev_schema_name field, it is used (in automatic mode) only in functions for working with manual concepts/mappings/etc and only if the script is running in the devv5

	pAppendVocabulary is a special parameter responsible for whether the above fields from the previous function call will be cleared or not.
	This is important because each call to SetLatestUpdate by default sets the date/version/schema name only to a specific pVocabularyName, to avoid the case where there were multiple incorrect calls by mistake.
	On the other hand, there are situations when several vocabularies are updated in one load_stage, and then pAppendVocabulary needs to be set to True for all vocabularies that will be added to the "main" updated vocabulary
	(in fact, it doesn't matter at all which vocabulary is specified in the first SetLatestUpdate, the main thing is so that it is with pAppendVocabulary=False (default value), and all others with pAppendVocabulary=True)

	Examples:
	--usage SetLatestUpdate for single vocabulary
	DO $_$
	BEGIN
		PERFORM vocabulary_pack.SetLatestUpdate(
		pVocabularyName			=> 'ICD10PCS',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources.icd10pcs LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.icd10pcs LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_ICD10PCS');
	END $_$;

	--usage SetLatestUpdate for several vocabularies
	DO $_$
	BEGIN
		PERFORM vocabulary_pack.SetLatestUpdate(
		pVocabularyName			=> 'NDC',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources.product LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.product LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_NDC'
	);
		PERFORM vocabulary_pack.SetLatestUpdate(
		pVocabularyName			=> 'SPL',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources.product LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.product LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_NDC',
		pAppendVocabulary		=> TRUE
	);
	END $_$;
	*/
BEGIN
	pVocabularyName=NULLIF(pVocabularyName,'');
	pVocabularyVersion=NULLIF(pVocabularyVersion,'');
	pVocabularyDevSchema=NULLIF(pVocabularyDevSchema,'');
	
	IF pVocabularyName IS NULL THEN
		RAISE EXCEPTION 'Please specify vocabulary_id (pVocabularyName)';
	END IF;

	IF pVocabularyDate IS NULL THEN
		RAISE EXCEPTION 'Vocabulary date cannot be empty!';
	END IF;

	IF pVocabularyVersion IS NULL THEN
		RAISE EXCEPTION 'Vocabulary version cannot be empty!';
	END IF;

	IF pVocabularyDevSchema IS NULL THEN
		RAISE EXCEPTION 'Vocabulary dev-schema cannot be empty!';
	END IF;

	PERFORM FROM vocabulary WHERE vocabulary_id = pVocabularyName;

	IF NOT FOUND THEN
		RAISE EXCEPTION $c$Vocabulary with id='%' not found$c$, pVocabularyName;
	END IF;

	PERFORM FROM information_schema.schemata WHERE schema_name = LOWER(pVocabularyDevSchema);

	IF NOT FOUND THEN
		RAISE EXCEPTION $c$Dev-schema with name '%' not found$c$, pVocabularyDevSchema;
	END IF;

	IF NOT pAppendVocabulary THEN
		UPDATE vocabulary
		SET latest_update = NULL,
			dev_schema_name = NULL
		WHERE latest_update IS NOT NULL;
	END IF;

	UPDATE vocabulary
	SET latest_update = pVocabularyDate,
		vocabulary_version = pVocabularyVersion,
		dev_schema_name = pVocabularyDevSchema
	WHERE vocabulary_id = pVocabularyName;

	PERFORM FROM vocabulary
	HAVING COUNT(DISTINCT dev_schema_name) > 1;

	IF FOUND THEN
		RAISE EXCEPTION 'More than one dev_schema specified'
			USING HINT='Check all pVocabularyDevSchema in your SetLatestUpdate calls, in all cases it must be one schema';
	END IF;

	ANALYZE vocabulary;--other queries will be able to use the index if it is linked to the vocabulary_id field from this table, e.g. select * from concept c join vocabulary v using (vocabulary_id) where v.latest_update is not null;
END;
$BODY$
LANGUAGE 'plpgsql'
SET client_min_messages = error;
CREATE OR REPLACE FUNCTION vocabulary_pack.ModifyVocabularyParam (
	pVocabulary_id TEXT,
	pParamName TEXT,
	pParamValue TEXT
)
RETURNS VOID AS
$BODY$
	/*
	Modify vocabulary additional parameters

	Usage:
	1. Get all available parameters
	SELECT DISTINCT JSONB_OBJECT_KEYS(vocabulary_params)
	FROM vocabulary
	ORDER BY 1;
	
	1.1. To view current value for specified parameter/vocabulary, use current query:
	SELECT vocabulary_params->>'special_deprecation' FROM vocabulary WHERE vocabulary_id='ICD10PCS';

	2. Use this function to change the desired parameter
	In this example we will make SNOMED an 'not-full' vocabulary (the generic_update will not deprecate missing concepts)
	DO $_$
	BEGIN
		PERFORM vocabulary_pack.ModifyVocabularyParam(
		pVocabulary_id	=> 'SNOMED',
		pParamName		=> 'is_full',
		pParamValue		=> '0'
		);
	END $_$;

	The following example shows how you can make a vocabulary 'special', that is, the generic_update will change the valid_end_date for concepts, but not invalid_reason
	DO $_$
	BEGIN
		PERFORM vocabulary_pack.ModifyVocabularyParam(
		pVocabulary_id	=> 'ICD10PCS',
		pParamName		=> 'special_deprecation',
		pParamValue		=> '1'
		);
	END $_$;
	*/
BEGIN
	pVocabulary_id:=NULLIF(pVocabulary_id,'');
	pParamName:=LOWER(NULLIF(pParamName,''));
	pParamValue:=NULLIF(pParamValue,'');

	IF pParamName IS NULL THEN
		RAISE EXCEPTION 'Please specify parameter name (pParamName)';
	END IF;

	IF pParamValue IS NULL THEN
		RAISE EXCEPTION 'Please specify parameter value (pParamValue)';
	END IF;

	IF pParamValue NOT IN ('0', '1') THEN
		RAISE EXCEPTION $q$Value must be '0' (means false) or '1' (means true)$q$;
	END IF;

	PERFORM FROM vocabulary WHERE vocabulary_params ? pParamName LIMIT 1;
	IF NOT FOUND THEN
		RAISE EXCEPTION $q$Parameter with name='%' not found$q$, pParamName;
	END IF;

	PERFORM FROM vocabulary WHERE vocabulary_id = pVocabulary_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION $q$Vocabulary with id='%' not found$q$, pVocabulary_id;
	END IF;

	UPDATE vocabulary
	SET vocabulary_params = COALESCE(vocabulary_params, JSONB_BUILD_OBJECT()) || JSONB_BUILD_OBJECT(pParamName, pParamValue)
	WHERE vocabulary_id=pVocabulary_id;
END;
$BODY$
LANGUAGE 'plpgsql';
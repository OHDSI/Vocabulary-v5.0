-- 1. Change the parameter of deprecation for CMS Place of Service vocabulary to create zombie concepts:
	DO $_$
	BEGIN
		PERFORM vocabulary_pack.ModifyVocabularyParam(
		pVocabulary_id	=> 'CMS Place of Service',
		pParamName		=> 'special_deprecation',
		pParamValue		=> '1'
		);
	END $_$;
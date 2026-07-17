--Make columns latest_update and dev_schema_name constant in vocabulary table and add a new JSONB-column to store additional vocabulary parameters [AVOC-4191]
DO $$
BEGIN
	ALTER TABLE vocabulary ADD COLUMN latest_update DATE,
		ADD COLUMN dev_schema_name TEXT, 
		ADD COLUMN vocabulary_params JSONB;

	COMMENT ON COLUMN vocabulary.latest_update IS 'Internal field, new update date for using in load_stage/functions/generic_update';
	COMMENT ON COLUMN vocabulary.dev_schema_name IS 'Internal field, the name of the schema where manual changes come from if the script is run in the devv5';
	COMMENT ON COLUMN vocabulary.vocabulary_params IS $c$Service field for storing additional params like 'Deprecation indicator (full/not full)', 'special deprecation indicator (invalid_reason is null, but valid_end_date is not 20991231)' etc$c$;

	--set deprecation indicator
	UPDATE vocabulary
	SET vocabulary_params = JSONB_BUILD_OBJECT('is_full', '1')
	WHERE vocabulary_id IN (
			'SNOMED',
			'LOINC',
			'ICD9CM',
			'ICD10',
			'RxNorm',
			'NDFRT',
			'VANDF',
			'VA Class',
			'ATC',
			'MedDRA',
			'Read',
			'ICD10CM',
			'GPI',
			'OPCS4',
			'MeSH',
			'GCN_SEQNO',
			'ETC',
			'Indication',
			'DPD',
			'NFC',
			'EphMRA ATC',
			'dm+d',
			'Gemscript',
			'Cost Type',
			'BDPM',
			'AMT',
			'CVX',
			'ICDO3',
			'CDT',
			'GGR',
			'LPD_Belgium',
			'APC',
			'SUS',
			'SNOMED Veterinary',
			'OSM',
			'US Census',
			'HemOnc',
			'NAACCR',
			'KCD7',
			'CTD',
			'EDI',
			'Nebraska Lexicon',
			'ICD10CN',
			'ICD9ProcCN',
			'CAP',
			'CIM10',
			'CIViC',
			'CGI',
			'ICD10GM',
			'CCAM',
			'SOPT',
			'OMOP Invest Drug',
			'COSMIC'
			);

	--set special deprecation indicator
	UPDATE vocabulary
	SET vocabulary_params = COALESCE(vocabulary_params, JSONB_BUILD_OBJECT()) || JSONB_BUILD_OBJECT('special_deprecation', '1')
	WHERE vocabulary_id IN (
			'CPT4',
			'HCPCS',
			'ICD9Proc',
			'ICD10PCS',
			'CVX',
			'Gemscript'
			);

	--store latest_release_date 
	UPDATE vocabulary v
	SET vocabulary_params = COALESCE(vocabulary_params, JSONB_BUILD_OBJECT()) || JSONB_BUILD_OBJECT('latest_release_date', TO_CHAR(vrs.latest_release_date,'YYYYMMDD'))
	FROM vocabulary_release_stat vrs
	WHERE v.vocabulary_id = vrs.vocabulary_id;

	--delete obsolete record
	DELETE FROM devv5.config$ WHERE var_name='special_vocabularies';
	--drop no longer needed table
	DROP TABLE vocabulary_release_stat;
END $$;
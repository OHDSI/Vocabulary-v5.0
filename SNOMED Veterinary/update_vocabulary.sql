DO $_$
	BEGIN
		PERFORM vocabulary_pack.SetLatestUpdate(
		pVocabularyName			=> 'SNOMED Veterinary',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources_vet_sct2_concept_full 
		                              WHERE moduleid = '332351000009108' LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources_vet_sct2_concept_full 
		                              WHERE moduleid = '332351000009108' LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_VETERINARY'
	);
	--	PERFORM vocabulary_pack.SetLatestUpdate(
	--	pVocabularyName			=> 'SNOMED',
	--	pVocabularyDate			=> (SELECT vocabulary_date FROM sources_vet_sct2_concept_full 
		--                              WHERE moduleid = '900000000000207008' LIMIT 1),
	--	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources_vet_sct2_concept_full 
		--                              WHERE moduleid = '900000000000207008' LIMIT 1),
	--	pVocabularyDevSchema	=> 'DEV_VETERINARY',
	--	pAppendVocabulary		=> TRUE
	-- );
	END $_$;
--add new UCUM concepts
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'per nanoliter',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'/nL'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'per picoliter',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'/pL'
	);
END $_$;
--add new UCUM concepts
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'cigar dosing unit',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'{Cigar}'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'cigarette dosing unit',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'{Cigarette}'
	);
END $_$;


DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'per kiloohm',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'/kOhm'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'hectopascal',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'hPa'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'millimole per 48 hours',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'mmol/(48.h)'
	);
END $_$;

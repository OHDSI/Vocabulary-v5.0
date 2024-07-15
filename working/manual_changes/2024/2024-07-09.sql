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
		pConcept_name		=>'centimeter watercolumn-second',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'cm[H2O].s'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'liter per second per centimeter watercolumn',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'L/s/cm[H2O]'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'centimeter watercolumn per liter per second',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'cm[H2O]/L/s'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'centigrams per liter',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'cg/l'
	);
END $_$;
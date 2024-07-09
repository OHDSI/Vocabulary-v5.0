--add new UCUM concepts
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'Cigar Dosing Unit',
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
		pConcept_name		=>'Cigarette Dosing Unit',
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
		pConcept_name		=>'milligram per specimen',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'mg/{spec}'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'Kaolin clotting time',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'KCT'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'picomole per hour per punch',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'pmol/hr/punch'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'unit per milliliter of white blood cells',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'[U]/mL{WBC}'
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
		pConcept_name		=>'centigrams Per Liter',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'cg/l'
	);
END $_$;
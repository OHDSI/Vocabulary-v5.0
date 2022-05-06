--https://github.com/OHDSI/Vocabulary-v5.0/issues/618
--deprecate old UCUM concepts and relationships (to self)
UPDATE concept
SET concept_name = 'Invalid UCUM Concept, do not use',
	concept_code = concept_id,
	valid_end_date = CURRENT_DATE,
	standard_concept = NULL,
	invalid_reason = 'D'
WHERE concept_id IN (
		9258,
		9259
		);

UPDATE concept_relationship
SET invalid_reason = 'D',
	valid_end_date = CURRENT_DATE
WHERE concept_id_1 IN (
		9258,
		9259
		);

--add new UCUM concepts
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'acre (British)',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'[acr_br]'
	);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'acre (US)',
		pDomain_id			=>'Unit',
		pVocabulary_id		=>'UCUM',
		pConcept_class_id	=>'Unit',
		pStandard_concept	=>'S',
		pConcept_code		=>'[acr_us]'
	);
END $_$;

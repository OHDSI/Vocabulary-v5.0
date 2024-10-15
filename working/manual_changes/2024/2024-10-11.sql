--Add new vocabulary
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewVocabulary(
	pVocabulary_id          => 'EORTC QLQ',
    pVocabulary_name        => 'EORTC Quality of Life questionnaires',
    pVocabulary_reference   => 'https://itemlibrary.eortc.org/',
    pVocabulary_version     => '2023_11',
    pOMOP_req				=> 'Y', --NULL or 'Y'
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;


--Add new concept class
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Core',
	pConcept_class_name	=>'Core questionnaire'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Standalone',
	pConcept_class_name	=>'Standalone questionnaire'
);
END $_$;


DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAT',
	pConcept_class_name	=>'Сomputerised adaptive testing questionnaire'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAT Short',
	pConcept_class_name	=>'Short version of Сomputerised adaptive testing questionnaire'
);
END $_$;



DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Previous',
	pConcept_class_name	=>'Historical version of questionnaire'
);
END $_$;


DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Direction',
	pConcept_class_name	=>'Direction of question'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Issue',
	pConcept_class_name	=>'Issue associated with question'
);
END $_$;


DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Response Scale',
	pConcept_class_name	=>'Response scale in questionnaire'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Time Scale',
	pConcept_class_name	=>'Time scale in questionnaire'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Symptom Scale',
	pConcept_class_name	=>'Symptom scale in questionnaire'
);
END $_$;


--Add new Drug specific relationships for EORTC
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has Scale',
	pRelationship_id			=>'Has Scale',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Scale of',
	pReverse_relationship_id		=>'Scale of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

--Add new Drug specific relationships for EORTC
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has Issue',
	pRelationship_id			=>'Has Issue',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Issue of',
	pReverse_relationship_id		=>'Issue of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;


--Add new Drug specific relationships for EORTC
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has Direction',
	pRelationship_id			=>'Has Direction',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Direction of',
	pReverse_relationship_id		=>'Direction of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;



--add new vocabulary='CAP'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CAP',
	pVocabulary_name		=> 'College of American Pathologists electronic cancer checklists',
	pVocabulary_reference	=> 'https://fileshare.cap.org/human.aspx?Arg12=filelist&Arg06=136884410',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> 'Y',
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--new classes for CAP
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAP Value',
	pConcept_class_name	=>'CAP Value'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAP Variable',
	pConcept_class_name	=>'CAP Variable'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAP Header',
	pConcept_class_name	=>'CAP Header'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAP Protocol',
	pConcept_class_name	=>'CAP Protocol'
);
END $_$;

--new relationships for CAP
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'CAP value of',
	pRelationship_id			=>'CAP value of',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Has CAP value',
	pRelationship_name_rev		=>'Has CAP value',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has CAP parent item',
	pRelationship_id			=>'Has CAP parent item',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'CAP parent item of',
	pRelationship_name_rev		=>'CAP parent item of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has CAP protocol',
	pRelationship_id			=>'Has CAP protocol',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'CAP protocol of',
	pRelationship_name_rev		=>'CAP protocol of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;
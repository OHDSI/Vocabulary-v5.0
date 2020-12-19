-- Adding required concept_classes
DO
$_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Biobank Category',
    pConcept_class_name     =>'Biobank Category'
);

  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Variable',
    pConcept_class_name     =>'Variable'
);

  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Value',
    pConcept_class_name     =>'Value'
);

  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Question-Answer pair',
    pConcept_class_name     =>'Question-Answer pair'
);

  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Variable-Value pair',
    pConcept_class_name     =>'Variable-Value pair'
);

  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has Question-Answer pair',
	pRelationship_id			=>'Has Q-A pair',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Q-A pair of',
	pRelationship_name_rev		=>'Question-Answer pair of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);

  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has Variable-Value pair',
	pRelationship_id			=>'Has V-V pair',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'V-V pair of',
	pRelationship_name_rev		=>'Variable-Value pair of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);

-- Adding required vocabulary
  PERFORM vocabulary_pack.AddNewVocabulary(
      pvocabulary_id => 'UK Biobank',
      pvocabulary_name =>  'UK Biobank',
      pvocabulary_reference => 'https://www.ukbiobank.ac.uk/',
      pvocabulary_version => TO_DATE('2020-10-15', 'yyyy-mm-dd'),
      pOMOP_req => NULL ,
      pClick_default => NULL,
      pAvailable => NULL,
      pURL => NULL,
      pClick_disabled => NULL
      );
END $_$;
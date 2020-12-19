-- Adding required concept_classes
DO
$_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Category',
    pConcept_class_name     =>'Category'
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
    pConcept_class_id       =>'Precoordinated pair',
    pConcept_class_name     =>'Precoordinated (Question-Answer/Variable-Value) pair '
);

  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has precoordinated (Question-Answer/Variable-Value) pair',
	pRelationship_id			=>'Has precoord pair',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Precoord pair of',
	pRelationship_name_rev		=>'Precoordinated (Question-Answer/Variable-Value) pair of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);

  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has Value',
	pRelationship_id			=>'Has Value',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Value of',
	pRelationship_name_rev		=>'Value of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);

  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has Category',
	pRelationship_id			=>'Has Category',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Category of',
	pRelationship_name_rev		=>'Category of',
	pIs_hierarchical_rev		=>1,
	pDefines_ancestry_rev		=>1
);

-- Adding required vocabulary
  PERFORM vocabulary_pack.AddNewVocabulary(
      pvocabulary_id => 'UK Biobank',
      pvocabulary_name =>  'UK Biobank',
      pvocabulary_reference => 'https://biobank.ctsu.ox.ac.uk/showcase/schema.cgi; https://biobank.ctsu.ox.ac.uk/crystal/refer.cgi?id=141140',
      pvocabulary_version => 'version 2020-10-15',
      pOMOP_req => NULL ,
      pClick_default => NULL,
      pAvailable => NULL,
      pURL => NULL,
      pClick_disabled => NULL
      );
END $_$;
--0 Adding required concept_class and vocabulary
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Biobank Category',
    pConcept_class_name     =>'Biobank Category'
);
  PERFORM vocabulary_pack.AddNewVocabulary(
      pvocabulary_id => 'uk_biobank',
      pvocabulary_name =>  'UK Biobank',
      pvocabulary_reference => 'https://www.ukbiobank.ac.uk/',
      pvocabulary_version => 'Version 0.0.1',
      pOMOP_req => NULL ,
      pClick_default => NULL,
      pAvailable => NULL,
      pURL => NULL,
      pClick_disabled => NULL
      );
END $_$;

--1. Update a 'latest_update' field to a new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'uk_biobank',
	pVocabularyDate			=> TO_DATE ('2007-03-21' ,'yyyy-mm-dd'),   --From UK Biobank: Protocol for a large-scale prospective epidemiological resource (main phase) https://www.ukbiobank.ac.uk/wp-content/uploads/2011/11/UK-Biobank-Protocol.pdf?phpMyAdmin=trmKQlYdjjnQIgJ%2CfAzikMhEnx6
	pVocabularyVersion		=> 'Version 0.0.1',
	pVocabularyDevSchema	=> 'dev_ukbiobank'
);
END $_$;
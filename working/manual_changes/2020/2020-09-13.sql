--update vocabulary name [AVOF-2798]
UPDATE vocabulary
SET vocabulary_name = 'Data Standards & Data Dictionary Volume II (NAACCR)'
WHERE vocabulary_id = 'NAACCR';
UPDATE concept
SET concept_name = 'Data Standards & Data Dictionary Volume II (NAACCR)'
WHERE concept_id = 32642;

UPDATE vocabulary
SET vocabulary_name = 'OMOP Extension (OHDSI)'
WHERE vocabulary_id = 'OMOP Extension';
UPDATE concept
SET concept_name = 'OMOP Extension (OHDSI)'
WHERE concept_id = 32758;

UPDATE vocabulary
SET vocabulary_name = 'RxNorm Extension (OHDSI)'
WHERE vocabulary_id = 'RxNorm Extension';
UPDATE concept
SET concept_name = 'RxNorm Extension (OHDSI)'
WHERE concept_id = 252;

UPDATE vocabulary
SET vocabulary_name = 'CAP electronic Cancer Checklists (College of American Pathologists)'
WHERE vocabulary_id = 'CAP';
UPDATE concept
SET concept_name = 'CAP electronic Cancer Checklists (College of American Pathologists)'
WHERE concept_id = 32771;

--new vocabularies, classes and relationships [AVOF-2799]
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CIViC',
	pVocabulary_name		=> 'Clinical Interpretation of Variants in Cancer (civicdb.org)',
	pVocabulary_reference	=> 'https://github.com/griffithlab/civic-server/blob/master/public/downloads/RankedCivicGeneCandidates.tsv',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CGI',
	pVocabulary_name		=> 'Cancer Genome Interpreter (Pompeu Fabra University)',
	pVocabulary_reference	=> 'https://www.cancergenomeinterpreter.org/data/cgi_biomarkers_latest.zip',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'ClinVar',
	pVocabulary_name		=> 'ClinVar (NCBI)',
	pVocabulary_reference	=> 'https://ftp.ncbi.nlm.nih.gov/pub/clinvar/',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'JAX',
	pVocabulary_name		=> 'The Clinical Knowledgebase (The Jackson Laboratory)',
	pVocabulary_reference	=> 'https://ckbhome.jax.org/',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'NCIt',
	pVocabulary_name		=> 'NCI Thesaurus (National Cancer Institute)',
	pVocabulary_reference	=> 'http://evs.nci.nih.gov/ftp1/NCI_Thesaurus',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'HGNC',
	pVocabulary_name		=> 'Human Gene Nomenclature (European Bioinformatics Institute)',
	pVocabulary_reference	=> 'https://biomart.genenames.org/martform/#!/default/HGNC?datasets=hgnc_gene_mart',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--create new relationship_ids for genomics
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Genomic DNA transcribes to mRNA',
	pRelationship_id			=>'Transcribes to',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Is transcribed from',
	pRelationship_name_rev		=>'mRNA is transcribed from genomic DNA',
	pIs_hierarchical_rev		=>1,
	pDefines_ancestry_rev		=>1
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'mRNA Translates to protein',
	pRelationship_id			=>'Translates to',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Is translated from',
	pRelationship_name_rev		=>'Protein is translated from mRNA',
	pIs_hierarchical_rev		=>1,
	pDefines_ancestry_rev		=>1
);
END $_$;

--create new classes for genomics
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Transcript Variant',
	pConcept_class_name	=>'Transcript Variant'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Genomic Variant',
	pConcept_class_name	=>'Genomic Variant'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Gene',
	pConcept_class_name	=>'Gene'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Variant',
	pConcept_class_name	=>'Variant'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Protein Variant',
	pConcept_class_name	=>'Protein Variant'
);
END $_$;

--small bugfix
update relationship set is_hierarchical=0 where relationship_id='Is a';
--Update of content to complement OMOP Genomic February 2024 release

--1. Add new concept classes
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Structural Variant',
    pConcept_class_name     =>'Variant at the DNA level not attributable to a single gene, including a karyotype'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Structural Variant',
    pConcept_class_name     =>'Variant at the DNA level not attributable to a single gene, including a karyotype'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Gene Protein Variant',
    pConcept_class_name     =>'Variant at the protein level for a gene'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Gene Variant',
    pConcept_class_name     =>'Variant of unspecified modality at the gene level'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Gene DNA Variant',
    pConcept_class_name     =>'Variant at the DNA level attributable to a gene'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Gene RNA Variant',
    pConcept_class_name     =>'Variant at the transcript (RNA) level for a gene'
);
END $_$;


--2. Modify vocabulary
UPDATE vocabulary
SET vocabulary_name = 'OMOP Genomic vocabulary of known variants involved in disease'
WHERE vocabulary_id = 'OMOP Genomic';

UPDATE concept
SET concept_name = 'OMOP Genomic vocabulary of known variants involved in disease'
WHERE concept_id = 33002;

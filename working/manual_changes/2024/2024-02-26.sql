--Update of content to compliment OMOP Genomic February 2024 release

--1. Add new concept classes
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Structural DNA Variant',
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


--2. Modify concept classes for existing concepts (to be used in ULS run)
--Change names of existing concept classes in OMOP Genomic
--Gene RNA Variant
UPDATE concept_stage
SET concept_class_id = 'Gene RNA Variant' 
WHERE concept_class_id = 'RNA Variant'; -- used to be 'RNA Variant'

--Gene DNA Variant
UPDATE concept_stage 
SET concept_class_id = 'Gene DNA Variant' 
WHERE concept_class_id = 'DNA Variant'; -- used to be 'DNA Variant'

--Gene Variant
UPDATE concept_stage 
SET concept_class_id = 'Gene Variant' 
WHERE concept_class_id = 'Genetic Variation'; -- used to be 'Genetic Variation'

--Gene Protein Variant
UPDATE concept_stage 
SET concept_class_id = 'Gene Protein Variant' 
WHERE concept_class_id = 'Protein Variant'; -- used to be 'Protein Variant'


--3. Modify vocabulary
UPDATE vocabulary 
SET vocabulary_name = 'OMOP Genomic vocabulary of known variants involved in disease'
WHERE vocabulary_id='OMOP Genomic';


--4. Modify basic tables (remove the old HGVS concepts)
--There are no relationships to these other than maps to themselves
DELETE FROM concept_synonym WHERE concept_id IN (SELECT concept_id FROM concept WHERE vocabulary_id = 'OMOP Genomic' AND concept_code LIKE 'N%');
DELETE FROM concept_relationship WHERE concept_id_1 IN (SELECT concept_id FROM concept WHERE vocabulary_id = 'OMOP Genomic' AND concept_code LIKE 'N%');
DELETE FROM concept_relationship WHERE concept_id_2 IN (SELECT concept_id FROM concept WHERE vocabulary_id = 'OMOP Genomic' AND concept_code LIKE 'N%');
DELETE FROM concept WHERE concept_id IN (SELECT concept_id FROM concept WHERE vocabulary_id = 'OMOP Genomic' AND concept_code LIKE 'N%');


--TODO: 

-- After load_stage, but before dropping stage tables
-- Remove synonyms for refreshed small concepts, new synonyms are in synonym_stage
DELETE FROM concept_synonym WHERE synonym_concept_id IN 
    (SELECT concept_id FROM concept JOIN concept_stage USING(vocabulary_id, concept_code) 
            WHERE invalid_reason IS NULL); -- remove the clause if the deprecated concepts also should loose their synonyms
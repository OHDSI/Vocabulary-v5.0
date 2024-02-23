--Update of content to compliment OMOP Genomic February 2024 release

--1. Modify concept classes
--Change names of existing concept classes in OMOP Genomic
--Gene RNA Variant
UPDATE concept 
SET concept_name = 'Gene RNA Variant' 
WHERE concept_id = 32923; -- used to be 'RNA Variant'

UPDATE concept_class
SET concept_class_id = 'Gene RNA Variant',
  concept_class_name = 'Variant at the transcript (RNA) level for a gene'
WHERE concept_class_concept_id = 32923;

--Gene DNA Variant
UPDATE concept 
SET concept_name = 'Gene DNA Variant' 
WHERE concept_id = 32924; -- used to be 'DNA Variant'

UPDATE concept_class 
SET concept_class_id = 'Gene DNA Variant',
  concept_class_name = 'Variant at the DNA level attributable to a gene'
WHERE concept_class_concept_id = 32924;

--Gene Variant
UPDATE concept 
SET concept_name = 'Gene Variant' 
WHERE concept_id = 32925; -- used to be 'Genetic Variation'

UPDATE concept_class
SET concept_class_id = 'Gene Variant',
  concept_class_name = 'Variant of unspecified modality at the gene level'
WHERE concept_class_concept_id = 32925;

--Gene Protein Variant
UPDATE concept 
SET concept_name = 'Gene Protein Variant'
WHERE concept_id = 32927; -- used to be 'Protein Variant'

UPDATE concept_class 
SET concept_class_id = 'Gene Protein Variant',
  concept_class_name = 'Variant at the protein level for a gene'
WHERE concept_class_concept_id = 32927;


--2. Add new concept class
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Structural DNA Variant',
    pConcept_class_name     =>'Variant at the DNA level not attributable to a single gene, including a karyotype'
);
END $_$;


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
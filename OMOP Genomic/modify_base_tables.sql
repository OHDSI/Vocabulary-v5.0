-- Before load_stage
--------------------------
-- 1. Modify concept_class
--------------------------
-- Change names of existing concept classes in OMOP Genomic
update concept set concept_name='Gene DNA Variant' where concept_id=32924; -- used to be 'DNA Variant'
update concept_class set
  concept_class_id='Gene DNA Variant',
  concept_class_name='Variant at the DNA level attributable to a gene'
where concept_class_concept_id=32924;
;
update concept set concept_name='Gene RNA Variant' where concept_id=32923; -- used to be 'RNA Variant'
update concept_class set
  concept_class_id='Gene RNA Variant',
  concept_class_name='Variant at the transcript (RNA) level for a gene'
where concept_class_concept_id=32923;
;
update concept set concept_name='Gene Protein Variant' where concept_id=32927; -- used to be 'Protein Variant'
update concept_class set
  concept_class_id='Gene Protein Variant',
  concept_class_name='Variant at the protein level for a gene'
where concept_class_concept_id=32927;
;
update concept set concept_name='Gene Variant' where concept_id=32925; -- used to be 'Genetic Variation'
update concept_class set
  concept_class_id='Gene Variant',
  concept_class_name='Variant of unspecified modality at the gene level'
where concept_class_concept_id=32925;
;

-- Add Structural DNA Variant
-- !!!!!! Needs concept_id filling mechanism
insert into concept (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values ('Structural DNA Variant', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', to_date('19700101', 'yyyymmdd'), to_date('20991231', 'yyyymmdd'), null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Structural DNA Variant', 'Variant at the DNA level not attributable to a single gene, including a karyotype', (select concept_id from concept where concept_name='Structural DNA Variant'));


-----------------------
-- 2. Modify vocabulary
-----------------------
-- Do this any time
-- The setlatestupdate package doesn't change the vocabulary_name. What it calls pvocabularyname is actually the vocabulary_id
update vocabulary set vocabulary_name='OMOP Genomic vocabulary of known variants involved in disease' where vocabulary_id='OMOP Genomic';

-----------------------------------
-- 2. Remove ugly concepts for good
-----------------------------------

-- !!!!!!!!!!!!!!!!
-- Kill old HGVS concept from OMOP Genomic
-- There are no relationships to these other than maps to themselves
delete from concept_synonym where concept_id in (select concept_id from concept where vocabulary_id='OMOP Genomic' and concept_code like 'N%');
delete from concept_relationship where concept_id_1 in (select concept_id from concept where vocabulary_id='OMOP Genomic' and concept_code like 'N%');
delete from concept_relationship where concept_id_2 in (select concept_id from concept where vocabulary_id='OMOP Genomic' and concept_code like 'N%');
delete from concept where concept_id in (select concept_id from concept where vocabulary_id='OMOP Genomic' and concept_code like 'N%');
;

---------------------
-- 1. Modify synonyms
---------------------
-- After load_stage, but before dropping stage tables
-- Remove synonyms for refreshed small concepts, new synonyms are in synonym_stage
delete from concept_synonym where synonym_concept_id in (select concept_id from concept join concept_stage using(vocabulary_id, concept_code) 
where invalid_reason is null); -- remove the clause if the deprecated concepts also should loose their synonyms


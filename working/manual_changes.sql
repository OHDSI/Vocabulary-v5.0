/*
-- start new sequence
-- drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id>=200 and concept_id<1000; -- Last valid value in the 500-1000 slot
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

-- Fix trailing zero problem in Race
update concept set concept_code='2.10.' where concept_id=38003583;
update concept set concept_code='2.20.' where concept_id=38003593;
update concept set concept_code='3.10.' where concept_id=38003607;

-- Remove unused domains
-- Domain
delete from concept_relationship where concept_id_1=1;
delete from concept_synonym where concept_id=1;
delete from domain where domain_id='Measurement';
delete from concept where concept_id=1;

-- Generic
delete from concept_relationship where concept_id_1=40;
delete from concept_synonym where concept_id=40;
delete from domain where domain_id='Generic';
delete from concept where concept_id=40;

-- Fixing trailing dots for the race codes
update concept set concept_code=regexp_replace(concept_code, '(.*)\.$', '\1') where vocabulary_id='Race' and regexp_like(concept_code, '.*\.$');

-- Fixing bad concept_name for associiated with
update concept set concept_name='Associated with finding (SNOMED)' where concept_id=44818792;
update concept set concept_name='Finding associated with (SNOMED)' where concept_id=44818890;
update relationship set relationship_name='Associated with finding (SNOMED)' where relationship_concept_id=44818792;
update relationship set relationship_name='Finding associated with (SNOMED)' where relationship_concept_id=44818890;

-- fix wrong order start_date and end_date
update concept set valid_start_date=valid_end_date-1 where valid_end_date<valid_start_date;

-- Add DPD
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Drug Product Database (Health Canada)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('DPD', 'Drug Product Database (Health Canada)', 'http://open.canada.ca/data/en/dataset/bf55e42a-63cb-4556-bfd8-44f26e5a36fe', '2016-03-04', (select concept_id from concept where concept_name='Drug Product Database (Health Canada)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (74, 'DPD', null, null, null, null);

-- Fix ABMS spelling
update concept set concept_name='Hospice and Palliative Medicine' where concept_id=45756777;

-- Add dm+d
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Dictionary of Medicines and Devices (NHS)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('dm+d', 'Dictionary of Medicines and Devices (NHS)', 'https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/1/subpack/24/releases', '2016-03-04', (select concept_id from concept where concept_name='Dictionary of Medicines and Devices (NHS)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (75, 'dm+d', null, null, null, null);

-- Add drug equivalence relationships
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Drug to standard drug equivalent (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Drug to standard eq', 'Drug go standard drug equivalent (OMOP)', 0, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Drug to standard drug equivalent (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Standard drug to drug equivalent (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Standard to drug eq', 'Standard drug to drug equivalent (OMOP)', 0, 0, 'Drug to standard eq', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Standard drug to drug equivalent (OMOP)'));
update relationship set reverse_relationship_id='Standard to drug eq' where relationship_id='Drug to standard eq';

-- Add new domain Condition/Device for ICD10CM
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Condition/Device', 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into domain (domain_id, domain_name, domain_concept_id)
  values ('Condition/Device', 'Condition/Device', (select concept_id from concept where concept_name='Condition/Device'));

-- add BDPM (French drugs)
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Public Database of Medications (Social-Sante)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('BDPM', 'Public Database of Medications (Social-Sante)', 'http://base-donnees-publique.medicaments.gouv.fr/telechargement.php', '2016-03-25', (select concept_id from concept where concept_name='Public Database of Medications (Social-Sante)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (76, 'BDPM', null, null, null, null);

-- add AMIS (German drugs)
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Medicinal Products Information System (DIMDI)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('AMIS', 'Medicinal Products Information System (DIMDI)', 'https://portal.dimdi.de/websearch/servlet/FlowController/AcceptFZK#__DEFANCHOR__', '2016-01-08', (select concept_id from concept where concept_name='Medicinal Products Information System (DIMDI)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (77, 'AMIS', null, null, null, null);

-- add AMT (Australian drugs)
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Australian Medicines Terminology (NEHTA)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('AMT', 'Australian Medicines Terminology (NEHTA)', 'https://www.nehta.gov.au/implementation-resources/terminology-access', '2016-03-31', (select concept_id from concept where concept_name='Australian Medicines Terminology (NEHTA)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (77, 'AMIS', null, null, null, null);




commit;

------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remove invalid ICD10 codes
delete 
from concept_relationship r 
where exists (
  select 1 from concept c1 where r.concept_id_1=c1.concept_id and c1.vocabulary_id='ICD10CM' and c1.concept_class_id='ICD10 code'
)
;

update concept set 
  'Invalid ICD10 Concept, do not use' as concept_name, 
  vocabulary_id='ICD10', 
  concept_code=concept_id, -- so they can't even find them anymore by concept_code
  '1-July-2015' as valid_end_date, 
  'D' as invalid_reason
where vocabulary_id='ICD10CM' 
and concept_class_id='ICD10 code'
;

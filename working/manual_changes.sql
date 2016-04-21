/*
-- start new sequence
drop sequence v5_concept;
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
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (78, 'AMT', null, null, null, null);

-- add EU drugs
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Community Register of Medicinal Products for Human Use (European Commission)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('EU Product', 'Community Register of Medicinal Products for Human Use (European Commission)', 'http://ec.europa.eu/health/documents/community-register/html/index_en.htm', '2016-04-04', (select concept_id from concept where concept_name='Community Register of Medicinal Products for Human Use (European Commission)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (79, 'EU Product', null, null, null, null);

-- Add drug equivalence relationships
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Drug class of drug (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Drug class of drug', 'Drug class of drug (OMOP)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Drug class of drug (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Drug has drug class (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Drug has drug class', 'Drug has drug class (OMOP)', 1, 0, 'Drug class of drug', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Drug has drug class (OMOP)'));
update relationship set reverse_relationship_id='Drug has drug class' where relationship_id='Drug class of drug';

-- Add non-drug concept_classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Non-human drug class Disinfectant', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Disinfectant', 'Non-human drug class Disinfectant', (select concept_id from concept where concept_name = 'Non-human drug class Disinfectant'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Non-human drug class Imaging Material', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Imaging Material', 'Non-human drug class Imaging Material', (select concept_id from concept where concept_name = 'Non-human drug class Imaging Material'));

update concept set concept_name='Non-human drug class Animal Drug' where concept_id=46277305;
update concept set concept_name='Human drug class Cellular Therapy' where concept_id=45754861;
update concept set concept_name='Human drug class Human OTC Drug' where concept_id=45754858;
update concept set concept_name='Human drug class Non-Standardized Allergenic' where concept_id=45754860;
update concept set concept_name='Human drug class Plasma Derivative' where concept_id=45754859;
update concept set concept_name='Human drug class Human Prescription Drug' where concept_id=45754857;
update concept set concept_name='Human drug class Vaccine' where concept_id=45754855;
update concept set concept_name='Human drug class Standardized Allergenic' where concept_id=45754856;
update concept set concept_name='Non-human drug class Food' where concept_id=46274137;
update concept set concept_name='Non-human drug class Supplement' where concept_id=46274138;
update concept set concept_name='Non-human drug class Cosmetic' where concept_id=46274139;

update concept_class set concept_class_name='Non-human drug class Animal Drug' where concept_class_concept_id=46277305;
update concept_class set concept_class_name='Human drug class Cellular Therapy' where concept_class_concept_id=45754861;
update concept_class set concept_class_name='Human drug class Human OTC Drug' where concept_class_concept_id=45754858;
update concept_class set concept_class_name='Human drug class Non-Standardized Allergenic' where concept_class_concept_id=45754860;
update concept_class set concept_class_name='Human drug class Plasma Derivative' where concept_class_concept_id=45754859;
update concept_class set concept_class_name='Human drug class Human Prescription Drug' where concept_class_concept_id=45754857;
update concept_class set concept_class_name='Human drug class Vaccine' where concept_class_concept_id=45754855;
update concept_class set concept_class_name='Human drug class Standardized Allergenic' where concept_class_concept_id=45754856;
update concept_class set concept_class_name='Non-human drug class Food' where concept_class_concept_id=46274137;
update concept_class set concept_class_name='Non-human drug class Supplement' where concept_class_concept_id=46274138;
update concept_class set concept_class_name='Non-human drug class Cosmetic' where concept_class_concept_id=46274139;

-- Remove invalid ICD10 codes
delete 
from concept_relationship r 
where exists (
  select 1 from concept c1 where r.concept_id_1=c1.concept_id and c1.vocabulary_id='ICD10CM' and c1.concept_class_id='ICD10 code'
)
;

delete 
from concept_relationship r 
where exists (
  select 1 from concept c1 where r.concept_id_2=c1.concept_id and c1.vocabulary_id='ICD10CM' and c1.concept_class_id='ICD10 code'
)
;

update concept set 
  concept_name='Invalid ICD10 Concept, do not use', 
  vocabulary_id='ICD10', 
  concept_code=concept_id, -- so they can't even find them anymore by concept_code
  valid_end_date='13-Apr-2016', 
  invalid_reason='D'
where vocabulary_id='ICD10CM' 
and concept_class_id='ICD10 code'
;

-- Fix domain assignment of existing procedure drugs
-- Remove radiopharmaceutical
update concept_relationship 
  set valid_end_date = '15-Apr-2016', invalid_reason = 'D' 
where concept_id_1=40664879 and concept_id_2=43531992;

-- Turn into Drugs
UPDATE concept c
   SET c.domain_id='Drug'
 WHERE     EXISTS (
              SELECT 1
                 FROM concept_relationship r, concept c2
                WHERE     r.concept_id_1 = c.concept_id
                      AND r.concept_id_2 = c2.concept_id
                      AND r.invalid_reason IS NULL
                      AND r.relationship_id = 'Maps to'
                      AND c2.vocabulary_id = 'RxNorm'
               UNION ALL
               SELECT 1
                 FROM concept_relationship_stage r
                WHERE     r.concept_code_1 = c.concept_code
                      AND r.vocabulary_id_1 = 'HCPCS'
                      AND r.vocabulary_id_2 = 'RxNorm'
                      AND r.invalid_reason IS NULL
                      AND r.relationship_id = 'Maps to'
              )
       AND c.domain_id<>'Drug'
       AND c.vocabulary_id='HCPCS'
;

-- Add composite Death Type
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other government reported or identified death', 'Type Concept', 'Death Type', 'Death Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);

update vocabulary_conversion set available=null where vocabulary_id_v5='ICD10CM';
update vocabulary_conversion set latest_update='28-Mar-2016' where vocabulary_id_v5='DPD';
update vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='BDPM';
update vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='AMIS';
update vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='AMT';
update vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='EU Product';
update vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='dm+d';
update vocabulary set vocabulary_name='Gemscript (Resip)', vocabulary_reference='http://www.resip.co.uk/downloads', vocabulary_version='March 2016' where vocabulary_id='Gemscript';
update vocabulary set vocabulary_reference='http://www.whocc.no/atc_ddd_index/' where vocabulary_id='Gemscript';
update vocabulary_conversion set click_disabled=null where vocabulary_id_v5='ICD10CM';

update prodv5.vocabulary_conversion set available=null where vocabulary_id_v5='ICD10CM';
update prodv5.vocabulary_conversion set latest_update='28-Mar-2016' where vocabulary_id_v5='DPD';
update prodv5.vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='BDPM';
update prodv5.vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='AMIS';
update prodv5.vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='AMT';
update prodv5.vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='EU Product';
update prodv5.vocabulary_conversion set available='Currently not available' where vocabulary_id_v5='dm+d';
update prodv5.vocabulary set vocabulary_name='Gemscript (Resip)', vocabulary_reference='http://www.resip.co.uk/downloads', vocabulary_version='March 2016' where vocabulary_id='Gemscript';
update prodv5.vocabulary set vocabulary_reference='http://www.whocc.no/atc_ddd_index/' where vocabulary_id='Gemscript';
update prodv5.vocabulary_conversion set click_disabled=null where vocabulary_id_v5='ICD10CM';
update prodv5.vocabulary_conversion set click_disabled='Y' where vocabulary_id_v5='DA_France';
update prodv5.vocabulary_conversion set click_disabled='Y' where vocabulary_id_v5='AMT';
update prodv5.vocabulary_conversion set click_disabled='Y' where vocabulary_id_v5='AMIS';
update prodv5.vocabulary_conversion set click_disabled='Y' where vocabulary_id_v5='EU Product';
update prodv5.vocabulary_conversion set click_disabled='Y' where vocabulary_id_v5='BDPM';
update prodv5.vocabulary_conversion set click_disabled='Y' where vocabulary_id_v5='dm+d';

commit;

-- Fix undeprecated old Maps to for HCPCS procedure drugs
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Maps to' and concept_id_1=43533174 and concept_id_2=44786563;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Maps to' and concept_id_1=43533174 and concept_id_2=42800248;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Mapped from' and concept_id_2=43533174 and concept_id_1=44786563;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Mapped from' and concept_id_2=43533174 and concept_id_1=42800248;

update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Maps to' and concept_id_1=43533246 and concept_id_2=44786570;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Maps to' and concept_id_1=43533246 and concept_id_2=42801290;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Mapped from' and concept_id_2=43533246 and concept_id_1=44786570;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Mapped from' and concept_id_2=43533246 and concept_id_1=42801290;

update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Maps to' and concept_id_1=43533298 and concept_id_2=44786568;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Maps to' and concept_id_1=43533298 and concept_id_2=42873620;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Mapped from' and concept_id_2=43533298 and concept_id_1=44786568;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Mapped from' and concept_id_2=43533298 and concept_id_1=42873620;

update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Maps to' and concept_id_1=43533338 and concept_id_2=44786573;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Maps to' and concept_id_1=43533338 and concept_id_2=42874264;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Mapped from' and concept_id_2=43533338 and concept_id_1=44786573;
update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' where relationship_id='Mapped from' and concept_id_2=43533338 and concept_id_1=42874264;

update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' 
where rowid in (
  select r.rowid
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null and r.relationship_id='Maps to'
  join concept c2 on c2.concept_id=r.concept_id_2
  where 1=1
  and c1.vocabulary_id='HCPCS' and c2.vocabulary_id='RxNorm'
  and c1.concept_id in (select concept_id_1 from concept_relationship where invalid_reason is null and relationship_id='Maps to' group by concept_id_1 having count(8)>1)
  and r.valid_start_date!='28-Oct-15'
)
;

update concept_relationship set valid_end_date='27-Oct-2015', invalid_reason='D' 
where rowid in (
  select r.rowid
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null and r.relationship_id='Mapped from'
  join concept c2 on c2.concept_id=r.concept_id_2
  where 1=1
  and c2.vocabulary_id='HCPCS' and c1.vocabulary_id='RxNorm'
  and c2.concept_id in (select concept_id_1 from concept_relationship where invalid_reason is null and relationship_id='Maps to' group by concept_id_1 having count(8)>1)
  and r.valid_start_date!='28-Oct-15'
)
;

rollback;


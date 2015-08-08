-- Add Mesh concept_class_id values
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Main Heading or Descriptor', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Supplementary Concept', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Main Heading', 'Main Heading or Descriptor', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Main Heading or Descriptor'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Suppl Concept', 'Supplementary Concept', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Supplementary Concept'));

-- remove duplicate MeSH codes
delete from concept_relationship where concept_id_1 in (45617698, 45613364, 45614600) or concept_id_2 in (45617698, 45613364, 45614600);
delete from concept where concept_id in (45617698, 45613364, 45614600);

-- Add ICD10CM classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '3-character non-billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('3-char nonbill code', '3-character non-billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '3-character non-billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '4-character non-billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('4-char nonbill code', '4-character non-billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '4-character non-billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '5-character non-billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('5-char nonbill code', '5-character non-billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '5-character non-billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '6-character non-billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('6-char nonbill code', '6-character non-billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '6-character non-billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '7-character non-billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('7-char nonbill code', '7-character non-billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '7-character non-billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '3-character billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('3-char billing code', '3-character billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '3-character billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '4-character billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('4-char billing code', '4-character billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '4-character billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '5-character billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('5-char billing code', '5-character billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '5-character billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '6-character billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('6-char billing code', '6-character billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '6-character billing code'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '7-character billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('7-char billing code', '7-character billing code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '7-character billing code'));

-- add ICD9 classes for E codes where the number of digits is counted differently.
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '3-digit billing E code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('3-dig billing E code', '3-digit billing E code', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = '3-digit billing E code'));

-- Make names of SNOMED associating relationships asymmetrical
update concept set concept_name = 'Finding associated with (SNOMED)' where concept_id = 44818792;
update concept set concept_name = 'Associated with finding (SNOMED)' where concept_id = 44818890;
update relationship set relationship_name = 'Finding associated with (SNOMED)' where relationship_concept_id = 44818792;
update relationship set relationship_name = 'Associated with finding (SNOMED)' where relationship_concept_id = 44818890;

-- Add relationships for LOINC panels
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Panel contains (LOINC)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Panel contains', 'Panel contains (LOINC)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Panel contains (LOINC)'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Contained in panel (LOINC)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Contained in panel', 'Contained in panel (LOINC)', 1, 0, 'Panel contains', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Contained in panel (LOINC)'));

-- Add fact_relationship concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Patient moved to', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Patient moved from', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Diastolic to systolic blood pressure measurement', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Systolic to diastolic blood pressure measurement', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Relevant condition of', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Condition relevant to', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Patient moved to', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Patient moved to', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Care Site is part of Care Site', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Care Site contains Care Site', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add vaccine NDC
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason) 
  values (v5_concept.nextval, 'Trumenba Meningococcal B Vaccine, recombinant lipoprotein', 'Drug', 'NDC', '11-digit NDC', null, '00005010002', to_date('20130715', 'YYYYMMDD'), to_date('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason) 
  values (v5_concept.nextval, 'Flucelvax Influenza vaccine, injectable, MDCK, preservative free', 'Drug', 'NDC', '11-digit NDC', null, '63851061301', to_date('20130715', 'YYYYMMDD'), to_date('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason) 
  values (v5_concept.nextval, 'Influenza (H5N1) vaccine monovalent, adjuvanted', 'Drug', 'NDC', '11-digit NDC', null, '58160080815', to_date('20130715', 'YYYYMMDD'), to_date('20991231', 'YYYYMMDD'), null);
-- GSK Infuenza A (H5N1) Virus Monovalent Vaccine, Adjuvanted, not found in RxNorm, might be there.
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason) 
  values (v5_concept.nextval, 'FluMist Quadrivalent influenza vaccine live intranasal', 'Drug', 'NDC', '11-digit NDC', null, '66019030010', to_date('20130715', 'YYYYMMDD'), to_date('20991231', 'YYYYMMDD'), null);
-- Flumist Nasal 2013-2014 Vaccine, absent from RxNorm

insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values ((select concept_id from concept where vocabulary_id='NDC' and concept_code='00005010002'), 45775646, 'Maps to', '15-Jul-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values ((select concept_id from concept where vocabulary_id='NDC' and concept_code='63851061301'), 44818418, 'Maps to', '15-Jul-2015', '31-Dec-2099', null);

-- Update vaccine NDC
update concept set concept_name ='FLUZONE High-Dose INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20130628', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281039365';
update concept set concept_name ='INFANRIX DIPHTHERIA AND TETANUS TOXOIDS AND ACELLULAR PERTUSSIS VACCINE ADSORBED intramuscular', valid_start_date = to_date('20090724', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081052';
update concept set concept_name ='INFANRIX DIPHTHERIA AND TETANUS TOXOIDS AND ACELLULAR PERTUSSIS VACCINE ADSORBED intramuscular', valid_start_date = to_date('20090724', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081011';
update concept set concept_name ='Typhim Vi SALMONELLA TYPHI TY2 VI POLYSACCHARIDE ANTIGEN intramuscular', valid_start_date = to_date('19941128', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281079051';
update concept set concept_name ='Typhim Vi SALMONELLA TYPHI TY2 VI POLYSACCHARIDE ANTIGEN intramuscular', valid_start_date = to_date('19941128', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281079020';
update concept set concept_name ='INFLUENZA A (H1N1) 2009 MONOVALENT VACCINE INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (FORMALDEHYDE INACTIVATED) intramuscular', valid_start_date = to_date('20090915', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281064015';
update concept set concept_name ='INFLUENZA A (H1N1) 2009 MONOVALENT VACCINE INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (FORMALDEHYDE INACTIVATED) intramuscular', valid_start_date = to_date('20090915', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281065010';
update concept set concept_name ='INFLUENZA A (H1N1) 2009 MONOVALENT VACCINE INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (FORMALDEHYDE INACTIVATED) intramuscular', valid_start_date = to_date('20090915', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281065090';
update concept set concept_name ='INFLUENZA A (H1N1) 2009 MONOVALENT VACCINE INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (FORMALDEHYDE INACTIVATED) intramuscular', valid_start_date = to_date('20090915', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281065025';
update concept set concept_name ='INFLUENZA A (H1N1) 2009 MONOVALENT VACCINE INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (FORMALDEHYDE INACTIVATED) intramuscular', valid_start_date = to_date('20090915', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281065070';
update concept set concept_name ='INFLUENZA A (H1N1) 2009 MONOVALENT VACCINE INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (FORMALDEHYDE INACTIVATED) intramuscular', valid_start_date = to_date('20090915', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281065050';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A INTRADERMAL', valid_start_date = to_date('20130628', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281070755';
update concept set concept_name ='FluMist INFLUENZA VACCINE LIVE intranasal NASAL', valid_start_date = to_date('20120801', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66019011010';
update concept set concept_name ='M-M-R II MEASLES, MUMPS, AND RUBELLA VIRUS VACCINE LIVE subcutaneous', valid_start_date = to_date('19710421', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006468100';
update concept set concept_name ='TENIVAC CLOSTRIDIUM TETANI TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED) AND CORYNEBACTERIUM DIPHTHERIAE TOXOID intramuscular', valid_start_date = to_date('20101208', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281021510';
update concept set concept_name ='TENIVAC CLOSTRIDIUM TETANI TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED) AND CORYNEBACTERIUM DIPHTHERIAE TOXOID intramuscular', valid_start_date = to_date('20101208', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281021515';
update concept set concept_name ='Menveo MENINGOCOCCAL (GROUPS A, C, Y AND W-135) OLIGOSACCHARIDE DIPHTHERIA CRM197 CONJUGATE VACCINE intramuscular', valid_start_date = to_date('20100219', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='46028020801';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20100723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281038765';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20100723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281038615';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20100723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001010';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20100723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001025';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20100723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001050';
update concept set concept_name ='M-M-R II MEASLES, MUMPS, AND RUBELLA VIRUS VACCINE LIVE subcutaneous', valid_start_date = to_date('19960807', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='54868098000';
update concept set concept_name ='CERVARIX HUMAN PAPILLOMAVIRUS BIVALENT (TYPES 16 AND 18) VACCINE, RECOMBINANT intramuscular', valid_start_date = to_date('20091016', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160083052';
update concept set concept_name ='CERVARIX HUMAN PAPILLOMAVIRUS BIVALENT (TYPES 16 AND 18) VACCINE, RECOMBINANT intramuscular', valid_start_date = to_date('20091016', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160083034';
update concept set concept_name ='PREVNAR 13 PNEUMOCOCCAL 13-VALENT CONJUGATE VACCINE intramuscular', valid_start_date = to_date('20100312', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00005197104';
update concept set concept_name ='PREVNAR 13 PNEUMOCOCCAL 13-VALENT CONJUGATE VACCINE intramuscular', valid_start_date = to_date('20100312', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00005197105';
update concept set concept_name ='PREVNAR 13 PNEUMOCOCCAL 13-VALENT CONJUGATE VACCINE intramuscular', valid_start_date = to_date('20100312', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00005197102';
update concept set concept_name ='Tetanus and Diphtheria Toxoids Adsorbed TETANUS AND DIPHTHERIA TOXOIDS ADSORBED intramuscular', valid_start_date = to_date('19700727', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='17478013101';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) subcutaneous; INTRAM', valid_start_date = to_date('19860723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='54868221901';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) subcutaneous; INTRAM', valid_start_date = to_date('19860723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='54868221900';
update concept set concept_name ='KINRIX DIPHTHERIA AND TETANUS TOXOIDS AND ACELLULAR PERTUSSIS ADSORBED AND INACTIVATED POLIOVIRUS VACCINE intramuscular', valid_start_date = to_date('20080709', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081252';
update concept set concept_name ='KINRIX DIPHTHERIA AND TETANUS TOXOIDS AND ACELLULAR PERTUSSIS ADSORBED AND INACTIVATED POLIOVIRUS VACCINE intramuscular', valid_start_date = to_date('20080709', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081211';
update concept set concept_name ='FluMist INFLUENZA VACCINE LIVE intranasal NASAL', valid_start_date = to_date('20100722', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66019010810';
update concept set concept_name ='COMVAX HAEMOPHILUS B CONJUGATE (MENINGOCOCCAL PROTEIN CONJUGATE) AND HEPATITIS B (RECOMBINANT) VACCINE intramuscular', valid_start_date = to_date('19961002', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006489800';
update concept set concept_name ='MENHIBRIX MENINGOCOCCAL GROUPS C AND Y AND HAEMOPHILUS B TETANUS TOXOID CONJUGATE VACCINE intramuscular', valid_start_date = to_date('20130903', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160080111';
update concept set concept_name ='Flucelvax INFLUENZA A VIRUS A/BRISBANE/10/2010 (H1N1) ANTIGEN (MDCK CELL DERIVED, PROPIOLACTONE INACTIVATED), intramuscular', valid_start_date = to_date('20130830', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='63851061201';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) intramuscular; subcutaneous', valid_start_date = to_date('19860723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006499200';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) intramuscular; subcutaneous', valid_start_date = to_date('19860723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006498100';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) intramuscular; subcutaneous', valid_start_date = to_date('19860723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006498000';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) intramuscular; subcutaneous', valid_start_date = to_date('19860723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006409309';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) subcutaneous; INTRAM', valid_start_date = to_date('19860723', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006409409';
update concept set concept_name ='GARDASIL HUMAN PAPILLOMAVIRUS QUADRIVALENT (TYPES 6, 11, 16, AND 18) VACCINE, RECOMBINANT intramuscular', valid_start_date = to_date('20060608', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006410909';
update concept set concept_name ='HAVRIX HEPATITIS A VACCINE intramuscular', valid_start_date = to_date('20070413', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='55045384101';
update concept set concept_name ='Fluvirin Influenza Virus Vaccine intramuscular', valid_start_date = to_date('19980812', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011202';
update concept set concept_name ='Fluvirin Influenza Virus Vaccine intramuscular', valid_start_date = to_date('19980812', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011210';
update concept set concept_name ='FluMist INFLUENZA VACCINE LIVE intranasal NASAL', valid_start_date = to_date('20090717', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66019010701';
update concept set concept_name ='DIPHTHERIA AND TETANUS TOXOIDS ADSORBED CORYNEBACTERIUM DIPHTHERIAE TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED) AND CLOSTRIDIUM TETANI TOXOID intramuscular', valid_start_date = to_date('20100329', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281022510';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A INTRADERMAL', valid_start_date = to_date('20120702', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281070555';
update concept set concept_name ='IXIARO JAPANESE ENCEPHALITIS VACCINE, INACTIVATED, ADSORBED intramuscular', valid_start_date = to_date('20090330', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='42515000101';
update concept set concept_name ='FLUARIX INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20120720', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160087952';
update concept set concept_name ='FLUARIX INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20130701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160088052';
update concept set concept_name ='ENGERIX-B HEPATITIS B VACCINE (RECOMBINANT) intramuscular', valid_start_date = to_date('20070425', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082011';
update concept set concept_name ='ENGERIX-B HEPATITIS B VACCINE (RECOMBINANT) intramuscular', valid_start_date = to_date('20070425', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082052';
update concept set concept_name ='ENGERIX-B HEPATITIS B VACCINE (RECOMBINANT) intramuscular', valid_start_date = to_date('20070328', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082111';
update concept set concept_name ='ENGERIX-B HEPATITIS B VACCINE (RECOMBINANT) intramuscular', valid_start_date = to_date('20070328', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082152';
update concept set concept_name ='ENGERIX-B HEPATITIS B VACCINE (RECOMBINANT) intramuscular', valid_start_date = to_date('20070328', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082134';
update concept set concept_name ='Flublok INFLUENZA VACCINE intramuscular', valid_start_date = to_date('20130201', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='42874001210';
update concept set concept_name ='DIPHTHERIA AND TETANUS TOXOIDS ADSORBED CORYNEBACTERIUM DIPHTHERIAE TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED) AND CLOSTRIDIUM TETANI TOXOID intramuscular', valid_start_date = to_date('19840918', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281027810';
update concept set concept_name ='FluMist INFLUENZA VACCINE LIVE intranasal NASAL', valid_start_date = to_date('20110630', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66019010910';
update concept set concept_name ='FLULAVAL INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20130701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='19515089007';
update concept set concept_name ='FLULAVAL INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20120720', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='19515088907';
update concept set concept_name ='FLUARIX QUADRIVALENT INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20130701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160090052';
update concept set concept_name ='IPOL POLIOVIRUS TYPE 1 ANTIGEN (FORMALDEHYDE INACTIVATED), POLIOVIRUS TYPE 2 ANTIGEN (FORMALDEHYDE INACTI intramuscular', valid_start_date = to_date('19901221', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281086055';
update concept set concept_name ='IPOL POLIOVIRUS TYPE 1 ANTIGEN (FORMALDEHYDE INACTIVATED), POLIOVIRUS TYPE 2 ANTIGEN (FORMALDEHYDE INACTI intramuscular', valid_start_date = to_date('19901221', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281086010';
update concept set concept_name ='FLUZONE High-Dose INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20110701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281038965';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20110701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281038815';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20110701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001110';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20110701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001150';
update concept set concept_name ='FLUZONE Intradermal INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A INTRADERMAL', valid_start_date = to_date('20110701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281070355';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20110701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281011125';
update concept set concept_name ='ENGERIX-B HEPATITIS B VACCINE (RECOMBINANT) intramuscular', valid_start_date = to_date('20020805', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='54868073400';
update concept set concept_name ='Influenza A (H1N1) 2009 Monovalent Vaccine Influenza A (H1N1) 2009 Monovalent Vaccine intramuscular', valid_start_date = to_date('20090915', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521020010';
update concept set concept_name ='Influenza A (H1N1) 2009 Monovalent Vaccine Influenza A (H1N1) 2009 Monovalent Vaccine intramuscular', valid_start_date = to_date('20090915', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521020002';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20100916', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='54868617700';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20100921', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='54868618000';
update concept set concept_name ='TRIPEDIA CORYNEBACTERIUM DIPHTHERIAE TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED), CLOSTRIDIUM TETANI TOXOID ANT intramuscular', valid_start_date = to_date('19920820', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281029810';
update concept set concept_name ='HIBERIX HAEMOPHILUS B CONJUGATE VACCINE (TETANUS TOXOID CONJUGATE) intramuscular', valid_start_date = to_date('20090824', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160080605';
update concept set concept_name ='AFLURIA INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-181 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20110715', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332001301';
update concept set concept_name ='AFLURIA INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-181 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20110715', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332011310';
update concept set concept_name ='FLUZONE High-Dose INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20120702', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281039165';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20120702', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001250';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20120702', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001210';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20120702', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281011225';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20120702', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281039015';
update concept set concept_name ='PedvaxHIB HAEMOPHILUS B CONJUGATE VACCINE (MENINGOCOCCAL PROTEIN CONJUGATE) intramuscular', valid_start_date = to_date('19891220', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006489700';
update concept set concept_name ='DECAVAC CLOSTRIDIUM TETANI TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED) AND CORYNEBACTERIUM DIPHTHERIAE TOXOID intramuscular', valid_start_date = to_date('20040324', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281029183';
update concept set concept_name ='DECAVAC CLOSTRIDIUM TETANI TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED) AND CORYNEBACTERIUM DIPHTHERIAE TOXOID intramuscular', valid_start_date = to_date('20040324', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281029110';
update concept set concept_name ='FLUZONE QUADRIVALENT INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20130610', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281041350';
update concept set concept_name ='FLUZONE QUADRIVALENT INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20130610', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281041310';
update concept set concept_name ='FLUZONE QUADRIVALENT INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20130610', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281051325';
update concept set concept_name ='FLUVIRIN INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-181 (H1N1) HEMAGGLUTININ ANTIGEN (PROPIOLACTONE INACTIVATED) intramuscular', valid_start_date = to_date('19880812', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011302';
update concept set concept_name ='FLUVIRIN INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-181 (H1N1) HEMAGGLUTININ ANTIGEN (PROPIOLACTONE INACTIVATED) intramuscular', valid_start_date = to_date('19880812', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011310';
update concept set concept_name ='Prevnar PNEUMOCOCCAL 7-VALENT intramuscular', valid_start_date = to_date('20000301', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00005197050';
update concept set concept_name ='RotaTeq ROTAVIRUS VACCINE, LIVE, ORAL, PENTAVALENT ORAL', valid_start_date = to_date('20060203', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006404741';
update concept set concept_name ='RotaTeq ROTAVIRUS VACCINE, LIVE, ORAL, PENTAVALENT ORAL', valid_start_date = to_date('20060203', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006404720';
update concept set concept_name ='PEDIARIX DIPHTHERIA AND TETANUS TOXOIDS AND ACELLULAR PERTUSSIS ADSORBED, HEPATITIS B (RECOMBINANT) AND INACT intramuscular', valid_start_date = to_date('20090724', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081152';
update concept set concept_name ='PEDIARIX DIPHTHERIA AND TETANUS TOXOIDS AND ACELLULAR PERTUSSIS ADSORBED, HEPATITIS B (RECOMBINANT) AND INACT intramuscular', valid_start_date = to_date('20090724', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081151';
update concept set concept_name ='VARIVAX VARICELLA VIRUS VACCINE LIVE subcutaneous', valid_start_date = to_date('19950317', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006482700';
update concept set concept_name ='VARIVAX VARICELLA VIRUS VACCINE LIVE subcutaneous', valid_start_date = to_date('19950317', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006482600';
update concept set concept_name ='BOOSTRIX TETANUS TOXOID, REDUCED DIPHTHERIA TOXOID AND ACELLULAR PERTUSSIS VACCINE, ADSORBED intramuscular', valid_start_date = to_date('20090724', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160084251';
update concept set concept_name ='BOOSTRIX TETANUS TOXOID, REDUCED DIPHTHERIA TOXOID AND ACELLULAR PERTUSSIS VACCINE, ADSORBED intramuscular', valid_start_date = to_date('20090724', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160084211';
update concept set concept_name ='BOOSTRIX TETANUS TOXOID, REDUCED DIPHTHERIA TOXOID AND ACELLULAR PERTUSSIS VACCINE, ADSORBED intramuscular', valid_start_date = to_date('20090724', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160084252';
update concept set concept_name ='BOOSTRIX TETANUS TOXOID, REDUCED DIPHTHERIA TOXOID AND ACELLULAR PERTUSSIS VACCINE, ADSORBED intramuscular', valid_start_date = to_date('20090724', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160084234';
update concept set concept_name ='Menactra NEISSERIA MENINGITIDIS GROUP A CAPSULAR POLYSACCHARIDE DIPHTHERIA TOXOID CONJUGATE ANTIGEN, NEISSERI intramuscular', valid_start_date = to_date('20050114', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281058905';
update concept set concept_name ='VAQTA HEPATITIS A VACCINE, INACTIVATED intramuscular', valid_start_date = to_date('19960329', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006409509';
update concept set concept_name ='VAQTA HEPATITIS A VACCINE, INACTIVATED intramuscular', valid_start_date = to_date('19960329', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006409609';
update concept set concept_name ='VAQTA HEPATITIS A VACCINE, INACTIVATED intramuscular', valid_start_date = to_date('19960329', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006483141';
update concept set concept_name ='RabAvert RABIES VACCINE intramuscular', valid_start_date = to_date('19971020', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='63851050101';
update concept set concept_name ='Influenza A H1N1 2009 Monovalent Vaccine Live Intr INFLUENZA A H1N1 2009 MONOVALENT VACCINE LIVE intranasal NASAL', valid_start_date = to_date('20091001', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66019020010';
update concept set concept_name ='Tetanus and Diphtheria Toxoids Adsorbed TETANUS AND DIPHTHERIA TOXOIDS ADSORBED intramuscular', valid_start_date = to_date('19700727', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='14362011103';
update concept set concept_name ='Influenza A INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (PROPIOLACTONE INACTIVATED) intramuscular', valid_start_date = to_date('20090701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332051901';
update concept set concept_name ='Influenza A INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (PROPIOLACTONE INACTIVATED) intramuscular', valid_start_date = to_date('20090701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332051925';
update concept set concept_name ='Influenza A INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE ANTIGEN (PROPIOLACTONE INACTIVATED) intramuscular', valid_start_date = to_date('20090701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332062910';
update concept set concept_name ='HAVRIX HEPATITIS A VACCINE intramuscular', valid_start_date = to_date('20070216', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082552';
update concept set concept_name ='HAVRIX HEPATITIS A VACCINE intramuscular', valid_start_date = to_date('20070216', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082511';
update concept set concept_name ='HAVRIX HEPATITIS A VACCINE intramuscular', valid_start_date = to_date('20070413', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082652';
update concept set concept_name ='HAVRIX HEPATITIS A VACCINE intramuscular', valid_start_date = to_date('20070413', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082634';
update concept set concept_name ='HAVRIX HEPATITIS A VACCINE intramuscular', valid_start_date = to_date('20070413', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160082611';
update concept set concept_name ='AFLURIA INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-181 (H1N1) HEMAGGLUTININ ANTIGEN (PROPIOLACTONE INACTIVATED) intramuscular', valid_start_date = to_date('20100730', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332001001';
update concept set concept_name ='AFLURIA INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-181 (H1N1) HEMAGGLUTININ ANTIGEN (PROPIOLACTONE INACTIVATED) intramuscular', valid_start_date = to_date('20100730', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332011010';
update concept set concept_name ='Fluvirin INFLUENZA A VIRUS A/CHRISTCHURCH/16/2010 NIB-74 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZ intramuscular', valid_start_date = to_date('20120720', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011510';
update concept set concept_name ='Fluvirin INFLUENZA A VIRUS A/CHRISTCHURCH/16/2010 NIB-74 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZ intramuscular', valid_start_date = to_date('20120720', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011502';
update concept set concept_name ='Tetanus and Diphtheria Toxoids Adsorbed TETANUS AND DIPHTHERIA TOXOIDS ADSORBED intramuscular', valid_start_date = to_date('19700727', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006413341';
update concept set concept_name ='PNEUMOVAX 23 PNEUMOCOCCAL VACCINE POLYVALENT intramuscular; subcutaneous', valid_start_date = to_date('20060220', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='54868432000';
update concept set concept_name ='PNEUMOVAX 23 PNEUMOCOCCAL VACCINE POLYVALENT subcutaneous; INTRAM', valid_start_date = to_date('19940920', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='54868333901';
update concept set concept_name ='BCG VACCINE BACILLUS CALMETTE-GUERIN SUBSTRAIN TICE LIVE ANTIGEN PERCUTANEOUS', valid_start_date = to_date('19890621', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00052060302';
update concept set concept_name ='BioThrax BACILLUS ANTHRACIS intramuscular', valid_start_date = to_date('19701104', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='64678021101';
update concept set concept_name ='Physicians EZ Use Flu Kit INFLUENZA A VIRUS A/CHRISTCHURCH/16/2010 NIB-74 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZ intramuscular; TOPIC', valid_start_date = to_date('20130401', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='76420047010';
update concept set concept_name ='PNEUMOVAX 23 PNEUMOCOCCAL VACCINE POLYVALENT intramuscular; subcutaneous', valid_start_date = to_date('19830707', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006473900';
update concept set concept_name ='PNEUMOVAX 23 PNEUMOCOCCAL VACCINE POLYVALENT intramuscular; subcutaneous', valid_start_date = to_date('19830707', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006494300';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20130628', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001310';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20130628', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281001350';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20130628', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281039215';
update concept set concept_name ='FLUZONE INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-179A (H1N1) ANTIGEN (FORMALDEHYDE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20130628', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281011325';
update concept set concept_name ='TETANUS TOXOID ADSORBED CLOSTRIDIUM TETANI TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED) intramuscular', valid_start_date = to_date('20050923', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281082010';
update concept set concept_name ='TETANUS TOXOID ADSORBED CLOSTRIDIUM TETANI TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED) intramuscular', valid_start_date = to_date('20050923', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281080083';
update concept set concept_name ='Adacel CLOSTRIDIUM TETANI TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED), CORYNEBACTERIUM DIPHTHERIAE TOXOID ANT intramuscular', valid_start_date = to_date('20131001', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281040015';
update concept set concept_name ='Medical Provider Single Use EZ Flu Shot 2013-2014 INFLUENZA A VIRUS A/CHRISTCHURCH/16/2010 NIB-74 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZ TOPICAL; intramuscularL', valid_start_date = to_date('20130530', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='76420048301';
update concept set concept_name ='Medical Provider Single Use EZ Flu Shot 2013-2014 INFLUENZA A VIRUS A/CHRISTCHURCH/16/2010 NIB-74 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZ intramuscular; TOPIC', valid_start_date = to_date('20130530', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='76420048201';
update concept set concept_name ='DAPTACEL CORYNEBACTERIUM DIPHTHERIAE TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED), CLOSTRIDIUM TETANI TOXOID ANT intramuscular', valid_start_date = to_date('20020514', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281028601';
update concept set concept_name ='DAPTACEL CORYNEBACTERIUM DIPHTHERIAE TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED), CLOSTRIDIUM TETANI TOXOID ANT intramuscular', valid_start_date = to_date('20020514', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281028605';
update concept set concept_name ='DAPTACEL CORYNEBACTERIUM DIPHTHERIAE TOXOID ANTIGEN (FORMALDEHYDE INACTIVATED), CLOSTRIDIUM TETANI TOXOID ANT intramuscular', valid_start_date = to_date('20020514', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281028610';
update concept set concept_name ='Tetanus and Diphtheria Toxoids Adsorbed TETANUS AND DIPHTHERIA TOXOIDS ADSORBED intramuscular', valid_start_date = to_date('19671013', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='21695041301';
update concept set concept_name ='TWINRIX HEPATITIS A AND HEPATITIS B (RECOMBINANT) VACCINE intramuscular', valid_start_date = to_date('20070607', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081546';
update concept set concept_name ='TWINRIX HEPATITIS A AND HEPATITIS B (RECOMBINANT) VACCINE intramuscular', valid_start_date = to_date('20070607', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081552';
update concept set concept_name ='TWINRIX HEPATITIS A AND HEPATITIS B (RECOMBINANT) VACCINE intramuscular', valid_start_date = to_date('20070607', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081534';
update concept set concept_name ='TWINRIX HEPATITIS A AND HEPATITIS B (RECOMBINANT) VACCINE intramuscular', valid_start_date = to_date('20070607', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081548';
update concept set concept_name ='TWINRIX HEPATITIS A AND HEPATITIS B (RECOMBINANT) VACCINE intramuscular', valid_start_date = to_date('20070607', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160081511';
update concept set concept_name ='FLUVIRIN INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE HEMAGGLUTININ ANTIGEN (PROPIOLACTONE INACTIVATED), intramuscular', valid_start_date = to_date('20110701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011410';
update concept set concept_name ='FLUVIRIN INFLUENZA A VIRUS A/CALIFORNIA/7/2009(H1N1)-LIKE HEMAGGLUTININ ANTIGEN (PROPIOLACTONE INACTIVATED), intramuscular', valid_start_date = to_date('20110701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011402';
update concept set concept_name ='Flulaval Quadrivalent INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20130815', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='19515089511';
update concept set concept_name ='Medical Provider Single Use EZ Flu Shot Kit INFLUENZA A VIRUS A/CHRISTCHURCH/16/2010 NIB-74 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZ TOPICAL; intramuscularL', valid_start_date = to_date('20130530', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='76420047101';
update concept set concept_name ='ProQuad MEASLES, MUMPS, RUBELLA AND VARICELLA VIRUS VACCINE LIVE subcutaneous', valid_start_date = to_date('20050906', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006499900';
update concept set concept_name ='PENTACEL DIPHTHERIA AND TETANUS TOXOIDS AND ACELLULAR PERTUSSIS ADSORBED, INACTIVATED POLIOVIRUS AND HAEMOPHI', valid_start_date = to_date('20080620', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281051005';
update concept set concept_name ='Adenovirus Type 4 and Type 7 Vaccine, Live, Oral ADENOVIRUS TYPE 4 AND TYPE 7 VACCINE, LIVE, ORAL', valid_start_date = to_date('20110531', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='51285013850';
update concept set concept_name ='IMOVAX RABIES RABIES VIRUS STRAIN PM-1503-3M ANTIGEN (PROPIOLACTONE INACTIVATED) AND WATER', valid_start_date = to_date('20130930', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281025051';
update concept set concept_name ='MENOMUNE - A/C/Y/W-135 COMBINED NEISSERIA MENINGITIDIS GROUP A CAPSULAR POLYSACCHARIDE ANTIGEN, NEISSERIA MENINGITIDIS GROUP C CAPSU', valid_start_date = to_date('19811123', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281048901';
update concept set concept_name ='YF-VAX YELLOW FEVER VIRUS LIVE ANTIGEN, A', valid_start_date = to_date('19530522', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281091501';
update concept set concept_name ='ACTHIB HAEMOPHILUS INFLUENZAE TYPE B STRAIN 1482 CAPSULAR POLYSACCHARIDE TETANUS TOXOID CONJUGATE ANTIGEN', valid_start_date = to_date('19930330', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281054505';
update concept set concept_name ='ROTARIX ROTAVIRUS VACCINE, LIVE, ORAL', valid_start_date = to_date('20110113', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160085452';
update concept set concept_name ='YF-VAX YELLOW FEVER VIRUS LIVE ANTIGEN, A', valid_start_date = to_date('19530522', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281091505';
update concept set concept_name ='MENOMUNE - A/C/Y/W-135 COMBINED NEISSERIA MENINGITIDIS GROUP A POLYSACCHARIDE ANTIGEN, A, NEISSERIA MENINGITIDIS GROUP C POLYSACCHAR', valid_start_date = to_date('19811123', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281048991';
update concept set concept_name ='ADACEL HAEMOPHILUS INFLUENZAE TYPE B STRAIN 1482 CAPSULAR POLYSACCHARIDE TETANUS TOXOID CONJUGATE ANTIGEN intramuscular', valid_start_date = to_date('20050610', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281040010';
update concept set concept_name ='ADACEL HAEMOPHILUS INFLUENZAE TYPE B STRAIN 1482 CAPSULAR POLYSACCHARIDE TETANUS TOXOID CONJUGATE ANTIGEN intramuscular', valid_start_date = to_date('20050610', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='49281040005';
update concept set concept_name ='Flublok INFLUENZA VACCINE intramuscular', valid_start_date = to_date('20131101', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='42874001310';
update concept set concept_name ='Fluvirin INFLUENZA A VIRUS A/CHRISTCHURCH/16/2010 NIB-74 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZA intramuscular', valid_start_date = to_date('20130730', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011610';
update concept set concept_name ='Fluvirin INFLUENZA A VIRUS A/CHRISTCHURCH/16/2010 NIB-74 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZA intramuscular', valid_start_date = to_date('20130730', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='66521011602';
update concept set concept_name ='GARDASIL HUMAN PAPILLOMAVIRUS QUADRIVALENT (TYPES 6, 11, 16, AND 18) VACCINE, RECOMBINANT intramuscular', valid_start_date = to_date('20060608', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006404541';
update concept set concept_name ='GARDASIL HUMAN PAPILLOMAVIRUS QUADRIVALENT (TYPES 6, 11, 16, AND 18) VACCINE, RECOMBINANT intramuscular', valid_start_date = to_date('20060608', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006404500';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) intramuscular; subcutaneous' where vocabulary_id ='NDC' and concept_code ='00006499541';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) intramuscular; subcutaneous' where vocabulary_id ='NDC' and concept_code ='00006499500';
update concept set concept_name ='VAQTA HEPATITIS A VACCINE, INACTIVATED intramuscular', valid_start_date = to_date('19960329', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006484141';
update concept set concept_name ='VAQTA HEPATITIS A VACCINE, INACTIVATED intramuscular', valid_start_date = to_date('19960329', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006484100';
update concept set concept_name ='FLUARIX QUADRIVALENT INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20140701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160090152';
update concept set concept_name ='PNEUMOVAX 23 PNEUMOCOCCAL VACCINE POLYVALENT intramuscular; subcutaneous', valid_start_date = to_date('20140530', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006483703';
update concept set concept_name ='Flulaval Quadrivalent INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20140701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='19515089452';
update concept set concept_name ='Flulaval Quadrivalent INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20140701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='19515089111';
update concept set concept_name ='FLULAVAL INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20140701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='19515089307';
update concept set concept_name ='Fluzone Quadrivalent, peds  Intramuscular' where vocabulary_id ='NDC' and concept_code ='49281051425';
update concept set concept_name ='FLUZONE QUADRIVALENT PF  INTRAMUSULAR' where vocabulary_id ='NDC' and concept_code ='49281041410';
update concept set concept_name ='FLUZONE QUADRIVALENT  intramuscular' where vocabulary_id ='NDC' and concept_code ='49281062115';
update concept set concept_name ='Flumist Quadrivalent INFLUENZA VACCINE LIVE intranasal' where vocabulary_id ='NDC' and concept_code ='66019030110';
update concept set concept_name ='Afluria INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-181 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20140715', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332001401';
update concept set concept_name ='AFLURIA INFLUENZA A VIRUS A/CALIFORNIA/7/2009 X-181 (H1N1) ANTIGEN (PROPIOLACTONE INACTIVATED), INFLUENZA A intramuscular', valid_start_date = to_date('20140715', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='33332011410';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT) intramuscular; subcutaneous' where vocabulary_id ='NDC' and concept_code ='00006409302';
update concept set concept_name ='RECOMBIVAX HB HEPATITIS B VACCINE (RECOMBINANT)' where vocabulary_id ='NDC' and concept_code ='00006409402';
update concept set concept_name ='VAQTA HEPATITIS A VACCINE, INACTIVATED' where vocabulary_id ='NDC' and concept_code ='00006409502';
update concept set concept_name ='VAQTA HEPATITIS A VACCINE, INACTIVATED' where vocabulary_id ='NDC' and concept_code ='00006409602';
update concept set concept_name ='Flublok influenza virus vaccine' where vocabulary_id ='NDC' and concept_code ='42874001410';
update concept set concept_name ='MENHIBRIX MENINGOCOCCAL GROUP?S C AND Y AND HAEMOPHILUS B TETANUS TOXOID CONJUGATE VACCINE intramuscular', valid_start_date = to_date('20130903', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160080905';
update concept set concept_name ='Flucelvax INFLUENZA A vaccine intramuscular', valid_start_date = to_date('20140701', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='62577061301';
update concept set concept_name ='FLUARIX INFLUENZA VIRUS VACCINE intramuscular', valid_start_date = to_date('20140627', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='58160088152';
update concept set concept_name ='Trumenba Meningococcal B Vaccine, recombinant lipoprotein' where vocabulary_id ='NDC' and concept_code ='00005010005';
update concept set concept_name ='Trumenba Meningococcal B Vaccine, recombinant lipoprotein'  where vocabulary_id ='NDC' and concept_code ='00005010010';
update concept set concept_name ='GARDASIL HUMAN PAPILLOMAVIRUS QUADRIVALENT (TYPES 6, 11, 16, AND 18) VACCINE, RECOMBINANT intramuscular', valid_start_date = to_date('20060608', 'YYYYMMDD') where vocabulary_id ='NDC' and concept_code ='00006410902';


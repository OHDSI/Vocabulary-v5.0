-- Always keep the two sequences on top of the manual_changes.sql. The first one is for really important ones concept_id<1000, 
-- and the other one is for filling in holes, currently in the 5000 range

-- start new sequence for important concepts. Do not use unless justified!!!
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
/

-- start new sequence in a hole of 10000:
drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id>=571191 and concept_id<581479; 
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
/

-- Add CVX
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'CDC Vaccine Administered CVX (NCIRD)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('CVX', 'CDC Vaccine Administered CVX (NCIRD)', 'https://www2a.cdc.gov/vaccines/iis/iisstandards/vaccines.asp?rpt=cvx', '2015 Edition', (select concept_id from concept where concept_name='CDC Vaccine Administered CVX (NCIRD)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (80, 'CVX', null, null, null, null);

-- New Concept Class
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'CVX vaccine', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('CVX', 'CVX vaccine', (select concept_id from concept where concept_name = 'CVX vaccine'));

-- relationships between CVX and RxNorm
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'RxNorm - CVX (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('RxNorm - CVX', 'RxNorm - CVX (OMOP)', 1, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'RxNorm - CVX (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'CVX - RxNorm (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('CVX - RxNorm', 'CVX - RxNorm (OMOP)', 1, 1, 'RxNorm - CVX', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'CVX - RxNorm (OMOP)'));
update relationship set reverse_relationship_id='CVX - RxNorm' where relationship_id='RxNorm - CVX';

commit;

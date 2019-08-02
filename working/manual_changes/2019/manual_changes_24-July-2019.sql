--new relationship for the fact_relationship
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32668, 'Measurement to Specimen', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32669, 'Specimen to Measurement', 'Metadata', 'Relationship', 'Relationship', 'S', 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

insert into concept_relationship values(32668,32668,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32669,32669,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);

--new relationship 'Has unit' (NAACCR)
DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Has unit';
    pRelationship_id constant varchar(100):='Has unit';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='Unit of';
    
    pRelationship_name_rev constant varchar(100):='Unit of';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    ALTER TABLE relationship DROP CONSTRAINT FPK_RELATIONSHIP_REVERSE;
    
    --direct
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
    DROP SEQUENCE v5_concept;
END $$;

--new relationship 'Has unit' (NAACCR)
DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Has type';
    pRelationship_id constant varchar(100):='Has type';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='Type of';
    
    pRelationship_name_rev constant varchar(100):='Type of';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    ALTER TABLE relationship DROP CONSTRAINT FPK_RELATIONSHIP_REVERSE;
    
    --direct
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
    DROP SEQUENCE v5_concept;
END $$;

--new class 'Metadata'
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Metadata';
    pConcept_class_name constant varchar(100):= 'Metadata';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--new vocabulary='Metadata'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
		pVocabulary_id			=> 'Metadata',
		pVocabulary_name		=> 'Metadata',
		pVocabulary_reference	=> 'OMOP generated',
		pVocabulary_version		=> NULL,
		pOMOP_req				=> 'Y',
		pClick_default			=>  'Y',
		pAvailable				=> NULL, 
		pURL					=> NULL,
		pClick_disabled			=> 'Y'
	);
END $_$;

--new concept 'Numeric'
insert into concept (concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
values (32676, 'Numeric' , 'Metadata', 'Metadata', 'Metadata', NULL, 'OMOP4833074', to_date ('19700101', 'yyyymmdd'),to_date ('20991231', 'yyyymmdd'), null);

--add missing 'Is a'
with cdm as (
  select c.concept_id field_concept_id, min(c_t.concept_id) table_concept_id
  from concept c
  left join concept_relationship cr on cr.concept_id_1=c.concept_id and cr.relationship_id='Is a'
  join concept c_t on c.concept_name like c_t.concept_name || '.%'
  where c.vocabulary_id='CDM' and c.concept_class_id='Field'
  and cr.concept_id_1 is null
  and c_t.vocabulary_id='CDM' and c_t.concept_class_id='Table'
  group by c.concept_id
),
rel as (
  select field_concept_id, table_concept_id, 'Is a' as relationship_id, to_date('20141111','yyyymmdd'), to_date('20991231','yyyymmdd'), null from cdm
  union all
  select table_concept_id, field_concept_id, 'Subsumes', to_date('20141111','yyyymmdd'), to_date('20991231','yyyymmdd'), null from cdm
)
insert into concept_relationship
select * from rel;


insert into concept (concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
values(32677, 'Disease Progression' , 'Episode', 'Episode', 'Disease Episode', 'S', 'OMOP4833075', to_date ('19700101', 'yyyymmdd'),to_date ('20991231', 'yyyymmdd'), null);
insert into concept_relationship values(32677,32677,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32677,32677,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
--add new UCUM concepts

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32660, 'mitoses per 10 high power field', 'Unit', 'UCUM', 'Unit', 'S', '{mitoses}/[10 HPF]', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32661, 'mitoses per 40 high power field', 'Unit', 'UCUM', 'Unit', 'S', '{mitoses}/[40 HPF]', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32662, 'mitoses per 50 high power field', 'Unit', 'UCUM', 'Unit', 'S', '{mitoses}/[50 HPF]', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32666, 'centigray', 'Unit', 'UCUM', 'Unit', 'S', 'cGy', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32667, 'mitoses per square millimeter', 'Unit', 'UCUM', 'Unit', 'S', '{mitoses}/mm2', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

insert into concept_relationship values(32660,32660,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32660,32660,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32661,32661,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32661,32661,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32662,32662,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32662,32662,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32666,32666,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32666,32666,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32667,32667,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32667,32667,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);


--the name updates
update concept set concept_code = ltrim (concept_code, '0') where concept_code <> '0' and vocabulary_id = 'UB04 Typ bill';
update concept set concept_name = replace (concept_name, 'Hospital (non-hospital based)', 'Hospice (non-hospital based)') where  concept_name like 'Hospital (non-hospital based)%' and  vocabulary_id = 'UB04 Typ bill';
update concept set concept_name = 'Residential Facility' where   vocabulary_id = 'UB04 Typ bill' and  concept_code = '86';

--new class 'Permissible Range'
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Permissible Range';
    pConcept_class_name constant varchar(100):= 'Permissible Range';
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

--new relationship 'Has permiss range'
DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Has permissible range';
    pRelationship_id constant varchar(100):='Has permiss range';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='Permiss range of';
    
    pRelationship_name_rev constant varchar(100):='Permissible range of';
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
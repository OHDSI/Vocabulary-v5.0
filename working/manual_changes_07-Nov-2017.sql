--Add new relationship_id
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Has presentation strength denominator unit (SNOMED)';
    pRelationship_id constant varchar2(100):='Has denominator unit';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Denominator unit of';

    pRelationship_name_rev constant varchar2(100):='Presentation strength denominator unit of (SNOMED)';
    pIs_hierarchical_rev constant varchar2(100):='0';
    pDefines_ancestry_rev constant varchar2(100):= '0';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 571191 AND concept_id < 581479;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'ALTER TABLE relationship DISABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    
    --direct
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    EXECUTE IMMEDIATE 'ALTER TABLE relationship ENABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
/
--Add new relationship_id
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Has presentation strength denominator value (SNOMED)';
    pRelationship_id constant varchar2(100):='Has denomin value';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Denom value of';

    pRelationship_name_rev constant varchar2(100):='Presentation strength denominator value of (SNOMED)';
    pIs_hierarchical_rev constant varchar2(100):='0';
    pDefines_ancestry_rev constant varchar2(100):= '0';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 571191 AND concept_id < 581479;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'ALTER TABLE relationship DISABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    
    --direct
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    EXECUTE IMMEDIATE 'ALTER TABLE relationship ENABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
/
--add here
--Add new relationship_id
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Has presentation strength numerator unit (SNOMED)';
    pRelationship_id constant varchar2(100):='Has numerator unit';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Numerator unit of';

    pRelationship_name_rev constant varchar2(100):='Presentation strength numerator unit of (SNOMED)';
    pIs_hierarchical_rev constant varchar2(100):='0';
    pDefines_ancestry_rev constant varchar2(100):= '0';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 571191 AND concept_id < 581479;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'ALTER TABLE relationship DISABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    
    --direct
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    EXECUTE IMMEDIATE 'ALTER TABLE relationship ENABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
 /
--Add new relationship_id
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Has presentation strength numerator value (SNOMED)';
    pRelationship_id constant varchar2(100):='Has numerator value';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Numerator value of';

    pRelationship_name_rev constant varchar2(100):='Presentation strength numerator value of (SNOMED)';
    pIs_hierarchical_rev constant varchar2(100):='0';
    pDefines_ancestry_rev constant varchar2(100):= '0';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 571191 AND concept_id < 581479;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'ALTER TABLE relationship DISABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    
    --direct
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    EXECUTE IMMEDIATE 'ALTER TABLE relationship ENABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
 /
--Add new relationship_id
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='During (SNOMED)';
    pRelationship_id constant varchar2(100):='During';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Has complication';

    pRelationship_name_rev constant varchar2(100):='Has complication (SNOMED)';
    pIs_hierarchical_rev constant varchar2(100):='0';
    pDefines_ancestry_rev constant varchar2(100):= '0';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 571191 AND concept_id < 581479;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'ALTER TABLE relationship DISABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    
    --direct
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    EXECUTE IMMEDIATE 'ALTER TABLE relationship ENABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
/ 


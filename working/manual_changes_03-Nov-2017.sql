 --MANUAL CHANGES RELATIONSHIP
update concept set standard_concept = 'S' where concept_id in (581411, 581410)
;
DELETE from relationship where RELATIONSHIP_CONCEPT_ID in (581411, 581410)
;
update vocabulary set vocabulary_name = 'AllOfUs_PPI' where vocabulary_id = 'PPI'
;
--Add new relationship_id 'Topic of' and reverse 'Has topic'
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Topic of';
    pRelationship_id constant varchar2(100):='Topic of';
    pIs_hierarchical constant varchar2(100):='1';
    pDefines_ancestry constant varchar2(100):= '1';
    pReverse_relationship_id constant varchar2(100):='Has Topic';

    pRelationship_name_rev constant varchar2(100):='Has Topic';
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
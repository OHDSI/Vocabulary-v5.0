-------------------------------------------------------------------
--SNOMED relationship hieararchy definitions changes
-------------------------------------------------------------------
update relationship set is_hierarchical=0, defines_ancestry=0 where 'Inheres in' in (relationship_id,reverse_relationship_id);
update relationship set is_hierarchical=0, defines_ancestry=0 where 'Has direct site' in (relationship_id,reverse_relationship_id);
update relationship set is_hierarchical=0, defines_ancestry=0 where 'Has precondition' in (relationship_id,reverse_relationship_id);
update relationship set is_hierarchical=0, defines_ancestry=0 where 'Has inherent loc' in (relationship_id,reverse_relationship_id);
update relationship set is_hierarchical=0, defines_ancestry=0 where 'Has technique' in (relationship_id,reverse_relationship_id);
update relationship set is_hierarchical=0, defines_ancestry=0 where 'Has relative part' in (relationship_id,reverse_relationship_id);
update relationship set is_hierarchical=0, defines_ancestry=0 where 'Has process output' in (relationship_id,reverse_relationship_id);
update relationship set is_hierarchical=0, defines_ancestry=0 where 'Characterizes' in (relationship_id,reverse_relationship_id);

-------------------------------------------------------------------
--PPI new Concept_class_ids, relationship_id, Type concepts, vocabulary_id
-------------------------------------------------------------------
--Add new vocabulary
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='PPI';
    pVocabulary_name constant varchar2(100):= 'PPI';
    pVocabulary_reference constant varchar2(100):='http://terminology.pmi-ops.org/CodeSystem/ppi';
    pVocabulary_version constant varchar2(100):='Codebook Version 0.2.59';
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
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pVocabulary_name, 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
      VALUES (pVocabulary_id, pVocabulary_name, pVocabulary_reference, pVocabulary_version, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--Add new concept
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Procedure Recorded from a Survey';
    pDomain_id constant varchar2(100):='Type Concept';
    pVocabulary_id constant varchar2(100):='Procedure Type';
    pConcept_class_id constant varchar2(100):='Procedure Type';
    pStandard_concept constant varchar2(100):='S';
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
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_name, pDomain_id, pVocabulary_id, pConcept_class_id, pStandard_concept, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Observation from Measurement';
    pDomain_id constant varchar2(100):='Type Concept';
    pVocabulary_id constant varchar2(100):='Observation Type';
    pConcept_class_id constant varchar2(100):='Observation Type';
    pStandard_concept constant varchar2(100):='S';
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
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_name, pDomain_id, pVocabulary_id, pConcept_class_id, pStandard_concept, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--Add new relationship_id
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Module of';
    pRelationship_id constant varchar2(100):='Module of';
    pIs_hierarchical constant varchar2(100):='1';
    pDefines_ancestry constant varchar2(100):= '1';
    pReverse_relationship_id constant varchar2(100):='Has Module';

    pRelationship_name_rev constant varchar2(100):='Has Module';
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

DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Observation to Measurement';
    pRelationship_id constant varchar2(100):='Observation to Meas';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Meas to Observation';

    pRelationship_name_rev constant varchar2(100):='Measurement to Observation';
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
  
--Add new concept_class_id
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='Topic';
    pConcept_class_name constant varchar2(100):= 'Topic';
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
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='Module';
    pConcept_class_name constant varchar2(100):= 'Module';
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
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;


DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='PPI Modifier';
    pConcept_class_name constant varchar2(100):= 'PPI Modifier';
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
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
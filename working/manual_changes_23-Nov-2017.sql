--Add new vocabulary 'ICD-O-3'
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='ICDO3';
    pVocabulary_name constant varchar2(100):= 'ICD-O-3';
    pVocabulary_reference constant varchar2(100):='https://seer.cancer.gov/icd-o-3/'; -- also  http://apps.who.int/classifications/apps/icd/ClassificationDownload/DLArea/ICD-O-3_CSV-metadata.zip
    pVocabulary_version constant varchar2(100):='ICD-O-3 SEER Site/Histology Released 09/18/2015';
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
/
--new relationships
--Add new relationship_id
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Has Histology ICDO';
    pRelationship_id constant varchar2(100):='Has Histology ICDO';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Histology of ICDO';

    pRelationship_name_rev constant varchar2(100):='Histology of ICDO';
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
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Has Topography ICDO';
    pRelationship_id constant varchar2(100):='Has Topography ICDO';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Topography of ICDO';

    pRelationship_name_rev constant varchar2(100):='Topography of ICDO';
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
--ICD-O - SNOMED
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='ICDO - SNOMED';
    pRelationship_id constant varchar2(100):='ICDO - SNOMED';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='SNOMED - ICDO';

    pRelationship_name_rev constant varchar2(100):='SNOMED - ICDO';
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
--add new classes
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ICDO Topography';
    pConcept_class_name constant varchar2(100):= 'ICDO Topography';
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
/
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ICDO Histology';
    pConcept_class_name constant varchar2(100):= 'ICDO Histology';
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
/
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ICDO Condition';
    pConcept_class_name constant varchar2(100):= 'ICDO Condition';
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
/



--2. PPI
--Add new relatinship concept
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Parent to Child Measurement';
    pDomain_id constant varchar2(100):='Metadata';
    pVocabulary_id constant varchar2(100):='Relationship';
    pConcept_class_id constant varchar2(100):='Relationship';
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
/
--Add new relatinship concept (reverse)
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Child to Parent Measurement';
    pDomain_id constant varchar2(100):='Metadata';
    pVocabulary_id constant varchar2(100):='Relationship';
    pConcept_class_id constant varchar2(100):='Relationship';
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

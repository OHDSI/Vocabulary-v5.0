--Add new vocabulary 'ISBT'
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='ISBT';
    pVocabulary_name constant varchar2(100):= 'ISBT 128 Product Description Code Database';
    pVocabulary_reference constant varchar2(200):='http://www.iccbba.org/tech-library/iccbba-documents/databases-and-reference-tables/product-description-codes-database2';
    pVocabulary_version constant varchar2(100):='7.9.0';
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

--Add new vocabulary 'ISBT Attribute'
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='ISBT Attribute';
    pVocabulary_name constant varchar2(100):= 'ISBT 128 Product Description Code Database';
    pVocabulary_reference constant varchar2(200):='http://www.iccbba.org/tech-library/iccbba-documents/databases-and-reference-tables/product-description-codes-database2';
    pVocabulary_version constant varchar2(100):='7.9.0';
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

--Add new concept_class_id 'ISBT Product'
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ISBT Product';
    pConcept_class_name constant varchar2(100):= 'ISBT Product';
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

--Add new concept_class_id 'ISBT Class'
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ISBT Class';
    pConcept_class_name constant varchar2(100):= 'ISBT Class';
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

--Add new concept_class_id 'ISBT Modifier'
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ISBT Modifier';
    pConcept_class_name constant varchar2(100):= 'ISBT Modifier';
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

--Add new concept_class_id 'ISBT Attrib value'
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ISBT Attrib value';
    pConcept_class_name constant varchar2(100):= 'ISBT Attrib value';
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

--Add new concept_class_id 'ISBT Attrib group'
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ISBT Attrib group';
    pConcept_class_name constant varchar2(100):= 'ISBT Attrib group';
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

--Add new concept_class_id 'ISBT Attrib cat'
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ISBT Attrib cat';
    pConcept_class_name constant varchar2(100):= 'ISBT Attrib cat';
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

--Add new concept_class_id 'ISBT Category'
DECLARE
    z    number;
    ex   number;
    pConcept_class_id constant varchar2(100):='ISBT Category';
    pConcept_class_name constant varchar2(100):= 'ISBT Category';
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
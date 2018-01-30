--Add new concept=Pharmacy visit (https://github.com/OHDSI/Vocabulary-v5.0/issues/149)
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Pharmacy visit';
    pDomain_id constant varchar2(100):='Visit';
    pVocabulary_id constant varchar2(100):='Visit';
    pConcept_class_id constant varchar2(100):='Visit';
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
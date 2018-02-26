--update of 'Place of Service'
--fix concept codes
update concept set concept_code='0'||concept_code where vocabulary_id='Place of Service' and concept_code in ('1','3','4','5','6','7','8','9');

--fix domains
update concept set domain_id='Visit' where vocabulary_id='Place of Service';

--deprecate old mappings from PoS to Visit
update concept_relationship set invalid_reason='D', valid_end_date=trunc(sysdate) 
where rowid in 
(
    select r.rowid From concept c1, concept c2, concept_relationship r
    where c1.concept_id=r.concept_id_1
    and c2.concept_id=r.concept_id_2
    and 'Place of Service' in (c1.vocabulary_id, c2.vocabulary_id)
    and relationship_id in ('PoS - Visit cat','Visit cat - PoS')
    and r.invalid_reason is null
);
commit;

--add new PoS concept and mapping for him
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Place of Employment-Worksite';
    pDomain_id constant varchar2(100):='Visit';
    pVocabulary_id constant varchar2(100):='Place of Service';
    pConcept_class_id constant varchar2(100):='Place of Service';
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
      VALUES (z, pConcept_name, pDomain_id, pVocabulary_id, pConcept_class_id, pStandard_concept, '18', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    INSERT INTO concept_relationship VALUES (z,z, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_relationship VALUES (z,z, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--add new Visit concepts and mappings for these
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Home Visit';
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

    INSERT INTO concept_relationship VALUES (z,z, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_relationship VALUES (z,z, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Office Visit';
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

    INSERT INTO concept_relationship VALUES (z,z, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_relationship VALUES (z,z, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Ambulance Visit';
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

    INSERT INTO concept_relationship VALUES (z,z, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_relationship VALUES (z,z, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Rehabilitation Visit';
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

    INSERT INTO concept_relationship VALUES (z,z, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_relationship VALUES (z,z, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Laboratory Visit';
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
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_name, pDomain_id, pVocabulary_id, pConcept_class_id, pStandard_concept, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    INSERT INTO concept_relationship VALUES (z,z, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_relationship VALUES (z,z, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
DECLARE
    z    number;
    ex   number;
    pConcept_name constant varchar2(100):= 'Intensive Care';
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
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_name, pDomain_id, pVocabulary_id, pConcept_class_id, pStandard_concept, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    INSERT INTO concept_relationship VALUES (z,z, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_relationship VALUES (z,z, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--add new relationships: PoS 'Is a' Visit 'Is a' Visit
BEGIN
    insert into concept_relationship values (8562,581458, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581458,8562, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8537,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8537, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,581476, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (8672,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8672, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8968,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8968, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8969,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8969, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8941,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8941, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8960,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8960, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (38003619,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,38003619, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8940,581477, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,8940, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,581477, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8536,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8536, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8615,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8615, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8851,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8851, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8584,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8584, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8602,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8602, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (38003620,581477, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,38003620, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581475,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,581475, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (5084,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,5084, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8782,581477, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,8782, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8717,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,8717, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8756,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8756, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8870,9203, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9203,8870, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8883,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8883, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8650,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8650, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8905,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8905, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8970,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,8970, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8970,42898160, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (42898160,8970, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8892,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,8892, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8863,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,8863, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8676,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8676, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8827,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8827, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8546,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8546, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8882,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8882, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8668,581478, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581478,8668, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581478,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,581478, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8850,581478, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581478,8850, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (8716,581477, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,8716, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8966,581477, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,8966, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8971,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,8971, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8913,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8913, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8964,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8964, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8951,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8951, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8957,581476, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581476,8957, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8976,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8976, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (8974,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8974, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8858,581477, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,8858, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8920,581479, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581479,8920, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8920,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,8920, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8947,581479, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581479,8947, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8947,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8947, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8949,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8949, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8977,581477, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,8977, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8761,581477, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (581477,8761, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8809,32036, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32036,8809, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (32036,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,32036, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (8677,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,8677, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581379,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,581379, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581379,32037, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32037,581379, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581380,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,581380, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581380,32037, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32037,581380, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581381,9203, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9203,581381, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581381,32037, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32037,581381, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581382,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,581382, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581382,32037, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32037,581382, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581383,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,581383, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581383,32037, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32037,581383, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581384,9201, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9201,581384, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581385,9202, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (9202,581385, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    
    insert into concept_relationship values (581399,5083, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (5083,581399, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
END;
COMMIT;
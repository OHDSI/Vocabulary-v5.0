--Add UB404 concepts and relationships (AVOF-851)

--Add new concept_class_id
DECLARE
    z    number;
    ex   number;
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
    
    FOR C IN (
        SELECT concept_class_id FROM dev_test.new_codes
        MINUS
        SELECT concept_class_id FROM concept_class 
    ) LOOP
        EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

        INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
          VALUES (z, c.concept_class_id, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
        INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
          VALUES (c.concept_class_id, c.concept_class_id, z);
    END LOOP;
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--Add new vocabulary 'UB04 Typ bill'
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='UB04 Typ bill';
    pVocabulary_name constant varchar2(100):= 'UB04 Typ bill';
    pVocabulary_reference constant varchar2(100):='https://ushik.ahrq.gov/ViewItemDetails?&system=apcd&itemKey=196987000';
    pVocabulary_version constant varchar2(100):=null;
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
      VALUES (z, pVocabulary_name, 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
      VALUES (pVocabulary_id, pVocabulary_name, pVocabulary_reference, pVocabulary_version, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--Add new vocabulary 'UB04 Point of Origin'
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='UB04 Point of Origin';
    pVocabulary_name constant varchar2(100):= 'UB04 Point of Origin';
    pVocabulary_reference constant varchar2(100):='https://www.resdac.org/cms-data/variables/Claim-Source-Inpatient-Admission-Code';
    pVocabulary_version constant varchar2(100):=null;
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
      VALUES (z, pVocabulary_name, 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
      VALUES (pVocabulary_id, pVocabulary_name, pVocabulary_reference, pVocabulary_version, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--Add new vocabulary 'UB04 Pri Typ of Adm'
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='UB04 Pri Typ of Adm';
    pVocabulary_name constant varchar2(100):= 'UB04 Pri Typ of Adm';
    pVocabulary_reference constant varchar2(100):='https://www.resdac.org/cms-data/variables/Claim-Inpatient-Admission-Type-Code';
    pVocabulary_version constant varchar2(100):=null;
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
      VALUES (z, pVocabulary_name, 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
      VALUES (pVocabulary_id, pVocabulary_name, pVocabulary_reference, pVocabulary_version, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--Add new vocabulary 'UB04 Pt dis status'
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='UB04 Pt dis status';
    pVocabulary_name constant varchar2(100):= 'UB04 Pt dis status';
    pVocabulary_reference constant varchar2(100):='https://www.resdac.org/cms-data/variables/patient-discharge-status-code';
    pVocabulary_version constant varchar2(100):=null;
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
      VALUES (z, pVocabulary_name, 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
      VALUES (pVocabulary_id, pVocabulary_name, pVocabulary_reference, pVocabulary_version, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--Add new codes
/*
CREATE TABLE new_codes
(
    domain_id           VARCHAR2 (20),
    vocabulary_id       VARCHAR2 (20),
    concept_class_id    VARCHAR2 (20),
    concept_code        VARCHAR2 (50),
    concept_name        VARCHAR2 (255),
    standard_concept    VARCHAR2 (1)
);
*/
DECLARE
    z    number;
    ex   number;
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

    FOR c in (SELECT * FROM dev_test.new_codes) LOOP
        EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
        INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
          VALUES (z, c.concept_name, c.domain_id, c.vocabulary_id, c.concept_class_id, c.standard_concept, c.concept_code, TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
        IF c.standard_concept='S' THEN
            INSERT INTO concept_relationship VALUES (z,z, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
            INSERT INTO concept_relationship VALUES (z,z, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
        END IF;
    END LOOP;

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;

--Add new relationship_id
DECLARE
    z    number;
    ex   number;
    pRelationship_name constant varchar2(100):='Typ bill Full to Frequency code (UB04)';
    pRelationship_id constant varchar2(100):='Typ bill - Freq Code';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Freq Code - Typ bill';

    pRelationship_name_rev constant varchar2(100):='Frequency code to Typ bill Full (UB04)';
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
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
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
    pRelationship_name constant varchar2(100):='Typ bill Full to Typ bill 3 digits (UB04)';
    pRelationship_id constant varchar2(100):='Typ bill - Typ bill3';
    pIs_hierarchical constant varchar2(100):='0';
    pDefines_ancestry constant varchar2(100):= '0';
    pReverse_relationship_id constant varchar2(100):='Typ bill3 - Typ bill';

    pRelationship_name_rev constant varchar2(100):='Typ bill 3 digits to Typ bill Full (UB04)';
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
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
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

--Add 'Maps to' relationships between UB04 and PoS
insert into concept_relationship
with t as (
    select c1.concept_id as typeofbill_id, c.concept_id as pos_id, to_date ('19700101', 'YYYYMMDD') as valid_start_date, to_date ('20991231', 'YYYYMMDD') as valid_end_date
    from dev_test.new_mappings m
    join concept c on c.concept_code=m.pos and c.vocabulary_id='Place of Service'
    join concept c1 on c1.concept_code like '0'||substr(m.typeofbill,1,2)||'%' and c1.vocabulary_id='UB04 Typ bill' and c1.concept_class_id='Full'
)
select typeofbill_id, pos_id, 'Maps to', valid_start_date,  valid_end_date, null from t
union all
select pos_id, typeofbill_id, 'Mapped from', valid_start_date,  valid_end_date, null from t;

--Add 'Typ bill3 - Typ bill' relationships between Typ bill 3 digits and Typ bill Full
insert into concept_relationship
with t as (
    select c.concept_id as type3_id, c1.concept_id as full_id, to_date ('19700101', 'YYYYMMDD') as valid_start_date, to_date ('20991231', 'YYYYMMDD') as valid_end_date
    from concept c
    join concept c1 on c1.concept_code like c.concept_code||'%' and c1.vocabulary_id=c.vocabulary_id and c1.concept_class_id='Full'
    where c.vocabulary_id='UB04 Typ bill' and c.concept_class_id='Typ bill 3 digits'
)
select type3_id, full_id, 'Typ bill3 - Typ bill', valid_start_date,  valid_end_date, null from t
union all
select full_id, type3_id, 'Typ bill - Typ bill3', valid_start_date,  valid_end_date, null from t;

--Add 'Typ bill - Freq Code' relationships between Typ bill Full and Frequency code
insert into concept_relationship
with t as (
    select c.concept_id as full_id, c1.concept_id as freq_id, to_date ('19700101', 'YYYYMMDD') as valid_start_date, to_date ('20991231', 'YYYYMMDD') as valid_end_date
    from concept c
    join concept c1 on c1.concept_code = substr(c.concept_code,-1) and c1.vocabulary_id=c.vocabulary_id and c1.concept_class_id='Frequency code'
    where c.vocabulary_id='UB04 Typ bill' and c.concept_class_id='Full'
)
select full_id, freq_id, 'Typ bill - Freq Code', valid_start_date,  valid_end_date, null from t
union all
select freq_id, full_id, 'Freq Code - Typ bill', valid_start_date,  valid_end_date, null from t;

INSERT INTO vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req)
   SELECT ROWNUM + (SELECT MAX (vocabulary_id_v4) FROM vocabulary_conversion)
             AS rn,
          vocabulary_id, 'Y' as omop_req
     FROM (SELECT vocabulary_id FROM VOCABULARY
           MINUS
           SELECT vocabulary_id_v5 FROM vocabulary_conversion);
COMMIT;


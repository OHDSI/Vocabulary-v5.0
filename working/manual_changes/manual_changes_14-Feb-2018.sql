--set proper name: 'Million unit per liter' -> 'Million unit per milliliter'
update concept set concept_name='Million unit per milliliter' where concept_Id=45890995;
commit;


--Add new concepts (batch-version): https://github.com/OHDSI/Vocabulary-v5.0/issues/160 and https://github.com/OHDSI/Vocabulary-v5.0/issues/156 (AVOF-835)
/*
EHR billing diagnosis	Type Concept	Condition Type	Condition Type	S	OMOP generated	19700101	20991231
EHR encounter diagnosis	Type Concept	Condition Type	Condition Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical claim	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on pharmacy claim	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical facility claim	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical professional claim	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical facility claim paid	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical facility claim denied	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical facility claim deferred	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical professional claim paid	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical professional claim denied	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on medical professional claim deferred	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on claim authorization	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on vision claim	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from encounter on dental claim	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from EHR billing record	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231
Visit derived from EHR encounter record	Type Concept	Visit Type	Visit Type	S	OMOP generated	19700101	20991231

*/
/*
CREATE TABLE new_manual_concepts
(
    CONCEPT_NAME        VARCHAR2 (256 BYTE) NOT NULL,
    DOMAIN_ID           VARCHAR2 (200 BYTE) NOT NULL,
    VOCABULARY_ID       VARCHAR2 (20 BYTE) NOT NULL,
    CONCEPT_CLASS_ID    VARCHAR2 (20 BYTE) NOT NULL,
    STANDARD_CONCEPT    VARCHAR2 (1 BYTE),
    CONCEPT_CODE        VARCHAR2 (50 BYTE) NOT NULL,
    VALID_START_DATE    DATE NOT NULL,
    VALID_END_DATE      DATE NOT NULL,
    INVALID_REASON      VARCHAR2 (1 BYTE)
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

    FOR c in (SELECT * FROM devv5.new_manual_concepts) LOOP
        EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
        INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
          VALUES (z, c.concept_name, c.domain_id, c.vocabulary_id, c.concept_class_id, c.standard_concept, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    END LOOP;

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    /*DROP TABLE new_manual_concepts;*/
END;

--new relationships between these concepts
begin
    insert into concept_relationship values (32021,44818517, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (44818517,32021, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32022,32021, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32021,32022, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32023,32021, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32021,32023, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32024,32021, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32021,32024, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32025,32023, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32023,32025, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32026,32023, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32023,32026, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32027,32023, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32023,32027, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32028,32024, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32024,32028, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32029,32024, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32024,32029, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32030,32024, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (32024,32030, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32031,44818517, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (44818517,32031, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32032,44818517, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (44818517,32032, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32033,44818517, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (44818517,32033, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32034,44818518, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (44818518,32034, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

    insert into concept_relationship values (32035,44818518, 'Is a',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    insert into concept_relationship values (44818518,32035, 'Subsumes',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
end;
commit;
https://github.com/OHDSI/Vocabulary-v5.0/issues/245#issuecomment-528880225
insert into concept_relationship values(32693,8756,'Is a',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(8756,32693,'Subsumes',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);

--Add new concept_class_id='KCD7 code'
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='KCD7 code';
    pConcept_class_name constant varchar(100):= 'KCD7 code';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$; 
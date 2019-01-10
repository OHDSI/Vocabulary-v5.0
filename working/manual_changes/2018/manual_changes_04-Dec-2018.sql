--https://github.com/OHDSI/OncologyWG/issues/12#event-1998241269
--Add new vocabulary_id='Episode'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Episode',
	pVocabulary_name		=> 'OMOP Episode',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> 'Y', --NULL or 'Y'
	pClick_default			=> 'Y', --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;

--Add new concept_class_id='Disease Episode'
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Disease Episode';
    pConcept_class_name constant varchar(100):= 'Disease Episode';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--Add new concept_class_id='Treatment Episode'
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Treatment Episode';
    pConcept_class_name constant varchar(100):= 'Treatment Episode';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--Add new concept_class_id='Episode of Care'
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Episode of Care';
    pConcept_class_name constant varchar(100):= 'Episode of Care';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--Add new domain_id='Episode'
DO $$
DECLARE
    z    int;
    ex   int;
    pDomain_id constant varchar(20):='Episode';
    pDomain_name constant varchar(255):= 'Episode';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pDomain_name, 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO domain (domain_id, domain_name, domain_concept_id)
      VALUES (pDomain_id, pDomain_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--Add concepts
INSERT INTO concept VALUES (32528,'Disease First Occurrence','Episode','Episode','Disease Episode','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL); 
INSERT INTO concept VALUES (32529,'Disease Recurrence','Episode','Episode','Disease Episode','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32530,'Disease Remission','Episode','Episode','Disease Episode','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32531,'Treatment Regimen','Episode','Episode','Treatment Episode','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32532,'Treatment Cycle','Episode','Episode','Treatment Episode','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32533,'Episode of Care','Episode','Episode','Episode of Care','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept_synonym VALUES (32528,'Disease First Occurrence',4180186);
INSERT INTO concept_synonym VALUES (32529,'Disease Recurrence',4180186);
INSERT INTO concept_synonym VALUES (32530,'Disease Remission',4180186);
INSERT INTO concept_synonym VALUES (32531,'Treatment Regimen',4180186);
INSERT INTO concept_synonym VALUES (32532,'Treatment Cycle',4180186);
INSERT INTO concept_synonym VALUES (32533,'Episode of Care',4180186);

--https://github.com/OHDSI/OncologyWG/issues/11
INSERT INTO concept VALUES (32534,'Tumor Registry','Type Concept','Meas Type','Meas Type','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32535,'Tumor Registry','Type Concept','Meas Type','Condition Type','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept_synonym VALUES (32534,'Tumor Registry',4180186);
INSERT INTO concept_synonym VALUES (32535,'Tumor Registry',4180186);

--create 'Maps to'
WITH to_be_upserted AS (
    SELECT c.concept_id, c.valid_start_date, lat.relationship_id FROM concept c
    LEFT JOIN concept_relationship cr ON cr.concept_id_1=c.concept_id AND cr.concept_id_1=cr.concept_id_2 AND cr.relationship_id='Maps to' AND cr.invalid_reason IS NULL
    CROSS JOIN LATERAL (SELECT case when generate_series=1 then 'Maps to' ELSE 'Mapped from' END AS relationship_id FROM generate_series(1,2)) lat
    WHERE c.standard_concept='S' AND c.invalid_reason IS NULL AND cr.concept_id_1 IS NULL
),
to_be_updated AS (
    UPDATE concept_relationship cr
    SET invalid_reason = NULL, valid_end_date = TO_DATE ('20991231', 'yyyymmdd')
    FROM to_be_upserted up
    WHERE cr.invalid_reason IS NOT NULL
    AND cr.concept_id_1 = up.concept_id AND cr.concept_id_2 = up.concept_id AND cr.relationship_id = up.relationship_id
    RETURNING cr.*
)
    INSERT INTO concept_relationship
    SELECT tpu.concept_id, tpu.concept_id, tpu.relationship_id, tpu.valid_start_date, TO_DATE ('20991231', 'yyyymmdd'), NULL 
    FROM to_be_upserted tpu 
    WHERE (tpu.concept_id, tpu.concept_id, tpu.relationship_id) 
    NOT IN (
        SELECT up.concept_id_1, up.concept_id_2, up.relationship_id FROM to_be_updated up
        UNION ALL
        SELECT cr_int.concept_id_1, cr_int.concept_id_2, cr_int.relationship_id FROM concept_relationship cr_int 
        WHERE cr_int.concept_id_1=cr_int.concept_id_2 AND cr_int.relationship_id IN ('Maps to','Mapped from')
    );
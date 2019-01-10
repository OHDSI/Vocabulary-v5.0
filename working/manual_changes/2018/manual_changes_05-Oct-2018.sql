--Add vocabulary for Payer, Plan, Sponsor and Stop Reason [AVOF-1243]
--new vocabularies
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Plan',
	pVocabulary_name		=> 'Health Plan - contract to administer healthcare transactions by the payer, facilitated by the sponsor',
	pVocabulary_reference	=> null,
	pVocabulary_version		=> null,
	pOMOP_req				=> 'Y', --NULL or 'Y'
	pClick_default			=> 'Y', --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Sponsor',
	pVocabulary_name		=> 'Sponsor - institution or individual financing healthcare transactions',
	pVocabulary_reference	=> null,
	pVocabulary_version		=> null,
	pOMOP_req				=> 'Y', --NULL or 'Y'
	pClick_default			=> 'Y', --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'PHDSC',
	pVocabulary_name		=> 'Source of Payment Typology (PHDSC)',
	pVocabulary_reference	=> 'http://www.phdsc.org/standards/payer-typology-source.asp',
	pVocabulary_version		=> 'Version 3.0',
	pOMOP_req				=> 'Y', --NULL or 'Y'
	pClick_default			=> 'Y', --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Plan Stop Reason',
	pVocabulary_name		=> 'Plan Stop Reason - Reason for termination of the Health Plan',
	pVocabulary_reference	=> null,
	pVocabulary_version		=> null,
	pOMOP_req				=> 'Y', --NULL or 'Y'
	pClick_default			=> 'Y', --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;

--new domain_ids
DO $$
DECLARE
    z    int;
    ex   int;
    pDomain_id constant varchar(100):='Plan';
    pDomain_name constant varchar(200):= 'Health Plan - contract to administer healthcare transactions by the payer, facilitated by the sponsor';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pDomain_name, 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO domain (domain_id, domain_name, domain_concept_id)
      VALUES (pDomain_id, pDomain_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pDomain_id constant varchar(100):='Sponsor';
    pDomain_name constant varchar(100):= 'Sponsor - institution or individual financing healthcare transactions';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pDomain_name, 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO domain (domain_id, domain_name, domain_concept_id)
      VALUES (pDomain_id, pDomain_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pDomain_id constant varchar(100):='Payer';
    pDomain_name constant varchar(100):= 'Payer - institution administering healthcare transactions';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pDomain_name, 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO domain (domain_id, domain_name, domain_concept_id)
      VALUES (pDomain_id, pDomain_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pDomain_id constant varchar(100):='Plan Stop Reason';
    pDomain_name constant varchar(100):= 'Plan Stop Reason - Reason for termination of the Health Plan';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pDomain_name, 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO domain (domain_id, domain_name, domain_concept_id)
      VALUES (pDomain_id, pDomain_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--new concept_class_ids
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Payer';
    pConcept_class_name constant varchar(100):= 'Payer - institution administering healthcare transactions';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Sponsor';
    pConcept_class_name constant varchar(100):= 'Sponsor - institution or individual financing healthcare transactions';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;


DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Plan Stop Reason';
    pConcept_class_name constant varchar(100):= 'Plan Stop Reason - Reason for termination of the Health Plan';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Benefit';
    pConcept_class_name constant varchar(100):= 'Benefit - healthcare items or services covered under a Health Plan';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Metal level';
    pConcept_class_name constant varchar(100):= 'Metal level: ratio of split of the healthcare transaction costs between Health Plan and patient';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--select * From dev_test.concept_manual;
--clearing
update dev_test.concept_manual set concept_name=trim(concept_name) where concept_name<>trim(concept_name);
update dev_test.concept_manual set concept_code=trim(concept_code) where concept_code<>trim(concept_code);
update dev_test.concept_manual set domain_id=trim(domain_id) where domain_id<>trim(domain_id);
update dev_test.concept_manual set vocabulary_id=trim(vocabulary_id) where vocabulary_id<>trim(vocabulary_id);
update dev_test.concept_manual set concept_class_id=trim(concept_class_id) where concept_class_id<>trim(concept_class_id);
update dev_test.concept_manual set standard_concept=trim(standard_concept) where standard_concept<>trim(standard_concept);

--insert concepts
DO $$
DECLARE
    ex   int;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
    WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      SELECT nextval('v5_concept'), concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null from dev_test.concept_manual;

    DROP SEQUENCE v5_concept;
END $$;


--create/update 'Maps to' for all 'S' without 'Maps to'
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

--create 'Is a' relationships for 'PHDSC'
INSERT INTO concept_relationship
WITH t AS (
		SELECT c1.concept_id AS concept_id_1,
			c2.concept_id AS concept_id_2,
			TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
			TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
			NULL AS invalid_reason
		FROM concept c1
		JOIN concept c2 ON c2.vocabulary_id = c1.vocabulary_id
			AND c2.concept_code LIKE c1.concept_code || '%'
			AND length(c2.concept_code) - 1 = length(c1.concept_code)
		WHERE c1.vocabulary_id = 'PHDSC'
		)
SELECT concept_id_1,
	concept_id_2,
	'Subsumes' AS relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM t

UNION ALL

SELECT concept_id_2,
	concept_id_1,
	'Is a' AS relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM t;

CREATE OR REPLACE FUNCTION vocabulary_pack.AddNewVocabulary (
  pVocabulary_id vocabulary.vocabulary_id%TYPE,
  pVocabulary_name vocabulary.vocabulary_name%TYPE,
  pVocabulary_reference vocabulary.vocabulary_reference%TYPE,
  pVocabulary_version vocabulary.vocabulary_version%TYPE,
  pOMOP_req vocabulary_conversion.omop_req%TYPE,
  pClick_default vocabulary_conversion.click_default%TYPE,
  pAvailable vocabulary_conversion.available%TYPE,
  pURL vocabulary_conversion.url%TYPE,
  pClick_disabled vocabulary_conversion.click_disabled%TYPE,
  pSEQ_VIP_gen BOOLEAN = FALSE
)
RETURNS void AS
$BODY$
DECLARE
    z  INT;
    ex INT;
BEGIN
    IF COALESCE(pOMOP_req,'Y') <> 'Y' 
    THEN 
        RAISE EXCEPTION 'pOMOP_req must be NULL or Y'; 
    END IF;

    IF COALESCE(pClick_default,'Y') <> 'Y' 
    THEN 
        RAISE EXCEPTION 'pClick_default must be NULL or Y'; 
    END IF;
    
    IF COALESCE(pAvailable,'License required') NOT IN ('Currently not available','License required','EULA required') 
    THEN 
        RAISE EXCEPTION 'Incorrect value for pAvailable: %', pAvailable; 
    END IF;

    IF COALESCE(pClick_disabled,'Y') <> 'Y'
    THEN 
        RAISE EXCEPTION 'pClick_disabled must be NULL or Y';
    END IF;

    IF pURL IS NULL AND pAvailable = 'License required' 
    THEN 
        pURL := 'mailto:contact@ohdsi.org?subject=License%20required%20for%20' ||
                devv5.urlencode(pVocabulary_id) ||
                '&body=Describe%20your%20situation%20and%20your%20need%20for%20this%20vocabulary.';
    END IF;

    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 
      INTO ex 
      FROM concept
     WHERE (concept_id >= 200 
            AND concept_id < 1000 
            AND pSEQ_VIP_gen = TRUE) --only for VIP concepts
        OR (concept_id >= 31967 
            AND concept_id < 72245 
            AND pSEQ_VIP_gen = FALSE);
            
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';

    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (
        concept_id, 
        concept_name, 
        domain_id, 
        vocabulary_id, 
        concept_class_id, 
        standard_concept, 
        concept_code, 
        valid_start_date, 
        valid_end_date, 
        invalid_reason)
     VALUES (
        z,
        pVocabulary_name,
        'Metadata',
        'Vocabulary',
        'Vocabulary',
        NULL,
        'OMOP generated',
        TO_DATE ('19700101', 'YYYYMMDD'),
        TO_DATE ('20991231', 'YYYYMMDD'),
        NULL
    );

    INSERT INTO vocabulary (
        vocabulary_id, 
        vocabulary_name, 
        vocabulary_reference, 
        vocabulary_version, 
        vocabulary_concept_id
    )
    VALUES (
        pVocabulary_id, 
        pVocabulary_name, 
        pVocabulary_reference, 
        pVocabulary_version, 
        z);

    DROP SEQUENCE v5_concept;

    INSERT INTO vocabulary_conversion (
        vocabulary_id_v4, 
        vocabulary_id_v5, 
        omop_req, 
        click_default, 
        available, 
        url, 
        click_disabled
    )
    SELECT 
        -1, 
        pVocabulary_id, 
        pOMOP_req, 
        pClick_default, 
        pAvailable, 
        pURL, 
        pClick_disabled;
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
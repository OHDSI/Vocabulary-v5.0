--Add 2 new 'Meas Type' concepts
INSERT INTO concept VALUES (32488,'Urgent lab result','Type Concept','Meas Type','Meas Type','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL); 
INSERT INTO concept VALUES (32489,'Accelerated lab result','Type Concept','Meas Type','Meas Type','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept_synonym VALUES (32488,'Urgent lab result','4180186');
INSERT INTO concept_synonym VALUES (32489,'Accelerated lab result','4180186');

--duplicate all concepts in 'Death Type'->'Observation Type'
DO $$
DECLARE
    ex   int;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';

    INSERT INTO concept
    SELECT nextval('v5_concept'),
        concept_name,
        domain_id,
        'Observation Type',
        concept_class_id,
        standard_concept,
        concept_code,
        valid_start_date,
        valid_end_date,
        invalid_reason
    FROM dev_test.concept
    WHERE vocabulary_id = 'Death Type';

    DROP SEQUENCE v5_concept;
END $$;

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
--undeprecate wrongly deprecated old mappings
update concept_relationship set invalid_reason=null, valid_end_date=TO_DATE('20991231', 'YYYYMMDD') where concept_id_1=40141336 and concept_id_2=1544872 and relationship_id='Maps to' and invalid_reason is not null;
update concept_relationship set invalid_reason=null, valid_end_date=TO_DATE('20991231', 'YYYYMMDD') where concept_id_1=1544872 and concept_id_2=40141336 and relationship_id='Mapped from' and invalid_reason is not null;
update concept_relationship set invalid_reason=null, valid_end_date=TO_DATE('20991231', 'YYYYMMDD') where concept_id_1=40141048 and concept_id_2=1516980 and relationship_id='Maps to' and invalid_reason is not null;
update concept_relationship set invalid_reason=null, valid_end_date=TO_DATE('20991231', 'YYYYMMDD') where concept_id_1=1516980 and concept_id_2=40141048 and relationship_id='Mapped from' and invalid_reason is not null;

--add 4 Type Concepts
INSERT INTO concept VALUES (32423,  'NLP derived',  'Type Concept',  'Meas Type',  'Meas Type',  'S',  'OMOP generated',  to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),  NULL);
INSERT INTO concept VALUES (32424,  'NLP derived',  'Type Concept',  'Condition Type',  'Condition Type',  'S',  'OMOP generated', to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),  NULL);
INSERT INTO concept VALUES (32425,  'NLP derived',  'Type Concept',  'Procedure Type',  'Procedure Type',  'S',  'OMOP generated',  to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),  NULL);
INSERT INTO concept VALUES (32426,  'NLP derived',  'Type Concept',  'Drug Type',  'Drug Type',  'S',  'OMOP generated',  to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),  NULL);

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
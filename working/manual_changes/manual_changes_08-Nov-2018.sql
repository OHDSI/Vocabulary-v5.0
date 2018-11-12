--https://github.com/OHDSI/Vocabulary-v5.0/issues/190
--rename 3 Cost Type
update concept set concept_name='Payer system (Primary payer)', concept_class_id='Cost Type' where concept_id=31968;
update concept_synonym set concept_synonym_name='Payer system (Primary payer)' where concept_id=31968;

update concept set concept_name='Payer system (Secondary payer)', concept_class_id='Cost Type' where concept_id=31969;
update concept_synonym set concept_synonym_name='Payer system (Secondary payer)' where concept_id=31969;

update concept set concept_name='Payer system (Paid premium)', concept_class_id='Cost Type' where concept_id=31970;
update concept_synonym set concept_synonym_name='Payer system (Paid premium)' where concept_id=31970;

--add 2 new Cost Type
INSERT INTO concept VALUES (32504,'Person (self) reported','Type Concept','Cost Type','Cost Type','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL); 
INSERT INTO concept VALUES (32505,'Provider System','Type Concept','Cost Type','Cost Type','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
insert into concept_synonym values
(32504,'Person (self) reported',4180186),
(32505,'Provider System',4180186);

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


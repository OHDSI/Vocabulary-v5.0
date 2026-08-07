DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(REPLACE(concept_code, 'OMOP','')::int4)+1 INTO ex FROM (
		SELECT concept_code FROM concept WHERE concept_code LIKE 'OMOP%'  AND concept_code NOT LIKE '% %' -- Last valid value of the OMOP123-type codes
			) AS s0;
	DROP SEQUENCE IF EXISTS omop_seq;
	EXECUTE 'CREATE SEQUENCE omop_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;

TRUNCATE TABLE concept_manual;
INSERT INTO concept_manual
(concept_name,
 domain_id,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 valid_start_date,
 valid_end_date,
 invalid_reason)
SELECT vocabulary_pack.CutConceptName (trim(concept_name)),
       'Measurement',
       'Cancer Modifier',
       concept_class_id,
       'S',
       'OMOP' || nextval('omop_seq'),
        current_date,
        TO_DATE('20991231', 'yyyymmdd'),
        NULL
FROM dev_christian.modifiers;
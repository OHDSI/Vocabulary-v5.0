-- Create sequence for new OMOP-created standard concepts
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM devv5.concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %'; -- Last valid value of the OMOP123-type codes
	DROP SEQUENCE IF EXISTS new_voc;
	EXECUTE 'CREATE SEQUENCE new_voc INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;
DELETE
FROM relationship_to_concept
WHERE concept_code_1 = '33386-4'
	AND concept_id_2 = 1326378
	AND precedence = 2;

DELETE
FROM relationship_to_concept
WHERE concept_code_1 = '00758-2'
	AND concept_id_2 = 975125
	AND precedence = 2;

UPDATE drug_concept_stage
SET concept_class_id = 'Drug Product'
WHERE concept_class_id LIKE 'Drug%';

UPDATE drug_concept_stage
SET concept_class_id = 'Supplier'
WHERE concept_class_id = 'Manufacturer';


UPDATE drug_concept_stage
SET standard_concept = NULL
WHERE concept_code IN (
		SELECT a.concept_code_1
		FROM internal_relationship_Stage a
		JOIN drug_concept_stage b ON a.concept_code_1 = b.concept_code
		JOIN drug_concept_stage c ON a.concept_code_2 = c.concept_code
		WHERE c.concept_class_id = 'Ingredient'
			AND b.concept_class_id = 'Ingredient'
		);

UPDATE drug_concept_stage
SET standard_concept = NULL
WHERE concept_class_id LIKE 'Drug%';

ALTER TABLE drug_concept_stage ADD COLUMN source_concept_class_id VARCHAR(20);

-- Create sequence for new OMOP-created standard concepts
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM devv5.concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %'; -- Last valid value of the OMOP123-type codes
	DROP SEQUENCE IF EXISTS new_vocab;
	EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;

-- change to procedure in the future
DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT 'OMOP' || nextval('new_vocab') AS new_code,
	concept_code AS old_code
FROM (
	SELECT concept_code
	FROM drug_concept_stage
	WHERE concept_code LIKE 'OMOP%'
	GROUP BY concept_code
	ORDER BY LPAD(concept_code, 50, '0')
	) AS s0;

UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;
--select * from code_replace where old_code ='OMOP28663';

UPDATE relationship_to_concept a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE ds_stage a
SET ingredient_concept_code = b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code;

UPDATE ds_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_2 = b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code;

UPDATE pc_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;


DELETE
FROM relationship_to_concept
WHERE concept_code_1 = 'microg'
	AND concept_id_2 = 9655
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_code_1 = 'microl'
	AND concept_id_2 = 9665
	AND precedence = 2;

DELETE
FROM relationship_to_concept
WHERE concept_code_1 = 'micromol'
	AND concept_id_2 = 9667
	AND precedence = 2;

UPDATE relationship_to_concept
SET precedence = 1
WHERE concept_code_1 = 'M'
	AND concept_id_2 = 8510
	AND precedence = 2;

UPDATE relationship_to_concept
SET precedence = 1
WHERE concept_code_1 = 'microg'
	AND concept_id_2 = 8576
	AND precedence = 2;

UPDATE relationship_to_concept
SET conversion_factor = 1000000
WHERE concept_code_1 = 'million cells'
	AND concept_id_2 = 45744812
	AND precedence = 1;

UPDATE relationship_to_concept
SET concept_id_2 = 8576,
	conversion_factor = 0.000001
WHERE concept_code_1 = 'ng'
	AND concept_id_2 = 9600
	AND precedence = 1;

UPDATE relationship_to_concept
SET concept_id_2 = 8576,
	conversion_factor = 1e-9
WHERE concept_code_1 = 'pg'
	AND concept_id_2 = 8564
	AND precedence = 1;

UPDATE relationship_to_concept
SET concept_id_2 = 45744812
WHERE concept_code_1 = 'megmo';

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'AMIS',
	pVocabularyDate			=> TO_DATE ('20161029', 'yyyymmdd'),
	pVocabularyVersion		=> 'AMIS 20161029',
	pVocabularyDevSchema	=> 'DEV_AMIS'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> TO_DATE ('20161029', 'yyyymmdd'),
	pVocabularyVersion		=> 'RxNorm Extension 20161029',
	pVocabularyDevSchema	=> 'DEV_AMIS',
	pAppendVocabulary		=> TRUE
);
END $_$;
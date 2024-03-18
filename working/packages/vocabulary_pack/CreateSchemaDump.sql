CREATE OR REPLACE FUNCTION vocabulary_pack.CreateSchemaDump (pSchemaName TEXT)
RETURNS VOID AS
$BODY$
	/*
	Creates text (csv) dump for concept, concept_relationship, relationship, concept_synonym, concept_ancestor, domain, drug_strength, concept_class, vocabulary, vocabulary_conversion in specified schema
	Usage:
	1. Connect as devv5
	2. Run SELECT vocabulary_pack.CreateSchemaDump ('dev_test');
	3. Compressed files will be created in the specified location (see iExportPath below) inside folder named as vocabulary.vocabulary_version WHERE vocabulary_id = 'None'
	*/
DECLARE
	iExportPath TEXT:='/data/vocab_dump/custom_dump/';
	iVocabVersion TEXT;
BEGIN
	PERFORM SET_CONFIG('search_path', pSchemaName, TRUE);
	
	SELECT RIGHT(vocabulary_version,-5) INTO iVocabVersion FROM vocabulary WHERE vocabulary_id = 'None';
	iExportPath:=iExportPath || iVocabVersion;

	EXECUTE FORMAT ($$
		COPY (
			SELECT vocabulary_id,
				vocabulary_name,
				vocabulary_reference,
				vocabulary_version,
				vocabulary_concept_id
			FROM vocabulary
		) TO PROGRAM 'mkdir -p %1$s && gzip -2 > %1$s/vocabulary.csv.gz' CSV HEADER;

		COPY (
			SELECT concept_id,
				concept_name,
				domain_id,
				vocabulary_id,
				concept_class_id,
				standard_concept,
				concept_code,
				TO_CHAR(valid_start_date, 'DD-MON-YYYY') valid_start_date,
				TO_CHAR(valid_end_date, 'DD-MON-YYYY') valid_end_date,
				invalid_reason
			FROM concept
		) TO PROGRAM 'gzip -2 > %1$s/concept.csv.gz' CSV HEADER;

		COPY (
			SELECT concept_id_1,
				concept_id_2,
				relationship_id,
				TO_CHAR(valid_start_date, 'DD-MON-YYYY') valid_start_date,
				TO_CHAR(valid_end_date, 'DD-MON-YYYY') valid_end_date,
				invalid_reason
			FROM concept_relationship
			WHERE invalid_reason IS NULL
		) TO PROGRAM 'gzip -2 > %1$s/concept_relationship.csv.gz' CSV HEADER;

		COPY relationship TO PROGRAM 'gzip -2 > %1$s/relationship.csv.gz' CSV HEADER;
		COPY concept_synonym TO PROGRAM 'gzip -2 > %1$s/concept_synonym.csv.gz' CSV HEADER;
		COPY concept_ancestor TO PROGRAM 'gzip -2 > %1$s/concept_ancestor.csv.gz' CSV HEADER;
		COPY domain TO PROGRAM 'gzip -2 > %1$s/domain.csv.gz' CSV HEADER;

		COPY (
			SELECT drug_concept_id,
				ingredient_concept_id,
				amount_value,
				amount_unit_concept_id,
				numerator_value,
				numerator_unit_concept_id,
				denominator_value,
				denominator_unit_concept_id,
				box_size,
				TO_CHAR(valid_start_date, 'DD-MON-YYYY') valid_start_date,
				TO_CHAR(valid_end_date, 'DD-MON-YYYY') valid_end_date,
				invalid_reason
			FROM drug_strength
		) TO PROGRAM 'gzip -2 > %1$s/drug_strength.csv.gz' CSV HEADER;

		COPY concept_class TO PROGRAM 'gzip -2 > %1$s/concept_class.csv.gz' CSV HEADER;

		COPY (
			SELECT vocabulary_id_v4,
				vocabulary_id_v5,
				omop_req,
				click_default,
				available,
				url,
				click_disabled,
				TO_CHAR(latest_update, 'DD-MON-YYYY') latest_update
			FROM vocabulary_conversion
		) TO PROGRAM 'gzip -2 > %1$s/vocabulary_conversion.csv.gz' CSV HEADER;
	$$, iExportPath);
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;
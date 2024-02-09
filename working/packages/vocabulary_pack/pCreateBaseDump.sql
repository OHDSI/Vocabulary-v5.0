CREATE OR REPLACE FUNCTION vocabulary_pack.pCreateBaseDump ()
RETURNS VOID AS
$BODY$
	/*
	Exporting base tables to disk
	*/
DECLARE
	crlf CONSTANT TEXT:= '<br>';
	iEmail CONSTANT TEXT:= (SELECT var_value FROM devv5.config$ WHERE var_name='vocabulary_athena_email');
	iVocabularyExportPath TEXT:= (SELECT var_value FROM devv5.config$ WHERE var_name='vocabulary_export_path');
	iRet TEXT;
	iCIDs TEXT;
BEGIN
	--v5
	EXECUTE FORMAT ($$
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
			FROM devv5.concept
		) TO '%1$s/v5_concept.csv' CSV HEADER;

		COPY devv5.vocabulary TO '%1$s/v5_vocabulary.csv' CSV HEADER;

		COPY (
			SELECT concept_id_1,
				concept_id_2,
				relationship_id,
				TO_CHAR(valid_start_date, 'DD-MON-YYYY') valid_start_date,
				TO_CHAR(valid_end_date, 'DD-MON-YYYY') valid_end_date,
				invalid_reason
			FROM devv5.concept_relationship
			WHERE invalid_reason IS NULL
		) TO '%1$s/v5_concept_relationship.csv' CSV HEADER;

		COPY devv5.relationship TO '%1$s/v5_relationship.csv' CSV HEADER;
		COPY devv5.concept_synonym TO '%1$s/v5_concept_synonym.csv' CSV HEADER;
		COPY devv5.concept_ancestor TO '%1$s/v5_concept_ancestor.csv' CSV HEADER;
		COPY devv5.domain TO '%1$s/v5_domain.csv' CSV HEADER;

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
			FROM devv5.drug_strength
		) TO '%1$s/v5_drug_strength.csv' CSV HEADER;

		COPY devv5.concept_class TO '%1$s/v5_concept_class.csv' CSV HEADER;

		COPY (
			SELECT vocabulary_id_v4,
				vocabulary_id_v5,
				omop_req,
				click_default,
				available,
				url,
				click_disabled,
				TO_CHAR(latest_update, 'DD-MON-YYYY') latest_update
			FROM devv5.vocabulary_conversion
		) TO '%1$s/v5_vocabulary_conversion.csv' CSV HEADER;
	$$, iVocabularyExportPath);

	--v4 will be deleted soon
	--v4
	execute 'COPY (select concept_id, concept_name, concept_level, concept_class, vocabulary_id, concept_code, 
	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
	invalid_reason from devv4.concept) TO '''||iVocabularyExportPath||'v4_concept.csv'' DELIMITER '','' CSV HEADER';
	execute 'COPY devv4.vocabulary TO '''||iVocabularyExportPath||'v4_vocabulary.csv'' DELIMITER '','' CSV HEADER';
	execute 'COPY (select concept_id_1, concept_id_2, relationship_id, 
	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
	invalid_reason from devv4.concept_relationship where invalid_reason is null) TO '''||iVocabularyExportPath||'v4_concept_relationship.csv'' DELIMITER '','' CSV HEADER';
	execute 'COPY devv4.relationship TO '''||iVocabularyExportPath||'v4_relationship.csv'' DELIMITER '','' CSV HEADER';
	execute 'COPY devv4.concept_synonym TO '''||iVocabularyExportPath||'v4_concept_synonym.csv'' DELIMITER '','' CSV HEADER';
	execute 'COPY devv4.concept_ancestor TO '''||iVocabularyExportPath||'v4_concept_ancestor.csv'' DELIMITER '','' CSV HEADER';
	execute 'COPY (select source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, mapping_type, primary_map, 
	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
	invalid_reason from devv4.source_to_concept_map) TO '''||iVocabularyExportPath||'v4_source_to_concept_map.csv'' DELIMITER '','' CSV HEADER';
	execute 'COPY (select  drug_concept_id, ingredient_concept_id, amount_value, amount_unit, concentration_value, concentration_enum_unit, concentration_denom_unit, box_size, 
	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
	invalid_reason from devv4.drug_strength) TO '''||iVocabularyExportPath||'v4_drug_strength.csv'' DELIMITER '','' CSV HEADER';

	PERFORM devv5.SendMailHTML (iEmail, 'Release status: started uploading to Athena', 'dummy e-mail');
	--start zipping and uploading
	PERFORM vocabulary_pack.run_upload(iVocabularyExportPath);

	--sending result
	SELECT STRING_AGG(concept_id::TEXT, ', ' ORDER BY concept_id)
	INTO iCIDs
	FROM (
		SELECT *
		FROM (
			SELECT concept_id
			FROM devv5.concept
			
			EXCEPT
			
			SELECT concept_id
			FROM prodv5.concept
			) AS s0
			LIMIT 5
		) AS s1;


	iRet := 'Release completed';

	IF iCIDs IS NOT NULL
	THEN
		iRet:= iRet || crlf || 'Some new concept_ids: ' || iCIDs;
	ELSE
		iRet:= iRet || crlf || 'No new concept_ids ';
	END IF;

	PERFORM devv5.SendMailHTML (iEmail, 'Release status [OK] [Athena]', iRet);

	EXCEPTION WHEN OTHERS THEN
		GET STACKED DIAGNOSTICS iRet = PG_EXCEPTION_CONTEXT;
		iRet:='ERROR: '||SQLERRM||crlf||'CONTEXT: '||REGEXP_REPLACE(iRet, '\r|\n|\r\n', crlf, 'g');
		iRet := SUBSTR ('Release completed with errors:'||crlf||'<b>'||iRet||'</b>', 1, 5000);
		PERFORM devv5.SendMailHTML (iEmail, 'Release status [ERROR] [Athena]', iRet);
END;
$BODY$
LANGUAGE 'plpgsql';
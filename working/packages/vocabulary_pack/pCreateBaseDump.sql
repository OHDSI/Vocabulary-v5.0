CREATE OR REPLACE FUNCTION vocabulary_pack.pcreatebasedump (
)
RETURNS void AS
$body$
/* Exporting base tables to disk*/
DECLARE
  crlf VARCHAR(4) := '<br>';
  email CONSTANT VARCHAR(1000) :=('timur.vakhitov@odysseusinc.com, maria.pozhidaeva@odysseusinc.com');
  pVocabularyExportPath varchar (1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='vocabulary_export_path');
  cRet TEXT;
  cCIDs VARCHAR(4000);
BEGIN
  --v5
  execute 'COPY (select concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, 
  	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
    invalid_reason from devv5.concept) TO '''||pVocabularyExportPath||'v5_concept.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv5.vocabulary TO '''||pVocabularyExportPath||'v5_vocabulary.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY (select concept_id_1, concept_id_2, relationship_id, 
  	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
    invalid_reason from devv5.concept_relationship where invalid_reason is null) TO '''||pVocabularyExportPath||'v5_concept_relationship.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv5.relationship TO '''||pVocabularyExportPath||'v5_relationship.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv5.concept_synonym TO '''||pVocabularyExportPath||'v5_concept_synonym.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv5.concept_ancestor TO '''||pVocabularyExportPath||'v5_concept_ancestor.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv5.domain TO '''||pVocabularyExportPath||'v5_domain.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY (select drug_concept_id, ingredient_concept_id, amount_value, amount_unit_concept_id, numerator_value, numerator_unit_concept_id, denominator_value,
  	denominator_unit_concept_id, box_size, to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
    invalid_reason from devv5.drug_strength) TO '''||pVocabularyExportPath||'v5_drug_strength.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv5.concept_class TO '''||pVocabularyExportPath||'v5_concept_class.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY (select vocabulary_id_v4, vocabulary_id_v5,	omop_req, click_default, available,	url, click_disabled, 
  	to_char(latest_update,''DD-MON-YYYY'') latest_update from devv5.vocabulary_conversion) TO '''||pVocabularyExportPath||'v5_vocabulary_conversion.csv'' DELIMITER '','' CSV HEADER';
  
  --v4
  execute 'COPY (select concept_id, concept_name, concept_level, concept_class, vocabulary_id, concept_code, 
  	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
    invalid_reason from devv4.concept) TO '''||pVocabularyExportPath||'v4_concept.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv4.vocabulary TO '''||pVocabularyExportPath||'v4_vocabulary.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY (select concept_id_1, concept_id_2, relationship_id, 
  	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
    invalid_reason from devv4.concept_relationship where invalid_reason is null) TO '''||pVocabularyExportPath||'v4_concept_relationship.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv4.relationship TO '''||pVocabularyExportPath||'v4_relationship.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv4.concept_synonym TO '''||pVocabularyExportPath||'v4_concept_synonym.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY devv4.concept_ancestor TO '''||pVocabularyExportPath||'v4_concept_ancestor.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY (select source_code, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id, mapping_type, primary_map, 
  	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
    invalid_reason from devv4.source_to_concept_map) TO '''||pVocabularyExportPath||'v4_source_to_concept_map.csv'' DELIMITER '','' CSV HEADER';
  execute 'COPY (select  drug_concept_id, ingredient_concept_id, amount_value, amount_unit, concentration_value, concentration_enum_unit, concentration_denom_unit, box_size, 
  	to_char(valid_start_date,''DD-MON-YYYY'') valid_start_date, to_char(valid_end_date,''DD-MON-YYYY'') valid_end_date, 
    invalid_reason from devv4.drug_strength) TO '''||pVocabularyExportPath||'v4_drug_strength.csv'' DELIMITER '','' CSV HEADER';
  
  perform devv5.SendMailHTML (email, 'Release status: started uploading to Athena', 'dummy e-mail');
  --start zipping and uploading
  perform vocabulary_pack.run_upload(pVocabularyExportPath);
  
  --sending result
  SELECT string_agg(concept_id::varchar, ', ' ORDER BY concept_id)
  INTO cCIDs
  FROM (SELECT * FROM (
          SELECT concept_id
          FROM devv5.concept
          EXCEPT
          SELECT concept_id
          FROM prodv5.concept
        ) AS s0 LIMIT 5
      ) as s1;

  cRet := 'Release completed';

  IF cCIDs IS NOT NULL
    THEN
    	cRet := cRet || crlf || 'Some new concept_id''s: ' || cCIDs;
    else
    	cRet := cRet || crlf || 'No new concept_id''s ';
  END IF;

  perform devv5.SendMailHTML (email, 'Release status [OK] [Athena]', cRet);
  
  EXCEPTION
  WHEN OTHERS
  THEN
    GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT;
    cRet:='ERROR: '||SQLERRM||crlf||'CONTEXT: '||regexp_replace(cRet, '\r|\n|\r\n', crlf, 'g');
    cRet := SUBSTR ('Release completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 5000);
    perform devv5.SendMailHTML (email, 'Release status [ERROR] [Athena]', cRet);
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;
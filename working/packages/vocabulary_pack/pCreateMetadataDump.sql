CREATE OR REPLACE FUNCTION vocabulary_pack.pCreateMetadataDump()
RETURNS VOID AS
$BODY$
    /*
    Exporting metadata tables to disk
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
                concept_category,
                reuse_status
            FROM devv5.concept_metadata
        ) TO '%1$s/concept_metadata.csv' CSV HEADER;

        --exclude the last three service columns
        COPY (
            SELECT crm.concept_id_1,
                   crm.concept_id_2,
                   crm.relationship_id,
                   crm.relationship_predicate_id,
                   crm.relationship_group,
                   crm.mapping_source,
                   crm.confidence,
                   crm.mapping_tool,
                   crm.mapper,
                   crm.reviewer
              FROM devv5.concept_relationship_metadata crm
              JOIN devv5.concept_relationship cr 
                ON crm.concept_id_1 = cr.concept_id_1  
               AND crm.concept_id_2 = cr.concept_id_2
               AND crm.relationship_id = cr.relationship_id
              WHERE cr.invalid_reason IS NULL
        ) TO '%1$s/concept_relationship_metadata.csv' CSV HEADER;

    $$, iVocabularyExportPath);
END;
$BODY$
LANGUAGE 'plpgsql';
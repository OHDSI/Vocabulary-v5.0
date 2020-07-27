CREATE OR REPLACE FUNCTION vocabulary_pack.ProcessManualRelationships (
)
RETURNS void AS
$body$
/*
 Inserts a manual relationships from concept_relationship_manual into the concept_relationship_stage
*/
declare
  z int4;
  cSchemaName VARCHAR(100);
begin
  /*
       Checking table concept_relationship_manual for errors
  */
  IF CURRENT_SCHEMA <> 'devv5' 
    THEN
    PERFORM vocabulary_pack.CheckManualRelationships();
  END IF;
  SELECT LOWER(MAX(dev_schema_name)),
         COUNT(DISTINCT dev_schema_name)
  FROM vocabulary
  WHERE latest_update IS NOT NULL
  INTO cSchemaName,
       z;
  IF z > 1
    THEN
    RAISE EXCEPTION 'ProcessManualRelationships: more than one dev_schema found';
  END IF;

  IF CURRENT_SCHEMA = 'devv5'
    THEN
    SELECT COUNT(*)
    INTO z
    FROM pg_tables pg_t
    WHERE pg_t.schemaname = cSchemaName
          AND pg_t.tablename = 'concept_relationship_manual';

    IF z = 0
      THEN
      RAISE EXCEPTION 'ProcessManualRelationships: % not found', cSchemaName ||
      '.concept_relationship_manual';
    END IF;

    TRUNCATE TABLE concept_relationship_manual;
    EXECUTE 'INSERT INTO concept_relationship_manual SELECT * FROM ' ||
      cSchemaName || '.concept_relationship_manual';

    PERFORM vocabulary_pack.CheckManualRelationships();
  END IF;
    --add new records
    insert into concept_relationship_stage(concept_code_1, concept_code_2,
      vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date,
      valid_end_date, invalid_reason)
    select *
    from concept_relationship_manual m
    where not exists (
                       select 1
                       from concept_relationship_stage crs_int
                       where crs_int.concept_code_1 = m.concept_code_1
                             and crs_int.concept_code_2 = m.concept_code_2
                             and crs_int.vocabulary_id_1 = m.vocabulary_id_1
                             and crs_int.vocabulary_id_2 = m.vocabulary_id_2
                             and crs_int.relationship_id = m.relationship_id
          );
    --update existing
    update concept_relationship_stage crs
    set 
        valid_start_date=m.valid_start_date,
        valid_end_date=m.valid_end_date,
        invalid_reason=m.invalid_reason
    from concept_relationship_manual m
    where
    crs.concept_code_1 = m.concept_code_1
    and crs.concept_code_2 = m.concept_code_2
    and crs.vocabulary_id_1 = m.vocabulary_id_1
    and crs.vocabulary_id_2 = m.vocabulary_id_2
    and crs.relationship_id = m.relationship_id
    and (
        crs.valid_start_date<>m.valid_start_date or
        crs.valid_end_date<>m.valid_end_date or
        coalesce(crs.invalid_reason,'X')<>coalesce(m.invalid_reason,'X')
    );

end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER;
CREATE OR REPLACE FUNCTION vocabulary_pack.SetLatestUpdate (
  pvocabularyname varchar,
  pvocabularydate date,
  pvocabularyversion varchar,
  pvocabularydevschema varchar,
  pappendvocabulary boolean = false
)
RETURNS void AS
$body$
    /*
     Adds (if not exists) column 'latest_update' to 'vocabulary' table and sets it to pVocabularyDate value
     Also adds 'dev_schema_name' column what needs for 'ProcessManualRelationships' procedure
     If pAppendVocabulary is set to TRUE, then procedure DOES NOT drops any columns, just updates the 'latest_update' and 'dev_schema_name'
    */
DECLARE
  z int4;
BEGIN
  IF pVocabularyName IS NULL
    THEN
    RAISE EXCEPTION 'pVocabularyName cannot be empty!';
  END IF;

  IF pVocabularyDate IS NULL
    THEN
    RAISE EXCEPTION 'pVocabularyDate cannot be empty!';
  END IF;

  /*IF pVocabularyDate > CURRENT_DATE
    THEN
    RAISE EXCEPTION 'pVocabularyDate bigger than current date!';
  END IF;*/ --disabled 20200713, e.g. ICD10CM may be from the 'future'

  IF pVocabularyVersion IS NULL
    THEN
    RAISE EXCEPTION 'pVocabularyVersion cannot be empty!';
  END IF;

  IF pVocabularyDevSchema IS NULL
    THEN
    RAISE EXCEPTION 'pVocabularyDevSchema cannot be empty!';
  END IF;
  SELECT COUNT(*)
  INTO z
  FROM vocabulary
  WHERE vocabulary_id = pVocabularyName;

  IF z = 0
    THEN
    RAISE EXCEPTION 'Vocabulary with id=% not found', pVocabularyName;
  END IF;
  SELECT COUNT(*)
  INTO z
  FROM information_schema.schemata
  WHERE schema_name = LOWER(pVocabularyDevSchema);

  IF z = 0
    THEN
    RAISE EXCEPTION  'Dev schema with name % not found', pVocabularyDevSchema;
  END IF;

  IF NOT pAppendVocabulary
    THEN
    ALTER TABLE vocabulary ADD
  if not exists latest_update DATE, add
  if not exists dev_schema_name VARCHAR(
        100);
    update vocabulary
    set latest_update = null,
        dev_schema_name = null;
  END IF;
  UPDATE vocabulary
  SET latest_update = pVocabularyDate,
      vocabulary_version = pVocabularyVersion,
      dev_schema_name = pVocabularyDevSchema
  WHERE vocabulary_id = pVocabularyName;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
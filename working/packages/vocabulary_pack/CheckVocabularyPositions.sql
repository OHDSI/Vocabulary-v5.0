CREATE OR REPLACE FUNCTION vocabulary_pack.checkvocabularypositions (
  int_pos1 integer,
  int_pos2 integer,
  pvocabularyname varchar
)
RETURNS void AS
$body$
BEGIN
  IF int_Pos1 = 0 OR int_Pos2 = 0 OR int_Pos2 <= int_Pos1
  THEN
  	RAISE EXCEPTION 'Something wrong while parsing %', pVocabularyName;
  END IF;
END ;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100;
CREATE OR REPLACE FUNCTION vocabulary_pack.CreateTablesCopiesATC ()
RETURNS void AS
$BODY$
/*
  This procedure creates a copy of dev_atc.class_to_drug when ATC is ready for release
*/
BEGIN
	DELETE FROM sources.class_to_drug;
	INSERT INTO sources.class_to_drug SELECT * FROM dev_atc.class_to_drug;
	ANALYZE sources.class_to_drug;
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY DEFINER;
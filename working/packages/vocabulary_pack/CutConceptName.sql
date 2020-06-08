CREATE OR REPLACE FUNCTION vocabulary_pack.CutConceptName (concept_name IN TEXT) RETURNS TEXT
AS
$BODY$
	SELECT CASE 
		WHEN LENGTH(concept_name) > 255
			THEN TRIM(SUBSTR(concept_name, 1, 252)) || '...'
		ELSE concept_name
		END;
$BODY$
LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE SECURITY INVOKER;
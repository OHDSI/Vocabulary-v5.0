CREATE OR REPLACE FUNCTION vocabulary_pack.CutConceptSynonymName (concept_name IN TEXT) RETURNS TEXT
AS
$BODY$
	SELECT CASE 
		WHEN LENGTH(concept_name) > 1000
			THEN TRIM(SUBSTR(concept_name, 1, 997)) || '...'
		ELSE concept_name
		END;
$BODY$
LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE SECURITY INVOKER;
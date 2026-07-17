CREATE OR REPLACE FUNCTION vocabulary_pack.DropIndexes (pTables TEXT[], pExcludeIndexes TEXT[])
RETURNS TEXT AS
$BODY$
	/*
	The function analyzes the tables specified in the input, saves all index definitions for them (except unique/PK and mentioned in pExcludeIndexes) in a separate script, and then drops the indexes

	Usage:
	DO $_$
	DECLARE
		iCreateDDL TEXT;
	BEGIN
		--drop indexes
		SELECT * INTO iCreateDDL FROM vocabulary_pack.DropIndexes(ARRAY ['concept','concept_relationship','concept_synonym','vocabulary','relationship','domain','concept_class','drug_strength','pack_content']);
		--...do other things...
		--create indexes back
		EXECUTE iCreateDDL;
	END $_$;
	*/
DECLARE
	iDropDDL TEXT;
	iCreateDDL TEXT;
BEGIN
	SELECT STRING_AGG(FORMAT('DROP INDEX %I', ind.indexrelid::REGCLASS::TEXT),';'),
		STRING_AGG(PG_GET_INDEXDEF(ind.indexrelid),';')
	INTO iDropDDL,
		iCreateDDL
	FROM pg_index ind
	WHERE ind.indrelid = ANY (pTables::REGCLASS[])
		AND ind.indexrelid <> ALL (pExcludeIndexes::REGCLASS[])
		AND NOT ind.indisunique; --exclude unique and PK indexes - they are associated with the corresponding constraints and therefore cannot be dropped

	EXECUTE COALESCE(iDropDDL,'');
	RETURN COALESCE(iCreateDDL,'');
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;
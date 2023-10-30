CREATE OR REPLACE FUNCTION vocabulary_pack.DropFKConstraints (pTargetTables TEXT[])
RETURNS TEXT AS
$BODY$
	/*
	The function analyzes the tables specified in the input, saves all FKs for them in a separate script, and then drops the FKs

	Usage:
	DO $_$
	DECLARE
		iCreateDDL TEXT;
	BEGIN
		--drop FKs
		SELECT * INTO iCreateDDL FROM vocabulary_pack.DropFKConstraints(ARRAY ['concept','concept_relationship','concept_synonym','vocabulary','relationship','domain','concept_class','drug_strength','pack_content']);
		--...do other things...
		--create FKs back
		EXECUTE iCreateDDL;
	END $_$;
	*/
DECLARE
	iDropDDL TEXT;
	iCreateDDL TEXT;
BEGIN
	SELECT STRING_AGG(FORMAT('ALTER TABLE %I DROP CONSTRAINT %I', pc.conrelid::REGCLASS::TEXT, pc.conname),';'),
		STRING_AGG(FORMAT('ALTER TABLE %I ADD CONSTRAINT %I %s', pc.conrelid::REGCLASS::TEXT, pc.conname, PG_GET_CONSTRAINTDEF(pc.oid)),';')
	INTO iDropDDL,
		iCreateDDL
	FROM pg_constraint pc
	WHERE pc.contype = 'f'
		AND pc.connamespace = CURRENT_SCHEMA::REGNAMESPACE
		AND pc.confrelid::REGCLASS::TEXT = ANY (pTargetTables);

	EXECUTE iDropDDL;
	RETURN COALESCE(iCreateDDL,'');
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;
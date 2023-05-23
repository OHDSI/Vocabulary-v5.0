--1. Create trigger for all manual tables
DO $$
DECLARE
	pTables TEXT[]:=ARRAY['base_concept_manual','base_concept_relationship_manual','base_concept_synonym_manual'];
	t TEXT;
BEGIN
	FOREACH t IN ARRAY pTables LOOP
		EXECUTE FORMAT('
		CREATE TRIGGER tg_audit_u
		AFTER UPDATE ON %1$I
		FOR EACH ROW
		WHEN (OLD.* IS DISTINCT FROM NEW.*)
		EXECUTE PROCEDURE audit.f_tg_audit();

		CREATE TRIGGER tg_audit_id
		AFTER INSERT OR DELETE ON %1$I
		FOR EACH ROW
		EXECUTE PROCEDURE audit.f_tg_audit();

		CREATE TRIGGER tg_audit_t
		AFTER TRUNCATE ON %1$I
		FOR EACH STATEMENT
		EXECUTE PROCEDURE audit.f_tg_audit();',t);
	END LOOP;
END $$;
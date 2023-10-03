CREATE OR REPLACE FUNCTION vocabulary_pack.CreateLocalProd (
)
RETURNS VOID AS
$BODY$
/*
  This procedure creates the local copy of DEVV5 after release (aka PROD)
  and this local copy is used by QA_TESTS.get_summary
  Necessary grants:
  grant drop any table to devv5;
  grant insert on <concept, concept_relationship, concept_ancestor> to devv5;
*/
BEGIN
  TRUNCATE TABLE prodv5.concept;
  INSERT INTO prodv5.concept SELECT * FROM concept;
  TRUNCATE TABLE prodv5.concept_relationship;
  INSERT INTO prodv5.concept_relationship SELECT * FROM concept_relationship;
  TRUNCATE TABLE prodv5.concept_ancestor;
  INSERT INTO prodv5.concept_ancestor SELECT * FROM concept_ancestor;
END;
$BODY$
LANGUAGE 'plpgsql';

REVOKE EXECUTE ON FUNCTION vocabulary_pack.CreateLocalProd FROM PUBLIC, role_read_only;
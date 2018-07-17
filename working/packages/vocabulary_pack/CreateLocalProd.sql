CREATE OR REPLACE FUNCTION vocabulary_pack.createlocalprod (
)
RETURNS void AS
$body$
/*
  This procedure creates the local copy of DEVV5 after release (aka PROD)
  and this local copy is used by QA_TESTS.get_summary
  Necessary grants:
  grant drop any table to devv5;
  grant insert on <concept, concept_relationship, concept_ancestor> to devv5;
*/
begin
  TRUNCATE TABLE PRODV5.CONCEPT;
  INSERT INTO PRODV5.CONCEPT SELECT * FROM CONCEPT;
  TRUNCATE TABLE PRODV5.CONCEPT_RELATIONSHIP;
  INSERT INTO PRODV5.CONCEPT_RELATIONSHIP SELECT * FROM CONCEPT_RELATIONSHIP;
  TRUNCATE TABLE PRODV5.CONCEPT_ANCESTOR;
  INSERT INTO PRODV5.CONCEPT_ANCESTOR SELECT * FROM CONCEPT_ANCESTOR;
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;
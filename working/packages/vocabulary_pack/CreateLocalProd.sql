CREATE OR REPLACE FUNCTION vocabulary_pack.CreateLocalProd ()
RETURNS VOID AS
$BODY$
/*
	This procedure CREATE TABLEs the local copy of DEVV5 after release (aka PROD)
	and this local copy is used by QA_TESTS.get_summary and for patch approach
*/
BEGIN
	DROP TABLE concept_ancestor, concept, concept_relationship, relationship, vocabulary, vocabulary_conversion, concept_class, domain, concept_synonym, drug_strength, pack_content;
	CREATE TABLE concept_ancestor AS TABLE devv5.concept_ancestor;
	CREATE TABLE concept AS TABLE devv5.concept;
	CREATE TABLE concept_relationship AS TABLE devv5.concept_relationship;
	CREATE TABLE relationship AS TABLE devv5.relationship;
	CREATE TABLE vocabulary AS TABLE devv5.vocabulary;
	CREATE TABLE vocabulary_conversion AS TABLE devv5.vocabulary_conversion;
	CREATE TABLE concept_class AS TABLE devv5.concept_class;
	CREATE TABLE domain AS TABLE devv5.domain;
	CREATE TABLE concept_synonym AS TABLE devv5.concept_synonym;
	CREATE TABLE drug_strength AS TABLE devv5.drug_strength;
	CREATE TABLE pack_content AS TABLE devv5.pack_content;
END;
$BODY$
LANGUAGE 'plpgsql'
SET search_path = prodv5, pg_temp;

REVOKE EXECUTE ON FUNCTION vocabulary_pack.CreateLocalProd FROM PUBLIC, role_read_only;
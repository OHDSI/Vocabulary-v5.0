/*
Adds new relationship

Usage:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Has system',
    pRelationship_id         =>'Has system',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'System of',
    pRelationship_name_rev   =>'System of',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;
*/

CREATE OR REPLACE FUNCTION vocabulary_pack.AddNewRelationship (
  pRelationship_name relationship.relationship_name%TYPE,
  pRelationship_id relationship.relationship_id%TYPE,
  pIs_hierarchical int,
  pDefines_ancestry int,
  pReverse_relationship_id relationship.reverse_relationship_id%TYPE,
  pRelationship_name_rev relationship.relationship_name%TYPE,
  pIs_hierarchical_rev int,
  pDefines_ancestry_rev int
)
RETURNS void AS
$BODY$
DECLARE
  z  INT;
  ex INT;
BEGIN
  IF COALESCE(pIs_hierarchical,-1) NOT IN (0,1) THEN RAISE EXCEPTION 'Incorrect value for pIs_hierarchical: %', pIs_hierarchical; END IF;
  IF COALESCE(pDefines_ancestry,-1) NOT IN (0,1) THEN RAISE EXCEPTION 'Incorrect value for pDefines_ancestry: %', pDefines_ancestry; END IF;
  IF COALESCE(pIs_hierarchical_rev,-1) NOT IN (0,1) THEN RAISE EXCEPTION 'Incorrect value for pIs_hierarchical_rev: %', pIs_hierarchical_rev; END IF;
  IF COALESCE(pDefines_ancestry_rev,-1) NOT IN (0,1) THEN RAISE EXCEPTION 'Incorrect value for pDefines_ancestry_rev: %', pDefines_ancestry_rev; END IF;
  IF pDefines_ancestry=1 AND pDefines_ancestry_rev=1 THEN RAISE EXCEPTION 'pDefines_ancestry and pDefines_ancestry_rev are both equal to 1'; END IF;

  DROP SEQUENCE IF EXISTS v5_concept;

  SELECT MAX (concept_id) + 1 INTO ex FROM concept
  WHERE concept_id >= 31967 AND concept_id < 72245;

  EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
  ALTER TABLE relationship DROP CONSTRAINT FPK_RELATIONSHIP_REVERSE;

  --direct
  SELECT nextval('v5_concept') INTO z;
  INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
    VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
  INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
    VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

  --reverse
  SELECT nextval('v5_concept') INTO z;
  INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
    VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
  INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
    VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

  ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
  DROP SEQUENCE v5_concept;
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
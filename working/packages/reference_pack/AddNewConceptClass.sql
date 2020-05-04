/*
Adds new concept class

Usage:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Proc Hierarchy',
    pConcept_class_name     =>'Procedure Hierarchy'
);
END $_$;
*/

CREATE OR REPLACE FUNCTION vocabulary_pack.AddNewConceptClass (
  pConcept_class_id concept_class.concept_class_id%TYPE,
  pConcept_class_name concept_class.concept_class_name%TYPE
)
RETURNS void AS
$body$
DECLARE
  z  INT;
  ex INT;
begin
  DROP SEQUENCE IF EXISTS v5_concept;

  SELECT MAX (concept_id) + 1 INTO ex FROM concept
  WHERE concept_id >= 31967 AND concept_id < 72245;

  EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
  SELECT nextval('v5_concept') INTO z;

  INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
    VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
  INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
    VALUES (pConcept_class_id, pConcept_class_name, z);

  DROP SEQUENCE v5_concept;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
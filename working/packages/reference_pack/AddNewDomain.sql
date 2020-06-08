/*
Adds new domain

Usage:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewDomain(
    pDomain_id       =>'Condition Status',
    pDomain_name     =>'OMOP Condition Status'
);
END $_$;
*/

CREATE OR REPLACE FUNCTION vocabulary_pack.AddNewDomain (
  pDomain_id domain.domain_id%TYPE,
  pDomain_name domain.domain_name%TYPE
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
    VALUES (z, pDomain_name, 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
  INSERT INTO domain (domain_id, domain_name, domain_concept_id)
    VALUES (pDomain_id, pDomain_name, z);

  DROP SEQUENCE v5_concept;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
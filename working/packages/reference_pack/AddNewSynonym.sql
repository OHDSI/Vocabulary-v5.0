/*
Adds new synonym

Usage:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>123,
    pSynonym_name        =>'test synonym',
    pLanguage_concept_id =>4180186
);
END $_$;

OR you can combine with the AddNewConcept:

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'test concept name 5',
                            pDomain_id        =>'Drug',
                            pVocabulary_id    =>'SNOMED',
                            pConcept_class_id =>'Ingredient',
                            pStandard_concept =>'S',
                            pConcept_code     =>'123_test5'
                        ),
    pSynonym_name        =>'test synonym 5',
    pLanguage_concept_id =>4180186
);
END $_$;
*/

CREATE OR REPLACE FUNCTION vocabulary_pack.AddNewSynonym (
  pConcept_id concept_synonym.concept_id%TYPE,
  pSynonym_name concept_synonym.concept_synonym_name%TYPE,
  pLanguage_concept_id concept_synonym.language_concept_id%TYPE = 4180186 /*English*/
)
RETURNS void AS
$BODY$
DECLARE
  z  INT;
  ex INT;
BEGIN
  pSynonym_name:=REGEXP_REPLACE(pSynonym_name, '[[:cntrl:]]+', ' ', 'g');
  pSynonym_name:=REGEXP_REPLACE(pSynonym_name, ' {2,}', ' ', 'g');
  pSynonym_name:=TRIM(pSynonym_name);
  pSynonym_name:=REPLACE(pSynonym_name, '–', '-');

  INSERT INTO concept_synonym (concept_id, concept_synonym_name, language_concept_id)
    VALUES (pConcept_id, pSynonym_name, pLanguage_concept_id);
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;
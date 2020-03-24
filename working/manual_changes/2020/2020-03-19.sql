--add new concepts
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Home isolation',
    pDomain_id        =>'Visit',
    pVocabulary_id    =>'Visit',
    pConcept_class_id =>'Visit',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP4873970'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Isolation in inpatient setting',
    pDomain_id        =>'Visit',
    pVocabulary_id    =>'Visit',
    pConcept_class_id =>'Visit',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP4873971'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Person Under Investigation (PUI)',
    pDomain_id        =>'Visit',
    pVocabulary_id    =>'Visit',
    pConcept_class_id =>'Visit',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP4873972'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Reference Lab result',
    pDomain_id        =>'Type Concept',
    pVocabulary_id    =>'Meas Type',
    pConcept_class_id =>'Meas Type',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP4873973'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Remdesivir',
    pDomain_id        =>'Drug',
    pVocabulary_id    =>'RxNorm Extension',
    pConcept_class_id =>'Ingredient',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP4873974'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Umifenovir',
    pDomain_id        =>'Drug',
    pVocabulary_id    =>'RxNorm Extension',
    pConcept_class_id =>'Ingredient',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP4873975'
);
END $_$;

--add new relationship for Visit
INSERT INTO concept_relationship VALUES
(32760,9201, 'Is a', current_date, to_date('20991231','yyyymmdd'),null),
(9201,32760, 'Subsumes', current_date, to_date('20991231','yyyymmdd'),null);
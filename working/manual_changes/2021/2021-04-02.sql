--Add new concept
DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewSynonym(
  pConcept_id=>vocabulary_pack.AddNewSynonym(
      pConcept_id =>vocabulary_pack.AddNewConcept(
                     pConcept_name     =>'COVID-19 convalescent plasma',
                     pDomain_id        =>'Drug',
                     pVocabulary_id    =>'RxNorm Extension',
                     pConcept_class_id =>'Ingredient',
                     pStandard_concept =>'S',
                     pConcept_code     =>NULL
                          ),
      pSynonym_name        =>'Disease caused by Severe acute respiratory syndrome coronavirus 2 convalescent plasma',
      pLanguage_concept_id =>4180186
  ),
  pSynonym_name        =>'Anti-SARS-CoV-2 convalescent plasma',
  pLanguage_concept_id =>4180186
);
END $_$;

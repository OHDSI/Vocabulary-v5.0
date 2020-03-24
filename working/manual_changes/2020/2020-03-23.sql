--add new concept with synonyms
DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewSynonym(
  pConcept_id=>vocabulary_pack.AddNewSynonym(
      pConcept_id          =>vocabulary_pack.AddNewConcept(
                              pConcept_name     =>'Favipiravir',
                              pDomain_id        =>'Drug',
                              pVocabulary_id    =>'RxNorm Extension',
                              pConcept_class_id =>'Ingredient',
                              pStandard_concept =>'S',
                              pConcept_code     =>'OMOP4873976'
                          ),
      pSynonym_name        =>'Favilavir',
      pLanguage_concept_id =>4180186
  ),
  pSynonym_name        =>'Avigan',
  pLanguage_concept_id =>4180186
);
END $_$;
--add new concept with synonyms
DO $_$
BEGIN
      pConcept_id =>vocabulary_pack.AddNewConcept(
                     pConcept_name     =>'BVRS-GamVac-Combi',
                     pDomain_id        =>'Drug',
                     pVocabulary_id    =>'RxNorm Extension',
                     pConcept_class_id =>'Ingredient',
                     pStandard_concept =>'S',
                     pConcept_code     =>'OMOP4873977'
      );
END $_$;

DO $_$
BEGIN
      pConcept_id =>vocabulary_pack.AddNewConcept(
                     pConcept_name     =>'Carrimycin',
                     pDomain_id        =>'Drug',
                     pVocabulary_id    =>'RxNorm Extension',
                     pConcept_class_id =>'Ingredient',
                     pStandard_concept =>'S',
                     pConcept_code     =>'OMOP4873978'
      );
END $_$;

DO $_$
BEGIN
      pConcept_id =>vocabulary_pack.AddNewConcept(
                     pConcept_name     =>'CD24Fc',
                     pDomain_id        =>'Drug',
                     pVocabulary_id    =>'RxNorm Extension',
                     pConcept_class_id =>'Ingredient',
                     pStandard_concept =>'S',
                     pConcept_code     =>'OMOP4873979'
      );
END $_$;


DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewSynonym(
  pConcept_id=>vocabulary_pack.AddNewSynonym(
      pConcept_id          =>vocabulary_pack.AddNewConcept(
                              pConcept_name     =>'Tetrandrine',
                              pDomain_id        =>'Drug',
                              pVocabulary_id    =>'RxNorm Extension',
                              pConcept_class_id =>'Ingredient',
                              pStandard_concept =>'S',
                              pConcept_code     =>'OMOP4873980'
                          ),
      pSynonym_name        =>'Tetradrine',
      pLanguage_concept_id =>4180186
  ),
  pSynonym_name        =>'Isotetrandrine',
  pLanguage_concept_id =>4180186
);
END $_$;


DO $_$
BEGIN
      pConcept_id =>vocabulary_pack.AddNewConcept(
                     pConcept_name     =>'Xiyanping',
                     pDomain_id        =>'Drug',
                     pVocabulary_id    =>'RxNorm Extension',
                     pConcept_class_id =>'Ingredient',
                     pStandard_concept =>'S',
                     pConcept_code     =>'OMOP4873981'
);
END $_$;

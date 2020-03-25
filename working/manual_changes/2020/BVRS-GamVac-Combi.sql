--add new concepts with synonyms
DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewSynonym(
      pConcept_id =>vocabulary_pack.AddNewConcept(
                     pConcept_name     =>'Middle East Respiratory Syndrome combined heterologous adenoviral-based vector vaccine',
                     pDomain_id        =>'Drug',
                     pVocabulary_id    =>'RxNorm Extension',
                     pConcept_class_id =>'Ingredient',
                     pStandard_concept =>'S',
                     pConcept_code     =>'OMOP4873977'
                          ),
      pSynonym_name        =>'BVRS-GamVac-Combi',
      pLanguage_concept_id =>4180186
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
PERFORM vocabulary_pack.AddNewSynonym(
  pConcept_id=>vocabulary_pack.AddNewSynonym(
      pConcept_id =>vocabulary_pack.AddNewConcept(
                     pConcept_name     =>'CD24 Extracellular Domain-IgG1 Fc Domain Recombinant Fusion Protein CD24Fc',
                     pDomain_id        =>'Drug',
                     pVocabulary_id    =>'RxNorm Extension',
                     pConcept_class_id =>'Ingredient',
                     pStandard_concept =>'S',
                     pConcept_code     =>'OMOP4873979'
                          ),
      pSynonym_name        =>'CD24Fc CD24IgG',
      pLanguage_concept_id =>4180186
  ),
  pSynonym_name        =>'CD24Fc',
  pLanguage_concept_id =>4180186
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
  pSynonym_name        =>'Fanchinine',
  pLanguage_concept_id =>4180186
);
END $_$;






DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewSynonym(
      pConcept_id =>vocabulary_pack.AddNewConcept(
                     pConcept_name     =>'Xiyanping',
                     pDomain_id        =>'Drug',
                     pVocabulary_id    =>'RxNorm Extension',
                     pConcept_class_id =>'Ingredient',
                     pStandard_concept =>'S',
                     pConcept_code     =>'OMOP4873981'
                          ),
      pSynonym_name        =>'喜炎平',
      pLanguage_concept_id =>4182948
  );
END $_$;

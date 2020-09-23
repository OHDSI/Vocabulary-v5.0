--add new vocabulary
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Cancer Modifier',
	pVocabulary_name		=> 'Diagnostic Modifiers of Cancer (OMOP)',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--add new concept_classes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Topography',
	pConcept_class_name	=>'Cancer topography and anatomical site'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Margin',
	pConcept_class_name	=>'Tumor resection margins and involvement by cancer cells'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Nodes',
	pConcept_class_name	=>'Lymph node metastases'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Staging/Grading',
	pConcept_class_name	=>'Official Grade or Stage System'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Extension/Invasion',
	pConcept_class_name	=>'Local cancer growth and invasion into adjacent tissue and organs'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Dimension',
	pConcept_class_name	=>'Tumor size and dimension'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Histopattern',
	pConcept_class_name	=>'Histological patterns of cancer tissue'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Metastasis',
	pConcept_class_name	=>'Distant metastases'
);
END $_$;

--rename classes Disease Episode -> Disease Extent, Treatment Episode -> Treatment [AVOF-2817]
DO $$
DECLARE
	cOldClass constant varchar(100):='Disease Episode';
	cNewClass constant varchar(100):='Disease Extent';
begin
	alter table concept drop constraint fpk_concept_class;
	update concept set concept_name=cNewClass where domain_id='Metadata' and vocabulary_id='Concept Class' and concept_name=cOldClass;
	update concept_class set concept_class_id=cNewClass, concept_class_name=cNewClass where concept_class_id=cOldClass;
	update concept set concept_class_id=cNewClass where concept_class_id=cOldClass;
	update concept_class_conversion set concept_class_id_new=cNewClass where concept_class_id_new=cOldClass;
	alter table concept add constraint fpk_concept_class foreign key (concept_class_id) references concept_class (concept_class_id);
END $$;

DO $$
DECLARE
	cOldClass constant varchar(100):='Treatment Episode';
	cNewClass constant varchar(100):='Treatment';
begin
	alter table concept drop constraint fpk_concept_class;
	update concept set concept_name=cNewClass where domain_id='Metadata' and vocabulary_id='Concept Class' and concept_name=cOldClass;
	update concept_class set concept_class_id=cNewClass, concept_class_name=cNewClass where concept_class_id=cOldClass;
	update concept set concept_class_id=cNewClass where concept_class_id=cOldClass;
	update concept_class_conversion set concept_class_id_new=cNewClass where concept_class_id_new=cOldClass;
	alter table concept add constraint fpk_concept_class foreign key (concept_class_id) references concept_class (concept_class_id);
END $$;

--add new concept_class_id='Disease Dynamic' [AVOF-2817]
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConceptClass(
	pConcept_class_id       =>'Disease Dynamic',
	pConcept_class_name     =>'Disease Dynamic'
);
END $_$;

--add new manual concepts [AVOF-2817]
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Cancer Surgery',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Treatment',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Cancer Radiotherapy',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Treatment',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Cancer Drug Treatment',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Treatment',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Confined Disease',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Disease Extent',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Invasive Disease',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Disease Extent',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Metastatic Disease',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Disease Extent',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Remission',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Disease Dynamic',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Complete Remission',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Disease Dynamic',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Partial Remission',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Disease Dynamic',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Stable Disease',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Disease Dynamic',
	pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
	pConcept_name     =>'Progression',
	pDomain_id        =>'Episode',
	pVocabulary_id    =>'OMOP Extension',
	pConcept_class_id =>'Disease Dynamic',
	pStandard_concept =>'S'
);
END $_$;
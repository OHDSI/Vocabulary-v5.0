--rename SNOMED relationship [AVOF-2184]

--'Has property (SNOMED)' > 'Has property'
do $$
declare
	rel_concept_id int4:=44818772;
begin
	update concept c set concept_name=r.relationship_id
	from relationship r
	where r.relationship_concept_id=c.concept_id
	and r.relationship_concept_id=rel_concept_id;
	
	update relationship r set relationship_name=r.relationship_id where r.relationship_concept_id=rel_concept_id;
	
	--reverse
	update concept c set concept_name=r.relationship_id
	from (
		select r2.* from relationship r1, relationship r2
		where r1.relationship_concept_id=rel_concept_id
		and r2.relationship_id=r1.reverse_relationship_id
	) r
	where r.relationship_concept_id=c.concept_id;
	
	update relationship r set relationship_name=r.relationship_id
	from relationship r1
	where r1.relationship_concept_id=rel_concept_id
	and r.relationship_id=r1.reverse_relationship_id;
end $$;

--new vocabulary='KNHIS' [AVOF-2186]
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'KNHIS',
	pVocabulary_name		=> 'Korean National Health Information System',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--new vocabulary='Korean Revenue Code'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Korean Revenue Code',
	pVocabulary_name		=> 'Korean Revenue Code',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> 'Y',
	pClick_default			=> 'Y', --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--new Korean concepts
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'National Health Insurance Program',
                            pDomain_id        =>'Payer',
                            pVocabulary_id    =>'KNHIS',
                            pConcept_class_id =>'Payer',
                            pStandard_concept =>'S',
                            pConcept_code     =>'1'
                        ),
    pSynonym_name        =>'건강보험',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Medical Aid program type 1',
                            pDomain_id        =>'Payer',
                            pVocabulary_id    =>'KNHIS',
                            pConcept_class_id =>'Payer',
                            pStandard_concept =>'S',
                            pConcept_code     =>'2'
                        ),
    pSynonym_name        =>'의료급여 1종',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Medical Aid program type 2',
                            pDomain_id        =>'Payer',
                            pVocabulary_id    =>'KNHIS',
                            pConcept_class_id =>'Payer',
                            pStandard_concept =>'S',
                            pConcept_code     =>'3'
                        ),
    pSynonym_name        =>'의료급여 2종',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Medication and administration fees - general classification',
                            pDomain_id        =>'Revenue Code',
                            pVocabulary_id    =>'Korean Revenue Code',
                            pConcept_class_id =>'Revenue Code',
                            pStandard_concept =>'S',
                            pConcept_code     =>'3'
                        ),
    pSynonym_name        =>'투약료',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Medication/medical supplies and injection fees (IM/SC/IV/others) - general classification',
                            pDomain_id        =>'Revenue Code',
                            pVocabulary_id    =>'Korean Revenue Code',
                            pConcept_class_id =>'Revenue Code',
                            pStandard_concept =>'S',
                            pConcept_code     =>'4'
                        ),
    pSynonym_name        =>'주사료',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Fees for procedure or surgery - General Classification',
                            pDomain_id        =>'Revenue Code',
                            pVocabulary_id    =>'Korean Revenue Code',
                            pConcept_class_id =>'Revenue Code',
                            pStandard_concept =>'S',
                            pConcept_code     =>'8'
                        ),
    pSynonym_name        =>'처치 및 수술료',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Examination fees - General Classification',
                            pDomain_id        =>'Revenue Code',
                            pVocabulary_id    =>'Korean Revenue Code',
                            pConcept_class_id =>'Revenue Code',
                            pStandard_concept =>'S',
                            pConcept_code     =>'9'
                        ),
    pSynonym_name        =>'검사료',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Medical charge of flat rate(palliative care) - General Classification',
                            pDomain_id        =>'Revenue Code',
                            pVocabulary_id    =>'Korean Revenue Code',
                            pConcept_class_id =>'Revenue Code',
                            pStandard_concept =>'S',
                            pConcept_code     =>'11'
                        ),
    pSynonym_name        =>'요양병원 호스피스 정액',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Medication cost - General classification',
                            pDomain_id        =>'Revenue Code',
                            pVocabulary_id    =>'Korean Revenue Code',
                            pConcept_class_id =>'Revenue Code',
                            pStandard_concept =>'S',
                            pConcept_code     =>'15'
                        ),
    pSynonym_name        =>'의약품',
    pLanguage_concept_id =>4175771
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewSynonym(
    pConcept_id          =>vocabulary_pack.AddNewConcept(
                            pConcept_name     =>'Medical practice fees - General classification',
                            pDomain_id        =>'Revenue Code',
                            pVocabulary_id    =>'Korean Revenue Code',
                            pConcept_class_id =>'Revenue Code',
                            pStandard_concept =>'S',
                            pConcept_code     =>'16'
                        ),
    pSynonym_name        =>'진료행위',
    pLanguage_concept_id =>4175771
);
END $_$;
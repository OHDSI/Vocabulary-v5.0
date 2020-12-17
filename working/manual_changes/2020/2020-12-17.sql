--add new UCUM concepts
DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'per meter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'/m'
);

PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'Decibel per megahertz',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'dB/MHz'
);

PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'decisecond',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'ds'
);

PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'kilojoule',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'kJ'
);

PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'liter per square meter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'L/m2'
);

PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'microgram per cubic meter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'ug/m3'
);

PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'nanogram per microliter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'ng/uL'
);
END $_$;

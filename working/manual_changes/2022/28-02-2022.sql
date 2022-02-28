DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'milliliter per kilogram per minute ',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'ml/kg/min'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'nanogram per kilogram per minute',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'ng/kg/min'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'wood unit per square meter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'[wood''U]/m2'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'dyne-second per centimeter to the fifth power per square meter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'dyn.s/cm5/m2'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'million per kilogram',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'10*6/kg'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'millivolt',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mV'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'kilojoule per mole',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'kJ/mol'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'kilojoule/mole',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'kJ/mol'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'kiloarbitary unit per liter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'10*3[arb''U]/L'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'gram per 48 hours',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'g/(48.h)'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'unit per 10 to the 10th power cells',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'U/10*10.{cells}'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'pack per day',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'pack/(24.h)'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'micrometer per second',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'um/s'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'picogram per gram of creatinine',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'pg/g{creat}'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'nanomole per minute per mg of protein',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'nmol/min/mg{protein}'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'cells per 7.5 mililiters',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'{cells}/(75.10*-1.mL)'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'femtoliter per nanoliter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'fL/nL'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'unit per kilogram',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'U/kg{Hb}'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'unit per 2 hours',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'U/(2.h)'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'threshold cycle value',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'{Ct_value}'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'milliliter per pound (US)',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mL/[lb_us]'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'millibar',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mbar'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'nanogram per nanogram',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'ng/ng'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'free thyroxine index',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'{FTI%}'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'milligram per deciliter per 24 hours',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mg/dL/(24.h)'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'picogram per milligram of creatinine',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'pg/mg{creat}'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'picomole per hour per microliter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'pmol/hr/uL'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'nanomole per 24 hours per milligram',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'nmol/(24.h)/mg'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'milliliter per millibar',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'ml/mbar'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'millibar per centimeter of water',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'ml/cm [H2O]'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'millibar per liter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mbar/L'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'fraction',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'{fraction}'
);
END $_$;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'milliliter per second per 1.73 square meter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mL/s/(173.10*-2.m2)'
);
END $_$;

--Manual update for concept_id=9117
UPDATE concept
SET  valid_end_date = CURRENT_DATE,
	 invalid_reason = 'D'
WHERE concept_id = 9117
;

DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'milliliter per minute per 1.73 square meter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mL/min/(173.10*-2.m2)'
);
END $_$;

WITH new_rel
AS (
	SELECT c1.concept_id AS c_id1,
		c2.concept_id AS c_id2
	FROM concept c1
	JOIN concept c2 ON c2.concept_code = 'mL/min/(173.10*-2.m2)'
		AND c2.vocabulary_id = 'UCUM'
	WHERE c1.concept_code = 'mL/min/1.73.m2'
		AND c1.vocabulary_id = 'UCUM'
	)
INSERT INTO concept_relationship (
		SELECT nr.c_id1,
	nr.c_id2,
	'Concept replaced by',
	CURRENT_DATE,
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL FROM new_rel nr
UNION ALL
	--reverse
	SELECT nc.c_id2,
	nc.c_id1,
	'Concept replaces',
	CURRENT_DATE,
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL FROM new_rel nc
);
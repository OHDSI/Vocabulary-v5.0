DO $_$
BEGIN
	--Add new UCUM concepts
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'milliliter per kilogram per minute ',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'ml/kg/min'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'nanogram per kilogram per minute',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'ng/kg/min'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'wood unit per square meter',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'[wood''U]/m2'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'dyne-second per centimeter to the fifth power per square meter',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'dyn.s/cm5/m2'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'million per kilogram',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'10*6/kg'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'millivolt',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'mV'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'kilojoule per mole',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'kJ/mol'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'kiloarbitary unit per liter',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'10*3[arb''U]/L'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'gram per 48 hours',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'g/(48.h)'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'unit per 10 to the 10th power cells',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'U/10*10.{cells}'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'pack per day',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'pack/(24.h)'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'micrometer per second',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'um/s'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'picogram per gram of creatinine',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'pg/g{creat}'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'nanomole per minute per mg of protein',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'nmol/min/mg{protein}'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'cells per 7.5 mililiters',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'{cells}/(75.10*-1.mL)'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'femtoliter per nanoliter',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'fL/nL'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'unit per kilogram of hemoglobin',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'U/kg{Hb}'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'unit per 2 hours',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'U/(2.h)'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'threshold cycle value',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'{Ct_value}'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'milliliter per pound (US)',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'mL/[lb_us]'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'millibar',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'mbar'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'nanogram per nanogram',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'ng/ng'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'free thyroxine index',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'{FTI%}'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'milligram per deciliter per 24 hours',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'mg/dL/(24.h)'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'picogram per milligram of creatinine',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'pg/mg{creat}'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'picomole per hour per microliter',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'pmol/hr/uL'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'nanomole per 24 hours per milligram',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'nmol/(24.h)/mg'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'milliliter per millibar',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'ml/mbar'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'millibar per centimeter of water',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'ml/cm [H2O]'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'millibar per liter',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'mbar/L'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'fraction',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'{fraction}'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'milliliter per second per 1.73 square meter',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'mL/s/(173.10*-2.m2)'
	);

	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name =>'milliliter per minute per 1.73 square meter',
		pDomain_id =>'Unit',
		pVocabulary_id =>'UCUM',
		pConcept_class_id =>'Unit',
		pStandard_concept =>'S',
		pConcept_code =>'mL/min/(173.10*-2.m2)'
	);

	--Manual update for concept_id=9117
	UPDATE concept
	SET valid_end_date = CURRENT_DATE,
		invalid_reason = 'U', --we want to replace this concept with a new one
		standard_concept = NULL
	WHERE concept_id = 9117;

	--Do a replace and a new mapping
	WITH new_rel
	AS (
		SELECT 9117 AS c_id1,
			(
				SELECT concept_id AS c_id2
				FROM concept
				WHERE concept_code = 'mL/min/(173.10*-2.m2)'
					AND vocabulary_id = 'UCUM'
				)
		)
	INSERT INTO concept_relationship (
		SELECT nr.c_id1,
		nr.c_id2,
		'Concept replaced by',
		CURRENT_DATE,
		TO_DATE('20991231', 'YYYYMMDD'),
		NULL FROM new_rel nr

	UNION ALL
		
		SELECT nr.c_id1,
		nr.c_id2,
		'Maps to',
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

	UNION ALL
		
		SELECT nr.c_id2,
		nr.c_id1,
		'Mapped from',
		CURRENT_DATE,
		TO_DATE('20991231', 'YYYYMMDD'),
		NULL FROM new_rel nr
		);

	--Deprecate old mappings from/to concept_id = 9117 ('Maps to'/'Mapped from' to self and to concept_id=9062)
	UPDATE concept_relationship
	SET valid_end_date = CURRENT_DATE,
		invalid_reason = 'D' --we want to replace this concept with a new one
	WHERE concept_id_1 = 9117
		AND concept_id_2 = 9117;

	UPDATE concept_relationship
	SET valid_end_date = CURRENT_DATE,
		invalid_reason = 'D' --we want to replace this concept with a new one
	WHERE concept_id_1 IN (
			9117,
			9062
			)
		AND concept_id_2 IN (
			9117,
			9062
			)
		AND relationship_id IN (
			'Maps to',
			'Mapped from'
			);

	--Add fresh mapping from concept_id=9062 to new UCUM concept
	WITH new_rel
	AS (
		SELECT 9062 AS c_id1,
			(
				SELECT concept_id AS c_id2
				FROM concept
				WHERE concept_code = 'mL/min/(173.10*-2.m2)'
					AND vocabulary_id = 'UCUM'
				)
		)
	INSERT INTO concept_relationship (
		SELECT nr.c_id1,
		nr.c_id2,
		'Maps to',
		CURRENT_DATE,
		TO_DATE('20991231', 'YYYYMMDD'),
		NULL FROM new_rel nr

	UNION ALL

		--reverse
		SELECT nc.c_id2,
		nc.c_id1,
		'Mapped from',
		CURRENT_DATE,
		TO_DATE('20991231', 'YYYYMMDD'),
		NULL FROM new_rel nc
		);
END $_$;
TRUNCATE TABLE concept_synonym_stage;

INSERT INTO concept_synonym_stage (
	synonym_concept_id,
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT NULL::int4,
	ingredient,
	ingredient_code,
	'AMIS',
	4182504
FROM ingredient_translation_all

UNION

SELECT NULL::int4,
	form,
	concept_code,
	'AMIS',
	4182504
FROM form_translation_all a
JOIN dcs_form c ON a.form = c.concept_name;

TRUNCATE TABLE relationship_to_concept;

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code,
	'AMIS',
	concept_id_2,
	precedence,
	NULL::FLOAT
FROM aut_ingr_all_mapped

UNION ALL

SELECT concept_code,
	'AMIS',
	concept_id_2,
	precedence,
	NULL::FLOAT
FROM aut_form_all_mapped
JOIN drug_concept_stage ON concept_name_1 = concept_name
	AND concept_class_id = 'Dose Form'

UNION ALL

SELECT concept_code,
	'AMIS',
	concept_id_2,
	PRECEDENCE,
	conversion_factor
FROM aut_unit_all_mapped

UNION ALL

SELECT concept_code,
	'AMIS',
	concept_id_2,
	precedence,
	NULL::FLOAT
FROM aut_brand_all_mapped
JOIN dcs_bn ON concept_name = concept_name_1;


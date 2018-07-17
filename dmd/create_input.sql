-- Todo:
-- drug_strength
-- Brands
-- mapping Ingredients
-- mapping Forms
-- mapping units

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'dm+d',
	pVocabularyDate			=> TO_DATE('20160325','YYYYMMDD'),
	pVocabularyVersion		=> 'dm+d Version 3.2.0',
	pVocabularyDevSchema	=> 'DEV_DMD'
);
END $_$;

-- 2. Create drug_concept_stage

DROP TABLE IF EXISTS drug_concept_stage;
CREATE TABLE drug_concept_stage AS
SELECT *
FROM concept_stage
WHERE 1 = 0;

ALTER TABLE drug_concept_stage ADD COLUMN insert_id INT,
	ADD COLUMN source_concept_class_id VARCHAR(20);

INSERT INTO drug_concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	insert_id,
	source_concept_class_id
	)
--Forms
SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Dose Form' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./CD/text()', i.xmlfield))::VARCHAR concept_code,
	to_date(coalesce(l.valid_start_date, '1970-01-01'), 'YYYY-MM-DD') valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	3 AS insert_id,
	'Form' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/LOOKUP/FORM/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i
LEFT JOIN lateral(SELECT unnest(xpath('./CDDT/text()', i.xmlfield))::VARCHAR valid_start_date) l ON true

UNION ALL

--deprecated Forms
SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Dose Form' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./CDPREV/text()', i.xmlfield))::VARCHAR concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	to_date(unnest(xpath('./CDDT/text()', i.xmlfield))::VARCHAR, 'YYYY-MM-DD') - 1 valid_end_date,
	'U' AS invalid_reason,
	4 AS insert_id,
	'Form' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/LOOKUP/FORM/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i

UNION ALL

--Ingredients
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./ISID/text()', i.xmlfield))::VARCHAR concept_code,
	to_date(coalesce(l.valid_start_date, '1970-01-01'), 'YYYY-MM-DD') valid_start_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'dm+d'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason,
	7 AS insert_id,
	'Ingredient' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/INGREDIENT_SUBSTANCES/ING', i.xmlfield)) xmlfield
	FROM sources.f_ingredient2 i
	) AS i
LEFT JOIN lateral(SELECT unnest(xpath('./ISIDDT/text()', i.xmlfield))::VARCHAR valid_start_date) l ON true
LEFT JOIN lateral(SELECT unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR invalid) l1 ON true

UNION ALL

--deprecated Ingredients
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./ISIDPREV/text()', i.xmlfield))::VARCHAR concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	to_date(unnest(xpath('./ISIDDT/text()', i.xmlfield))::VARCHAR, 'YYYY-MM-DD') - 1 valid_end_date,
	'U' AS invalid_reason,
	8 AS insert_id,
	'Ingredient' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/INGREDIENT_SUBSTANCES/ING', i.xmlfield)) xmlfield
	FROM sources.f_ingredient2 i
	) AS i

UNION ALL

--VTMs (Ingredients)
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./VTMID/text()', i.xmlfield))::VARCHAR concept_code,
	to_date(coalesce(l.valid_start_date, '1970-01-01'), 'YYYY-MM-DD') valid_start_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'dm+d'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason,
	9 AS insert_id,
	'VTM' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/VIRTUAL_THERAPEUTIC_MOIETIES/VTM', i.xmlfield)) xmlfield
	FROM sources.f_vtm2 i
	) AS i
LEFT JOIN lateral(SELECT unnest(xpath('./VTMIDDT/text()', i.xmlfield))::VARCHAR valid_start_date) l ON true
LEFT JOIN lateral(SELECT unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR invalid) l1 ON true

UNION ALL

--deprecated VTMs
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./VTMIDPREV/text()', i.xmlfield))::VARCHAR concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	to_date(unnest(xpath('./VTMIDDT/text()', i.xmlfield))::VARCHAR, 'YYYY-MM-DD') - 1 valid_end_date,
	'U' AS invalid_reason,
	10 AS insert_id,
	'VTM' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/VIRTUAL_THERAPEUTIC_MOIETIES/VTM', i.xmlfield)) xmlfield
	FROM sources.f_vtm2 i
	) AS i

UNION ALL

--VMPs (generic or clinical drugs)
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Clinical Drug' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR concept_code,
	to_date(coalesce(l.valid_start_date, '1970-01-01'), 'YYYY-MM-DD') valid_start_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'dm+d'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason,
	11 AS insert_id,
	'VMP' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/VMPS/VMP', i.xmlfield)) xmlfield
	FROM sources.f_vmp2 i
	) AS i
LEFT JOIN lateral(SELECT unnest(xpath('./VTMIDDT/text()', i.xmlfield))::VARCHAR valid_start_date) l ON true
LEFT JOIN lateral(SELECT unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR invalid) l1 ON true

UNION ALL

--deprecated VMPs
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Clinical Drug' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./VPIDPREV/text()', i.xmlfield))::VARCHAR concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	to_date(unnest(xpath('./VPIDDT/text()', i.xmlfield))::VARCHAR, 'YYYY-MM-DD') - 1 valid_end_date,
	'U' AS invalid_reason,
	12 AS insert_id,
	'VMP' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/VMPS/VMP', i.xmlfield)) xmlfield
	FROM sources.f_vmp2 i
	) AS i

UNION ALL

-- AMPs (branded drugs)
SELECT substr(devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::TEXT), 1, 255) concept_name,
	CASE l2.domain_id
		WHEN '0002'
			THEN 'Device'
		WHEN '0000'
			THEN 'Unknown'
		WHEN '0003'
			THEN 'Unknown'
		ELSE 'Drug'
		END AS domain_id,
	'dm+d' AS vocabulary_id,
	'Branded Drug' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./APID/text()', i.xmlfield))::VARCHAR concept_code,
	to_date(coalesce(l.valid_start_date, '1970-01-01'), 'YYYY-MM-DD') valid_start_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'dm+d'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason,
	13 AS insert_id,
	'AMP' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP', i.xmlfield)) xmlfield
	FROM sources.f_amp2 i
	) AS i
LEFT JOIN lateral(SELECT unnest(xpath('./NMDT/text()', i.xmlfield))::VARCHAR valid_start_date) l ON true
LEFT JOIN lateral(SELECT unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR invalid) l1 ON true
LEFT JOIN lateral(SELECT unnest(xpath('./LIC_AUTHCD/text()', i.xmlfield))::VARCHAR domain_id) l2 ON true

UNION ALL

--VMPPs (Clinical Drug Box)
SELECT substr(devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::TEXT), 1, 255) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Clinical Drug Box' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./VPPID/text()', i.xmlfield))::VARCHAR concept_code,
	TO_DATE('19700101', 'YYYYMMDD') valid_start_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'dm+d'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason,
	14 AS insert_id,
	'VMPP' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCT_PACK/VMPPS/VMPP', i.xmlfield)) xmlfield
	FROM sources.f_vmpp2 i
	) AS i
LEFT JOIN lateral(SELECT unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR invalid) l1 ON true

UNION ALL

--AMPPs (Branded Drug Box)
SELECT substr(devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::TEXT), 1, 255) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Branded Drug Box' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./APPID/text()', i.xmlfield))::VARCHAR concept_code,
	TO_DATE('19700101', 'YYYYMMDD') valid_start_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'dm+d'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN l1.invalid = '1'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason,
	15 AS insert_id,
	'AMPP' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP', i.xmlfield)) xmlfield
	FROM sources.f_ampp2 i
	) AS i
LEFT JOIN lateral(SELECT unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR invalid) l1 ON true

UNION ALL

--Suppliers
SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::TEXT) concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Supplier' AS concept_class_id,
	NULL AS standard_concept,
	unnest(xpath('./CD/text()', i.xmlfield))::VARCHAR concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	16 AS insert_id,
	'Supplier' AS source_concept_class_id
FROM (
	SELECT unnest(xpath('/LOOKUP/SUPPLIER/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i;

-- Delete duplicates, first of all concepts with invalid_reason='D', then 'U', last of all 'NULL'
DELETE
FROM drug_concept_stage csd
WHERE NOT EXISTS (
		SELECT 1
		FROM (
			SELECT LAST_VALUE(ctid) OVER (
					PARTITION BY concept_code ORDER BY invalid_reason,
						ctid ROWS BETWEEN UNBOUNDED PRECEDING
							AND UNBOUNDED FOLLOWING
					) AS i_ctid
			FROM drug_concept_stage
			) i
		WHERE i.i_ctid = csd.ctid
		);

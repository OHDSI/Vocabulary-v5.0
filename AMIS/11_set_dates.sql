UPDATE drug_concept_stage
SET valid_start_date = TO_DATE('19700101', 'yyyymmdd');

UPDATE drug_concept_stage dcs
SET valid_start_date = TO_DATE(d.bdzul, 'dd.mm.yyyy')
FROM (
	SELECT enr,
		bdzul
	FROM source_table
	) d
WHERE d.enr = dcs.concept_code;
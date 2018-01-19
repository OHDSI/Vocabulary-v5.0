update drug_concept_stage set valid_start_date = TO_DATE('1970/01/01', 'yyyy/mm/dd');

MERGE
INTO    drug_concept_stage dcs
USING   (
select enr, bdzul FROM source_table
) d ON (d.enr=dcs.concept_code)
WHEN MATCHED THEN UPDATE
    SET dcs.valid_start_date =  TO_DATE(d.bdzul, 'dd.mm.yyyy')
;
truncate table ds_stage;

INSERT INTO ds_stage 
SELECT distinct
drug_code as drug_concept_code,
nvl(c.concept_code, a.ingredient_Code) as  ingredient_concept_code,
box_size, amount_value, amount_unit, numerator_value, numerator_unit, denominator_value, denominator_unit FROM strength_tmp a 
LEFT JOIN (select b.concept_code_1 as ns_ingredient_code, c.concept_code from internal_relationship_stage b left join drug_concept_stage c on c.concept_Code=b.concept_code_2 AND c.standard_concept='S') c ON c.ns_ingredient_code = a.ingredient_Code;

--
MERGE
INTO ds_stage ds
USING   (
select distinct
  a.drug_concept_code,
  a.INGREDIENT_CONCEPT_CODE,
  a.box_size,
  a.amount_value,
  a.amount_unit,
  case 
    when a.numerator_unit=b.numerator_unit then a.numerator_value+b.numerator_value 
    when a.numerator_unit='m'||b.numerator_unit then a.numerator_value+1000*b.numerator_value 
    when 'm'||a.numerator_unit=b.numerator_unit then 1000*a.numerator_value+b.numerator_value 
  end as numerator_value,
  case 
    when a.numerator_unit=b.numerator_unit then a.numerator_unit 
    when a.numerator_unit='m'||b.numerator_unit then a.numerator_unit 
    when 'm'||a.numerator_unit=b.numerator_unit then b.numerator_unit
  end as numerator_unit,
  a.denominator_value,
  a.denominator_unit
from ds_stage a join ds_stage b on a.drug_concept_code = b.drug_concept_code and a.INGREDIENT_CONCEPT_CODE = b.INGREDIENT_CONCEPT_CODE and (a.rowid != b.rowid) AND 
a.DENOMINATOR_VALUE = b.DENOMINATOR_VALUE AND a.DENOMINATOR_unit = b.DENOMINATOR_unit
 ) d ON (d.drug_concept_code=ds.drug_concept_code AND d.INGREDIENT_CONCEPT_CODE=ds.INGREDIENT_CONCEPT_CODE)
WHEN MATCHED THEN UPDATE
  SET ds.numerator_value=d.numerator_value, ds.numerator_unit=d.numerator_unit;

delete from ds_stage where rowid in (
select ds.rowid from ds_stage ds JOIN (
select drug_concept_code, INGREDIENT_CONCEPT_CODE, MAX(rowid) mr from ds_stage GROUP BY drug_concept_code, INGREDIENT_CONCEPT_CODE HAVING count(1) > 1) mds USING (drug_concept_code, INGREDIENT_CONCEPT_CODE)
WHERE ds.rowid < mds.mr);

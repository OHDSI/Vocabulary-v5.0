INSERT INTO STRENGTH_TMP
(DRUG_CODE, INGREDIENT_CODE, INGREDIENT_NAME, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE, NUMERATOR_UNIT, DENOMINATOR_VALUE, DENOMINATOR_UNIT)

SELECT DISTINCT DRUG_CODE, INGREDIENT_CODE, INGREDIENT,

--  EXEC :regexp01 := '(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)';  
  -- If BMn contains 'Stueck' then 'DOSAGE_VALUE' and
  -- 'DOSAGE_UNIT' goes to 'AMOUNT_VALUE' and 'AMOUNT_UNIT' respectively
  CASE
    WHEN BM_N like '%tueck%' THEN DOSAGE_VALUE
    ELSE NULL
  END as AMOUNT_VALUE,
  CASE
    WHEN BM_N like '%tueck%' THEN DOSAGE_UNIT
    ELSE NULL
  END as AMOUNT_UNIT,

  CASE
    WHEN BM_N not like '%tueck%' and regexp_like(DRUG_COMPONENT_PREPRECESSED, '[[:digit:]\.]+\s*[[:alpha:]]+/\s*[[:digit:]\.]+\s*[[:alpha:]]+') THEN
      TO_BINARY_DOUBLE(REGEXP_SUBSTR(REGEXP_SUBSTR(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[[:digit:]\.]+\s*[[:alpha:]]+/\s*[[:digit:]\.]+\s*[[:alpha:]]+'),
      '^[^/]+'),
      '[[:digit:]\.]+'))
    WHEN BM_N not like '%tueck%' THEN DOSAGE_VALUE
      
    ELSE NULL
  END as NUMERATOR_VALUE,
  CASE
    WHEN BM_N not like '%tueck%' and regexp_like(DRUG_COMPONENT_PREPRECESSED, '[[:digit:]\.]+\s*[[:alpha:]]+/\s*[[:digit:]\.]+\s*[[:alpha:]]+') THEN
      REGEXP_SUBSTR(REGEXP_SUBSTR(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[[:digit:]\.]+\s*[[:alpha:]]+/\s*[[:digit:]\.]+\s*[[:alpha:]]+'),
      '^[^/]+'),
      '[[:alpha:]]+')
    WHEN BM_N not like '%tueck%' THEN DOSAGE_UNIT
    ELSE NULL
  END as NUMERATOR_UNIT,

  CASE
    WHEN BM_N not like '%tueck%' and regexp_like(DRUG_COMPONENT_PREPRECESSED, '[[:digit:]\.]+\s*[[:alpha:]]+/\s*[[:digit:]\.]+\s*[[:alpha:]]+') THEN
      TO_BINARY_DOUBLE(REGEXP_SUBSTR(REGEXP_SUBSTR(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[[:digit:]\.]+\s*[[:alpha:]]+/\s*[[:digit:]\.]+\s*[[:alpha:]]+'),
      '[^/]+$'),
      '[[:digit:]\.]+'))
    WHEN BM_N not like '%tueck%' THEN
      TO_BINARY_DOUBLE(REGEXP_REPLACE(
      REGEXP_SUBSTR(REGEXP_SUBSTR(bm_n, '([[:digit:]\.]+)\s*(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)', 1, 1, 'i'),
      '[[:digit:]\.]+'),
      '(^\.$|^$)', '0'))
    ELSE NULL
  END as DENOMINATOR_VALUE,
  CASE
    WHEN BM_N not like '%tueck%' and regexp_like(DRUG_COMPONENT_PREPRECESSED, '[[:digit:]\.]+\s*[[:alpha:]]+/\s*[[:digit:]\.]+\s*[[:alpha:]]+') THEN
      REGEXP_SUBSTR(REGEXP_SUBSTR(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[[:digit:]\.]+\s*[[:alpha:]]+/\s*[[:digit:]\.]+\s*[[:alpha:]]+'),
      '[^/]+$'),
      '[[:alpha:]]+')
    WHEN BM_N not like '%tueck%' THEN
      REGEXP_SUBSTR(REGEXP_SUBSTR(bm_n, '([[:digit:]\.]+)\s*(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)', 1, 1, 'i'),
      '(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)', 1, 1, 'i')
    ELSE NULL
  END as DENOMINATOR_UNIT
  
FROM DENORM_LIST;
--OFFSET 0 ROWS FETCH NEXT 500 ROWS ONLY;


-- update for cases when bm2 contains ampule size. set denominator

MERGE
INTO    STRENGTH_TMP st
USING   (
select distinct dl.DRUG_CODE,
dl.INGREDIENT_CODE,
TO_BINARY_DOUBLE(TRIM(TRIM(TRAILING '.' FROM REGEXP_REPLACE(
      REGEXP_SUBSTR(REGEXP_SUBSTR(BM2, '([[:digit:]\.]+)\s*(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)', 1, 1, 'i'),
      '[[:digit:]\.]+'),
      '(^\.$|^$)', '0')))) denom_value,
      
 REGEXP_SUBSTR(REGEXP_SUBSTR(BM2, '([[:digit:]\.]+)\s*(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)', 1, 1, 'i'),
      '(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)', 1, 1, 'i') denom_unit
from denorm_list dl JOIN Source_table st ON st.enr=dl.drug_code where st.BM2 is not null and st.WSSTF2_1 is null
) d ON (d.DRUG_CODE=st.DRUG_CODE AND d.INGREDIENT_CODE=st.INGREDIENT_CODE AND d.denom_value IS NOT NULL)
WHEN MATCHED THEN UPDATE
    SET st.DENOMINATOR_UNIT = d.denom_unit, st.DENOMINATOR_VALUE = TO_BINARY_DOUBLE(d.denom_value)
;
















-- update for cases when wsstf2_1 is absent but wsstf3_1 is present. In this case STRENGTH_TMP has several records with different denominator. ml is more appreciated
DELETE FROM STRENGTH_TMP WHERE rowid IN (
SELECT st.rowid from STRENGTH_TMP st JOIN 
(Select DRUG_CODE, INGREDIENT_CODE, LISTAGG(DENOMINATOR_UNIT, ', ') WITHIN GROUP (ORDER BY DENOMINATOR_UNIT) "units" from STRENGTH_TMP group by DRUG_CODE, INGREDIENT_CODE having count(*) > 1) d
ON d.DRUG_CODE=st.DRUG_CODE AND d.INGREDIENT_CODE=st.INGREDIENT_CODE AND REGEXP_LIKE(d."units", 'ml', 'i')
WHERE NOT REGEXP_LIKE(st.DENOMINATOR_UNIT, 'ml', 'i'));

--deleting homeopathic drugs with different dosage in single ingredient
DELETE FROM strength_tmp WHERE rowid IN (
SELECT st.rowid FROM strength_tmp st JOIN (
select ingredient_code, drug_code, MIN(numerator_value) m from strength_tmp WHERE numerator_unit = 'D' group by ingredient_code, drug_code ) d 
ON d.ingredient_code=st.ingredient_code AND d.drug_code=st.drug_code
WHERE numerator_unit = 'D' AND numerator_value > m);

--manual updates
--bacterial units
UPDATE STRENGTH_TMP   SET NUMERATOR_VALUE = 1.2,       NUMERATOR_UNIT = 'g' WHERE DRUG_CODE = '232696' AND   INGREDIENT_CODE = '05574-6';
UPDATE STRENGTH_TMP  SET NUMERATOR_UNIT = 'UNT' WHERE DRUG_CODE = '2602431' AND   INGREDIENT_CODE = '31524-8';
UPDATE STRENGTH_TMP   SET NUMERATOR_UNIT = 'UNT' WHERE DRUG_CODE = '2602489' AND   INGREDIENT_CODE = '34463-5';
UPDATE STRENGTH_TMP   SET NUMERATOR_UNIT = 'UNT' WHERE DRUG_CODE = '2602489' AND   INGREDIENT_CODE = '34464-0';
UPDATE STRENGTH_TMP   SET NUMERATOR_UNIT = 'UNT' WHERE DRUG_CODE = '2602489' AND   INGREDIENT_CODE = '34465-6';
UPDATE STRENGTH_TMP  SET NUMERATOR_UNIT = 'UNT' WHERE DRUG_CODE = '2602489' AND   INGREDIENT_CODE = '34466-1';
UPDATE STRENGTH_TMP   SET NUMERATOR_UNIT = 'UNT' WHERE DRUG_CODE = '2603252' AND   INGREDIENT_CODE = '31427-0';
--Macrogols
DELETE FROM STRENGTH_TMP WHERE DRUG_CODE = '2113817' AND   INGREDIENT_CODE = '00265-2';
UPDATE STRENGTH_TMP   SET NUMERATOR_VALUE = 0.52 WHERE DRUG_CODE = '2113817' AND   INGREDIENT_CODE = '00265-2';
--impfdoses in BM1 and BM3
DELETE FROM STRENGTH_TMP WHERE DRUG_CODE = '2604165' AND   INGREDIENT_CODE = '31411-3' AND   NUMERATOR_VALUE = 500;
DELETE FROM STRENGTH_TMP WHERE DRUG_CODE = '2604165' AND   INGREDIENT_CODE = '31412-9' AND   NUMERATOR_VALUE = 500;
DELETE FROM STRENGTH_TMP WHERE DRUG_CODE = '2604165' AND   INGREDIENT_CODE = '31410-8' AND   NUMERATOR_VALUE = 500;
DELETE FROM STRENGTH_TMP WHERE DRUG_CODE = '2604165' AND   INGREDIENT_CODE = '31409-2' AND   NUMERATOR_VALUE = 500;
UPDATE STRENGTH_TMP  SET AMOUNT_VALUE = NULL,      AMOUNT_UNIT = '',       NUMERATOR_VALUE = 2.3,      NUMERATOR_UNIT = 'mg' WHERE DRUG_CODE = '2128247' AND   INGREDIENT_CODE = '18667-1';

--patches
UPDATE STRENGTH_TMP   SET DENOMINATOR_VALUE = 24,      DENOMINATOR_UNIT = 'h' WHERE DRUG_CODE = '2170879' AND   INGREDIENT_CODE = '27668-6';
UPDATE STRENGTH_TMP   SET DENOMINATOR_VALUE = 24,       DENOMINATOR_UNIT = 'h' WHERE DRUG_CODE = '2143617' AND   INGREDIENT_CODE = '27668-6'; 
UPDATE STRENGTH_TMP  SET DENOMINATOR_VALUE = 24,       DENOMINATOR_UNIT = 'h' WHERE DRUG_CODE = '2170878' AND   INGREDIENT_CODE = '27668-6';
UPDATE STRENGTH_TMP   SET DENOMINATOR_VALUE = 24,       DENOMINATOR_UNIT = 'h' WHERE INGREDIENT_CODE = '27668-6' AND   INGREDIENT_NAME = 'Estradiol-Hemihydrat' AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_UNIT = 'mg' AND   DENOMINATOR_VALUE = 5 AND   DENOMINATOR_UNIT = 'cm';


update STRENGTH_TMP   SET AMOUNT_VALUE = NUMERATOR_VALUE,  AMOUNT_UNIT=NUMERATOR_UNIT, NUMERATOR_VALUE = NULL, NUMERATOR_UNIT=NULL WHERE NUMERATOR_VALUE IS NOT NULL AND DENOMINATOR_VALUE IS NULL;
update STRENGTH_TMP   SET AMOUNT_VALUE = NUMERATOR_VALUE / DENOMINATOR_VALUE,  AMOUNT_UNIT=NUMERATOR_UNIT, NUMERATOR_VALUE = NULL, NUMERATOR_UNIT=NULL, DENOMINATOR_VALUE = NULL, DENOMINATOR_UNIT = NULL WHERE regexp_like(denominator_unit, 'dos', 'i');

-- Verify the result

/*SELECT * FROM STRENGTH_TMP
OFFSET 0 ROWS FETCH NEXT 500 ROWS ONLY;*/


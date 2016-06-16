-- Add fields parts, parsed from ''DRUG_COMPONENT'
ALTER TABLE DENORM_LIST
  ADD (INGREDIENT_CODE  VARCHAR2(255 Byte),
       INGREDIENT       VARCHAR2(255 Byte),
       DOSAGE_VALUE     DECIMAL(38,19),
       DOSAGE_UNIT      VARCHAR2(255 Byte),
       DOSAGE_HINT      VARCHAR2(255 Byte)
);

-- Preprocessing of 'DRUG_COMPONENT' - convert floats to format 1.2e07
-- 1st pattern: Looks for occurences of '1.0 x10[E05]', '1. x10(E05)', '1. x10E[05]' and '1. x10E(05)'
-- 2nd pattern: Looks for occurnces of '1. x10^5'

ALTER TABLE DENORM_LIST
  ADD DRUG_COMPONENT_PREPRECESSED  VARCHAR2(1023 Byte);

-- Temporary field
ALTER TABLE DENORM_LIST
  ADD NEW_INGREDIENT VARCHAR2(300 Byte);

UPDATE DENORM_LIST SET DRUG_COMPONENT_PREPRECESSED = DRUG_COMPONENT;
UPDATE DENORM_LIST SET
        DRUG_COMPONENT_PREPRECESSED = REGEXP_REPLACE(DRUG_COMPONENT_PREPRECESSED, '([[:digit:]\.]+)\s*x10E?(\[|\()E?(\d+)(\]|\))', '\1e\3')
WHERE DRUG_COMPONENT like '%x10%';
UPDATE DENORM_LIST SET
        DRUG_COMPONENT_PREPRECESSED = REGEXP_REPLACE(DRUG_COMPONENT_PREPRECESSED, '([[:digit:]\.]+)\s*x10\^(\d+)', '\1e\2')
WHERE DRUG_COMPONENT like '%x10%';

-- Preview parsing expressions. Take note 'NEW_INGREDIENT' contains improved parsing rules
/*
SELECT  TRIM(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[^,]+', 1, 1)) AS INGREDIENT_CODE,
        REGEXP_REPLACE(TRIM(REGEXP_REPLACE(DRUG_COMPONENT_PREPRECESSED, '(^[^,]+,|,[^,]+$)')), '\s+(\(.*$|\[\d.*$|-.*$|''.*$|[[:digit:]\.]+\sH<2>O.*$)') AS NEW_INGREDIENT,
        REGEXP_REPLACE(TRIM(REGEXP_SUBSTR (DRUG_COMPONENT_PREPRECESSED, '[^,]+', 1, 2)), '\s+(\(.*$|-.*$|''.*$|\d+\sH<2>O.*$)') AS INGREDIENT,
        TO_NUMBER(REGEXP_REPLACE(
        REGEXP_SUBSTR(REGEXP_REPLACE(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[^,]+$'), '[[:digit:]\.]+(e\d+)*\s*-'), '[[:digit:]\.]+(e\d+)*', 1, 1),
        '(^\.$|^$)', '0')) AS DOSAGE_VALUE,

        REGEXP_SUBSTR(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[^,]+$'), '[^[:digit:]\.]+$', 1, 1) AS DOSAGE_UNIT,
        TRIM(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '\([[:digit:]\.\:\-]+\)', 1, 1)) AS DOSAGE_HINT, DRUG_COMPONENT

FROM DENORM_LIST
OFFSET 0 ROWS FETCH NEXT 100 ROWS ONLY;
*/

-- Parse 'DRUG_COMPONENT' and update the 'DENORM_LIST' table
UPDATE DENORM_LIST SET
       INGREDIENT_CODE = TRIM(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[^,]+', 1, 1)),
       NEW_INGREDIENT = REGEXP_REPLACE(TRIM(REGEXP_REPLACE(DRUG_COMPONENT_PREPRECESSED, '(^[^,]+,|,[^,]+$)')), '\s+(\(.*$|\[\d.*$|-.*$|''.*$|[[:digit:]\.]+\sH<2>O.*$)'),
       INGREDIENT = REGEXP_REPLACE(TRIM(REGEXP_SUBSTR (DRUG_COMPONENT_PREPRECESSED, '[^,]+', 1, 2)), '\s+(\(.*$|-.*$|''.*$|\d+\sH<2>O.*$)'),
       DOSAGE_VALUE = 
       TO_NUMBER(REGEXP_REPLACE(
        REGEXP_SUBSTR(REGEXP_REPLACE(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[^,]+$'), '[[:digit:]\.]+(e\d+)*\s*-'), '[[:digit:]\.]+(e\d+)*', 1, 1),
        '(^\.$|^$)', '0')),
       DOSAGE_UNIT = REGEXP_SUBSTR(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '[^,]+$'), '[^[:digit:]\.]+$', 1, 1),
       DOSAGE_HINT = TRIM(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, '\([[:digit:]\.\:\-]+\)', 1, 1));

-- Postprocessing: Update 'DOSAGE_UNIT'
UPDATE DENORM_LIST SET DOSAGE_UNIT = TRIM(DOSAGE_UNIT);

UPDATE DENORM_LIST SET DOSAGE_UNIT = REGEXP_REPLACE(DOSAGE_UNIT, '(\%)\s.*$', '\1')
WHERE regexp_like(DOSAGE_UNIT, '\%');

UPDATE DENORM_LIST SET DOSAGE_UNIT = REGEXP_REPLACE(DOSAGE_UNIT, '(ml)\s.*$', '\1')
WHERE regexp_like(DOSAGE_UNIT, 'ml');

UPDATE DENORM_LIST SET DOSAGE_UNIT = REGEXP_REPLACE(DOSAGE_UNIT, '(mg)\s.*$', '\1')
WHERE regexp_like(DOSAGE_UNIT, 'mg');

UPDATE DENORM_LIST SET DOSAGE_UNIT = REGEXP_REPLACE(DOSAGE_UNIT, '(g)\s.*$', '\1')
WHERE regexp_like(DOSAGE_UNIT, 'g\s') and DOSAGE_UNIT not like '%mg%';

UPDATE DENORM_LIST SET DOSAGE_UNIT = REGEXP_REPLACE(DOSAGE_UNIT, 'Mio Zellen', 'million cells')
WHERE regexp_like(DOSAGE_UNIT, 'Mio Zellen');

UPDATE DENORM_LIST SET DOSAGE_UNIT = REGEXP_REPLACE(DOSAGE_UNIT, 'Zellen', 'cells')
WHERE regexp_like(DOSAGE_UNIT, 'Zellen');

UPDATE DENORM_LIST SET DOSAGE_UNIT = NULL WHERE DOSAGE_UNIT like '%Mengenangabe%';
UPDATE DENORM_LIST SET DOSAGE_UNIT = NULL WHERE DOSAGE_UNIT like '%hierfuer keine%';

UPDATE DENORM_LIST SET DOSAGE_UNIT = REGEXP_REPLACE(DOSAGE_UNIT, 'microgHA', 'microg')
WHERE regexp_like(DOSAGE_UNIT, 'microgHA');

UPDATE DENORM_LIST SET DOSAGE_UNIT = REGEXP_REPLACE(DOSAGE_UNIT, '(FSH)\s.*$', '\1')
WHERE regexp_like(DOSAGE_UNIT, 'FSH');

-- 

update denorm_list SET DOSAGE_UNIT = 'I.E.' WHERE DOSAGE_VALUE is not null and DOSAGE_UNIT is null AND REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, 'I.E.$', 'i');
update denorm_list SET DOSAGE_UNIT = 'T.E.' WHERE DOSAGE_VALUE is not null and DOSAGE_UNIT is null AND REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, 'T.E.$', 'i');
update denorm_list SET DOSAGE_UNIT = 'A.E.' WHERE DOSAGE_VALUE is not null and DOSAGE_UNIT is null AND REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, 'A.E.$', 'i');
update denorm_list SET DOSAGE_UNIT = 'FIP-E.' WHERE DOSAGE_VALUE is not null and DOSAGE_UNIT is null AND REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, 'FIP-E.$', 'i');
update denorm_list SET DOSAGE_UNIT = 'E.' WHERE DOSAGE_VALUE is not null and DOSAGE_UNIT is null AND REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, '\sE.$', 'i');


update denorm_list SET DOSAGE_UNIT = 'CFU' WHERE DOSAGE_VALUE is not null and DOSAGE_UNIT is null AND REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, '\(CFU\)');

update denorm_list SET DOSAGE_UNIT = 'cells' WHERE DOSAGE_VALUE is not null and DOSAGE_UNIT is null AND REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, 'zell', 'i');

update denorm_list SET DOSAGE_UNIT = 'D',  DOSAGE_VALUE = REGEXP_SUBSTR(REGEXP_SUBSTR(DRUG_COMPONENT_PREPRECESSED, 'D(\d+)\)?\"?,?$',1,1),'\d+',1,1)  WHERE REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, 'D\d+\)?\"?,?$'); 


update denorm_list SET DOSAGE_UNIT = 'GKID(50)' WHERE REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, 'GKID\(50\)$', 'i');
update denorm_list SET DOSAGE_UNIT = 'ZKID(50)' WHERE REGEXP_LIKE(DRUG_COMPONENT_PREPRECESSED, 'ZKID\(50\)$', 'i');

UPDATE DENORM_LIST SET DOSAGE_UNIT = 'I.E.' WHERE regexp_like(DOSAGE_UNIT, 'FSH');
UPDATE DENORM_LIST SET DOSAGE_UNIT = 'ml' WHERE regexp_like(DOSAGE_UNIT, 'ml\sUT');
UPDATE DENORM_LIST SET DOSAGE_UNIT = 'mg' WHERE regexp_like(DOSAGE_UNIT, 'mg\/ml');
UPDATE DENORM_LIST SET DOSAGE_UNIT = 'g' WHERE regexp_like(DOSAGE_UNIT, 'g\/l');


MERGE
INTO    denorm_list dl
USING   (
SELECT distinct drug_code, ingredient_code, regexp_substr(dosage, '[[:digit:].]+') dosage_value, regexp_replace(dosage, '[[:digit:].]+\s*') dosage_unit  FROM (
select drug_code, ingredient_code, regexp_substr(regexp_substr(DRUG_COMPONENT_PREPRECESSED, '([[:digit:].]+)\s?(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)\s?[^[:digit:].]*[[:digit:].]+\s?X X X$'),'^[[:digit:].]+\s?(dosis|i\.e\.|impfdosen|impfdosis|sq-e|cm|cm sup2|mm|g|kg|l|mg|microg|microl|ml)') dosage from denorm_list where dosage_unit = 'X X X' 
)
) d ON (d.DRUG_CODE=dl.DRUG_CODE AND d.INGREDIENT_CODE=dl.INGREDIENT_CODE)
WHEN MATCHED THEN UPDATE
    SET dl.dosage_value = TO_NUMBER(d.dosage_value), dl.dosage_unit = d.dosage_unit
;


update denorm_list set dosage_value = round(dosage_value*1000)*1000 WHERE regexp_like(drug_component,'Mio\.? I\.E\.', 'i');

-- Verify 'DOSAGE_VALUE' and 'DOSAGE_UNIT'
/*SELECT DISTINCT DOSAGE_UNIT FROM DENORM_LIST;
SELECT COUNT(*) FROM DENORM_LIST WHERE DOSAGE_VALUE is NULL;
SELECT DISTINCT INGREDIENT_CODE, INGREDIENT FROM DENORM_LIST;

SELECT INGREDIENT_CODE, NEW_INGREDIENT, INGREDIENT, DOSAGE_VALUE, DOSAGE_UNIT, DOSAGE_HINT, DRUG_COMPONENT
FROM DENORM_LIST
OFFSET 0 ROWS FETCH NEXT 500 ROWS ONLY;*/


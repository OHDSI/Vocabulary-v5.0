/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Christian Reich, Dmitry Dymshyts, Anna Ostropolets
* Date: 2016
**************************************************************************/ 
--this algorithm shows you concept_code and an error type related to this code, 
--for ds_stage it gets drug_concept_code
--for relationship_to_concept it gives concept_code_1
--for internal_relationship it gives concpept_code_1
--for drug_concept_stage it gives concept_code
-- 1. relationship_to_concept
--incorrect mapping to concept
--different classes in concept_code_1 and concept_id_2
SELECT error_type,
       COUNT(1)
FROM (SELECT a.concept_code, 'different classes in concept_code_1 and concept_id_2' AS error_type
      FROM relationship_to_concept r
        JOIN drug_concept_stage a ON a.concept_code = r.concept_code_1
        JOIN devv5.concept c ON c.concept_id = r.concept_id_2 AND c.vocabulary_id like 'RxNorm%'
      WHERE a.concept_class_id != c.concept_class_id
UNION
      --concept_id's that don't exist
      SELECT a.concept_code, 'concept_id_2 exists but doesnt belong to any concept'
      FROM relationship_to_concept r
        JOIN drug_concept_stage a ON a.concept_code = r.concept_code_1
        LEFT JOIN devv5.concept c ON c.concept_id = r.concept_id_2
      WHERE c.concept_name IS NULL
UNION
      -- 2. ds_stage
      --wrong units
      SELECT DISTINCT drug_concept_code,'unit doesnt exist in concept_table'
      FROM ds_stage
      WHERE (amount_unit NOT IN (SELECT concept_code
                                 FROM drug_concept_stage
                                 WHERE concept_class_id = 'Unit')
                         OR numerator_unit NOT IN (SELECT concept_code FROM drug_concept_stage WHERE concept_class_id = 'Unit')
                         OR denominator_unit NOT IN (SELECT concept_code FROM drug_concept_stage  WHERE concept_class_id = 'Unit'))
UNION
      --0 in ds_stage values
      SELECT drug_concept_code,  '0 in values'
      FROM ds_stage WHERE 0 IN (numerator_value,amount_value,denominator_value)
      UNION
      SELECT ds.drug_concept_code, 'ds_stage duplicates after mapping to Rx'
      FROM ds_stage ds
        JOIN ds_stage ds2 ON ds.drug_concept_code = ds2.drug_concept_code AND ds.ingredient_concept_code != ds2.ingredient_concept_code
        JOIN relationship_to_concept rc ON ds.ingredient_concept_code = rc.concept_code_1
        JOIN relationship_to_concept rc2 ON ds2.ingredient_concept_code = rc2.concept_code_1
      WHERE rc.concept_id_2 = rc2.concept_id_2
UNION
      -- drug codes are not exist in a drug_concept_stage but present in ds_stage
      SELECT DISTINCT s.drug_concept_code, 'ds_stage has drug_codes absent in drug_concept_stage'
      FROM ds_stage s
        LEFT JOIN drug_concept_stage a ON a.concept_code = s.drug_concept_code  AND a.concept_class_id = 'Drug Product'
        LEFT JOIN drug_concept_stage b  ON b.concept_code = s.INGREDIENT_CONCEPT_CODE  AND b.concept_class_id = 'Ingredient'
      WHERE a.concept_code IS NULL
UNION
      -- ingredient codes not exist in a drug_concept_stage but present in ds_stage
      SELECT DISTINCT s.drug_concept_code, 'ds_stage has ingredient_codes absent in drug_concept_stage'
      FROM ds_stage s
        LEFT JOIN drug_concept_stage a  ON a.concept_code = s.drug_concept_code  AND a.concept_class_id = 'Drug Product'
        LEFT JOIN drug_concept_stage b ON b.concept_code = s.INGREDIENT_CONCEPT_CODE  AND b.concept_class_id = 'Ingredient'
      WHERE b.concept_code IS NULL
UNION
      --impossible entries combinations in ds_stage table
      SELECT DISTINCT s.drug_concept_code, 'impossible combination of values and units in ds_stage'
      FROM ds_stage s
      WHERE AMOUNT_VALUE IS NOT NULL
      AND   AMOUNT_UNIT IS NULL
      OR    (denominator_VALUE IS NOT NULL AND denominator_UNIT IS NULL)
      OR    (NUMERATOR_VALUE IS NOT NULL AND denominator_UNIT IS NULL AND DENOMINATOR_VALUE IS NULL AND NUMERATOR_UNIT != '%')
      OR    (AMOUNT_VALUE IS NULL AND AMOUNT_UNIT IS NOT NULL)
UNION
      --Different DENOMINATOR_VALUE or DENOMINATOR_unit in the same drug
      SELECT DISTINCT a.drug_concept_code,  'Different DENOMINATOR_VALUE or DENOMINATOR_unit in the same drug'
      FROM ds_stage a
        JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code 
        AND (a.DENOMINATOR_VALUE IS NULL
         AND b.DENOMINATOR_VALUE IS NOT NULL
          OR a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
          OR a.DENOMINATOR_unit != b.DENOMINATOR_unit)
UNION
      --ds_stage dublicates
      SELECT drug_concept_code, 'ds_stage dublicates'
      FROM (SELECT drug_concept_code, ingredient_concept_code
            FROM ds_stage
            GROUP BY drug_concept_code, ingredient_concept_code  HAVING COUNT(1) > 1)
 UNION
      SELECT drug_concept_code, 'missing unit'
      FROM ds_stage
      WHERE (numerator_value IS NOT NULL AND numerator_unit IS NULL)
      OR    (denominator_value IS NOT NULL AND denominator_unit IS NULL)
      OR    (amount_value IS NOT NULL AND amount_unit IS NULL)
UNION
      SELECT drug_concept_code,'homeopathy in amount, need to check'
      FROM concept c
 	 JOIN relationship_to_concept rc2 ON concept_id_2 = concept_id
         JOIN internal_relationship_stage irs ON rc2.concept_code_1 = irs.concept_code_2
         JOIN ds_stage ds ON ds.drug_concept_code = irs.concept_code_1
         JOIN relationship_to_concept rtc    ON amount_unit = rtc.concept_code_1   AND rtc.concept_id_2 IN (9324, 9325)
     WHERE NOT REGEXP_LIKE (concept_name,'Tablet|Capsule|Lozenge')
     AND   concept_class_id = 'Dose Form' AND   vocabulary_id LIKE 'Rx%'
UNION
      SELECT drug_concept_code,'numerator should be placed into amount'
      FROM concept c
 	 JOIN relationship_to_concept rc2 ON concept_id_2 = concept_id
         JOIN internal_relationship_stage irs ON rc2.concept_code_1 = irs.concept_code_2
         JOIN ds_stage ds ON ds.drug_concept_code = irs.concept_code_1
         JOIN relationship_to_concept rtc    ON numerator_unit = rtc.concept_code_1   AND rtc.concept_id_2 IN (9324, 9325)
     WHERE REGEXP_LIKE (concept_name,'Tablet|Capsule|Lozenge')
     AND   concept_class_id = 'Dose Form' AND   vocabulary_id LIKE 'Rx%'
UNION
      SELECT drug_concept_code,'unmapped unit'
      FROM ds_stage
      WHERE denominator_unit NOT IN (SELECT concept_code_1 FROM relationship_to_concept)
      OR    numerator_unit NOT IN (SELECT concept_code_1 FROM relationship_to_concept)
      OR    amount_unit NOT IN (SELECT concept_code_1 FROM relationship_to_concept)
UNION
      --3. internal_relationship_stage
      SELECT concept_code_1, 'internal_relationship_dublicates'
      FROM (SELECT concept_code_1, concept_code_2
            FROM internal_relationship_stage
            GROUP BY concept_code_1, concept_code_2
            HAVING COUNT(1) > 1)
 UNION
      --drugs without ingredients won't be proceeded
      SELECT concept_code,  'missing relationship to ingredient'
      FROM drug_concept_stage
      WHERE concept_code NOT IN (SELECT concept_code_1
                                 FROM internal_relationship_stage
                                   JOIN drug_concept_stage ON concept_code_2 = concept_code  AND concept_class_id = 'Ingredient')
      AND   concept_code NOT IN (SELECT pack_concept_code FROM pc_stage)
      AND   concept_class_id = 'Drug Product'
UNION
      SELECT concept_code_1,'different ingredient count in IRS and ds_stage'
      FROM (SELECT DISTINCT concept_code_1, COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
            FROM internal_relationship_stage
              JOIN drug_concept_stage ON concept_code = concept_code_2 AND concept_class_id = 'Ingredient') irs
        JOIN (SELECT DISTINCT drug_concept_code, COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
              FROM ds_stage) ds
          ON drug_concept_code = concept_code_1   AND irs_cnt != ds_cnt
 UNION
      --Marketed Drugs without the dosage or Drug Form
select concept_code, 'Marketed Drugs without the dosage or Drug Form' from drug_concept_stage  dcs
join (
SELECT concept_code_1
FROM internal_relationship_stage
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
left join ds_stage on drug_concept_code = concept_code_1 
where drug_concept_code is null
union 
SELECT concept_code_1
FROM internal_relationship_stage
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
where concept_code_1 not in (SELECT concept_code_1
                                  FROM internal_relationship_stage
                                    JOIN drug_concept_stage   ON concept_code_2 = concept_code  AND concept_class_id = 'Dose Form')
) s on s.concept_code_1 = dcs.concept_code
where dcs.concept_class_id = 'Drug Product' and invalid_reason is null 
UNION
      --4.drug_concept_stage
      --duplicates in drug_concept_stage table
      SELECT DISTINCT concept_code, 'Duplicate concept code'
      FROM drug_concept_stage
      WHERE concept_code IN (SELECT concept_code
                             FROM drug_concept_stage
                             GROUP BY concept_code
                             HAVING COUNT(1) > 1)
 UNION
      --same names for different drug classes
      SELECT concept_code,  'same names for basic drug classes'
      FROM drug_concept_stage
      WHERE TRIM(LOWER(concept_name)) IN (SELECT TRIM(LOWER(concept_name)) AS n
                                          FROM drug_concept_stage
                                          WHERE concept_class_id IN ('Brand Name','Dose Form','Unit','Ingredient','Supplier') AND   standard_concept = 'S'
                                          GROUP BY TRIM(LOWER(concept_name))
                                          HAVING COUNT(8) > 1)
UNION
      --short names but not a Unit
      SELECT concept_code,  'short names but not a Unit'
      FROM drug_concept_stage
      WHERE LENGTH(concept_name) < 3
      AND   concept_class_id NOT IN ('Unit')
UNION
      --concept_name is null
      SELECT concept_code, 'concept_name is null'
      FROM drug_concept_stage
      WHERE concept_name IS NULL
UNION
      --relationship_to_concept
      --relationship_to_concept concept_code_1_2 duplicates
      SELECT concept_code_1, 'relationship_to_concept concept_code_1_2 duplicates'
      FROM (SELECT concept_code_1, concept_id_2
            FROM relationship_to_concept
            GROUP BY concept_code_1,   concept_id_2 HAVING COUNT(1) > 1)
UNION
      --relationship_to_concept concept_code_1_precedence duplicates
      SELECT concept_code_1, 'relationship_to_concept concept_code_1_2 duplicates'
      FROM (SELECT concept_code_1, precedence
            FROM relationship_to_concept
            GROUP BY concept_code_1, precedence HAVING COUNT(1) > 1)
UNION
   
      --Brand Name doesnt relate to any drug
      SELECT DISTINCT a.concept_code, 'Brand Name doesnt relate to any drug'
      FROM drug_concept_stage a
        LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
      WHERE a.concept_class_id = 'Brand Name'
      AND   b.concept_code_1 IS NULL
UNION
      --Dose Form doesnt relate to any drug
      SELECT DISTINCT a.concept_code, 'Dose Form doesnt relate to any drug'
      FROM drug_concept_stage a
        LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
      WHERE a.concept_class_id = 'Dose Form'
      AND   b.concept_code_1 IS NULL
UNION
      --duplicates in ds_stage
      --Concept_code_1 - Precedence duplicates
      SELECT concept_code_1, 'Concept_code_1 - precedence duplicates'
      FROM (SELECT concept_code_1,  precedence
            FROM relationship_to_concept
            GROUP BY concept_code_1,  precedence HAVING COUNT(1) > 1)
UNION
      ----Concept_code_1 - Ingredient duplicates
      SELECT concept_code_1, 'Concept_code_1 - precedence duplicates'
      FROM (SELECT concept_code_1,  concept_id_2
            FROM relationship_to_concept
            GROUP BY concept_code_1,  concept_id_2  HAVING COUNT(1) > 1)
 UNION
      --Unit without mapping
      SELECT CONCEPT_CODE, 'Unit without mapping'
      FROM drug_concept_Stage a
        LEFT JOIN relationship_to_concept b ON a.concept_code = b.concept_code_1
      WHERE concept_class_id IN ('Unit')
      AND   b.concept_code_1 IS NULL
UNION
      --Dose Form without mapping
      SELECT CONCEPT_CODE, 'Dose Form without mapping'
      FROM drug_concept_Stage a
        LEFT JOIN relationship_to_concept b ON a.concept_code = b.concept_code_1
      WHERE concept_class_id IN ('Dose Form')
      AND   b.concept_code_1 IS NULL
UNION
      --duplicates will be present in drug_concept_stage, unable to summarize values
      SELECT DISTINCT a.drug_concept_code,'concept overlaps with other one by target concept, please look also onto rigth sight of query result'
      FROM (SELECT DISTINCT a.amount_unit, a.numerator_unit,cs.concept_code, cs.concept_name AS old_name,rc.concept_name AS RxName,a.drug_concept_code
            FROM ds_stage a
              JOIN relationship_to_concept b ON a.ingredient_concept_code = b.concept_code_1
              JOIN drug_Concept_stage cs ON cs.concept_code = a.ingredient_concept_code
              JOIN devv5.concept rc ON rc.concept_id = b.concept_id_2
              JOIN drug_Concept_stage rd ON rd.concept_code = a.drug_concept_code
              JOIN (SELECT a.drug_concept_code, b.concept_id_2
                    FROM ds_stage a
                    JOIN relationship_to_concept b ON a.ingredient_concept_code = b.concept_code_1 GROUP BY a.drug_concept_code,  b.concept_id_2 HAVING COUNT(1) > 1) c  
                    ON c.DRUG_CONCEPT_CODE = a.DRUG_CONCEPT_CODE   AND c.CONCEPT_ID_2 = b.CONCEPT_ID_2  WHERE precedence = 1) a
        JOIN (SELECT DISTINCT a.amount_unit, a.numerator_unit, cs.concept_name AS old_name,rc.concept_name AS RxName, a.drug_concept_code
              FROM ds_stage a
                JOIN relationship_to_concept b ON a.ingredient_concept_code = b.concept_code_1
                JOIN drug_Concept_stage cs ON cs.concept_code = a.ingredient_concept_code
                JOIN devv5.concept rc ON rc.concept_id = b.concept_id_2
                JOIN drug_Concept_stage rd ON rd.concept_code = a.drug_concept_code
                JOIN (SELECT a.drug_concept_code, b.concept_id_2
                      FROM ds_stage a
                        JOIN relationship_to_concept b ON a.ingredient_concept_code = b.concept_code_1 GROUP BY a.drug_concept_code,  b.concept_id_2 HAVING COUNT(1) > 1) c  ON c.DRUG_CONCEPT_CODE = a.DRUG_CONCEPT_CODE AND c.CONCEPT_ID_2 = b.CONCEPT_ID_2  WHERE precedence = 1) b
          ON a.RxName = b.RxName  AND a.drug_concept_code = b.drug_concept_code AND (a.AMOUNT_UNIT != b.amount_unit OR a.NUMERATOR_UNIT != b.NUMERATOR_UNIT OR a.NUMERATOR_UNIT IS NULL  AND b.NUMERATOR_UNIT IS NOT NULL  OR a.AMOUNT_UNIT IS NULL   AND b.amount_unit IS NOT NULL)
UNION
      --Improper valid_end_date
      SELECT concept_code, 'Improper valid_end_date'
      FROM drug_concept_stage
      WHERE concept_code NOT IN (SELECT concept_code
                                 FROM drug_concept_stage
                                 WHERE valid_end_date <= SYSDATE OR    valid_end_date = TO_DATE('2099-12-31','YYYY-MM-DD'))
UNION
      --Improper valid_start_date
      SELECT concept_code,'Improper valid_start_date'
      FROM drug_concept_stage
      WHERE valid_start_date >SYSDATE
UNION
      --Wrong vocabulary mapping
      SELECT concept_code_1, 'Wrong vocabulary mapping'
      FROM relationship_to_concept a
        JOIN devv5.concept b ON a.concept_id_2 = b.concept_id
      WHERE b.VOCABULARY_ID NOT IN ('ATC','UCUM','RxNorm','RxNorm Extension')
UNION
      --"<=0" in ds_stage values
      SELECT drug_concept_code, '0 in values'
      FROM ds_stage
      WHERE amount_value <= 0  OR    denominator_value <= 0  OR    numerator_value <= 0
UNION
      --pc_stage issues
      --pc_stage duplicates
      SELECT PACK_CONCEPT_CODE, 'pc_stage duplicates'
      FROM (SELECT PACK_CONCEPT_CODE,  DRUG_CONCEPT_CODE
            FROM pc_stage
            GROUP BY DRUG_CONCEPT_CODE, PACK_CONCEPT_CODE HAVING COUNT(1) > 1)
UNION
      --non drug as a pack component
      SELECT DRUG_CONCEPT_CODE, 'non drug as a pack component'
      FROM pc_stage
        JOIN drug_concept_stage ON DRUG_CONCEPT_CODE = concept_code AND concept_class_id != 'Drug Product'
UNION
      --wrong drug classes
      SELECT concept_code, 'wrong drug classes'
      FROM drug_concept_stage
      WHERE concept_class_id NOT IN ('Ingredient','Unit','Drug Product','Dose Form','Supplier','Brand Name','Device')
UNION
      --wrong domains
      SELECT concept_code, 'wrong domain_id'
      FROM drug_concept_stage
      WHERE domain_id NOT IN ('Drug','Device')
UNION
      --wrong dosages > 1000
      SELECT drug_concept_code, 'wrong dosages > 1000'
      FROM ds_stage
      WHERE (LOWER(numerator_unit) IN ('mg') AND LOWER(denominator_unit) IN ('ml','g') OR LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('l'))
      AND   numerator_value / NVL(denominator_value,1) > 1000
UNION
      SELECT a.drug_concept_code, '3-leg dogs'
      FROM ds_stage a
        JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code  AND a.ingredient_concept_code != b.ingredient_concept_code AND   a.amount_unit IS NULL AND b.amount_unit IS NOT NULL  
        union
          SELECT a.drug_concept_code, '3-leg dogs'
      FROM ds_stage a
        JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code  AND a.ingredient_concept_code != b.ingredient_concept_code AND   a.numerator_unit IS NULL AND b.numerator_unit IS NOT NULL 
UNION
      SELECT drug_concept_code, 'mg/mg >1'
      FROM ds_stage
      WHERE numerator_unit = 'mg' AND   denominator_unit = 'mg' AND   numerator_value / NVL(denominator_value,1) > 1
      UNION
      --wrong dosages > 1
      SELECT drug_concept_code, 'wrong dosages > 1'
      FROM ds_stage
      WHERE LOWER(numerator_unit) IN ('g')  AND   LOWER(denominator_unit) IN ('ml') AND   numerator_value / denominator_value > 1
UNION
      --% in ds_stage 
      SELECT drug_concept_code, '% in ds_stage'
      FROM ds_stage
      WHERE numerator_unit IN ('%','pct','percent')
      OR    amount_unit IN ('%','pct','percent')
      OR    denominator_unit IN ('%','pct','percent')
UNION
      SELECT drug_concept_code,'wrong dosage with ml'
      FROM ds_stage
      WHERE lower(numerator_unit) IN ('ml')
      OR    lower(amount_unit) IN ('ml')
UNION      
      SELECT drug_concept_code, 'problems in ds_stage'
      FROM ds_stage
      WHERE COALESCE(amount_value,numerator_value,0) = 0
      -- needs to have at least one value, zeros don't count
      OR    COALESCE(amount_unit,numerator_unit) IS NULL
      -- needs to have at least one unit
      OR    (amount_value IS NOT NULL AND amount_unit IS NULL)
      -- if there is an amount record, there must be a unit
      OR    (NVL(numerator_value,0) != 0 AND COALESCE(numerator_unit,denominator_unit) IS NULL)
      -- if there is a concentration record there must be a unit in both numerator and denominator
UNION
       SELECT drug_concept_code,'Drug Comp Box, need to remove box_size'
       FROM ds_stage ds
       JOIN internal_relationship_stage i ON concept_code_1 = drug_concept_code
       LEFT JOIN drug_concept_stage ON concept_code = concept_code_2 AND concept_class_id = 'Dose Form'
       WHERE box_size IS NOT NULL AND   concept_name IS NULL
UNION
      -- as we don't have the mapping all the decives should be standard
      SELECT concept_code,  'non-standard devices'
      FROM drug_concept_stage
      WHERE domain_id = 'Device' AND standard_concept IS NULL
UNION
      --several attributes but should be the only one
      SELECT concept_code_1, 'several attributes but should be the only one'
      FROM (SELECT concept_code_1, b.concept_class_id
            FROM internal_relationship_stage a
              JOIN drug_concept_stage b ON concept_code = concept_code_2
            WHERE b.concept_class_id IN ('Supplier','Dose Form','Brand Name')
            GROUP BY concept_code_1, b.concept_class_id HAVING COUNT(1) > 1)
UNION
      --replacement mappings to several concepts
      SELECT concept_code_1, 'several attributes but should be the only one'
      FROM (SELECT concept_code_1,  b.concept_class_id
            FROM internal_relationship_stage a
              JOIN drug_concept_stage z ON z.concept_code = concept_code_1
              JOIN drug_concept_stage b ON b.concept_code = concept_code_2
            WHERE b.concept_class_id = z.concept_class_id
            GROUP BY concept_code_1, b.concept_class_id  HAVING COUNT(1) > 1)
UNION
      --sequence intersection
      SELECT a.concept_code, 'sequence intersection'
      FROM drug_concept_stage a
        JOIN concept b ON a.concept_code = b.concept_code
      WHERE a.concept_code LIKE 'OMOP%'
UNION
      --invalid_concept_id_2
      SELECT concept_code_1, 'invalid_concept_id_2'
      FROM relationship_to_concept
        JOIN concept ON concept_id = concept_id_2
      WHERE invalid_reason IS NOT NULL
UNION
      --map to non-stand_ingredient
      SELECT concept_code_1, 'map to non-stand_ingredient'
      FROM relationship_to_concept
        JOIN drug_concept_stage s ON s.concept_code = concept_code_1
        JOIN concept c ON c.concept_id = concept_id_2
      WHERE c.standard_concept IS NULL  AND   s.concept_class_id = 'Ingredient'
UNION
      --map to unit that doesn't exist in RxNorm
      SELECT a.concept_code_1, 'map to unit that doesn''t exist in RxNorm'
      FROM relationship_to_concept a
        JOIN drug_concept_stage b ON concept_code_1 = concept_code
        JOIN concept c ON concept_id_2 = c.concept_id
      WHERE b.concept_class_id = 'Unit'
      AND   concept_id_2 NOT IN (SELECT DISTINCT NVL(AMOUNT_UNIT_CONCEPT_ID,NUMERATOR_UNIT_CONCEPT_ID)
                                 FROM drug_strength a
                                   JOIN concept b ON drug_concept_id = concept_id  AND vocabulary_id = 'RxNorm'
                                 WHERE NVL(AMOUNT_UNIT_CONCEPT_ID,NUMERATOR_UNIT_CONCEPT_ID) IS NOT NULL
                                 UNION
                                 SELECT DISTINCT DENOMINATOR_UNIT_CONCEPT_ID
                                 FROM drug_strength a
                                   JOIN concept b  ON drug_concept_id = concept_id AND vocabulary_id = 'RxNorm'
                                 WHERE DENOMINATOR_UNIT_CONCEPT_ID IS NOT NULL)
 UNION
      SELECT concept_code_1,   'Empty conversion factor'
      FROM relationship_to_concept a
        JOIN drug_concept_stage b ON concept_code_1 = concept_code  AND concept_class_id = 'Unit'
      WHERE conversion_factor IS NULL
UNION
      --replacement with invalid concept
      SELECT concept_code_1, 'replacement with invalid concept'
      FROM internal_relationship_stage
        JOIN drug_concept_stage ON concept_code = concept_code_2
      WHERE invalid_reason IS NOT NULL
 UNION
      --standard but invalid concept
      SELECT concept_code, 'standard but invalid concept'
      FROM drug_concept_stage
      WHERE standard_concept = 'S'   AND   invalid_reason IS NOT NULL
 UNION
      --standard ingredients have replacemt mapping 
      SELECT concept_code, 'standard ingredients have replacemt mapping'
      FROM drug_concept_stage
        JOIN internal_relationship_stage ON concept_code_1 = concept_code
      WHERE concept_class_id = 'Ingredient' AND   standard_concept IS NOT NULL
UNION
      --non-standard ingredients don't have replacemt mapping 
      SELECT concept_code,'non-standard ingredients dont have replacemt mapping '
      FROM drug_concept_stage
        LEFT JOIN internal_relationship_stage ON concept_code_1 = concept_code
      WHERE concept_class_id = 'Ingredient' AND   standard_concept IS NULL AND   concept_code_2 IS NULL
UNION
      --wrong dosages ,> 1000, with conversion
      SELECT drug_concept_code,
             'wrong dosages > 1000, with conversion'
      FROM ds_stage ds
        JOIN relationship_to_concept n ON numerator_unit = n.concept_code_1 AND n.concept_id_2 = 8576
        JOIN relationship_to_concept d  ON denominator_unit = d.concept_code_1 AND d.concept_id_2 = 8587
      WHERE numerator_value*n.conversion_factor /(denominator_value*d.conversion_factor) > 1000
UNION
      --pack(drug)_concept_code doesn't exist in drug_concept_stage
      SELECT drug_concept_code, 'pc missing'
      FROM pc_stage
      WHERE drug_concept_code NOT IN (SELECT concept_code FROM drug_concept_stage)
UNION

 select drug_concept_code, 'drug_ingr relationship is missing from irs' from ds_Stage where (drug_concept_code, ingredient_concept_code) not in (select concept_code_1, concept_code_2 from internal_relationship_stage)
union
      SELECT pack_concept_code, 'pc missing'
      FROM pc_stage
      WHERE pack_concept_code NOT IN (SELECT concept_code FROM drug_concept_stage)
union      
--name_equal_mapping absence
select dcs.concept_code, 'name_equal_mapping absence' from drug_concept_stage dcs
join concept cc on lower (cc.concept_name) = lower (dcs.concept_name) and cc.concept_class_id = dcs.concept_class_id and cc.vocabulary_id like 'RxNorm%'
left join relationship_to_concept cr on dcs.concept_code = cr.concept_code_1
where concept_code_1 is null and cc.invalid_reason is null
and dcs.concept_class_id in ('Ingredient', 'Brand Name', 'Dose Form', 'Supplier')
)
GROUP BY error_type;

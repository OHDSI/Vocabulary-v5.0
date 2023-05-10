--add manual mapping
INSERT INTO aut_ingredient_mapped (concept_name, precedence, concept_id_2)
SELECT DISTINCT concept_name, COALESCE(precedence, 1), concept_id_2
FROM ingredient_mm
WHERE concept_id_2 IS NOT NULL
  AND concept_id_2 NOT IN (17, 0)
  AND concept_name NOT IN (
                          SELECT concept_name
                          FROM aut_ingredient_mapped
                          );

INSERT INTO aut_bn_mapped (concept_name, concept_id_2, precedence)
SELECT DISTINCT concept_name, concept_id_2, COALESCE(precedence, 1)
FROM bn_mm
WHERE concept_id_2 IS NOT NULL
  AND concept_id_2 NOT IN (17, 0)
  AND concept_name NOT IN (
                          SELECT concept_name
                          FROM aut_bn_mapped
                          );


INSERT INTO aut_suppliers_mapped (source_name, concept_name, concept_id_2, precedence)
SELECT DISTINCT source_name, concept_name, concept_id_2, COALESCE(precedence, 1)
FROM supplier_mm
WHERE concept_id_2 IS NOT NULL
  AND concept_id_2 NOT IN (17, 0)
  AND source_name NOT IN (
                          SELECT source_name
                          FROM aut_suppliers_mapped
                          );

--clean up input tables removing relationships and drug_concept_stage inputs if an Attribute is junk or not supported by the current model
--IRS
delete from internal_relationship_stage where concept_code_2 in (
select concept_code from drug_concept_stage rcs 
join (
select concept_name, 'Ingredient' as concept_class_id from aut_ingredient_mapped where precedence = -1 union all
select concept_name, 'Brand Name' from aut_bn_mapped where precedence = -1 union all
select source_name, 'Supplier' from aut_suppliers_mapped where precedence = -1 ) a
using (concept_name, concept_class_id) 
)
;
delete from ds_stage where ingredient_concept_code in (
select concept_code from drug_concept_stage rcs 
join (
select concept_name, 'Ingredient' as concept_class_id from aut_ingredient_mapped where precedence = -1 ) a
using (concept_name, concept_class_id) 
)
;
-- DCS
delete from drug_concept_stage where (concept_name, concept_class_id) in (
select concept_name, 'Ingredient' as concept_class_id from aut_ingredient_mapped where precedence = -1 union all
select concept_name, 'Brand Name' from aut_bn_mapped where precedence = -1 union all
select source_name, 'Supplier' from aut_suppliers_mapped where precedence = -1  )
;

/************************************************
* 9. Populate relationship_to_concept *
************************************************/

-- 9.1 Forms
-- insert mapped forms back to aut_form_mapped
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dc.concept_code, 'JMDC', concept_id_2, precedence
FROM aut_form_mapped a
JOIN drug_concept_stage dc
    ON dc.concept_name = COALESCE(a.new_name, a.concept_name)
WHERE dc.concept_class_id = 'Dose Form'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE rtc2.concept_code_1 = dc.concept_code)
;
--9.2 Units
-- insert mapped forms back to aut_unit_mapped
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
SELECT DISTINCT concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor
FROM aut_unit_mapped a
WHERE NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE rtc2.concept_code_1 = a.concept_code_1)
;
--9.3 Ingredients
--insert mappings back from aut_ingredient_mapped or aut_parsed_ingr (for ingredients that need parsing)
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dc.concept_code, 'JMDC', CAST(concept_id_2 AS int), precedence
FROM aut_ingredient_mapped a
JOIN drug_concept_stage dc
    ON dc.concept_name = a.concept_name AND concept_class_id = 'Ingredient'
WHERE NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE rtc2.concept_code_1 = dc.concept_code)
and  coalesce (precedence,1) != -1
;

INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dc.concept_code, 'JMDC', concept_id_2, RANK() OVER (PARTITION BY dc.concept_code ORDER BY concept_id_2)
FROM aut_parsed_ingr a
JOIN drug_concept_stage dc
    ON LOWER(dc.concept_name) = LOWER(a.ing_name) AND dc.concept_class_id = 'Ingredient'
WHERE NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE rtc2.concept_code_1 = dc.concept_code);

INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dc.concept_code, 'JMDC', concept_id_2, RANK() OVER (PARTITION BY dc.concept_code ORDER BY concept_id_2)
FROM aut_parsed_ingr a
JOIN drug_concept_stage dc
    ON LOWER(dc.concept_name) = LOWER(a.concept_name) AND dc.concept_class_id = 'Ingredient'
WHERE NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE rtc2.concept_code_1 = dc.concept_code);

-- 9.4 BN
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT dc.concept_code, 'JMDC', CAST(concept_id_2 AS int), precedence
FROM aut_bn_mapped a
JOIN drug_concept_stage dc
    ON dc.concept_name = a.concept_name AND concept_class_id = 'Brand Name'
WHERE NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc2
                 WHERE rtc2.concept_code_1 = dc.concept_code)
                 and coalesce (precedence,1) != -1
;

-- 9.5 Supplier
-- insert mappings from aut_supplier_mapped
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT
    dc.concept_code, 'JMDC', a.concept_id_2,
    RANK() OVER (PARTITION BY dc.concept_code ORDER BY a.concept_id_2)
FROM aut_suppliers_mapped a
JOIN drug_concept_stage dc
    ON a.source_name = dc.concept_name
WHERE a.concept_id_2 IS NOT NULL
  AND dc.concept_code NOT IN (
                             SELECT concept_code_1
                             FROM relationship_to_concept
                             )
and coalesce (precedence,1) != -1                             
;

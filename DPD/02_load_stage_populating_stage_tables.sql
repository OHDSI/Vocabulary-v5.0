--STEP 3: Populating stage tables
--find OMOP codes that aren't used in concept table and create sequence
DO
$$
DECLARE
ex INTEGER;
BEGIN
SELECT MAX(REPLACE(concept_code, 'OMOP', '')::INT4) + 1
INTO ex
FROM concept
WHERE concept_code LIKE 'OMOP%'
AND concept_code NOT LIKE '% %';
DROP SEQUENCE IF EXISTS new_voc;
EXECUTE 'CREATE SEQUENCE new_voc INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END
$$;

--Table with omop-generated codes
DROP TABLE IF EXISTS list_temp;
CREATE TABLE list_temp AS
SELECT DISTINCT a.*,
	nextval('new_voc') AS concept_code
FROM (

    SELECT DISTINCT initcap(modified_name) AS concept_name,
                    'Ingredient' AS concept_class_id,
                    NULL AS standard_concept
	FROM ingr

	UNION

	SELECT DISTINCT new_name AS concept_name,
	       'Brand Name' AS concept_class_id,
	       NULL AS standard_concept
	FROM brand_name
	WHERE new_name IS NOT NULL

	UNION

	SELECT DISTINCT initcap(form_name) AS concept_name,
	       'Dose Form' AS concept_class_id,
	       NULL AS standard_concept
	FROM forms
	WHERE form_name IS NOT NULL

	UNION

	SELECT DISTINCT initcap(edited_name) AS concept_name,
	       'Supplier' AS concept_class_id,
	       NULL AS standard_concept
	FROM companies
	WHERE edited_name IS NOT NULL

    UNION

    SELECT DISTINCT non_drug.brand_name AS concept_name,
                    'Device' AS concept_class_id,
                    NULL AS standard_concept
    FROM non_drug
    WHERE drug_id = 'Not Applicable/non applicable'
	) AS a;

--TODO: Comment says OMOP, but DPD added in original code???
--Concept-stage creation
TRUNCATE TABLE drug_concept_stage;
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)

SELECT DISTINCT concept_name,
                'DPD',
	concept_class_id,
	standard_concept,
	concept_code,
	NULL,
	CASE WHEN concept_class_id = 'Device' THEN 'Device'
	    ELSE 'Drug' END,
	valid_start_date,
    valid_end_date,
    invalid_reason
FROM (
	SELECT initcap(concept_name) AS concept_name,
	       concept_class_id,
	       standard_concept,
	       'OMOP' || concept_code AS concept_code,
	       (current_date - 1) AS valid_start_date,
	       to_date('20991231', 'yyyymmdd') AS valid_end_date,
	       'D' AS invalid_reason

	FROM list_temp --ADD 'OMOP' to all OMOP-generated concepts

UNION
	SELECT concept_name,
	       concept_class_id,
	       NULL AS standard_concept,
	       concept_code,
	       (current_date - 1) AS valid_start_date,
	       to_date('20991231', 'yyyymmdd') AS valid_end_date,
	       'D' AS invalid_reason
	FROM unit

UNION
	SELECT initcap(brand_name || ' [Drug]') AS concept_name,         --TODO: Do we really need [Drug] added?
	       'Drug Product' AS concept_class_id,
	       NULL AS standard_concept,
	       drug_id::varchar(50) AS concept_code,
	       drug_product.valid_start_date,
	       drug_product.valid_end_date,
	       drug_product.invalid_reason

	FROM drug_product
UNION
    SELECT initcap(brand_name) AS concept_name,
           'Device' AS concept_class_id,
           CASE WHEN non_drug.valid_end_date > current_date THEN 'S' ELSE NULL END AS standard_concept,             --TODO: Should we leave any device standard?
           drug_id::varchar(50) AS concept_code,
           non_drug.valid_start_date,
           non_drug.valid_end_date,
           non_drug.invalid_reason
    FROM non_drug
    WHERE drug_id != 'Not Applicable/non applicable'
	) AS a;

--Case when valid_start_date or valid_end_date > current date
--Source can have data of this type, but OMOP should not
UPDATE drug_concept_stage
    SET valid_start_date = CASE WHEN valid_start_date > current_date THEN current_date
                                ELSE valid_start_date END,
        valid_end_date = CASE WHEN valid_end_date > current_date THEN current_date
                              WHEN valid_end_date < valid_start_date THEN valid_start_date
                                ELSE valid_end_date END;

--Integration with existing concepts for OMOP-generated concepts
--13043 matches with DPD
--77 matches with OMOP

--TODO: For the first run on devv5, change OMOP% to DPD%????
/*
with a AS (
    SELECT *
    FROM devv5.concept c
    WHERE c.vocabulary_id = 'DPD'
    AND c.concept_code like 'OMOP%'
)
UPDATE drug_concept_stage
SET concept_code = a.concept_code
FROM drug_concept_stage cs
JOIN a
    ON cs.concept_name = a.concept_name and cs.concept_class_id = a.concept_class_id
AND cs.concept_code like 'OMOP%';
 */

--Delete Water as unnecessary ingredient
DELETE FROM drug_concept_stage
WHERE concept_name IN ('Sterile Water (Diluent)', 'Sea Water', 'Water (Diluent)', 'Sterile Water');

--Create drug_concept_code backup + versioning
-- Implemented from AMT

--create dsc_backup prior to name updates to get old names in mapping review
DROP TABLE IF EXISTS drug_concept_stage_backup;
CREATE TABLE drug_concept_stage_backup AS
SELECT *
FROM drug_concept_stage;


--+ Unclear where to put this piece of code
--TODO: maybe put it right before rtc_2?

-- set new_names for ingredients from ingredient_mapped
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM ingredient_mapped
     WHERE new_name <> ''
     ) AS names
WHERE lower(dcs.concept_name) = lower(names.name)
    AND dcs.concept_class_id = 'Ingredient'
;

-- set new_names for brand names from brand_name_mapped
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM brand_name_mapped
     WHERE new_name <> ''
     ) AS names
WHERE lower(dcs.concept_name) = lower(names.name)
    AND dcs.concept_class_id = 'Brand Name'
;

-- set new_names for suppliers from supplier_mapped
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM supplier_mapped
     WHERE new_name <> ''
     ) AS names
WHERE lower(dcs.concept_name) = lower(names.name)
    AND concept_class_id = 'Supplier'
;

-- set new_names for dose forms from dose_form_mapped
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM dose_form_mapped
     WHERE new_name <> ''
     ) AS names
WHERE lower(dcs.concept_name) = lower(names.name)
    AND concept_class_id = 'Dose Form'
;


-- delete from dcs concepts, mapped to 0 in ingredient_mapped
DELETE
FROM drug_concept_stage dcs
WHERE lower(concept_name) IN (
                             SELECT lower(name)
                             FROM ingredient_mapped
                             WHERE concept_id_2 = 0
                               AND name IS NOT NULL
                             )
  AND concept_class_id = 'Ingredient';

-- delete from dcs concepts, mapped to 0 in brand_name_mapped
DELETE
FROM drug_concept_stage dcs
WHERE lower(concept_name) IN (
                             SELECT lower(name)
                             FROM brand_name_mapped
                             WHERE concept_id_2 = 0
                                AND name IS NOT NULL
                             )
  AND concept_class_id = 'Brand Name';

-- delete from dcs concepts, mapped to 0 in supplier_mapped
DELETE
FROM drug_concept_stage dcs
WHERE lower(concept_name) IN (
                             SELECT lower(name)
                             FROM supplier_mapped
                             WHERE concept_id_2 = 0
                               AND name IS NOT NULL
                      )
AND concept_class_id = 'Supplier';

-- delete from dcs concepts, mapped to 0 in dose_form_mapped
DELETE
FROM drug_concept_stage dcs
WHERE lower(concept_name) IN (
                             SELECT lower(name)
                             FROM dose_form_mapped
                             WHERE concept_id_2 = 0
                               AND name IS NOT NULL
                             )
AND concept_class_id = 'Dose Form';

--internal_relationship_stage population

TRUNCATE internal_relationship_stage;
INSERT INTO internal_relationship_stage (concept_code_1, concept_code_2)
(
--drug to manufacturer
SELECT DISTINCT dp.drug_id AS concept_code_1, dcs.concept_code AS concept_code_2
FROM companies co
JOIN drug_concept_stage dcs
ON co.edited_name = dcs.concept_name AND dcs.concept_class_id = 'Supplier'
JOIN drug_product dp
ON dp.drug_code = co.drug_code

UNION

--drug to ingredient
SELECT DISTINCT dp.drug_id AS concept_code_1, dcs.concept_code AS concept_code_2
FROM ingr i
JOIN drug_concept_stage dcs
ON initcap(i.modified_name) = dcs.concept_name AND dcs.concept_class_id = 'Ingredient'
JOIN drug_product dp
ON dp.drug_code = i.drug_code

UNION

--drug to form
SELECT DISTINCT dp.drug_id AS concept_code_1, dcs.concept_code AS concept_code_2
FROM forms f
JOIN drug_concept_stage dcs
ON initcap(f.form_name) = dcs.concept_name AND dcs.concept_class_id = 'Dose Form'
JOIN drug_product dp
ON dp.drug_code = f.drug_code

UNION

--drug to brand name
SELECT DISTINCT dp.drug_id AS concept_code_1, dcs.concept_code AS concept_code_2
FROM brand_name bn
JOIN drug_concept_stage dcs
ON initcap(bn.new_name) = dcs.concept_name AND dcs.concept_class_id = 'Brand Name'
JOIN drug_product dp
ON dp.drug_code = bn.drug_code

)
;

--Removing drug_forms which exist with devices only
DELETE FROM drug_concept_stage
WHERE concept_code IN
(SELECT DISTINCT a.concept_code
FROM drug_concept_stage a
LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
WHERE a.concept_class_id = 'Dose Form'
	AND b.concept_code_1 IS NULL);

--Step 4: ds_stage population
--ds_stage population
--TODO: NIL
TRUNCATE ds_stage;

--Initial creation of ds_stage table to perform update on it
INSERT INTO ds_stage(drug_concept_code, ingredient_concept_code, amount_value, amount_unit, numerator_value, numerator_unit, denominator_value, denominator_unit)
SELECT DISTINCT dp.drug_id AS drug_concept_code,
	dcs.concept_code AS ingredient_concept_code,
regexp_replace(strength, '^\.[0-9]', '0'||strength)::double precision AS amount_value,
                strength_unit AS amount_unit,
regexp_replace(strength, '^\.[0-9]', '0'||strength)::double precision AS numerator_value,
                strength_unit AS numerator_unit,
regexp_replace(dosage_value, '^\.[0-9]', '0'||dosage_value)::double precision AS denominator_value,
dosage_unit AS denominator_unit
FROM drug_product dp
JOIN active_ingredients ai
    ON dp.drug_code = ai.drug_code
JOIN ingr i
    ON ai.active_ingredient_code = i.active_ingredient_code and i.drug_code = dp.drug_code
JOIN drug_concept_stage dcs
    ON initcap(i.modified_name) = initcap(dcs.concept_name) AND dcs.concept_class_id = 'Ingredient'
;

--Drugs without denominators should have only amount populated
UPDATE ds_stage
SET numerator_value = NULL, numerator_unit = NULL
WHERE denominator_unit IS NULL AND denominator_value IS NULL;

--Drugs with denominator should have only numerator populated
UPDATE ds_stage
SET amount_value = NULL, amount_unit = NULL
WHERE denominator_unit IS NOT NULL AND denominator_value IS NOT NULL;

--add 1 as denominator value and set unnescessary fields to null for drugs with amounts and isolated denominators units
UPDATE ds_stage ds
SET amount_value = (CASE WHEN denominator_unit IN ('Kg', 'DROP', 'G', 'HOUR', 'L', 'ML', 'SQ CM') THEN NULL ELSE amount_value END),
    amount_unit = (CASE WHEN denominator_unit IN ('Kg', 'DROP', 'G', 'HOUR', 'L', 'ML', 'SQ CM') THEN NULL ELSE amount_unit END),
    numerator_value = (CASE WHEN denominator_unit IN ('Kg', 'DROP', 'G', 'HOUR', 'L', 'ML', 'SQ CM') THEN numerator_value ELSE NULL END),
    numerator_unit = (CASE WHEN denominator_unit IN ('Kg', 'DROP', 'G', 'HOUR', 'L', 'ML', 'SQ CM') THEN numerator_unit ELSE NULL END),
    denominator_unit = (CASE WHEN denominator_unit IN ('Kg', 'DROP', 'G', 'HOUR', 'L', 'ML', 'SQ CM') THEN denominator_unit ELSE NULL END),
    denominator_value = (CASE WHEN denominator_unit IN ('Kg', 'DROP', 'G', 'HOUR', 'L', 'ML', 'SQ CM') THEN 1 ELSE NULL END)
WHERE amount_value IS NOT NULL
      AND amount_unit IS NOT NULL
      AND denominator_value IS NULL
      AND denominator_unit IS NOT NULL
    AND denominator_unit != '%'
    AND amount_unit != '%'
    AND numerator_unit != '%'
;


--Homeopathy
--Deliting all the homeopathy
DELETE FROM ds_stage
    WHERE amount_unit IN ('C', 'CC', 'D', 'DH', 'X')
            OR numerator_unit IN ('C', 'CC', 'D', 'DH', 'X')
            OR denominator_unit IN ('C', 'CC', 'D', 'DH', 'X');


/*
UPDATE ds_stage
SET amount_value = NULL,
    amount_unit = NULL,
    numerator_unit = 'ML',
    numerator_value = 1,
    denominator_value = CASE WHEN numerator_unit = 'C' THEN 10^(2*numerator_value::int)
         WHEN numerator_unit = 'D' THEN 10^numerator_value::int
         WHEN numerator_unit = 'DH' THEN 10^numerator_value::int
         WHEN numerator_unit = 'CC' THEN 10^(2*numerator_value::int)
         WHEN numerator_unit = 'X' THEN 10^numerator_value::int
    END,
    denominator_unit = 'ML'
WHERE denominator_unit IN ('C', 'CC', 'D', 'DH', 'X')
        OR numerator_unit IN ('C', 'CC', 'D', 'DH', 'X');
 */


--%
UPDATE ds_stage
    SET amount_value = NULL, amount_unit = NULL,
        numerator_value = (CASE WHEN denominator_unit IN ('W/W', 'W/V') THEN numerator_value * 10 WHEN denominator_unit = 'V/V' THEN numerator_value END),
        numerator_unit = (CASE WHEN denominator_unit IN ('W/W', 'W/V') THEN 'MG' WHEN denominator_unit = 'V/V' THEN 'ML' END),
        denominator_value = (CASE WHEN denominator_unit IN ('W/W', 'W/V') THEN 1 WHEN denominator_unit = 'V/V' THEN 100 END),
        denominator_unit = (CASE WHEN denominator_unit = 'W/W' THEN 'G' WHEN denominator_unit in ('W/V', 'V/V') THEN 'ML' END)
WHERE amount_unit = '%'
    AND numerator_unit = '%'
    AND denominator_unit IN ('W/W', 'V/V', 'W/V');


WITH a AS (
SELECT DISTINCT drug_concept_code, ingredient_concept_code, numerator_value, numerator_unit, denominator_value, denominator_unit, f.form_name,
                CASE WHEN form_name ~* 'SOLUTION|LIQUID|SYRUP|DROP|SUSPENS|EMULSION|TEA|MOUTHWASH|LEAF|INFILTRATION KIT' AND form_name !~* 'POWDER' THEN 'W/V'
                     WHEN form_name ~* 'CREAM|CAPS|TABL|POWDER|SHAMPOO|OINTMENT|GEL|PASTE|LOTION|SUPPOSITORY|AEROSOL|TINCTURE|SPRAY|JELLY|PLASTER|SPONGE|PATCH|STRIP|DRESSING|TOPICAL KIT|IMPLANT|LOZENGE|SOAP|(VAGINAL|ORAL) KIT|TOPICAL PAD' THEN 'W/W'
                     WHEN form_name ~* 'GAS|OIL' THEN 'V/V'
                ELSE 'W/V' END AS factor --To cover the most possible and neutral option
from ds_stage ds
join drug_product dp
ON dp.drug_id = ds.drug_concept_code
left join forms f
ON f.drug_code = dp.drug_code
WHERE amount_unit = '%' OR numerator_unit = '%') --AND numerator_unit = '%')

UPDATE ds_stage dsu
        SET amount_value = NULL, amount_unit = NULL,
        numerator_value = (CASE WHEN a.factor IN ('W/W', 'W/V') THEN coalesce(dsu.numerator_value * 10, dsu.amount_value * 10) WHEN a.factor = 'V/V' THEN coalesce(dsu.numerator_value, dsu.amount_value) END),
        numerator_unit = (CASE WHEN a.factor IN ('W/W', 'W/V') THEN 'MG' WHEN a.factor = 'V/V' THEN 'ML' END),
        denominator_value = (CASE WHEN a.factor IN ('W/W', 'W/V') THEN 1 WHEN a.factor = 'V/V' THEN 100 END),
        denominator_unit = (CASE WHEN a.factor = 'W/W' THEN 'G' WHEN a.factor in ('W/V', 'V/V') THEN 'ML' END)
FROM ds_stage ds
    JOIN a ON (ds.drug_concept_code, ds.ingredient_concept_code) = (a.drug_concept_code, a.ingredient_concept_code)
WHERE dsu.amount_unit = '%' OR dsu.numerator_unit = '%' --AND dsu.numerator_unit = '%'
;

--Correction of wrong denominator_unit from packaging information
UPDATE ds_stage
SET denominator_unit = 'G'
WHERE drug_concept_code IN (
    select distinct drug_id
    FROM packaging
    JOIN drug_product dp
        on packaging.drug_code = dp.drug_code
    where upper(trim(package_size_unit)) NOT IN ('LOZENGE', 'CAPLET', 'CAPSULE', 'SUPPOSITORY', 'TABLET', 'PATCH', 'PAD', 'GRANULES')
AND package_size_unit = 'GM'
AND package_size !~* '-'
    );

UPDATE ds_stage
SET denominator_unit = 'ML'
WHERE drug_concept_code IN (
    select distinct drug_id
    FROM packaging
    JOIN drug_product dp
        on packaging.drug_code = dp.drug_code
    where upper(trim(package_size_unit)) NOT IN ('LOZENGE', 'CAPLET', 'CAPSULE', 'SUPPOSITORY', 'TABLET', 'PATCH', 'PAD', 'GRANULES')
AND package_size_unit = 'ML'
AND package_size !~* '-'
    )
AND denominator_unit = 'G';

--Introducing box size
--TODO: One unanswered question (not even on the official site of DPD vocabulary): for drugs with %, how can we be sure that box size is 300 g, ml and not kg and l?
--Use package_size to get box_size
UPDATE ds_stage ds
SET box_size = bs.package_size::INT
FROM (
	SELECT DISTINCT package_size, dp.drug_id
	FROM packaging
	JOIN drug_product dp
	    on packaging.drug_code = dp.drug_code
	WHERE packaging.drug_code IN (
			SELECT drug_code
			FROM (
				SELECT DISTINCT drug_code, package_size
				FROM packaging
				WHERE package_size IS NOT NULL
					AND upper(trim(package_size_unit)) IN ('LOZENGE', 'CAPLET', 'CAPSULE', 'SUPPOSITORY', 'TABLET', 'PATCH', 'PAD', 'GRANULES')
				) AS s0
			GROUP BY drug_code
			HAVING COUNT(1) = 1
			)
		AND packaging.drug_code NOT IN (
			SELECT drug_code
			FROM packaging
			GROUP BY drug_code
			HAVING COUNT(1) > 1
			)
	) bs
WHERE bs.drug_id = ds.drug_concept_code;

--box_size for the rest lozenges, capsules, tablets
UPDATE ds_stage
SET box_size = bs.box_size
FROM
(SELECT DISTINCT packaging.drug_code,
                dp.drug_id,
                trim(substring(product_information, '^\d+\.?\d?'))::numeric as box_size, CASE WHEN trim(substring(product_information, '(LOZENGES|CAP(S|SUL|SULE|SULES)?|TAB(S|LET|LETS)?|CAPLETS)')) ~* 'LOZ' THEN 'LOZENGES'
                                                                                WHEN trim(substring(product_information, '(LOZENGES|CAP(S|SUL|SULE|SULES)?|TAB(S|LET|LETS)?|CAPLETS)')) IN ('CAP', 'CAPS', 'CAPSUL', 'CAPSULE', 'CAPSULES') THEN 'CAPSULES'
                                                                                WHEN trim(substring(product_information, '(LOZENGES|CAP(S|SUL|SULE|SULES)?|TAB(S|LET|LETS)?|CAPLETS)')) ~* 'TAB' THEN 'TABLETS'
                                                                                WHEN trim(substring(product_information, '(LOZENGES|CAP(S|SUL|SULE|SULES)?|TAB(S|LET|LETS)?|CAPLETS)')) ~* 'CAPLETS' THEN 'CAPLETS' END as unit
from packaging
JOIN drug_product dp
                       ON packaging.drug_code = dp.drug_code
WHERE product_information ~* '^\d+\.?\d?\s?(LOZENGES|CAP(S|SUL|SULE|SULES)?|TAB(S|LET|LETS)?|CAPLETS)$'
AND product_information !~* '/'
AND packaging.drug_code NOT IN (
			SELECT drug_code
			FROM packaging
			GROUP BY drug_code
			HAVING COUNT(1) > 1)) bs
WHERE bs.drug_id = ds_stage.drug_concept_code
AND ds_stage.box_size IS NULL
AND (amount_value, amount_unit) IS NOT NULL
AND (numerator_value, numerator_unit, denominator_value, denominator_unit) IS NULL;

--TODO: Deal with these concepts
/*
select * from ds_stage
where denominator_unit is NOT NULL AND denominator_value is null;
 */

--amount for ML/L
UPDATE ds_stage
SET numerator_value = CASE WHEN bs.unit = 'L' THEN round(((numerator_value::decimal/denominator_value)::numeric * 1000 * amount), 2)
                            ELSE round(((numerator_value/denominator_value)::numeric * amount), 2) END,
    denominator_value = CASE WHEN bs.unit = 'L' THEN bs.amount * 1000
                            ELSE bs.amount END,
    denominator_unit = CASE WHEN bs.unit = 'L' THEN 'ML'
                            ELSE denominator_unit END

FROM (
         SELECT DISTINCT packaging.drug_code,
                         dp.drug_id,
                         trim(substring(product_information, '^\d+\.?\d?'))::numeric as amount,
                         trim(substring(product_information, '(ML|L)'))     as unit
         FROM packaging
                  JOIN drug_product dp
                       ON packaging.drug_code = dp.drug_code
         WHERE product_information ~* '^\d+\.?\d?\s?(ML|L)$'
           AND product_information !~* '/'
    AND packaging.drug_code NOT IN (
			SELECT drug_code
			FROM packaging
			GROUP BY drug_code
			HAVING COUNT(1) > 1)
     ) bs
WHERE bs.drug_id = ds_stage.drug_concept_code
    AND upper(ds_stage.denominator_unit) = 'ML';

--Conversion all G, KG, MCG to MG
UPDATE ds_stage
    SET numerator_value = CASE WHEN upper(numerator_unit) = 'G' THEN numerator_value * 1000
                                WHEN upper(numerator_unit) = 'KG' THEN numerator_value * 1000000
                                WHEN upper(numerator_unit) = 'MCG' THEN (numerator_value::decimal/1000) END,
        numerator_unit = 'MG'
WHERE upper(numerator_unit) in ('G', 'KG', 'MCG');

UPDATE ds_stage
    SET denominator_value = CASE WHEN upper(denominator_unit) = 'G' THEN denominator_value * 1000
                                WHEN upper(denominator_unit) = 'KG' THEN denominator_value * 1000000
                                WHEN upper(denominator_unit) = 'MCG' THEN denominator_value::decimal/1000 END,
        denominator_unit = 'MG'
WHERE upper(denominator_unit) in ('G', 'KG', 'MCG');


--amount for MG/G/Kg/MCG
UPDATE ds_stage
SET numerator_value = CASE WHEN upper(bs.unit) = 'MG' THEN round(((numerator_value::decimal/denominator_value)::numeric * amount), 2)
                            WHEN upper(bs.unit) = 'G' THEN round(((numerator_value::decimal/denominator_value)::numeric * 1000 * amount), 2)
                            WHEN upper(bs.unit) = 'KG' THEN round(((numerator_value::decimal/denominator_value)::numeric * 1000000 * amount), 2) END,
    denominator_value = bs.amount,
    denominator_unit = bs.unit

FROM (
         SELECT DISTINCT packaging.drug_code,
                         dp.drug_id,
                         trim(substring(product_information, '^\d+\.?\d?'))::numeric as amount,
                         CASE WHEN (trim(substring(product_information, '(G|KG|GM)'))) = 'GM' THEN 'G' ELSE trim(substring(product_information, '(G|KG|GM)')) END as unit
         FROM packaging
                  JOIN drug_product dp
                       ON packaging.drug_code = dp.drug_code
         WHERE product_information ~* '^\d+\.?\d?\s?(G|KG|GM)$'
           AND product_information !~* '/'
    AND packaging.drug_code NOT IN (
			SELECT drug_code
			FROM packaging
			GROUP BY drug_code
			HAVING COUNT(1) > 1)
     ) bs
WHERE bs.drug_id = ds_stage.drug_concept_code
    AND upper(ds_stage.denominator_unit) IN ('MG', 'G', 'GM', 'KG');

--amount for OZ
UPDATE ds_stage
SET numerator_value = round(((numerator_value::decimal/denominator_value)::numeric * amount * 29.574), 2), --conversion from OZ to ML
    denominator_value = bs.amount,
    denominator_unit = 'OZ'

FROM (
         SELECT DISTINCT packaging.drug_code,
                         dp.drug_id,
                         trim(substring(product_information, '^\d+\.?\d?'))::numeric as amount,
                         trim(substring(product_information, 'OZ')) as unit
         FROM packaging
                  JOIN drug_product dp
                       ON packaging.drug_code = dp.drug_code
         WHERE product_information ~* '^\d+\.?\d?\s?OZ$'
           AND product_information !~* '/'
    AND packaging.drug_code NOT IN (
			SELECT drug_code
			FROM packaging
			GROUP BY drug_code
			HAVING COUNT(1) > 1)
     ) bs
WHERE bs.drug_id = ds_stage.drug_concept_code
    AND upper(ds_stage.denominator_unit) = 'ML';

--Clear numbers in product_information
UPDATE ds_stage
SET box_size = CASE WHEN (amount_unit, amount_value) IS NOT NULL AND (box_size, numerator_value, numerator_unit, denominator_value, denominator_unit) IS NULL THEN bs.amount
                        ELSE box_size END,
    numerator_value = CASE WHEN (numerator_value, numerator_unit, denominator_value, denominator_unit) IS NOT NULL THEN numerator_value * amount
                        ELSE numerator_value END,
    denominator_value = CASE WHEN (numerator_value, numerator_unit, denominator_value, denominator_unit) IS NOT NULL THEN denominator_value * amount
                        ELSE denominator_value END
FROM
(SELECT DISTINCT packaging.drug_code,
                         dp.drug_id,
                product_information::numeric as amount
from packaging
JOIN drug_product dp
                       ON packaging.drug_code = dp.drug_code

WHERE product_information ~* '^\d+$'
AND packaging.drug_code NOT IN (
			SELECT drug_code
			FROM packaging
			GROUP BY drug_code
			HAVING COUNT(1) > 1)) bs
WHERE bs.drug_id = ds_stage.drug_concept_code;

--Updating drugs that have ingredients with 2 or more dosages that need to be sum up
--HOT BUG FIX
DELETE FROM ds_stage
WHERE (drug_concept_code = '2237356' AND ingredient_concept_code = 'OMOP4920356');  --problem galactose code

UPDATE ds_stage
SET amount_unit = 'MG', amount_value = amount_value * 1000
WHERE drug_concept_code = '2210614' AND ingredient_concept_code = 'OMOP4917795' AND amount_unit = 'G';

--Updating drugs that have ingredients with 2 or more dosages that need to be sum up
with a AS (                             --Only for these concepts amounts and numerators should be summed up
SELECT DISTINCT drug_id
FROM active_ingredients ai
JOIN drug_product dp
    ON dp.drug_code = ai.drug_code
WHERE (ai.drug_code, active_ingredient_code) IN
(SELECT drug_code, active_ingredient_code
    FROM active_ingredients
    GROUP BY drug_code, active_ingredient_code
    HAVING count(*) > 1)

AND ((notes ~* (' EQ|AS |LEAVES|PODS|JUNIPER BERRIES|ASCORBIC ACID|SOD ASCORBATE|MAGNESIUM PROTEINATE|THROMBIN|FOLIC ACID|YEAST|RIBOFLAV|VIT B12|RADIX')
AND notes !~* ('TAB|CAP')
AND ingredient !~* 'POVIDON'
AND strength_unit NOT IN ('C', 'CC', 'D', 'DH', 'X'))
OR (notes IS NULL))),

     sum AS (                              --Table to update from
         select drug_concept_code, ingredient_concept_code,
                sum(coalesce(amount_value, 0)) AS amount_value,
                sum(coalesce(numerator_value, 0)) AS numerator_value
         FROM ds_stage
         WHERE (drug_concept_code, ingredient_concept_code) IN
         (SELECT drug_concept_code, ingredient_concept_code
    FROM ds_stage
    GROUP BY drug_concept_code, ingredient_concept_code
    HAVING count(*) > 1)
         GROUP BY drug_concept_code, ingredient_concept_code
     )

UPDATE ds_stage
    SET amount_value = CASE WHEN sum.amount_value = 0 THEN NULL ELSE sum.amount_value END,
        numerator_value = CASE WHEN sum.numerator_value = 0 THEN NULL ELSE sum.numerator_value END

FROM sum

WHERE ds_stage.drug_concept_code IN (SELECT drug_id FROM a)
AND sum.drug_concept_code = ds_stage.drug_concept_code
AND sum.ingredient_concept_code = ds_stage.ingredient_concept_code
;

--Removing duplicates from ds_stage
with delete AS
(DELETE FROM ds_stage returning *),
inserted AS
(select drug_concept_code, ingredient_concept_code, box_size, amount_value, amount_unit, numerator_value, numerator_unit, denominator_value,denominator_unit,
               row_number() over (partition by drug_concept_code, ingredient_concept_code, box_size, amount_value, amount_unit, numerator_value, numerator_unit, denominator_value, denominator_unit order by drug_concept_code) rank
    FROM delete)
INSERT INTO ds_stage SELECT drug_concept_code,
               ingredient_concept_code,
               box_size,
               amount_value,
               amount_unit,
               numerator_value,
               numerator_unit,
               denominator_value,
               denominator_unit
FROM inserted
WHERE rank = 1;

--Bug fixing for ds_stage
--Removing numerators and denominators where amounts are not null
UPDATE ds_stage
SET numerator_value = NULL,
    numerator_unit = NULL,
    denominator_value = NULL,
    denominator_unit = NULL
WHERE (amount_value, amount_unit) IS NOT NULL;

--* source data has > 1000 mg per ml
--Delete drugs with questionable dosages
	DELETE FROM ds_stage
	WHERE (
			LOWER(numerator_unit) IN ('mg')
			AND LOWER(denominator_unit) IN (
				'ml',
				'g'
				)
			OR LOWER(numerator_unit) IN ('g')
			AND LOWER(denominator_unit) IN ('l')
			)
		AND numerator_value / coalesce(denominator_value, 1) > 1000;

--* source data has 0 in active ingredients
--Delete drugs with 0 in active ingredients
	DELETE FROM ds_stage
	WHERE amount_value <= 0
		OR denominator_value <= 0
		OR numerator_value <= 0;

--Set box_ize to NULL where box_size = 1 (redundant case)
UPDATE ds_stage
SET box_size = NULL
WHERE box_size = 1;

--Removing impossible dosages
--TODO: impove with concepts where > 1000 mg per ml, etc (or check it if already done)
DELETE FROM ds_stage d
WHERE
    (d.numerator_value / coalesce(d.denominator_value, 1)) > 1
AND numerator_unit = denominator_unit;

--Removing pseudounits (NIL)
DELETE FROM ds_stage
WHERE amount_unit = 'NIL'
    OR numerator_unit = 'NIL'
    OR denominator_unit = 'NIL';

--conflicting or incomplete dosage information fix
--1) If there are solid forms for drug -> remove numerator/denominator
--2) If there are solutions, etc -> remove amount
--3) If both -> remove amount
with a AS (
    SELECT DISTINCT ds.drug_concept_code,
                    f.form_name,
                    CASE
                        WHEN upper(form_name) ~* ('CAPSULE|TABLET|GRANULE|GLOBULE|JELLY|PELLET|POWDER')
                            THEN 'numerator/denominator'
                        --Take solid forms, not solutions
                        ELSE 'amount' END AS to_delete
                        --Take solutions, etc.
    FROM ds_stage ds
             JOIN drug_product dp ON ds.drug_concept_code = dp.drug_id
             JOIN forms f on dp.drug_code = f.drug_code
    WHERE drug_concept_code IN
          (
              SELECT a.drug_concept_code
              FROM ds_stage a
                       JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
                  AND a.ingredient_concept_code != b.ingredient_concept_code
                  AND a.amount_unit IS NULL
                  AND b.amount_unit IS NOT NULL
                   --the dosage should be always present if UNIT is not null (checked before)
              UNION

              SELECT a.drug_concept_code
              FROM ds_stage a
                       JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
                  AND a.ingredient_concept_code != b.ingredient_concept_code
                  AND a.numerator_unit IS NULL
                  AND b.numerator_unit IS NOT NULL
              --the dosage should be always present if UNIT is not null (checked before)
          )
)

DELETE
FROM ds_stage
USING a
WHERE
      a.drug_concept_code = ds_stage.drug_concept_code
      AND
      CASE WHEN ds_stage.drug_concept_code IN (select drug_concept_code from a where a.to_delete = 'amount') THEN (amount_unit IS NOT NULL AND amount_value IS NOT NULL)
                ELSE (numerator_value IS NOT NULL AND denominator_value IS NOT NULL AND denominator_unit IS NOT NULL AND numerator_unit IS NOT NULL)
            END
;

--Step 5: pack_content population
--TODO: Unclear how to do this correctly
--Candidates for pack-content table
/*
select distinct dp.drug_code, brand_name, ai.active_ingredient_code, ai.ingredient, p.package_size_unit, p.package_size, p.product_information
from drug_product dp
join active_ingredients ai on dp.drug_code = ai.drug_code
join packaging p on ai.drug_code = p.drug_code
WHERE dp.drug_code IN
(
    select drug_code
    from active_ingredients
    where ingredient ~* 'ethin'
    group by drug_code, active_ingredient_code
    having count(active_ingredient_code) > 1
    )
order by drug_code;
 */
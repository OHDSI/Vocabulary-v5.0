-- sequence_number_3 - drug form code PHARMACEUTICAL_FORM_PF table
-- sequence_number_4 - drug strength code, last 6 digits in the field STRENGTH_STR table
-- drug_name - BN or ingredient name INGREDIENT_IND, SUBSTANCE_SUN tables
-- company (marketing_authorization_holder?) - supplier_code

-- collect drug info for 1000 random drugs
SELECT DISTINCT ON (mp.drug_name)
                mp.drug_name AS drug, sun.substance_name AS ingredient,
                str.text AS strength, pf.text AS drug_form,
                org1.name AS company,
                org2.name AS marketing_authorization_holder
FROM source_medicinal_product_mp mp
JOIN ingredient_ing ing
    ON mp.medicinalprod_id = ing.medicinalprod_id
JOIN substance_sun sun
    ON ing.substance_id = sun.substance_id
JOIN strength_str str
    ON RIGHT(mp.sequence_number_4, 6) = str.strength_id
JOIN pharmaceutical_form_pf pf
    ON RIGHT(mp.sequence_number_3, 3) = pf.pharmform_id
JOIN organization_org org1
    ON mp.company = org1.organization_id
JOIN organization_org org2
    ON mp.marketing_authorization_holder = org2.organization_id
LIMIT 1000;

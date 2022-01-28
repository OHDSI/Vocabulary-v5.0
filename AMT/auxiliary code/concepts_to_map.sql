-- ingredients to map
SELECT DISTINCT name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM ingredient_to_map itm
WHERE lower(itm.name) NOT IN (
                             SELECT lower(new_name)
                             FROM ingredient_mapped
                             WHERE new_name IS NOT NULL
                             )
ORDER BY itm.name;


--brand_names_to_map
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM brand_name_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM brand_name_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;


-- suppliers_to_map
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM supplier_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM supplier_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;


-- dose_form_to_map
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM dose_form_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM dose_form_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;


--unit_to_map
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS conversion_factor,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM unit_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM unit_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;


--vaccines_to_map
SELECT DISTINCT source_concept_name, source_concept_class_id, concept_id, concept_name, concept_class_id,
                standard_concept, invalid_reason, domain_id, vocabulary_id, new_concept, dosage
FROM vaccines_to_map
ORDER BY source_concept_name;
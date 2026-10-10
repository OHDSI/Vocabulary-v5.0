-- Procedure/admin codes that match a JnJ brand name or ingredient (from bnui lookup table)
-- but do NOT have a mapping to a Drug domain concept.
-- bnui is extracted from the JnJ website: brand names and active ingredients.
SELECT c.*
FROM concept c
JOIN @scratchSchema.bnui
  ON (    UPPER(c.concept_name) LIKE CONCAT('%', bnui.cleaned_name, '%')
       OR LOWER(c.concept_name) LIKE CONCAT('%', bnui.ingr_name,    '%') )
JOIN concept c2
  ON CHARINDEX(LOWER(c2.concept_name), LOWER(c.concept_name)) > 0
 AND (    c2.standard_concept = 'S'    AND c2.concept_class_id = 'Ingredient' AND c2.vocabulary_id = 'RxNorm' AND LEN(c2.concept_name) > 4
       OR c2.invalid_reason IS NULL    AND c2.concept_class_id = 'Brand Name'  AND c2.vocabulary_id = 'RxNorm' AND LEN(c2.concept_name) > 4 )
WHERE c.concept_id NOT IN (
  SELECT c.concept_id
  FROM concept c
  JOIN concept_relationship cr
    ON cr.concept_id_1 = c.concept_id AND relationship_id = 'Maps to'
  JOIN concept c2
    ON c2.concept_id = cr.concept_id_2 AND c2.domain_id = 'Drug'
  WHERE c.vocabulary_id IN ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
    AND c.concept_class_id NOT IN ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy')
    AND (    LOWER(c.concept_name) LIKE '%administration%'
          OR LOWER(c.concept_name) LIKE '%administered through%'
          OR c.concept_name LIKE '% mg %'   OR c.concept_name LIKE '% mg)%'  OR c.concept_name LIKE '% mg,%'
          OR c.concept_name LIKE '% units %' OR c.concept_name LIKE '% units)%' OR c.concept_name LIKE '% units,%'
          OR c.concept_name LIKE '% ml %'   OR c.concept_name LIKE '% ml)%'  OR c.concept_name LIKE '% ml,%'
          OR c.concept_name LIKE '% meg %'  OR c.concept_name LIKE '% mcg %'
          OR c.concept_name LIKE '% millicurie%'
          OR c.concept_name LIKE '% gram %' OR c.concept_name LIKE '% grams %'
          OR c.concept_name LIKE '% million %'
          OR c.concept_name LIKE '% cc %'   OR c.concept_name LIKE '% cc)%'
          OR LOWER(c.concept_name) LIKE '%introduction of %'
          OR LOWER(c.concept_name) LIKE '%per millicurie%'
          OR LOWER(c.concept_name) LIKE '%vaccine%'
          OR LOWER(c.concept_name) LIKE '%injection%'
          OR LOWER(c.concept_name) LIKE '%for intravenous use%'
          OR LOWER(c.concept_name) LIKE '%releasing intrauterine system%'
          OR c.concept_name LIKE '%patches, %' )
)
AND c.vocabulary_id IN ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
AND c.concept_class_id NOT IN ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy')
AND (    LOWER(c.concept_name) LIKE 'administration%'
      OR LOWER(c.concept_name) LIKE '%administered through%'
      OR LOWER(c.concept_name) LIKE 'introduction of %'
      OR LOWER(c.concept_name) LIKE '%per millicurie%'
      OR LOWER(c.concept_name) LIKE '%vaccine%'
      OR LOWER(c.concept_name) LIKE '%for intravenous use%'
      OR LOWER(c.concept_name) LIKE '%releasing intrauterine system%'
      OR LOWER(c.concept_name) LIKE '%patches%'
      OR c.concept_name LIKE '% mg %'   OR c.concept_name LIKE '% mg)%'  OR c.concept_name LIKE '% mg,%'
      OR c.concept_name LIKE '% units %' OR c.concept_name LIKE '% units)%' OR c.concept_name LIKE '% units,%'
      OR c.concept_name LIKE '% ml %'   OR c.concept_name LIKE '% ml)%'  OR c.concept_name LIKE '% ml,%'
      OR c.concept_name LIKE '% meg %'  OR c.concept_name LIKE '% mcg %'
      OR c.concept_name LIKE '% millicurie%'
      OR c.concept_name LIKE '% gram %' OR c.concept_name LIKE '% grams %'
      OR c.concept_name LIKE '% million %' )
ORDER BY c.vocabulary_id, c.concept_code

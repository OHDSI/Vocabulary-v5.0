-- Post-GenericUpdate fixes for SNOMED Veterinary
-- Run this immediately after GenericUpdate completes

-- RxNorm is standard, don't change SNOMED Veterinary drugs to standard
-- Fix 1: Restore Standard status for unmapped medicinal products with external mappings
-- UPDATE concept c
-- SET standard_concept = 'S'
-- WHERE c.vocabulary_id = 'SNOMED Veterinary'
--  AND c.concept_class_id IN ('Pharma/Biol Product', 'Clinical Drug', 'Clinical Drug Form')
--   AND c.standard_concept IS NULL
--   AND c.invalid_reason IS NULL
--   AND EXISTS (
--       SELECT 1 FROM concept_relationship cr
--       WHERE cr.concept_id_1 = c.concept_id
--         AND cr.relationship_id = 'Maps to'
--   );

-- Fix 2: Restore any Maps to relationships that were incorrectly deprecated and fix their dates
-- Catches both deprecated relationships (invalid_reason = 'D') and bad date ranges (valid_end_date <= valid_start_date)
UPDATE concept_relationship cr
SET invalid_reason = NULL,
    valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
WHERE cr.relationship_id = 'Maps to'
  AND (cr.invalid_reason = 'D' OR cr.valid_end_date <= cr.valid_start_date)
  AND EXISTS (
      SELECT 1 FROM concept c
      WHERE c.concept_id = cr.concept_id_1
        AND c.vocabulary_id = 'SNOMED Veterinary'
        AND c.concept_class_id IN ('Pharma/Biol Product', 'Clinical Drug', 'Clinical Drug Form')
  );
-- Fix 3: Also fix the inverse Mapped from relationships
UPDATE concept_relationship cr
SET invalid_reason = NULL,
    valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
WHERE cr.relationship_id = 'Mapped from'
  AND (cr.invalid_reason = 'D' OR cr.valid_end_date <= cr.valid_start_date)
  AND EXISTS (
      SELECT 1 FROM concept c
      WHERE c.concept_id = cr.concept_id_2
        AND c.vocabulary_id = 'SNOMED Veterinary'
        AND c.concept_class_id IN ('Pharma/Biol Product', 'Clinical Drug', 'Clinical Drug Form')
  );

-- Fix 4: Remove self-mappings for deprecated/upgraded concepts
-- Self-mappings should only exist for valid concepts
DELETE FROM concept_relationship cr
WHERE cr.relationship_id IN ('Maps to', 'Mapped from')
  AND cr.concept_id_1 = cr.concept_id_2
  AND EXISTS (
      SELECT 1 FROM concept c
      WHERE c.concept_id = cr.concept_id_1
        AND c.vocabulary_id = 'SNOMED Veterinary'
        AND c.invalid_reason IS NOT NULL
  );
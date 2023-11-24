--1. Ensure no UKDE concepts are present in concept_stage

-- It looks like UKDE makes changes to reactivate concept
-- OVER SNOMED INTERNATIONAL. Another reason to remove it.
-- So let's limit search to concepts that were not reactivated by UKDE
WITH last_non_uk_active AS (
    SELECT
        c.id,
        first_value(c.active) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS active
    FROM sources.sct2_concept_full_merged c
    WHERE moduleid NOT IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
),
killed_by_intl AS (
    SELECT id
    FROM last_non_uk_active
    WHERE active = 0
),
current_module AS (
    SELECT
        c.id,
        first_value(moduleid) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS moduleid
    FROM sources.sct2_concept_full_merged c
)
SELECT DISTINCT
    cs.concept_code,
    cs.concept_name,
    cs.concept_class_id,
    cs.valid_start_date,
    cs.valid_end_date,
    cs.invalid_reason,
    cm.moduleid
FROM current_module cm
JOIN concept_stage cs ON
    cs.concept_code = cm.id :: VARCHAR AND
    cs.vocabulary_id = 'SNOMED'
LEFT JOIN killed_by_intl ki ON
    ki.id = cm.id
WHERE
        ki.id IS NULL
    AND moduleid IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
;

-- 2. Ensure no UKDE-specific synonyms are assigned to concepts
WITH uk_synonyms AS (
    SELECT
        s.conceptid,
        s.term,
        s.active,
        ROW_NUMBER() OVER
            (PARTITION BY s.id ORDER BY s.effectivetime DESC) AS rn
    FROM sources.sct2_desc_full_merged s
    WHERE moduleid IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
),
non_uk_synonyms AS (
    SELECT
        s.conceptid,
        s.term,
        s.active,
        ROW_NUMBER() OVER
            (PARTITION BY s.id ORDER BY s.effectivetime DESC) AS rn
    FROM sources.sct2_desc_full_merged s
    WHERE moduleid NOT IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
)
SELECT
    cs.concept_code,
    cs.concept_name,
    cs.valid_start_date,
    cs.invalid_reason,
    'concept.concept_name' as field
FROM concept_stage cs
JOIN uk_synonyms ON
        uk_synonyms.conceptid :: varchar = cs.concept_code
    AND vocabulary_pack.cutconceptname(uk_synonyms.term) = cs.concept_name
    AND uk_synonyms.active = 1
    AND uk_synonyms.rn = 1
LEFT JOIN non_uk_synonyms ON -- Not duplicated by a "good" synonym
        uk_synonyms.conceptid = non_uk_synonyms.conceptid
    AND vocabulary_pack.cutconceptname(non_uk_synonyms.term) = cs.concept_name
    AND non_uk_synonyms.active = 1
    AND non_uk_synonyms.rn = 1
WHERE
        non_uk_synonyms.conceptid IS NULL
    AND cs.vocabulary_id = 'SNOMED'
    AND cs.domain_id != 'Route' --[AVOC-4087], this is a special case

        UNION ALL

SELECT
    cs.concept_code,
    cs.concept_name,
    cs.valid_start_date,
    cs.invalid_reason,
    'concept_synonym.concept_synonym_name' as field
FROM concept_stage cs
JOIN concept_synonym_stage ON
        concept_synonym_stage.synonym_concept_code = cs.concept_code
JOIN uk_synonyms ON
            uk_synonyms.conceptid :: varchar = cs.concept_code
        AND vocabulary_pack.cutconceptsynonymname(uk_synonyms.term) = concept_synonym_stage.synonym_name
        AND uk_synonyms.active = 1
        AND uk_synonyms.rn = 1
LEFT JOIN non_uk_synonyms ON -- Not duplicated by a "good" synonym
            uk_synonyms.conceptid = non_uk_synonyms.conceptid
        AND vocabulary_pack.cutconceptsynonymname(non_uk_synonyms.term) = concept_synonym_stage.synonym_name
        AND non_uk_synonyms.active = 1
        AND non_uk_synonyms.rn = 1
WHERE
        non_uk_synonyms.conceptid IS NULL
    AND cs.vocabulary_id = 'SNOMED'
;

-- 3. Relationships are very painful to test, so I will focus on 'Is a' relationships,
-- which are the most important and most numerous ones.

-- Maybe it is a time for a lookup table from relationshipId to relationship_id
-- instead of hardcoded legacy logic
WITH uk_is_a AS (
    SELECT
        r.id,
        r.sourceid,
        r.destinationid,
        r.active,
        ROW_NUMBER() OVER
            (PARTITION BY r.id ORDER BY r.effectivetime DESC) AS rn
    FROM sources.sct2_rela_full_merged r
    WHERE
        moduleid IN (
            999000011000001104, --UK Drug extension
            999000021000001108  --UK Drug extension reference set module
        )
    AND typeid = 116680003
),
non_uk_is_a AS (
    SELECT
        r.id,
        r.sourceid,
        r.destinationid,
        r.active,
        ROW_NUMBER() OVER
            (PARTITION BY r.id ORDER BY r.effectivetime DESC) AS rn
    FROM sources.sct2_rela_full_merged r
    WHERE
        moduleid NOT IN (
            999000011000001104, --UK Drug extension
            999000021000001108  --UK Drug extension reference set module
        )
    AND typeid = 116680003
)
SELECT
    cs.concept_code,
    cs.concept_name,
    cs.concept_class_id,
    'Is a' AS relationship_id,
    cs2.concept_code AS destination_concept_code,
    cs2.concept_name AS destination_concept_name,
    cs2.concept_class_id AS destination_concept_class_id
FROM concept_stage cs
JOIN concept_relationship_stage cr ON
        cr.concept_code_1 = cs.concept_code
    AND cr.vocabulary_id_1 = cs.vocabulary_id
    AND cr.relationship_id = 'Is a'
    AND cs.vocabulary_id = 'SNOMED' -- for idx
JOIN concept_stage cs2 ON
        cs2.concept_code = cr.concept_code_2
    AND cs2.vocabulary_id = cr.vocabulary_id_2
    AND cs2.vocabulary_id = 'SNOMED' -- for idx
JOIN uk_is_a ON
        uk_is_a.sourceid :: varchar = cs.concept_code
    AND uk_is_a.destinationid :: varchar = cs2.concept_code
    AND uk_is_a.active = 1
    AND uk_is_a.rn = 1
LEFT JOIN non_uk_is_a ON -- Not duplicated by a "good" Is a
        uk_is_a.sourceid = non_uk_is_a.sourceid
    AND uk_is_a.destinationid = non_uk_is_a.destinationid
    AND non_uk_is_a.active = 1
    AND non_uk_is_a.rn = 1
WHERE
        non_uk_is_a.id IS NULL
;

-- 4. Ensure no UKDE-specific replacements are assigned to concepts
WITH uk_replacements AS (
    SELECT
        r.refsetid,
        r.referencedcomponentid as sourceId,
        r.targetcomponent as targetId,
        r.active,
        ROW_NUMBER() OVER
            (PARTITION BY r.refsetid, r.referencedcomponentid, r.targetcomponent ORDER BY r.effectivetime DESC) AS rn
    FROM sources.der2_crefset_assreffull_merged r
    WHERE
            moduleid IN (
                999000011000001104, --UK Drug extension
                999000021000001108  --UK Drug extension reference set module
            )
        AND refsetid IN (
             900000000000526001, -- Replaced by
             900000000000523009, -- Possibly equivalent to
             900000000000528000, -- Was a
             900000000000527005, -- Same as
             900000000000530003  -- Alt to
        )
),
non_uk_replacements AS (
    SELECT
        r.refsetid,
        r.referencedcomponentid as sourceId,
        r.targetcomponent as targetId,
        r.active,
        ROW_NUMBER() OVER
            (PARTITION BY r.refsetid, r.referencedcomponentid, r.targetcomponent ORDER BY r.effectivetime DESC) AS rn
    FROM sources.der2_crefset_assreffull_merged r
    WHERE
            moduleid NOT IN (
                999000011000001104, --UK Drug extension
                999000021000001108  --UK Drug extension reference set module
            )
        AND refsetid IN (
             900000000000526001, -- Replaced by
             900000000000523009, -- Possibly equivalent to
             900000000000528000, -- Was a
             900000000000527005, -- Same as
             900000000000530003  -- Alt to
        )
)
SELECT
    cs.concept_code,
    cs.concept_name,
    cs.concept_class_id,
    uk_replacements.refsetid,
    cs2.concept_code AS destination_concept_code,
    cs2.concept_name AS destination_concept_name,
    cs2.concept_class_id AS destination_concept_class_id
FROM concept_stage cs
JOIN concept_relationship_stage cr ON
        cr.concept_code_1 = cs.concept_code
    AND cr.vocabulary_id_1 = cs.vocabulary_id
    AND cr.relationship_id IN (
         'Concept replaced by',
         'Concept poss_eq to',
         'Concept was_a to',
         'Concept same_as to',
         'Concept alt_to to'
    )
    AND cs.vocabulary_id = 'SNOMED' -- for idx
JOIN concept_stage cs2 ON
        cs2.concept_code = cr.concept_code_2
    AND cs2.vocabulary_id = cr.vocabulary_id_2
    AND cs2.vocabulary_id = 'SNOMED' -- for idx
JOIN uk_replacements ON
        uk_replacements.sourceId :: varchar = cs.concept_code
    AND uk_replacements.targetId :: varchar = cs2.concept_code
    AND uk_replacements.active = 1
    AND uk_replacements.rn = 1
    AND cr.relationship_id =
        CASE refsetid
            WHEN 900000000000526001
                THEN 'Concept replaced by'
            WHEN 900000000000523009
                THEN 'Concept poss_eq to'
            WHEN 900000000000528000
                THEN 'Concept was_a to'
            WHEN 900000000000527005
                THEN 'Concept same_as to'
            WHEN 900000000000530003
                THEN 'Concept alt_to to'
        END
LEFT JOIN non_uk_replacements ON -- Not duplicated by a "good" replacement
        uk_replacements.sourceId = non_uk_replacements.sourceId
    AND uk_replacements.targetId = non_uk_replacements.targetId
    AND uk_replacements.refsetid = non_uk_replacements.refsetid
    AND non_uk_replacements.active = 1
    AND non_uk_replacements.rn = 1
WHERE
        non_uk_replacements.refsetid IS NULL
    AND cs.vocabulary_id = 'SNOMED'
;
-- 5. Make sure concept_manual does not add non-deprecated concepts exclusive to UKDE
WITH last_non_uk_active AS (
    SELECT
        c.id,
        first_value(c.active) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS active
    FROM sources.sct2_concept_full_merged c
    WHERE moduleid NOT IN (
                           999000011000001104, --UK Drug extension
                           999000021000001108  --UK Drug extension reference set module
        )
),
killed_by_intl AS (
    SELECT id
    FROM last_non_uk_active
    WHERE active = 0
),
current_module AS (
    SELECT
        c.id,
        first_value(moduleid) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS moduleid
    FROM sources.sct2_concept_full_merged c
)
SELECT *
FROM concept_manual c
JOIN current_module cm ON
        cm.id :: text = c.concept_code
    AND cm.moduleid IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
LEFT JOIN killed_by_intl ki ON
    ki.id = cm.id
WHERE
        ki.id IS NULL
    AND c.vocabulary_id = 'SNOMED'
    AND c.invalid_reason IS NULL
;
-- 6. Make sure concept_relationship_manual does not add non-deprecated relationships exclusive to UKDE
WITH last_non_uk_active AS (
    SELECT
        c.id,
        first_value(c.active) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS active
    FROM sources.sct2_concept_full_merged c
    WHERE moduleid NOT IN (
             99000011000001104, --UK Drug extension
             99000021000001108  --UK Drug extension reference set module
        )
),
killed_by_intl AS (
    SELECT id
    FROM last_non_uk_active
    WHERE active = 0
),
current_module AS (
    SELECT
        c.id,
        first_value(moduleid) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS moduleid
    FROM sources.sct2_concept_full_merged c
)
SELECT cm.id, concept_relationship_manual.*
FROM concept_relationship_manual
JOIN current_module cm ON
        (
            (
                cm.id :: text = concept_code_1
                AND vocabulary_id_1 = 'SNOMED'
            )
                OR
            (
                    cm.id :: text = concept_code_2
                AND concept_code_2 = 'SNOMED'
            )
        )
    AND cm.moduleid IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
LEFT JOIN killed_by_intl ki ON
    ki.id = cm.id
WHERE
        ki.id IS NULL
    AND concept_relationship_manual.invalid_reason IS NULL
    AND 'SNOMED' IN (vocabulary_id_1, vocabulary_id_2)
;
-- Get counts:
CREATE OR REPLACE VIEW ukde_ghosts AS
WITH last_non_uk_active AS (
    SELECT
        c.id,
        first_value(c.active) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS active
    FROM sources.sct2_concept_full_merged c
    WHERE moduleid NOT IN (
           999000011000001104, --UK Drug extension
           999000021000001108  --UK Drug extension reference set module
        )
),
belongs_to_uk_module AS (
    SELECT
        c.id,
        first_value(moduleid) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS moduleid
    FROM sources.sct2_concept_full_merged c
    LEFT JOIN last_non_uk_active na ON
        na.id = c.id AND
        na.active = 0
    WHERE
            c.moduleid IN (
                999000011000001104, --UK Drug extension
                999000021000001108  --UK Drug extension reference set module
            )
    AND na.id IS NULL
)
SELECT c.*
FROM devv5.concept c
JOIN belongs_to_uk_module b ON
        b.id :: text = c.concept_code
    AND c.vocabulary_id = 'SNOMED'
;
--1. Count of invalid concepts in UK Drug extension
SELECT count(1) as cnt, 'Total invalid concepts' as lbl, 'Invalid' as shorthand
FROM ukde_ghosts c
WHERE c.invalid_reason IS NOT NULL
    UNION ALL
--2. Total count of concepts in Drug domain
SELECT count(1), 'Total concepts in Drug domain', 'Drug'
FROM ukde_ghosts c
WHERE
        c.domain_id = 'Drug'
    AND c.invalid_reason IS NULL

    UNION ALL
    --2.1. Among them, matching dm+d concepts
SELECT
    count(1),
    'Total concepts in Drug domain matching dm+d concepts',
    'Drug/dmd now'
FROM ukde_ghosts c
JOIN devv5.concept dm ON
        dm.concept_code = c.concept_code
    AND dm.vocabulary_id = 'dm+d'
WHERE
        c.domain_id = 'Drug'
    AND c.invalid_reason IS NULL

    UNION ALL
    --2.2. Among them, matching dm+d sources, but not existing concepts
SELECT
    count(DISTINCT c.concept_code),
    'Total concepts in Drug domain matching dm+d '||
        'sources, but not existing concepts',
    'Drug/dmd next'
FROM ukde_ghosts c
LEFT JOIN devv5.concept dm ON
        dm.concept_code = c.concept_code
    AND dm.vocabulary_id = 'dm+d'
JOIN (
        SELECT vtmid as id from vtms
            UNION ALL
        SELECT isid FROM ingredient_substances
            UNION ALL
        SELECT vpid FROM vmps
            UNION ALL
        SELECT apid FROM amps
            UNION ALL
        SELECT vppid FROM vmpps
            UNION ALL
        SELECT appid FROM ampps
    ) dm_sources ON
        dm_sources.id = c.concept_code
WHERE
        c.domain_id = 'Drug'
    AND c.invalid_reason IS NULL
    AND dm.concept_code IS NULL
        UNION ALL
--3. Total count of concepts in Device domain matching dm+d concepts -- Standard
SELECT
    count(1),
    'Standard concepts in Device domain matching dm+d concepts',
    'Device/dmd_standard'
FROM ukde_ghosts c
JOIN devv5.concept dm ON
        dm.concept_code = c.concept_code
    AND dm.vocabulary_id = 'dm+d'
WHERE
        c.domain_id = 'Device'
    AND c.invalid_reason IS NULL
    AND c.standard_concept = 'S'
        UNION ALL
--4. Total count of concepts in Device domain matching dm+d concepts -- Non-standard
SELECT
    count(1),
    'Non-standard concepts in Device domain matching dm+d concepts',
    'Device/dmd_nonstandard'
FROM ukde_ghosts c
JOIN devv5.concept dm ON
        dm.concept_code = c.concept_code
    AND dm.vocabulary_id = 'dm+d'
WHERE
        c.domain_id = 'Device'
    AND c.invalid_reason IS NULL
    AND c.standard_concept IS NULL
        UNION ALL
--5. Total count of concepts in Device domain that are not in dm+d, but have dm+d sources
SELECT
    count(DISTINCT c.concept_code),
    'Total concepts in Device domain that are not in dm+d, but have dm+d sources',
    'Device/dmd_next'
FROM ukde_ghosts c
         LEFT JOIN devv5.concept dm ON
            dm.concept_code = c.concept_code
        AND dm.vocabulary_id = 'dm+d'
         JOIN (
    SELECT vtmid as id from vtms
    UNION ALL
    SELECT isid FROM ingredient_substances
    UNION ALL
    SELECT vpid FROM vmps
    UNION ALL
    SELECT apid FROM amps
    UNION ALL
    SELECT vppid FROM vmpps
    UNION ALL
    SELECT appid FROM ampps
) dm_sources ON
        dm_sources.id = c.concept_code
WHERE
        c.domain_id = 'Device'
    AND c.invalid_reason IS NULL
    AND dm.concept_code IS NULL
        UNION ALL
--5. Total count of concepts in Route domain -- Standard
SELECT
    count(1),
    'Standard concepts in Route domain',
    'Metadata/Standard Route'
FROM ukde_ghosts c
WHERE
        c.domain_id = 'Route'
    AND c.invalid_reason IS NULL
    AND c.standard_concept = 'S'
        UNION ALL
--6. Total count of concepts in other domains and Non-standard Routes
SELECT count(1), 'Other domains and Non-standard Routes', 'Metadata/Other'
FROM ukde_ghosts c
WHERE
        c.domain_id NOT IN ('Drug', 'Device')
    AND (NOT c.domain_id = 'Route' AND c.standard_concept = 'S')
    AND c.invalid_reason IS NULL
        UNION ALL
--7. Devices total count
SELECT count(1), 'Total concepts in Device domain', 'Device'
FROM ukde_ghosts c
WHERE
        c.domain_id = 'Device'
    AND c.invalid_reason IS NULL
;
DROP VIEW IF EXISTS ukde_ghosts
;
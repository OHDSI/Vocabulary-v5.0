-- orphan_drug_concepts.sql
--
-- Detects "orphan" standard drug concepts: valid standard RxNorm / RxNorm Extension drug concepts
-- that have NO valid Ingredient among their ancestors in concept_ancestor (the hierarchy is broken
-- somewhere between the concept and its ingredient).
--
-- For every orphan it returns its highest existing ancestor(s) (largest max_levels_of_separation;
-- the concept itself if it has no ancestors at all) and tells whether that top concept
-- still has a further possible parent, i.e. a valid hierarchical relationship exists but the
-- target is invalid (D/U), so the link does not reach concept_ancestor.
--
-- Run in a schema that contains concept, concept_relationship, concept_ancestor and relationship
-- (e.g. dev_xyz after GenericUpdate + concept_ancestor build, or devv5/prodv5 for a baseline).
-- Nothing is modified.
--
-- top_status:
--   ONLY_INVALID_PARENT_LINK           : the top ancestor has a valid hierarchical link to a parent, but all such
--                                        parents are invalid -> remap/replace the invalid parent
--   VALID_PARENT_LINK_NOT_IN_ANCESTOR  : a valid link to a valid parent exists but is missing from
--                                        concept_ancestor -> concept_ancestor is stale or incomplete
--   TOP_IS_INVALID_INGREDIENT          : the chain reaches an Ingredient, but that Ingredient is invalid
--   NO_PARENT_LINK                     : no hierarchical link up at all -> the relationship is missing
--
-- The hierarchy rules are the "neighbor" class relationships from vocabulary_pack.pConceptAncestor
-- (rxnorm_allowed_rel); attribute classes (Brand Name, Dose Form, Supplier, ...) are not part of the chain.

WITH hier (parent_class, rel, child_class) AS (
    -- parent -> child as stored in pConceptAncestor.rxnorm_allowed_rel
    VALUES
        ('Ingredient',          'RxNorm ing of',       'Clinical Drug Comp'),
        ('Ingredient',          'RxNorm ing of',       'Clinical Drug Form'),
        ('Clinical Drug Comp',  'Constitutes',         'Clinical Drug'),
        ('Clinical Drug Comp',  'Has tradename',       'Branded Drug Comp'),
        ('Clinical Drug Form',  'RxNorm inverse is a', 'Clinical Drug'),
        ('Clinical Drug Form',  'Has tradename',       'Branded Drug Form'),
        ('Branded Drug Comp',   'Constitutes',         'Branded Drug'),
        ('Branded Drug Form',   'RxNorm inverse is a', 'Branded Drug'),
        ('Clinical Drug',       'Has tradename',       'Branded Drug'),
        ('Clinical Drug',       'Has quantified form', 'Quant Clinical Drug'),
        ('Clinical Drug',       'Available as box',    'Clinical Drug Box'),
        ('Branded Drug',        'Has quantified form', 'Quant Branded Drug'),
        ('Branded Drug',        'Available as box',    'Branded Drug Box'),
        ('Quant Clinical Drug', 'Has tradename',       'Quant Branded Drug'),
        ('Quant Clinical Drug', 'Available as box',    'Quant Clinical Box'),
        ('Quant Branded Drug',  'Available as box',    'Quant Branded Box'),
        ('Clinical Drug Box',   'Has quantified form', 'Quant Clinical Box'),
        ('Clinical Drug Box',   'Has tradename',       'Branded Drug Box'),
        ('Branded Drug Box',    'Has quantified form', 'Quant Branded Box'),
        ('Quant Clinical Box',  'Has tradename',       'Quant Branded Box'),
        ('Clinical Pack',       'Has tradename',       'Branded Pack'),
        ('Clinical Pack',       'Available as box',    'Clinical Pack Box'),
        ('Branded Pack',        'Available as box',    'Branded Pack Box'),
        ('Clinical Pack Box',   'Has tradename',       'Branded Pack Box')
    UNION ALL
    SELECT p.c, 'Contained in', k.c
    FROM (VALUES ('Clinical Drug'), ('Quant Clinical Drug'), ('Branded Drug'), ('Quant Branded Drug')) p (c)
    CROSS JOIN (VALUES ('Clinical Pack'), ('Clinical Pack Box'), ('Branded Pack'), ('Branded Pack Box'), ('Marketed Product')) k (c)
    UNION ALL
    SELECT p.c, 'Has marketed form', 'Marketed Product'
    FROM (VALUES ('Clinical Drug'), ('Branded Drug'), ('Quant Clinical Drug'), ('Quant Branded Drug'),
                 ('Clinical Drug Box'), ('Branded Drug Box'), ('Quant Clinical Box'), ('Quant Branded Box'),
                 ('Clinical Pack'), ('Branded Pack'), ('Clinical Pack Box'), ('Branded Pack Box')) p (c)
),

-- child -> parent direction: the relationship_id as seen from the child concept
hier_up AS (
    SELECT h.parent_class,
           h.child_class,
           r.reverse_relationship_id AS rel_up
    FROM hier h
    JOIN relationship r ON r.relationship_id = h.rel
),

-- classes that are attributes / groupers, not part of the ingredient-to-drug chain
attr_classes (concept_class_id) AS (
    VALUES ('Brand Name'), ('Dose Form'), ('Dose Form Group'), ('Clinical Dose Group'),
           ('Branded Dose Group'), ('Supplier'), ('Precise Ingredient')
),

-- scope: valid standard drug-hierarchy concepts, excluding Ingredient itself and the attribute classes
scope AS (
    SELECT c.*
    FROM concept c
    WHERE c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        AND c.domain_id = 'Drug'
        AND c.standard_concept = 'S'
        AND c.invalid_reason IS NULL
        AND c.concept_class_id <> 'Ingredient'
        AND c.concept_class_id NOT IN (SELECT concept_class_id FROM attr_classes)
),

-- orphans: no valid Ingredient among the ancestors
orphans AS (
    SELECT s.*
    FROM scope s
    WHERE NOT EXISTS (
            SELECT 1
            FROM concept_ancestor ca
            JOIN concept ing ON ing.concept_id = ca.ancestor_concept_id
                AND ing.concept_class_id = 'Ingredient'
                AND ing.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                AND ing.invalid_reason IS NULL
            WHERE ca.descendant_concept_id = s.concept_id
            )
),

-- highest existing ancestor(s): the self-row (0 levels) guarantees a result even with no ancestors
tops AS (
    SELECT o.concept_id AS orphan_id,
           a.concept_id AS top_id,
           ca.max_levels_of_separation AS levels_up,
           RANK() OVER (PARTITION BY o.concept_id ORDER BY ca.max_levels_of_separation DESC) AS rnk
    FROM orphans o
    JOIN concept_ancestor ca ON ca.descendant_concept_id = o.concept_id
    JOIN concept a ON a.concept_id = ca.ancestor_concept_id
        AND a.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        AND a.concept_class_id NOT IN (SELECT concept_class_id FROM attr_classes)
),

top_ancestors AS (
    SELECT * FROM tops WHERE rnk = 1
),

-- valid hierarchical links from the top ancestor to a parent of the right class
parent_links AS (
    SELECT t.top_id,
           r.relationship_id,
           p.concept_id AS parent_id,
           p.concept_name AS parent_name,
           p.concept_class_id AS parent_class,
           p.invalid_reason AS parent_invalid_reason
    FROM (SELECT DISTINCT top_id FROM top_ancestors) t
    JOIN concept tc ON tc.concept_id = t.top_id
    JOIN hier_up hu ON hu.child_class = tc.concept_class_id
    JOIN concept_relationship r ON r.concept_id_1 = t.top_id
        AND r.relationship_id = hu.rel_up
        AND r.invalid_reason IS NULL
    JOIN concept p ON p.concept_id = r.concept_id_2
        AND p.concept_class_id = hu.parent_class
        AND p.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
),

parent_summary AS (
    SELECT top_id,
           BOOL_OR(parent_invalid_reason IS NULL) AS has_valid_parent,
           BOOL_OR(parent_invalid_reason IS NOT NULL) AS has_invalid_parent,
           STRING_AGG(DISTINCT parent_id || ' ' || parent_name || ' [' || parent_class || ', ' || relationship_id
                      || ', invalid_reason=' || COALESCE(parent_invalid_reason, 'NULL') || ']', '; ')
               FILTER (WHERE parent_invalid_reason IS NOT NULL) AS invalid_parents
    FROM parent_links
    GROUP BY top_id
)

SELECT o.concept_id AS orphan_concept_id,
       o.concept_code AS orphan_concept_code,
       o.concept_name AS orphan_concept_name,
       o.concept_class_id AS orphan_class,
       o.vocabulary_id AS orphan_vocabulary_id,
       tc.concept_id AS top_ancestor_id,
       tc.concept_code AS top_ancestor_code,
       tc.concept_name AS top_ancestor_name,
       tc.concept_class_id AS top_ancestor_class,
       tc.invalid_reason AS top_ancestor_invalid_reason,
       t.levels_up,
       CASE
           WHEN COALESCE(ps.has_valid_parent, FALSE) THEN 'VALID_PARENT_LINK_NOT_IN_ANCESTOR'
           WHEN COALESCE(ps.has_invalid_parent, FALSE) THEN 'ONLY_INVALID_PARENT_LINK'
           WHEN tc.concept_class_id = 'Ingredient' THEN 'TOP_IS_INVALID_INGREDIENT'
           ELSE 'NO_PARENT_LINK'
       END AS top_status,
       COALESCE(ps.has_invalid_parent, FALSE) AS has_invalid_further_parent,
       ps.invalid_parents
FROM top_ancestors t
JOIN orphans o ON o.concept_id = t.orphan_id
JOIN concept tc ON tc.concept_id = t.top_id
LEFT JOIN parent_summary ps ON ps.top_id = t.top_id
ORDER BY top_status, o.vocabulary_id, o.concept_class_id, o.concept_id;

-- Summary by status (replace the final SELECT above with this to get counts):
-- SELECT top_status, orphan_vocabulary_id, orphan_class, COUNT(DISTINCT orphan_concept_id) AS orphans
-- FROM (<query above>) q GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;

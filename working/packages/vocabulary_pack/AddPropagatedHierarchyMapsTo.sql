CREATE OR REPLACE FUNCTION vocabulary_pack.AddPropagatedHierarchyMapsTo(
    p_relationship_id text[] DEFAULT NULL::text[],
    p_vocabulary_id_1 text[] DEFAULT NULL::text[],
    p_vocabulary_id_2 text[] DEFAULT NULL::text[])
RETURNS void
LANGUAGE plpgsql
AS $BODY$
/*
    The function propagates the hierarchical relationships of the mapped concepts to the respective target.
    Parameters:
        - p_relationship_id: exclude all relationship_id that are in p_relationship_id
        - p_vocabulary_id_1: exclude all new_parent_vocabulary_id that are in p_vocabulary_id_1
        - p_vocabulary_id_2: exclude all new_child_vocabulary_id that are in p_vocabulary_id_2
*/
DECLARE 
    wrong_links RECORD;
    dynamic_query TEXT;
BEGIN
    ANALYZE concept_relationship_stage;
    ANALYZE concept_stage;

    -- prepare a table with new mappings
    CREATE TEMP TABLE mapped_concepts$ AS
        -- from stage table
        SELECT crs.concept_code_1 AS source_concept_code,
               crs.concept_code_2 AS target_concept_code,
               crs.vocabulary_id_1 AS source_vocabulary_id,
               crs.vocabulary_id_2 AS target_vocabulary_id,
               c1.concept_class_id AS source_concept_class_id,
               c2.concept_class_id AS target_concept_class_id
          FROM concept_relationship_stage crs
          JOIN concept c1 ON crs.concept_code_1 = c1.concept_code AND crs.vocabulary_id_1 = c1.vocabulary_id
          JOIN concept c2 ON crs.concept_code_2 = c2.concept_code AND crs.vocabulary_id_2 = c2.vocabulary_id
         WHERE crs.relationship_id = 'Maps to'
           AND crs.concept_code_1 != crs.concept_code_2 
           AND c1.vocabulary_id != c2.vocabulary_id
           AND c2.standard_concept IS NOT NULL
           AND crs.invalid_reason IS NULL
        UNION ALL
        -- from base table
        SELECT c1.concept_code AS source_concept_code,
               c2.concept_code AS target_concept_code,
               c1.vocabulary_id AS source_vocabulary_id,
               c2.vocabulary_id AS target_vocabulary_id,
               c1.concept_class_id AS source_concept_class_id,
               c2.concept_class_id AS target_concept_class_id
          FROM concept_relationship cr
          JOIN concept c1 ON cr.concept_id_1 = c1.concept_id
          JOIN concept c2 ON cr.concept_id_2 = c2.concept_id
         WHERE cr.relationship_id = 'Maps to'
               AND c1.concept_id != c2.concept_id 
               AND c2.standard_concept IS NOT NULL
               AND cr.invalid_reason IS NULL;

    CREATE INDEX idx_mapped_concepts$ ON mapped_concepts$ (source_concept_code, source_vocabulary_id);

    -- prepare a table with all elationships
    CREATE TEMP TABLE hierarchical_relationships$ AS
        -- from base table
        SELECT r.relationship_id,
               c1.concept_code AS parent_concept_code,
               c2.concept_code AS child_concept_code,
               c1.vocabulary_id AS parent_vocabulary_id,
               c2.vocabulary_id AS child_vocabulary_id,
               c1.concept_class_id AS parent_concept_class_id,
               c2.concept_class_id AS child_concept_class_id
          FROM relationship r
          JOIN concept_relationship cr ON cr.relationship_id = r.relationship_id
          JOIN concept c1 ON c1.concept_id = cr.concept_id_1
          JOIN concept c2 ON c2.concept_id = cr.concept_id_2
          JOIN vocabulary v1 ON v1.vocabulary_id = c1.vocabulary_id
          JOIN vocabulary v2 ON v2.vocabulary_id = c2.vocabulary_id
         WHERE r.is_hierarchical = 1
               AND COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL
               AND r.defines_ancestry = 1
               AND c2.standard_concept IS NOT NULL
               AND cr.invalid_reason IS NULL
        UNION ALL
        -- from stage table
        SELECT r.relationship_id,
               c1.concept_code AS parent_concept_code,
               c2.concept_code AS child_concept_code,
               c1.vocabulary_id AS parent_vocabulary_id,
               c2.vocabulary_id AS child_vocabulary_id,
               c1.concept_class_id AS parent_concept_class_id,
               c2.concept_class_id AS child_concept_class_id
          FROM relationship r
          JOIN concept_relationship_stage crs ON crs.relationship_id = r.relationship_id
          JOIN concept c1 ON c1.concept_code = crs.concept_code_1 AND crs.vocabulary_id_1 = c1.vocabulary_id
          JOIN concept c2 ON c2.concept_code = crs.concept_code_2 AND crs.vocabulary_id_2 = c2.vocabulary_id
         WHERE r.is_hierarchical = 1
               AND r.defines_ancestry = 1
               AND c2.standard_concept IS NOT NULL
               AND crs.invalid_reason IS NULL;

    CREATE INDEX idx_hierarchical_relationships$ ON hierarchical_relationships$ (parent_concept_code, parent_vocabulary_id);
    ANALYZE hierarchical_relationships$, mapped_concepts$;

    -- build new relationships by changing parents to target_concept_code from new mappings
    CREATE TEMP TABLE propagated_relationships$ AS
        SELECT hr.relationship_id,
               mc.source_concept_code AS initial_parent_concept_code,
               mc.target_concept_code AS new_parent_concept_code,
               hr.child_concept_code AS new_child_concept_code,
               mc.target_vocabulary_id AS new_parent_vocabulary_id,
               hr.child_vocabulary_id AS new_child_vocabulary_id,
               mc.target_concept_class_id AS new_parent_concept_class_id,
               hr.child_concept_class_id AS new_child_concept_class_id
          FROM hierarchical_relationships$ hr
          JOIN mapped_concepts$ mc ON mc.source_concept_code = hr.parent_concept_code
               AND mc.source_vocabulary_id = hr.parent_vocabulary_id
         WHERE mc.target_concept_code != hr.child_concept_code 
               AND mc.target_vocabulary_id != hr.child_vocabulary_id; 

    -- filter relationships by excluding relationship_id, new_parent_vocabulary_id, ew_child_vocabulary_id
    dynamic_query := '
        CREATE TEMP TABLE propagated_relationships_filtered$ AS
        SELECT DISTINCT
               pr.relationship_id,
               pr.new_parent_concept_code AS concept_code_1,
               pr.new_child_concept_code AS concept_code_2,
               pr.new_parent_vocabulary_id AS vocabulary_id_1,
               pr.new_child_vocabulary_id AS vocabulary_id_2,
               pr.new_parent_concept_class_id AS concept_class_id_1,
               pr.new_child_concept_class_id AS concept_class_id_2,
               CURRENT_DATE AS valid_start_date,
               TO_DATE(''20991231'', ''YYYYMMDD'') AS valid_end_date,
               NULL AS invalid_reason
          FROM propagated_relationships$ pr
         WHERE NOT EXISTS (SELECT 1 
                             FROM concept c
                             JOIN concept_relationship r ON c.concept_id = r.concept_id_1 AND r.relationship_id = ''Maps to value''
                            WHERE c.concept_code = pr.initial_parent_concept_code) '; 

    -- exclude all relationship_id that are in p_relationship_id
    IF p_relationship_id IS NOT NULL THEN
        dynamic_query := dynamic_query || ' AND NOT (pr.relationship_id = ANY($1))';
    END IF;

    -- exclude all new_parent_vocabulary_id that are in p_vocabulary_id_1
    IF p_vocabulary_id_1 IS NOT NULL THEN
        dynamic_query := dynamic_query || ' AND NOT (pr.new_parent_vocabulary_id = ANY($2))';
    END IF;

    -- exclude all new_child_vocabulary_id that are in p_vocabulary_id_2
    IF p_vocabulary_id_2 IS NOT NULL THEN
        dynamic_query := dynamic_query || ' AND NOT (pr.new_child_vocabulary_id = ANY($3))';
    END IF;

    EXECUTE dynamic_query
    USING p_relationship_id, p_vocabulary_id_1, p_vocabulary_id_2;

    ANALYZE propagated_relationships_filtered$;

    -- create table with valid relationships
    CREATE TEMP TABLE rxnorm_rxnormextension_valid_hierarchical_triples$ AS
        WITH rx_tab AS (
        SELECT DISTINCT
               'Correct (core) Rx Hierarchy' AS flag,      -- Define a flag to indicate correct Rx hierarchy --never changed!!!
               c.concept_class_id AS parent_class_id,      -- Parent concept's class ID
               cr.relationship_id,                         -- Relationship between parent and child
               cc.concept_class_id AS child_class_id
        FROM prodv5.concept c
        JOIN prodv5.concept_relationship cr
             ON cr.concept_id_1 = c.concept_id           -- Link concepts based on relationships
             AND cr.invalid_reason IS NULL               -- Exclude invalid relationships
             AND c.vocabulary_id = 'RxNorm'              -- Only include concepts in the RxNorm vocabulary
        JOIN prodv5.concept cc
             ON cr.concept_id_2 = cc.concept_id          -- Link child concepts
             AND cc.vocabulary_id = 'RxNorm'             -- Only include child concepts in the RxNorm vocabulary
        JOIN relationship r
             ON r.relationship_id = cr.relationship_id   -- Join with relationship metadata
             AND r.defines_ancestry = 1                  -- Must define ancestry
             AND r.is_hierarchical = 1                   -- Must be hierarchical relationships
                                                         -- Group by flag, parent class ID, relationship ID, child class ID
        UNION ALL
        --staged inputs
        SELECT DISTINCT
            'Correct (staged-core) Rx Hierarchy' AS flag,   -- Define a flag to indicate correct Rx hierarchy --never changed!!!
            c.concept_class_id AS parent_class_id,          -- Parent concept's class ID
            cr.relationship_id,                             -- Relationship between parent and child
            cc.concept_class_id AS child_class_id
        FROM concept_stage c
        JOIN concept_relationship_stage cr
             ON cr.concept_code_1 = c.concept_code 
             AND cr.vocabulary_id_1 = c.vocabulary_id    -- Link concepts based on relationships
             AND cr.invalid_reason IS NULL               -- Exclude invalid relationships
             AND c.vocabulary_id = 'RxNorm'              -- Only include concepts in the RxNorm vocabulary
        JOIN concept_stage cc
             ON cr.concept_code_2 = cc.concept_code 
             AND cr.vocabulary_id_2 = cc.vocabulary_id   -- Link child concepts
             AND cc.vocabulary_id = 'RxNorm'             -- Only include child concepts in the RxNorm vocabulary
        JOIN relationship r
             ON r.relationship_id = cr.relationship_id   -- Join with relationship metadata
             AND r.defines_ancestry = 1                  -- Must define ancestry
             AND r.is_hierarchical = 1 
    )
    -- Step 2: Perform the main SELECT query for the controlled Rx/RxE Hierarchy
    SELECT DISTINCT
           'Controlled Rx/RxE Hierarchy' AS flag,           -- Define a flag for the controlled hierarchy
           c.concept_class_id AS parent_class_id,           -- Parent concept's class ID
           cr.relationship_id,                              -- Relationship between parent and child
           cc.concept_class_id AS child_class_id            -- Child concept's class ID
    FROM prodv5.concept c
    JOIN prodv5.concept_relationship cr
         ON cr.concept_id_1 = c.concept_id                       -- Link concepts based on relationships
         AND cr.invalid_reason IS NULL                           -- Exclude invalid relationships
         AND c.vocabulary_id IN ('RxNorm Extension', 'RxNorm')   -- Include RxNorm and RxNorm Extension vocabularies
    JOIN prodv5.concept cc
         ON cr.concept_id_2 = cc.concept_id                      -- Link child concepts
         AND cc.vocabulary_id IN ('RxNorm Extension', 'RxNorm')  -- Include RxNorm and RxNorm Extension vocabularies
    JOIN relationship r
         ON r.relationship_id = cr.relationship_id               -- Join with relationship metadata
         AND r.defines_ancestry = 1                              -- Must define ancestry
         AND r.is_hierarchical = 1                               -- Must be hierarchical relationships
    WHERE
        NOT EXISTS (                                             -- Exclude concepts already in the "Correct Rx Hierarchy"
            SELECT 1
            FROM rx_tab r
            WHERE r.child_class_id = cc.concept_class_id
                  AND r.parent_class_id = c.concept_class_id
                  AND r.relationship_id = cr.relationship_id
        )
        AND (c.concept_class_id, cr.relationship_id, cc.concept_class_id)   -- Eliminate hardcoded incorrect triples
            NOT IN (
                SELECT parent, rel, child
                FROM (
                    VALUES --put new triples if thier exclusion is required
                        ('Branded Drug', 'Branded Drug', 'Constitutes'),
                        ('Branded Drug', 'Branded Drug', 'Has marketed form'),
                        ('Branded Drug', 'Branded Drug Box', 'Has marketed form'),
                        ('Branded Drug', 'Clinical Drug', 'Constitutes'),
                        ('Branded Drug', 'Quant Branded Box', 'Has marketed form'),
                        ('Branded Drug', 'Clinical Drug Box', 'Available as box'),
                        ('Branded Drug', 'Quant Branded Box', 'Available as box'),
                        ('Branded Drug', 'Quant Branded Drug', 'Has marketed form'),
                        ('Branded Drug Box', 'Branded Drug Box', 'Has marketed form'),
                        ('Branded Drug Comp', 'Clinical Drug', 'Constitutes'),
                        ('Branded Drug Form', 'Clinical Drug', 'RxNorm inverse is a'),
                        ('Clinical Drug', 'Clinical Drug', 'Constitutes'),
                        ('Clinical Drug', 'Clinical Drug', 'Has marketed form'),
                        ('Clinical Drug', 'Branded Drug', 'Has marketed form'),
                        ('Clinical Drug', 'Branded Drug Box', 'Has marketed form'),
                        ('Clinical Drug', 'Quant Branded Box', 'Has marketed form'),
                        ('Clinical Drug', 'Quant Branded Drug', 'Has marketed form'),
                        ('Clinical Drug', 'Quant Clinical Box', 'Has marketed form'),
                        ('Clinical Drug', 'Quant Clinical Drug', 'Has marketed form'),
                        ('Branded Drug Box', 'Quant Branded Box', 'Has marketed form'),
                        ('Clinical Drug Box', 'Branded Drug Box', 'Has marketed form'),
                        ('Clinical Drug Box', 'Quant Clinical Box', 'Has marketed form'),
                        ('Clinical Drug Box', 'Quant Branded Box', 'Has marketed form'),
                        ('Clinical Drug', 'Branded Pack Box', 'Contained in'),
                        ('Clinical Drug', 'Clinical Pack Box', 'Contained in'),
                        ('Clinical Drug', 'Quant Clinical Box', 'Available as box'),
                        ('Clinical Pack', 'Marketed Product', 'Has marketed form'),
                        ('Quant Branded Drug', 'Quant Clinical Box', 'Available as box'),
                        ('Quant Clinical Box', 'Quant Branded Box', 'Has marketed form'),
                        ('Quant Clinical Drug', 'Quant Clinical Drug', 'Has marketed form'),
                        ('Quant Clinical Drug', 'Branded Pack Box', 'Contained in'),
                        ('Quant Clinical Drug', 'Clinical Pack Box', 'Contained in'),
                        ('Quant Clinical Drug', 'Quant Branded Box', 'Has marketed form'),
                        ('Quant Clinical Drug', 'Quant Branded Drug', 'Has marketed form'),
                        ('Quant Clinical Drug', 'Quant Clinical Box', 'Has marketed form')
                ) AS t (parent,child,rel)
            )
    -- Step 3: Combine results with "Correct Rx Hierarchy" using UNION ALL
    UNION ALL
    SELECT
        flag,
        parent_class_id,
        relationship_id,
        child_class_id
    FROM
        rx_tab;

    -- check for the presence of a new wrong relationship in the reference table dev_test2.rx_hier_ref
    FOR wrong_links IN (
        SELECT DISTINCT
               nhr.concept_class_id_1,
               nhr.concept_class_id_2,
               nhr.relationship_id
        FROM propagated_relationships_filtered$ nhr
        WHERE nhr.vocabulary_id_1 IN ('RxNorm','RxNorm Extension')
              AND nhr.vocabulary_id_2 IN ('RxNorm','RxNorm Extension')
              AND NOT EXISTS ( SELECT 1
                                 FROM rxnorm_rxnormextension_valid_hierarchical_triples$ rhr
                                WHERE rhr.parent_class_id = nhr.concept_class_id_1
                                      AND rhr.child_class_id = nhr.concept_class_id_2
                                      AND rhr.relationship_id = nhr.relationship_id
        )
    ) LOOP
        -- if an invalid relationship is found, delete and show
        DELETE 
          FROM propagated_relationships_filtered$ nhr
         WHERE nhr.concept_class_id_1 = wrong_links.concept_class_id_1
               AND nhr.concept_class_id_2 = wrong_links.concept_class_id_2
               AND nhr.relationship_id = wrong_links.relationship_id;

        RAISE NOTICE 'Invalid relationship detected: concept_class_id_1=%, concept_class_id_2=%, relationship_id=%',
            wrong_links.concept_class_id_1, wrong_links.concept_class_id_2, wrong_links.relationship_id;
    END LOOP;

    CREATE TEMP TABLE new_hierarchical_relationships$ AS
    SELECT DISTINCT *
      FROM propagated_relationships_filtered$ n
     WHERE NOT EXISTS (SELECT 1
                         FROM concept_relationship_stage crs
                        WHERE crs.concept_code_1 = n.concept_code_1
                              AND crs.concept_code_2 = n.concept_code_2
                              AND crs.vocabulary_id_1 = n.vocabulary_id_1
                              AND crs.vocabulary_id_2 = n.vocabulary_id_2
                              AND crs.relationship_id = n.relationship_id
                              AND crs.invalid_reason IS NULL
    );

    INSERT INTO concept_relationship_stage AS crs (
        concept_code_1,
        concept_code_2,
        vocabulary_id_1,
        vocabulary_id_2,
        relationship_id,
        valid_start_date,
        valid_end_date,
        invalid_reason
    )
    SELECT concept_code_1,
        concept_code_2,
        vocabulary_id_1,
        vocabulary_id_2,
        relationship_id,
        valid_start_date,
        valid_end_date,
        invalid_reason
    FROM new_hierarchical_relationships$
    ON CONFLICT DO NOTHING;

    IF current_schema() = 'devv5' THEN
        INSERT INTO audit.logged_propogated_maps_to (
            concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            created
        )
        SELECT
            new_parent_concept_code AS concept_code_1,
            new_child_concept_code AS concept_code_2,
            new_parent_vocabulary_id AS vocabulary_id_1,
            new_child_vocabulary_id AS vocabulary_id_2,
            relationship_id,
            CURRENT_TIMESTAMP AS created
        FROM new_hierarchical_relationships$;
    END IF;

    DROP TABLE mapped_concepts$,
               hierarchical_relationships$, 
               propagated_relationships$, 
               propagated_relationships_filtered$,
               new_hierarchical_relationships$,
               rxnorm_rxnormextension_valid_hierarchical_triples$;

END;
$BODY$
LANGUAGE 'plpgsql';

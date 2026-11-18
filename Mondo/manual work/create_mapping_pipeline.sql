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
**************************************************************************/

DROP TABLE IF EXISTS dev_mondo.mondo_cde;
create table dev_mondo.mondo_cde
(
    metadata_enriched         boolean     default true,
    concept_code              varchar(50) not null,
    concept_name              varchar(255),
    vocabulary_id             varchar(20) default 'MONDO'::character varying,
    sty                       varchar,
    mapability                varchar,
    relationship_id           varchar(20),
    relationship_id_predicate varchar(20),
    decision                  boolean,
    confidence                double precision,
    mapping_source            character varying[],
    mapping_path              character varying[],
    mapping_path_key          varchar(1000), -- Shared source-side path used to link Maps to and Maps to value rows.
    mapper_id                 varchar,
    reviewer_id               varchar,
    comments                  varchar,
    valid_start_date          date,
    valid_end_date            date,
    invalid_reason            varchar,
    target_concept_id         bigint,
    target_concept_code       varchar(50),
    target_concept_name       varchar(255),
    target_concept_class      varchar(50),
    target_standard_concept   varchar(1),
    target_invalid_reason     varchar(1),
    target_domain_id          varchar(20),
    target_vocabulary_id      varchar(20)
);





create or replace function initiatemondomappingpipeline() returns void
	language plpgsql
as $$
BEGIN
    -- =====================================================================
    -- MONDO → OMOP Automated Mapping Pipeline
    -- =====================================================================

    /*
    Purpose:
      Populate dev_mondo.mondo_cde with mappings from MONDO concepts to OMOP standard concepts using multiple sources


     */

   INSERT INTO dev_mondo.mondo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, mapping_path_key, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
   SELECT distinct concept_code,
          concept_name,
          sty,
          mapability,
          relationship_id,
          relationship_id_predicate,
          mapping_source,
          mapping_path,
          mapping_path_key,
          decision,
          confidence::float,
          mapper_id,
          reviewer_id,
          valid_start_date,
          valid_end_date,
          invalid_reason,
          comments,
          target_concept_id,
          target_concept_code,
          target_concept_name,
          target_concept_class,
          target_standard_concept,
          target_invalid_reason,
          target_domain_id,
          target_vocabulary_id
    FROM
       (
    WITH umls_vocab_map AS (
      SELECT *
      FROM (VALUES
        ('SNOMEDCT_US', 'SNOMED'),
        ('ICD10', 'ICD10'),
        ('MDR', 'MedDRA'),
        ('MSH', 'MeSH')
      ) AS x(sab, vocabulary_id)
    ),
    normalized_tab AS (
      SELECT DISTINCT
                       s.concept_code,
                       s.concept_name,
                       c.concept_code AS concept_code_u,
                       c.vocabulary_id AS vocabulary_id,
                       NULL AS sty,
                       cr.relationship_id,
                       obo.predicate_id,
                       obo.mapping_justification,
                       CASE WHEN obo.predicate_id <> 'skos:exactMatch' then NULL::float else 0.75::float end AS confidence,
                       NULL AS subject_match_field,
                       NULL AS object_match_field,
                       NULL AS other
      FROM dev_mondo.MONDO_source s
      JOIN dev_mondo.mondo_sssom_maps obo
        ON regexp_replace(obo.subject_id, ':', '_') = s.concept_code
       AND split_part(obo.object_id, ':', 1) = 'UMLS'
      JOIN sources.mrconso mrc
        ON trim(mrc.cui) = trim(split_part(obo.object_id, ':', 2))
      JOIN umls_vocab_map uvm
        ON uvm.sab = mrc.sab
      JOIN devv5.concept c1
        ON c1.concept_code = mrc.code
       AND c1.vocabulary_id = uvm.vocabulary_id
      JOIN devv5.concept_relationship cr
        ON cr.concept_id_1 = c1.concept_id
       AND cr.relationship_id IN ('Maps to','Maps to value')
       AND cr.invalid_reason IS NULL
      JOIN devv5.concept c
        ON c.concept_id = cr.concept_id_2
    )
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    CASE WHEN m.relationship_id='Maps to value' then 'Maps to value' else crx.relationship_id end AS relationship_id,
                    m.predicate_id AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-MONDO_SSSOM_UMLS-', m.mapping_justification, ':', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(
                        m.concept_code,
                        ' > ', ccx.vocabulary_id, ':', ccx.concept_code,
                        ' --', CASE WHEN m.relationship_id = 'Maps to value' THEN 'Maps to value' ELSE crx.relationship_id END, '--> ',
                        cc.vocabulary_id, ':', cc.concept_code
                    )) AS mapping_path,
                    CONCAT(m.concept_code, ' > ', ccx.vocabulary_id, ':', ccx.concept_code) AS mapping_path_key,
                    FALSE AS decision,
                             max(m.confidence) AS confidence,
                             'Unassigned' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                             CURRENT_DATE AS valid_start_date,
                                             TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                                             NULL AS invalid_reason,
                                             NULL AS comments,
                                             cc.concept_id AS target_concept_id,
                                             cc.concept_code AS target_concept_code,
                                             cc.concept_name AS target_concept_name,
                                             cc.concept_class_id AS target_concept_class,
                                             cc.standard_concept AS target_standard_concept,
                                             cc.invalid_reason AS target_invalid_reason,
                                             cc.domain_id AS target_domain_id,
                                             cc.vocabulary_id AS target_vocabulary_id
    FROM normalized_tab m
    JOIN concept ccx ON (m.concept_code_u,
                         m.vocabulary_id) = (ccx.concept_code,
                                             ccx.vocabulary_id)
    JOIN concept_relationship crx ON crx.concept_id_1 = ccx.concept_id
    AND crx.invalid_reason IS NULL
    AND crx.relationship_id IN ('Maps to',
                                'Maps to value')
    JOIN concept cc ON cc.concept_id = crx.concept_id_2
    GROUP BY m.concept_code,
             crx.relationship_id,
             m.predicate_id,
             m.concept_name,
             string_to_array(CONCAT('Auto-MONDO_SSSOM_UMLS-', m.mapping_justification, ':', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL'),
             CONCAT(m.concept_code, ' > ', ccx.vocabulary_id, ':', ccx.concept_code),
             CURRENT_DATE,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id,
             m.relationship_id) as mondo_prim
    ;
    
    -- Mapping via OHDSI HECATE

    INSERT INTO dev_mondo.mondo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, mapping_path_key, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    WITH normalized_tab AS
(
      SELECT DISTINCT s.concept_code,
                       s.concept_name,
                       obo.concept_id as tid,
                       obo.concept_code AS concept_code_u,
                       obo.vocabulary_id AS vocabulary_id,
                       NULL AS sty,
                       obo.search_score AS confidence
       FROM dev_mondo.mondo_source s
       JOIN dev_mondo.mondo_hekate_mapped obo ON obo.source_code = s.concept_code
     )
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-HECATE-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(
                        m.concept_code,
                        ' > ', ccx.vocabulary_id, ':', ccx.concept_code,
                        ' --', crx.relationship_id, '--> ',
                        cc.vocabulary_id, ':', cc.concept_code
                    )) AS mapping_path,
                    CONCAT(m.concept_code, ' > ', ccx.vocabulary_id, ':', ccx.concept_code) AS mapping_path_key,
                    FALSE AS decision,
                             max(m.confidence) AS confidence,
                             'Unassigned' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                             CURRENT_DATE AS valid_start_date,
                                             TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                                             NULL AS invalid_reason,
                                             NULL AS comments,
                                             cc.concept_id AS target_concept_id,
                                             cc.concept_code AS target_concept_code,
                                             cc.concept_name AS target_concept_name,
                                             cc.concept_class_id AS target_concept_class,
                                             cc.standard_concept AS target_standard_concept,
                                             cc.invalid_reason AS target_invalid_reason,
                                             cc.domain_id AS target_domain_id,
                                             cc.vocabulary_id AS target_vocabulary_id
    FROM normalized_tab m
    JOIN concept ccx ON (m.concept_code_u,
                         m.vocabulary_id) = (ccx.concept_code,
                                             ccx.vocabulary_id)
    JOIN concept_relationship crx ON crx.concept_id_1 = ccx.concept_id
    AND crx.invalid_reason IS NULL
    AND crx.relationship_id IN ('Maps to',
                                'Maps to value')
    JOIN concept cc ON cc.concept_id = crx.concept_id_2
    GROUP BY m.concept_code,
             crx.relationship_id,
             m.concept_name,
             string_to_array(CONCAT('Auto-HECATE-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL'),
             CONCAT(m.concept_code, ' > ', ccx.vocabulary_id, ':', ccx.concept_code),
             CURRENT_DATE,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    /*
      Purpose:
        Build and score candidate MONDO → OMOP mappings using semantic similarity/human-reviewer confidence, lexical similarity, ontology structure metrics,
        mapping-dev_mondo.source consensus, and domain-aware practice frequencies; then select the best target per MONDO code.
    */

        -- IRRELEVANT TARGETS by domain
    DELETE
    FROM dev_mondo.mondo_cde
    WHERE relationship_id='Maps to'
        AND
             TARGET_DOMAIN_ID NOT IN (
    'Measurement',
    'Procedure',
    'Condition','Observation'
    );

            -- IRRELEVANT TARGETS by vocabulary
    DELETE
    FROM dev_mondo.mondo_cde
    WHERE relationship_id = 'Maps to'
      AND TARGET_VOCABULARY_ID IN (
                                   'NAACCR',
                                   'Nebraska Lexicon',
                                   'OPCS4',
                                   'RxNorm','SNOMED Veterinary'
        );

                -- IRRELEVANT TARGETS by vocabulary
    DELETE
    FROM dev_mondo.mondo_cde
    WHERE relationship_id = 'Maps to value'
      AND TARGET_VOCABULARY_ID IN (
                                   'NAACCR',
                                   'Nebraska Lexicon',
                                   'OPCS4','SNOMED Veterinary');

    -- -- IRRELEVANT TARGETS by class
    DELETE
    FROM dev_mondo.mondo_cde
    WHERE relationship_id='Maps to'
        AND
             TARGET_DOMAIN_ID  IN ('Observation')
    AND target_concept_class NOT IN ('Procedure',
    'Morph Abnormality',
    'Clinical Finding',
    'Observable Entity',
    'Context-dependent',
    'Clinical Observation',
    'Disorder',
    'Event'
        );

    -- CREATE TABLE WITH PRECALCULATED METRICS
    DROP TABLE IF EXISTS dev_mondo.mondo_to_omop_candidates_mondo_precalculated;
    CREATE TABLE dev_mondo.mondo_to_omop_candidates_mondo_precalculated AS
    -- Collect all dev_mondo.source names and synonyms
    WITH src_names AS (
        SELECT concept_code, concept_name AS name
        FROM dev_mondo.mondo_cde
    ),
    src_syn AS (
        SELECT synonym_concept_code AS concept_code, synonym_name AS name
        FROM (SELECT
      concept_code as synonym_concept_code,
      synonym_name as synonym_name,
      'Mondo' as vocabulary_id,
      4180186 AS language_concept_id -- English
    FROM dev_mondo.MONDO_source s
    WHERE s.synonym_name is not null
    and s.version IN (SELECT version as version_date
         FROM dev_mondo.mondo_json
         ORDER BY version DESC
         LIMIT 1)
    and left(s.concept_code,6)='MONDO_'
    and synonym_type='hasExactSynonym'
    )        AS  cst
    WHERE language_concept_id = 4180186
    ),
    src_all AS (
        SELECT * FROM src_names
        UNION ALL
        SELECT * FROM src_syn
    ),
    -- Collect all target names and synonyms
    tgt_base AS (
        SELECT concept_id, concept_name AS name
        FROM concept
    ),
    tgt_syn AS (
        SELECT concept_id, concept_synonym_name AS name
        FROM concept_synonym
        WHERE language_concept_id = 4180186
    ),
    tgt_all AS (
        SELECT * FROM tgt_base
        UNION ALL
        SELECT * FROM tgt_syn
    ),
    -- Maximum similarity across all dev_mondo.source × target name combinations
    name_sim AS (
        SELECT
            a.concept_code,
            a.target_concept_id,
            MAX(devv5.similarity(src.name, tgt.name)) AS max_similarity
        FROM dev_mondo.mondo_cde a
        JOIN src_all src ON src.concept_code = a.concept_code
        JOIN tgt_all tgt ON tgt.concept_id = a.target_concept_id
        GROUP BY a.concept_code, a.target_concept_id
    ),
    -- Count ancestors/descendants
    anc_cnt AS (
        SELECT descendant_concept_id, COUNT(DISTINCT ancestor_concept_id) AS anc_cnt
        FROM concept_ancestor
        GROUP BY descendant_concept_id
    ),
    desc_cnt AS (
        SELECT ancestor_concept_id, COUNT(DISTINCT descendant_concept_id) AS desc_cnt
        FROM concept_ancestor
        GROUP BY ancestor_concept_id
    ),
    -- Count lateral relationships
    rel_cnt AS (
        SELECT concept_id_2 AS target_concept_id, COUNT(*) AS lateral_rel_cnt
        FROM concept_relationship
        WHERE invalid_reason IS NULL
        GROUP BY concept_id_2
    ),
    -- Count distinct mapping sources per (dev_mondo.source, relationship, target)
    mapping_cnt AS (
        SELECT concept_code, relationship_id, target_concept_id, COUNT(DISTINCT mapping_source) AS mapping_source_cnt
        FROM dev_mondo.mondo_cde
        GROUP BY concept_code, relationship_id, target_concept_id
    )
    -- Main query: assemble candidate mappings with precomputed metrics
    SELECT
        a.concept_code,
        a.concept_name,
        a.vocabulary_id AS source_vocabulary_id,
        a.confidence,
        cst.domain_id AS source_domain_id,
        a.relationship_id,
        a.relationship_id_predicate,
        a.mapping_source,
        a.mapping_path,
        a.mapping_path_key,
        a.target_concept_id,
        a.target_concept_code,
        a.target_concept_name,
        a.target_concept_class,
        a.target_standard_concept,
        a.target_invalid_reason,
        a.target_domain_id,
        a.target_vocabulary_id,
        COALESCE(ac.anc_cnt,0) AS anc_cnt,
        COALESCE(dc.desc_cnt,0) AS desc_cnt,
        ns.max_similarity AS pt_st_max_similarity,  -- Maximum source-to-target lexical similarity
        COALESCE(rc.lateral_rel_cnt,0) AS lateral_rel_cnt,
        COALESCE(mc.mapping_source_cnt,0) AS mapping_source_cnt
    FROM dev_mondo.mondo_cde a
    JOIN concept_stage cst
        ON cst.concept_code = a.concept_code
    LEFT JOIN name_sim ns
        ON ns.concept_code = a.concept_code
       AND ns.target_concept_id = a.target_concept_id
    LEFT JOIN anc_cnt ac
        ON ac.descendant_concept_id = a.target_concept_id
    LEFT JOIN desc_cnt dc
        ON dc.ancestor_concept_id = a.target_concept_id
    LEFT JOIN rel_cnt rc
        ON rc.target_concept_id = a.target_concept_id
    LEFT JOIN mapping_cnt mc
        ON mc.concept_code = a.concept_code
       AND mc.relationship_id = a.relationship_id
       AND mc.target_concept_id = a.target_concept_id
    ;

    -- indexing
    DROP INDEX IF EXISTS dev_mondo.idx_concept_code;
    CREATE INDEX idx_concept_code ON dev_mondo.mondo_to_omop_candidates_mondo_precalculated(concept_code);
    DROP INDEX IF EXISTS dev_mondo.idx_domains;
    CREATE INDEX idx_domains ON dev_mondo.mondo_to_omop_candidates_mondo_precalculated(
      source_domain_id,
      target_domain_id,
      target_vocabulary_id,
      target_concept_class
    );

    -- domain filtered logic
    DROP TABLE IF EXISTS dev_mondo.mondo_to_omop_candidates_scored;
    CREATE TABLE dev_mondo.mondo_to_omop_candidates_scored AS
    WITH stand_practice AS (
        SELECT
            c.domain_id  AS source_domain_id,
            cc.domain_id AS target_domain_id,
            cc.vocabulary_id AS target_vocabulary_id,
            cc.concept_class_id AS target_concept_class_id,
            CASE
                WHEN c.domain_id='Observation'
                 AND cc.domain_id='Condition'
                    THEN 20 * COUNT(DISTINCT cr.*)

                WHEN c.domain_id='Condition'
                 AND cc.domain_id='Measurement'
                 AND cc.vocabulary_id='Cancer Modifier'
                 AND cc.concept_class_id='Metastasis'
                    THEN 2.5 * COUNT(DISTINCT cr.*)

                WHEN c.domain_id='Condition'
                 AND cc.domain_id='Observation'
                    THEN 0.75 * COUNT(DISTINCT cr.*)

                WHEN c.domain_id='Observation'
                 AND cc.domain_id='Procedure'
                    THEN 0.75 * COUNT(DISTINCT cr.*)

                WHEN c.domain_id IN ('Condition','Observation','Measurement')
                 AND (
                     cc.concept_class_id IN (
                        'Morph Abnormality','Qualifier Value','Organism','Substance',
                        'Answer','APC','CPT4','CPT4 Modifier','Disposition',
                        'Doc Subject Matter','HCPCS','HCPCS Modifier','Histopattern',
                        'ICDO Histology','Life circumstance','Module','MS-DRG',
                        'NAACCR Value','NAACCR Variable','Question','Topic',
                        'Value','Variable'
                     )
                  OR cc.domain_id NOT IN ('Condition','Measurement','Observation','Procedure')
                 )
                    THEN 0.0005 * COUNT(DISTINCT cr.*)

                ELSE COUNT(DISTINCT cr.*)
            END AS cnt
        FROM concept c
        JOIN concept_relationship cr
          ON cr.concept_id_1 = c.concept_id
         AND cr.relationship_id = 'Maps to'
         AND cr.invalid_reason IS NULL
        JOIN concept cc
          ON cc.concept_id = cr.concept_id_2
        WHERE cr.concept_id_1 <> cr.concept_id_2
        GROUP BY c.domain_id, cc.domain_id, cc.vocabulary_id, cc.concept_class_id
    ),

    per_concept_max AS (
        SELECT
            sl.concept_code,

            GREATEST(MAX(sl.anc_cnt),1)             AS max_anc,
            GREATEST(MAX(sl.desc_cnt),1)            AS max_desc,
            GREATEST(MAX(sl.lateral_rel_cnt),1)     AS max_lat,
            GREATEST(MAX(sl.mapping_source_cnt),1)  AS max_map,

            GREATEST(MAX(COALESCE(sl.pt_st_max_similarity,0.001)),0.001) AS max_sim,
            GREATEST(MAX(COALESCE(sl.confidence,0.001)),0.001)           AS max_conf,
            GREATEST(MAX(COALESCE(sp.cnt,0)),1)                          AS max_practice

        FROM dev_mondo.mondo_to_omop_candidates_mondo_precalculated sl
        JOIN stand_practice sp
          ON sp.source_domain_id = sl.source_domain_id
         AND sp.target_domain_id = sl.target_domain_id
         AND sp.target_vocabulary_id = sl.target_vocabulary_id
         AND sp.target_concept_class_id = sl.target_concept_class
        GROUP BY sl.concept_code
    ),

    normalized AS (
        SELECT
            sl.*,
            COALESCE(sp.cnt,0) AS practice_cnt,

            sl.anc_cnt::float              / pc.max_anc  AS anc_norm,
            sl.desc_cnt::float             / pc.max_desc AS desc_norm,
            sl.lateral_rel_cnt::float      / pc.max_lat  AS lat_norm,
            sl.pt_st_max_similarity::float / pc.max_sim AS sim_norm,
            sl.confidence::float           / pc.max_conf AS conf_norm,
            sl.mapping_source_cnt::float   / pc.max_map  AS map_norm,

            LN(1 + COALESCE(sp.cnt,0)) / LN(1 + pc.max_practice) AS practice_score_log,

            (
                (sl.anc_cnt::float         / pc.max_anc) +
                (sl.desc_cnt::float        / pc.max_desc) +
                (sl.lateral_rel_cnt::float / pc.max_lat)
            ) / 45 AS structure_score

        FROM dev_mondo.mondo_to_omop_candidates_mondo_precalculated sl
        JOIN per_concept_max pc
          ON pc.concept_code = sl.concept_code
        LEFT JOIN stand_practice sp
          ON sp.source_domain_id = sl.source_domain_id
         AND sp.target_domain_id = sl.target_domain_id
         AND sp.target_vocabulary_id = sl.target_vocabulary_id
         AND sp.target_concept_class_id = sl.target_concept_class
    ),

    weights AS (
        SELECT
            w_conf,
            w_struct,
            w_lat,
            w_sim,
            w_practice,
            w_map
        FROM generate_series(0.5,1.0,0.25)  w_conf
        CROSS JOIN generate_series(0.0,0.2,0.05) w_struct
        CROSS JOIN generate_series(0.0,0.15,0.05) w_lat
        CROSS JOIN generate_series(0.5,1.0,0.25)  w_sim
        CROSS JOIN generate_series(0.3,1.0,0.35)  w_practice
        CROSS JOIN generate_series(0.3,1.0,0.35)  w_map
    ),

    scores AS (
        SELECT
            n.concept_code,
            n.target_concept_id,
            w.*,
            (
                n.map_norm            * w.w_map +
                n.conf_norm           * w.w_conf +
                n.structure_score     * w.w_struct +
                n.lat_norm            * w.w_lat +
                n.sim_norm            * w.w_sim +
                n.practice_score_log  * w.w_practice
            ) AS score_final
        FROM normalized n
        CROSS JOIN weights w
    ),

    ranked AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY concept_code, w_conf, w_struct, w_lat, w_sim, w_practice, w_map
                ORDER BY score_final DESC NULLS LAST
            ) AS rn
        FROM scores
    ),

    accuracy AS (
        SELECT
            r.w_conf, r.w_struct, r.w_lat, r.w_sim, r.w_practice, r.w_map,
            COUNT(*) FILTER (
                WHERE r.rn = 1
                  AND r.target_concept_id = g.target_concept_id
            )::float / COUNT(*) AS accuracy
        FROM ranked r
        LEFT JOIN (
            SELECT concept_code, MIN(target_concept_id) AS target_concept_id
            FROM dev_mondo.mondo_cde
            WHERE target_domain_id IN ('Condition','Measurement','Observation')
              AND relationship_id='Maps to'
            GROUP BY concept_code
            HAVING COUNT(DISTINCT target_concept_id) = 1
        ) g
          ON g.concept_code = r.concept_code
        GROUP BY r.w_conf, r.w_struct, r.w_lat, r.w_sim, r.w_practice, r.w_map
    ),

    best_weights AS (
        SELECT w_conf, w_struct, w_lat, w_sim, w_practice, w_map
        FROM accuracy
        ORDER BY accuracy DESC
        LIMIT 1
    )

    SELECT *
    FROM (
        SELECT
            n.*,
            (
                n.map_norm           * bw.w_map +
                n.conf_norm          * bw.w_conf +
                n.structure_score    * bw.w_struct +
                n.lat_norm           * bw.w_lat +
                n.sim_norm           * bw.w_sim +
                n.practice_score_log * bw.w_practice
            ) AS score_final,
            ROW_NUMBER() OVER (
                PARTITION BY n.concept_code
                ORDER BY
                    (
                        n.map_norm           * bw.w_map +
                        n.conf_norm          * bw.w_conf +
                        n.structure_score    * bw.w_struct +
                        n.lat_norm           * bw.w_lat +
                        n.sim_norm           * bw.w_sim +
                        n.practice_score_log * bw.w_practice
                    ) DESC NULLS LAST,
                    n.confidence DESC NULLS LAST,
                    n.mapping_source_cnt DESC NULLS LAST,
                    n.pt_st_max_similarity DESC NULLS LAST,
                    n.mapping_source_cnt DESC NULLS LAST,
                    n.structure_score DESC NULLS LAST
            ) AS rn_final
        FROM normalized n
        CROSS JOIN best_weights bw
    ) t
    ORDER BY concept_code, rn_final;

    -- raw selection for review
    DROP TABLE IF EXISTS dev_mondo.mondo_to_omop_mapped;
    CREATE TABLE dev_mondo.mondo_to_omop_mapped AS
    with tab as (
    SELECT concept_code,
           concept_name,
           source_vocabulary_id,
           source_domain_id,
           relationship_id,
       string_agg (distinct relationship_id_predicate,'|') as relationship_id_predicate,
            max(anc_cnt) as anc_cnt,
            max(desc_cnt) as desc_cnt,
           max(pt_st_max_similarity) as pt_st_max_similarity,
           max(lateral_rel_cnt) as lateral_rel_cnt,
           max(mapping_source_cnt) as mapping_source_cnt,
           max(anc_norm) as anc_norm,
           max(desc_norm) as desc_norm,
           max(lat_norm) as lat_norm ,
           max(sim_norm) as sim_norm,
           max(conf_norm) as conf_norm,
           max(structure_score) as structure_score,
             max(coalesce(score_final,2.5)) as score_final,
           min(rn_final) as rn_final,
               max(coalesce(confidence,0.5)) as confidence,
           string_agg (distinct array_to_string(mapping_source,',','*'),'|') as mapping_source,
          string_agg (distinct array_to_string(mapping_path,',','*'),'|') as mapping_path,
           mapping_path_key,
           target_concept_id,
           target_concept_code,
           target_concept_name,
           target_concept_class,
           target_standard_concept,
           target_invalid_reason,
           target_domain_id,
           target_vocabulary_id

    FROM dev_mondo.mondo_to_omop_candidates_scored sl
    where (sl.source_domain_id,sl.target_domain_id,sl.target_concept_class) IN (

        SELECT c.domain_id as source_domain_id,
               cc.domain_id as target_domain_id,
               cc.concept_class_id as target_concept_class_id
        FROM concept c
        JOIN concept_relationship cr
          ON cr.concept_id_1 = c.concept_id
         AND cr.invalid_reason IS NULL
         AND cr.relationship_id='Maps to'
        JOIN concept cc
          ON cr.concept_id_2 = cc.concept_id
        WHERE cr.concept_id_2 <> cr.concept_id_1
        )
    GROUP BY concept_code,
           concept_name,
           source_vocabulary_id,

           source_domain_id,
           relationship_id,
           mapping_path_key,
                 target_concept_id,
           target_concept_code,
           target_concept_name,
           target_concept_class,
           target_standard_concept,
           target_invalid_reason,
           target_domain_id,
           target_vocabulary_id
    ORDER BY concept_code,rn_final)
    ,
        mapping_source_count as (
            SELECT concept_code,count(distinct mapping_source) as total_mapping_source
            from dev_mondo.mondo_to_omop_candidates_scored sl
            group by concept_code
        )
    ,
         -- Rank only the primary Maps to paths; linked Maps to value rows inherit
         -- the same rate_of_target through mapping_path_key.
         maps_to_group AS (
    SELECT
           t.concept_code,
           t.mapping_path_key,
           MIN(t.rn_final) AS maps_to_rn_final,
           MAX(t.score_final) AS maps_to_score_final
    FROM tab t
    WHERE t.relationship_id = 'Maps to'
    GROUP BY t.concept_code, t.mapping_path_key
    ),
         maps_to_rank AS (
    SELECT
           mtg.concept_code,
           mtg.mapping_path_key,
           mtg.maps_to_rn_final,
           DENSE_RANK() OVER (
                PARTITION BY mtg.concept_code
                ORDER BY mtg.maps_to_rn_final ASC, mtg.maps_to_score_final DESC NULLS LAST, mtg.mapping_path_key
            ) AS maps_to_rate_of_target
    FROM maps_to_group mtg
    ),
         tab2 as (
    SELECT t.concept_code,
           t.concept_name,
           t.relationship_id_predicate,
           t.source_vocabulary_id,
           t.source_domain_id,
           t.relationship_id,
           t.anc_cnt,
           t.desc_cnt,
           t.pt_st_max_similarity,
           t.lateral_rel_cnt,
           t.mapping_source_cnt,
           t.anc_norm,
           t.desc_norm,
           t.lat_norm,
           t.sim_norm,
           t.conf_norm,
           t.structure_score,
           t.score_final,
           t.rn_final,
           COALESCE(mtr.maps_to_rn_final, t.rn_final) AS maps_to_rn_final,
           m.total_mapping_source,
           COALESCE(
               mtr.maps_to_rate_of_target,
               DENSE_RANK() OVER (
                    PARTITION BY t.concept_code
                    ORDER BY t.rn_final ASC, t.score_final DESC NULLS LAST, t.mapping_path_key
               )
           ) AS rate_of_target,
           t.confidence,
           t.mapping_source,
           t.mapping_path,
           t.mapping_path_key,
           t.target_concept_id,
           t.target_concept_code,
           t.target_concept_name,
           t.target_concept_class,
           t.target_standard_concept,
           t.target_invalid_reason,
           t.target_domain_id,
           t.target_vocabulary_id
    from tab t
    JOIN mapping_source_count m
    on m.concept_code=t.concept_code
    LEFT JOIN maps_to_rank mtr
      ON mtr.concept_code = t.concept_code
     AND mtr.mapping_path_key = t.mapping_path_key
    )
    ,
        for_review_tab as (
    SELECT distinct rate_of_target,concept_code as source_code,
                    concept_name as source_code_description,
                    source_vocabulary_id,
                    source_domain_id,
                    relationship_id,
                    relationship_id_predicate,
                    pt_st_max_similarity,
                    CASE WHEN confidence>1 then 1 ELSE confidence END as semantic_similarity,
                    CASE WHEN mapping_source ~*'HECATE'then 'AM-tool_U' else null end as mapping_tool,
                    mapping_source_cnt || '/' || total_mapping_source  as mapping_source_cnt,
                    round(((mapping_source_cnt::numeric/total_mapping_source::numeric)*100),1) as mapping_source_cnt_prcnt,
                    mapping_source,
                    mapping_path,
                    mapping_path_key,
                    maps_to_rn_final,
                    target_concept_id,
                    target_concept_code,
                    target_concept_name,
                    target_concept_class as target_concept_class_id,
                    target_standard_concept,
                    target_invalid_reason,
                    target_domain_id,
                    target_vocabulary_id
    from tab2
   -- where rate_of_target=1
    ORDER BY source_code,relationship_id,target_concept_id)

    SELECT
    DISTINCT
    'obo:' || source_code as subject_id,
    source_code as mondo_code,
    source_code_description as mondo_name,
    source_domain_id as mondo_omop_domain_id,
    pt_st_max_similarity as lexical_similarity,
    CASE WHEN pt_st_max_similarity between 0.9 and 1.0 then '0.9-1.0'
         WHEN pt_st_max_similarity between 0.8 and 0.9 then '0.8-0.9'
         WHEN pt_st_max_similarity between 0.7 and 0.8 then '0.7-0.8'
         WHEN pt_st_max_similarity between 0.6 and 0.7 then '0.6-0.7'
         WHEN pt_st_max_similarity between 0.5 and 0.6 then '0.5-0.6'
         WHEN pt_st_max_similarity between 0.4 and 0.5 then '0.4-0.5'
         WHEN pt_st_max_similarity between 0.3 and 0.4 then '0.3-0.4'
         WHEN pt_st_max_similarity between 0.2 and 0.3 then '0.2-0.3'
         WHEN pt_st_max_similarity between 0.1 and 0.2 then '0.1-0.2'
        WHEN pt_st_max_similarity between 0.0 and 0.1 then '0.0-0.1'
             ELSE NULL  END as lex_match_range,
        CASE WHEN coalesce(semantic_similarity,0.49) between 0.9 and 1.0 then '0.9-1.0'
            WHEN coalesce(semantic_similarity,0.49) between 0.8 and 0.9 then '0.8-0.9'
         WHEN coalesce(semantic_similarity,0.49) between 0.7 and 0.8 then '0.7-0.8'
         WHEN coalesce(semantic_similarity,0.49) between 0.6 and 0.7 then '0.6-0.7'
         WHEN coalesce(semantic_similarity,0.49) between 0.5 and 0.6 then '0.5-0.6'
         WHEN coalesce(semantic_similarity,0.49) between 0.4 and 0.5 then '0.4-0.5'
         WHEN coalesce(semantic_similarity,0.49) between 0.3 and 0.4 then '0.3-0.4'
         WHEN coalesce(semantic_similarity,0.49) between 0.2 and 0.3 then '0.2-0.3'
         WHEN coalesce(semantic_similarity,0.49) between 0.1 and 0.2 then '0.1-0.2'
            WHEN coalesce(semantic_similarity,0.49) between 0.0 and 0.1 then '0.0-0.1'
             ELSE NULL END as sem_match_range,
         CASE WHEN  mapping_source_cnt_prcnt between 90 and 100 then '0.9-1.0'
             WHEN mapping_source_cnt_prcnt between 80 and 90 then '0.8-0.9'
         WHEN mapping_source_cnt_prcnt between 70 and 80 then '0.7-0.8'
         WHEN mapping_source_cnt_prcnt between 60 and 70 then '0.6-0.7'
         WHEN mapping_source_cnt_prcnt between 50 and 60 then '0.5-0.6'
         WHEN mapping_source_cnt_prcnt between 40 and 50 then '0.4-0.5'
         WHEN mapping_source_cnt_prcnt between 30 and 40 then '0.3-0.4'
         WHEN mapping_source_cnt_prcnt between 20 and 30 then '0.2-0.3'
         WHEN mapping_source_cnt_prcnt between 10 and 20 then '0.1-0.2'
             WHEN mapping_source_cnt_prcnt between 0 and 10 then '0.0-0.1'
            ELSE NULL END as source_consensus_category,
    coalesce(semantic_similarity,0.49) as semantic_similarity,
    mapping_source_cnt_prcnt as source_consensus,
    mapping_source_cnt as source_consensus_count,
    CASE WHEN  mapping_source_cnt_prcnt>=10
    and semantic_similarity>=0.8 and semantic_similarity<1
    and pt_st_max_similarity>=0.6 and pt_st_max_similarity=1 then 'skos:closeMatch'
        WHEN  mapping_source_cnt_prcnt>=10
    and semantic_similarity>=0.8 and semantic_similarity=1
    and pt_st_max_similarity>=0.6 and pt_st_max_similarity=1  then 'skos:exactMatch'
                WHEN  mapping_source_cnt_prcnt>=10
    and semantic_similarity>=0.8 and semantic_similarity!=1
    and pt_st_max_similarity>=0.6 and pt_st_max_similarity!= 1 then 'skos:relatedMatch'
         WHEN  mapping_source_cnt_prcnt>=10
    and semantic_similarity>=0.8 and pt_st_max_similarity>=0.6 then 'skos:relatedMatch'
                    ELSE null end as predicate_id,

    relationship_id,
    'omop:' || target_concept_id::varchar as object_id,
    target_concept_code,
    target_concept_name,
    target_vocabulary_id,
    target_domain_id,
    target_concept_class_id,
    mapping_source,
    mapping_path,
    mapping_path_key,
    maps_to_rn_final,
    rate_of_target

    FROM (
    SELECT *
    from for_review_tab

    ) as tt
    ORDER BY predicate_id NULLS last, mondo_code
    ;

    --cleanup phase
    DROP TABLE IF EXISTS mondo_omop_domain_annotation;
END;
$$;



SELECT dev_mondo.initiatemondomappingpipeline();

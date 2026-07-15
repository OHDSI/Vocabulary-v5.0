create or replace function initiatehpomappingpipeline() returns void
	language plpgsql
as $$
BEGIN
    -- =====================================================================
    -- HPO → OMOP Automated Mapping Pipeline
    -- =====================================================================

    /*
    Purpose:
      Populate dev_hpo.hpo_cde with mappings from HPO concepts to OMOP standard concepts using multiple sources:
      - UMLS crosswalks to SNOMED, LOINC, ICD10, ICD10CM, ICD9CM, HCPCS, CPT4, MedDRA, MeSH, HemOnc, RxNorm
      - OMOP name/synonym matches
      - Distributive mappings derived from HPO references (UMLS/SNOMED/MedDRA/ICD)
      - OMOP2OBO (SSSOM-formated) and OHDSI HECATE derived mappings
      - External SNOMED mappings (one-to-one match only, w/o SNOMED expressions)
      - External Tufts mappings


     */

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                             current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'SNOMED'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'SNOMEDCT_US'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to standard using LOINC

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'LOINC'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'lnc'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to standard using ICD10CM

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'ICD10'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'ICD10'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to standard using ICD10

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'ICD10CM'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'ICD10CM'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to standard using ICD9CM

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'ICD9CM'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'ICD9CM'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to S using HCPCS

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'HCPCS'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'HCPCS'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to S using CPT4

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'CPT4'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'CPT'
      AND m.concept_code NOT IN
        (SELECT DISTINCT concept_code
         FROM dev_hpo.hpo_cde)
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to S using MedDRA

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'MedDRA'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'MDR'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
            current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to S using MeSH

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'MeSH'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'MSH'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to S using HemOnc

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'HemOnc'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'HemOnc'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
             current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to RxNorm

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    cr.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', s.code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'UMLS' AS mapper_id,
                             'Unreviewed' AS reviewer_id,
                              current_date AS valid_start_date,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT  version  as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN sources.mrconso s ON s.cui = m.cui
    JOIN concept c ON c.concept_code = s.code
    AND c.vocabulary_id = 'RxNorm'
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND cr.relationship_id IN ('Maps to',
                               'Maps to value')
    AND cr.invalid_reason IS NULL
    JOIN concept cc ON cc.concept_id = cr.concept_id_2
    WHERE s.sab = 'RXNORM'
    GROUP BY m.concept_code,
             m.concept_name,
             cr.relationship_id,
             string_to_array(CONCAT('AUTO-UMLS', ':', c.vocabulary_id), ':', 'NULL'),
              current_date,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id ;

    -- Mapping to non-Defined standard by name-match (OMOP)

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-OMOP-name_match', ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
                             'Unreviewed'AS mapper_id,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       LEFT JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN concept ccx ON trim(lower(ccx.concept_name)) = trim(lower(m.concept_name)) -- AND cc.standard_concept = 'S'
     -- AND cc.vocabulary_id IN ('SNOMED', 'LOINC')

    AND ccx.domain_id IN ('Condition',
                          'Procedure',
                          'Measurement',
                          'Observation')
    JOIN concept_relationship crx ON crx.concept_id_1 = ccx.concept_id
    AND crx.invalid_reason IS NULL
    AND crx.relationship_id IN ('Maps to',
                                'Maps to value')
    JOIN concept cc ON cc.concept_id = crx.concept_id_2
    GROUP BY m.concept_code,
             m.concept_name,
             crx.relationship_id,
             string_to_array(CONCAT('Auto-OMOP-name_match', ':', ccx.vocabulary_id), ':', 'NULL'),
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

    -- Mapping to non-Defined standard by synonym name-match (OMOP)

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT st.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-OMOP-synonym_match', ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
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
    FROM
      (SELECT s.*,
              x.cui
       FROM dev_hpo.HPO_source s
       JOIN sources.mrconso x ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
       WHERE x.sab = 'HPO'
         AND s.version IN
           (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)) AS m
    JOIN sources.mrsty st ON m.cui = st.cui
    JOIN concept ccx
    JOIN concept_synonym cs ON ccx.concept_id = cs.concept_id ON trim(lower(cs.concept_synonym_name)) = trim(lower(m.concept_name))
    AND ccx.domain_id IN ('Condition',
                          'Procedure',
                          'Measurement',
                          'Observation')
    JOIN concept_relationship crx ON crx.concept_id_1 = ccx.concept_id
    AND crx.invalid_reason IS NULL
    AND crx.relationship_id IN ('Maps to',
                                'Maps to value')
    JOIN concept cc ON cc.concept_id = crx.concept_id_2
    GROUP BY m.concept_code,
             crx.relationship_id,
             m.concept_name,
             string_to_array(CONCAT('Auto-OMOP-synonym_match', ':', ccx.vocabulary_id), ':', 'NULL'),
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

    -- Mapping via HPO-distributive UMLS tags

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id)
    WITH tab AS
      (SELECT DISTINCT concept_code,
                       concept_name,
                       refrence,
                       split_part(refrence, ':', 1) AS ref_vocab,
                       split_part(refrence, ':', 2) AS ref_code
       FROM dev_hpo.HPO_source
       WHERE refrence IS NOT NULL
         AND LEFT (concept_code,
                   3) = 'HP_'
         AND refrence ~*'UMLS|SNOMED|MEDDRA|ICD'),
                                                                                                                                                                                                                                                                                                                                                                                                                                                  normalized_tab AS
      (SELECT DISTINCT t.concept_code,
                       t.concept_name,
                       s.cui,
                       st.sty,
                       s.code AS concept_code_u,
                       CASE
                           WHEN s.sab = 'MDR' THEN 'MedDRA'
                           WHEN s.sab = 'SNOMEDCT_US' THEN 'SNOMED'
                           WHEN s.sab = 'MSH' THEN 'MeSH'
                           WHEN s.sab = 'ICD10CM' THEN 'ICD10CM'
                           WHEN s.sab = 'ICD10' THEN 'ICD10'
                           WHEN s.sab = 'ICD9CM' THEN 'ICD9CM'
                           WHEN s.sab = 'LNC' THEN 'LOINC'
                           ELSE s.sab
                       END AS vocabulary_id
       FROM tab t
       JOIN sources.mrconso s ON ref_code = s.cui
       JOIN sources.mrsty st ON s.cui = st.cui
       WHERE ref_vocab = 'UMLS'
         AND s.sab IN ('MDR',
                       'SNOMEDCT_US',
                       'MSH',
                       'ICD10CM',
                       'ICD10',
                       'ICD9CM',
                       'LNC'))
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-HPO-distributive-UMLS', ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
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
             string_to_array(CONCAT('Auto-HPO-distributive-UMLS', ':', ccx.vocabulary_id), ':', 'NULL'),
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

    -- Mapping via HPO-distributive SNOMED refs
    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id) WITH tab AS
      (SELECT DISTINCT concept_code,
                       concept_name,
                       refrence,
                       split_part(refrence, ':', 1) AS ref_vocab,
                       split_part(refrence, ':', 2) AS ref_code
       FROM dev_hpo.HPO_source
       WHERE refrence IS NOT NULL
         AND LEFT (concept_code,
                   3) = 'HP_'
         AND refrence ~*'UMLS|SNOMED|MEDDRA|ICD'),
                                                                                                                                                                                                                                                                                                                                                                                                                                                  normalized_tab AS
      (SELECT DISTINCT t.concept_code,
                       t.concept_name,
                       s.cui,
                       st.sty,
                       t.ref_code AS concept_code_u,
                       'SNOMED' AS vocabulary_id
       FROM tab t
       JOIN sources.mrconso s ON concept_code = replace(s.code, ':', '_')
       AND s.sab = 'HPO'
       JOIN sources.mrsty st ON s.cui = st.cui
       WHERE ref_vocab ~* 'SNOMED')
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-HPO-distributive-vocabulary-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
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
             string_to_array(CONCAT('Auto-HPO-distributive-vocabulary-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL'),
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

    -- Mapping via HPO-distributive MedDRA refs

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id) WITH tab AS
      (SELECT DISTINCT concept_code,
                       concept_name,
                       refrence,
                       split_part(refrence, ':', 1) AS ref_vocab,
                       split_part(refrence, ':', 2) AS ref_code
       FROM dev_hpo.HPO_source
       WHERE refrence IS NOT NULL
         AND LEFT (concept_code,
                   3) = 'HP_'
         AND refrence ~*'UMLS|SNOMED|MEDDRA|ICD'),
                                                                                                                                                                                                                                                                                                                                                                                                                                                  normalized_tab AS
      (SELECT DISTINCT t.concept_code,
                       t.concept_name,
                       s.cui,
                       st.sty,
                       t.ref_code AS concept_code_u,
                       'MedDRA' AS vocabulary_id
       FROM tab t
       JOIN sources.mrconso s ON concept_code = replace(s.code, ':', '_')
       AND s.sab = 'HPO'
       JOIN sources.mrsty st ON s.cui = st.cui
       WHERE ref_vocab ~* 'MEDDRA')
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-HPO-distributive-vocabulary-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
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
             string_to_array(CONCAT('Auto-HPO-distributive-vocabulary-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL'),
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

    -- Mapping via HPO-distributive ICDs refs

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id) WITH tab AS
      (SELECT DISTINCT concept_code,
                       concept_name,
                       refrence,
                       split_part(refrence, ':', 1) AS ref_vocab,
                       split_part(refrence, ':', 2) AS ref_code
       FROM dev_hpo.HPO_source
       WHERE refrence IS NOT NULL
         AND LEFT (concept_code,
                   3) = 'HP_'
         AND refrence ~*'UMLS|SNOMED|MEDDRA|ICD'),
                                                                                                                                                                                                                                                                                                                                                                                                                                                  normalized_tab AS
      (SELECT DISTINCT t.concept_code,
                       t.concept_name,
                       s.cui,
                       st.sty,
                       t.ref_code AS concept_code_u,
                       CASE
                           WHEN ref_vocab ~* 'ICD.*10' THEN 'ICD10'
                           WHEN ref_vocab ~* 'ICD.*9' THEN 'ICD9CM'
                       END AS vocabulary_id
       FROM tab t
       JOIN sources.mrconso s ON concept_code = replace(s.code, ':', '_')
       AND s.sab = 'HPO'
       JOIN sources.mrsty st ON s.cui = st.cui
       WHERE ref_vocab ~* 'ICD.*10|ICD.*9')
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-HPO-distributive-vocabulary-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
                    FALSE AS decision,
                             NULL::int AS confidence,
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
             string_to_array(CONCAT('Auto-HPO-distributive-vocabulary-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL'),
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

    -- Mapping via OMOP2OBO (SSSOM)

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id) WITH normalized_tab AS
      (SELECT DISTINCT s.concept_code,
                       s.concept_name,
                       c.concept_code AS concept_code_u,
                       c.vocabulary_id AS vocabulary_id,
                       st.sty,
                       obo.predicate_id,
                       obo.mapping_justification,
                       obo.confidence,
                       obo.subject_match_field,
                       obo.object_match_field,
                       obo.other
       FROM dev_hpo.HPO_source s
       JOIN dev_hpo.omop2obo_condition_sssom obo ON split_part(obo.object_id, ':', 2) = s.concept_code
       AND left(split_part(obo.object_id, ':', 2), 3) = 'HP_'
       JOIN concept c ON c.concept_id = split_part(obo.subject_id, ':', 2)::int
       JOIN sources.mrconso s1 ON s.concept_code = replace(s1.code, ':', '_')
       JOIN sources.mrsty st ON s1.cui = st.cui)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    m.predicate_id AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-OMOP2OBO-', m.mapping_justification, ':', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
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
             string_to_array(CONCAT('Auto-OMOP2OBO-', m.mapping_justification, ':', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL'),
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

    -- Mapping via OHDSI HECATE

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id) WITH normalized_tab AS
      (SELECT DISTINCT s.concept_code,
                       s.concept_name,
                       obo.concept_code AS concept_code_u,
                       obo.vocabulary_id AS vocabulary_id,
                       st.sty,
                       obo.search_score AS confidence
       FROM dev_hpo.HPO_source s
       JOIN dev_hpo.hpo_mapped_via_ohdsi_hecate obo ON obo.source_code = s.concept_code
       JOIN sources.mrconso s1 ON s.concept_code = replace(s1.code, ':', '_')
       JOIN sources.mrsty st ON s1.cui = st.cui)
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-HECATE-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
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

    -- Mapping via external SNOMED file (Graham one-to-one)

    INSERT INTO dev_hpo.hpo_cde (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate, mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date, valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code, target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id) WITH normalized_tab AS
      (SELECT DISTINCT s.concept_code,
                       s.concept_name,
                       obo.canonical_view AS concept_code_u,
                       'SNOMED' AS vocabulary_id,
                       st.sty,
                       0.95 AS confidence
       FROM dev_hpo.HPO_source s
       JOIN dev_hpo.hpo_to_snomed_map obo ON replace(obo.hp_id, ':', '_') = s.concept_code
       JOIN sources.mrconso s1 ON s.concept_code = replace(s1.code, ':', '_')
       JOIN sources.mrsty st ON s1.cui = st.cui
       WHERE obo.match_group = 'One to one match')
    SELECT DISTINCT m.concept_code,
                    m.concept_name,
                    string_agg(DISTINCT m.sty, '|') AS sty,
                    NULL AS mapability,
                    crx.relationship_id AS relationship_id,
                    NULL AS relationship_id_predicate,
                    string_to_array(CONCAT('Auto-Graham-SNOMED-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL') AS mapping_source,
                    ARRAY_AGG(DISTINCT CONCAT(m.concept_code, ' > ', ccx.concept_code)) AS mapping_path,
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
             string_to_array(CONCAT('Auto-Graham-SNOMED-', m.vocabulary_id, ':', ccx.vocabulary_id), ':', 'NULL'),
             CURRENT_DATE,
             TO_DATE('20991231', 'yyyymmdd'),
             cc.concept_id ,
             cc.concept_code ,
             cc.concept_name ,
             cc.concept_class_id,
             cc.standard_concept,
             cc.invalid_reason,
             cc.domain_id,
             cc.vocabulary_id
    ;

    -- Mapping via Tufts CVB curated table
    INSERT INTO dev_hpo.hpo_cde (
        concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
        mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id,
        valid_start_date, valid_end_date, invalid_reason, comments,
        target_concept_id, target_concept_code, target_concept_name, target_concept_class,
        target_standard_concept, target_invalid_reason, target_domain_id, target_vocabulary_id
    )
    WITH latest_hpo AS (
        SELECT version AS version_date
        FROM dev_hpo.hpo_json
        ORDER BY version DESC
        LIMIT 1
    ),
    hpo_source AS (
        SELECT DISTINCT
            s.concept_code,
            s.concept_name,
            x.cui
        FROM dev_hpo.HPO_source s
        JOIN sources.mrconso x
          ON regexp_replace(x.code, ':', '_', 'gi') = s.concept_code
         AND x.sab = 'HPO'
        JOIN latest_hpo lh
          ON s.version = lh.version_date
    )
    SELECT
        m.source_code AS concept_code,
        COALESCE(hs.concept_name, m.source_description, m.source_description_synonym, m.source_code) AS concept_name,
        string_agg(DISTINCT st.sty, '|') AS sty,
        NULL AS mapability,
        COALESCE(m.relationship_id, 'Maps to') AS relationship_id,
        m.predicate_id AS relationship_id_predicate,
        string_to_array(
            CONCAT(
                'Manual-CVB-Tufts', ':',
                COALESCE(NULLIF(m.source_vocabulary_id, ''), 'HPO'), ':',
                COALESCE(cc.vocabulary_id, NULLIF(m.target_vocabulary_id, ''), 'UNKNOWN')
            ),
            ':', 'NULL'
        ) AS mapping_source,
        ARRAY_AGG(
            DISTINCT CONCAT(
                m.source_code, ' > ',
                COALESCE(cc.concept_code, m.target_concept_id::varchar)
            )
        ) AS mapping_path,
        FALSE AS decision,
        m.confidence AS confidence,
        COALESCE(NULLIF(m.author_label, ''), 'Tufts-CVB') AS mapper_id,
        COALESCE(NULLIF(m.reviewer_label, ''), 'Unreviewed') AS reviewer_id,
        CURRENT_DATE AS valid_start_date,
        TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
        NULL AS invalid_reason,
        COALESCE(
            NULLIF(m.reviewer_comments, ''),
            NULLIF(m.mapping_justification, ''),
            NULL
        ) AS comments,
        cc.concept_id AS target_concept_id,
        cc.concept_code AS target_concept_code,
        cc.concept_name AS target_concept_name,
        cc.concept_class_id AS target_concept_class,
        cc.standard_concept AS target_standard_concept,
        cc.invalid_reason AS target_invalid_reason,
        cc.domain_id AS target_domain_id,
        cc.vocabulary_id AS target_vocabulary_id
    FROM dev_hpo.cvb_hpo_mapping m
    LEFT JOIN hpo_source hs
      ON hs.concept_code = m.source_code
    LEFT JOIN sources.mrsty st
      ON st.cui = hs.cui
    JOIN concept cc
      ON cc.concept_id = m.target_concept_id
    WHERE m.source_code LIKE 'HP\_%' ESCAPE '\'
      AND m.target_concept_id IS NOT NULL
    GROUP BY
        m.source_code,
        COALESCE(hs.concept_name, m.source_description, m.source_description_synonym, m.source_code),
        COALESCE(m.relationship_id, 'Maps to'),
        m.predicate_id,
        string_to_array(
            CONCAT(
                'Manual-CVB-Tufts', ':',
                COALESCE(NULLIF(m.source_vocabulary_id, ''), 'HPO'), ':',
                COALESCE(cc.vocabulary_id, NULLIF(m.target_vocabulary_id, ''), 'UNKNOWN')
            ),
            ':', 'NULL'
        ),
        m.confidence,
        COALESCE(NULLIF(m.author_label, ''), 'Tufts-CVB'),
        COALESCE(NULLIF(m.reviewer_label, ''), 'Unreviewed'),
        CURRENT_DATE,
        TO_DATE('20991231', 'yyyymmdd'),
        COALESCE(NULLIF(m.reviewer_comments, ''), NULLIF(m.mapping_justification, ''), NULL),
        cc.concept_id,
        cc.concept_code,
        cc.concept_name,
        cc.concept_class_id,
        cc.standard_concept,
        cc.invalid_reason,
        cc.domain_id,
        cc.vocabulary_id;

    /*
      Purpose:
        Build and score candidate HPO → OMOP mappings using semantic similarity/human-reviewer confidence, lexical similarity, ontology structure metrics,
        mapping-dev_hpo.HPO_source consensus, and domain-aware practice frequencies; then select the best target per HPO code.
    */

        -- IRRELEVANT TARGETS by domain
    DELETE
    FROM dev_hpo.hpo_cde
    WHERE relationship_id='Maps to'
        AND
             TARGET_DOMAIN_ID NOT IN (
    'Measurement',
    'Procedure',
    'Condition','Observation'
    );

            -- IRRELEVANT TARGETS by vocabulary
    DELETE
    FROM dev_hpo.hpo_cde
    WHERE relationship_id = 'Maps to'
      AND TARGET_VOCABULARY_ID IN (
                                   'NAACCR',
                                   'Nebraska Lexicon',
                                   'OPCS4',
                                   'RxNorm','SNOMED Veterinary'
        );

                -- IRRELEVANT TARGETS by vocabulary
    DELETE
    FROM dev_hpo.hpo_cde
    WHERE relationship_id = 'Maps to value'
      AND TARGET_VOCABULARY_ID IN (
                                   'NAACCR',
                                   'Nebraska Lexicon',
                                   'OPCS4','SNOMED Veterinary');

    -- -- IRRELEVANT TARGETS by class
    DELETE
    FROM dev_hpo.hpo_cde
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
    DROP TABLE IF EXISTS dev_hpo.hpo_to_omop_candidates_hpo_precalculated;
    CREATE TABLE dev_hpo.hpo_to_omop_candidates_hpo_precalculated AS
    -- Collect all dev_hpo.HPO_source names and synonyms
    WITH src_names AS (
        SELECT concept_code, concept_name AS name
        FROM dev_hpo.hpo_cde
    ),
    src_syn AS (
        SELECT synonym_concept_code AS concept_code, synonym_name AS name
        FROM (SELECT
      concept_code as synonym_concept_code,
      synonym_name as synonym_name,
      'HPO' as vocabulary_id,
      4180186 AS language_concept_id -- English
    FROM dev_hpo.HPO_source s
    WHERE s.synonym_name is not null
    and s.version IN (SELECT version as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1)
    and left(s.concept_code,3)='HP_'
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
    -- Maximum similarity across all dev_hpo.HPO_source × target name combinations
    name_sim AS (
        SELECT
            a.concept_code,
            a.target_concept_id,
            MAX(devv5.similarity(src.name, tgt.name)) AS max_similarity
        FROM dev_hpo.hpo_cde a
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
    -- Count distinct mapping sources per (dev_hpo.HPO_source, relationship, target)
    mapping_cnt AS (
        SELECT concept_code, relationship_id, target_concept_id, COUNT(DISTINCT mapping_source) AS mapping_source_cnt
        FROM dev_hpo.hpo_cde
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
        ns.max_similarity AS pt_st_max_similarity,  -- максимальное сходство dev_hpo.HPO_source ↔ target
        COALESCE(rc.lateral_rel_cnt,0) AS lateral_rel_cnt,
        COALESCE(mc.mapping_source_cnt,0) AS mapping_source_cnt
    FROM dev_hpo.hpo_cde a
    JOIN dev_hpo.concept_stage cst
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
       AND mc.target_concept_id = a.target_concept_id;

    -- indexing
    DROP INDEX IF EXISTS dev_hpo.idx_concept_code;
    CREATE INDEX idx_concept_code ON dev_hpo.hpo_to_omop_candidates_hpo_precalculated(concept_code);
    DROP INDEX IF EXISTS dev_hpo.idx_domains;
    CREATE INDEX idx_domains ON dev_hpo.hpo_to_omop_candidates_hpo_precalculated(
      source_domain_id,
      target_domain_id,
      target_vocabulary_id,
      target_concept_class
    );

    -- domain filtered logic
    DROP TABLE IF EXISTS dev_hpo.hpo_to_omop_candidates_scored;
    CREATE TABLE dev_hpo.hpo_to_omop_candidates_scored AS
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

        FROM dev_hpo.hpo_to_omop_candidates_hpo_precalculated sl
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
            sl.pt_st_max_similarity::float / pc.max_sim  AS sim_norm,
            sl.confidence::float           / pc.max_conf AS conf_norm,
            sl.mapping_source_cnt::float   / pc.max_map  AS map_norm,

            LN(1 + COALESCE(sp.cnt,0)) / LN(1 + pc.max_practice) AS practice_score_log,

            (
                (sl.anc_cnt::float         / pc.max_anc) +
                (sl.desc_cnt::float        / pc.max_desc) +
                (sl.lateral_rel_cnt::float / pc.max_lat)
            ) / 45 AS structure_score

        FROM dev_hpo.hpo_to_omop_candidates_hpo_precalculated sl
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
            FROM dev_hpo.hpo_cde
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
    DROP TABLE IF EXISTS dev_hpo.hpo_to_omop_mapped;
    CREATE TABLE dev_hpo.hpo_to_omop_mapped AS
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
           target_concept_id,
           target_concept_code,
           target_concept_name,
           target_concept_class,
           target_standard_concept,
           target_invalid_reason,
           target_domain_id,
           target_vocabulary_id

    FROM dev_hpo.hpo_to_omop_candidates_scored sl
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
            from dev_hpo.hpo_to_omop_candidates_scored sl
            group by concept_code
        )
    ,
         tab2 as (
    SELECT t.concept_code,
           concept_name,
           relationship_id_predicate,
           source_vocabulary_id,
           source_domain_id,
           relationship_id,
           anc_cnt,
           desc_cnt,
           pt_st_max_similarity,
           lateral_rel_cnt,
           mapping_source_cnt,
           anc_norm,
           desc_norm,
           lat_norm,
           sim_norm,
           conf_norm,
           structure_score,
           score_final,
           rn_final,
           m.total_mapping_source,
           ROW_NUMBER() OVER (
                PARTITION BY t.concept_code
                ORDER BY rn_final ASC,score_final DESC NULLS last
            ) AS rate_of_target,
           confidence,
           mapping_source,
           mapping_path,
           target_concept_id,
           target_concept_code,
           target_concept_name,
           target_concept_class,
           target_standard_concept,
           target_invalid_reason,
           target_domain_id,
           target_vocabulary_id
    from tab t
    JOIN mapping_source_count m
    on m.concept_code=t.concept_code
    )
    ,
        for_review_tab as (
    SELECT distinct rate_of_target,concept_code as source_code,
                    concept_name as source_code_description,
                    source_vocabulary_id,
                    source_domain_id,
                    relationship_id,
                    relationship_id_predicate,
                    pt_st_max_similarity as lexical_sumilarity,
                    CASE WHEN confidence>1 then 1 ELSE confidence END as semantic_similarity,
                    CASE WHEN mapping_source ~*'HECATE'then 'AM-tool_U' else null end as mapping_tool,
                    mapping_source_cnt || '/' || total_mapping_source  as mapping_source_cnt,
                    round(((mapping_source_cnt::numeric/total_mapping_source::numeric)*100),1) as mapping_source_cnt_prcnt,
                    mapping_source,
                    mapping_path,
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
    source_code as hpo_code,
    source_code_description as hpo_name,
    source_domain_id as hpo_omop_domain_id,
    lexical_sumilarity as lexical_similarity,
    CASE WHEN lexical_sumilarity between 0.9 and 1.0 then '0.9-1.0'
         WHEN lexical_sumilarity between 0.8 and 0.9 then '0.8-0.9'
         WHEN lexical_sumilarity between 0.7 and 0.8 then '0.7-0.8'
         WHEN lexical_sumilarity between 0.6 and 0.7 then '0.6-0.7'
         WHEN lexical_sumilarity between 0.5 and 0.6 then '0.5-0.6'
         WHEN lexical_sumilarity between 0.4 and 0.5 then '0.4-0.5'
         WHEN lexical_sumilarity between 0.3 and 0.4 then '0.3-0.4'
         WHEN lexical_sumilarity between 0.2 and 0.3 then '0.2-0.3'
         WHEN lexical_sumilarity between 0.1 and 0.2 then '0.1-0.2'
        WHEN lexical_sumilarity between 0.0 and 0.1 then '0.0-0.1'
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
             ELSE NULL END as source_concensus_category,
    coalesce(semantic_similarity,0.49) as semantic_similarity,
    mapping_source_cnt_prcnt as source_consensus,
    mapping_source_cnt as source_consensus_nar,
    CASE WHEN  mapping_source_cnt_prcnt>=10
    and semantic_similarity>=0.8 and semantic_similarity<1
    and lexical_sumilarity>=0.6 and lexical_sumilarity=1 then 'skos:closeMatch'
        WHEN  mapping_source_cnt_prcnt>=10
    and semantic_similarity>=0.8 and semantic_similarity=1
    and lexical_sumilarity>=0.6 and lexical_sumilarity=1  then 'skos:exactMatch'
                WHEN  mapping_source_cnt_prcnt>=10
    and semantic_similarity>=0.8 and semantic_similarity!=1
    and lexical_sumilarity>=0.6 and lexical_sumilarity!= 1 then 'skos:relatedMatch'
         WHEN  mapping_source_cnt_prcnt>=10
    and semantic_similarity>=0.8 and lexical_sumilarity>=0.6 then 'skos:relatedMatch'
                    ELSE null end as predicate_id,

    relationship_id,
    'omop:' || target_concept_id::varchar as object_id,
    target_concept_code,
    target_concept_name,
    target_vocabulary_id,
    target_domain_id,
    target_concept_class_id,rate_of_target

    FROM (
    SELECT *
    from for_review_tab

    ) as tt
    ORDER BY predicate_id NULLS last, hpo_code
    ;
END;
$$;



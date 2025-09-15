--01. Concept changes

--01.1. Concepts changed their Domain
--In this check we manually review the changes of concept's Domain to make sure they are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id, vocabulary_id fields as well as old vs new domain_id pairs. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), Domain changes may be caused, and, therefore, explained by multiple reasons, e.g.:
-- - based on Domain of the target concept and script logic on top of that;
-- - source hierarchy change;
-- - manual curation of the content by the vocabulary folks;
-- - Domain assigning script change or its unexpected behaviour.

SELECT new.concept_code,
       new.concept_name AS concept_name,
       new.concept_class_id AS concept_class_id,
       new.standard_concept AS standard_concept,
       new.vocabulary_id AS vocabulary_id,
       old.domain_id AS old_domain_id,
       new.domain_id AS new_domain_id
FROM concept new
JOIN prodv5.concept old
    USING (concept_code, vocabulary_id)
WHERE old.domain_id != new.domain_id
    AND new.vocabulary_id IN (:your_vocabs)
;

--01.2. Domain of newly added concepts
--In this check we manually review the assignment of new concept's Domain to make sure they are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id, vocabulary_id fields as well as domain_id. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), Domain assignment logic may be different, e.g.:
-- - based on Domain of the target concept and script logic on top of that;
-- - source hierarchy;
-- - manual curation of the content by the vocabulary folks;
-- - hardcoded.

SELECT c1.concept_code,
       c1.concept_name,
       c1.concept_class_id,
       c1.vocabulary_id,
       c1.standard_concept,
       c1.domain_id AS new_domain
FROM concept c1
LEFT JOIN prodv5.concept c2
    ON c1.concept_code = c2.concept_code
       AND c1.vocabulary_id = c2.vocabulary_id
WHERE c2.vocabulary_id IS NULL
    AND c1.vocabulary_id IN (:your_vocabs)
;

--01.3. Concepts changed their names
--In this check we manually review the name change of the concepts. Similarity rate to be used for prioritizing more significant changes and, depending on the volume of content, for defining a review threshold.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by concept_class_id and vocabulary_id fields. Then the content to be reviewed separately within the groups.
--Serious changes in concept semantics are not allowed and may indicate the code reuse by the source.
--Structural changes may be a reason to reconsider the source name processing.
--Minor changes and more/less precise definitions are allowed, unless it changes the concept semantics.
--This check also controls the source and vocabulary database integrity making sure that concepts doesn't change the concept_code or concept_id.

SELECT c.vocabulary_id,
       c.concept_class_id,
       c.concept_code,
       c2.concept_name AS old_name,
       c.concept_name AS new_name,
       devv5.similarity (c2.concept_name, c.concept_name)
FROM concept c
JOIN prodv5.concept c2
    ON c.concept_code = c2.concept_code
        AND c.vocabulary_id = c2.vocabulary_id
        AND c.concept_name != c2.concept_name
WHERE c.vocabulary_id IN (:your_vocabs)
ORDER BY devv5.similarity (c2.concept_name, c.concept_name)
;

--01.4. Concepts changed their synonyms
--In this check we manually review the synonym change of the concepts.
--Similarity rate to be used for prioritizing more significant changes and, depending on the volume of content, for defining a review threshold. NULL similarity implies the absence of one of the synonyms.
--Serious changes in synonym semantics are not allowed and may indicate the code reuse by the source.
--Structural changes or significant changes in the content volume (synonyms of additional language, sort or property) may be a reason to reconsider the synonyms processing.
--Minor changes and more/less precise definitions are allowed, unless it changes the concept semantics.
--This check also controls the source and vocabulary database integrity making sure that concepts doesn't change the concept_code or concept_id.

WITH old_syn AS (
SELECT c.concept_code,
       c.vocabulary_id,
       string_agg (DISTINCT cs.language_concept_id::text, '; ' ORDER BY cs.language_concept_id::text) AS old_language_concept_id,
       string_agg (cs.concept_synonym_name, '; ' ORDER BY cs.language_concept_id, cs.concept_synonym_name) AS old_synonym
FROM prodv5.concept c
    JOIN prodv5.concept_synonym cs
      ON c.concept_id = cs.concept_id WHERE c.vocabulary_id IN (:your_vocabs)
GROUP BY
    c.concept_code,
    c.vocabulary_id
         ),
new_syn AS (
SELECT c.concept_code,
       c.vocabulary_id,
       string_agg (DISTINCT cs.language_concept_id::text, '; ' ORDER BY cs.language_concept_id::text) AS new_language_concept_id,
       string_agg (cs.concept_synonym_name, '; ' ORDER BY cs.language_concept_id, cs.concept_synonym_name) AS new_synonym
FROM concept c
JOIN concept_synonym cs
    ON c.concept_id = cs.concept_id
WHERE c.vocabulary_id IN (:your_vocabs)
GROUP BY
    c.concept_code,
       c.vocabulary_id
)
SELECT DISTINCT
    o.concept_code,
    o.vocabulary_id,
    o.old_synonym,
    n.new_synonym,
    o.old_language_concept_id,
    n.new_language_concept_id,
    CASE
        WHEN o.old_synonym = n.new_synonym AND o.old_language_concept_id != n.new_language_concept_id THEN
            1
        WHEN (o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id != n.new_language_concept_id THEN
            2
    END AS language_changed,
    CASE
        WHEN (o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id = n.new_language_concept_id THEN
             devv5.similarity(o.old_synonym::varchar, n.new_synonym::varchar)
        WHEN (o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id != n.new_language_concept_id THEN
             devv5.similarity(o.old_synonym::varchar, n.new_synonym::varchar)
        --ELSE 0
    END AS similarity_or_condition
FROM old_syn o
LEFT JOIN new_syn n
    ON o.concept_code = n.concept_code
        AND o.vocabulary_id = n.vocabulary_id
WHERE
    o.old_synonym = n.new_synonym AND o.old_language_concept_id != n.new_language_concept_id
    OR (o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id = n.new_language_concept_id
    OR (o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id != n.new_language_concept_id
ORDER BY similarity_or_condition, language_changed;

--02. Mapping of concepts

--02.1. looking at new concepts and their mapping -- 'Maps to' absent
--In this check we manually review new concepts that don't have "Maps to" links to the Standard equivalent concepts.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by concept_class_id, vocabulary_id and domain_id fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), vocabulary importance and its maturity level, effort and resources available, result should be critically analyzed and may represent multiple scenarios, e.g.:
-- - concepts of some concept classes doesn't require "Maps to" links because the targets are not set as Standard concepts by design (brand names, drug forms, etc.);
-- - new NDC or vaccine concepts are not yet represented in the RxNorm/CVX vocabulary, and, therefore, can't be mapped;
-- - OMOP-generated invalidated concepts are not used as the source concepts, and, therefore, replacement links are not supported;
-- - concepts that were wrongly designed by the author (e.g. SNOMED) can't be explicitly mapped to the Standard target.

SELECT a.concept_code AS concept_code_source,
       a.concept_name AS concept_name_source,
       a.vocabulary_id AS vocabulary_id_source,
       a.concept_class_id AS concept_class_id_source,
       a.domain_id AS domain_id_source,
       b.concept_name AS concept_name_target,
       b.vocabulary_id AS vocabulary_id_target
FROM concept a
LEFT JOIN concept_relationship r ON a.concept_id= r.concept_id_1 AND r.invalid_reason IS NULL AND r.relationship_Id ='Maps to'
LEFT JOIN concept b ON b.concept_id = r.concept_id_2
LEFT JOIN prodv5.concept c ON (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
WHERE a.vocabulary_id IN (:your_vocabs)
AND c.concept_id IS NULL AND b.concept_id IS NULL
;

--02.2. looking at new concepts and their mapping -- 'Maps to', 'Maps to value' present
--In this check we manually review new concepts that have "Maps to", "Maps to value" links to the Standard equivalent concepts or themselves.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by concept_class_id, vocabulary_id and domain_id fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), result should be critically analyzed and may represent multiple scenarios, e.g.:
-- - new SNOMED "Clinical finding" concepts are mapped to themselves;
-- - new unit concepts of any vocabulary are mapped to 'UCUM' vocabulary;
-- - new Devices of any source drug vocabulary are mapped to themselves, some of them are also mapped to the oxygen Ingredient;
-- - new HCPCS/CPT4 COVID-19 vaccines are mapped to CVX or RxNorm.
--In this check we are not aiming on reviewing the semantics or quality of mapping. The completeness of content (versus 02.1 check) and alignment of the source use cases and mapping scenarios is the subject matter in this check.

SELECT a.concept_code AS concept_code_source,
       a.concept_name AS concept_name_source,
       a.vocabulary_id AS vocabulary_id_source,
       a.concept_class_id AS concept_class_id_source,
       a.domain_id AS domain_id_source,
       r.relationship_id,
       CASE WHEN a.concept_id = b.concept_id AND r.relationship_id ='Maps to' THEN '<Mapped to itself>'
           ELSE b.concept_name END AS concept_name_target,
       CASE WHEN a.concept_id = b.concept_id AND r.relationship_id ='Maps to' THEN '<Mapped to itself>'
           ELSE b.vocabulary_id END AS vocabulary_id_target
FROM concept a
JOIN concept_relationship r
    ON a.concept_id=r.concept_id_1
           AND r.invalid_reason IS NULL
           AND r.relationship_Id IN ('Maps to', 'Maps to value')
JOIN concept b
    ON b.concept_id = r.concept_id_2
LEFT JOIN prodv5.concept  c
    ON (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
WHERE a.vocabulary_id IN (:your_vocabs)
    AND c.concept_id IS NULL
    --AND a.concept_id != b.concept_id --use it to exclude mapping to itself
ORDER BY a.concept_code
;

--02.3. looking at new concepts and their ancestry -- 'Is a' absent
--In this check we manually review new concepts that don't have "Is a" hierarchical links to the parental concepts.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id, vocabulary_id and domain_id fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), vocabulary importance and its maturity level, effort and resources available, result should be critically analyzed and may represent multiple scenarios, e.g.:
-- - Standard or non-Standard concepts of the source vocabulary that doesn't provide hierarchical links, and we don't build them (source drug vocabularies);
-- - concepts of the concept classes that can't be hierarchically linked (units, methods, scales);
-- - concepts of the source vocabularies deStandardized and mapped over to the Standard concepts instead of added to the hierarchy;
-- - top level concepts.

SELECT a.concept_code AS concept_code_source,
       a.concept_name AS concept_name_source,
       a.vocabulary_id AS vocabulary_id_source,
       a.standard_concept AS standard_concept_source,
       a.concept_class_id AS concept_class_id_source,
       a.domain_id AS domain_id_source,
       b.concept_name AS concept_name_target,
       b.concept_class_id AS concept_class_id_target,
       b.vocabulary_id AS vocabulary_id_target
FROM concept a
LEFT JOIN concept_relationship r ON a.concept_id= r.concept_id_1 AND r.invalid_reason IS NULL AND r.relationship_Id ='Is a'
LEFT JOIN concept b ON b.concept_id = r.concept_id_2
LEFT JOIN prodv5.concept c ON (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
WHERE a.vocabulary_id IN (:your_vocabs)
AND c.concept_id IS NULL AND b.concept_id IS NULL
;

--02.4. looking at new concepts and their ancestry -- 'Is a' present
--In this check we manually review new concepts that have "Is a" hierarchical links to the parental concepts.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by concept_class_id, vocabulary_id, domain_id and vocabulary_id_target fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), result should be critically analyzed and may represent multiple scenarios, e.g.:
--TODO: add scenarios
--In this check we are not aiming on reviewing the semantics or quality of relationships. The completeness of content (versus 02.3 check) and alignment of the source use cases and mapping scenarios is the subject matter in this check.

SELECT a.concept_code AS concept_code_source,
       a.concept_name AS concept_name_source,
       a.vocabulary_id AS vocabulary_id_source,
       a.concept_class_id AS concept_class_id_source,
       a.domain_id AS domain_id_source,
       r.relationship_id,
       b.concept_name AS concept_name_target,
       b.concept_class_id AS concept_class_id_target,
       b.vocabulary_id AS vocabulary_id_target
FROM concept a
JOIN concept_relationship r ON a.concept_id= r.concept_id_1 AND r.invalid_reason IS NULL AND r.relationship_Id ='Is a'
JOIN concept b ON b.concept_id = r.concept_id_2
LEFT JOIN prodv5.concept c ON (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
WHERE a.vocabulary_id IN (:your_vocabs)
AND c.concept_id IS NULL
;

--02.5. concepts changed their mapping ('Maps to', 'Maps to value')
--In this check we manually review the changes of concept's mapping to make sure they are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id and vocabulary_id fields. Then the content to be reviewed separately within the groups.
--This occurrence includes 2 possible scenarios: (i) mapping changed; (ii) mapping present in one version, absent in another. To review the absent mappings cases, sort by the respective code_agg to get the NULL values first.
--Also, we can assess the source which mapping comes from and at what point in the run the mapping changes occurred:
--- "old_mapping_source" and "new_mapping_source" fields indicate whether mapping comes from concept_relationship_manual or it is built by load_stage scripts;
--- "mapping_changes_source" field shows at what step of the vocabulary run the mapping was deprecated: concept_relationship_manual, load_stage or generic_update.

WITH crm AS (
    SELECT concept_code_1,
           vocabulary_id_1,
           relationship_id,
           concept_code_2,
           vocabulary_id_2,
           invalid_reason
    FROM concept_relationship_manual
    WHERE vocabulary_id_1 IN (:your_vocabs)
     AND relationship_id LIKE 'Maps to%'
   ),

    new_cr AS (
        SELECT a.concept_id AS source_concept_id,
            a.vocabulary_id AS source_vocabulary_id,
            a.concept_class_id AS source_concept_class_id,
            a.standard_concept AS source_standard_concept,
            a.concept_code AS source_code,
            a.concept_name AS source_name,
            r.relationship_id,
            r.invalid_reason,
            b.concept_id AS target_concept_id,
            b.concept_code AS target_concept_code,
            b.concept_name AS target_concept_name,
            b.vocabulary_id AS target_vocabulary_id
        FROM concept a
        LEFT JOIN concept_relationship r on a.concept_id = concept_id_1 AND r.relationship_id LIKE 'Maps to%' AND r.invalid_reason IS NULL
        LEFT JOIN concept b ON b.concept_id = concept_id_2
        WHERE a.vocabulary_id IN (:your_vocabs)
        --and a.invalid_reason IS NULL --to exclude invalid concepts
  ),

    old_cr AS (
        SELECT a.concept_id AS source_concept_id,
            a.vocabulary_id AS source_vocabulary_id,
            a.concept_class_id AS source_concept_class_id,
            a.standard_concept AS source_standard_concept,
            a.concept_code AS source_code,
            a.concept_name AS source_name,
            r.relationship_id,
            r.invalid_reason,
            b.concept_id AS target_concept_id,
            b.concept_code AS target_concept_code,
            b.concept_name AS target_concept_name,
            b.vocabulary_id AS target_vocabulary_id
        FROM  prodv5.concept a
        LEFT JOIN  prodv5.concept_relationship r ON a.concept_id = concept_id_1 AND r.relationship_id  LIKE 'Maps to%' AND r.invalid_reason IS NULL
        LEFT JOIN  prodv5.concept b ON b.concept_id = concept_id_2
        WHERE a.vocabulary_id IN (:your_vocabs)
        --and a.invalid_reason IS NULL --to exclude invalid concepts
  ),

    new_map AS (
        SELECT source_concept_id,
           source_vocabulary_id,
           source_concept_class_id,
           source_standard_concept,
           source_code,
           source_name,
           string_agg (relationship_id, '-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS relationship_agg,
           string_agg (CASE WHEN source_concept_id = target_concept_id THEN '<Mapped to itself>' ELSE target_concept_code END, '-/-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS code_agg,
           string_agg (CASE WHEN source_concept_id = target_concept_id THEN '<Mapped to itself>' ELSE target_concept_name END, '-/-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS name_agg,
           string_agg (CASE WHEN source_concept_id = target_concept_id THEN '<Mapped to itself>' ELSE target_vocabulary_id END, '-/-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS vocabulary_agg,
           string_agg (CASE WHEN EXISTS (SELECT 1
                                         FROM crm
                                         WHERE concept_code_1 = n.source_code
                                            AND vocabulary_id_1 = n.source_vocabulary_id
                                            AND relationship_id = n.relationship_id
                                            AND concept_code_2 = target_concept_code
                                            AND vocabulary_id_2 = n.target_vocabulary_id
                                            AND invalid_reason IS NULL
                                         )
                            THEN 'manual mapping' ELSE 'load_stage' END, '-/-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS source_agg
    FROM new_cr n
    GROUP BY source_concept_id, source_vocabulary_id, source_concept_class_id, source_standard_concept, source_code, source_name
   ),

    old_map AS (
        SELECT source_concept_id,
           source_vocabulary_id,
           source_concept_class_id,
           source_standard_concept,
           source_code,
           source_name,
           string_agg (relationship_id, '-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS relationship_agg,
           string_agg (CASE WHEN source_concept_id = target_concept_id THEN '<Mapped to itself>' ELSE target_concept_code END, '-/-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS code_agg,
           string_agg (CASE WHEN source_concept_id = target_concept_id THEN '<Mapped to itself>' ELSE target_concept_name END, '-/-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS name_agg,
           string_agg (CASE WHEN EXISTS (SELECT 1
                                         FROM crm
                                         WHERE concept_code_1 = o.source_code
                                            AND vocabulary_id_1 = o.source_vocabulary_id
                                            AND relationship_id = o.relationship_id
                                            AND concept_code_2 = o.target_concept_code
                                            AND vocabulary_id_2 = o.target_vocabulary_id
                                            AND invalid_reason = 'D'
                                         )
                           THEN 'deprecated manually'
                           WHEN EXISTS
                                        (SELECT 1
                                         FROM concept_relationship_stage
                                          WHERE concept_code_1 = o.source_code
                                            AND vocabulary_id_1 = o.source_vocabulary_id
                                            AND relationship_id = o.relationship_id
                                            AND concept_code_2 = o.target_concept_code
                                            AND vocabulary_id_2 = o.target_vocabulary_id
                                            AND invalid_reason IS NULL)
                                 AND EXISTS
                                         (SELECT 1
                                          FROM concept_relationship
                                          WHERE concept_id_1 = o.source_concept_id
                                            AND relationship_id = o.relationship_id
                                            AND concept_id_2 = o.target_concept_id
                                            AND invalid_reason = 'D'
                                            AND relationship_id LIKE 'Maps to%'
                                            AND concept_id_1 IN (SELECT concept_id FROM concept c WHERE c.vocabulary_id IN (:your_vocabs)))
                           THEN 'deprecated by generic'
                           WHEN EXISTS
                                         (SELECT 1
                                          FROM concept_relationship
                                          WHERE concept_id_1 = o.source_concept_id
                                            AND relationship_id = o.relationship_id
                                            AND concept_id_2 = o.target_concept_id
                                            AND invalid_reason = 'D'
                                            AND relationship_id LIKE 'Maps to%'
                                          AND concept_id_1 IN (SELECT concept_id FROM concept c WHERE c.vocabulary_id IN (:your_vocabs)))
                           THEN 'deprecated by load_stage'
                           ELSE 'valid' END, '-/-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS changes_agg,
           string_agg (CASE WHEN EXISTS (SELECT 1
                                         FROM crm
                                         WHERE concept_code_1 = o.source_code
                                            AND vocabulary_id_1 = o.source_vocabulary_id
                                            AND relationship_id = o.relationship_id
                                            AND concept_code_2 = o.target_concept_code
                                            AND vocabulary_id_2 = o.target_vocabulary_id
                                            AND invalid_reason IS NULL
                                         )
                        THEN 'manual mapping' ELSE 'load_stage' END, '-/-' ORDER BY relationship_id, target_concept_code, target_vocabulary_id) AS source_agg
    FROM old_cr o
    GROUP BY source_concept_id, source_vocabulary_id, source_concept_class_id, source_standard_concept, source_code, source_name
    )

SELECT b.source_vocabulary_id AS vocabulary_id,
       b.source_concept_class_id,
       b.source_standard_concept,
       b.source_code,
       b.source_name,
       CASE WHEN a.code_agg IS NULL THEN NULL
           ELSE a.source_agg END AS old_mapping_source,
       a.relationship_agg AS old_relat_agg,
       a.code_agg AS old_code_agg,
       a.name_agg AS old_name_agg,
       CASE WHEN a.code_agg IS NULL THEN NULL
           ELSE a.changes_agg END AS mapping_changes_source,
       CASE WHEN b.code_agg IS NULL THEN NULL
           ELSE b.source_agg END AS new_mapping_source,
       b.relationship_agg AS new_relat_agg,
       b.code_agg AS new_code_agg,
       b.name_agg AS new_name_agg
FROM old_map a
JOIN new_map b
ON a.source_code = b.source_code
       AND a.source_vocabulary_id = b.source_vocabulary_id
       AND ((coalesce (a.code_agg, '') != coalesce (b.code_agg, '')) OR (coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, '')))
ORDER BY a.source_code
;

--02.6. Concepts changed their ancestry ('Is a')
--In this check we manually review the changes of concept's ancestry to make sure they are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id, vocabulary_id fields. Then the content to be reviewed separately within the groups.
--This occurrence includes 2 possible scenarios: (i) ancestor(s) changed; (ii) ancestor(s) present in one version, absent in another. To review the absent ancestry cases, sort by the respective code_agg to get the NULL values first.
--In this check we review the actual concept-level content, and for prioritization purposes more artifacts can be found in the following scenarios:
-- - ancestor(s) presented before, but is missing now;
-- - multiple 'Is a' links (sort by relationship_id to find such cases);
-- - frequent target concept (sort by new_relat_agg or old_relat_agg fields to find such cases).
--TODO: add logical groups for suspicious target domains

WITH new_map AS (
SELECT a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS relationship_agg,
       string_agg (b.concept_code, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS code_agg,
       string_agg (b.concept_name, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS name_agg
FROM concept a
LEFT JOIN concept_relationship r ON a.concept_id = concept_id_1 AND r.relationship_id IN ('Is a') AND r.invalid_reason IS NULL
LEFT JOIN concept b ON b.concept_id = concept_id_2
WHERE a.vocabulary_id IN (:your_vocabs) AND a.invalid_reason IS NULL
GROUP BY a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
,
old_map AS (
SELECT a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS relationship_agg,
       string_agg (b.concept_code, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS code_agg,
       string_agg (b.concept_name, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS name_agg
FROM prodv5. concept a
LEFT JOIN prodv5.concept_relationship r ON a.concept_id = concept_id_1 AND r.relationship_id IN ('Is a') AND r.invalid_reason IS NULL
LEFT JOIN prodv5.concept b ON b.concept_id = concept_id_2
WHERE a.vocabulary_id IN (:your_vocabs) AND a.invalid_reason IS NULL
GROUP BY a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
SELECT b.vocabulary_id AS vocabulary_id,
       b.concept_class_id,
       b.standard_concept,
       b.concept_code AS source_code,
       b.concept_name AS source_name,
       a.relationship_agg AS old_relat_agg,
       a.code_agg AS old_code_agg,
       a.name_agg AS old_name_agg,
       b.relationship_agg AS new_relat_agg,
       b.code_agg AS new_code_agg,
       b.name_agg AS new_name_agg
FROM old_map a
JOIN new_map b
ON a.concept_code = b.concept_code
       AND a.vocabulary_id = b.vocabulary_id
       AND ((coalesce (a.code_agg, '') != coalesce (b.code_agg, '')) OR (coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, '')))
ORDER BY a.concept_code
;

--02.7. Concepts with 1-to-many mapping -- multiple 'Maps to%' present
--In this check we manually review the concepts mapped to multiple Standard targets to make sure they are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by concept_class_id, vocabulary_id and domain_id fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case) result should be critically analyzed and may represent multiple scenarios, e.g.:
-- - source complex (e.g. procedure) concepts are split up and mapped over to multiple targets;
-- - oxygen-containing devices are mapped to itself and oxygen ingredient.
--TODO: add logical groups for suspicious target domains

SELECT *
FROM (
	SELECT s0.vocabulary_id,
		s0.source_concept_code,
		s0.source_concept_name,
		s0.source_concept_class_id,
		s0.source_domain_id,
		s0.relationship_id,
		s0.target_concept_code,
		s0.target_concept_name,
		s0.target_vocabulary_id,
		s0.max_vsd_in_group,
		(l.concept_id IS NULL) AS new_1_to_many_mappings
	FROM (
		SELECT a.concept_id,
			a.vocabulary_id,
			a.concept_code AS source_concept_code,
			a.concept_name AS source_concept_name,
			a.concept_class_id AS source_concept_class_id,
			a.domain_id AS source_domain_id,
			r.relationship_id,
			b.concept_code AS target_concept_code,
			CASE
				WHEN a.concept_id = b.concept_id
					THEN '<Mapped to itself>'
				ELSE b.concept_name
				END AS target_concept_name,
			CASE
				WHEN a.concept_id = b.concept_id
					THEN '<Mapped to itself>'
				ELSE b.vocabulary_id
				END AS target_vocabulary_id,
			COUNT(*) OVER (PARTITION BY a.concept_id) AS mappings_cnt,
			MAX(r.valid_start_date) OVER (PARTITION BY a.concept_id) AS max_vsd_in_group
		FROM concept a
		JOIN concept_relationship r ON r.concept_id_1 = a.concept_id
			AND r.invalid_reason IS NULL
			AND r.relationship_Id LIKE 'Maps to%'
		JOIN concept b ON b.concept_id = r.concept_id_2
		WHERE a.vocabulary_id IN (:your_vocabs)
		--AND r.concept_id_1 <> r.concept_id_2 --use it to exclude mapping to itself
		) s0
	LEFT JOIN (
		SELECT r_int.concept_id_1 AS concept_id,
		       c1.concept_code,
		       c1.vocabulary_id
		FROM prodv5.concept_relationship r_int
		JOIN prodv5.concept c1 ON c1.concept_id = r_int.concept_id_1
		WHERE r_int.invalid_reason IS NULL
			AND r_int.relationship_Id LIKE 'Maps to%'
			--AND r_int.concept_id_1 <> r_int.concept_id_2 --use it to exclude mapping to itself
		GROUP BY r_int.concept_id_1, c1.concept_code, c1.vocabulary_id
		HAVING COUNT(*) > 1
		) l ON (s0.source_concept_code, s0.vocabulary_id) = (l.concept_code, l.vocabulary_id)
	WHERE s0.mappings_cnt > 1
	) s1
ORDER BY s1.max_vsd_in_group DESC,
	s1.new_1_to_many_mappings DESC,
	s1.vocabulary_id,
	s1.source_concept_code,
	s1.target_concept_code;

--02.8. Concepts became non-Standard with no mapping replacement
--In this check we manually review the changes of concept's Standard status to non-Standard where 'Maps to' mapping replacement link is missing to make sure changes are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by concept_class_id, vocabulary_id and domain_id fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), vocabulary importance and its maturity level, effort and resources available, result should be critically analyzed and may represent multiple scenarios, e.g.:
-- - vocabulary authors deprecated previously Standard concepts without replacement mapping. [Zombie](https://github.com/OHDSI/Vocabulary-v5.0/wiki/Standard-but-deprecated-(by-the-source)-%E2%80%9Czombie%E2%80%9D-concepts) concepts may be considered;
-- - concepts that were previously wrongly designed by the author (e.g. SNOMED) are deprecated now and can't be explicitly mapped to the Standard target;
-- - scripts unexpected behavior.

SELECT a.concept_code,
       a.concept_name,
       a.concept_class_id,
       a.domain_id,
       a.vocabulary_id
FROM concept a
JOIN prodv5.concept b
        ON a.concept_code = b.concept_code
           AND a.vocabulary_id = b.vocabulary_id
WHERE a.vocabulary_id IN (:your_vocabs)
    AND b.standard_concept = 'S'
    AND a.standard_concept IS NULL
    AND not exists (
                    SELECT 1
                    FROM concept_relationship cr
                    WHERE a.concept_id = cr.concept_id_1
                        AND cr.relationship_id = 'Maps to'
                        AND cr.invalid_reason IS NULL
    )
;

--02.9. Concepts are presented in CRM with "Maps to" link, but end up with no valid "Maps to" in basic tables
-- This check controls that concepts that are manually mapped withing the concept_relationship_manual table have Standard target concepts, and links are properly processed by the vocabulary machinery.

SELECT *
FROM concept c
WHERE c.vocabulary_id IN (:your_vocabs)
    AND EXISTS (SELECT 1
                FROM concept_relationship_manual crm
                WHERE c.concept_code = crm.concept_code_1
                    AND c.vocabulary_id = crm.vocabulary_id_1
                    AND crm.relationship_id = 'Maps to' AND crm.invalid_reason IS NULL)
AND NOT EXISTS (SELECT 1
                FROM concept_relationship cr
                WHERE c.concept_id = cr.concept_id_1
                    AND cr.relationship_id = 'Maps to'
                    AND cr.invalid_reason IS NULL)
;

--02.10. Mapping of vaccines
--This check retrieves the mapping of vaccine concepts to Standard targets.
--It's highly sensitive and adjusted for the Drug vocabularies only. Other vocabularies (Conditions, Measurements, Procedure) will end up in huge number of false positive results.
--Because of mapping complexity and trickiness, and depending on the way the mappings were produced, full manual review may be needed.
--move to the project-specific QA folder and adjust exclusion criteria in there
--use mask_array field for prioritization and filtering out the false positive results
--adjust inclusion criteria here if needed: https://github.com/OHDSI/Vocabulary-v5.0/blob/master/RxNorm_E/manual_work/specific_qa/vaccine%20selection.sql

WITH vaccine_exclusion AS (SELECT
    'placeholder|placeholder' AS vaccine_exclusion
    )
,
     vaccine_inclusion AS (
         SELECT  unnest(regexp_split_to_array(vaccine_inclusion, '\|(?![^(]*\))')) AS mask FROM dev_rxe.vaccine_inclusion)

SELECT DISTINCT array_agg(DISTINCT coalesce(vi.mask,vi2.mask )) AS mask_array,
                c.concept_code,
                c.vocabulary_id,
                c.concept_name,
                c.concept_class_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_name END AS target_concept_name,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_class_id END AS target_concept_class_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.vocabulary_id END AS target_vocabulary_id
FROM concept c
LEFT JOIN concept_relationship cr
    ON cr.concept_id_1 = c.concept_id
           AND relationship_id ='Maps to' AND cr.invalid_reason IS NULL
LEFT JOIN concept b
    ON b.concept_id = cr.concept_id_2
LEFT JOIN vaccine_inclusion vi
    ON c.concept_name ~* vi.mask
LEFT JOIN vaccine_inclusion vi2
    ON b.concept_name ~* vi2.mask
WHERE c.vocabulary_id IN (:your_vocabs)
    AND ((c.concept_name ~* (SELECT vaccine_inclusion FROM dev_rxe.vaccine_inclusion) AND c.concept_name !~* (SELECT vaccine_exclusion FROM vaccine_exclusion))
        OR
        (b.concept_name ~* (SELECT vaccine_inclusion FROM dev_rxe.vaccine_inclusion) AND b.concept_name !~* (SELECT vaccine_exclusion FROM vaccine_exclusion)))

GROUP BY
                c.concept_code,
                c.vocabulary_id,
                c.concept_name,
                c.concept_class_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_name END ,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_class_id END ,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.vocabulary_id END
;

--02.11. Mapping of COVID-19 concepts
-- This check retrieves the mapping of COVID-19 concepts to Standard targets.
-- Because of mapping complexity and trickiness, and depending on the way the mappings were produced, full manual review may be needed.
-- Please adjust inclusion/exclusion in the master branch if found some flaws
-- Use valid_start_date field to prioritize the current mappings under the old ones ('1970-01-01' placeholder can be used for either old and recent mappings).

WITH covid_inclusion AS (SELECT covid_inclusion,unnest(regexp_split_to_array(covid_inclusion, '\|(?![^(]*\))')) AS mask
                         FROM (SELECT 'sars(?!(tedt|aparilla))|^cov(?!(er|onia|aWound|idien))|cov$|^ncov|ncov$|corona(?!(l|ry|ries| radiata))|severe acute|covid(?!ien)' AS covid_inclusion
                                       ) AS t
    ),

covid_exclusion AS (SELECT
    '( |^)LASSARS' AS covid_exclusion
    )


SELECT distinct array_agg(DISTINCT coalesce(vi.mask,vi2.mask )) AS mask_array,
                MAX(cr2.valid_start_date) AS valid_start_date,
                c.vocabulary_id,
                c.concept_code,
                c.concept_name,
                c.concept_class_id,
                cr.relationship_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_name END AS target_concept_name,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_class_id END AS target_concept_class_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.domain_id END AS target_domain_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.vocabulary_id END AS target_vocabulary_id
FROM concept c
LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id IN ('Maps to', 'Maps to value') AND cr.invalid_reason IS NULL
LEFT JOIN concept b ON b.concept_id = cr.concept_id_2
LEFT JOIN concept_relationship cr2 ON cr2.concept_id_1 = c.concept_id AND cr2.relationship_id IN ('Maps to', 'Maps to value') AND cr2.invalid_reason IS NULL
LEFT JOIN covid_inclusion vi
    ON c.concept_name ~* vi.mask
LEFT JOIN covid_inclusion vi2
    ON b.concept_name ~* vi2.mask
WHERE c.vocabulary_id IN (:your_vocabs)

    AND ((c.concept_name ~* (SELECT DISTINCT covid_inclusion FROM covid_inclusion) AND c.concept_name !~* (SELECT covid_exclusion FROM covid_exclusion))
        or
        (b.concept_name ~* (SELECT DISTINCT covid_inclusion FROM covid_inclusion) AND b.concept_name !~* (SELECT covid_exclusion FROM covid_exclusion)))
GROUP BY 3,4,5,6,7,8,9,10,11
ORDER BY MAX(cr2.valid_start_date) DESC,
         c.vocabulary_id,
         c.concept_code,
         relationship_id
;

--02.12. 1-to-many mapping to the descendant and its ancestor
--We expect this check to return nothing because in most of the cases such mapping is not consistent since any concept implies the semantics of its every ancestor.
--In some cases it may be consistent and done by the purpose:
-- - if the concept implies 2 or more different diseases, and you don't just split up the source concept into the pieces;
-- - if you want to emphasize some aspects that do not follow from the hierarchy naturally;
-- - if the hierarchy of affected concepts is wrong.
-- Use the valid_start_date field to prioritize the current mappings under the old ones ('1970-01-01' placeholder can be used for either old or recent mappings)

SELECT LEAST (a.valid_start_date, b.valid_start_date) AS valid_start_date,
       c.vocabulary_id,
       c.concept_code,
       c.concept_name,
       a.concept_id_2 AS descendant_concept_id,
       b.concept_id_2 AS ancestor_concept_id,
       c_des.concept_name AS descendant_concept_name,
       c_anc.concept_name AS ancestor_concept_name
FROM concept_relationship a
JOIN concept_relationship b
    ON a.concept_id_1 = b.concept_id_1
JOIN concept c
    ON c.concept_id = a.concept_id_1
LEFT JOIN prodv5.concept_ancestor ca_old
    ON a.concept_id_2 = ca_old.descendant_concept_id
        AND b.concept_id_2 = ca_old.ancestor_concept_id
LEFT JOIN concept c_des
    ON a.concept_id_2 = c_des.concept_id
LEFT JOIN concept c_anc
    ON b.concept_id_2 = c_anc.concept_id
WHERE a.concept_id_2 != b.concept_id_2
    AND a.concept_id_1 != a.concept_id_2
    AND b.concept_id_1 != b.concept_id_2
    AND c.vocabulary_id IN (:your_vocabs)
    AND a.relationship_id = 'Maps to'
    AND b.relationship_id = 'Maps to'
    AND a.invalid_reason IS NULL
    AND b.invalid_reason IS NULL
    AND ca_old.descendant_concept_id IS NOT NULL
ORDER BY LEAST (a.valid_start_date, b.valid_start_date) DESC,
         c.vocabulary_id,
         c.concept_code
;

--03. Concepts have a replacement link, but miss the "Maps to" link
-- This check controls that all replacement links are repeated with the 'Maps to' links that are used by ETL.
SELECT DISTINCT c.vocabulary_id,
                c.concept_class_id,
                cr.concept_id_1,
                cr.relationship_id,
                cc.standard_concept,
                cr.valid_start_date
FROM concept_relationship cr
JOIN concept c
    ON c.concept_id = cr.concept_id_1
LEFT JOIN concept cc
    ON cc.concept_id = cr.concept_id_2
WHERE c.vocabulary_id IN (:your_vocabs)
    AND NOT EXISTS (SELECT concept_id_1
                    FROM concept_relationship cr2
                    WHERE cr2.relationship_id IN ('Maps to')
                        AND cr2.invalid_reason IS NULL
                        AND cr2.concept_id_1 = cr.concept_id_1)
    AND cr.relationship_id IN ('Concept replaced by', 'Concept same_as to', 'Concept alt_to to', 'Concept was_a to')
    AND cr.invalid_reason is null
    AND cc.standard_concept = 'S' -- exclude cases where replacement leads to non-standard concepts (no mapping is possible)
ORDER BY cr.relationship_id, cc.standard_concept, cr.concept_id_1
;

--04. Relationships between concept classes
-- In this check, we identify and compare relationships absent in the previous (prodv5 by default) and new (current by default) versions of RxNorm/RxE concepts.
-- The focus is on hierarchical and non-hierarchical links between concept classes.
-- To prioritize and structure the review, results are grouped by concept_class_id, relationship_id, and c_class_2. Sorting is applied to facilitate separate analysis within logical groups.
-- Depending on the logical group, vocabulary importance, and maturity level, the results may represent multiple scenarios, such as following:
--- Relationships missing in the previous version but present in the new version, indicating improvements;
--- Relationships present in the previous version but absent in the new version, suggesting regressions or intentional changes (e.g., de-standardization or mapping adjustments).

--Do not treat such triples as fully reciprocal ones, as Clinical Drug Forms may mostly have links to Clinical Drugs, while Clinical Drugs may have substantially more lacking links to forms
--NB! Marketed Products is the RxE class of entities and, due to BuilderRxE imperfection, it has no proper formal structure
WITH possible_relationships AS (
    SELECT * FROM (
        WITH t AS (
            SELECT 'Brand Name' c_class_1, 'Brand name of' relationship_id, 'Branded Drug Box' c_class_2 UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Drug Comp' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Drug Form' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Drug' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Pack' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Pack Box' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Marketed Product' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Quant Branded Box' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Quant Branded Drug' UNION ALL
            SELECT 'Branded Drug Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Branded Drug Box', 'Has quantified form', 'Quant Branded Box' UNION ALL
            SELECT 'Branded Drug Comp', 'Constitutes', 'Branded Drug' UNION ALL
            SELECT 'Branded Drug Form', 'RxNorm inverse is a', 'Branded Drug' UNION ALL
            SELECT 'Branded Drug', 'Available as box', 'Branded Drug Box' UNION ALL
            SELECT 'Branded Drug', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Branded Drug', 'Has quantified form', 'Quant Branded Drug' UNION ALL
            SELECT 'Clinical Drug Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Clinical Drug Box', 'Has quantified form', 'Quant Clinical Box' UNION ALL
            SELECT 'Clinical Drug Box', 'Has tradename', 'Branded Drug Box' UNION ALL
            SELECT 'Clinical Drug Comp', 'Constitutes', 'Clinical Drug' UNION ALL
            SELECT 'Clinical Drug Comp', 'Has tradename', 'Branded Drug Comp' UNION ALL
            SELECT 'Clinical Drug Form', 'Has tradename', 'Branded Drug Form' UNION ALL
            SELECT 'Clinical Drug Form', 'RxNorm inverse is a', 'Clinical Drug' UNION ALL
            SELECT 'Clinical Drug', 'Available as box', 'Clinical Drug Box' UNION ALL
            SELECT 'Clinical Drug', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Clinical Drug', 'Has quantified form', 'Quant Clinical Drug' UNION ALL
            SELECT 'Clinical Drug', 'Has tradename', 'Branded Drug' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug Box' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug Form' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Pack' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Box' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Form' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Pack' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Marketed Product' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Branded Box' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Branded Drug' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Box' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Drug' UNION ALL
            SELECT 'Ingredient', 'Has brand name', 'Brand Name' UNION ALL
            SELECT 'Ingredient', 'RxNorm ing of', 'Clinical Drug Comp' UNION ALL
            SELECT 'Ingredient', 'RxNorm ing of', 'Clinical Drug Form' UNION ALL
            SELECT 'Marketed Product', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Supplier', 'Supplier of', 'Marketed Product' UNION ALL
            SELECT 'Quant Branded Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Quant Branded Drug', 'Available as box', 'Quant Branded Box' UNION ALL
            SELECT 'Quant Branded Drug', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Quant Clinical Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Quant Clinical Box', 'Has tradename', 'Quant Branded Box' UNION ALL
            SELECT 'Quant Clinical Drug', 'Available as box', 'Quant Clinical Box' UNION ALL
            SELECT 'Quant Clinical Drug', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Quant Clinical Drug', 'Has tradename', 'Quant Branded Drug' UNION ALL
            SELECT 'Branded Dose Group', 'Has brand name', 'Brand Name' UNION ALL
            SELECT 'Branded Dose Group', 'Has dose form group', 'Dose Form Group' UNION ALL
            SELECT 'Branded Dose Group', 'Marketed form of', 'Dose Form Group' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm has ing', 'Brand Name' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Branded Drug Form' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Branded Drug' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Quant Branded Drug' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Quant Clinical Drug' UNION ALL
            SELECT 'Branded Dose Group', 'Tradename of', 'Clinical Dose Group' UNION ALL
            SELECT 'Clinical Dose Group', 'Has dose form group', 'Dose Form Group' UNION ALL
            SELECT 'Clinical Dose Group', 'Marketed form of', 'Dose Form Group' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm has ing', 'Ingredient' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm has ing', 'Precise Ingredient' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Clinical Drug Form' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Clinical Drug' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Quant Branded Drug' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Quant Clinical Drug' UNION ALL
            SELECT 'Dose Form Group', 'RxNorm inverse is a', 'Dose Form' UNION ALL
            SELECT 'Precise Ingredient', 'Form of', 'Ingredient' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Clinical Pack' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Clinical Pack Box' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Branded Pack' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Branded Pack Box' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Marketed Product' UNION ALL
            SELECT 'Branded Drug', 'Contained in', 'Branded Pack' UNION ALL
            SELECT 'Branded Drug', 'Contained in', 'Branded Pack Box' UNION ALL
            SELECT 'Branded Drug', 'Contained in', 'Marketed Product' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Clinical Pack' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Clinical Pack Box' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Branded Pack' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Branded Pack Box' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Marketed Product' UNION ALL
            SELECT 'Quant Branded Drug', 'Contained in', 'Branded Pack' UNION ALL
            SELECT 'Quant Branded Drug', 'Contained in', 'Branded Pack Box' UNION ALL
            SELECT 'Quant Branded Drug', 'Contained in', 'Marketed Product' UNION ALL
            SELECT 'Branded Pack', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Branded Pack Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Branded Pack', 'Available as box', 'Branded Pack Box' UNION ALL
            SELECT 'Clinical Pack', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Clinical Pack Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Clinical Pack', 'Has tradename', 'Branded Pack' UNION ALL
            SELECT 'Clinical Pack', 'Available as box', 'Clinical Pack Box' UNION ALL
            SELECT 'Clinical Pack Box', 'Has tradename', 'Branded Pack Box'
        )
        SELECT * FROM t
        UNION ALL
        SELECT c_class_2, r.reverse_relationship_id, c_class_1
        FROM t rra, prodv5.relationship r
        WHERE rra.relationship_id = r.relationship_id
    ) AS s1
),
valid_concepts_prev AS (
    SELECT concept_id, concept_name, concept_class_id
    FROM prodv5.concept
    WHERE vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND invalid_reason IS NULL
),
existing_relationships_prev AS (
    SELECT
        cr.concept_id_1,
        cr.relationship_id,
        c2.concept_class_id AS concept_class_id_2
    FROM prodv5.concept_relationship cr
    JOIN valid_concepts_prev vc ON cr.concept_id_1 = vc.concept_id
    JOIN prodv5.concept c2 ON cr.concept_id_2 = c2.concept_id
    WHERE cr.invalid_reason IS NULL
    AND c2.invalid_reason IS NULL
    AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
),
absent_relationships_prev AS (
    SELECT
        vc.concept_class_id,
        pr.relationship_id,
        pr.c_class_2,
        COUNT(DISTINCT vc.concept_id) AS concept_count
    FROM valid_concepts_prev vc
    CROSS JOIN possible_relationships pr
    WHERE pr.c_class_1 = vc.concept_class_id
    AND NOT EXISTS (
        SELECT 1
        FROM existing_relationships_prev er
        WHERE er.concept_id_1 = vc.concept_id
        AND er.relationship_id = pr.relationship_id
        AND er.concept_class_id_2 = pr.c_class_2
    )
    GROUP BY vc.concept_class_id, pr.relationship_id, pr.c_class_2
),
valid_concepts_dev_new AS (
    SELECT concept_id, concept_name, concept_class_id
    FROM concept
    WHERE vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND invalid_reason IS NULL
),
existing_relationships_dev_new AS (
    SELECT
        cr.concept_id_1,
        cr.relationship_id,
        c2.concept_class_id AS concept_class_id_2
    FROM concept_relationship cr
    JOIN valid_concepts_dev_new vc ON cr.concept_id_1 = vc.concept_id
    JOIN concept c2 ON cr.concept_id_2 = c2.concept_id
    WHERE cr.invalid_reason IS NULL
    AND c2.invalid_reason IS NULL
    AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
),
absent_relationships_dev_new AS (
    SELECT
        vc.concept_class_id,
        pr.relationship_id,
        pr.c_class_2,
        COUNT(DISTINCT vc.concept_id) AS concept_count
    FROM valid_concepts_dev_new vc
    CROSS JOIN possible_relationships pr
    WHERE pr.c_class_1 = vc.concept_class_id
    AND NOT EXISTS (
        SELECT 1
        FROM existing_relationships_dev_new er
        WHERE er.concept_id_1 = vc.concept_id
        AND er.relationship_id = pr.relationship_id
        AND er.concept_class_id_2 = pr.c_class_2
    )
    GROUP BY vc.concept_class_id, pr.relationship_id, pr.c_class_2
)
SELECT
    COALESCE(s1.concept_class_id, s2.concept_class_id) AS concept_class,
    COALESCE(s1.relationship_id, s2.relationship_id) || ' - ' || COALESCE(s1.c_class_2, s2.c_class_2) AS missing_connections,
    total_class_volume,
    COALESCE(s1.concept_count, 0) AS count_in_prev,
    COALESCE(s2.concept_count, 0) AS count_in_dev_new,
    COALESCE(s2.concept_count, 0) - COALESCE(s1.concept_count, 0) AS delta_abs,
    CASE
        WHEN COALESCE(s2.concept_count, 0) > 0
            AND COALESCE(s1.concept_count, 0) > 0
        THEN ROUND(((COALESCE(s2.concept_count, 0) - COALESCE(s1.concept_count, 0))::FLOAT / COALESCE(s1.concept_count, 0) * 100)::NUMERIC, 2)
        ELSE NULL
    END AS delta_percent
FROM absent_relationships_prev s1
FULL OUTER JOIN absent_relationships_dev_new s2
    ON s1.concept_class_id = s2.concept_class_id
    AND s1.relationship_id = s2.relationship_id
    AND s1.c_class_2 = s2.c_class_2
JOIN  (SELECT concept_class_id,count(*) as total_class_volume
       from prodv5.concept
       where vocabulary_id IN ('RxNorm','RxNorm Extension')
       GROUP BY concept_class_id ) as t
on t.concept_class_id=COALESCE(s1.concept_class_id, s2.concept_class_id)
ORDER BY concept_class, missing_connections;
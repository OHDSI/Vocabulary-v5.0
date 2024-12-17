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
JOIN devv5.concept old
    USING (concept_id)
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
LEFT JOIN devv5.concept c2
    ON c1.concept_id = c2.concept_id
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
JOIN devv5.concept c2
    ON c.concept_id = c2.concept_id
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
       cs.language_concept_id as old_language_concept_id,
       array_agg (DISTINCT cs.concept_synonym_name ORDER BY cs.concept_synonym_name) as old_synonym
FROM devv5.concept c
JOIN devv5.concept_synonym cs
    ON c.concept_id = cs.concept_id
WHERE c.vocabulary_id IN (:your_vocabs)
GROUP BY
    c.concept_code,
       c.vocabulary_id,
       cs.language_concept_id
),
new_syn AS (
SELECT c.concept_code,
       c.vocabulary_id,
       cs.language_concept_id as new_language_concept_id,
       array_agg (DISTINCT cs.concept_synonym_name ORDER BY cs.concept_synonym_name) as new_synonym
FROM concept c
JOIN concept_synonym cs
    ON c.concept_id = cs.concept_id
WHERE c.vocabulary_id IN (:your_vocabs)
GROUP BY
    c.concept_code,
       c.vocabulary_id,
       cs.language_concept_id
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
LEFT JOIN concept  b ON b.concept_id = r.concept_id_2
LEFT JOIN devv5.concept  c ON c.concept_id = a.concept_id
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
LEFT JOIN devv5.concept  c
    ON c.concept_id = a.concept_id
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
LEFT JOIN devv5.concept  c ON c.concept_id = a.concept_id
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
JOIN concept  b ON b.concept_id = r.concept_id_2
LEFT JOIN devv5.concept  c ON c.concept_id = a.concept_id
WHERE a.vocabulary_id IN (:your_vocabs)
AND c.concept_id IS NULL
;

--02.5. concepts changed their mapping ('Maps to', 'Maps to value')
--In this check we manually review the changes of concept's mapping to make sure they are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id and vocabulary_id fields. Then the content to be reviewed separately within the groups.
--This occurrence includes 2 possible scenarios: (i) mapping changed; (ii) mapping present in one version, absent in another. To review the absent mappings cases, sort by the respective code_agg to get the NULL values first.
--In this check we review the actual concept-level content and mapping quality, and for prioritization purposes more artifacts can be found in the following scenarios:
-- - mapping presented before, but is missing now;
-- - multiple 'Maps to' and/or 'Maps to value' links (sort by relationship_id to find such cases);
-- - frequent target concept (sort by new_code_agg or old_code_agg fields to find such cases).
--TODO: add logical groups for suspicious target domains

WITH new_map AS (
SELECT a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS relationship_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_code end, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS code_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_name end, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS name_agg
FROM concept a
LEFT JOIN concept_relationship r ON a.concept_id = concept_id_1 AND r.relationship_id IN ('Maps to', 'Maps to value') AND r.invalid_reason IS NULL
LEFT JOIN concept b ON b.concept_id = concept_id_2
WHERE a.vocabulary_id IN (:your_vocabs)
    --AND a.invalid_reason IS NULL --to exclude invalid concepts
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
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_code end, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS code_agg,
       string_agg (case when a.concept_id = b.concept_id then '<Mapped to itself>' else b.concept_name end, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS name_agg
FROM devv5.concept a
LEFT JOIN devv5.concept_relationship r ON a.concept_id = concept_id_1 AND r.relationship_id IN ('Maps to', 'Maps to value') AND r.invalid_reason IS NULL
LEFT JOIN devv5.concept b ON b.concept_id = concept_id_2
WHERE a.vocabulary_id IN (:your_vocabs)
    --AND a.invalid_reason IS NULL --to exclude invalid concepts
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
       b.name_agg AS new_name_agg,
       devv5.similarity(  a.name_agg,b.name_agg) AS old_new_similarity,
       devv5.similarity(  a.name_agg,b.concept_name) AS old_source_similarity,
       devv5.similarity(  b.name_agg,b.concept_name) AS new_source_similarity
FROM old_map a
JOIN new_map b
ON a.concept_id = b.concept_id AND ((COALESCE(a.code_agg, '') != COALESCE(b.code_agg, '')) OR (COALESCE(a.relationship_agg, '') != COALESCE(b.relationship_agg, '')))
ORDER BY a.concept_code,old_new_similarity NULLS FIRST,old_source_similarity NULLS FIRST,new_source_similarity NULLS FIRST
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
FROM devv5. concept a
LEFT JOIN devv5.concept_relationship r ON a.concept_id = concept_id_1 AND r.relationship_id IN ('Is a') AND r.invalid_reason IS NULL
LEFT JOIN devv5.concept b ON b.concept_id = concept_id_2
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
       b.name_agg AS new_name_agg,
       devv5.similarity(  a.name_agg,b.name_agg) AS old_new_similarity,
       devv5.similarity(  a.name_agg,b.concept_name) AS old_source_similarity,
       devv5.similarity(  b.name_agg,b.concept_name) AS new_source_similarity
FROM old_map  a
JOIN new_map b
ON a.concept_id = b.concept_id AND ((coalesce (a.code_agg, '') != coalesce (b.code_agg, '')) OR (coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, '')))
ORDER BY a.concept_code,old_new_similarity NULLS FIRST,old_source_similarity NULLS FIRST,new_source_similarity NULLS FIRST
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
		s0.concept_code_source,
		s0.concept_name_source,
		s0.concept_class_id_source,
		s0.domain_id_source,
		s0.relationship_id,
		s0.concept_code_target,
		s0.concept_name_target,
		s0.vocabulary_id_target,
		s0.max_vsd_in_group,
		(l.concept_id IS NULL) AS new_1_to_many_mappings
	FROM (
		SELECT a.concept_id,
			a.vocabulary_id,
			a.concept_code AS concept_code_source,
			a.concept_name AS concept_name_source,
			a.concept_class_id AS concept_class_id_source,
			a.domain_id AS domain_id_source,
			r.relationship_id,
			b.concept_code AS concept_code_target,
			CASE
				WHEN a.concept_id = b.concept_id
					THEN '<Mapped to itself>'
				ELSE b.concept_name
				END AS concept_name_target,
			CASE
				WHEN a.concept_id = b.concept_id
					THEN '<Mapped to itself>'
				ELSE b.vocabulary_id
				END AS vocabulary_id_target,
			COUNT(*) OVER (PARTITION BY a.concept_id) AS mappings_cnt,
			MAX(r.valid_start_date) OVER (PARTITION BY a.concept_id) AS max_vsd_in_group
		FROM concept a
		JOIN concept_relationship r ON r.concept_id_1 = a.concept_id
			AND r.invalid_reason IS NULL
			AND r.relationship_Id LIKE  'Maps to%'
		JOIN concept b ON b.concept_id = r.concept_id_2
		WHERE a.vocabulary_id IN (:your_vocabs)
		--AND r.concept_id_1 <> r.concept_id_2 --use it to exclude mapping to itself
		) s0
	LEFT JOIN (
		SELECT r_int.concept_id_1 AS concept_id
		FROM devv5.concept_relationship r_int
		WHERE r_int.invalid_reason IS NULL
			AND r_int.relationship_Id LIKE 'Maps to%'
			--AND r_int.concept_id_1 <> r_int.concept_id_2 --use it to exclude mapping to itself
		GROUP BY r_int.concept_id_1
		HAVING COUNT(*) > 1
		) l USING (concept_id)
	WHERE s0.mappings_cnt > 1
	) s1
ORDER BY s1.max_vsd_in_group DESC,
	s1.new_1_to_many_mappings DESC,
	s1.vocabulary_id,
	s1.concept_code_source,
	s1.concept_code_target;

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
JOIN devv5.concept b
        ON a.concept_id = b.concept_id
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
         SELECT  unnest(regexp_split_to_array(vaccine_inclusion,  '\|(?![^(]*\))')) AS mask FROM dev_rxe.vaccine_inclusion)

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

WITH covid_inclusion AS (SELECT covid_inclusion,unnest(regexp_split_to_array(covid_inclusion,  '\|(?![^(]*\))')) AS mask
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
-- - if you want to emphasis some aspects that are not follow from the hierarchy naturally;
-- - if the hierarchy of affected concepts is wrong.
-- problem_schema field reflects the schema in which the problem occurs (devv5, current or both). If you expect concept_ancestor changes in your development process, please run concept_ancestor builder appropriately.
-- Use valid_start_date field to prioritize the current mappings under the old ones ('1970-01-01' placeholder can be used for either old and recent mappings)

SELECT CASE WHEN ca_old.descendant_concept_id IS NOT NULL AND ca.descendant_concept_id IS NOT NULL  THEN 'both'
            WHEN ca_old.descendant_concept_id IS NOT NULL AND ca.descendant_concept_id IS NULL      THEN 'devv5'
            WHEN ca_old.descendant_concept_id IS NULL     AND ca.descendant_concept_id IS NOT NULL  THEN 'current'
                END AS problem_schema,
       LEAST (a.valid_start_date, b.valid_start_date) AS valid_start_date,
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
LEFT JOIN devv5.concept_ancestor ca_old
    ON a.concept_id_2 = ca_old.descendant_concept_id
        AND b.concept_id_2 = ca_old.ancestor_concept_id
LEFT JOIN concept_ancestor ca
    ON a.concept_id_2 = ca.descendant_concept_id
        AND b.concept_id_2 = ca.ancestor_concept_id
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
    AND (ca_old.descendant_concept_id IS NOT NULL OR ca.descendant_concept_id IS NOT NULL)
ORDER BY LEAST (a.valid_start_date, b.valid_start_date) DESC,
         c.vocabulary_id,
         c.concept_code
;

-- 02.13. Mapping of visit concepts
--In this check we manually review the mapping of visits to the 'Visit' domain.
-- -- Three flags are used:
-- -- - 'incorrect mapping' - indicates the concepts that are probably visits but mapped to domains other than 'Visit';
-- -- - 'review mapping to visit' - indicates concepts that are mapped to the 'Visit' domain but the target_concept_id differs from the reference;
-- -- - 'correct mapping' - indicates the concepts mapped to the expected target visits.
-- -- The flag_visit_should_be field contains the most commonly used types of visits that could be the target for your mapping, and also flag 'other visit' that may indicate the relatively rarely used concepts in the 'Visit' domain.
-- Because of mapping complexity and trickiness, and depending on the way the mappings were produced, full manual review may be needed.
-- Please adjust inclusion/exclusion in the master branch if found some flaws

--- 02.13.01 This check is highly sensitive and adjusted for the Procedure vocabularies only.

WITH home_visit AS (SELECT ('(?<!(morp))home(?!(tr|opath|less|ria|ostasis))|domiciliary') AS home_visit),
    outpatient_visit AS (SELECT ('outpatient|out.patient|ambul(?!(ance|ation|ism))|office(?!(r))') AS outpatient_visit),
    ambulance_visit AS (SELECT ('ambulance(\W)|transport(?!(er))') AS ambulance_visit),
    emergency_room_visit AS (SELECT ('emerg(?!(ence|omyces))|(\W)ER(\W)') AS emergency_room_visit),
    pharmacy_visit AS (SELECT ('(\W)pharm(\s)|pharmacy') AS pharmacy_visit),
    inpatient_visit AS (SELECT ('inpatient|in.patient|(\W)hosp(?!(ice|h|ira))') AS inpatient_visit),
    telehealth AS (SELECT ('(?<!(pla))tele(?!(t|scop|ctasis))|remote|video') AS telehealth),
    other_visit AS (SELECT ('clinic(?!(al))|esrd|(\W)center(\W)|(\W)facility|visit|institution|encounter|rehab|hospice|nurs|school|(\W)unit(\W)|(\W)nicu(\W)') AS other_visit),
    ER_exclusion AS (SELECT ('estrogen') AS ER_exclusion),
    ambulance_exclusion AS (SELECT ('accident|collision|metabol') AS ambulance_exclusion),

flag AS (SELECT DISTINCT c.concept_code,
                c.concept_name,
                c.vocabulary_id,
                b.concept_id AS target_concept_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_name END AS target_concept_name,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.vocabulary_id END AS target_vocabulary_id,
                b.domain_id AS target_domain_id,
                              CASE WHEN c.concept_name ~* (SELECT home_visit FROM home_visit) AND
                                       b.concept_id != '581476' THEN 'home visit'
                                  WHEN c.concept_name ~* (SELECT outpatient_visit FROM outpatient_visit) AND
                                       b.concept_id != '9202' THEN 'outpatient visit'
                                  WHEN c.concept_name ~* (SELECT ambulance_visit FROM ambulance_visit)
                                           AND c.concept_name !~* (SELECT ambulance_exclusion FROM ambulance_exclusion)
                                           AND b.concept_id NOT IN ('581478', '38004353') THEN 'ambulance visit'
                                  WHEN c.concept_name ~* (SELECT emergency_room_visit FROM emergency_room_visit)
                                           AND c.concept_name !~* (SELECT ER_exclusion FROM ER_exclusion)
                                           AND b.concept_id != '9203' THEN 'emergency room visit'
                                  WHEN c.concept_name ~* (SELECT pharmacy_visit FROM pharmacy_visit) AND
                                       b.concept_id != '581458' THEN 'pharmacy visit'
                                  WHEN c.concept_name ~* (SELECT inpatient_visit FROM inpatient_visit) AND
                                       b.concept_id != '9201' THEN 'inpatient visit'
                                  WHEN c.concept_name ~* (SELECT telehealth FROM telehealth) AND
                                       b.concept_id != '5083' THEN 'telehealth'
                                  WHEN c.concept_name ~* (SELECT other_visit FROM other_visit)
                                        THEN 'other visit'
                                  END AS flag_visit_should_be
FROM concept c
LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND relationship_id ='Maps to' AND cr.invalid_reason IS NULL
LEFT JOIN concept b ON b.concept_id = cr.concept_id_2
WHERE c.vocabulary_id IN (:your_vocabs)
),

incorrect_mapping AS (SELECT concept_code,
                concept_name,
                vocabulary_id,
                target_concept_id,
                target_concept_name,
                target_vocabulary_id,
                'incorrect_mapping' AS flag,
                flag_visit_should_be
FROM flag
WHERE target_domain_id != 'Visit'),

review_mapping_to_visit AS (SELECT concept_code,
                concept_name,
                vocabulary_id,
                target_concept_id,
                target_concept_name,
                target_vocabulary_id,
                'review_mapping_to_visit' AS flag,
                flag_visit_should_be
FROM flag
WHERE target_domain_id = 'Visit'),

correct_mapping AS (SELECT DISTINCT c.concept_code,
                c.concept_name,
                c.vocabulary_id,
                b.concept_id AS target_concept_id,
                b.concept_name AS target_concept_name,
                b.vocabulary_id AS target_vocabulary_id,
                'correct mapping' AS flag,
                NULL AS flag_visit_should_be
FROM concept c
LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND relationship_id ='Maps to' AND cr.invalid_reason IS NULL
LEFT JOIN concept b ON b.concept_id = cr.concept_id_2
WHERE c.vocabulary_id IN (:your_vocabs)
AND b.concept_id IN (581476, 9202, 581478, 38004353, 9203, 581458, 9201, 5083)
)

SELECT vocabulary_id,
       concept_code,
       concept_name,
       flag,
       flag_visit_should_be,
       target_concept_id,
       target_concept_name,
       target_vocabulary_id
FROM incorrect_mapping
WHERE flag_visit_should_be IS NOT NULL
             AND concept_code NOT IN (SELECT concept_code FROM review_mapping_to_visit) -- concepts mapped 1-to-many to visit + other domain should not be flagged as incorrect
             AND concept_code NOT IN (SELECT concept_code FROM correct_mapping) -- concepts mapped 1-to-many to visit + other domain should not be flagged as incorrect

UNION ALL

SELECT vocabulary_id,
       concept_code,
       concept_name,
       flag,
       flag_visit_should_be,
       target_concept_id,
       target_concept_name,
       target_vocabulary_id
FROM review_mapping_to_visit
WHERE flag_visit_should_be IS NOT NULL
              AND concept_code NOT IN (SELECT concept_code FROM correct_mapping) -- do not include concepts, already mentioned in correct_mapping and mistakenly defined as 'other visit' by regex

UNION ALL

SELECT vocabulary_id,
       concept_code,
       concept_name,
       flag,
       flag_visit_should_be,
       target_concept_id,
       target_concept_name,
       target_vocabulary_id
FROM correct_mapping

ORDER BY flag,
    flag_visit_should_be,
    vocabulary_id,
    concept_code
;

--- 02.13.02 This check presents higher specificity, and it's adjusted for non-Procedure vocabs (Conditions, Measurements, Drugs, etc.)

WITH home_visit AS (SELECT ('home visit|home care|home service|home assessment|home therapy|home health aide|(\W)at.home|domiciliary') AS home_visit),
    outpatient_visit AS (SELECT ('outpatient(\s)|(\s)out.patient|ambul(?!(ance|ation|ism|ant|ating))') AS outpatient_visit),
    ambulance_visit AS (SELECT ('ambulance(\W)') AS ambulance_visit),
    emergency_room_visit AS (SELECT ('emergency department|emergency room|(\s)ER(\s)') AS emergency_room_visit),
    pharmacy_visit AS (SELECT ('(\s)pharmacy') AS pharmacy_visit),
    inpatient_visit AS (SELECT ('inpatient|(\W)hospit') AS inpatient_visit),
    telehealth AS (SELECT ('telehealth|telepractice|telephone|telemedicine|video') AS telehealth),
    other_visit AS (SELECT ('clinic(\s)|esrd|(\W)center(\W)|(\W)facility|(\s)visit(?!(or))|hospice|nursing(\W)unit(\W)|(\W)nicu(\W)') AS other_visit),

    ER_exclusion AS (SELECT ('estrogen|signposting|refer') AS ER_exclusion),
    ambulance_exclusion AS (SELECT ('accident|collision|refer|signposting') AS ambulance_exclusion),
    home_exclusion AS (SELECT ('nursing|refer|occurrence') AS home_exclusion),
    inpatient_exclusion AS (SELECT ('quality|grade|refer|signposting|suppl|ltd|born|risk') AS inpatient_exclusion),
    other_exclusion AS (SELECT ('refer|signposting|follic|ossification|claim') AS other_exclusion),
    outpatient_exclusion AS (SELECT ('refer|signposting') AS outpatient_exclusion),
    pharmacy_exclusion AS (SELECT ('ltd') AS pharmacy_exclusion),
    telehealth_exclusion AS (SELECT ('number|operator|technician|manager|fitter|user|cassette|printer|(\w)scop') AS telehealth_exclusion),

flag AS (SELECT DISTINCT c.concept_code,
                c.concept_name,
                c.vocabulary_id,
                b.concept_id AS target_concept_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_name END AS target_concept_name,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.vocabulary_id END AS target_vocabulary_id,
                b.domain_id AS target_domain_id,
                              CASE WHEN c.concept_name ~* (SELECT home_visit FROM home_visit)
                                            AND c.concept_name !~* (SELECT home_exclusion FROM home_exclusion)
                                            AND b.concept_id != '581476' THEN 'home visit'
                                  WHEN c.concept_name ~* (SELECT outpatient_visit FROM outpatient_visit)
                                            AND c.concept_name !~* (SELECT outpatient_exclusion FROM outpatient_exclusion)
                                            AND b.concept_id != '9202' THEN 'outpatient visit'
                                  WHEN c.concept_name ~* (SELECT ambulance_visit FROM ambulance_visit)
                                           AND c.concept_name !~* (SELECT ambulance_exclusion FROM ambulance_exclusion)
                                           AND b.concept_id NOT IN ('581478', '38004353') THEN 'ambulance visit'
                                  WHEN c.concept_name ~* (SELECT emergency_room_visit FROM emergency_room_visit)
                                           AND c.concept_name !~* (SELECT ER_exclusion FROM ER_exclusion)
                                           AND b.concept_id != '9203' THEN 'emergency room visit'
                                  WHEN c.concept_name ~* (SELECT pharmacy_visit FROM pharmacy_visit)
                                      AND c.concept_name !~* (SELECT pharmacy_exclusion FROM pharmacy_exclusion)
                                      AND b.concept_id != '581458' THEN 'pharmacy visit'
                                  WHEN c.concept_name ~* (SELECT inpatient_visit FROM inpatient_visit)
                                           AND c.concept_name !~* (SELECT inpatient_exclusion FROM inpatient_exclusion)
                                           AND b.concept_id != '9201' THEN 'inpatient visit'
                                  WHEN c.concept_name ~* (SELECT telehealth FROM telehealth)
                                       AND c.concept_name !~* (SELECT telehealth_exclusion FROM telehealth_exclusion)
                                       AND b.concept_id != '5083' THEN 'telehealth'
                                  WHEN c.concept_name ~* (SELECT other_visit FROM other_visit)
                                        AND c.concept_name !~* (SELECT other_exclusion FROM other_exclusion)
                                        THEN 'other visit'
                                  END AS flag_visit_should_be
FROM concept c
LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND relationship_id ='Maps to' AND cr.invalid_reason IS NULL
LEFT JOIN concept b ON b.concept_id = cr.concept_id_2
WHERE c.vocabulary_id IN (:your_vocabs)
),

incorrect_mapping AS (SELECT concept_code,
                concept_name,
                vocabulary_id,
                target_concept_id,
                target_concept_name,
                target_vocabulary_id,
                'incorrect_mapping' AS flag,
                flag_visit_should_be
FROM flag
WHERE target_domain_id != 'Visit'),

review_mapping_to_visit AS (SELECT concept_code,
                concept_name,
                vocabulary_id,
                target_concept_id,
                target_concept_name,
                target_vocabulary_id,
                'review_mapping_to_visit' AS flag,
                flag_visit_should_be
FROM flag
WHERE target_domain_id = 'Visit'),

correct_mapping AS (SELECT DISTINCT c.concept_code,
                c.concept_name,
                c.vocabulary_id,
                b.concept_id AS target_concept_id,
                b.concept_name AS target_concept_name,
                b.vocabulary_id AS target_vocabulary_id,
                'correct mapping' AS flag,
                NULL AS flag_visit_should_be
FROM concept c
LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND relationship_id ='Maps to' AND cr.invalid_reason IS NULL
LEFT JOIN concept b ON b.concept_id = cr.concept_id_2
WHERE c.vocabulary_id IN (:your_vocabs)
AND b.concept_id IN (581476, 9202, 581478, 38004353, 9203, 581458, 9201, 5083)
)

SELECT vocabulary_id,
       concept_code,
       concept_name,
       flag,
       flag_visit_should_be,
       target_concept_id,
       target_concept_name,
       target_vocabulary_id
FROM incorrect_mapping
WHERE flag_visit_should_be IS NOT NULL
             AND concept_code NOT IN (SELECT concept_code FROM review_mapping_to_visit) -- concepts mapped 1-to-many to visit + other domain should not be flagged as incorrect
             AND concept_code NOT IN (SELECT concept_code FROM correct_mapping) -- concepts mapped 1-to-many to visit + other domain should not be flagged as incorrect

UNION ALL

SELECT vocabulary_id,
       concept_code,
       concept_name,
       flag,
       flag_visit_should_be,
       target_concept_id,
       target_concept_name,
       target_vocabulary_id
FROM review_mapping_to_visit
WHERE flag_visit_should_be IS NOT NULL
              AND concept_code NOT IN (SELECT concept_code FROM correct_mapping) -- do not include concepts, already mentioned in correct_mapping and mistakenly defined as 'other visit' by regex


UNION ALL

SELECT vocabulary_id,
       concept_code,
       concept_name,
       flag,
       flag_visit_should_be,
       target_concept_id,
       target_concept_name,
       target_vocabulary_id
FROM correct_mapping

ORDER BY flag,
    flag_visit_should_be,
    vocabulary_id,
    concept_code,
    target_concept_id
;

--03. Check we don't add duplicative concepts
-- This check retrieves the list of duplicative concepts with the same names and the flag indicator whether the concepts are new.
-- This may be indication on the source wrong processing or duplication of content in it, and has to be further investigated.
SELECT CASE WHEN string_agg (DISTINCT c2.concept_id::text, '-') IS NULL THEN 'new concept' ELSE 'old concept' END AS when_added,
       c.concept_name,
       string_agg (DISTINCT c2.concept_id::text, '-') AS concept_id
FROM concept c
LEFT JOIN devv5.concept c2
    ON c.concept_id = c2.concept_id
WHERE c.vocabulary_id IN (:your_vocabs)
    AND c.invalid_reason IS NULL
GROUP BY c.concept_name
HAVING COUNT (*) >1
ORDER BY when_added, concept_name
;

--04. Concepts have replacement link, but miss "Maps to" link
-- This check controls that all replacement links are repeated with the 'Maps to' link that are used by ETL.
--TODO: at the moment it's not resolved in SNOMED and some other places and requires additional attention. Review p.5 of "What's New" chapter [here](https://github.com/OHDSI/Vocabulary-v5.0/releases/tag/v20220829_1661776786)

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
    AND EXISTS (SELECT concept_id_1
                FROM concept_relationship cr1
                WHERE cr1.relationship_id IN ('Concept replaced by', 'Concept same_as to', 'Concept alt_to to', 'Concept was_a to')
                    AND cr1.invalid_reason IS NULL
                    AND cr1.concept_id_1 = cr.concept_id_1)
    AND NOT EXISTS (SELECT concept_id_1
                    FROM concept_relationship cr2
                    WHERE cr2.relationship_id IN ('Maps to')
                        AND cr2.invalid_reason IS NULL
                        AND cr2.concept_id_1 = cr.concept_id_1)
    AND cr.relationship_id IN ('Concept replaced by', 'Concept same_as to', 'Concept alt_to to', 'Concept was_a to')
ORDER BY cr.relationship_id, cc.standard_concept, cr.concept_id_1
;

--05. Check the presence of symmetric relationships in the manual tables.
--- We expect this check to return nothing. Normally we don't store symmetric relationships in manual tables since they're created by generic_update.sql.
--- Otherwise you should find out why these relationships are stored in manual tables and consider dropping them if they're useless.

SELECT crm1.concept_code_1, crm1.vocabulary_id_1, crm1.relationship_id, crm1.concept_code_2, crm1.vocabulary_id_2,
        crm2.concept_code_1, crm2.vocabulary_id_1, crm2.relationship_id, crm2.concept_code_2, crm2.vocabulary_id_2
FROM concept_relationship_manual crm1
         JOIN concept_relationship_manual crm2 ON crm1.concept_code_1 = crm2.concept_code_2
         AND crm1.concept_code_2 = crm2.concept_code_1
WHERE (crm1.relationship_id = 'Maps to' AND crm2.relationship_id = 'Mapped from')
OR (crm1.relationship_id = 'Is a' AND crm2.relationship_id = 'Subsumes')
OR (crm1.relationship_id = 'Maps to value' AND crm2.relationship_id = 'Value mapped from')
AND crm1.vocabulary_id_1 = crm2.vocabulary_id_2
AND crm2.vocabulary_id_1 = crm1.vocabulary_id_2
AND crm1.vocabulary_id_1 IN (:your_vocabs)
ORDER BY crm1.concept_code_1;
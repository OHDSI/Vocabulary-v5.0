--01. Concept changes

--01.1. Concepts changed their Domain
--In this check we manually review the changes of concept's Domain to make sure they are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id, vocabulary_id fields as well as old vs new domain_id pairs. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), Domain changes may be caused, and, therefore, explained by multiple reasons, e.g.:
-- - based on Domain of the target concept and script logic on top of that;
-- - source hierarchy change;
-- - manual curation of the content by the vocabulary folks;
-- - Domain assigning script change or its unexpected behaviour.

select new.concept_code,
       new.concept_name as concept_name,
       new.concept_class_id as concept_class_id,
       new.standard_concept as standard_concept,
       new.vocabulary_id as vocabulary_id,
       old.domain_id as old_domain_id,
       new.domain_id as new_domain_id
from concept new
join devv5.concept old
    using (concept_id)
where old.domain_id != new.domain_id
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
       c1.domain_id as new_domain
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
       c2.concept_name as old_name,
       c.concept_name as new_name,
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

with old_syn as (

SELECT c.concept_code,
       c.vocabulary_id,
       cs.language_concept_id,
       array_agg (DISTINCT cs.concept_synonym_name ORDER BY cs.concept_synonym_name) as old_synonym
FROM devv5.concept c
JOIN devv5.concept_synonym cs
    ON c.concept_id = cs.concept_id
WHERE c.vocabulary_id IN (:your_vocabs)
GROUP BY c.concept_code,
       c.vocabulary_id,
       cs.language_concept_id
),

new_syn as (

SELECT c.concept_code,
       c.vocabulary_id,
       cs.language_concept_id,
       array_agg (DISTINCT cs.concept_synonym_name ORDER BY cs.concept_synonym_name) as new_synonym
FROM concept c
JOIN concept_synonym cs
    ON c.concept_id = cs.concept_id
WHERE c.vocabulary_id IN (:your_vocabs)
GROUP BY c.concept_code,
       c.vocabulary_id,
       cs.language_concept_id
)

SELECT DISTINCT
       o.concept_code,
       o.vocabulary_id,
       o.old_synonym,
       n.new_synonym,
       devv5.similarity (o.old_synonym::varchar, n.new_synonym::varchar)
FROM old_syn o

LEFT JOIN new_syn n
    ON o.concept_code = n.concept_code
        AND o.vocabulary_id = n.vocabulary_id
        AND o.language_concept_id = n.language_concept_id

WHERE o.old_synonym != n.new_synonym OR n.new_synonym IS NULL

ORDER BY devv5.similarity (o.old_synonym::varchar, n.new_synonym::varchar)
;

--02. Mapping of concepts

--02.1. looking at new concepts and their mapping -- 'Maps to' absent
--In this check we manually review new concepts that don't have "Maps to" links to the Standard equivalent concepts.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by concept_class_id, vocabulary_id and domain_id fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), vocabulary importance and its maturity level, effort and resources available, result should be critically analyzed and may represent multiple scenarios, e.g.:
-- - concepts of some concept classes doesn't require "Maps to" links because the targets are not set as Standard concepts by design (brand names, drug forms, etc.);
-- - new NDC or vaccine concepts are not yet represented in the RxNorm/CVX vocabulary, and, therefore, can't be mapped;
-- - OMOP-generated invalidated concepts are not used as the source concepts, and, therefore, replacement links are not supported;
-- - concepts that were wrongly designed by the author (e.g. SNOMED) can't be explicitly mapped to the Standard target.

select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.vocabulary_id as vocabulary_id_source,
       a.concept_class_id as concept_class_id_source,
       a.domain_id as domain_id_source,
       b.concept_name as concept_name_target,
       b.vocabulary_id as vocabulary_id_target
 from concept a
left join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Maps to'
left join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN (:your_vocabs)
and c.concept_id is null and b.concept_id is null
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

select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.vocabulary_id as vocabulary_id_source,
       a.concept_class_id as concept_class_id_source,
       a.domain_id as domain_id_source,
       r.relationship_id,
       CASE WHEN a.concept_id = b.concept_id and r.relationship_id ='Maps to' THEN '<Mapped to itself>'
           ELSE b.concept_name END as concept_name_target,
       CASE WHEN a.concept_id = b.concept_id and r.relationship_id ='Maps to' THEN '<Mapped to itself>'
           ELSE b.vocabulary_id END as vocabulary_id_target
from concept a
join concept_relationship r
    on a.concept_id=r.concept_id_1
           and r.invalid_reason is null
           and r.relationship_Id in ('Maps to', 'Maps to value')
join concept b
    on b.concept_id = r.concept_id_2
left join devv5.concept  c
    on c.concept_id = a.concept_id
where a.vocabulary_id IN (:your_vocabs)
    and c.concept_id is null
    --and a.concept_id != b.concept_id --use it to exclude mapping to itself
order by a.concept_code
;

--02.3. looking at new concepts and their ancestry -- 'Is a' absent
--In this check we manually review new concepts that don't have "Is a" hierarchical links to the parental concepts.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id, vocabulary_id and domain_id fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), vocabulary importance and its maturity level, effort and resources available, result should be critically analyzed and may represent multiple scenarios, e.g.:
-- - Standard or non-Standard concepts of the source vocabulary that doesn't provide hierarchical links, and we don't build them (source drug vocabularies);
-- - concepts of the concept classes that can't be hierarchically linked (units, methods, scales);
-- - concepts of the source vocabularies deStandardized and mapped over to the Standard concepts instead of added to the hierarchy;
-- - top level concepts.

select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.vocabulary_id as vocabulary_id_source,
       a.standard_concept as standard_concept_source,
       a.concept_class_id as concept_class_id_source,
       a.domain_id as domain_id_source,
       b.concept_name as concept_name_target,
       b.concept_class_id as concept_class_id_target,
       b.vocabulary_id as vocabulary_id_target
from concept a
left join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Is a'
left join concept b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN (:your_vocabs)
and c.concept_id is null and b.concept_id is null
;

--02.4. looking at new concepts and their ancestry -- 'Is a' present
--In this check we manually review new concepts that have "Is a" hierarchical links to the parental concepts.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by concept_class_id, vocabulary_id, domain_id and vocabulary_id_target fields. Then the content to be reviewed separately within the groups.
--Depending on the logical group (use case), result should be critically analyzed and may represent multiple scenarios, e.g.:
--TODO: add scenarios
--In this check we are not aiming on reviewing the semantics or quality of relationships. The completeness of content (versus 02.3 check) and alignment of the source use cases and mapping scenarios is the subject matter in this check.


select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.vocabulary_id as vocabulary_id_source,
       a.concept_class_id as concept_class_id_source,
       a.domain_id as domain_id_source,
       r.relationship_id,
       b.concept_name as concept_name_target,
       b.concept_class_id as concept_class_id_target,
       b.vocabulary_id as vocabulary_id_target
from concept a
join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Is a'
join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN (:your_vocabs)
and c.concept_id is null
;

--02.5. concepts changed their mapping ('Maps to', 'Maps to value')
--In this check we manually review the changes of concept's mapping to make sure they are expected, correct and in line with the current conventions and approaches.
--Also we can assess the source which mapping comes from and at what point in the run the mapping changes occurred.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id and vocabulary_id fields. Then the content to be reviewed separately within the groups.
--This occurrence includes 2 possible scenarios: (i) mapping changed; (ii) mapping present in one version, absent in another. To review the absent mappings cases, sort by the respective code_agg to get the NULL values first.
--In this check we review the actual concept-level content and mapping quality, and for prioritization purposes more artifacts can be found in the following scenarios:
-- - mapping presented before, but is missing now;
-- - multiple 'Maps to' and/or 'Maps to value' links (sort by relationship_id to find such cases);
-- - frequent target concept (sort by new_code_agg or old_code_agg fields to find such cases).
CREATE OR REPLACE FUNCTION mapping_changes(your_vocabs text[])
RETURNS TABLE (
    vocabulary_id varchar,
    concept_class_id varchar,
    standard_concept varchar,
    source_code varchar,
    source_name varchar,
    old_source_agg text,
    old_relat_agg text,
    old_code_agg text,
    old_name_agg text,
    old_mapping_changes text,
    new_source_agg text,
    new_relat_agg text,
    new_code_agg text,
    new_name_agg text,
    old_new_similarity real,
    old_source_similarity real,
    new_source_similarity real
) AS $$
BEGIN
    -- Create temporary table for new_map
    DROP TABLE IF EXISTS temp_new_map;
    CREATE TEMPORARY TABLE temp_new_map AS
    SELECT a.concept_id,
           a.vocabulary_id,
           a.concept_class_id,
           a.standard_concept,
           a.concept_code,
           a.concept_name,
           STRING_AGG(r.relationship_id, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS relationship_agg,
           STRING_AGG(CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>' ELSE b.concept_code END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS code_agg,
           STRING_AGG(CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>' ELSE b.concept_name END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS name_agg,
           STRING_AGG(CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>' ELSE b.vocabulary_id END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS vocabulary_agg,
           STRING_AGG(CASE WHEN EXISTS
                            (SELECT 1 FROM concept_relationship_manual
                             WHERE concept_code_1 = a.concept_code AND vocabulary_id_1 = a.vocabulary_id
                             AND relationship_id = r.relationship_id
                             AND concept_code_2 = b.concept_code AND vocabulary_id_2 = b.vocabulary_id
                             AND vocabulary_id_1 = ANY (your_vocabs) AND invalid_reason IS NULL)
                        THEN 'manual mapping' ELSE 'load_stage' END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS source_agg
    FROM concept a
    LEFT JOIN concept_relationship r ON a.concept_id = r.concept_id_1 AND r.relationship_id IN ('Maps to', 'Maps to value') AND r.invalid_reason IS NULL
    LEFT JOIN concept b ON b.concept_id = r.concept_id_2
    WHERE a.vocabulary_id = ANY (your_vocabs)
    --AND a.invalid_reason IS NULL --to exclude invalid concepts
    GROUP BY a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name;

    -- Create indexes for temp_new_map
    CREATE INDEX idx_temp_new_map_concept_id ON temp_new_map(concept_id);
    CREATE INDEX idx_temp_new_map_vocabulary_id ON temp_new_map(vocabulary_id);

    -- Create temporary table for old_map
    DROP TABLE IF EXISTS temp_old_map;
    CREATE TEMPORARY TABLE temp_old_map AS
    SELECT a.concept_id,
           a.vocabulary_id,
           a.concept_class_id,
           a.standard_concept,
           a.concept_code,
           a.concept_name,
           STRING_AGG(r.relationship_id, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS relationship_agg,
           STRING_AGG(CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>' ELSE b.concept_code END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS code_agg,
           STRING_AGG(CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>' ELSE b.concept_name END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS name_agg,
           STRING_AGG(CASE WHEN EXISTS
                            (SELECT 1 FROM concept_relationship_manual
                             WHERE concept_code_1 = a.concept_code AND vocabulary_id_1 = a.vocabulary_id
                             AND relationship_id = r.relationship_id
                             AND concept_code_2 = b.concept_code AND vocabulary_id_2 = b.vocabulary_id
                             AND vocabulary_id_1 = ANY (your_vocabs) AND invalid_reason = 'D')
                        THEN 'deprecated manually'
               WHEN EXISTS
                            (SELECT 1 FROM concept_relationship_stage
                             WHERE concept_code_1 = a.concept_code
                             AND vocabulary_id_1 = a.vocabulary_id
                             AND relationship_id = r.relationship_id
                             AND concept_code_2 = b.concept_code
                             AND vocabulary_id_2 = b.vocabulary_id
                             AND invalid_reason IS NULL)
                   AND EXISTS
                            (SELECT 1 FROM concept_relationship
                             WHERE concept_id_1 = a.concept_id AND relationship_id = r.relationship_id
                             AND concept_id_2 = b.concept_id AND invalid_reason = 'D' AND relationship_id IN ('Maps to', 'Maps to value')
                             AND concept_id_1 IN (SELECT concept_id FROM concept c WHERE c.vocabulary_id = ANY (your_vocabs)))
                        THEN 'deprecated by generic'
                        ELSE 'valid' END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS changes_agg,
           STRING_AGG(CASE WHEN EXISTS
                            (SELECT 1 FROM devv5.base_concept_relationship_manual
                             WHERE concept_code_1 = a.concept_code AND vocabulary_id_1 = a.vocabulary_id
                             AND relationship_id = r.relationship_id
                             AND concept_code_2 = b.concept_code AND vocabulary_id_2 = b.vocabulary_id
                             AND vocabulary_id_1 = ANY (your_vocabs) AND invalid_reason IS NULL)
                        THEN 'manual mapping' ELSE 'load_stage' END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS source_agg
    FROM devv5.concept a
    LEFT JOIN devv5.concept_relationship r ON a.concept_id = r.concept_id_1 AND r.relationship_id IN ('Maps to', 'Maps to value') AND r.invalid_reason IS NULL
    LEFT JOIN devv5.concept b ON b.concept_id = r.concept_id_2
    WHERE a.vocabulary_id = ANY (your_vocabs)
    --AND a.invalid_reason IS NULL --to exclude invalid concepts
    GROUP BY a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name;

    -- Create indexes for temp_old_map
    CREATE INDEX idx_temp_old_map_concept_id ON temp_old_map(concept_id);
    CREATE INDEX idx_temp_old_map_vocabulary_id ON temp_old_map(vocabulary_id);

    -- Final query using the temporary tables
    RETURN QUERY
    SELECT b.vocabulary_id AS vocabulary_id,
           b.concept_class_id,
           b.standard_concept,
           b.concept_code AS source_code,
           b.concept_name AS source_name,
           CASE WHEN a.code_agg IS NULL THEN NULL ELSE a.source_agg END AS old_source_agg,
           a.relationship_agg AS old_relat_agg,
           a.code_agg AS old_code_agg,
           a.name_agg AS old_name_agg,
           CASE WHEN a.code_agg IS NULL THEN NULL ELSE a.changes_agg END AS old_mapping_changes,
           CASE WHEN b.code_agg IS NULL THEN NULL ELSE b.source_agg END AS new_source_agg,
           b.relationship_agg AS new_relat_agg,
           b.code_agg AS new_code_agg,
           b.name_agg AS new_name_agg,
           devv5.similarity(  a.name_agg,b.name_agg) AS old_new_similarity,
           devv5.similarity(  a.name_agg,b.concept_name) AS old_source_similarity,
           devv5.similarity(  b.name_agg,b.concept_name) AS new_source_similarity
    FROM temp_old_map a
    JOIN temp_new_map b ON a.concept_id = b.concept_id
                         AND (COALESCE(a.code_agg, '') != COALESCE(b.code_agg, '') OR
                              COALESCE(a.relationship_agg, '') != COALESCE(b.relationship_agg, ''))
    ORDER BY a.concept_code;
END;
$$ LANGUAGE plpgsql;

-- Run the function and review the results:
SELECT *
FROM mapping_changes(ARRAY['xyz']); --ARRAY['SNOMED', 'HCPCS', 'LOINC']


--02.6. Concepts changed their ancestry ('Is a')
--In this check we manually review the changes of concept's ancestry to make sure they are expected, correct and in line with the current conventions and approaches.
--To prioritize and make the review process more structured, the logical groups to be identified using the sorting by standard_concept, concept_class_id, vocabulary_id fields. Then the content to be reviewed separately within the groups.
--This occurrence includes 2 possible scenarios: (i) ancestor(s) changed; (ii) ancestor(s) present in one version, absent in another. To review the absent ancestry cases, sort by the respective code_agg to get the NULL values first.
--In this check we review the actual concept-level content, and for prioritization purposes more artifacts can be found in the following scenarios:
-- - ancestor(s) presented before, but is missing now;
-- - multiple 'Is a' links (sort by relationship_id to find such cases);
-- - frequent target concept (sort by new_relat_agg or old_relat_agg fields to find such cases).
--TODO: add logical groups for suspicious target domains

with new_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as relationship_agg,
       string_agg (b.concept_code, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as code_agg,
       string_agg (b.concept_name, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as name_agg
from concept a
left join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
left join concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs) and a.invalid_reason is null
group by a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as relationship_agg,
       string_agg (b.concept_code, '-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as code_agg,
       string_agg (b.concept_name, '-/-' order by r.relationship_id, b.concept_code, b.vocabulary_id) as name_agg
from devv5. concept a
left join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
left join devv5.concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs) and a.invalid_reason is null
group by a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
select b.vocabulary_id as vocabulary_id,
       b.concept_class_id,
       b.standard_concept,
       b.concept_code as source_code,
       b.concept_name as source_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
from old_map  a
join new_map b
on a.concept_id = b.concept_id and ((coalesce (a.code_agg, '') != coalesce (b.code_agg, '')) or (coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, '')))
order by a.concept_code
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

select a.concept_code,
       a.concept_name,
       a.concept_class_id,
       a.domain_id,
       a.vocabulary_id
from concept a
join devv5.concept b
        on a.concept_id = b.concept_id
where a.vocabulary_id IN (:your_vocabs)
    and b.standard_concept = 'S'
    and a.standard_concept IS NULL
    and not exists (
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

with vaccine_exclusion as (SELECT
    'placeholder|placeholder' as vaccine_exclusion
    )
,
     vaccine_inclusion as (
         SELECT  unnest(regexp_split_to_array(vaccine_inclusion,  '\|(?![^(]*\))')) as mask FROM dev_rxe.vaccine_inclusion)

SELECT DISTINCT array_agg(DISTINCT coalesce(vi.mask,vi2.mask )) as mask_array,
                c.concept_code,
                c.vocabulary_id,
                c.concept_name,
                c.concept_class_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_name END as target_concept_name,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_class_id END as target_concept_class_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.vocabulary_id END as target_vocabulary_id
FROM concept c
LEFT JOIN concept_relationship cr
    ON cr.concept_id_1 = c.concept_id
           AND relationship_id ='Maps to' and cr.invalid_reason IS NULL
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

with covid_inclusion as (SELECT
        'sars(?!(tedt|aparilla))|^cov(?!(er|onia|aWound|idien))|cov$|^ncov|ncov$|corona(?!(l|ry|ries| radiata))|severe acute|covid(?!ien)' as covid_inclusion
    ),

covid_exclusion as (SELECT
    '( |^)LASSARS' as covid_exclusion
    )


select distinct
                MAX(cr2.valid_start_date) as valid_start_date,
                c.vocabulary_id,
                c.concept_code,
                c.concept_name,
                c.concept_class_id,
                cr.relationship_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_name END as target_concept_name,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.concept_class_id END as target_concept_class_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.domain_id END as target_domain_id,
                CASE WHEN c.concept_id = b.concept_id THEN '<Mapped to itself>'
                    ELSE b.vocabulary_id END as target_vocabulary_id
from concept c
left join concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to', 'Maps to value') and cr.invalid_reason is null
left join concept b on b.concept_id = cr.concept_id_2
left join concept_relationship cr2 on cr2.concept_id_1 = c.concept_id and cr2.relationship_id IN ('Maps to', 'Maps to value') and cr2.invalid_reason is null
where c.vocabulary_id IN (:your_vocabs)

    and ((c.concept_name ~* (select covid_inclusion from covid_inclusion) and c.concept_name !~* (select covid_exclusion from covid_exclusion))
        or
        (b.concept_name ~* (select covid_inclusion from covid_inclusion) and b.concept_name !~* (select covid_exclusion from covid_exclusion)))
GROUP BY 2,3,4,5,6,7,8,9,10
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
       a.concept_id_2 as descendant_concept_id,
       b.concept_id_2 as ancestor_concept_id,
       c_des.concept_name as descendant_concept_name,
       c_anc.concept_name as ancestor_concept_name
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

WITH home_visit AS (SELECT ('(?!(morp))home(?!(tr|opath|less|ria|ostasis))|domiciliary') as home_visit),
    outpatient_visit AS (SELECT ('outpatient|out.patient|ambul(?!(ance|ation|ism))|office(?!(r))') as outpatient_visit),
    ambulance_visit AS (SELECT ('ambulance(\W)|transport(?!(er))') AS ambulance_visit),
    emergency_room_visit AS (SELECT ('emerg(?!(ence|omyces))|(\W)ER(\W)') AS emergency_room_visit),
    pharmacy_visit AS (SELECT ('(\W)pharm(\s)|pharmacy') AS pharmacy_visit),
    inpatient_visit AS (SELECT ('inpatient|in.patient|(\W)hosp(?!(ice|h|ira))') AS inpatient_visit),
    telehealth AS (SELECT ('(?!(pla))tele(?!(t|scop|ctasis))|remote|video') AS telehealth),
    other_visit AS (SELECT ('clinic(?!(al))|esrd|(\W)center(\W)|(\W)facility|visit|institution|encounter|rehab|hospice|nurs|school|(\W)unit(\W)') AS other_visit),
    ER_exclusion AS (SELECT ('estrogen') AS ER_exclusion),
    ambulance_exclusion AS (SELECT ('accident|collision|metabol') AS ambulance_exclusion),

flag AS (SELECT DISTINCT c.concept_code,
                c.concept_name,
                c.vocabulary_id,
                b.concept_id as target_concept_id,
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
                                           AND b.concept_id != '581478' THEN 'ambulance visit'
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
AND b.concept_id IN (581476, 9202, 581478, 9203, 581458, 9201, 5083)
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
             AND concept_code NOT IN (SELECT concept_code from review_mapping_to_visit) -- concepts mapped 1-to-many to visit + other domain should not be flagged as incorrect
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

WITH home_visit AS (SELECT ('home visit|home care|home service|home assessment|home therapy|home health aide|(\W)at.home|domiciliary') as home_visit),
    outpatient_visit AS (SELECT ('outpatient(\s)|(\s)out.patient|ambul(?!(ance|ation|ism|ant|ating))') as outpatient_visit),
    ambulance_visit AS (SELECT ('ambulance(\W)') AS ambulance_visit),
    emergency_room_visit AS (SELECT ('emergency department|emergency room|(\s)ER(\s)') AS emergency_room_visit),
    pharmacy_visit AS (SELECT ('(\s)pharmacy') AS pharmacy_visit),
    inpatient_visit AS (SELECT ('inpatient|(\W)hospit') AS inpatient_visit),
    telehealth AS (SELECT ('telehealth|telepractice|telephone|telemedicine|video') AS telehealth),
    other_visit AS (SELECT ('clinic(\s)|esrd|(\W)center(\W)|(\W)facility|(\s)visit(?!(or))|hospice|nursing(\W)unit(\W)') AS other_visit),

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
                b.concept_id as target_concept_id,
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
                                           AND b.concept_id != '581478' THEN 'ambulance visit'
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
AND b.concept_id IN (581476, 9202, 581478, 9203, 581458, 9201, 5083)
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
             AND concept_code NOT IN (SELECT concept_code from review_mapping_to_visit) -- concepts mapped 1-to-many to visit + other domain should not be flagged as incorrect
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
SELECT CASE WHEN string_agg (DISTINCT c2.concept_id::text, '-') IS NULL THEN 'new concept' ELSE 'old concept' END as when_added,
       c.concept_name,
       string_agg (DISTINCT c2.concept_id::text, '-') as concept_id
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
                cc.standard_concept
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
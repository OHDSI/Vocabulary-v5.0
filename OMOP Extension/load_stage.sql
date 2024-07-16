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
*
* Authors: Medical team
* Date: 2020
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=>'OMOP Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'OMOP Extension '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'DEV_OMOPEXT'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--4. Manual synonyms
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--5. Manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--6. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--7. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--8. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--9. Delete ambiguous 'Maps to' mappings
--Not used because there are no mappings to the Drug Domain
/*DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;*/

--10. Assign Domain and Class for concepts with unassigned Domain and Class using the Domain and Class of an ancestor
DO $$
DECLARE
	--v2, AVOF-3703
	DOMAINS_ARRAY TEXT[]:=ARRAY['Condition','Observation','Procedure','Measurement','Device','Meas Value']; --order does matter (the first position has the highest priority, then in descending order)
	CONCEPT_CLASS_ARRAY TEXT[]:=ARRAY['Disorder','Clinical Finding','Event','Observable Entity','Context-dependent','Procedure','Lab Test','Staging / Scales','Substance','Qualifier Value','Social Context','Attribute']; --order does matter (the first position has the highest priority, then in descending order)
BEGIN
	--build the ancestor
	DROP TABLE IF EXISTS omop_ext_ancestor CASCADE;
	CREATE UNLOGGED TABLE omop_ext_ancestor AS
		WITH RECURSIVE hierarchy_concepts (
			ancestor_concept_code,
			ancestor_vocabulary_id,
			descendant_concept_code,
			descendant_vocabulary_id,
			descendant_domain_id,
			descendant_standard_concept,
			descendant_concept_class_id,
			root_ancestor_concept_code,
			root_ancestor_vocabulary_id,
			full_path,
			hierarchy_path,
			hierarchy_depth
			)
		AS (
			SELECT ancestor_concept_code,
				ancestor_vocabulary_id,
				descendant_concept_code,
				descendant_vocabulary_id,
				descendant_domain_id,
				descendant_standard_concept,
				descendant_concept_class_id,
				ancestor_concept_code AS root_ancestor_concept_code,
				ancestor_vocabulary_id AS root_ancestor_vocabulary_id,
				ARRAY [ROW (descendant_concept_code, descendant_vocabulary_id)] AS full_path,
				ARRAY [ancestor_concept_code, descendant_concept_code]::TEXT[] AS hierarchy_path, --w/o casting to TEXT[] we get an error:  recursive query "hierarchy_concepts" column 8 has type character varying(50)[] in non-recursive term but type character varying[] overall
				0 AS hierarchy_depth
			FROM concepts

			UNION ALL

			SELECT c.ancestor_concept_code,
				c.ancestor_vocabulary_id,
				c.descendant_concept_code,
				c.descendant_vocabulary_id,
				c.descendant_domain_id,
				c.descendant_standard_concept,
				c.descendant_concept_class_id,
				hc.root_ancestor_concept_code,
				hc.root_ancestor_vocabulary_id,
				hc.full_path || ROW(c.descendant_concept_code, c.descendant_vocabulary_id) AS full_path,
				hc.hierarchy_path || ARRAY [c.descendant_concept_code]::TEXT[],
				hc.hierarchy_depth + 1
			FROM concepts c
			JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
				AND hc.descendant_vocabulary_id = c.ancestor_vocabulary_id
			WHERE ROW(c.descendant_concept_code, c.descendant_vocabulary_id) <> ALL (full_path)
			),
		concepts
		AS (
			SELECT DISTINCT CASE WHEN crs.relationship_id IN ('Is a','Contained in panel','Precoord pair of') THEN crs.concept_code_1 ELSE crs.concept_code_2 END AS ancestor_concept_code,
				CASE WHEN crs.relationship_id IN ('Is a','Contained in panel','Precoord pair of') THEN crs.vocabulary_id_1 ELSE crs.vocabulary_id_2 END AS ancestor_vocabulary_id,
				CASE WHEN crs.relationship_id IN ('Is a','Contained in panel','Precoord pair of') THEN crs.concept_code_2 ELSE crs.concept_code_1 END AS descendant_concept_code,
				CASE WHEN crs.relationship_id IN ('Is a','Contained in panel','Precoord pair of') THEN crs.vocabulary_id_2 ELSE crs.vocabulary_id_1 END AS descendant_vocabulary_id,
				CASE WHEN crs.relationship_id IN ('Is a','Contained in panel','Precoord pair of') THEN c_info_2.domain_id ELSE c_info_1.domain_id END AS descendant_domain_id,
				CASE WHEN crs.relationship_id IN ('Is a','Contained in panel','Precoord pair of') THEN c_info_2.concept_class_id ELSE c_info_1.concept_class_id END AS descendant_concept_class_id,
				CASE WHEN crs.relationship_id IN ('Is a','Contained in panel','Precoord pair of') THEN c_info_2.standard_concept ELSE c_info_1.standard_concept END AS descendant_standard_concept
			FROM concept_relationship_stage crs
			CROSS JOIN vocabulary_pack.GetActualConceptInfo(crs.concept_code_1, crs.vocabulary_id_1) c_info_1
			CROSS JOIN vocabulary_pack.GetActualConceptInfo(crs.concept_code_2, crs.vocabulary_id_2) c_info_2
			/*WHERE c_info_1.invalid_reason IS NULL
				AND c_info_2.invalid_reason IS NULL*/
				WHERE crs.relationship_id IN (
					'Is a',
					'Subsumes',
					'Precoord pair of',
					'Has precoord pair',
					'Contained in panel',
					'Panel contains'
					)
				AND crs.invalid_reason IS NULL
			)
		SELECT hc.root_ancestor_concept_code AS ancestor_concept_code,
			hc.root_ancestor_vocabulary_id AS ancestor_vocabulary_id,
			hc.descendant_concept_code,
			hc.descendant_vocabulary_id,
			hc.descendant_domain_id,
			hc.descendant_standard_concept,
			hc.descendant_concept_class_id,
			hc.hierarchy_path,
			hc.hierarchy_depth,
			DOMAINS_ARRAY AS approved_domains_array,
			CONCEPT_CLASS_ARRAY AS approved_concept_class_array
		FROM hierarchy_concepts hc
		--filter by OMOP Ext as ancestor_concept_code
		JOIN concept_stage cs ON cs.concept_code = hc.root_ancestor_concept_code
			AND cs.vocabulary_id = hc.root_ancestor_vocabulary_id;

	--ancestor processing, go to the nearest one with a filled domain. if there are several of them, we take those that are S. otherwise, we take all
	CREATE OR REPLACE VIEW v_domains_an AS
	SELECT *
	FROM (
		SELECT s0.*,
			MIN(descendant_standard_concept) OVER (PARTITION BY s0.ancestor_concept_code) AS min_descendant_standard_concept --we can have either S or null in this field, so this query can be interpreted as "do we have S?"
		FROM (
			SELECT ancestor_concept_code,
				ancestor_vocabulary_id,
				descendant_concept_code,
				descendant_vocabulary_id,
				descendant_domain_id,
				NULLIF(descendant_standard_concept, 'C') AS descendant_standard_concept, --'C' as a standard_concept is considered non-standard
				descendant_standard_concept AS orig_descendant_standard_concept, --preserve original standard_concept for debugging
				approved_domains_array,
				hierarchy_path,
				hierarchy_depth,
				MIN(hierarchy_depth) FILTER(WHERE descendant_domain_id IS NOT NULL) OVER (PARTITION BY ancestor_concept_code) min_hierarchy_depth --min depth with non-null domain(s)
			FROM omop_ext_ancestor
			) s0
		WHERE s0.hierarchy_depth = s0.min_hierarchy_depth
		) s1
	WHERE s1.min_descendant_standard_concept IS NOT DISTINCT FROM s1.descendant_standard_concept;--will select only 'S' descendants or all non-standard, if there is no standard

	--same logic for classes
	CREATE OR REPLACE VIEW v_classes_an AS
	SELECT *
	FROM (
		SELECT s0.*,
			MIN(descendant_standard_concept) OVER (PARTITION BY s0.ancestor_concept_code) AS min_descendant_standard_concept --we can have either S or null in this field, so this query can be interpreted as "do we have S?"
		FROM (
			SELECT ancestor_concept_code,
				ancestor_vocabulary_id,
				descendant_concept_code,
				descendant_vocabulary_id,
				descendant_concept_class_id,
				NULLIF(descendant_standard_concept, 'C') AS descendant_standard_concept, --'C' as a standard_concept is considered non-standard
				descendant_standard_concept AS orig_descendant_standard_concept, --preserve original standard_concept for debugging
				approved_concept_class_array,
				hierarchy_path,
				hierarchy_depth,
				MIN(hierarchy_depth) FILTER(WHERE descendant_concept_class_id IS NOT NULL) OVER (PARTITION BY ancestor_concept_code) min_hierarchy_depth --min depth with non-null concept_class(es)
			FROM omop_ext_ancestor
			) s0
		WHERE s0.hierarchy_depth = s0.min_hierarchy_depth
		) s1
	WHERE s1.min_descendant_standard_concept IS NOT DISTINCT FROM s1.descendant_standard_concept; --will select only 'S' descendants or all non-standard, if there is no standard

	--update domain if not defined
	UPDATE concept_stage cs
	SET domain_id = i.domain_id
	FROM (
		SELECT DISTINCT ON (
				cs_int.concept_code,
				cs_int.vocabulary_id
				) cs_int.concept_code,
			cs_int.vocabulary_id,
			CASE
				WHEN an.approved_domains_array @> ARRAY_AGG(an.descendant_domain_id) OVER (
						--collect all domains we have
						PARTITION BY cs_int.concept_code,
						cs_int.vocabulary_id
						)
					THEN an.descendant_domain_id
				ELSE '-1'
				END AS domain_id
		FROM v_domains_an an
		JOIN concept_stage cs_int ON cs_int.concept_code = an.ancestor_concept_code
			AND cs_int.vocabulary_id = an.ancestor_vocabulary_id
			AND cs_int.domain_id IS NULL --for concepts with no domain defined
		LEFT JOIN UNNEST(an.approved_domains_array) WITH ORDINALITY AS domains(domain_id, domain_position) ON domains.domain_id = an.descendant_domain_id
		WHERE an.descendant_domain_id IS NOT NULL --descendant concepts without a domain can be on the same level (depth), we filter such
		ORDER BY cs_int.concept_code,
			cs_int.vocabulary_id,
			domains.domain_position
		) i
	WHERE cs.concept_code = i.concept_code
		AND cs.vocabulary_id = i.vocabulary_id;

	--update concept_class if not defined
	UPDATE concept_stage cs
	SET concept_class_id = i.concept_class_id
	FROM (
		SELECT DISTINCT ON (
				cs_int.concept_code,
				cs_int.vocabulary_id
				) cs_int.concept_code,
			cs_int.vocabulary_id,
			CASE 
				WHEN cs_int.concept_code IN (
						SELECT concept_code_1
						FROM concept_relationship_stage
						WHERE relationship_id = 'Precoord pair of'
						)
					THEN 'Precoordinated pair'
				WHEN cs_int.domain_id = 'Measurement'
					AND an.descendant_concept_class_id = 'Procedure'
					THEN 'Lab Test'
				WHEN an.approved_concept_class_array @> ARRAY_AGG(an.descendant_concept_class_id) OVER (
						--collect all classes we have
						PARTITION BY cs_int.concept_code,
						cs_int.vocabulary_id
						)
					THEN an.descendant_concept_class_id
				ELSE '-1'
				END AS concept_class_id
		FROM v_classes_an an
		JOIN concept_stage cs_int ON cs_int.concept_code = an.ancestor_concept_code
			AND cs_int.vocabulary_id = an.ancestor_vocabulary_id
			AND cs_int.concept_class_id IS NULL --for concepts with no class defined
		LEFT JOIN UNNEST(an.approved_concept_class_array) WITH ORDINALITY AS classes(concept_class_id, class_position) ON classes.concept_class_id = an.descendant_concept_class_id
		WHERE an.descendant_concept_class_id IS NOT NULL --descendant concepts without a class can be on the same level (depth), we filter such
		ORDER BY cs_int.concept_code,
			cs_int.vocabulary_id,
			classes.class_position
		) i
	WHERE cs.concept_code = i.concept_code
		AND cs.vocabulary_id = i.vocabulary_id;
END $$;

--Check for domain/class assignment error
--We are waiting for no errors. If errors exist, you can get these concepts using the check below
DO $$
DECLARE
	z int4;
BEGIN
	SELECT COUNT(*)
	INTO z
	FROM concept_stage
	WHERE '-1' IN (
			domain_id,
			concept_class_id
			);

	IF z > 0 THEN
		RAISE EXCEPTION '% assignment error(s) found', z;
	END IF;
END $$;

--Get specific concept_codes
--We are waiting nothing as the result
--run this if you have domain/class assignment error
--get specific concept_codes for unassigned domains
/*SELECT an.ancestor_concept_code,
	an.ancestor_vocabulary_id,
	an.descendant_concept_code,
	an.descendant_vocabulary_id,
	an.orig_descendant_standard_concept,
	CASE
		WHEN NOT an.approved_domains_array @> ARRAY [an.descendant_domain_id]
			THEN an.descendant_domain_id
		END AS domain_not_in_list,
		an.descendant_domain_id,
	array_to_string(an.hierarchy_path, ' -> ') AS hierarchy_path
FROM v_domains_an an
JOIN concept_stage cs ON cs.concept_code = an.ancestor_concept_code
	AND cs.vocabulary_id = an.ancestor_vocabulary_id
	AND cs.domain_id = '-1'
ORDER BY 1, 2, 3, 4;*/

--same for unassigned classes
/*SELECT an.ancestor_concept_code,
	an.ancestor_vocabulary_id,
	an.descendant_concept_code,
	an.descendant_vocabulary_id,
	an.orig_descendant_standard_concept,
	CASE
		WHEN NOT an.approved_concept_class_array @> ARRAY [an.descendant_concept_class_id]
			THEN an.descendant_concept_class_id
		END AS class_not_in_list,
	array_to_string(an.hierarchy_path, ' -> ') AS hierarchy_path
FROM v_classes_an an
JOIN concept_stage cs ON cs.concept_code = an.ancestor_concept_code
	AND cs.vocabulary_id = an.ancestor_vocabulary_id
	AND cs.concept_class_id = '-1'
ORDER BY 1, 2, 3, 4;*/


--11. Clean up
DROP TABLE omop_ext_ancestor CASCADE;

--12. Workaround to drop the relationships between the vocabularies that are not affected by the SetLatestUpdate
DELETE
FROM concept_relationship_stage crs
USING vocabulary v1,
	vocabulary v2
WHERE v1.vocabulary_id = crs.vocabulary_id_1
	AND v2.vocabulary_id = crs.vocabulary_id_2
	AND v1.latest_update IS NULL
	AND v2.latest_update IS NULL;

--At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script

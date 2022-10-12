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

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=>'OMOP Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'OMOP Extension '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'DEV_OMOPEXT'
);
END $_$;

-- 2. Truncate all working tables
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
	DOMAINS_ARRAY VARCHAR[]:=ARRAY['Condition','Observation','Procedure','Measurement','Device']; --order does matter
	CONCEPT_CLASS_ARRAY VARCHAR[]:=ARRAY['Clinical Finding','Event','Observable Entity','Context-dependent','Procedure','Lab Test','Staging / Scales','Substance','Qualifier Value','Social Context','Attribute']; --order does matter
BEGIN
	--build the concept_ancestor
	DROP TABLE IF EXISTS omop_ext_ancestor;
	CREATE UNLOGGED TABLE omop_ext_ancestor AS
		WITH RECURSIVE hierarchy_concepts (
			ancestor_concept_code,
			ancestor_vocabulary_id,
			descendant_concept_code,
			descendant_vocabulary_id,
			descendant_domain_id,
			descendant_concept_class_id,
			root_ancestor_concept_code,
			root_ancestor_vocabulary_id,
			full_path,
			hierarchy_path
			)
		AS (
			SELECT ancestor_concept_code,
				ancestor_vocabulary_id,
				descendant_concept_code,
				descendant_vocabulary_id,
				descendant_domain_id,
				descendant_concept_class_id,
				ancestor_concept_code AS root_ancestor_concept_code,
				ancestor_vocabulary_id AS root_ancestor_vocabulary_id,
				ARRAY [ROW (descendant_concept_code, descendant_vocabulary_id)] AS full_path,
				--ARRAY [ancestor_concept_code||' ('||ancestor_vocabulary_id||')', descendant_concept_code||' ('||descendant_vocabulary_id||')'] AS hierarchy_path
				ARRAY [ancestor_concept_code, descendant_concept_code]::TEXT[] AS hierarchy_path --w/o casting to TEXT[] we get an error:  recursive query "hierarchy_concepts" column 8 has type character varying(50)[] in non-recursive term but type character varying[] overall
			FROM concepts

			UNION ALL

			SELECT c.ancestor_concept_code,
				c.ancestor_vocabulary_id,
				c.descendant_concept_code,
				c.descendant_vocabulary_id,
				c.descendant_domain_id,
				c.descendant_concept_class_id,
				root_ancestor_concept_code,
				root_ancestor_vocabulary_id,
				hc.full_path || ROW(c.descendant_concept_code, c.descendant_vocabulary_id) AS full_path,
				--hc.hierarchy_path || ARRAY [c.descendant_concept_code||' ('||c.descendant_vocabulary_id||')']
				hc.hierarchy_path || ARRAY [c.descendant_concept_code]::TEXT[]
			FROM concepts c
			JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
				AND hc.descendant_vocabulary_id = c.ancestor_vocabulary_id
			WHERE ROW(c.descendant_concept_code, c.descendant_vocabulary_id) <> ALL (full_path)
			),
		concepts
		AS (
			SELECT DISTINCT CASE WHEN crs.relationship_id = 'Is a' THEN crs.concept_code_1 ELSE crs.concept_code_2 END AS ancestor_concept_code,
				CASE WHEN crs.relationship_id = 'Is a' THEN crs.vocabulary_id_1 ELSE crs.vocabulary_id_2 END AS ancestor_vocabulary_id,
				CASE WHEN crs.relationship_id = 'Is a' THEN crs.concept_code_2 ELSE crs.concept_code_1 END AS descendant_concept_code,
				CASE WHEN crs.relationship_id = 'Is a' THEN crs.vocabulary_id_2 ELSE crs.vocabulary_id_1 END AS descendant_vocabulary_id,
				CASE WHEN crs.relationship_id = 'Is a' THEN c_info_2.domain_id ELSE c_info_1.domain_id END AS descendant_domain_id,
				CASE WHEN crs.relationship_id = 'Is a' THEN c_info_2.concept_class_id ELSE c_info_1.concept_class_id END AS descendant_concept_class_id
			FROM concept_relationship_stage crs
			CROSS JOIN vocabulary_pack.GetActualConceptInfo(crs.concept_code_1, crs.vocabulary_id_1) c_info_1
			CROSS JOIN vocabulary_pack.GetActualConceptInfo(crs.concept_code_2, crs.vocabulary_id_2) c_info_2
			WHERE c_info_1.invalid_reason IS NULL
				AND c_info_1.standard_concept = 'S'
				AND c_info_2.invalid_reason IS NULL
				AND c_info_2.standard_concept = 'S'
				AND crs.relationship_id IN (
					'Is a',
					'Subsumes'
					)
				AND crs.invalid_reason IS NULL
			)
		SELECT hc.root_ancestor_concept_code AS ancestor_concept_code,
			hc.root_ancestor_vocabulary_id AS ancestor_vocabulary_id,
			hc.descendant_concept_code,
			hc.descendant_vocabulary_id,
			hc.descendant_domain_id,
			hc.descendant_concept_class_id,
			hc.hierarchy_path,
			DOMAINS_ARRAY as approved_domains_array,
			CONCEPT_CLASS_ARRAY as approved_concept_class_array
		FROM hierarchy_concepts hc
		--filter by OMOP Ext as ancestor_concept_code
		JOIN concept_stage cs ON cs.concept_code = hc.root_ancestor_concept_code
			AND cs.vocabulary_id = hc.root_ancestor_vocabulary_id;

	--update domain if not defined
	UPDATE concept_stage cs
	SET domain_id = i.domain_id
	FROM (
		SELECT DISTINCT ON (
				cs_int.concept_code,
				cs_int.vocabulary_id
				) cs_int.concept_code,
			cs_int.vocabulary_id,
			CASE WHEN an.approved_domains_array @> ARRAY_AGG(an.descendant_domain_id) OVER (
						--collect all domains we have
						PARTITION BY cs_int.concept_code,
						cs_int.vocabulary_id
						) THEN an.descendant_domain_id ELSE '-1' END AS domain_id
		FROM omop_ext_ancestor an
		JOIN concept_stage cs_int ON cs_int.concept_code = an.ancestor_concept_code
			AND cs_int.vocabulary_id = an.ancestor_vocabulary_id
			AND cs_int.domain_id IS NULL
		LEFT JOIN UNNEST(an.approved_domains_array) WITH ORDINALITY AS domains(domain_id, domain_position) ON domains.domain_id = an.descendant_domain_id
		WHERE an.descendant_domain_id IS NOT NULL
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
			CASE WHEN an.approved_concept_class_array @> ARRAY_AGG(an.descendant_concept_class_id) OVER (
						--collect all classes we have
						PARTITION BY cs_int.concept_code,
						cs_int.vocabulary_id
						) THEN an.descendant_concept_class_id ELSE '-1' END AS concept_class_id
		FROM omop_ext_ancestor an
		JOIN concept_stage cs_int ON cs_int.concept_code = an.ancestor_concept_code
			AND cs_int.vocabulary_id = an.ancestor_vocabulary_id
			AND cs_int.concept_class_id IS NULL
		LEFT JOIN UNNEST(an.approved_concept_class_array) WITH ORDINALITY AS classes(concept_class_id, class_position) ON classes.concept_class_id = an.descendant_concept_class_id
		WHERE an.descendant_concept_class_id IS NOT NULL
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
SELECT an.ancestor_concept_code,
	an.ancestor_vocabulary_id,
	an.descendant_concept_code,
	an.descendant_vocabulary_id,
	CASE WHEN NOT an.approved_domains_array @> ARRAY [an.descendant_domain_id]
			AND cs.domain_id = '-1' THEN an.descendant_domain_id END AS domain_not_in_list,
	CASE WHEN NOT an.approved_concept_class_array @> ARRAY [an.descendant_concept_class_id]
			AND cs.concept_class_id = '-1' THEN an.descendant_concept_class_id END AS class_not_in_list,
	array_to_string(an.hierarchy_path, ' -> ') AS hierarchy_path
FROM omop_ext_ancestor an
JOIN concept_stage cs ON cs.concept_code = an.ancestor_concept_code
	AND cs.vocabulary_id = an.ancestor_vocabulary_id
	AND '-1' IN (
		cs.domain_id,
		cs.concept_class_id
		)
ORDER BY 1, 2, 3, 4;

--Clean up
DROP TABLE omop_ext_ancestor;

--12. Workaround to drop the relationships between the vocabularies that are not affected by the SetLatestUpdate
DELETE
FROM concept_relationship_stage
WHERE vocabulary_id_1 = vocabulary_id_2
    AND vocabulary_id_1 IN ('SNOMED')
;

--13. "History of" / replacement mapping fix

--At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
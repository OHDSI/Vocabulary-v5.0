CREATE OR REPLACE FUNCTION vocabulary_pack.ShowMappingChains (
	pAncestorCode TEXT DEFAULT NULL,
	pAncestorVocabularyID TEXT DEFAULT NULL
)
RETURNS TABLE (
	concept_code_1 VARCHAR,
	vocabulary_id_1 VARCHAR,
	concept_name_1 VARCHAR,
	domain_id_1 VARCHAR,
	concept_class_id_1 VARCHAR,
	last_relationship_id VARCHAR,
	concept_code_2 VARCHAR,
	vocabulary_id_2 VARCHAR,
	concept_name_2 VARCHAR,
	domain_id_2 VARCHAR,
	concept_class_id_2 VARCHAR,
	value_count_group INT4,
	mapsto_count_group INT4,
	value_count_row INT4,
	mapsto_count_row INT4,
	max_chain_length INT4,
	chain_count INT4,
	hierarchy_path TEXT
)
AS
$BODY$
	/*
	The function shows chains of mappings and replacement relationships. It is intended to be part of the debug process for each vocabulary release.
	By default, the function returns a set of chains for every Maps to / Maps to Value / replacement relationship, which may require a lot of time and computational resources. Therefore, it may be better to create a table from the results of the function.
	It also accepts a single ancestor concept and calculates chains for this concept exclusively (less time and resources required).
	NB! The function has the following limitations:
		1. It uses tables in local schema and concept_relationship in devv5 schema to be able to calculate the path. Concept_relationship in local schema contains already changed relationships and therefore can't be used for path calculations.
		2. Due to the way the function works, the actual chains constructed may differ from the chains shown. This is due to the fact that the function takes into account replacement relationships, but in reality they will not necessarily be covered by 'Maps to'

	The returned fields are (except for self-explanatory):
		last_relationship_id - the last relationship_id in the chain
		value_count_group - number of 'Maps to value' relationships per group (concept_code_1)
		mapsto_count_group - number of 'Maps to' relationships per group (concept_code_1)
		value_count_row - number of 'Maps to value' relationships per chain
		mapsto_count_row - number of 'Maps to' relationships per chain
		max_chain_length - maximum chain length within a group
		chain_count - number of chains per group (concept_code_1)
	Also in the 'hierarchy_path' column information is displayed about where the relationship came from (from manual tables [M] or from basic tables [B]), e.g. 'A' 'Concept replaced by [B]' 'B'

	Examples:
	--build all chains
	[CREATE UNLOGGED TABLE mapping_chains AS] SELECT * FROM vocabulary_pack.ShowMappingChains();

	--show chains for the specified concept
	SELECT * FROM vocabulary_pack.ShowMappingChains(pAncestorCode=>'10033711000001107', pAncestorVocabularyID=>'SNOMED');
	*/
BEGIN
	CREATE TEMP TABLE upgraded_concepts$ AS
	WITH upgraded_concepts_prepare AS (
		SELECT crm.concept_code_1,
			crm.vocabulary_id_1,
			crm.concept_code_2,
			crm.vocabulary_id_2,
			crm.relationship_id,
			CASE 
				WHEN crm.relationship_id = 'Concept replaced by'
					THEN 1
				WHEN crm.relationship_id = 'Concept same_as to'
					THEN 2
				WHEN crm.relationship_id = 'Concept alt_to to'
					THEN 3
				WHEN crm.relationship_id = 'Concept was_a to'
					THEN 5
				WHEN crm.relationship_id IN ('Maps to', 'Maps to value')
					THEN 6
				END AS rel_id,
			'[M]' AS rel_source
		FROM concept_relationship_manual crm
		WHERE crm.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept was_a to',
					'Maps to',
					'Maps to value'
					)
			AND crm.invalid_reason IS NULL
			AND NOT (
				--exclude mappings to self
				crm.concept_code_1 = crm.concept_code_2
				AND crm.vocabulary_id_1 = crm.vocabulary_id_2
				)
		
		UNION ALL
		
		--some concepts might be in 'base' tables
		SELECT c1.concept_code,
			c1.vocabulary_id,
			c2.concept_code,
			c2.vocabulary_id,
			r.relationship_id,
			CASE 
				WHEN r.relationship_id = 'Concept replaced by'
					THEN 1
				WHEN r.relationship_id = 'Concept same_as to'
					THEN 2
				WHEN r.relationship_id = 'Concept alt_to to'
					THEN 3
				WHEN r.relationship_id = 'Concept was_a to'
					THEN 5
				WHEN r.relationship_id IN ('Maps to', 'Maps to value')
					THEN 6
				END AS rel_id,
			'[B]' AS rel_source
		FROM devv5.concept_relationship r
		JOIN concept c1 ON c1.concept_id = r.concept_id_1
		JOIN concept c2 ON c2.concept_id = r.concept_id_2
		LEFT JOIN concept_relationship_manual crm ON crm.concept_code_1 = c1.concept_code
			AND crm.vocabulary_id_1 = c1.vocabulary_id
			AND crm.relationship_id = r.relationship_id
			AND crm.invalid_reason IS NULL
		WHERE r.concept_id_1 <> r.concept_id_2
			AND crm.concept_code_1 IS NULL --we need only fresh 'Maps to/value' which contains in stage tables (per each concept_code_1), but if we doesn't have them - take from base tables
			AND r.invalid_reason IS NULL
			AND r.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept was_a to',
					'Maps to',
					'Maps to value'
					)
			--don't use already deprecated relationships
			AND NOT EXISTS (
				SELECT 1
				FROM concept_relationship_manual crm
				WHERE crm.concept_code_1 = c1.concept_code
					AND crm.vocabulary_id_1 = c1.vocabulary_id
					AND crm.concept_code_2 = c2.concept_code
					AND crm.vocabulary_id_2 = c2.vocabulary_id
					AND crm.relationship_id = r.relationship_id
					AND crm.invalid_reason IS NOT NULL
				)
		),
	upgraded_concepts AS (
		(
			SELECT DISTINCT ON (
					ucp.concept_code_1,
					ucp.vocabulary_id_1
					) ucp.*
			FROM upgraded_concepts_prepare ucp
			WHERE ucp.rel_id <> 6 --take replacement relationship according to priority
			ORDER BY ucp.concept_code_1,
				ucp.vocabulary_id_1,
				ucp.rel_id
		)

		UNION ALL

		SELECT ucp.*
		FROM upgraded_concepts_prepare ucp
		WHERE ucp.rel_id = 6 --Maps to/value
		)
	SELECT * FROM upgraded_concepts;

	--CREATE INDEX idx_upgraded_concepts$ ON upgraded_concepts$ (concept_code_1,vocabulary_id_1) INCLUDE (concept_code_2,vocabulary_id_2,relationship_id,rel_source) WITH (FILLFACTOR=100);
	--ANALYZE upgraded_concepts$;

	RETURN QUERY
	WITH RECURSIVE rec AS (
		SELECT uc.concept_code_1,
			uc.vocabulary_id_1,
			uc.concept_code_2,
			uc.vocabulary_id_2,
			uc.concept_code_1 AS root_concept_code_1,
			uc.vocabulary_id_1 AS root_vocabulary_id_1,
			ARRAY [ROW (uc.concept_code_2, uc.vocabulary_id_2)] AS full_path,
			CASE WHEN uc.relationship_id='Maps to value' THEN 1 ELSE 0 END AS value_count,
			CASE WHEN uc.relationship_id='Maps to' THEN 1 ELSE 0 END AS mapsto_count,
			uc.relationship_id AS last_relationship_id,
			1 AS chain_length,
			uc.concept_code_1||' ('||uc.vocabulary_id_1||' / '||c1.concept_name||') '''||uc.relationship_id||' '||uc.rel_source||''' '||uc.concept_code_2||' ('||uc.vocabulary_id_2||' / '||c2.concept_name||')' AS hierarchy_path
		FROM upgraded_concepts$ uc
		LEFT JOIN concept c1 ON c1.concept_code = uc.concept_code_1
			AND c1.vocabulary_id = uc.vocabulary_id_1
		LEFT JOIN concept c2 ON c2.concept_code = uc.concept_code_2
			AND c2.vocabulary_id = uc.vocabulary_id_2
		WHERE uc.concept_code_1 = COALESCE(pAncestorCode, uc.concept_code_1)
			AND uc.vocabulary_id_1 = COALESCE(pAncestorVocabularyID, uc.vocabulary_id_1)
		
		UNION ALL
		
		SELECT uc.concept_code_1,
			uc.vocabulary_id_1,
			uc.concept_code_2,
			uc.vocabulary_id_2,
			r.root_concept_code_1,
			r.root_vocabulary_id_1,
			r.full_path || ROW (uc.concept_code_2, uc.vocabulary_id_2),
			r.value_count+(CASE WHEN relationship_id='Maps to value' THEN 1 ELSE 0 END) AS value_count,
			r.mapsto_count+(CASE WHEN relationship_id='Maps to' THEN 1 ELSE 0 END) AS mapsto_count,
			uc.relationship_id AS last_relationship_id,
			r.chain_length + 1 AS chain_length,
			r.hierarchy_path||' '''||uc.relationship_id||' '||uc.rel_source||''' '||uc.concept_code_2||' ('||uc.vocabulary_id_2||' / '||c2.concept_name||')' AS hierarchy_path
		FROM upgraded_concepts$ uc
		JOIN rec r ON r.concept_code_2 = uc.concept_code_1
			AND r.vocabulary_id_2 = uc.vocabulary_id_1
		LEFT JOIN concept c2 ON c2.concept_code=uc.concept_code_2
			AND c2.vocabulary_id=uc.vocabulary_id_2
		WHERE ROW (uc.concept_code_2, uc.vocabulary_id_2) <> ALL (full_path) --excluding loops
		)
	SELECT r.root_concept_code_1,
		r.root_vocabulary_id_1,
		c1.concept_name AS concept_name_1,
		c1.domain_id AS domain_id_1,
		c1.concept_class_id AS concept_class_id_1,
		r.last_relationship_id,
		r.concept_code_2,
		r.vocabulary_id_2,
		c2.concept_name AS concept_name_2,
		c2.domain_id AS domain_id_2,
		c2.concept_class_id AS concept_class_id_2,
		SUM(r.value_count) OVER (PARTITION BY r.root_concept_code_1,r.root_vocabulary_id_1)::INT4 AS value_count_group,
		SUM(r.mapsto_count) OVER (PARTITION BY r.root_concept_code_1,r.root_vocabulary_id_1)::INT4 AS mapsto_count_group,
		r.value_count AS value_count_row,
		r.mapsto_count AS mapsto_count_row,
		MAX(r.chain_length) OVER (PARTITION BY r.root_concept_code_1,r.root_vocabulary_id_1) AS max_chain_length, 
		COUNT(*) OVER (PARTITION BY r.root_concept_code_1,r.root_vocabulary_id_1)::INT4 AS chain_count,
		r.hierarchy_path
	FROM rec r
	LEFT JOIN concept c1 ON c1.concept_code = r.root_concept_code_1
		AND c1.vocabulary_id = r.root_vocabulary_id_1
	LEFT JOIN concept c2 ON c2.concept_code = r.concept_code_2
		AND c2.vocabulary_id = r.vocabulary_id_2
	WHERE NOT EXISTS (
			/*same as oracle's CONNECT_BY_ISLEAF*/
			SELECT 1
			FROM rec r_int
			WHERE r_int.concept_code_1 = r.concept_code_2
				AND r_int.vocabulary_id_1 = r.vocabulary_id_2
			)
	--check if target concept is valid and standard (or a new concept that is not in the concept table yet)
	AND (
			(
				c2.concept_code IS NOT NULL
				AND c2.standard_concept = 'S'
				)
			OR c2.concept_code IS NULL
			)
		/*AND NOT EXISTS (
			--relationship 'Maps to value' must not duplicate an existing 'Maps to'
			SELECT 1
			FROM devv5.concept_relationship cr
			join concept c1 on c1.concept_id=cr.concept_id_1 and c1.concept_code=r.root_concept_code_1 and c1.vocabulary_id=r.root_vocabulary_id_1
			join concept c2 on c2.concept_id=cr.concept_id_2 and c2.concept_code=r.concept_code_2 and c2.vocabulary_id=r.vocabulary_id_2
			WHERE cr.relationship_id = 'Maps to'
				AND cr.invalid_reason IS NULL
			)*/;

	DROP TABLE upgraded_concepts$;
END;
$BODY$
LANGUAGE 'plpgsql';
CREATE OR REPLACE FUNCTION vocabulary_pack.AddFreshMAPSTO (pVocabulary VARCHAR DEFAULT NULL)
RETURNS void AS
$BODY$
/*
The function works with chains like A 'Maps to' B 'Maps to' C ... 'Maps to' Z, adding a new mapping A 'Maps to' Z to concept_relationship_stage
For example, there was a mapping A 'Maps to' B. Then another mapping B 'Maps to' C was added. The function will build a new mapping A 'Maps to' C.
The number of links in the chain is unlimited.
The function will also add 'Maps to' for all replacement mappings ('Concept replaced by', 'Concept same_as to', etc.), the number of links here is also unlimited.
The following rules apply:
1. The chain should only consist of undeprecated mappings (invalid_reason is null)
2. The latest target concept must be alive (invalid_reason is null) and have standard_concept = 'S'. If there is such a concept in concept_stage (cs) and in concept, then cs will take precedence (because the concept table is ultimately formed from the cs table)
For example, there is a mapping A 'Maps to' B, while concept B is present in cs (as deprecated) and in concept (as alive), then such a mapping will not be considered by the function
3. Only 'Maps to' are taken from concept_relationship. This means that the function does not take replacement mappings from this table, because they are already duplicated by the corresponding 'Maps to' (if applicable)
4. If 'Maps to' mapping from the same source concept is present in both concept_relationship_stage (crs) and concept_relationship (cr), then mapping from crs will take precedence
For example, cr has a mapping A 'Maps to' B, and crs has a mapping A 'Maps to' B1. In this case, the mapping to concept B will be ignored (and as a result generic_update will deprecate the old mapping). This allows you to change the mappings if necessary, if a more suitable target appears, or deprecate the wrong one.
5. If the final mapping that the function built is already in crs, then it will be updated (invalid_reason will be set to NULL, valid_end_date will be 20991231)
6. If the concept has several different replacement mappings at the same time, for example, 'Concept replaced by' and 'Concept was_a to', then one is taken in the following priority:
Concept replaced by
Concept same_as to
Concept alt_to to
Concept was_a to

NB:
The fact of having multiple mappings from one concept is handled correctly, each chain separately
For example, if there are mappings in crs
A 'Maps to' A1 'Maps to' A2
A 'Maps to' B1 'Maps to' B2
then both chains will be processed independently and the output will be two mappings: A 'Maps to' A2 and A 'Maps to' B2 (of course, in compliance with the above rules)

Changes:
#20230116
1. Previously, the function extended relationships only for those concepts that were present in the concept_relationship_stage in the concept_code_1 field.
This led to the fact that the "old" relationships were not eventually processed for possible errors (for example, in DeleteAmbiguousMAPSTO). Now the function takes these relationships from the base tables in any case, even if the updated vocabulary is in vocabulary_id_2.
2. In some cases, the function could put a relationship where both fields vocabulary_id_1 and vocabulary_id_2 do not match SetLatestUpdate. Now this behavior has been corrected, one of the fields must be one of the updated vocabularies.
3. As a consequence of the operation of p1 and p2, a new parameter has been added (pVocabulary). It can be useful if several vocabularies are being updated, and we want to receive relationships sequentially for each vocabulary separately. 
For example, this is relevant for NDC/SPL, since the first time the function is called for SPL and at this stage we do not need relationships for NDC yet.
*/
BEGIN
	ANALYZE concept_relationship_stage;

	CREATE TEMP TABLE new_relationships ON COMMIT DROP AS
		WITH RECURSIVE rec AS (
				SELECT u.concept_code_1,
					u.vocabulary_id_1,
					u.concept_code_2,
					u.vocabulary_id_2,
					u.concept_code_1 AS root_concept_code_1,
					u.vocabulary_id_1 AS root_vocabulary_id_1,
					ARRAY [ ROW (u.concept_code_2, u.vocabulary_id_2) ] AS full_path
				FROM upgraded_concepts u
				
				UNION ALL
				
				SELECT uc.concept_code_1,
					uc.vocabulary_id_1,
					uc.concept_code_2,
					uc.vocabulary_id_2,
					r.root_concept_code_1,
					r.root_vocabulary_id_1,
					r.full_path || ROW(uc.concept_code_2, uc.vocabulary_id_2)
				FROM upgraded_concepts uc
				JOIN rec r ON r.concept_code_2 = uc.concept_code_1
					AND r.vocabulary_id_2 = uc.vocabulary_id_1
				WHERE ROW(uc.concept_code_2, uc.vocabulary_id_2) <> ALL (full_path) --excluding loops
				),
			upgraded_concepts AS (
				SELECT *
				FROM (
					SELECT DISTINCT concept_code_1,
						CASE 
							WHEN rel_id <> 6
								THEN FIRST_VALUE(concept_code_2) OVER (
										PARTITION BY concept_code_1 ORDER BY rel_id 
										)
							ELSE
								--we need only fresh 'Maps to' which contains in stage-tables (per each concept_code_1), but if we doesn't have them - take from base tables
								--fixed bug AVOF-307/AVOF-308
								CASE 
									WHEN in_base_tables = MIN(in_base_tables) OVER (PARTITION BY concept_code_1)
										THEN concept_code_2
									ELSE NULL
									END
							END AS concept_code_2,
						vocabulary_id_1,
						vocabulary_id_2
					FROM (
						SELECT crs.concept_code_1,
							crs.concept_code_2,
							crs.vocabulary_id_1,
							crs.vocabulary_id_2,
							--if concepts have more than one relationship_id, then we take only the one with following precedence
							CASE 
								WHEN crs.relationship_id = 'Concept replaced by'
									THEN 1
								WHEN crs.relationship_id = 'Concept same_as to'
									THEN 2
								WHEN crs.relationship_id = 'Concept alt_to to'
									THEN 3
								WHEN crs.relationship_id = 'Concept was_a to'
									THEN 5
								WHEN crs.relationship_id = 'Maps to'
									THEN 6
								END AS rel_id,
							0 AS in_base_tables
						FROM concept_relationship_stage crs
						WHERE crs.relationship_id IN (
								'Concept replaced by',
								'Concept same_as to',
								'Concept alt_to to',
								'Concept was_a to',
								'Maps to'
								)
							AND crs.invalid_reason IS NULL
							AND NOT (
								--exclude mappings to self
								crs.concept_code_1 = crs.concept_code_2
								AND crs.vocabulary_id_1 = crs.vocabulary_id_2
								)
						
						UNION ALL
						
						--some concepts might be in 'base' tables
						SELECT c1.concept_code,
							c2.concept_code,
							c1.vocabulary_id,
							c2.vocabulary_id,
							6 AS rel_id,
							1 AS in_base_tables
						FROM concept c1,
							concept c2,
							concept_relationship r
						WHERE c1.concept_id = r.concept_id_1
							AND c2.concept_id = r.concept_id_2
							AND r.concept_id_1 <> r.concept_id_2
							AND r.invalid_reason IS NULL
							AND r.relationship_id = 'Maps to'
							--don't use already deprecated relationships
							AND NOT EXISTS (
								SELECT 1
								FROM concept_relationship_stage crs_int
								WHERE crs_int.concept_code_1 = c1.concept_code
									AND crs_int.vocabulary_id_1 = c1.vocabulary_id
									AND crs_int.concept_code_2 = c2.concept_code
									AND crs_int.vocabulary_id_2 = c2.vocabulary_id
									AND crs_int.relationship_id = r.relationship_id
									AND crs_int.invalid_reason IS NOT NULL
								)
						) AS s1
					) AS s2
				WHERE concept_code_2 IS NOT NULL
				)
		SELECT s3.root_concept_code_1,
			s3.concept_code_2,
			s3.root_vocabulary_id_1,
			s3.vocabulary_id_2,
			'Maps to' AS relationship_id,
			GREATEST(s3.lu_1, s3.lu_2) AS valid_start_date,
			TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
			NULL AS invalid_reason
		FROM (
			SELECT DISTINCT r.root_concept_code_1,
				r.root_vocabulary_id_1,
				r.concept_code_2,
				r.vocabulary_id_2,
				v1.latest_update AS lu_1,
				v2.latest_update AS lu_2
			FROM rec r
			JOIN vocabulary v1 ON v1.vocabulary_id = r.root_vocabulary_id_1
			JOIN vocabulary v2 ON v2.vocabulary_id = r.vocabulary_id_2
			WHERE COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL
				AND COALESCE(pVocabulary, r.root_vocabulary_id_1) IN (
					r.root_vocabulary_id_1,
					r.vocabulary_id_2
					)
				AND NOT EXISTS (
					/*same as oracle's CONNECT_BY_ISLEAF*/
					SELECT 1
					FROM rec r_int
					WHERE r_int.concept_code_1 = r.concept_code_2
						AND r_int.vocabulary_id_1 = r.vocabulary_id_2
					)
			) AS s3
		WHERE EXISTS (--check if target concept is valid and standard (first in concept_stage, then concept)
		SELECT 1
		FROM vocabulary_pack.GetActualConceptInfo(s3.concept_code_2, s3.vocabulary_id_2) a
		WHERE a.standard_concept = 'S'
			AND a.invalid_reason IS NULL);

	--add new records, update existing
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
	SELECT nr.*
	FROM new_relationships nr
	ON CONFLICT ON CONSTRAINT idx_pk_crs
	DO UPDATE
	SET invalid_reason = NULL,
		valid_end_date = TO_DATE('20991231', 'yyyymmdd')
	WHERE ROW (crs.valid_start_date, crs.valid_end_date, crs.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.valid_start_date, excluded.valid_end_date, excluded.invalid_reason);
END;
$BODY$
LANGUAGE 'plpgsql';
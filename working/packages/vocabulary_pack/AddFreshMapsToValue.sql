CREATE OR REPLACE FUNCTION vocabulary_pack.AddFreshMapsToValue (pVocabulary VARCHAR DEFAULT NULL)
RETURNS VOID AS
$BODY$
/*
 Adds mapping from deprecated to fresh concepts for 'Maps to value'
 Works similar to AddFreshMAPSTO function, but with differences:
 1. The function doesn't automatically add the 'Maps to value' for replacement relationships (they are not used at all)
 2. The function can use both 'Maps to value' and 'Maps to' relationships
 For example, if we have A 'Maps to' B 'Maps to value' C, then A 'Maps to value' C will be created
 
 Also, if there is already 'Maps to' between the target concepts, then 'Maps to value' will not be created
 For example, if we have A 'Maps to' B 'Maps to value' C, and A 'Maps to' C, then A 'Maps to value' C will NOT be created
 
 NOTE: for the function to work correctly, it must be launched after AddFreshMAPSTO
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
					ARRAY [ROW (u.concept_code_2, u.vocabulary_id_2)] AS full_path
				FROM upgraded_concepts u
				
				UNION ALL
				
				SELECT uc.concept_code_1,
					uc.vocabulary_id_1,
					uc.concept_code_2,
					uc.vocabulary_id_2,
					r.root_concept_code_1,
					r.root_vocabulary_id_1,
					r.full_path || ROW (uc.concept_code_2, uc.vocabulary_id_2)
				FROM upgraded_concepts uc
				JOIN rec r ON r.concept_code_2 = uc.concept_code_1
					AND r.vocabulary_id_2 = uc.vocabulary_id_1
				WHERE ROW (uc.concept_code_2, uc.vocabulary_id_2) <> ALL (full_path) --excluding loops
				),
			upgraded_concepts AS (
				SELECT *
				FROM (
					SELECT DISTINCT s1.concept_code_1,
						CASE 
							WHEN s1.in_base_tables = MIN(s1.in_base_tables) OVER (PARTITION BY s1.concept_code_1)
								THEN s1.concept_code_2
							END AS concept_code_2,
						s1.vocabulary_id_1,
						s1.vocabulary_id_2
					FROM (
						SELECT crs.concept_code_1,
							crs.concept_code_2,
							crs.vocabulary_id_1,
							crs.vocabulary_id_2,
							0 AS in_base_tables
						FROM concept_relationship_stage crs
						WHERE crs.relationship_id IN (
								'Maps to',
								'Maps to value'
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
							1 AS in_base_tables
						FROM concept_relationship r
						JOIN concept c1 ON c1.concept_id = r.concept_id_1
						JOIN concept c2 ON c2.concept_id = r.concept_id_2
						WHERE r.invalid_reason IS NULL
							AND r.concept_id_1 <> r.concept_id_2 --exclude mappings to self
							AND r.relationship_id IN (
								'Maps to',
								'Maps to value'
								)
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
			'Maps to value' AS relationship_id,
			GREATEST(s3.lu_1, s3.lu_2) AS valid_start_date,
			TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
			NULL AS invalid_reason
		FROM (
			SELECT DISTINCT root_concept_code_1,
				root_vocabulary_id_1,
				concept_code_2,
				vocabulary_id_2,
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
		WHERE EXISTS (
				--check if target concept is valid and standard (first in concept_stage, then concept)
				SELECT 1
				FROM vocabulary_pack.GetActualConceptInfo(s3.concept_code_2, s3.vocabulary_id_2) a
				WHERE a.standard_concept = 'S'
					AND a.invalid_reason IS NULL
				)
			AND NOT EXISTS (
				--relationship 'Maps to value' must not duplicate an existing 'Maps to'
				SELECT 1
				FROM concept_relationship_stage crs_int
				WHERE crs_int.concept_code_1 = s3.root_concept_code_1
					AND crs_int.vocabulary_id_1 = s3.root_vocabulary_id_1
					AND crs_int.concept_code_2 = s3.concept_code_2
					AND crs_int.vocabulary_id_2 = s3.vocabulary_id_2
					AND crs_int.relationship_id = 'Maps to'
					AND crs_int.invalid_reason IS NULL
				);
		
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

	--if the function is executed in a transaction, then by the time of the next call the temp table will exist
	DROP TABLE new_relationships;
END;
$BODY$
LANGUAGE 'plpgsql';
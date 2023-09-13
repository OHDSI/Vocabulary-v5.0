CREATE OR REPLACE FUNCTION vocabulary_pack.DeprecateWrongMapsTo ()
RETURNS VOID AS
$BODY$
	/*
	 Deprecates 'Maps to' mappings to deprecated ('D') and upgraded ('U') concepts
	*/
BEGIN
	UPDATE concept_relationship_stage crs
	SET valid_end_date = GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
						)
				)),
		invalid_reason = 'D'
	WHERE crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL
		AND EXISTS (
				--check if target concept is non-valid (first in concept_stage, then concept)
				SELECT 1
				FROM vocabulary_pack.GetActualConceptInfo(crs.concept_code_2, crs.vocabulary_id_2) a
				WHERE a.invalid_reason IN (
						'U',
						'D'
						)
				);
END;
$BODY$
LANGUAGE 'plpgsql';
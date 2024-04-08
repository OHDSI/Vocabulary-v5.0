CREATE OR REPLACE FUNCTION devv5.GetPrimaryRelationshipID (pRelationship_id TEXT) 
RETURNS TEXT AS
$BODY$
	/*
	Returns the 'correct' direction of mappings for the CheckManualRelationships function
	This prevents situations when medicals put the same relationship between the same concepts, only the first one put "direct" and the second - "reverse"
	*/
	WITH replacements
	AS (
			SELECT * FROM (VALUES 
				('Mapped from', 'Maps to'),
				('Subsumes', 'Is a'),
				('LOINC - CPT4 eq', 'CPT4 - LOINC eq'),
				('Schema to Value', 'Value to Schema'),
				('Answer of', 'Has Answer'),
				('Proc Schema to ICDO', 'ICDO to Proc Schema'),
				('Schema to Variable', 'Variable to Schema'),
				('Has precoord pair', 'Precoord pair of'),
				('Panel contains', 'Contained in panel'),
				('Schema to ICDO', 'ICDO to Schema'),
				('SNOMED - ATC eq', 'ATC - SNOMED eq'),
				('Answer of (PPI)', 'Has answer (PPI)')
			) AS r(incorrect_direction, correct_direction)
		)
	SELECT COALESCE(r.correct_direction, r1.relationship_id)
	FROM relationship r1
	JOIN relationship r2 ON r2.relationship_id = r1.reverse_relationship_id
		AND r2.relationship_concept_id > r1.relationship_concept_id
	LEFT JOIN replacements r ON r.incorrect_direction = r1.relationship_id
	WHERE pRelationship_id IN (
			r1.relationship_id,
			r1.reverse_relationship_id
			);
$BODY$
LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
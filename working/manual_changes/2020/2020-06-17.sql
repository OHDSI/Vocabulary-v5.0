--remove 'LOINC' from 'Has Answer' and 'Answer of' relationships [AVOF-2614]
UPDATE relationship
SET relationship_name = 'Has Answer'
WHERE relationship_id = 'Has Answer';

UPDATE relationship
SET relationship_name = 'Answer of'
WHERE relationship_id = 'Answer of';

UPDATE concept
SET concept_name = REPLACE(concept_name, ' (LOINC)', '')
WHERE concept_id IN (
		45754684, -- 'Answer of'
		45754683 -- 'Has Answer'
		);
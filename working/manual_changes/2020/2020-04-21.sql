--Cleanup deprecated concepts with 'Duplicate of' description [AVOF-2395]
CREATE TABLE concept_blacklisted (concept_id int4 NOT NULL);

START TRANSACTION;

INSERT INTO concept_blacklisted
SELECT concept_id
FROM concept
WHERE concept_name LIKE 'Duplicate of%';

DELETE
FROM concept_synonym
WHERE concept_id IN (
		SELECT concept_id
		FROM concept
		WHERE concept_name LIKE 'Duplicate of%'
		);

DELETE
FROM concept_relationship
WHERE concept_id_1 IN (
		SELECT concept_id
		FROM concept
		WHERE concept_name LIKE 'Duplicate of%'
		);

DELETE
FROM concept_relationship
WHERE concept_id_2 IN (
		SELECT concept_id
		FROM concept
		WHERE concept_name LIKE 'Duplicate of%'
		);

DELETE
FROM concept
WHERE concept_name LIKE 'Duplicate of%';

COMMIT;

VACUUM ANALYZE concept_synonym;
VACUUM ANALYZE concept_relationship;
VACUUM ANALYZE concept;
--dedup episodes [https://github.com/OHDSI/Vocabulary-v5.0/issues/402] [AVOF-2849]
--remove from the synonyms
DELETE
FROM concept_synonym
WHERE concept_id IN (
		35225445,
		35225446,
		35225447,
		35225448,
		35225449,
		35225450,
		35225455,
		35225451,
		35225452,
		35225453,
		35225454
		);

--move relationships
UPDATE concept_relationship
SET concept_id_1 = 32945
WHERE concept_id_1 = 35225455
	AND concept_id_2 = 32530
	AND relationship_id = 'Mapped from';

UPDATE concept_relationship
SET concept_id_2 = 32945
WHERE concept_id_2 = 35225455
	AND concept_id_1 = 32530
	AND relationship_id = 'Maps to';

UPDATE concept_relationship
SET concept_id_1 = 32949
WHERE concept_id_1 = 35225454
	AND concept_id_2 = 32677
	AND relationship_id = 'Mapped from';

UPDATE concept_relationship
SET concept_id_2 = 32949
WHERE concept_id_2 = 35225454
	AND concept_id_1 = 32677
	AND relationship_id = 'Maps to';

--delete unnecessary links
DELETE
FROM concept_relationship
WHERE concept_id_1 IN (
		35225445,
		35225446,
		35225447,
		35225448,
		35225449,
		35225450,
		35225455,
		35225451,
		35225452,
		35225453,
		35225454
		)
	AND concept_id_1 = concept_id_2;

--delete from the concept
DELETE
FROM concept
WHERE concept_id IN (
		35225445,
		35225446,
		35225447,
		35225448,
		35225449,
		35225450,
		35225455,
		35225451,
		35225452,
		35225453,
		35225454
		);

--update vocabulary_id
UPDATE concept
SET vocabulary_id = 'Episode'
WHERE concept_id IN (
		32939,
		32940,
		32941,
		32942,
		32943,
		32944,
		32945,
		32946,
		32947,
		32948,
		32949
		);
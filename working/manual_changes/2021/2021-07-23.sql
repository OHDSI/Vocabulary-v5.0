--Remove duplicates from provider domain [AVOF-3219, AVOF-3005]

--1. Add new concepts
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Service Provider',
    pDomain_id        =>'Provider',
    pVocabulary_id    =>'Provider',
    pConcept_class_id =>'Provider',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP5117445',
    pValid_start_date => CURRENT_DATE
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Supplier / Service Provider',
    pDomain_id        =>'Visit',
    pVocabulary_id    =>'Visit',
    pConcept_class_id =>'Visit',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP5117446',
    pValid_start_date => CURRENT_DATE
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Psychiatry or Neurology',
    pDomain_id        =>'Provider',
    pVocabulary_id    =>'Provider',
    pConcept_class_id =>'Physician Specialty',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP5117448',
    pValid_start_date => CURRENT_DATE
);
END $_$;

--2. Add concepts and map (Maps to) the 1st one (Transfer from a Designated Disaster Alternate Care Site) to the 2nd one (Alternate care site (ACS))
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Transfer from a Designated Disaster Alternate Care Site',
    pDomain_id        =>'Visit',
      pVocabulary_id    =>'UB04 Point of Origin',
    pConcept_class_id =>'UB04 Point of Origin',
    pStandard_concept =>NULL,
    pConcept_code     =>'G',
    pValid_start_date => TO_DATE ('20200701', 'YYYYMMDD')
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Alternate care site (ACS)',
    pDomain_id        =>'Visit',
    pVocabulary_id    =>'Visit',
    pConcept_class_id =>'Visit',
    pStandard_concept =>'S',
    pConcept_code     =>'OMOP5117447',
    pValid_start_date => CURRENT_DATE
);
END $_$;

--Create mappings
WITH new_concepts
AS (
	SELECT c1.concept_id AS c_id1,
		c2.concept_id AS c_id2
	FROM concept c1
	JOIN concept c2 ON c2.concept_code = 'OMOP5117447'
		AND c2.vocabulary_id = 'Visit'
	WHERE c1.concept_code = 'G'
		AND c1.vocabulary_id = 'UB04 Point of Origin'
	)
INSERT INTO concept_relationship (
	--direct Maps to
	SELECT nc.c_id1,
	nc.c_id2,
	'Maps to',
	CURRENT_DATE,
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL FROM new_concepts nc
UNION ALL
	--reverse Maps to
	SELECT nc.c_id2,
	nc.c_id1,
	'Mapped from',
	CURRENT_DATE,
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL FROM new_concepts nc
);

--3. Update concepts from the "Concepts" file (dev_test.providers_to_update)
--Update domain_id, concept_class_id, invalid_reason and valid_end_date
UPDATE concept c
SET domain_id = p.domain_id,
	concept_class_id = p.concept_class_id,
	valid_end_date = CASE 
		WHEN p.invalid_reason IS NULL
			THEN TO_DATE('20991231', 'YYYYMMDD')
		ELSE CURRENT_DATE
		END,
	invalid_reason = p.invalid_reason
FROM dev_test.providers_to_update p
WHERE c.concept_id = p.concept_id
	AND (
		c.domain_id <> p.domain_id
		OR c.concept_class_id <> p.concept_class_id
		OR COALESCE(c.invalid_reason, 'X') <> COALESCE(p.invalid_reason, 'X')
		);

--Update concept_name but preserve the current name as a synonym (only for NUCC and for those concepts that have no synonym)
--Manual update for concept_id=43125860
UPDATE concept
SET concept_name = 'Allopathic & Osteopathic Physicians, Psychiatry & Neurology, Behavioral Neurology & Neuropsychiatry'
WHERE concept_id = 43125860;

--Manual update for concept_id=43125856
UPDATE concept
SET concept_name = 'Dental Providers, Dentist, Dentist Anesthesiologist'
WHERE concept_id = 43125856;

--Manual update for concept_id=43125859
UPDATE concept
SET concept_name = 'Allopathic & Osteopathic Physicians, Obstetrics & Gynecology, Female Pelvic Medicine and Reconstructive Surgery'
WHERE concept_id = 43125859;

--Manual update for concept_id=43125861
UPDATE concept
SET concept_name = 'Allopathic & Osteopathic Physicians, Urology, Female Pelvic Medicine and Reconstructive Surgery'
WHERE concept_id = 43125861;


WITH update_concept
AS (
	UPDATE concept c
	SET concept_name = p.concept_name
	FROM dev_test.providers_to_update p
	WHERE c.concept_id = p.concept_id
		AND c.concept_name <> p.concept_name
		AND p.vocabulary_id='NUCC'
	RETURNING c.concept_id
	)
INSERT INTO concept_synonym
SELECT c.concept_id,
	c.concept_name,
	4180186
FROM concept c
JOIN update_concept u USING (concept_id)
LEFT JOIN concept_synonym cs USING (concept_id)
WHERE cs.concept_id IS NULL;

--Those concepts that became Standard should lose their 'Maps to' to any other concepts
WITH update_concept
AS (
	UPDATE concept c
	SET standard_concept = p.standard_concept
	FROM dev_test.providers_to_update p
	WHERE c.concept_id = p.concept_id
		AND c.standard_concept IS NULL
		AND p.standard_concept = 'S' RETURNING c.concept_id
	),
deprecate_mappings
AS (
	UPDATE concept_relationship cr
	SET valid_end_date = CURRENT_DATE,
		invalid_reason = 'D'
	FROM update_concept u
	WHERE u.concept_id IN (
			cr.concept_id_1,
			cr.concept_id_2
			)
		AND cr.relationship_id IN (
			'Maps to',
			'Mapped from'
			)
		AND cr.invalid_reason IS NULL
	)
--Add new mapping 'Maps to' to self (and reverse)
INSERT INTO concept_relationship (
	SELECT u.concept_id,
	u.concept_id,
	'Maps to',
	CURRENT_DATE,
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL FROM update_concept u

UNION ALL
	
	SELECT u.concept_id,
	u.concept_id,
	'Mapped from',
	CURRENT_DATE,
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL FROM update_concept u
	)
	ON CONFLICT ON CONSTRAINT xpk_concept_relationship DO UPDATE --update existing mappings
	SET valid_end_date = TO_DATE('20991231', 'YYYYMMDD'),
		invalid_reason = NULL;

--Those concepts that became non-Standard should lose 'Maps to' aimed to them. Also exclude them from the hierarchy, including "Is a/Subsumes" "to/from" them (4 types of links)
WITH update_concept
AS (
	UPDATE concept c
	SET standard_concept = p.standard_concept
	FROM dev_test.providers_to_update p
	WHERE c.concept_id = p.concept_id
		AND c.standard_concept = 'S'
		AND p.standard_concept IS NULL
	RETURNING c.concept_id
	)
UPDATE concept_relationship cr
SET valid_end_date = CURRENT_DATE,
	invalid_reason = 'D'
FROM update_concept u
WHERE u.concept_id IN (
		cr.concept_id_1,
		cr.concept_id_2
		)
	AND cr.relationship_id IN (
		'Maps to',
		'Mapped from',
		'Is a',
		'Subsumes'
		)
	AND cr.invalid_reason IS NULL;

--4. Ingest the relationships from the "Mappings" file (dev_test.providers_relationships)
WITH update_concept
AS (
	UPDATE concept c
	SET standard_concept = NULL
	FROM dev_test.providers_relationships pr
	WHERE c.concept_code = pr.concept_code_1
		AND c.vocabulary_id = pr.vocabulary_id_1
		AND pr.relationship_id = 'Maps to'
		AND pr.invalid_reason IS NULL
	RETURNING c.concept_id
	),
deprecate_self_mappings
AS (
	UPDATE concept_relationship cr
	SET valid_end_date = CURRENT_DATE,
		invalid_reason = 'D'
	FROM update_concept u
	WHERE u.concept_id = cr.concept_id_1
		AND u.concept_id = cr.concept_id_2
		AND cr.relationship_id IN (
			'Maps to',
			'Mapped from'
			)
		AND cr.invalid_reason IS NULL
	)
--Deprecate hierarchical mappings
UPDATE concept_relationship cr
SET valid_end_date = CURRENT_DATE,
	invalid_reason = 'D'
FROM update_concept u
WHERE u.concept_id IN (
		cr.concept_id_1,
		cr.concept_id_2
		)
	AND cr.relationship_id IN (
		'Is a',
		'Subsumes'
		)
	AND cr.invalid_reason IS NULL;

--Merge providers_relationships
WITH concepts_to_merge
AS (
	SELECT c1.concept_id AS concept_id_1,
		c2.concept_id AS concept_id_2,
		pr.relationship_id,
		pr.invalid_reason
	FROM dev_test.providers_relationships pr
	JOIN concept c1 ON c1.concept_code = pr.concept_code_1
		AND c1.vocabulary_id = pr.vocabulary_id_1
	JOIN concept c2 ON c2.concept_code = pr.concept_code_2
		AND c2.vocabulary_id = pr.vocabulary_id_2
	),
update_relationship
AS (
	UPDATE concept_relationship cr
	SET valid_end_date = CASE 
			WHEN m.invalid_reason IS NULL
				THEN TO_DATE('20991231', 'YYYYMMDD')
			ELSE CURRENT_DATE
			END,
		invalid_reason = m.invalid_reason
	FROM concepts_to_merge m
	WHERE cr.concept_id_1 = m.concept_id_1
		AND cr.concept_id_2 = m.concept_id_2
		AND cr.relationship_id = m.relationship_id
		RETURNING cr.concept_id_1, cr.concept_id_2, cr.relationship_id
	),
update_reverse_relationship
AS (
	UPDATE concept_relationship cr
	SET valid_end_date = CASE 
			WHEN m.invalid_reason IS NULL
				THEN TO_DATE('20991231', 'YYYYMMDD')
			ELSE CURRENT_DATE
			END,
		invalid_reason = m.invalid_reason
	FROM concepts_to_merge m
	JOIN relationship r USING (relationship_id)
	WHERE cr.concept_id_1 = m.concept_id_2
		AND cr.concept_id_2 = m.concept_id_1
		AND cr.relationship_id = r.reverse_relationship_id
	),
new_mappings
AS (
	SELECT m.*
	FROM concepts_to_merge m
	LEFT JOIN update_relationship ur USING (concept_id_1, concept_id_2, relationship_id)
	WHERE ur.concept_id_1 IS NULL
	)
--Insert new mappings with reverse
INSERT INTO concept_relationship (
	SELECT n.concept_id_1,
	n.concept_id_2,
	n.relationship_id,
	CURRENT_DATE,
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL FROM new_mappings n

UNION ALL
	
	SELECT n.concept_id_2,
	n.concept_id_1,
	r.reverse_relationship_id,
	CURRENT_DATE,
	TO_DATE('20991231', 'YYYYMMDD'),
	NULL FROM new_mappings n
	JOIN relationship r USING (relationship_id)
	);




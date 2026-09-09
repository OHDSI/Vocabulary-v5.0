CREATE OR REPLACE FUNCTION dev_snomed.MapDrugs ()
RETURNS VOID AS
$BODY$
BEGIN
-- 1. Add mappings FROM substances to RxNorm/RxE in case of full name match:
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT cs.concept_code,
       cc.concept_code,
       cs.vocabulary_id,
       cc.vocabulary_id,
       'Maps to',
        (
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage cs
JOIN devv5.concept cc on lower(cs.concept_name) = lower(cc.concept_name)
WHERE cs.domain_id = 'Drug'
    AND cs.concept_class_id = 'Substance'
    AND cs.vocabulary_id = 'SNOMED'
    AND cc.vocabulary_id like 'RxNorm%'
    AND cc.standard_concept = 'S'
    AND NOT exists(
        SELECT 1
        FROM devv5.concept_relationship cr
        JOIN devv5.concept c on c.concept_id = cr.concept_id_1
        WHERE (c.concept_code, c.vocabulary_id) = (cs.concept_code, cs.vocabulary_id)
            AND cr.relationship_id = 'Maps to'
            AND cr.invalid_reason IS NULL)
;

-- 2. Add mappings for Drugs FROM UMLS:
--- FROM mrconso
INSERT INTO concept_relationship_stage
(concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)
SELECT DISTINCT ON (cs.concept_code, cs.vocabulary_id)
        cs.concept_code,
        cc.concept_code,
        cs.vocabulary_id,
        cc.vocabulary_id,
        'Maps to',
        current_date,
        '2099-12-31'::DATE,
        NULL
FROM sources.mrconso rx
JOIN sources.mrconso s using(cui)
JOIN concept_stage cs on cs.concept_code = s.code AND cs.vocabulary_id = 'SNOMED' AND cs.domain_id = 'Drug'
JOIN concept cc on cc.concept_code = rx.code AND cc.vocabulary_id = 'RxNorm' AND cc.standard_concept = 'S'
WHERE rx.sab = 'RXNORM'
AND s.sab  = 'SNOMEDCT_US'
AND cs.concept_class_id != 'Organism'
AND NOT exists (select 1
       			FROM concept_relationship_stage crs
       			WHERE crs.concept_code_1 = cs.concept_code
       			    AND crs.vocabulary_id_1 = 'SNOMED'
	          		AND crs.relationship_id = 'Maps to'
	              )
;
--- FROM rxnconco:
INSERT INTO concept_relationship_stage
(concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)
SELECT DISTINCT cs.concept_code,
        cc.concept_code,
        cs.vocabulary_id,
        cc.vocabulary_id,
        'Maps to',
        current_date,
        '2099-12-31'::DATE,
        NULL
FROM sources.rxnconso rx
JOIN sources.rxnconso s using(rxcui)
JOIN concept_stage cs on cs.concept_code = s.code AND cs.vocabulary_id = 'SNOMED'
JOIN concept cc on cc.concept_code = rx.code AND cc.vocabulary_id = 'RxNorm' AND cc.standard_concept = 'S'
WHERE rx.sab = 'RXNORM'
AND s.sab  = 'SNOMEDCT_US'
AND cs.concept_class_id != 'Organism'
AND NOT exists (select 1
       			FROM concept_relationship_stage crs
       			WHERE crs.concept_code_1 = cs.concept_code
       			    AND crs.vocabulary_id_1 = 'SNOMED'
	          		AND crs.relationship_id = 'Maps to'
	              )
;

-- 3. Add mappings of Clinical Drug Forms to their ingredients:
INSERT INTO concept_relationship_stage
(concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)
SELECT DISTINCT c.concept_code,
                c2.concept_code,
                c.vocabulary_id,
                c2.vocabulary_id,
                'Maps to',
                current_date,
                '2099-12-31'::date,
                NULL
FROM concept_stage c
JOIN concept_relationship_stage cr ON cr.concept_code_1 = c.concept_code
                                    AND cr.vocabulary_id_1 = c.vocabulary_id
                                    AND cr.relationship_id = 'Has active ing'
                                    AND cr.invalid_reason IS NULL
JOIN concept_stage cc on (cc.concept_code, cc.vocabulary_id) = (cr.concept_code_2, cr.vocabulary_id_2)
JOIN concept_relationship_stage cr1 ON (cc.concept_code, cc.vocabulary_id) = (cr1.concept_code_1, cr1.vocabulary_id_1)
                                     AND cr1.relationship_id = 'Maps to'
                                     AND cr1.invalid_reason IS NULL
JOIN concept_stage c2 on (c2.concept_code, c2.vocabulary_id) = (cr1.concept_code_2, cr1.vocabulary_id_2)
WHERE c.vocabulary_id = 'SNOMED'
  AND c.domain_id = 'Drug'
  AND c2.vocabulary_id LIKE 'RxNorm%'
  AND NOT exists(SELECT 1
               FROM concept_relationship_stage crs1
               WHERE (c.concept_code, c.vocabulary_id) = (crs1.concept_code_1, crs1.vocabulary_id_1)
               AND crs1.relationship_id = 'Maps to'
               AND crs1.invalid_reason IS NULL)
  AND NOT exists(SELECT 1
               FROM devv5.concept_relationship b
               JOIN devv5.concept a on a.concept_id = b.concept_id_1
               WHERE (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
               AND b.relationship_id = 'Maps to'
               AND b.invalid_reason IS NULL);
END;
$BODY$
LANGUAGE plpgsql;
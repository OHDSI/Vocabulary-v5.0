BEGIN
	DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'GPI',
										  pVocabularyDate        => TRUNC(SYSDATE),
										  pVocabularyVersion     => 'GPI 2017',
										  pVocabularyDevSchema   => 'DEV_GPI');
END;
COMMIT;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load GPI codes with best names
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT FIRST_VALUE(substr(str, 1, 255)) OVER (
		PARTITION BY atv ORDER BY CASE 
				WHEN LENGTH(str) <= 255
					THEN LENGTH(str)
				ELSE 0
				END DESC,
			LENGTH(str) ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS concept_name,
	'Drug' AS domain_id,
	'GPI' AS vocabulary_id,
	'GPI' AS concept_class_id,
	NULL AS standard_concept,
	atv AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'GPI'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM dev_rxnorm.rxnconso rxc
JOIN dev_rxnorm.rxnsat rxn ON rxn.rxcui = rxc.rxcui
	AND rxn.rxaui = rxc.rxaui
	AND rxn.sab = rxc.sab
WHERE rxc.sab = 'MDDB'
	AND rxn.atn = 'GPI';
COMMIT;

--4. Add mapping from GPI to RxNorm from rxnconso
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
WITH all_concepts AS (
		SELECT concept_code_1,
			concept_code_2,
			vocabulary_id_1,
			vocabulary_id_2,
			relationship_id,
			valid_start_date,
			valid_end_date,
			invalid_reason,
			min(cnt) OVER (PARTITION BY concept_code_1) AS min_cnt,
			cnt,
			concept_class_id
		FROM (
			SELECT concept_code_1,
				concept_code_2,
				vocabulary_id_1,
				vocabulary_id_2,
				relationship_id,
				valid_start_date,
				valid_end_date,
				invalid_reason,
				count(*) OVER (
					PARTITION BY concept_code_1,
					concept_class_id
					) AS cnt,
				concept_class_id
			FROM (
				SELECT DISTINCT rxn.atv AS concept_code_1,
					rxn.rxcui AS concept_code_2,
					'GPI' AS vocabulary_id_1,
					'RxNorm' AS vocabulary_id_2,
					'Maps to' AS relationship_id,
					v.latest_update AS valid_start_date,
					TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
					NULL AS invalid_reason,
					c.concept_class_id
				FROM dev_rxnorm.rxnconso rxc
				JOIN dev_rxnorm.rxnsat rxn ON rxn.rxcui = rxc.rxcui
					AND rxn.rxaui = rxc.rxaui
					AND rxn.sab = rxc.sab
				JOIN concept c ON rxc.rxcui = concept_code
					AND c.vocabulary_id = 'RxNorm'
					AND COALESCE(c.invalid_reason, 'X') <> 'D'
				JOIN vocabulary v ON v.vocabulary_id = 'GPI'
				WHERE rxc.sab = 'MDDB'
					AND rxn.atn = 'GPI'
					AND rxc.suppress NOT IN (
						'E',
						'O',
						'Y'
						)
					AND rxn.suppress NOT IN (
						'E',
						'O',
						'Y'
						)
				)
			)
		)
SELECT DISTINCT concept_code_1,
	first_value(concept_code_2) OVER (
		PARTITION BY concept_code_1 ORDER BY cnt,
			CASE concept_class_id
				WHEN 'Branded Pack'
					THEN 1
				WHEN 'Quant Branded Drug'
					THEN 2
				WHEN 'Branded Drug'
					THEN 3
				WHEN 'Clinical Pack'
					THEN 4
				WHEN 'Quant Clinical Drug'
					THEN 5
				WHEN 'Clinical Drug'
					THEN 6
				WHEN 'Clinical Drug Form'
					THEN 7
				WHEN 'Ingredient'
					THEN 8
				WHEN 'Precise Ingredient'
					THEN 9
				WHEN 'Clinical Dose Group'
					THEN 10
				ELSE 11
				END,
			concept_code_2
		) AS concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM (
	SELECT *
	FROM all_concepts a
	WHERE a.min_cnt > 1
		AND NOT EXISTS (
			SELECT 1
			FROM concept c1,
				concept c2,
				concept_relationship r
			WHERE c1.concept_id = r.concept_id_1
				AND c2.concept_id = r.concept_id_2
				AND c1.vocabulary_id = 'GPI'
				AND c2.vocabulary_id = 'RxNorm'
				AND r.invalid_reason IS NULL
				AND r.relationship_id = 'Maps to'
				AND c1.concept_code = a.concept_code_1
			)
	UNION ALL
	SELECT *
	FROM all_concepts a
	WHERE a.min_cnt = 1
	);
COMMIT;

--5. Add synonyms
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT atv,
	str,
	'GPI',
	4180186
FROM dev_rxnorm.rxnconso rxc
JOIN dev_rxnorm.rxnsat rxn ON rxn.rxcui = rxc.rxcui
	AND rxn.rxaui = rxc.rxaui
	AND rxn.sab = rxc.sab
WHERE rxc.sab = 'MDDB'
	AND rxn.atn = 'GPI';
COMMIT;

--6. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
	DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;

--7. Add mapping from deprecated to fresh concepts
BEGIN
	DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;

--8. Delete ambiguous 'Maps to' mappings
BEGIN
	DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

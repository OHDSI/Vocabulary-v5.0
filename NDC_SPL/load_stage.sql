/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'NDC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.product LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.product LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_NDC'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'SPL',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.product LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.product LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_NDC',
	pAppendVocabulary		=> TRUE
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create necessary functions
--get aggregated dose
CREATE OR REPLACE FUNCTION GetAggrDose (active_numerator_strength IN VARCHAR, active_ingred_unit IN VARCHAR) RETURNS VARCHAR
AS
$BODY$
DECLARE
	z VARCHAR(4000);
BEGIN
	SELECT STRING_AGG(a_n_s||a_i_u, ' / ' ORDER BY LPAD(a_n_s||a_i_u,50,'0')) INTO z FROM
	(
		SELECT * FROM (
			SELECT DISTINCT
			UNNEST(regexp_matches(active_numerator_strength, '[^; ]+', 'g')) a_n_s,
			UNNEST(regexp_matches(active_ingred_unit, '[^; ]+', 'g')) a_i_u
		) AS s0
	) AS s1;
	RETURN z;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER;

--get unique dose
CREATE OR REPLACE FUNCTION GetDistinctDose (active_numerator_strength IN VARCHAR, active_ingred_unit IN VARCHAR, p IN INT) RETURNS VARCHAR
AS
$BODY$
DECLARE
	z VARCHAR(4000);
BEGIN
	IF p=1 THEN --distinct active_numerator_strength values
		SELECT STRING_AGG(a_n_s, '; ' ORDER BY LPAD(a_n_s,50,'0')) INTO z FROM
		(
			SELECT * FROM (
				SELECT DISTINCT
				UNNEST(regexp_matches(active_numerator_strength, '[^; ]+', 'g')) a_n_s,
				UNNEST(regexp_matches(active_ingred_unit, '[^; ]+', 'g')) a_i_u
			) AS s0
		) AS s1;
	ELSE --distinct active_ingred_unit values (but order by active_numerator_strength!)
		SELECT STRING_AGG(a_i_u, '; ' ORDER BY LPAD(a_n_s,50,'0')) INTO z FROM
		(
			SELECT * FROM (
				SELECT DISTINCT
				UNNEST(regexp_matches(active_numerator_strength, '[^; ]+', 'g')) a_n_s,
				UNNEST(regexp_matches(active_ingred_unit, '[^; ]+', 'g')) a_i_u
			) AS s0
		) AS s1;
	END IF;
	RETURN z;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER;

--4. Load upgraded SPL concepts
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
SELECT SUBSTR(spl_name, 1, 255) AS concept_name,
	CASE 
		WHEN displayname IN ('COSMETIC')
			THEN 'Observation'
		WHEN displayname IN (
				'MEDICAL DEVICE',
				'OTC MEDICAL DEVICE LABEL',
				'PRESCRIPTION MEDICAL DEVICE LABEL',
				'MEDICAL FOOD',
				'DIETARY SUPPLEMENT'
				)
			THEN 'Device'
		ELSE 'Drug'
		END AS domain_id,
	'SPL' AS vocabulary_id,
	CASE 
		WHEN displayname IN ('BULK INGREDIENT')
			THEN 'Ingredient'
		WHEN displayname IN (
				'CELLULAR THERAPY',
				'LICENSED MINIMALLY MANIPULATED CELLS LABEL'
				)
			THEN 'Cellular Therapy'
		WHEN displayname IN ('COSMETIC')
			THEN 'Cosmetic'
		WHEN displayname IN ('DIETARY SUPPLEMENT')
			THEN 'Supplement'
		WHEN displayname IN ('HUMAN OTC DRUG LABEL')
			THEN 'OTC Drug'
		WHEN displayname IN (
				'MEDICAL DEVICE',
				'OTC MEDICAL DEVICE LABEL',
				'PRESCRIPTION MEDICAL DEVICE LABEL'
				)
			THEN 'Device'
		WHEN displayname IN ('MEDICAL FOOD')
			THEN 'Food'
		WHEN displayname IN ('NON-STANDARDIZED ALLERGENIC LABEL')
			THEN 'Non-Stand Allergenic'
		WHEN displayname IN ('OTC ANIMAL DRUG LABEL')
			THEN 'Animal Drug'
		WHEN displayname IN ('PLASMA DERIVATIVE')
			THEN 'Plasma Derivative'
		WHEN displayname IN ('STANDARDIZED ALLERGENIC')
			THEN 'Standard Allergenic'
		WHEN displayname IN ('VACCINE LABEL')
			THEN 'Vaccine'
		ELSE 'Prescription Drug'
		END AS concept_class_id,
	'C' AS standard_concept,
	replaced_spl AS concept_code,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	spl_date - 1 AS valid_end_date,
	'U' AS invalid_reason
FROM (
	SELECT DISTINCT first_value(coalesce(s2.concept_name, c.concept_name)) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date,
				s.concept_code rows BETWEEN unbounded preceding
					AND unbounded following
			) spl_name,
		first_value(s.displayname) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date,
				s.concept_code rows BETWEEN unbounded preceding
					AND unbounded following
			) displayname,
		first_value(s.valid_start_date) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date rows BETWEEN unbounded preceding
					AND unbounded following
			) spl_date,
		l.replaced_spl
	FROM sources.spl_ext s
	JOIN lateral(SELECT unnest(regexp_matches(s.replaced_spl, '[^;]+', 'g')) AS replaced_spl) l ON true
	LEFT JOIN concept c ON c.vocabulary_id = 'SPL'
		AND c.concept_code = l.replaced_spl
	LEFT JOIN sources.spl_ext s2 ON s2.concept_code = l.replaced_spl
	WHERE s.replaced_spl IS NOT NULL -- if there is an SPL codes ( l ) that is mentioned in another record as replaced_spl (path /document/relatedDocument/relatedDocument/setId/@root)
	) AS s0
WHERE spl_name IS NOT NULL
	AND displayname NOT IN (
		'IDENTIFICATION OF CBER-REGULATED GENERIC DRUG FACILITY',
		'INDEXING - PHARMACOLOGIC CLASS',
		'INDEXING - SUBSTANCE',
		'WHOLESALE DRUG DISTRIBUTORS AND THIRD-PARTY LOGISTICS FACILITY REPORT'
		);

--5. Load main SPL concepts into concept_stage
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
SELECT TRIM(SUBSTR(concept_name, 1, 255)) concept_name,
	CASE 
		WHEN displayname IN (
				'COSMETIC',
				'MEDICAL FOOD'
				)
			THEN 'Observation'
		WHEN displayname IN (
				'MEDICAL DEVICE',
				'OTC MEDICAL DEVICE LABEL',
				'PRESCRIPTION MEDICAL DEVICE LABEL'
				)
			THEN 'Device'
		ELSE 'Drug'
		END AS domain_id,
	'SPL' AS vocabulary_id,
	CASE 
		WHEN displayname IN ('BULK INGREDIENT')
			THEN 'Ingredient'
		WHEN displayname IN ('CELLULAR THERAPY')
			THEN 'Cellular Therapy'
		WHEN displayname IN ('COSMETIC')
			THEN 'Cosmetic'
		WHEN displayname IN ('DIETARY SUPPLEMENT')
			THEN 'Supplement'
		WHEN displayname IN ('HUMAN OTC DRUG LABEL')
			THEN 'OTC Drug'
		WHEN displayname IN ('LICENSED MINIMALLY MANIPULATED CELLS LABEL')
			THEN 'Cellular Therapy'
		WHEN displayname IN (
				'MEDICAL DEVICE',
				'OTC MEDICAL DEVICE LABEL',
				'PRESCRIPTION MEDICAL DEVICE LABEL'
				)
			THEN 'Device'
		WHEN displayname IN ('MEDICAL FOOD')
			THEN 'Food'
		WHEN displayname IN ('NON-STANDARDIZED ALLERGENIC LABEL')
			THEN 'Non-Stand Allergenic'
		WHEN displayname IN ('OTC ANIMAL DRUG LABEL')
			THEN 'Animal Drug'
		WHEN displayname IN ('PLASMA DERIVATIVE')
			THEN 'Plasma Derivative'
		WHEN displayname IN ('STANDARDIZED ALLERGENIC')
			THEN 'Standard Allergenic'
		WHEN displayname IN ('VACCINE LABEL')
			THEN 'Vaccine'
		ELSE 'Prescription Drug'
		END AS concept_class_id,
	'C' AS standard_concept,
	concept_code,
	valid_start_date,
	to_date('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.spl_ext s
WHERE displayname NOT IN (
		'IDENTIFICATION OF CBER-REGULATED GENERIC DRUG FACILITY',
		'INDEXING - PHARMACOLOGIC CLASS',
		'INDEXING - SUBSTANCE',
		'WHOLESALE DRUG DISTRIBUTORS AND THIRD-PARTY LOGISTICS FACILITY REPORT'
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE lower(s.concept_code) = lower(cs_int.concept_code)
		);

--6. Load other SPL into concept_stage (from 'product')
CREATE OR REPLACE VIEW prod --for using INDEX 'idx_f_product'
AS
(
		SELECT SUBSTR(productid, devv5.INSTR(productid, '_') + 1) AS concept_code,
			DOSAGEFORMNAME,
			ROUTENAME,
			proprietaryname,
			nonproprietaryname,
			proprietarynamesuffix,
			active_numerator_strength,
			active_ingred_unit
		FROM sources.product
		);

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
WITH good_spl AS (
		SELECT CASE -- add [brandname] if proprietaryname exists and not identical to nonproprietaryname
				WHEN brand_name IS NULL
					THEN TRIM(SUBSTR(TRIM(concept_name), 1, 255))
				ELSE TRIM(SUBSTR(CONCAT (
							TRIM(concept_name),
							' [',
							brand_name,
							']'
							), 1, 255))
				END AS concept_name,
			'Drug' AS domain_id,
			'SPL' AS vocabulary_id,
			concept_class_id,
			'C' AS standard_concept,
			concept_code,
			COALESCE(valid_start_date, latest_update) AS valid_start_date,
			TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
			NULL AS invalid_reason
		FROM --get unique and aggregated data from source
			(
			SELECT concept_code,
				concept_class_id,
				MULTI_NONPROPRIETARYNAME,
				CASE 
					WHEN MULTI_NONPROPRIETARYNAME IS NULL
						THEN CONCAT (
								SUBSTR(nonproprietaryname, 1, 100),
								CASE 
									WHEN length(nonproprietaryname) > 100
										THEN '...'
									END,
								NULLIF(' ' || SUBSTR(aggr_dose, 1, 100), ' '),
								' ',
								SUBSTR(routename, 1, 100),
								' ',
								SUBSTR(dosageformname, 1, 100)
								)
					ELSE CONCAT (
							'Multiple formulations: ',
							SUBSTR(nonproprietaryname, 1, 100),
							CASE 
								WHEN length(nonproprietaryname) > 100
									THEN '...'
								END,
							NULLIF(' ' || SUBSTR(aggr_dose, 1, 100), ' '),
							' ',
							SUBSTR(routename, 1, 100),
							' ',
							SUBSTR(dosageformname, 1, 100)
							)
					END AS concept_name,
				SUBSTR(brand_name, 1, 255) AS brand_name,
				valid_start_date
			FROM (
				WITH t AS (
						SELECT concept_code,
							concept_class_id,
							valid_start_date,
							GetAggrDose(active_numerator_strength, active_ingred_unit) aggr_dose
						FROM (
							SELECT concept_code,
								concept_class_id,
								string_agg(active_numerator_strength, '; ' ORDER BY CONCAT (active_numerator_strength,active_ingred_unit)) AS active_numerator_strength,
								string_agg(active_ingred_unit, '; ' ORDER BY CONCAT (active_numerator_strength,active_ingred_unit)) AS active_ingred_unit,
								valid_start_date
							FROM (
								SELECT concept_code,
									concept_class_id,
									active_numerator_strength,
									active_ingred_unit,
									min(valid_start_date) OVER (PARTITION BY concept_code) AS valid_start_date
								FROM (
									SELECT GetDistinctDose(active_numerator_strength, active_ingred_unit, 1) AS active_numerator_strength,
										GetDistinctDose(active_numerator_strength, active_ingred_unit, 2) AS active_ingred_unit,
										SUBSTR(productid, devv5.INSTR(productid, '_') + 1) AS concept_code,
										CASE producttypename
											WHEN 'VACCINE'
												THEN 'Vaccine'
											WHEN 'LICENSED VACCINE BULK INTERMEDIATE'
												THEN 'Vaccine'
											WHEN 'STANDARDIZED ALLERGENIC'
												THEN 'Standard Allergenic'
											WHEN 'HUMAN PRESCRIPTION DRUG'
												THEN 'Prescription Drug'
											WHEN 'HUMAN OTC DRUG'
												THEN 'OTC Drug'
											WHEN 'PLASMA DERIVATIVE'
												THEN 'Plasma Derivative'
											WHEN 'NON-STANDARDIZED ALLERGENIC'
												THEN 'Non-Stand Allergenic'
											WHEN 'CELLULAR THERAPY'
												THEN 'Cellular Therapy'
											END AS concept_class_id,
										startmarketingdate AS valid_start_date
									FROM sources.product
									) AS s0
								GROUP BY concept_code,
									concept_class_id,
									active_numerator_strength,
									active_ingred_unit,
									valid_start_date
								) AS s1
							GROUP BY concept_code,
								concept_class_id,
								valid_start_date
							) AS s2
						)
				SELECT t1.*,
					--aggregated unique DOSAGEFORMNAME
					(
						SELECT string_agg(DOSAGEFORMNAME, ', ' ORDER BY DOSAGEFORMNAME)
						FROM (
							SELECT DISTINCT P.DOSAGEFORMNAME
							FROM prod p
							WHERE p.concept_code = t1.concept_code
							) AS s3
						) AS DOSAGEFORMNAME,
					--aggregated unique ROUTENAME
					(
						SELECT string_agg(ROUTENAME, ', ' ORDER BY ROUTENAME)
						FROM (
							SELECT DISTINCT P.ROUTENAME
							FROM prod p
							WHERE p.concept_code = t1.concept_code
							) AS s4
						) AS ROUTENAME,
					--aggregated unique NONPROPRIETARYNAME
					(
						SELECT string_agg(NONPROPRIETARYNAME, ', ' ORDER BY NONPROPRIETARYNAME)
						FROM (
							SELECT DISTINCT lower(P.NONPROPRIETARYNAME) NONPROPRIETARYNAME
							FROM prod p
							WHERE p.concept_code = t1.concept_code
							ORDER BY NONPROPRIETARYNAME limit 14
							) AS s5
						) AS NONPROPRIETARYNAME,
					--multiple formulations flag
					(
						SELECT count(lower(P.NONPROPRIETARYNAME))
						FROM prod p
						WHERE p.concept_code = t1.concept_code
						HAVING count(DISTINCT lower(P.NONPROPRIETARYNAME)) > 1
						) AS MULTI_NONPROPRIETARYNAME,
					(
						SELECT string_agg(brand_name, ', ' ORDER BY brand_name)
						FROM (
							SELECT DISTINCT CASE 
									WHEN (
											lower(proprietaryname) <> lower(nonproprietaryname)
											OR nonproprietaryname IS NULL
											)
										THEN LOWER(TRIM(CONCAT (
														proprietaryname,
														' ',
														proprietarynamesuffix
														)))
									ELSE NULL
									END AS brand_name
							FROM prod p
							WHERE p.concept_code = t1.concept_code
							ORDER BY brand_name limit 49 --brand_name may be too long for concatenation
							) AS s6
						) AS brand_name
				FROM t t1
				) AS s7
			) s,
			vocabulary v
		WHERE v.vocabulary_id = 'SPL'
		)
SELECT *
FROM good_spl s
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE lower(s.concept_code) = lower(cs_int.concept_code)
		);

DROP VIEW prod;

--7. Add upgrade SPL relationships
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
SELECT spl_code AS concept_code_1,
	replaced_spl AS concept_code_2,
	'SPL' AS vocabulary_id_1,
	'SPL' AS vocabulary_id_2,
	'Concept replaced by' AS relationship_id,
	spl_date - 1 AS valid_start_date,
	to_date('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT first_value(s.concept_code) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date,
				s.concept_code rows BETWEEN unbounded preceding
					AND unbounded following
			) spl_code,
		first_value(s.valid_start_date) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date,
				s.concept_code rows BETWEEN unbounded preceding
					AND unbounded following
			) spl_date,
		l.replaced_spl
	FROM sources.spl_ext s
	JOIN lateral(SELECT unnest(regexp_matches(s.replaced_spl, '[^;]+', 'g')) AS replaced_spl) l ON true
	WHERE s.replaced_spl IS NOT NULL -- if there is an SPL codes ( l ) that is mentioned in another record as replaced_spl (path /document/relatedDocument/relatedDocument/setId/@root)
	) AS s0;

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

--8. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--10. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--12. Load NDC into temporary table from 'product'
DROP TABLE IF EXISTS main_ndc;
CREATE UNLOGGED TABLE main_ndc AS SELECT * FROM concept_stage WHERE 1=0;

CREATE OR REPLACE VIEW prod --for using INDEX 'idx_f1_product'
AS
(
		SELECT CASE 
				WHEN devv5.INSTR(productndc, '-') = 5
					THEN '0' || SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
				ELSE SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
				END || CASE 
				WHEN LENGTH(SUBSTR(productndc, devv5.INSTR(productndc, '-'))) = 4
					THEN '0' || SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
				ELSE SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
				END AS concept_code,
			dosageformname,
			routename,
			proprietaryname,
			nonproprietaryname,
			proprietarynamesuffix,
			active_numerator_strength,
			active_ingred_unit
		FROM sources.product
		);

INSERT INTO main_ndc
SELECT NULL AS concept_id,
	CASE -- add [brandname] if proprietaryname exists and not identical to nonproprietaryname
		WHEN brand_name IS NULL
			THEN TRIM(SUBSTR(TRIM(concept_name), 1, 255))
		ELSE TRIM(SUBSTR(CONCAT (
					TRIM(concept_name),
					' [',
					brand_name,
					']'
					), 1, 255))
		END AS concept_name,
	'Drug' AS domain_id,
	'NDC' AS vocabulary_id,
	'9-digit NDC' AS concept_class_id,
	NULL AS standard_concept,
	concept_code,
	COALESCE(valid_start_date, latest_update) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM --get unique and aggregated data from source
	(
	SELECT concept_code,
		CASE 
			WHEN MULTI_NONPROPRIETARYNAME IS NULL
				THEN CONCAT (
						SUBSTR(nonproprietaryname, 1, 100),
						CASE 
							WHEN length(nonproprietaryname) > 100
								THEN '...'
							END,
						NULLIF(' ' || SUBSTR(aggr_dose, 1, 100), ' '),
						' ',
						SUBSTR(routename, 1, 100),
						' ',
						SUBSTR(dosageformname, 1, 100)
						)
			ELSE CONCAT (
					'Multiple formulations: ',
					SUBSTR(nonproprietaryname, 1, 100),
					CASE 
						WHEN length(nonproprietaryname) > 100
							THEN '...'
						END,
					NULLIF(' ' || SUBSTR(aggr_dose, 1, 100), ' '),
					' ',
					SUBSTR(routename, 1, 100),
					' ',
					SUBSTR(dosageformname, 1, 100)
					)
			END AS concept_name,
		SUBSTR(brand_name, 1, 255) AS brand_name,
		valid_start_date
	FROM (
		WITH t AS (
				SELECT concept_code,
					valid_start_date,
					GetAggrDose(active_numerator_strength, active_ingred_unit) aggr_dose
				FROM (
					SELECT concept_code,
						string_agg(active_numerator_strength, '; ' ORDER BY CONCAT (active_numerator_strength,active_ingred_unit)) AS active_numerator_strength,
						string_agg(active_ingred_unit, '; ' ORDER BY CONCAT (active_numerator_strength,active_ingred_unit)) AS active_ingred_unit,
						valid_start_date
					FROM (
						SELECT concept_code,
							active_numerator_strength,
							active_ingred_unit,
							min(valid_start_date) OVER (PARTITION BY concept_code) AS valid_start_date
						FROM (
							SELECT GetDistinctDose(active_numerator_strength, active_ingred_unit, 1) AS active_numerator_strength,
								GetDistinctDose(active_numerator_strength, active_ingred_unit, 2) AS active_ingred_unit,
								CASE 
									WHEN devv5.INSTR(productndc, '-') = 5
										THEN '0' || SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
									ELSE SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
									END || CASE 
									WHEN LENGTH(SUBSTR(productndc, devv5.INSTR(productndc, '-'))) = 4
										THEN '0' || SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
									ELSE SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
									END AS concept_code,
								startmarketingdate AS valid_start_date
							FROM sources.product
							) AS s0
						GROUP BY concept_code,
							active_numerator_strength,
							active_ingred_unit,
							valid_start_date
						) AS s1
					GROUP BY concept_code,
						valid_start_date
					) AS s2
				)
		SELECT t1.*,
			--aggregated unique DOSAGEFORMNAME
			(
				SELECT string_agg(DOSAGEFORMNAME, ', ' ORDER BY DOSAGEFORMNAME)
				FROM (
					SELECT DISTINCT P.DOSAGEFORMNAME
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					) AS s3
				) AS DOSAGEFORMNAME,
			--aggregated unique ROUTENAME
			(
				SELECT string_agg(ROUTENAME, ', ' ORDER BY ROUTENAME)
				FROM (
					SELECT DISTINCT P.ROUTENAME
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					) AS s4
				) AS ROUTENAME,
			--aggregated unique NONPROPRIETARYNAME
			(
				SELECT string_agg(NONPROPRIETARYNAME, ', ' ORDER BY NONPROPRIETARYNAME)
				FROM (
					SELECT DISTINCT lower(P.NONPROPRIETARYNAME) NONPROPRIETARYNAME
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					ORDER BY NONPROPRIETARYNAME limit 14
					) AS s5
				) AS NONPROPRIETARYNAME,
			--multiple formulations flag
			(
				SELECT count(lower(P.NONPROPRIETARYNAME))
				FROM prod p
				WHERE p.concept_code = t1.concept_code
				HAVING count(DISTINCT lower(P.NONPROPRIETARYNAME)) > 1
				) AS MULTI_NONPROPRIETARYNAME,
			(
				SELECT string_agg(brand_name, ', ' ORDER BY brand_name)
				FROM (
					SELECT DISTINCT CASE 
							WHEN (
									lower(proprietaryname) <> lower(nonproprietaryname)
									OR nonproprietaryname IS NULL
									)
								THEN LOWER(TRIM(proprietaryname || ' ' || proprietarynamesuffix))
							ELSE NULL
							END AS brand_name
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					ORDER BY brand_name limit 49 --brand_name may be too long for concatenation
					) AS s6
				) AS brand_name
		FROM t t1
		) AS s7
	) AS s8,
	vocabulary v
WHERE v.vocabulary_id = 'NDC';

DROP VIEW prod;

--13. Add NDC to MAIN_NDC from rxnconso
INSERT INTO main_ndc (
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
SELECT DISTINCT TRIM(SUBSTR(c.str, 1, 255)) AS concept_name,
	'Drug' AS domain_id,
	'NDC' AS vocabulary_id,
	'11-digit NDC' AS concept_class_id,
	NULL AS standard_concept,
	s.atv AS concept_code,
	latest_update AS valid_start_date,
	TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.rxnsat s
JOIN sources.rxnconso c ON c.sab = 'RXNORM'
	AND c.rxaui = s.rxaui
	AND c.rxcui = s.rxcui
JOIN vocabulary v ON v.vocabulary_id = 'NDC'
WHERE s.sab = 'RXNORM'
	AND s.atn = 'NDC';

CREATE INDEX idx_main_ndc ON main_ndc (concept_code);
ANALYZE main_ndc;

--14. Add additional NDC with fresh dates and active mapping to RxCUI (source: http://rxnav.nlm.nih.gov/REST/ndcstatus?history=1&ndc=xxx) [part 1 of 3]
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
SELECT TRIM(SUBSTR(concept_name, 1, 255)) AS concept_name,
	'Drug' AS domain_id,
	'NDC' AS vocabulary_id,
	'11-digit NDC' AS concept_class_id,
	NULL AS standard_concept,
	concept_code,
	startDate AS valid_start_date,
	endDate AS valid_end_date,
	invalid_reason
FROM (
	SELECT n.concept_code,
		n.startDate,
		n.endDate,
		n.invalid_reason,
		coalesce(mn.concept_name, c.concept_name, max(spl.concept_name)) concept_name
	FROM (
		SELECT ndc.concept_code,
			startDate,
			CASE 
				WHEN LOWER(STATUS) = 'active'
					THEN to_date('20991231', 'yyyymmdd')
				ELSE endDate
				END endDate,
			CASE 
				WHEN LOWER(STATUS) = 'active'
					THEN NULL
				ELSE 'D'
				END AS invalid_reason
		FROM apigrabber.ndc_history ndc
		WHERE ndc.activeRxcui = (
				SELECT ndc_int.activeRxcui
				FROM apigrabber.ndc_history ndc_int,
					concept c_int
				WHERE c_int.vocabulary_id = 'RxNorm'
					AND ndc_int.activeRxcui = c_int.concept_code
					AND ndc_int.concept_code = ndc.concept_code
				ORDER BY c_int.invalid_reason NULLS FIRST,
					c_int.valid_start_date DESC,
					CASE c_int.concept_class_id
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
						ELSE 7
						END,
					c_int.concept_id limit 1
				)
		) n
	LEFT JOIN main_ndc mn ON mn.concept_code = n.concept_code
		AND mn.vocabulary_id = 'NDC' --first search name in old sources
	LEFT JOIN concept c ON c.concept_code = n.concept_code
		AND c.vocabulary_id = 'NDC' --search name in concept
	LEFT JOIN sources.spl2ndc_mappings s ON n.concept_code = s.ndc_code --take name from SPL
	LEFT JOIN sources.spl_ext spl ON spl.concept_code = s.concept_code
	GROUP BY n.concept_code,
		n.startDate,
		n.endDate,
		n.invalid_reason,
		mn.concept_name,
		c.concept_name
	) AS s0
WHERE concept_name IS NOT NULL;

--15. Add additional NDC with fresh dates from the ndc_history where NDC have't activerxcui (same source). Take dates from coalesce(NDC API, big XML (SPL), MAIN_NDC, concept, default dates)
CREATE OR REPLACE FUNCTION CheckNDCDate (pDate IN VARCHAR, pDateDefault IN DATE) RETURNS DATE
AS
$BODY$
DECLARE
	iDate DATE;
BEGIN
	RETURN COALESCE (TO_DATE (pDate, 'YYYYMMDD'), pDateDefault);
	EXCEPTION WHEN OTHERS THEN
	RETURN pDateDefault;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER;

WITH ADDITIONALNDCINFO
AS (
	SELECT concept_code,
		coalesce(startdate, min(l.ndc_valid_start_date)) valid_start_date,
		coalesce(enddate, max(h.ndc_valid_end_date)) valid_end_date,
		TRIM(SUBSTR(coalesce(c_name1, c_name2, max(spl_name)), 1, 255)) concept_name
	FROM (
		SELECT n.concept_code,
			n.startdate,
			n.enddate,
			spl.low_value,
			spl.high_value,
			mn.concept_name c_name1,
			c.concept_name c_name2,
			spl.concept_name spl_name,
			mn.valid_start_date c_st_date1,
			mn.valid_end_date c_end_date1,
			c.valid_start_date c_st_date2,
			c.valid_end_date c_end_date2
		FROM apigrabber.ndc_history n
		LEFT JOIN main_ndc mn ON mn.concept_code = n.concept_code
			AND mn.vocabulary_id = 'NDC'
		LEFT JOIN concept c ON c.concept_code = n.concept_code
			AND c.vocabulary_id = 'NDC'
		LEFT JOIN sources.spl2ndc_mappings s ON n.concept_code = s.ndc_code
		LEFT JOIN sources.spl_ext spl ON spl.concept_code = s.concept_code
		WHERE n.activerxcui IS NULL
		) n,
		lateral(SELECT min(ndc_valid_start_date) AS ndc_valid_start_date FROM (
			SELECT CheckNDCDate(min(low_val), coalesce(n.c_st_date1, n.c_st_date2, to_date('19700101', 'YYYYMMDD'))) AS ndc_valid_start_date
			FROM (
				SELECT UNNEST(regexp_matches(n.low_value, '[^;]+', 'g')) AS low_val
				) AS s0
			) AS s1) l,
		lateral(SELECT max(ndc_valid_end_date) AS ndc_valid_end_date FROM (
			SELECT CheckNDCDate(max(high_val), coalesce(n.c_end_date1, n.c_end_date2, to_date('20991231', 'YYYYMMDD'))) AS ndc_valid_end_date
			FROM (
				SELECT UNNEST(regexp_matches(n.high_value, '[^;]+', 'g')) AS high_val
				) AS s2
			) AS s3) h
	GROUP BY concept_code,
		startdate,
		enddate,
		c_name1,
		c_name2
	)
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
SELECT concept_name,
	'Drug' AS domain_id,
	'NDC' AS vocabulary_id,
	LENGTH(concept_code) || '-digit NDC' AS concept_class_id,
	NULL AS standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	CASE 
		WHEN valid_end_date = TO_DATE('20991231', 'yyyymmdd')
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM additionalndcinfo
WHERE concept_name IS NOT NULL;

--16. Create temporary table for NDC mappings to RxNorm (source: http://rxnav.nlm.nih.gov/REST/rxcui/xxx/allndcs?history=1)
DROP TABLE IF EXISTS rxnorm2ndc_mappings_ext;
CREATE UNLOGGED TABLE rxnorm2ndc_mappings_ext AS
SELECT concept_code,
	ndc_code,
	startDate,
	endDate,
	invalid_reason,
	COALESCE(c_name1, c_name2, last_rxnorm_name) concept_name
FROM (
	SELECT DISTINCT mp.concept_code,
		mn.concept_name c_name1,
		c.concept_name c_name2,
		last_value(rxnorm.concept_name) OVER (
			PARTITION BY mp.ndc_code ORDER BY rxnorm.valid_start_date,
				rxnorm.concept_id rows BETWEEN unbounded preceding
					AND unbounded following
			) last_rxnorm_name,
		mp.startDate,
		mp.ndc_code,
		CASE 
			WHEN mp.endDate = mp.max_end_date
				THEN TO_DATE('20991231', 'yyyymmdd')
			ELSE mp.endDate
			END endDate,
		CASE 
			WHEN mp.endDate = mp.max_end_date
				THEN NULL
			ELSE 'D'
			END invalid_reason
	FROM (
		SELECT concept_code,
			ndc_code,
			startDate,
			endDate,
			max(endDate) OVER () max_end_date
		FROM apigrabber.rxnorm2ndc_mappings
		) mp
	LEFT JOIN main_ndc mn ON mn.concept_code = mp.ndc_code
		AND mn.vocabulary_id = 'NDC' --first search name in old sources
	LEFT JOIN concept c ON c.concept_code = mp.ndc_code
		AND c.vocabulary_id = 'NDC' --search name in concept
	LEFT JOIN concept rxnorm ON rxnorm.concept_code = mp.concept_code
		AND rxnorm.vocabulary_id = 'RxNorm' --take name from RxNorm
	) AS s0;

--17. Add additional NDC with fresh dates from previous temporary table (RXNORM2NDC_MAPPINGS_EXT) [part 3 of 3]
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
SELECT DISTINCT concept_name,
	'Drug' AS domain_id,
	'NDC' AS vocabulary_id,
	'11-digit NDC' AS concept_class_id,
	NULL AS standard_concept,
	ndc_code AS concept_code,
	first_value(startDate) OVER (
		PARTITION BY ndc_code ORDER BY startDate rows BETWEEN unbounded preceding
				AND unbounded following
		) AS valid_start_date,
	last_value(endDate) OVER (
		PARTITION BY ndc_code ORDER BY endDate rows BETWEEN unbounded preceding
				AND unbounded following
		) AS valid_end_date,
	last_value(invalid_reason) OVER (
		PARTITION BY ndc_code ORDER BY endDate rows BETWEEN unbounded preceding
				AND unbounded following
		) AS invalid_reason
FROM rxnorm2ndc_mappings_ext m
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = m.ndc_code
			AND cs_int.vocabulary_id = 'NDC'
		);

--18. Add all other NDC from 'product'
INSERT INTO concept_stage
SELECT *
FROM main_ndc m
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = m.concept_code
			AND cs_int.vocabulary_id = 'NDC'
		);

--19. Add mapping from SPL to RxNorm through RxNorm API (source: http://rxnav.nlm.nih.gov/REST/rxcui/xxx/property?propName=SPL_SET_ID)
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
SELECT spl_code AS concept_code_1,
	concept_code AS concept_code_2,
	'SPL' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'SPL - RxNorm' AS relationship_id,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM apigrabber.rxnorm2spl_mappings rm
WHERE spl_code IS NOT NULL
	AND NOT EXISTS (
		SELECT 1
		FROM concept c
		WHERE c.concept_code = rm.concept_code
			AND c.vocabulary_id = 'RxNorm'
			AND c.concept_class_id = 'Ingredient'
		);

--20. Add mapping from SPL to RxNorm through rxnsat
ANALYZE concept_relationship_stage;
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
SELECT DISTINCT a.atv AS concept_code_1,
	b.code AS concept_code_2,
	'SPL' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'SPL - RxNorm' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.rxnsat a
JOIN sources.rxnsat b ON a.rxcui = b.rxcui
JOIN vocabulary v ON v.vocabulary_id = 'SPL'
WHERE a.sab = 'MTHSPL'
	AND a.atn = 'SPL_SET_ID'
	AND b.sab = 'RXNORM'
	AND b.atn = 'RXN_HUMAN_DRUG'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = a.atv
			AND crs_int.concept_code_2 = b.code
			AND crs_int.relationship_id = 'SPL - RxNorm'
			AND crs_int.vocabulary_id_1 = 'SPL'
			AND crs_int.vocabulary_id_2 = 'RxNorm'
		);

--21. Add mapping from NDC to RxNorm from rxnconso
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
SELECT DISTINCT s.atv AS concept_code_1,
	c.rxcui AS concept_code_2,
	'NDC' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE ('20991231', 'yyyymmdd')AS valid_end_date,
	NULL AS invalid_reason
FROM sources.rxnsat s
JOIN sources.rxnconso c ON c.sab = 'RXNORM'
	AND c.rxaui = s.rxaui
	AND c.rxcui = s.rxcui
JOIN vocabulary v ON v.vocabulary_id = 'NDC'
WHERE s.sab = 'RXNORM'
	AND s.atn = 'NDC';

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
SELECT first_half || second_half AS concept_code_1,
	concept_code_2,
	'NDC' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	valid_start_date,
	TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT CASE 
			WHEN devv5.INSTR(productndc, '-') = 5
				THEN '0' || SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
			ELSE SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
			END AS first_half,
		CASE 
			WHEN LENGTH(SUBSTR(productndc, devv5.INSTR(productndc, '-'))) = 4
				THEN '0' || SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
			ELSE SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
			END AS second_half,
		v.latest_update AS valid_start_date,
		r.rxcui AS concept_code_2 -- RxNorm concept_code
	FROM sources.product p
	JOIN sources.rxnconso c ON c.code = p.productndc
		AND c.sab = 'MTHSPL'
	JOIN sources.rxnconso r ON r.rxcui = c.rxcui
		AND r.sab = 'RXNORM'
	JOIN vocabulary v ON v.vocabulary_id = 'NDC'
	) AS s0;

--22. Add additional mapping for NDC codes 
--The 9-digit NDC codes that have no mapping can be mapped to the same concept of the 11-digit NDC codes, if all 11-digit NDC codes agree on the same destination Concept

CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
CREATE INDEX IF NOT EXISTS trgm_crs_idx ON concept_relationship_stage USING GIN (concept_code_1 devv5.gin_trgm_ops); --for LIKE patterns
ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

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
SELECT concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM (
	SELECT concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		/*PG doesn't support COUNT (DISTINCT concept_code_2) OVER (partition by concept_code_1) -> "Use of DISTINCT is not allowed with the OVER clause"
		so replacing with nice trick with dense_rank()
		*/
		(
			dense_rank() OVER (
				PARTITION BY concept_code_1 ORDER BY concept_code_2
				) + dense_rank() OVER (
				PARTITION BY concept_code_1 ORDER BY concept_code_2 DESC
				) - 1
			) cnt
	FROM (
		SELECT t.concept_code_9 AS concept_code_1,
			r.concept_code_2 AS concept_code_2,
			r.vocabulary_id_1 AS vocabulary_id_1,
			r.vocabulary_id_2 AS vocabulary_id_2,
			r.relationship_id AS relationship_id,
			r.valid_start_date AS valid_start_date,
			r.valid_end_date AS valid_end_date,
			r.invalid_reason AS invalid_reason
		FROM concept_relationship_stage r,
			(
				SELECT c.concept_code AS concept_code_9
				FROM concept_stage c,
					concept_stage c1
				WHERE c.vocabulary_id = 'NDC'
					AND c.concept_class_id = '9-digit NDC'
					AND c1.concept_code LIKE c.concept_code || '%'
					AND c1.vocabulary_id = 'NDC'
					AND c1.concept_class_id = '11-digit NDC'
					AND NOT EXISTS (
						SELECT 1
						FROM concept_relationship_stage r_int
						WHERE r_int.concept_code_1 = c.concept_code
							AND r_int.vocabulary_id_1 = c.vocabulary_id
						)
				) t
		WHERE r.concept_code_1 LIKE t.concept_code_9 || '%'
			AND r.vocabulary_id_1 = 'NDC'
			AND r.relationship_id = 'Maps to'
			AND r.vocabulary_id_2 = 'RxNorm'
		GROUP BY t.concept_code_9,
			r.concept_code_2,
			r.vocabulary_id_1,
			r.vocabulary_id_2,
			r.relationship_id,
			r.valid_start_date,
			r.valid_end_date,
			r.invalid_reason
		) AS s0
	) AS s1
WHERE cnt = 1;

DROP INDEX trgm_idx;
DROP INDEX trgm_crs_idx;

--23. MERGE concepts from fresh sources (RXNORM2NDC_MAPPINGS_EXT). Add/merge only fresh mappings (even if rxnorm2ndc_mappings_ext gives us deprecated mappings we put them as fresh: redmine #70209)
WITH to_be_upserted
AS (
	SELECT DISTINCT ndc_code,
		last_value(concept_code) OVER (
			PARTITION BY ndc_code ORDER BY invalid_reason nulls last,
				startDate rows BETWEEN unbounded preceding
					AND unbounded following
			) AS concept_code,
		last_value(startDate) OVER (
			PARTITION BY ndc_code ORDER BY invalid_reason nulls last,
				startDate rows BETWEEN unbounded preceding
					AND unbounded following
			) AS startDate,
		last_value(invalid_reason) OVER (
			PARTITION BY ndc_code ORDER BY invalid_reason nulls last,
				startDate rows BETWEEN unbounded preceding
					AND unbounded following
			) AS invalid_reason
	FROM rxnorm2ndc_mappings_ext
	),
to_be_updated
AS (
	UPDATE concept_relationship_stage crs
	SET valid_start_date = up.startdate,
		valid_end_date = TO_DATE('20991231', 'yyyymmdd'),
		invalid_reason = NULL
	FROM to_be_upserted up
	WHERE crs.concept_code_1 = up.ndc_code
		AND crs.concept_code_2 = up.concept_code
		AND crs.relationship_id = 'Maps to'
		AND crs.vocabulary_id_1 = 'NDC'
		AND crs.vocabulary_id_2 = 'RxNorm'
		AND up.invalid_reason IS NULL RETURNING crs.*
	)
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
SELECT tpu.ndc_code,
	tpu.concept_code,
	'NDC',
	'RxNorm',
	'Maps to',
	tpu.startdate,
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM to_be_upserted tpu
WHERE (
		tpu.ndc_code,
		tpu.concept_code,
		'NDC',
		'RxNorm',
		'Maps to'
		) NOT IN (
		SELECT up.concept_code_1,
			up.concept_code_2,
			up.vocabulary_id_1,
			up.vocabulary_id_2,
			up.relationship_id
		FROM to_be_updated up
		
		UNION ALL
		
		SELECT crs_int.concept_code_1,
			crs_int.concept_code_2,
			crs_int.vocabulary_id_1,
			crs_int.vocabulary_id_2,
			crs_int.relationship_id
		FROM concept_relationship_stage crs_int
		WHERE crs_int.relationship_id = 'Maps to'
			AND crs_int.vocabulary_id_1 = 'NDC'
			AND crs_int.vocabulary_id_2 = 'RxNorm'
		);

--24. Add manual source
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--25. Delete duplicate mappings to packs

--25.1. Deprecate 'Maps to' mappings to deprecated and upgraded concepts (necessary for the next step)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--25.2. Add mapping from deprecated to fresh concepts (necessary for the next step)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--25.3 Do it
DELETE
FROM concept_relationship_stage r
WHERE r.relationship_id = 'Maps to'
	AND r.invalid_reason IS NULL
	AND r.vocabulary_id_1 = 'NDC'
	AND r.vocabulary_id_2 LIKE 'RxNorm%'
	AND concept_code_1 IN (
		--get all duplicate NDC mappings
		SELECT concept_code_1
		FROM concept_relationship_stage r_int
		WHERE r_int.relationship_id = 'Maps to'
			AND r_int.invalid_reason IS NULL
			AND r_int.vocabulary_id_1 = 'NDC'
			AND r_int.vocabulary_id_2 LIKE 'RxNorm%'
			--at least one mapping to pack should exist
			AND EXISTS (
				SELECT 1
				FROM concept c_int
				WHERE c_int.concept_code = r_int.concept_code_2
					AND c_int.vocabulary_id LIKE 'RxNorm%'
					AND c_int.concept_class_id IN (
						'Branded Pack',
						'Clinical Pack',
						'Quant Branded Drug',
						'Quant Clinical Drug',
						'Branded Drug',
						'Clinical Drug'
						)
				)
		GROUP BY concept_code_1
		HAVING count(*) > 1
		)
	AND concept_code_2 NOT IN (
		--exclude 'true' mappings to packs [Branded->Clinical->etc]
		SELECT c_int.concept_code
		FROM concept_relationship_stage r_int,
			concept c_int
		WHERE r_int.relationship_id = 'Maps to'
			AND r_int.invalid_reason IS NULL
			AND r_int.vocabulary_id_1 = r.vocabulary_id_1
			AND r_int.vocabulary_id_2 LIKE 'RxNorm%'
			AND c_int.concept_code = r_int.concept_code_2
			AND c_int.vocabulary_id = r_int.vocabulary_id_2
			AND r_int.concept_code_1 = r.concept_code_1
		ORDER BY c_int.invalid_reason NULLS FIRST,
			c_int.standard_concept DESC NULLS LAST, --'S' first, next 'C' and NULL
			CASE c_int.concept_class_id
				WHEN 'Branded Pack'
					THEN 1
				WHEN 'Clinical Pack'
					THEN 2
				WHEN 'Quant Branded Drug'
					THEN 3
				WHEN 'Quant Clinical Drug'
					THEN 4
				WHEN 'Branded Drug'
					THEN 5
				WHEN 'Clinical Drug'
					THEN 6
				ELSE 7
				END,
			CASE r_int.vocabulary_id_2
				WHEN 'RxNorm'
					THEN 1
				ELSE 2
				END, --mappings to RxNorm first
			c_int.valid_start_date DESC,
			c_int.concept_id LIMIT 1
		);

--26. Add PACKAGES
ANALYZE concept_stage;
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
WITH ndc AS (
		SELECT DISTINCT CASE 
				WHEN devv5.INSTR(productndc, '-') = 5
					THEN '0' || SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
				ELSE SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
				END || CASE 
				WHEN LENGTH(SUBSTR(productndc, devv5.INSTR(productndc, '-'))) = 4
					THEN '0' || SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
				ELSE SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
				END AS concept_code,
			productndc
		FROM sources.product
		)
SELECT DISTINCT cs.concept_name,
	cs.domain_id,
	cs.vocabulary_id,
	'11-digit NDC' AS concept_class_id,
	NULL AS standard_concept,
	p.pack_code,
	min(startmarketingdate) OVER (PARTITION BY p.pack_code) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM ndc n
JOIN concept_stage cs ON cs.concept_code = n.concept_code
	AND cs.vocabulary_id = 'NDC'
JOIN sources.package p ON p.productndc = n.productndc
LEFT JOIN concept_stage cs1 ON cs1.concept_code = p.pack_code
	AND cs1.vocabulary_id = 'NDC'
WHERE cs1.concept_code IS NULL;

--27. Add relationships (take from 9-digit NDC codes), but only new
ANALYZE concept_relationship_stage;
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
WITH ndc AS (
		SELECT DISTINCT CASE 
				WHEN devv5.INSTR(productndc, '-') = 5
					THEN '0' || SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
				ELSE SUBSTR(productndc, 1, devv5.INSTR(productndc, '-') - 1)
				END || CASE 
				WHEN LENGTH(SUBSTR(productndc, devv5.INSTR(productndc, '-'))) = 4
					THEN '0' || SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
				ELSE SUBSTR(productndc, devv5.INSTR(productndc, '-') + 1)
				END AS concept_code,
			productndc
		FROM sources.product
		)
SELECT DISTINCT p.pack_code AS concept_code_1,
	crs.concept_code_2,
	'NDC' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	crs.valid_start_date,
	crs.valid_end_date,
	crs.invalid_reason
FROM ndc n
JOIN concept_relationship_stage crs ON crs.concept_code_1 = n.concept_code
	AND crs.vocabulary_id_1 = 'NDC'
	AND crs.vocabulary_id_2 = 'RxNorm'
JOIN sources.package p ON p.productndc = n.productndc
LEFT JOIN concept_relationship_stage crs1 ON crs1.concept_code_1 = p.pack_code
	AND crs1.vocabulary_id_1 = 'NDC'
	AND crs1.vocabulary_id_2 = 'RxNorm'
WHERE crs1.concept_code_1 IS NULL;

--28. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

/*--29. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--30. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;*/

--29. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--30. Delete records that does not exists in the concept and concept_stage
DELETE
FROM concept_relationship_stage crs
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		LEFT JOIN concept c1 ON c1.concept_code = crs_int.concept_code_1
			AND c1.vocabulary_id = crs_int.vocabulary_id_1
		LEFT JOIN concept_stage cs1 ON cs1.concept_code = crs_int.concept_code_1
			AND cs1.vocabulary_id = crs_int.vocabulary_id_1
		LEFT JOIN concept c2 ON c2.concept_code = crs_int.concept_code_2
			AND c2.vocabulary_id = crs_int.vocabulary_id_2
		LEFT JOIN concept_stage cs2 ON cs2.concept_code = crs_int.concept_code_2
			AND cs2.vocabulary_id = crs_int.vocabulary_id_2
		WHERE (
				(
					c1.concept_code IS NULL
					AND cs1.concept_code IS NULL
					)
				OR (
					c2.concept_code IS NULL
					AND cs2.concept_code IS NULL
					)
				)
			AND crs_int.concept_code_1 = crs.concept_code_1
			AND crs_int.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs_int.concept_code_2 = crs.concept_code_2
			AND crs_int.vocabulary_id_2 = crs.vocabulary_id_2
		);

--31. Set proper concept_class_id (Device)
UPDATE concept_stage
SET concept_class_id = 'Device',
	domain_id = 'Device',
	standard_concept='S'
WHERE concept_name ~* 'PUMP |METER |LANCET|DEVICE|PEDIALYTE|SUNSCREEN|NEEDLE|MONITOR|FREEDOM|BLOOD GLUCOSE|STERI-STRIP|HUGGIES|GAUZE|STOCKING|DEPEND|CHAMBER|COMPRESSR|COMPRESSOR|NEBULIZER|FREESTYLE|SHARPS|ACCU-CHEK|ELECTROLYTE| TRAY|WAVESENSE|DEPEND|EASY TOUCH|MONIT|ENSURE|XEROFORM|PCCA|REAGENT|UNDERWEAR|CONTOUR|UNDERPAD|UNDERPAD|TRANSMITTER|GX|STERILE PADS|POISE PADS|GLUCERNA|PENTIP|MONOJECT|INSULIN SYR|DIAPHRAGM|PCCA|BD INSULIN|PEDIASURE|BD SYR|SIMILAC|OMNIPOD| DRINK|DRESS|ORALYTE|NUTRAMIGEN|REAGENT STRIPS|CONDOMS|INNOSPIRE|TEST STRIPS|CONDOM|DIAPHRAGM|CLEAR SHAMPOO|HEATWRAP|VAPORIZER|UNDERPANTS|HUMIDIFIER'::TEXT
	AND NOT concept_name ~* 'INTRAUTERINE|ZINC OXIDE|OXYMETAZOLINE|BENZ|BUPROPION|ALBUTEROL|MONOJECT|DIMETHICONE|PINE NEEDLE|HYDROQUIONONE|3350 '
	AND concept_code NOT IN (
		'547760002',
		'547760005'
		)
	AND vocabulary_id = 'NDC';

--After first update we will have these codes as 'Device' in the concept. So we might return classes from the concept in future
UPDATE concept_stage cs
SET concept_class_id = 'Device',
	domain_id = 'Device',
	standard_concept='S'
FROM concept c
WHERE cs.concept_code = c.concept_code
	AND cs.vocabulary_id = 'NDC'
	AND cs.concept_class_id <> 'Device'
	AND c.vocabulary_id = 'NDC'
	AND c.concept_class_id = 'Device';

--Some devices, that cannot be detected using the patterns
UPDATE concept_stage
SET concept_class_id = 'Device',
	domain_id = 'Device',
	standard_concept = 'S'
WHERE concept_code IN (
		'00019960110',
		'00019960220',
		'17156020105',
		'17156052205',
		'488151001',
		'651740461',
		'50914773104',
		'48815100101',
		'48815100105',
		'488151002',
		'48815100201',
		'48815100205',
		'509147720',
		'50914772008',
		'65174046105',
		'699450601',
		'69945060110',
		'699450602',
		'69945060220',
		'91237000148',
		'91237000144',
		'509147731'
		)
	AND vocabulary_id = 'NDC';

/*Put your updates here..
	UPDATE concept_stage SET concept_class_id = 'Device', domain_id = 'Device', standard_concept='S' WHERE concept_code in ('x','y');
*/
/*
UPDATE concept_stage cs
SET concept_class_id = 'Device',
	domain_id = 'Device',
	standard_concept='S'
FROM ndc_devices i
WHERE cs.concept_code = i.concept_code
	AND cs.concept_class_id <> 'Device';
*/

--32. Return proper valid_end_date from base tables
UPDATE concept_relationship_stage crs
SET valid_start_date = i.valid_start_date,
	valid_end_date = i.valid_end_date
FROM (
	SELECT c1.concept_code AS concept_code_1,
		c1.vocabulary_id AS vocabulary_id_1,
		c2.concept_code AS concept_code_2,
		c2.vocabulary_id AS vocabulary_id_2,
		r.relationship_id,
		r.valid_start_date,
		r.valid_end_date
	FROM concept_relationship r
	JOIN concept c1 ON c1.concept_id = r.concept_id_1
	JOIN concept c2 ON c2.concept_id = r.concept_id_2
	WHERE r.invalid_reason IS NOT NULL
	) i
WHERE crs.concept_code_1 = i.concept_code_1
	AND crs.vocabulary_id_1 = i.vocabulary_id_1
	AND crs.concept_code_2 = i.concept_code_2
	AND crs.vocabulary_id_2 = i.vocabulary_id_2
	AND crs.relationship_id = i.relationship_id
	AND crs.valid_end_date <> i.valid_end_date
	AND crs.invalid_reason IS NOT NULL;

--33. Clean up
DROP FUNCTION GetAggrDose (active_numerator_strength IN VARCHAR, active_ingred_unit IN VARCHAR);
DROP FUNCTION GetDistinctDose (active_numerator_strength IN VARCHAR, active_ingred_unit IN VARCHAR, p IN INT);
DROP FUNCTION CheckNDCDate (pDate IN VARCHAR, pDateDefault IN DATE);
DROP TABLE main_ndc;
DROP TABLE rxnorm2ndc_mappings_ext;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
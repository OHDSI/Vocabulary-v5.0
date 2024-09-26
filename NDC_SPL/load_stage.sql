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
* Date: 2021
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
LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;

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
				UNNEST(regexp_matches(active_numerator_strength, '[^; ]+', 'g')) a_n_s,--::numeric::varchar a_n_s, --double cast to convert corrupted values e.g. '.7' to 0.7 (numeric) and then back to a text value /*disabled atm*/
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
LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;

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
SELECT vocabulary_pack.CutConceptName(spl_name) AS concept_name,
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
	NULL AS standard_concept,
	replaced_spl AS concept_code,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	spl_date - 1 AS valid_end_date,
	'U' AS invalid_reason
FROM (
	SELECT DISTINCT FIRST_VALUE(COALESCE(s2.concept_name, c.concept_name)) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date,
				s.concept_code ROWS BETWEEN unbounded preceding
					AND UNBOUNDED FOLLOWING
			) spl_name,
		FIRST_VALUE(s.displayname) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date,
				s.concept_code ROWS BETWEEN unbounded preceding
					AND UNBOUNDED FOLLOWING
			) displayname,
		FIRST_VALUE(s.valid_start_date) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date ROWS BETWEEN unbounded preceding
					AND UNBOUNDED FOLLOWING
			) spl_date,
		l.replaced_spl
	FROM (
		SELECT s_int.concept_code,
			s_int.replaced_spl,
			s_int.displayname,
			MIN(s_int.valid_start_date) AS valid_start_date
		FROM sources.spl_ext s_int
		WHERE s_int.replaced_spl IS NOT NULL -- if there is an SPL codes ( l ) that is mentioned in another record as replaced_spl (path /document/relatedDocument/relatedDocument/setId/@root)
		GROUP BY s_int.concept_code,
			s_int.replaced_spl,
			s_int.displayname
		) s
	CROSS JOIN LATERAL(SELECT UNNEST(regexp_matches(s.replaced_spl, '[^;]+', 'g')) AS replaced_spl) l
	LEFT JOIN concept c ON c.vocabulary_id = 'SPL'
		AND c.concept_code = l.replaced_spl
	LEFT JOIN sources.spl_ext s2 ON s2.concept_code = l.replaced_spl
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
SELECT vocabulary_pack.CutConceptName(concept_name) concept_name,
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
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT ON (s_int.concept_code)
		s_int.concept_code,
		s_int.concept_name,
		s_int.displayname,
		s_int.valid_start_date
	FROM sources.spl_ext s_int
	ORDER BY s_int.concept_code,
		s_int.valid_start_date DESC
	) s
WHERE displayname NOT IN (
		'IDENTIFICATION OF CBER-REGULATED GENERIC DRUG FACILITY',
		'INDEXING - PHARMACOLOGIC CLASS',
		'INDEXING - SUBSTANCE',
		'WHOLESALE DRUG DISTRIBUTORS AND THIRD-PARTY LOGISTICS FACILITY REPORT'
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE LOWER(s.concept_code) = LOWER(cs_int.concept_code)
		);

--6. Load other SPL into concept_stage (from 'product')
CREATE OR REPLACE VIEW prod --for using INDEX 'idx_f_product'
AS
(
		SELECT SUBSTR(productid, devv5.INSTR(productid, '_') + 1) AS concept_code,
			dosageformname,
			routename,
			proprietaryname,
			nonproprietaryname,
			TRIM(proprietarynamesuffix) AS proprietarynamesuffix,
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
					THEN vocabulary_pack.CutConceptName(concept_name)
				ELSE vocabulary_pack.CutConceptName(CONCAT (
								TRIM(concept_name),
								' [',
								brand_name,
								']'
								))
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
				CASE 
					WHEN multi_nonproprietaryname IS NULL
						THEN CONCAT (
								SUBSTR(nonproprietaryname, 1, 100),
								CASE 
									WHEN LENGTH(nonproprietaryname) > 100
										THEN '...'
									END,
								' ' || TRIM(SUBSTR(aggr_dose, 1, 100)),
								' ' || TRIM(SUBSTR(routename, 1, 100)),
								' ',
								TRIM(SUBSTR(dosageformname, 1, 100))
								)
					ELSE CONCAT (
							'Multiple formulations: ',
							SUBSTR(nonproprietaryname, 1, 100),
							CASE 
								WHEN LENGTH(nonproprietaryname) > 100
									THEN '...'
								END,
							' ' || TRIM(SUBSTR(aggr_dose, 1, 100)),
							' ' || TRIM(SUBSTR(routename, 1, 100)),
							' ',
							TRIM(SUBSTR(dosageformname, 1, 100))
							)
					END AS concept_name,
				vocabulary_pack.CutConceptName(brand_name) AS brand_name,
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
								STRING_AGG(active_numerator_strength, '; ' ORDER BY CONCAT (
										active_numerator_strength,
										active_ingred_unit
										)) AS active_numerator_strength,
								STRING_AGG(active_ingred_unit, '; ' ORDER BY CONCAT (
										active_numerator_strength,
										active_ingred_unit
										)) AS active_ingred_unit,
								valid_start_date
							FROM (
								SELECT concept_code,
									concept_class_id,
									active_numerator_strength,
									active_ingred_unit,
									MIN(valid_start_date) OVER (PARTITION BY concept_code) AS valid_start_date
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
					--aggregated unique dosageformname
					(
						SELECT STRING_AGG(dosageformname, ', ' ORDER BY dosageformname)
						FROM (
							SELECT DISTINCT p.dosageformname
							FROM prod p
							WHERE p.concept_code = t1.concept_code
							) AS s3
						) AS dosageformname,
					--aggregated unique routename
					(
						SELECT STRING_AGG(routename, ', ' ORDER BY routename)
						FROM (
							SELECT DISTINCT P.routename
							FROM prod p
							WHERE p.concept_code = t1.concept_code
							) AS s4
						) AS routename,
					--aggregated unique nonproprietaryname
					(
						SELECT STRING_AGG(nonproprietaryname, ', ' ORDER BY nonproprietaryname)
						FROM (
							SELECT DISTINCT LOWER(p.nonproprietaryname) nonproprietaryname
							FROM prod p
							WHERE p.concept_code = t1.concept_code
							ORDER BY nonproprietaryname LIMIT 14
							) AS s5
						) AS nonproprietaryname,
					--multiple formulations flag
					(
						SELECT COUNT(LOWER(p.nonproprietaryname))
						FROM prod p
						WHERE p.concept_code = t1.concept_code
						HAVING COUNT(DISTINCT LOWER(p.nonproprietaryname)) > 1
						) AS multi_nonproprietaryname,
					(
						SELECT STRING_AGG(brand_name, ', ' ORDER BY brand_name)
						FROM (
							SELECT DISTINCT CASE 
									WHEN (
											LOWER(proprietaryname) <> LOWER(nonproprietaryname)
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
							ORDER BY brand_name LIMIT 49 --brand_name may be too long for concatenation
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
		WHERE LOWER(s.concept_code) = LOWER(cs_int.concept_code)
		);

--7. Add full SPL names into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT concept_code AS synonym_concept_code,
	'SPL' AS vocabulary_id,
	vocabulary_pack.CutConceptSynonymName(CASE 
				WHEN brand_name IS NULL
					THEN TRIM(long_concept_name)
				ELSE CONCAT (
						TRIM(long_concept_name),
						' [',
						brand_name,
						']'
						)
				END) AS synonym_name,
	4180186 AS language_concept_id -- English
FROM --get unique and aggregated data from source
	(
	SELECT concept_code,
		CASE 
			WHEN multi_nonproprietaryname IS NULL
				THEN CONCAT (
						nonproprietaryname,
						' ' || aggr_dose,
						' ' || routename,
						' ',
						dosageformname
						)
			ELSE CONCAT (
					'Multiple formulations: ',
					nonproprietaryname,
					' ' || aggr_dose,
					' ' || routename,
					' ',
					dosageformname
					)
			END AS long_concept_name,
		vocabulary_pack.CutConceptName(brand_name) AS brand_name
	FROM (
		WITH t AS (
				SELECT concept_code,
					GetAggrDose(active_numerator_strength, active_ingred_unit) aggr_dose
				FROM (
					SELECT concept_code,
						STRING_AGG(active_numerator_strength, '; ' ORDER BY CONCAT (
								active_numerator_strength,
								active_ingred_unit
								)) AS active_numerator_strength,
						STRING_AGG(active_ingred_unit, '; ' ORDER BY CONCAT (
								active_numerator_strength,
								active_ingred_unit
								)) AS active_ingred_unit
					FROM (
						SELECT DISTINCT GetDistinctDose(active_numerator_strength, active_ingred_unit, 1) AS active_numerator_strength,
							GetDistinctDose(active_numerator_strength, active_ingred_unit, 2) AS active_ingred_unit,
							SUBSTR(productid, devv5.INSTR(productid, '_') + 1) AS concept_code
						FROM sources.product
						) AS s0
					GROUP BY concept_code
					) AS s2
				)
		SELECT t1.*,
			--aggregated unique dosageformname
			(
				SELECT STRING_AGG(dosageformname, ', ' ORDER BY dosageformname)
				FROM (
					SELECT DISTINCT p.dosageformname
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					) AS s3
				) AS dosageformname,
			--aggregated unique routename
			(
				SELECT STRING_AGG(routename, ', ' ORDER BY routename)
				FROM (
					SELECT DISTINCT p.routename
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					) AS s4
				) AS routename,
			--aggregated unique nonproprietaryname
			(
				SELECT STRING_AGG(nonproprietaryname, ', ' ORDER BY nonproprietaryname)
				FROM (
					SELECT DISTINCT LOWER(p.nonproprietaryname) nonproprietaryname
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					ORDER BY nonproprietaryname LIMIT 14
					) AS s5
				) AS nonproprietaryname,
			--multiple formulations flag
			(
				SELECT COUNT(LOWER(P.nonproprietaryname))
				FROM prod p
				WHERE p.concept_code = t1.concept_code
				HAVING COUNT(DISTINCT LOWER(P.nonproprietaryname)) > 1
				) AS multi_nonproprietaryname,
			(
				SELECT STRING_AGG(brand_name, ', ' ORDER BY brand_name)
				FROM (
					SELECT DISTINCT CASE 
							WHEN (
									LOWER(proprietaryname) <> LOWER(nonproprietaryname)
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
					ORDER BY brand_name LIMIT 49 --brand_name may be too long for concatenation
					) AS s6
				) AS brand_name
		FROM t t1
		) AS s7
	) s;

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
SELECT replaced_spl AS concept_code_1,
	spl_code AS concept_code_2,
	'SPL' AS vocabulary_id_1,
	'SPL' AS vocabulary_id_2,
	'Concept replaced by' AS relationship_id,
	spl_date - 1 AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT FIRST_VALUE(s.concept_code) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date,
				s.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
					AND UNBOUNDED FOLLOWING
			) spl_code,
		FIRST_VALUE(s.valid_start_date) OVER (
			PARTITION BY l.replaced_spl ORDER BY s.valid_start_date,
				s.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
					AND UNBOUNDED FOLLOWING
			) spl_date,
		l.replaced_spl
	FROM (
		SELECT s_int.concept_code,
			s_int.replaced_spl,
			MIN(s_int.valid_start_date) AS valid_start_date
		FROM sources.spl_ext s_int
		WHERE s_int.replaced_spl IS NOT NULL -- if there is an SPL codes ( l ) that is mentioned in another record as replaced_spl (path /document/relatedDocument/relatedDocument/setId/@root)
		GROUP BY s_int.concept_code,
			s_int.replaced_spl
		) s
	CROSS JOIN LATERAL(SELECT UNNEST(regexp_matches(s.replaced_spl, '[^;]+', 'g')) AS replaced_spl) l
	) AS s0;

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

--8. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO('SPL');
END $_$;

--10. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--12. Load NDC into temporary table from 'product'
DROP TABLE IF EXISTS main_ndc;
CREATE UNLOGGED TABLE main_ndc (
	concept_name TEXT,
	long_concept_name TEXT,
	domain_id TEXT,
	vocabulary_id TEXT,
	concept_class_id TEXT,
	standard_concept TEXT,
	concept_code TEXT,
	valid_start_date DATE,
	valid_end_date DATE,
	invalid_reason TEXT,
	is_diluent BOOLEAN DEFAULT FALSE
	);

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
			TRIM(proprietarynamesuffix) AS proprietarynamesuffix,
			active_numerator_strength,
			active_ingred_unit
		FROM sources.product
		);

INSERT INTO main_ndc
SELECT CASE -- add [brandname] if proprietaryname exists and not identical to nonproprietaryname
		WHEN brand_name IS NULL
			THEN vocabulary_pack.CutConceptName(concept_name)
		ELSE vocabulary_pack.CutConceptName(CONCAT (
						TRIM(concept_name),
						' [',
						brand_name,
						']'
						))
		END AS concept_name,
	CASE -- same for long concept name
		WHEN brand_name IS NULL
			THEN TRIM(long_concept_name)
		ELSE CONCAT (
				TRIM(long_concept_name),
				' [',
				brand_name,
				']'
				)
		END AS long_concept_name,
	'Drug' AS domain_id,
	'NDC' AS vocabulary_id,
	'9-digit NDC' AS concept_class_id,
	NULL AS standard_concept,
	concept_code,
	COALESCE(valid_start_date, latest_update) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	is_diluent
FROM --get unique and aggregated data from source
	(
	SELECT concept_code,
		CASE 
			WHEN multi_nonproprietaryname IS NULL
				THEN CONCAT (
						SUBSTR(nonproprietaryname, 1, 100),
						CASE 
							WHEN LENGTH(nonproprietaryname) > 100
								THEN '...'
							END,
						' ' || TRIM(SUBSTR(aggr_dose, 1, 100)),
						' ' || TRIM(SUBSTR(routename, 1, 100)),
						' ',
						TRIM(SUBSTR(dosageformname, 1, 100))
						)
			ELSE CONCAT (
					'Multiple formulations: ',
					SUBSTR(nonproprietaryname, 1, 100),
					CASE 
						WHEN LENGTH(nonproprietaryname) > 100
							THEN '...'
						END,
					' ' || TRIM(SUBSTR(aggr_dose, 1, 100)),
					' ' || TRIM(SUBSTR(routename, 1, 100)),
					' ',
					TRIM(SUBSTR(dosageformname, 1, 100))
					)
			END AS concept_name,
		CASE 
			WHEN multi_nonproprietaryname IS NULL
				THEN CONCAT (
						nonproprietaryname,
						' ' || aggr_dose,
						' ' || routename,
						' ',
						dosageformname
						)
			ELSE CONCAT (
					'Multiple formulations: ',
					nonproprietaryname,
					' ' || aggr_dose,
					' ' || routename,
					' ',
					dosageformname
					)
			END AS long_concept_name,
		vocabulary_pack.CutConceptName(brand_name) AS brand_name,
		valid_start_date,
		is_diluent
	FROM (
		WITH t AS (
				SELECT concept_code,
					valid_start_date,
					GetAggrDose(active_numerator_strength, active_ingred_unit) aggr_dose,
					is_diluent
				FROM (
					SELECT concept_code,
						STRING_AGG(active_numerator_strength, '; ' ORDER BY CONCAT (
								active_numerator_strength,
								active_ingred_unit
								)) AS active_numerator_strength,
						STRING_AGG(active_ingred_unit, '; ' ORDER BY CONCAT (
								active_numerator_strength,
								active_ingred_unit
								)) AS active_ingred_unit,
						valid_start_date,
						is_diluent
					FROM (
						SELECT concept_code,
							active_numerator_strength,
							active_ingred_unit,
							MIN(valid_start_date) OVER (PARTITION BY concept_code) AS valid_start_date,
							is_diluent
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
								startmarketingdate AS valid_start_date,
								CASE 
									WHEN proprietaryname ILIKE '%diluent%' 
										THEN TRUE 
									ELSE FALSE
									END AS is_diluent
							FROM sources.product
							) AS s0
						GROUP BY concept_code,
							active_numerator_strength,
							active_ingred_unit,
							valid_start_date,
							is_diluent
						) AS s1
					GROUP BY concept_code,
						valid_start_date,
						is_diluent
					) AS s2
				)
		SELECT t1.*,
			--aggregated unique dosageformname
			(
				SELECT STRING_AGG(dosageformname, ', ' ORDER BY dosageformname)
				FROM (
					SELECT DISTINCT p.dosageformname
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					) AS s3
				) AS dosageformname,
			--aggregated unique routename
			(
				SELECT STRING_AGG(routename, ', ' ORDER BY routename)
				FROM (
					SELECT DISTINCT p.routename
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					) AS s4
				) AS routename,
			--aggregated unique nonproprietaryname
			(
				SELECT STRING_AGG(nonproprietaryname, ', ' ORDER BY nonproprietaryname)
				FROM (
					SELECT DISTINCT LOWER(p.nonproprietaryname) nonproprietaryname
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					ORDER BY nonproprietaryname LIMIT 14
					) AS s5
				) AS nonproprietaryname,
			--multiple formulations flag
			(
				SELECT COUNT(LOWER(p.nonproprietaryname))
				FROM prod p
				WHERE p.concept_code = t1.concept_code
				HAVING COUNT(DISTINCT LOWER(p.nonproprietaryname)) > 1
				) AS multi_nonproprietaryname,
			(
				SELECT STRING_AGG(brand_name, ', ' ORDER BY brand_name)
				FROM (
					SELECT DISTINCT CASE 
							WHEN (
									LOWER(proprietaryname) <> LOWER(nonproprietaryname)
									OR nonproprietaryname IS NULL
									)
								THEN LOWER(TRIM(proprietaryname || ' ' || proprietarynamesuffix))
							ELSE NULL
							END AS brand_name
					FROM prod p
					WHERE p.concept_code = t1.concept_code
					ORDER BY brand_name LIMIT 49 --brand_name may be too long for concatenation
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
	long_concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT vocabulary_pack.CutConceptName(c.str) AS concept_name,
	TRIM(c.str) AS long_concept_name,
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
SELECT vocabulary_pack.CutConceptName(concept_name) AS concept_name,
	'Drug' AS domain_id,
	'NDC' AS vocabulary_id,
	'11-digit NDC' AS concept_class_id,
	NULL AS standard_concept,
	concept_code,
	startDate AS valid_start_date,
	endDate AS valid_end_date,
	invalid_reason
FROM (
	SELECT DISTINCT ON (n.concept_code)
		n.concept_code,
		n.startDate,
		n.endDate,
		n.invalid_reason,
		COALESCE(mn.concept_name, c.concept_name, spl.concept_name) concept_name
	FROM (
		SELECT ndc.concept_code,
			startDate,
			CASE 
				WHEN LOWER(status) = 'active'
					THEN TO_DATE('20991231', 'yyyymmdd')
				ELSE endDate
				END endDate,
			CASE 
				WHEN LOWER(status) = 'active'
					THEN NULL
				ELSE 'D'
				END AS invalid_reason
		FROM apigrabber.ndc_history ndc
		JOIN (
			SELECT DISTINCT FIRST_VALUE(ndc_int.activeRxcui) OVER (
					PARTITION BY ndc_int.concept_code ORDER BY c_int.invalid_reason NULLS FIRST,
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
						c_int.concept_id
					) AS activeRxcui,
				ndc_int.concept_code
			FROM apigrabber.ndc_history ndc_int
			JOIN concept c_int ON c_int.vocabulary_id = 'RxNorm'
				AND c_int.concept_code = ndc_int.activeRxcui
			) rx ON rx.activeRxcui = ndc.activeRxcui
			AND rx.concept_code = ndc.concept_code
		) n
	LEFT JOIN main_ndc mn ON mn.concept_code = n.concept_code
		AND mn.vocabulary_id = 'NDC' --first search name in old sources
	LEFT JOIN concept c ON c.concept_code = n.concept_code
		AND c.vocabulary_id = 'NDC' --search name in concept
	LEFT JOIN sources.spl2ndc_mappings s ON s.ndc_code = n.concept_code--take name from SPL
	LEFT JOIN sources.spl_ext spl ON spl.concept_code = s.concept_code
		AND COALESCE(spl.ndc_code,s.ndc_code)=s.ndc_code
	ORDER BY n.concept_code,
		spl.high_value NULLS FIRST,
		LENGTH(spl.concept_name) DESC
	) AS s0
WHERE concept_name IS NOT NULL;

--15. Add additional NDC with fresh dates from the ndc_history where NDC have't activerxcui (same source). Take dates from COALESCE(NDC API, big XML (SPL), MAIN_NDC, concept, default dates)
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
LANGUAGE 'plpgsql' IMMUTABLE;

WITH ADDITIONALNDCINFO
AS (
	SELECT n.concept_code,
		COALESCE(n.startdate, CheckNDCDate(l.ndc_valid_start_date, COALESCE(mn.valid_start_date, c.valid_start_date, TO_DATE('19700102', 'YYYYMMDD')))) AS valid_start_date,
		COALESCE(
			CASE WHEN LOWER(n.status)='active' THEN TO_DATE('20991231', 'YYYYMMDD') ELSE n.enddate END,
			CheckNDCDate(l.ndc_valid_end_date, COALESCE(mn.valid_end_date, c.valid_end_date, TO_DATE('20991231', 'YYYYMMDD')))
		) AS valid_end_date,
		vocabulary_pack.CutConceptName(COALESCE(mn.concept_name, c.concept_name, l.spl_name)) AS concept_name
	FROM apigrabber.ndc_history n
	LEFT JOIN main_ndc mn ON mn.concept_code = n.concept_code
		AND mn.vocabulary_id = 'NDC'
	LEFT JOIN concept c ON c.concept_code = n.concept_code
		AND c.vocabulary_id = 'NDC'
	LEFT JOIN LATERAL(
		SELECT DISTINCT
			FIRST_VALUE(spl.low_value) OVER (ORDER BY spl.low_value) AS ndc_valid_start_date,
			FIRST_VALUE(COALESCE(spl.high_value, '20991231')) OVER (ORDER BY spl.high_value DESC) AS ndc_valid_end_date,
			FIRST_VALUE(spl.concept_name) OVER (ORDER BY spl.high_value DESC) AS spl_name
		FROM sources.spl2ndc_mappings s
		JOIN sources.spl_ext spl ON spl.concept_code = s.concept_code
				AND COALESCE(spl.ndc_code, s.ndc_code) = s.ndc_code
		WHERE s.ndc_code = n.concept_code
	) l ON TRUE
	WHERE n.activerxcui IS NULL
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

--15.1 Fix bug in sources, SPL XML returns 11/06/2103 for NDC:61077-003-33, proof: https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=fcd4b3e8-a40a-4aa1-9745-1c9768dca539&type=display
UPDATE concept_stage
SET valid_start_date = TO_DATE('20131106', 'yyyymmdd')
WHERE concept_code = '61077000333'
	AND valid_start_date = TO_DATE('21031106', 'yyyymmdd');

--Another fix for NDCs tagged "delayed release", examples: https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=e0e8023a-3c82-e455-a57b-ccc0206ad156&type=display https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=8516e135-5cc0-ef2d-6dad-0f9f841bb27b&type=display
--Just use latest_update if valid_start_date is greater than current_date + 2 year [AVOF-3394]
UPDATE concept_stage cs
SET valid_start_date = v.latest_update
FROM vocabulary v
WHERE v.vocabulary_id=cs.vocabulary_id
	AND cs.valid_start_date > CURRENT_DATE + INTERVAL '2 year';

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
		LAST_VALUE(rxnorm.concept_name) OVER (
			PARTITION BY mp.ndc_code ORDER BY rxnorm.valid_start_date,
				rxnorm.concept_id ROWS BETWEEN UNBOUNDED PRECEDING
					AND UNBOUNDED FOLLOWING
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
			MAX(endDate) OVER () max_end_date
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
	FIRST_VALUE(startDate) OVER (
		PARTITION BY ndc_code ORDER BY startDate ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS valid_start_date,
	LAST_VALUE(endDate) OVER (
		PARTITION BY ndc_code ORDER BY endDate ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS valid_end_date,
	LAST_VALUE(invalid_reason) OVER (
		PARTITION BY ndc_code ORDER BY endDate ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS invalid_reason
FROM rxnorm2ndc_mappings_ext m
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = m.ndc_code
			AND cs_int.vocabulary_id = 'NDC'
		);

--18. Add all other NDC from 'product'
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
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM main_ndc m
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = m.concept_code
			AND cs_int.vocabulary_id = 'NDC'
		);

--19. Add full unique NDC names into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT mn.concept_code,
	mn.vocabulary_id,
	vocabulary_pack.CutConceptSynonymName(mn.long_concept_name),
	4180186 AS language_concept_id -- English
FROM main_ndc mn
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = mn.concept_code
			AND cs_int.vocabulary_id = mn.vocabulary_id
			AND REPLACE(LOWER(cs_int.concept_name), ' [diluent]', '') = LOWER(vocabulary_pack.CutConceptSynonymName(mn.long_concept_name))
		);

--20. Add mapping from SPL to RxNorm through RxNorm API (source: http://rxnav.nlm.nih.gov/REST/rxcui/xxx/property?propName=SPL_SET_ID)
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

--21. Add mapping from SPL to RxNorm through rxnsat
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

--22. Add mapping from NDC to RxNorm from rxnconso
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
	TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
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

--23. Add additional mapping for NDC codes 
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
			DENSE_RANK() OVER (
				PARTITION BY concept_code_1 ORDER BY concept_code_2
				) + DENSE_RANK() OVER (
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

--24. MERGE concepts from fresh sources (RXNORM2NDC_MAPPINGS_EXT). Add/merge only fresh mappings (even if rxnorm2ndc_mappings_ext gives us deprecated mappings we put them as fresh: redmine #70209)
WITH to_be_upserted
AS (
	SELECT DISTINCT ON (m.ndc_code) m.ndc_code,
		m.concept_code,
		m.startDate,
		m.invalid_reason
	FROM rxnorm2ndc_mappings_ext m
	JOIN concept c ON c.concept_code = m.concept_code
		AND c.vocabulary_id = 'RxNorm'
	ORDER BY m.ndc_code,
		m.invalid_reason NULLS FIRST,
		m.startDate DESC,
		CASE c.concept_class_id --fixed a bug with wrong choice of rx-concept (random)
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
			END
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

--25. Add PACKAGES
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
	MIN(startmarketingdate) OVER (PARTITION BY p.pack_code) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM ndc n
JOIN concept_stage cs ON cs.concept_code = n.concept_code
	AND cs.vocabulary_id = 'NDC'
JOIN sources.package p ON p.productndc = n.productndc
LEFT JOIN concept_stage cs1 ON cs1.concept_code = p.pack_code
	AND cs1.vocabulary_id = 'NDC'
WHERE cs1.concept_code IS NULL
	AND p.pack_code IS NOT NULL; --fixed a bug with an empty code that appeared in 20230116

--26. Add manual source
--26.1. Add concept_manual
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--26.2. Add concept_relationship_manual
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--27. Delete duplicate mappings to packs
--27.1. Add mapping from deprecated to fresh concepts (necessary for the next step)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO('NDC');
END $_$;

--27.2. Deprecate 'Maps to' mappings to deprecated and upgraded concepts (necessary for the next step)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--27.3 Do it
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
		HAVING COUNT(*) > 1
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

--28. Add full unique NDC packages names into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
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
SELECT DISTINCT p.pack_code AS synonym_concept_code,
	m.vocabulary_id,
	vocabulary_pack.CutConceptSynonymName(m.long_concept_name),
	4180186 AS language_concept_id -- English
FROM ndc n
JOIN main_ndc m ON m.concept_code = n.concept_code
JOIN sources.package p ON p.productndc = n.productndc
LEFT JOIN concept_synonym_stage css ON css.synonym_concept_code = p.pack_code
WHERE css.synonym_concept_code IS NULL
	AND p.pack_code IS NOT NULL
	AND NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = p.pack_code
			AND cs_int.vocabulary_id = m.vocabulary_id
			AND REPLACE(LOWER(cs_int.concept_name), ' [diluent]', '') = LOWER(vocabulary_pack.CutConceptSynonymName(m.long_concept_name))
		);

--29. Add relationships (take from 9-digit NDC codes), but only new
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
	AND crs1.vocabulary_id_1 = crs.vocabulary_id_1
	AND crs1.vocabulary_id_2 = crs.vocabulary_id_2
WHERE crs1.concept_code_1 IS NULL;

--30. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--31. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--32. Delete records that does not exists in the concept and concept_stage
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

--33. Set proper concept_class_id (Device)
UPDATE concept_stage
SET concept_class_id = 'Device',
	domain_id = 'Device',
	standard_concept = 'S'
WHERE concept_name ~* ('PUMP( |$)|METER( |$)|LANCET|DEVICE|PEDIALYTE|SUNSCREEN|NEEDLE|MONITOR|FREEDOM|BLOOD GLUCOSE|STERI-STRIP|HUGGIES|GAUZE|STOCKING|DEPEND|CHAMBER|COMPRESSR|COMPRESSOR|NEBULIZER|FREESTYLE|SHARPS|ACCU-CHEK|ELECTROLYTE|'
	|| ' TRAY|WAVESENSE|DEPEND|EASY TOUCH|MONIT|ENSURE|XEROFORM|PCCA|REAGENT|UNDERWEAR|CONTOUR|UNDERPAD|UNDERPAD|TRANSMITTER|GX|STERILE PADS|POISE PADS|GLUCERNA|PENTIP|MONOJECT|INSULIN SYR|DIAPHRAGM|PCCA|BD INSULIN|'
	|| 'PEDIASURE|BD SYR|SIMILAC|OMNIPOD| DRINK|DRESS|ORALYTE|NUTRAMIGEN|REAGENT STRIPS|INNOSPIRE|TEST STRIPS|CONDOM|DIAPHRAGM|CLEAR SHAMPOO|HEATWRAP|VAPORIZER|UNDERPANTS|HUMIDIFIER|MURI-LUBE')
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

--Devices from the manual table
UPDATE concept_stage cs
SET concept_class_id = 'Device',
	domain_id = 'Device',
	standard_concept = 'S'
FROM ndc_manual_mapped m
WHERE m.source_code = cs.concept_code
	AND cs.vocabulary_id = 'NDC'
	AND m.target_concept_id = 17;

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

--34. Return proper valid_end_date from base tables
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

--35. Mark diluent as [Diluent]
WITH ndc_packages
AS (
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
	),
ndc_codes
AS (
	SELECT concept_code
	FROM main_ndc
	WHERE is_diluent
	
	UNION
	
	SELECT p.pack_code
	FROM ndc_packages n
	JOIN main_ndc m ON m.concept_code = n.concept_code
		AND m.is_diluent
	JOIN sources.package p ON p.productndc = n.productndc
	
	UNION
	
	SELECT ndc_code
	FROM sources.spl_ext
	WHERE is_diluent
		AND ndc_code IS NOT NULL
	),
ndc_update --update concept_stage
AS (
	UPDATE concept_stage cs
	SET concept_name = vocabulary_pack.CutConceptSynonymName(COALESCE(css.synonym_name, cs.concept_name) || ' [Diluent]')
	FROM ndc_codes nc
	LEFT JOIN concept_synonym_stage css ON css.synonym_concept_code = nc.concept_code
		AND css.synonym_name NOT ILIKE '%water%' --exclude water
	WHERE nc.concept_code = cs.concept_code
		AND cs.concept_name NOT LIKE '% [Diluent]' --do not mark already marked codes
		AND cs.concept_name NOT ILIKE '%water%'
	)
--update concept_synonym_stage
UPDATE concept_synonym_stage css
SET synonym_name = vocabulary_pack.CutConceptSynonymName('Diluent of ' || cs.concept_name)
FROM concept_stage cs
JOIN ndc_codes USING (concept_code)
WHERE cs.concept_code = css.synonym_concept_code
	AND cs.concept_name NOT ILIKE '%water%'; --exclude water
	
--36. Prioritization of manual changes over load_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--37. Clean up
DROP FUNCTION GetAggrDose (active_numerator_strength IN VARCHAR, active_ingred_unit IN VARCHAR);
DROP FUNCTION GetDistinctDose (active_numerator_strength IN VARCHAR, active_ingred_unit IN VARCHAR, p IN INT);
DROP FUNCTION CheckNDCDate (pDate IN VARCHAR, pDateDefault IN DATE);
DROP TABLE main_ndc;
DROP TABLE rxnorm2ndc_mappings_ext;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
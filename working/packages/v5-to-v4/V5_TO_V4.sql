﻿CREATE OR REPLACE FUNCTION devv4.v5_to_v4 (
)
RETURNS void AS
$BODY$
BEGIN
	DROP TABLE IF EXISTS concept CASCADE;
	DROP TABLE IF EXISTS relationship CASCADE;
	DROP TABLE IF EXISTS concept_relationship;
	DROP TABLE IF EXISTS concept_ancestor;
	DROP TABLE IF EXISTS concept_synonym;
	DROP TABLE IF EXISTS source_to_concept_map;
	DROP TABLE IF EXISTS drug_strength;
	DROP TABLE IF EXISTS pack_content;
	DROP TABLE IF EXISTS vocabulary;

	--add table relationship
	CREATE TABLE relationship (
		relationship_id INTEGER NOT NULL,
		relationship_name VARCHAR(256) NOT NULL,
		is_hierarchical INTEGER NOT NULL,
		defines_ancestry INTEGER DEFAULT 1 NOT NULL,
		reverse_relationship INTEGER
		);


	CREATE UNIQUE INDEX xpkrelationship_type ON relationship (relationship_id);
	ALTER TABLE relationship ADD CONSTRAINT xpkrelationship_type PRIMARY KEY USING INDEX xpkrelationship_type;

	--add table drug_strength
	CREATE TABLE drug_strength (
		drug_concept_id INTEGER NOT NULL,
		ingredient_concept_id INTEGER NOT NULL,
		amount_value NUMERIC,
		amount_unit VARCHAR(60),
		concentration_value NUMERIC,
		concentration_enum_unit VARCHAR(60),
		concentration_denom_unit VARCHAR(60),
		box_size INT2,
		valid_start_date DATE NOT NULL,
		valid_end_date DATE NOT NULL,
		invalid_reason VARCHAR(1)
		);

	CREATE TABLE pack_content (
		pack_concept_id NUMERIC NOT NULL,
		drug_concept_id NUMERIC NOT NULL,
		amount INT2,
		box_size INT2
		);

	--add table vocabulary
	CREATE TABLE vocabulary (
		vocabulary_id INTEGER NOT NULL,
		vocabulary_name VARCHAR(256) NOT NULL
		);


	--fill tables
	INSERT INTO devv5.relationship_conversion (
		relationship_id,
		relationship_id_new
		)
	SELECT ROW_NUMBER() OVER () + (
			SELECT MAX(relationship_id)
			FROM devv5.relationship_conversion
			) AS rn,
		relationship_id
	FROM (
		(
			SELECT relationship_id
			FROM devv5.relationship
			
			UNION ALL
			
			SELECT reverse_relationship_id
			FROM devv5.relationship
			)
		
		EXCEPT
		
		(
			SELECT relationship_id_new
			FROM devv5.relationship_conversion
			)
		) AS t;


	CREATE TABLE t_concept_class_conversion AS (
		SELECT concept_class,
		concept_class_id_new FROM devv5.concept_class_conversion WHERE concept_class_id_new NOT IN (
			SELECT concept_class_id_new
			FROM devv5.concept_class_conversion
			GROUP BY concept_class_id_new
			HAVING COUNT(*) > 1
			)
		)

	UNION ALL

	(
		SELECT concept_class_id_new AS concept_class,
			concept_class_id_new
		FROM devv5.concept_class_conversion
		GROUP BY concept_class_id_new
		HAVING COUNT(*) > 1
		)

	UNION ALL

	(
		SELECT concept_class_id AS concept_class,
			concept_class_id AS concept_class_id_new
		FROM devv5.concept
		
		EXCEPT
		
		(
			SELECT concept_class_id_new,
				concept_class_id_new
			FROM devv5.concept_class_conversion
			)
		);


	INSERT INTO relationship (
		relationship_id,
		relationship_name,
		is_hierarchical,
		defines_ancestry,
		reverse_relationship
		)
	SELECT rc.relationship_id,
		r.relationship_name,
		r.is_hierarchical::int,
		r.defines_ancestry,
		rc_rev.relationship_id
	FROM devv5.relationship r,
		devv5.relationship_conversion rc,
		devv5.relationship_conversion rc_rev
	WHERE r.relationship_id = rc.relationship_id_new
		AND r.reverse_relationship_id = rc_rev.relationship_id_new;


	CREATE TABLE concept AS

	SELECT concept_id,
		concept_name,
		concept_level,
		concept_class,
		vocabulary_id,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT c.concept_id,
			c.concept_name,
			CASE c.vocabulary_id
				WHEN 'SNOMED'
					THEN -- full hierarchy
						CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get children
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.ancestor_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 1 -- if it has no children then leaf
											-- get parents
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.descendant_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 3 -- if it has no parents then top guy
									ELSE 2 -- in the middle
									END
							END
				END AS concept_level,
			ccc.concept_class,
			vc.vocabulary_id_v4 AS vocabulary_id,
			c.concept_code,
			c.valid_start_date,
			c.valid_end_date,
			c.invalid_reason
		FROM devv5.concept c
		JOIN t_concept_class_conversion ccc ON ccc.concept_class_id_new = c.concept_class_id
		JOIN devv5.vocabulary_conversion vc ON vc.vocabulary_id_v5 = c.vocabulary_id
		LEFT JOIN (
			SELECT count(*) cnt,
				c_int.vocabulary_id
			FROM devv5.concept c_int
			WHERE standard_concept IN (
					'C',
					'S'
					)
			GROUP BY c_int.vocabulary_id
			) cc_exists ON cc_exists.vocabulary_id = C.vocabulary_id
		WHERE (
				cc_exists.cnt > 0
				OR C.concept_code IN (
					'OMOP generated',
					'No matching concept'
					)
				)
			AND c.vocabulary_id = 'SNOMED'
		
		UNION ALL
		
		SELECT c.concept_id,
			c.concept_name,
			CASE c.vocabulary_id
				WHEN 'ICD9Proc'
					THEN -- hierarchy, but no top guys
						CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get children
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.ancestor_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 1 -- if it has no children then leaf
									ELSE 2 -- in the middle
									END
							END
				END AS concept_level,
			ccc.concept_class,
			vc.vocabulary_id_v4 AS vocabulary_id,
			c.concept_code,
			c.valid_start_date,
			c.valid_end_date,
			c.invalid_reason
		FROM devv5.concept c
		JOIN t_concept_class_conversion ccc ON ccc.concept_class_id_new = C.concept_class_id
		JOIN devv5.vocabulary_conversion vc ON vc.vocabulary_id_v5 = C.vocabulary_id
		LEFT JOIN (
			SELECT count(*) cnt,
				c_int.vocabulary_id
			FROM devv5.concept c_int
			WHERE standard_concept IN (
					'C',
					'S'
					)
			GROUP BY c_int.vocabulary_id
			) cc_exists ON cc_exists.vocabulary_id = C.vocabulary_id
		WHERE (
				cc_exists.cnt > 0
				OR C.concept_code IN (
					'OMOP generated',
					'No matching concept'
					)
				)
			AND C.vocabulary_id = 'ICD9Proc'
		
		UNION ALL
		
		SELECT c.concept_id,
			c.concept_name,
			CASE c.vocabulary_id
				WHEN 'CPT4'
					THEN -- full hierarchy
						CASE 
							WHEN C.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get children
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.ancestor_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 1 -- if it has no children then leaf
											-- get parents
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.descendant_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 3 -- if it has no parents then top guy
									ELSE 2 -- in the middle
									END
							END
				END AS concept_level,
			ccc.concept_class,
			vc.vocabulary_id_v4 AS vocabulary_id,
			c.concept_code,
			c.valid_start_date,
			c.valid_end_date,
			c.invalid_reason
		FROM devv5.concept c
		JOIN t_concept_class_conversion ccc ON ccc.concept_class_id_new = C.concept_class_id
		JOIN devv5.vocabulary_conversion vc ON vc.vocabulary_id_v5 = C.vocabulary_id
		LEFT JOIN (
			SELECT count(*) cnt,
				c_int.vocabulary_id
			FROM devv5.concept c_int
			WHERE standard_concept IN (
					'C',
					'S'
					)
			GROUP BY c_int.vocabulary_id
			) cc_exists ON cc_exists.vocabulary_id = C.vocabulary_id
		WHERE (
				cc_exists.cnt > 0
				OR c.concept_code IN (
					'OMOP generated',
					'No matching concept'
					)
				)
			AND C.vocabulary_id = 'CPT4'
		
		UNION ALL
		
		SELECT c.concept_id,
			c.concept_name,
			CASE c.vocabulary_id
				WHEN 'LOINC'
					THEN -- full hierarchy
						CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get children
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.ancestor_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 1 -- if it has no children then leaf
											-- get parents
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.descendant_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 3 -- if it has no parents then top guy
									ELSE 2 -- in the middle
									END
							END
				END AS concept_level,
			ccc.concept_class,
			vc.vocabulary_id_v4 AS vocabulary_id,
			c.concept_code,
			c.valid_start_date,
			c.valid_end_date,
			c.invalid_reason
		FROM devv5.concept c
		JOIN t_concept_class_conversion ccc ON ccc.concept_class_id_new = c.concept_class_id
		JOIN devv5.vocabulary_conversion vc ON vc.vocabulary_id_v5 = c.vocabulary_id
		LEFT JOIN (
			SELECT count(*) cnt,
				c_int.vocabulary_id
			FROM devv5.concept c_int
			WHERE standard_concept IN (
					'C',
					'S'
					)
			GROUP BY c_int.vocabulary_id
			) cc_exists ON cc_exists.vocabulary_id = c.vocabulary_id
		WHERE (
				cc_exists.cnt > 0
				OR c.concept_code IN (
					'OMOP generated',
					'No matching concept'
					)
				)
			AND C.vocabulary_id = 'LOINC'
		
		UNION ALL
		
		SELECT c.concept_id,
			c.concept_name,
			CASE c.vocabulary_id
				WHEN 'NDFRT'
					THEN -- full hierarchy
						CASE 
							WHEN C.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get parents
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.descendant_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 4 -- if it has no parents then top guy
									ELSE 3 -- in the middle
									END
							END
				WHEN 'ETC'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get parents
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.descendant_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 4 -- if it has no parents then top guy
									ELSE 3 -- in the middle
									END
							END
				WHEN 'ATC'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get parents
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.descendant_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 4 -- if it has no parents then top guy
									ELSE 3 -- in the middle
									END
							END
				WHEN 'SMQ'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get childrens
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.ancestor_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 1 -- if it has no children then leaf
											-- get parents
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.descendant_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 3 -- if it has no parents then top guy
									ELSE 2 -- in the middle
									END
							END
				WHEN 'VA Class'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get parents
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.descendant_concept_id = C.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 4 -- if it has no parents then top guy
									ELSE 3 -- in the middle
									END
							END
				WHEN 'Race'
					THEN -- 2 level hierarchy
						CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE 
									-- get childrens
									WHEN NOT EXISTS (
											SELECT 1
											FROM devv5.concept_ancestor ca
											WHERE ca.ancestor_concept_id = c.concept_id
												AND ca.ancestor_concept_id <> ca.descendant_concept_id
											)
										THEN 1 -- if it has no children then leaf
									ELSE 2 -- on top
									END
							END
				END AS concept_level,
			ccc.concept_class,
			vc.vocabulary_id_v4 AS vocabulary_id,
			c.concept_code,
			c.valid_start_date,
			c.valid_end_date,
			c.invalid_reason
		FROM devv5.concept c
		JOIN t_concept_class_conversion ccc ON ccc.concept_class_id_new = c.concept_class_id
		JOIN devv5.vocabulary_conversion vc ON vc.vocabulary_id_v5 = c.vocabulary_id
		LEFT JOIN (
			SELECT count(*) cnt,
				c_int.vocabulary_id
			FROM devv5.concept c_int
			WHERE standard_concept IN (
					'C',
					'S'
					)
			GROUP BY c_int.vocabulary_id
			) cc_exists ON cc_exists.vocabulary_id = C.vocabulary_id
		WHERE (
				cc_exists.cnt > 0
				OR c.concept_code IN (
					'OMOP generated',
					'No matching concept'
					)
				)
			AND C.vocabulary_id IN (
				'NDFRT',
				'ETC',
				'ATC',
				'SMQ',
				'VA Class',
				'Race'
				)
		
		UNION ALL
		
		SELECT c.concept_id,
			c.concept_name,
			CASE c.vocabulary_id
				WHEN 'ICD9CM'
					THEN 0 -- all source
				WHEN 'RxNorm'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE concept_class_id
									WHEN 'Ingredient'
										THEN 2
									WHEN 'Clinical Drug'
										THEN 1
									WHEN 'Branded Drug Box'
										THEN 1
									WHEN 'Clinical Drug Box'
										THEN 1
									WHEN 'Quant Branded Box'
										THEN 1
									WHEN 'Quant Clinical Box'
										THEN 1
									WHEN 'Quant Clinical Drug'
										THEN 1
									WHEN 'Quant Branded Drug'
										THEN 1
									WHEN 'Clinical Drug Comp'
										THEN 1
									WHEN 'Branded Drug Comp'
										THEN 1
									WHEN 'Branded Drug Form'
										THEN 1
									WHEN 'Clinical Drug Form'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'DPD'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'RxNorm Extension'
					THEN -- same as RxNorm
						CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE concept_class_id
									WHEN 'Ingredient'
										THEN 2
									WHEN 'Clinical Drug'
										THEN 1
									WHEN 'Branded Drug Box'
										THEN 1
									WHEN 'Clinical Drug Box'
										THEN 1
									WHEN 'Quant Branded Box'
										THEN 1
									WHEN 'Quant Clinical Box'
										THEN 1
									WHEN 'Quant Clinical Drug'
										THEN 1
									WHEN 'Quant Branded Drug'
										THEN 1
									WHEN 'Clinical Drug Comp'
										THEN 1
									WHEN 'Branded Drug Comp'
										THEN 1
									WHEN 'Branded Drug Form'
										THEN 1
									WHEN 'Clinical Drug Form'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'dm+d'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'NDC'
					THEN 0
				WHEN 'GPI'
					THEN 0
				WHEN 'MedDRA'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE concept_class_id
									WHEN 'LLT'
										THEN 1
									WHEN 'PT'
										THEN 2
									WHEN 'HLT'
										THEN 3
									WHEN 'HLGT'
										THEN 4
									WHEN 'SOC'
										THEN 5
									END
							END
				WHEN 'Multum'
					THEN 0
				WHEN 'Read'
					THEN 0
				WHEN 'OXMIS'
					THEN 0
				WHEN 'Indication'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE 3 -- Drug hierarchy on top of Ingredient (level 2)
							END
				WHEN 'Multilex'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE concept_class_id
									WHEN 'Ingredient'
										THEN 2
									WHEN 'Clinical Drug'
										THEN 1
									WHEN 'Branded Drug'
										THEN 1
									WHEN 'Clinical Pack'
										THEN 1
									WHEN 'Branded Pack'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'Visit'
					THEN -- flat list
						CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE 2 -- on top of place of service
							END
				WHEN 'Cohort'
					THEN 0
				WHEN 'ICD10'
					THEN 0
				WHEN 'ICD10PCS'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE 1
							END
				WHEN 'MDC'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE 2 -- on top of DRG (level 1)
							END
				WHEN 'MeSH'
					THEN 0
				WHEN 'Provider Specialty'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE 2 -- on top of DRG (level 1)
							END
				WHEN 'SPL'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE 3 -- on top of Ingredient (level 2)
							END
				WHEN 'GCN_SEQNO'
					THEN 0
				WHEN 'CCS'
					THEN 0
				WHEN 'OPCS4'
					THEN 1
				WHEN 'Gemscript'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'HES Specialty'
					THEN 0
				WHEN 'ICD10CM'
					THEN 0
				WHEN 'BDPM'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'EphMRA ATC'
					THEN 3 -- Classification
				WHEN 'DA_France'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'AMIS'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'NFC'
					THEN 4
				WHEN 'AMT'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'LPD_Australia'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'CVX'
					THEN 1
				WHEN 'PPI'
					THEN CASE 
							WHEN c.invalid_reason IS NOT NULL
								THEN 0
							ELSE CASE 
									WHEN c.concept_class_id IN (
											'Topic',
											'Module',
											'PPI Modifier'
											)
										THEN 2
									ELSE 1
									END
							END
				WHEN 'ICDO3'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE 1
							END
				WHEN 'CDT'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE concept_class_id
									WHEN 'CDT'
										THEN 1
									WHEN 'CDT Hierarchy'
										THEN 2
									ELSE 0
									END
							END
				WHEN 'ISBT'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE concept_class_id
									WHEN 'ISBT Product'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'ISBT Attribute'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE CASE concept_class_id
									WHEN 'ISBT Class'
										THEN 2
									WHEN 'ISBT Modifier'
										THEN 2
									WHEN 'ISBT Attrib value'
										THEN 2
									WHEN 'ISBT Attrib group'
										THEN 3
									WHEN 'ISBT Category'
										THEN 3
									ELSE 0
									END
							END
				WHEN 'GGR'
					THEN CASE 
							WHEN c.standard_concept IS NULL
								THEN 0
							ELSE 1
							END
				WHEN 'LPD_Belgium'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'KDC'
					THEN -- specialized hierarchy
						CASE 
							WHEN c.domain_id = 'Drug'
								THEN 0
							ELSE CASE 
									WHEN c.standard_concept = 'S'
										THEN 1
									ELSE 0
									END
							END
				WHEN 'SUS'
					THEN 0
				ELSE -- flat list
					CASE 
						WHEN c.standard_concept IS NULL
							THEN 0
						ELSE 1
						END
				END AS concept_level,
			ccc.concept_class,
			vc.vocabulary_id_v4 AS vocabulary_id,
			c.concept_code,
			c.valid_start_date,
			c.valid_end_date,
			c.invalid_reason
		FROM devv5.concept c
		JOIN t_concept_class_conversion ccc ON ccc.concept_class_id_new = C.concept_class_id
		JOIN devv5.vocabulary_conversion vc ON vc.vocabulary_id_v5 = C.vocabulary_id
		LEFT JOIN (
			SELECT count(*) cnt,
				c_int.vocabulary_id
			FROM devv5.concept c_int
			WHERE standard_concept IN (
					'C',
					'S'
					)
			GROUP BY c_int.vocabulary_id
			) cc_exists ON cc_exists.vocabulary_id = C.vocabulary_id
		WHERE (
				cc_exists.cnt > 0
				OR c.concept_code IN (
					'OMOP generated',
					'No matching concept'
					)
				)
			AND c.vocabulary_id NOT IN (
				'SNOMED',
				'ICD9Proc',
				'CPT4',
				'LOINC',
				'NDFRT',
				'ETC',
				'ATC',
				'SMQ',
				'VA Class',
				'Race'
				)
		) AS t;


	DROP TABLE t_concept_class_conversion;

	CREATE INDEX concept_code ON concept (
		concept_code,
		vocabulary_id
		);

	CREATE UNIQUE INDEX xpkconcept ON concept (concept_id);

	ALTER TABLE concept ADD CONSTRAINT xpkconcept_chk CHECK (
		invalid_reason IN (
			'D',
			'U'
			)
		),
		ADD PRIMARY KEY USING INDEX XPKCONCEPT,
		VALIDATE CONSTRAINT xpkconcept_chk;

	--add table concept_relationship
	CREATE TABLE concept_relationship AS

	SELECT concept_id_1,
		concept_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT r.concept_id_1,
			r.concept_id_2,
			rc.relationship_id AS relationship_id,
			r.valid_start_date,
			r.valid_end_date,
			r.invalid_reason
		FROM devv5.concept_relationship r,
			devv5.relationship_conversion rc
		WHERE r.relationship_id = rc.relationship_id_new
			AND EXISTS (
				SELECT 1
				FROM concept c_int
				WHERE c_int.concept_id = r.concept_id_1
				)
			AND EXISTS (
				SELECT 1
				FROM concept c_int
				WHERE c_int.concept_id = r.concept_id_2
				)
		) AS t;

	INSERT INTO concept_relationship (
		concept_id_1,
		concept_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT c.concept_id AS concept_id_1,
		d.domain_concept_id AS concept_id_2,
		360 AS relationship_id,
		--Is domain
		TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM devv5.concept c,
		devv5.domain d
	WHERE c.domain_id = d.domain_id
		AND EXISTS (
			SELECT 1
			FROM concept c_int
			WHERE c_int.concept_id = c.concept_id
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r_int
			WHERE r_int.concept_id_1 = c.concept_id
				AND r_int.concept_id_2 = d.domain_concept_id
				AND relationship_id = 360
			)

	UNION ALL

	SELECT d.domain_concept_id AS concept_id_1,
		c.concept_id AS concept_id_2,
		359 AS relationship_id,
		--Domain subsumes
		TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM devv5.concept c,
		devv5.domain d
	WHERE c.domain_id = d.domain_id
		AND EXISTS (
			SELECT 1
			FROM concept c_int
			WHERE c_int.concept_id = c.concept_id
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship r_int
			WHERE r_int.concept_id_1 = d.domain_concept_id
				AND r_int.concept_id_2 = c.concept_id
				AND relationship_id = 359
			);

	CREATE UNIQUE INDEX xpkconcept_relationship ON concept_relationship (
		concept_id_1,
		concept_id_2,
		relationship_id
		);

	ALTER TABLE concept_relationship ADD CONSTRAINT xpkconcept_relationship_chk CHECK (
		invalid_reason IN (
			'D',
			'U'
			)
		),
		ADD PRIMARY KEY USING INDEX xpkconcept_relationship,
		VALIDATE CONSTRAINT xpkconcept_relationship_chk;


	ALTER TABLE concept_relationship
		ADD CONSTRAINT concept_rel_child_fk FOREIGN KEY (concept_id_2) REFERENCES concept (concept_id), VALIDATE CONSTRAINT concept_rel_child_fk,
		ADD CONSTRAINT concept_rel_parent_fk FOREIGN KEY (concept_id_1) REFERENCES concept (concept_id), VALIDATE CONSTRAINT concept_rel_parent_fk,
		ADD CONSTRAINT concept_rel_rel_type_fk FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id), VALIDATE CONSTRAINT concept_rel_rel_type_fk;


	--add table concept_ancestor
	CREATE TABLE concept_ancestor AS

	SELECT ancestor_concept_id,
		descendant_concept_id,
		max_levels_of_separation,
		min_levels_of_separation
	FROM (
		SELECT ca.ancestor_concept_id,
			ca.descendant_concept_id,
			ca.max_levels_of_separation,
			ca.min_levels_of_separation
		FROM devv5.concept_ancestor ca
		WHERE EXISTS (
				SELECT 1
				FROM concept c_int
				WHERE c_int.concept_id = ca.ancestor_concept_id
				)
			AND EXISTS (
				SELECT 1
				FROM concept c_int
				WHERE c_int.concept_id = ca.descendant_concept_id
				)
		) AS t;


	CREATE UNIQUE INDEX xpkconcept_ancestor ON concept_ancestor (
		ancestor_concept_id,
		descendant_concept_id
		);

	ALTER TABLE concept_ancestor ADD PRIMARY KEY USING INDEX xpkconcept_ancestor;

	ALTER TABLE concept_ancestor 
		ADD CONSTRAINT concept_ancestor_fk FOREIGN KEY (ancestor_concept_id) REFERENCES concept (concept_id), VALIDATE CONSTRAINT concept_ancestor_fk,
		ADD CONSTRAINT concept_descendant_fk FOREIGN KEY (descendant_concept_id) REFERENCES concept (concept_id), VALIDATE CONSTRAINT concept_descendant_fk;

	--add table concept_synonym
	CREATE TABLE concept_synonym AS

	SELECT concept_synonym_id,
		concept_id,
		concept_synonym_name
	FROM (
		SELECT ROW_NUMBER() OVER () AS concept_synonym_id,
			cs.concept_id,
			cs.concept_synonym_name
		FROM devv5.concept_synonym cs
		WHERE EXISTS (
				SELECT 1
				FROM concept c_int
				WHERE c_int.concept_id = cs.concept_id
				)
		) AS t;


	CREATE UNIQUE INDEX xpkconcept_synonym ON concept_synonym (concept_synonym_id);

	ALTER TABLE concept_synonym ADD CONSTRAINT xpkconcept_synonym PRIMARY KEY USING INDEX xpkconcept_synonym;

	ALTER TABLE concept_synonym ADD CONSTRAINT concept_synonym_concept_FK FOREIGN KEY (concept_id) REFERENCES concept (concept_id);

	--concepts with direct mappings
	CREATE TABLE source_to_concept_map AS

	SELECT source_code,
		source_vocabulary_id,
		source_code_description,
		target_concept_id,
		target_vocabulary_id,
		mapping_type,
		primary_map,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT DISTINCT c1.concept_code AS source_code,
			vc1.vocabulary_id_v4 AS source_vocabulary_id,
			c1.concept_name AS source_code_description,
			c2.concept_id AS target_concept_id,
			vc2.vocabulary_id_v4 AS target_vocabulary_id,
			c2.domain_id AS mapping_type,
			'Y' AS primary_map,
			r.valid_start_date AS valid_start_date,
			r.valid_end_date AS valid_end_date,
			r.invalid_reason AS invalid_reason
		FROM devv5.concept c1,
			devv5.concept c2,
			devv5.concept_relationship r,
			devv5.vocabulary_conversion vc1,
			devv5.vocabulary_conversion vc2
		WHERE c1.concept_id = r.concept_id_1
			AND c2.concept_id = r.concept_id_2
			AND r.relationship_id = 'Maps to'
			AND c1.vocabulary_id = vc1.vocabulary_id_v5
			AND c2.vocabulary_id = vc2.vocabulary_id_v5
			AND NOT (
				c1.concept_name LIKE '%do not use%'
				AND c1.vocabulary_id IN (
					'ICD9CM',
					'ICD10',
					'MedDRA'
					)
				AND c1.invalid_reason IS NOT NULL
				)
			AND EXISTS (
				SELECT 1
				FROM concept c_int
				WHERE c_int.concept_id = c2.concept_id
				)
		) AS t;


	--unmapped concepts
	INSERT INTO source_to_concept_map (
		source_code,
		source_vocabulary_id,
		source_code_description,
		target_concept_id,
		target_vocabulary_id,
		mapping_type,
		primary_map,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT c1.concept_code AS source_code,
		vc1.vocabulary_id_v4 AS source_vocabulary_id,
		c1.concept_name AS source_code_description,
		0 AS target_concept_id,
		0 AS target_vocabulary_id,
		'Unmapped' AS mapping_type,
		'Y' AS primary_map,
		c1.valid_start_date AS valid_start_date,
		c1.valid_end_date AS valid_end_date,
		CASE 
			WHEN c1.invalid_reason = 'U'
				THEN 'D'
			ELSE c1.invalid_reason
			END
	FROM devv5.concept c1
	JOIN devv5.vocabulary_conversion vc1 ON vc1.vocabulary_id_v5 = c1.vocabulary_id
	WHERE NOT EXISTS (
			SELECT 1
			FROM devv5.concept_relationship r
			WHERE r.concept_id_1 = c1.concept_id
				AND r.relationship_id = 'Maps to'
				AND r.invalid_reason IS NULL
			)
		AND c1.concept_code <> 'OMOP generated'
		AND c1.concept_id IN (
			SELECT MIN(c2.concept_id) --remove duplicates
			FROM devv5.concept c2
			WHERE c2.vocabulary_id = c1.vocabulary_id
				AND c2.concept_code = c1.concept_code
			GROUP BY c2.vocabulary_id,
				c2.concept_code,
				c2.valid_end_date
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept c_int
			WHERE c_int.concept_id = c1.concept_id
			)
		AND NOT EXISTS (
			SELECT 1
			FROM source_to_concept_map s_int
			WHERE s_int.source_code = c1.concept_code
				AND s_int.source_vocabulary_id = vc1.vocabulary_id_v4
			)
		AND NOT (
			c1.concept_name LIKE '%do not use%'
			AND c1.vocabulary_id IN (
				'ICD9CM',
				'ICD10',
				'MedDRA'
				)
			AND c1.invalid_reason IS NOT NULL
			)
		AND c1.concept_class_id <> 'Concept Class';

	CREATE UNIQUE INDEX xpksource_to_concept_map ON source_to_concept_map (
		source_vocabulary_id,
		target_concept_id,
		source_code,
		valid_end_date
		);

	ALTER TABLE source_to_concept_map ADD CONSTRAINT xpksource_to_concept_map_chk CHECK (
		primary_map IN ('Y')
		AND invalid_reason IN (
			'D',
			'U'
			)
		),
		ADD PRIMARY KEY USING INDEX xpksource_to_concept_map,
		VALIDATE CONSTRAINT xpksource_to_concept_map_chk;

	ALTER TABLE source_to_concept_map 
		ADD CONSTRAINT source_to_concept_concept FOREIGN KEY (target_concept_id) REFERENCES concept (concept_id), VALIDATE CONSTRAINT source_to_concept_concept;

	INSERT INTO drug_strength
	SELECT s.drug_concept_id,
		s.ingredient_concept_id,
		s.amount_value,
		au.concept_code AS amount_unit,
		s.numerator_value AS concentration_value,
		nu.concept_code AS concentration_enum_unit,
		du.concept_code AS concentration_denom_unit,
		s.box_size,
		s.valid_start_date,
		s.valid_end_date,
		s.invalid_reason
	FROM devv5.drug_strength s
	JOIN concept au ON au.concept_id = s.amount_unit_concept_id
	LEFT JOIN concept nu ON nu.concept_id = s.numerator_unit_concept_id
	LEFT JOIN concept du ON du.concept_id = s.denominator_unit_concept_id;

	INSERT INTO pack_content
	SELECT s.pack_concept_id,
		s.drug_concept_id,
		s.amount,
		s.box_size
	FROM devv5.pack_content s
	JOIN concept au ON au.concept_id = s.pack_concept_id
	JOIN concept nu ON nu.concept_id = s.drug_concept_id;

	INSERT INTO vocabulary
	SELECT vocabulary_id_v4,
		vocabulary_id_v5
	FROM devv5.vocabulary_conversion;

	UPDATE vocabulary
	SET vocabulary_name = 'OMOP Vocabulary v4.5 ' || TO_CHAR(CURRENT_DATE, 'DD-MON-YY')
	WHERE vocabulary_id = 0;
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100
SET SCHEMA 'devv4'
SET client_min_messages = error;
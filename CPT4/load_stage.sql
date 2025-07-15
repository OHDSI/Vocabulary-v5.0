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
* Authors: Polina Talapova, Dmitry Dymshits, Timur Vakhitov, Christian Reich, Masha Khitrun
* Date: 2025
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CPT4',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.mrsmap LIMIT 1),
	pVocabularyVersion		=> (SELECT EXTRACT (YEAR FROM vocabulary_date)||' Release' FROM sources.mrsmap LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CPT4'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add CPT4 concepts from the source into the concept_stage using the MRCONSO table provided by UMLS  https://www.ncbi.nlm.nih.gov/books/NBK9685/table/ch03.T.concept_names_and_sources_file_mr/
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT vocabulary_pack.CutConceptName(UPPER(SUBSTRING(str FROM 1 FOR 1)) || SUBSTRING(str FROM 2 FOR LENGTH(str))) AS concept_name, -- field with a term name from mrconso
	'CPT4' AS vocabulary_id,
	'CPT4' AS concept_class_id,
	'S' AS standard_concept,
	scui AS concept_code, -- = mrconso.code
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso
WHERE sab = 'CPT'
	AND suppress NOT IN (
		'E', -- Non-obsolete content marked suppressible by an editor
		'O', -- All obsolete content, whether they are obsolesced by the source or by NLM
		'Y' -- Non-obsolete content deemed suppressible during inversion
		)
	AND tty IN (
		'PT', -- Designated preferred name
		'GLP' -- Global period
		);

--4. Add Place of Sevice (POS) CPT terms which do not appear in patient data and used for hierarchical search
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT vocabulary_pack.CutConceptName(UPPER(SUBSTRING(str FROM 1 FOR 1)) || SUBSTRING(str FROM 2 FOR LENGTH(str))) AS concept_name,
	'CPT4' AS vocabulary_id,
	'Visit' AS concept_class_id,
	NULL AS standard_concept,
	scui AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso
WHERE sab = 'CPT'
	AND suppress NOT IN (
		'E', -- Non-obsolete content marked suppressible by an editor
		'O', -- All obsolete content, whether they are obsolesced by the source or by NLM
		'Y' -- Non-obsolete content deemed suppressible during inversion
		)
	AND tty = 'POS';

--5. Add CPT Modifiers
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT FIRST_VALUE(vocabulary_pack.CutConceptName(UPPER(SUBSTRING(str FROM 1 FOR 1)) || SUBSTRING(str FROM 2 FOR LENGTH(str)))) OVER (
		PARTITION BY scui ORDER BY CASE 
				WHEN LENGTH(str) <= 255
					THEN LENGTH(str)
				ELSE 0
				END DESC,
			LENGTH(str) ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS concept_name,
	'CPT4' AS vocabulary_id,
	'CPT4 Modifier' AS concept_class_id,
	'S' AS standard_concept,
	scui AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso
WHERE sab IN (
		'CPT',
		'HCPT'
		)
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		)
	AND tty = 'MP';--Preferred names of modifiers

--6. Add Hierarchical CPT terms, which are considered to be Classification (do not appear in patient data, only for hierarchical search)
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT vocabulary_pack.CutConceptName(UPPER(SUBSTRING(str FROM 1 FOR 1)) || SUBSTRING(str FROM 2 FOR LENGTH(str))) AS concept_name,
	'CPT4' AS vocabulary_id,
	'CPT4 Hierarchy' AS concept_class_id,
	'C' AS standard_concept,
	scui AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso
WHERE sab IN (
		'CPT',
		'HCPT'
		)
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		)
	AND tty = 'HT';--Hierarchical terms

--7. Insert other existing CPT4 concepts that are absent in the source (should be outdated but alive)
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT CASE 
		WHEN c.concept_name LIKE '% (Deprecated)'
			THEN c.concept_name -- to support subsequent source deprecations 
		WHEN (
				COALESCE(c.invalid_reason, 'D') = 'D'
				OR (
					c.standard_concept = 'S'
					AND c.valid_end_date < TO_DATE('20991231', 'YYYYMMDD')
					)
				)
			AND LENGTH(c.concept_name) <= 242
			THEN c.concept_name || ' (Deprecated)'
		WHEN LENGTH(c.concept_name) > 242
			THEN LEFT(c.concept_name, 239) || '... (Deprecated)' -- to get no more than 255 characters in total and highlight concept_names which were cut
		ELSE c.concept_name -- for alive concepts
		END AS concept_name,
	c.vocabulary_id,
	CASE 
		WHEN LENGTH(c.concept_code) = 2
			THEN 'CPT4 Modifier'
		ELSE c.concept_class_id
		END AS concept_class_id,
	CASE 
		WHEN COALESCE(c.invalid_reason, 'D') = 'D'
			AND COALESCE(c.standard_concept, 'S') <> 'C'
			THEN 'S'
		WHEN c.concept_class_id = 'CPT4 Hierarchy'
			AND c.invalid_reason IS NOT NULL
			AND standard_concept IS NULL
			THEN 'C'
		ELSE c.standard_concept
		END AS standard_concept,
	c.concept_code,
	c.valid_start_date,
	CASE 
		WHEN c.valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
			THEN (
					SELECT latest_update
					FROM vocabulary
					WHERE vocabulary_id = 'CPT4'
					)
		ELSE c.valid_end_date
		END AS valid_end_date,
	NULLIF(c.invalid_reason, 'D') AS invalid_reason
FROM concept c
WHERE c.vocabulary_id = 'CPT4'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = c.concept_code
		);

--8. Add CPT4 codes which have no entry in sab = 'CPT' (only sab = 'HCPT'). Note, they are not HCPCS codes! 
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT vocabulary_pack.CutConceptName(UPPER(SUBSTRING(mr.str FROM 1 FOR 1)) || SUBSTRING(mr.str FROM 2 FOR LENGTH(str))) AS concept_name,
	'CPT4' AS vocabulary_id,
	'CPT4' AS concept_class_id,
	'S' AS standard_concept,
	mr.scui AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CPT4'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso mr
WHERE EXISTS (
		SELECT 1
		FROM sources.mrconso mr_int
		WHERE mr_int.sab = 'HCPT'
			AND mr_int.scui = mr.scui
			and mr.sab = 'HCPT'
		)
	AND NOT EXISTS (
		SELECT 1
		FROM sources.mrconso mr_int
		WHERE mr_int.sab = 'CPT'
			AND mr_int.scui = mr.scui
			and mr.sab = 'CPT'
		)
	AND (
		(
			mr.tty = 'PT'
			AND mr.suppress = 'N'
			)
		OR (
			mr.tty = 'OP'
			AND mr.suppress = 'O'
			)
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = mr.scui
		);

--9. Pick up all different str values that are not obsolete or suppressed
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT scui AS synonym_concept_code,
	vocabulary_pack.CutConceptSynonymName(str) AS synonym_name,
	'CPT4' AS synonym_vocabulary_id,
	4180186 AS language_concept_id
FROM sources.mrconso
WHERE sab IN (
		'CPT',
		'HCPT'
		)
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		);

--10. Add names concatenated with the names of source concept classes 
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT s0.synonym_concept_code,
	vocabulary_pack.CutConceptSynonymName(s0.concept_name || ' | ' || STRING_AGG('[' || s0.sty || ']', ' - ' ORDER BY s0.sty)) AS synonym_name,
	'CPT4' AS synonym_vocabulary_id,
	4180186 AS language_concept_id
FROM (
	/*it seems like a distinct can be used inside string_agg. yes, but it does not work with "order by", so we need a subquery for distinct values before "order by"*/
	SELECT DISTINCT cs.concept_code AS synonym_concept_code,
		cs.concept_name,
		m2.sty
	FROM concept_stage cs
	JOIN sources.mrconso m1 ON m1.code = cs.concept_code
	JOIN sources.mrsty m2 ON m2.cui = m1.cui
	WHERE m1.sab IN (
			'CPT',
			'HCPT'
			)
	) AS s0
GROUP BY s0.synonym_concept_code,
	s0.concept_name;

--11. Extract "hidden" CPT4 codes inside concept_names of another CPT4 codes.
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT *
FROM (
	SELECT UNNEST(REGEXP_MATCHES(concept_name, '\((\d\d\d\d[A-Z])\)', 'gi')) AS concept_code_1,
		concept_code AS concept_code_2,
		'Subsumes' AS relationship_id,
		'CPT4' AS vocabulary_id_1,
		'CPT4' AS vocabulary_id_2,
		TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
		TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
		NULL AS invalid_reason
	FROM concept_stage
	WHERE vocabulary_id = 'CPT4'
	) AS s
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = s.concept_code_1
			AND crs.concept_code_2 = s.concept_code_2
			AND crs.relationship_id = 'Subsumes'
			AND crs.vocabulary_id_1 = 'CPT4'
			AND crs.vocabulary_id_2 = 'CPT4'
		);

--12. Update dates from mrsat.atv (only for new concepts)
UPDATE concept_stage cs
SET valid_start_date = i.dt
FROM (
	SELECT MAX(TO_DATE(s.atv, 'YYYYMMDD')) dt,
		cs.concept_code
	FROM concept_stage cs
	LEFT JOIN sources.mrconso m ON m.scui = cs.concept_code
		AND m.sab IN (
			'CPT',
			'HCPT'
			)
	LEFT JOIN sources.mrsat s ON s.cui = m.cui
		AND s.atn = 'DA'
	WHERE NOT EXISTS (
			-- only new codes we don't already have
			SELECT 1
			FROM concept co
			WHERE co.concept_code = cs.concept_code
				AND co.vocabulary_id = cs.vocabulary_id
			)
		AND cs.vocabulary_id = 'CPT4'
		AND cs.concept_class_id = 'CPT4'
		AND s.atv IS NOT NULL
	GROUP BY concept_code
	) i
WHERE i.concept_code = cs.concept_code;

--13. Update domain_id in concept_stage
UPDATE concept_stage cs
SET domain_id = t1.domain_id
FROM (
	SELECT DISTINCT cs.concept_code,
		CASE -- word patterns defined according to the frequency of the occurrence in the existing domains
			WHEN cs.concept_name ~* '^electrocardiogram, routine ecg|^pinworm|excision|supervision|removal|abortion|introduction|sedation|endoscopy|insertion'
				AND m2.tui NOT IN (
					'T033',
					'T034'
					)
				AND cs.concept_code NOT IN (
					'0244U', -- Oncology (solid organ), DNA, comprehensive genomic profiling
					'0250U', -- Oncology (solid organ neoplasm), targeted genomic sequence DNA analysis of 505 genes,...
					'0258U', -- Autoimmune (psoriasis), mRNA, next-generation sequencing, gene expression profiling of 50-100 genes,...
					'0260U', -- Rare diseases (constitutional/heritable disorders), identification of copy number variations...
					'0264U', -- Rare diseases (constitutional/heritable disorders), identification of copy number variations...
					'0267U', -- Rare constitutional and other heritable disorders, identification of copy number variations...
					'0335U', -- Neurology (prion disease), cerebrospinal fluid, detection of prion protein ...
					'0336U' -- Oncology (oropharyngeal), evaluation of 17 DNA biomarkers using droplet digital PCR (ddPCR),...
					)
				THEN 'Procedure'
			WHEN m2.tui = 'T023'
				THEN 'Spec Anatomic Site'
			WHEN m2.sty = 'Medical Device'
				AND cs.concept_code <> '44015'
				THEN 'Device'
			WHEN cs.concept_code IN (
					'99143',
					'99144',
					'99148',
					'99149', -- 99143-99149 Moderate sedation services
					'44015' -- Tube or needle catheter jejunostomy
					)
				THEN 'Procedure'
			WHEN m2.tui IN (
					'T121',
					'T109',
					'T200'
					)
				AND cs.concept_code NOT IN (
					'86789', -- Antibody; West Nile virus
					'1036228'
					) -- Estradiol (measurement)
				THEN 'Drug'
			WHEN tty = 'POS'
				AND cs.concept_code NOT IN (
					'1022193', -- Introduction
					'1022194', -- Section Numbers and Their Sequences
					'44015' -- Tube or needle catheter jejunostomy
					)
				THEN 'Visit'
			WHEN m2.tui = 'T059'
				AND cs.concept_name !~* ('processing|preparation|procedure|isolation|storage|preservation|thawing|biopsy|treatment|consultation|collection|fertilization|insemination|sampling|digitization')
				AND cs.concept_code NOT IN (
						'86960',
						'86965',
						'86985',
						'86890',
						'86891',
						'1011136',
						'1011189',
						'1012112',
						'1012123',
						'1012127',
						'1012348',
						'1012534',
						'1012537',
						'1012546',
						'1012559',
						'1012564',
						'1014644',
						'1018504',
						'1019105',
						'1037591'
						)
					OR cs.concept_code IN ('1036228', '0564T')
					OR (length(cs.concept_code) > 2
					    AND cs.concept_code LIKE '%U') -- Proprietary Laboratory Analyses
				THEN 'Measurement'
			WHEN m2.tui IN (
					'T081',
					'T097',
					'T077'
					)
				OR (
					m2.tui = 'T185'
					AND tty <> 'HT'
					AND tty <> 'MP'
					)
				OR (
					m2.tui = 'T080'
					AND cs.concept_name NOT ILIKE '%modifier%'
					)
				THEN 'Meas Value'
			WHEN (
					cs.concept_name !~* ('echocardiograph|electrocardiograph|ultrasound|fitting|emptying|\yscores?\y|algorithm|dosimetry|detection|services/procedures|therapy|evaluation|assessment|recording|screening|\ycare\y|counseling|insertion|abortion|transplant|tomography|^infectious disease|^oncology|monitoring|typing|cytopathology|^ophthalmolog|^visual field')
					AND (
							cs.concept_name ~* 'documented|^patient|established|prescribed|assessed|reviewed|receiving|reported|services|\(DM\)|symptoms|visit|\(HIV\)|instruction|ordered'
							OR (
								LENGTH(cs.concept_code) <= 2
								AND cs.concept_code NOT IN (
									'TP',
									'KR'
									)
								)
							)
					)
				OR (
					m2.tui = 'T093'
					AND m1.tty <> 'POS'
					)
				OR (
					m2.tui = 'T058'
					AND cs.concept_name ~* ('documented|^patient|established|prescribed|assessed|reviewed|receiving|reported|services|\(DM\)|symptoms|visit|\(HIV\)|instruction|ordered')
					AND m1.tty <> 'ETCLIN'
					)
				OR (
					m2.tui = 'T033'
					AND cs.concept_code NOT IN (
						'80346',
						'80347',
						'1014978',
						'94729',
						'TE',
						'27',
						'26567',
						'G7',
						'QF',
						'QG',
						'QE',
						'QB',
						'QR',
						'QA',
			  			'78801'
						)
					)
				OR cs.concept_code IN (
						'80500',
						'80502',
						'4060F',
						'77370',
						'99429',
						'1037418',
						'1037424',
						'1037420'
						)
				THEN 'Observation'
			WHEN c.concept_code IN (
					'TP',
					'KR'
					)
				THEN 'Device'
			WHEN c.concept_id IS NOT NULL
				THEN c.domain_id -- regarding the fact that CPT4 codes are met in Claims as procedures
			ELSE 'Procedure'
			END AS domain_id -- preserve existing domains for all other cases
	FROM concept_stage cs
	LEFT JOIN concept c ON c.concept_code = cs.concept_code
		AND c.vocabulary_id = 'CPT4'
	LEFT JOIN sources.mrconso m1 ON m1.code = cs.concept_code
		AND m1.sab IN (
			'CPT',
			'HCPT'
			)
	LEFT JOIN sources.mrsty m2 ON m2.cui = m1.cui
	) t1
WHERE t1.concept_code = cs.concept_code;

--14. Create hierarchical relationships between HT and normal CPT codes
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c1.code AS concept_code_1,
	c2.code AS concept_code_2,
	'Is a' AS relationship_id,
	'CPT4' AS vocabulary_id_1,
	'CPT4' AS vocabulary_id_2,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT aui AS aui1,
		REGEXP_REPLACE(ptr, '(.+\.)(A\d+)$', '\2', 'g') AS aui2
	FROM sources.mrhier
	WHERE sab = 'CPT'
		AND rela = 'isa'
	) h
JOIN sources.mrconso c1 ON c1.aui = h.aui1
	AND c1.sab = 'CPT'
JOIN sources.mrconso c2 ON c2.aui = h.aui2
	AND c2.sab = 'CPT';

--15. Add relationships of equivalence between CPT4 and SNOMED
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT m2.code AS concept_code_1,
	m3.code AS concept_code_2,
	CASE
		WHEN rel = 'PAR'
			THEN 'CPT4 - SNOMED cat'
		WHEN rel = 'SY'
			THEN 'CPT4 - SNOMED eq'
		END AS relationship_id,
	'CPT4' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	(SELECT latest_update
	 FROM vocabulary
	 WHERE vocabulary_id = 'CPT4') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT cui1,
		cui2,
		rel
	FROM sources.mrrel m
	WHERE m.rel IN (
			'PAR', --has parent relationship in a Metathesaurus source vocabulary
			'SY'
			) --source asserted synonymy
		AND m.sab = 'CPT'
	) m1
JOIN sources.mrconso m2 ON m2.cui = m1.cui1
	AND m2.sab = 'CPT'
JOIN concept a ON a.concept_code = m2.code
	AND a.vocabulary_id = 'CPT4'
	AND a.concept_class_id = 'CPT4'
JOIN sources.mrconso m3 ON m3.cui = m1.cui2
	AND m3.sab = 'SNOMEDCT_US'
WHERE EXISTS (
		SELECT 1
		FROM concept c
		WHERE c.concept_code = m3.code
			AND c.vocabulary_id = 'SNOMED'
			AND c.invalid_reason IS NULL
		);

--16. Add everything from the Manual tables
--Working with manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--Working with manual synonyms
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--Working with manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
	PERFORM VOCABULARY_PACK.AddPropagatedHierarchyMapsTo(null, '{CVX, RxNorm}', null);
END $_$;

--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--17. All concepts mapped to RxNorm/RxNorm Ext./CVX should be assigned with Drug domain
UPDATE concept_stage cs
SET domain_id = 'Drug'
FROM concept_relationship_stage crs
WHERE crs.vocabulary_id_2 IN (
		'RxNorm',
		'RxNorm Extension',
		'CVX'
		)
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL
	AND cs.concept_class_id <> 'CPT4 Hierarchy'
	AND cs.concept_code = crs.concept_code_1
	AND cs.vocabulary_id = crs.vocabulary_id_1;

-- At the end, the concept_stage, concept_relationship_stage and concept_synonym_stage tables are ready to be fed into the generic_update script
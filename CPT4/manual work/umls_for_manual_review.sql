--Use this script to extract relationships of synonymy and ancestry provided by UMLS source
--Add these relationships to CPT4_mapped spreadsheet and review
WITH umls_mapping AS (
	SELECT a.concept_name AS source_concept_name,
		 a.concept_code AS source_concept_code,
		 a.concept_class_id AS source_concept_class_id,
		 a.invalid_reason AS source_invalid_reason,
		 a.domain_id AS source_domain_id,
		 a.vocabulary_id AS source_vocabulary_id,
		 null AS cr_invalid_reason,
		 null AS mapping_tool,
		 null AS mapping_source,
		 '1' AS confidence,
	 CASE WHEN rel = 'PAR'
	        THEN 'Is a'
		WHEN rel = 'SY'
			THEN 'Maps to'
			END AS relationship_id,
		null as relationship_id_predicate,
		 'to_review' AS source,
		 null as comments,
		 c.concept_id AS target_concept_id,
		 c.concept_code AS target_concept_code,
		 c.concept_name AS target_concept_name,
		 c.concept_class_id AS target_concept_class_id,
		 c.standard_concept AS target_standard_concept,
		 c.invalid_reason AS target_invalid_reason,
		 c.domain_id AS target_domain_id,
		 c.vocabulary_id AS target_vocabulary_id,
		 'your_name' AS mapper_id,
		 'your_name' AS reviewer_id,
		 ROW_NUMBER() OVER (PARTITION BY m2.code || ' ' || m3.code) AS sort
	FROM (SELECT cui1, cui2, rel
				FROM sources.mrrel
				WHERE rel IN ('PAR', --has parent relationship in a Metathesaurus source vocabulary
							  'SY') --source asserted synonymy
					AND sab = 'CPT') m1
			JOIN sources.mrconso m2 ON m1.cui1 = m2.cui
					 AND m2.sab = 'CPT'
					 AND LENGTH(m2.code) = 5
			JOIN concept a ON a.concept_code = m2.code
					 AND a.vocabulary_id = 'CPT4'
			JOIN sources.mrconso m3 ON m1.cui2 = m3.cui
					 AND m3.sab = 'SNOMEDCT_US'
					 AND m3.str NOT LIKE 'Retired procedure%'
			JOIN devv5.concept c ON m3.code = c.concept_code
					 AND c.vocabulary_id = 'SNOMED'
					 AND c.standard_concept = 'S'
	WHERE m2.code NOT IN (SELECT source_code
								FROM cpt4_mapped))

SELECT *
FROM umls_mapping
WHERE sort = 1
ORDER BY source_concept_code, relationship_id
;
-- 1. Populate concept_stage table
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
	)*/
SELECT DISTINCT vocabulary_pack.CutConceptName(UPPER(SUBSTRING(str FROM 1 FOR 1)) || SUBSTRING(str FROM 2 FOR LENGTH(str))) AS concept_name,
                'Condition' AS domain_id,
                'Orphanet' AS vocabulary_id,
                s.sty AS concept_class_id, -- not sure about it. See sty = 'Pharmacologic substance': select * from sources.mrconso where cui = 'C0022230'
                NULL AS standard_concept,
                m.code as concept_code,
             /*   (
                SELECT latest_update
                FROM vocabulary
                WHERE vocabulary_id = 'Orphanet'
                ) AS valid_start_date,*/
                TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	            NULL AS invalid_reason
FROM sources.mrconso m
JOIN sources.mrsty s USING (cui)
WHERE sab = 'ORPHANET'
and suppress = 'N'
and tty = 'PT';


-- 2. Populate concept_synonym table:
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT m.code,
	            'Orphanet',
	            vocabulary_pack.CutConceptSynonymName(m.str),
	            4180186
from sources.mrconso m
WHERE sab = 'ORPHANET'
and tty = 'SY';

-- semantic types (may be added to synonyms or used as classificators)
SELECT distinct s.*
from sources.mrsty s
join sources.mrconso c using(cui)
where c.sab = 'ORPHANET'
and c.tty = 'PT';

-- 3. Create hierarchical relationships:
/*INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)*/
SELECT DISTINCT c1.code AS concept_code_1,
	c2.code AS concept_code_2,
	'Is a' AS relationship_id,
	'Orphanet' AS vocabulary_id_1,
	'Orphanet' AS vocabulary_id_2,
	(SELECT latest_update
	 FROM vocabulary
	 WHERE vocabulary_id = 'Orphanet') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
from sources.mrrel r
join sources.mrconso c1 on c1.cui = r.cui2
join sources.mrconso c2 on c2.cui = r.cui1
where r.sab = 'ORPHANET'
and rela = 'isa'
and c1.sab = 'ORPHANET'
and c2.sab = 'ORPHANET'
;

-- 4. Add mappings to SNOMED:
/*INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)*/
SELECT DISTINCT c.code AS concept_code_1,
                cc.code AS concept_code_2,
                'Maps to' AS relationship_id,
                'Orphanet' AS vocabulary_id_1,
	            'Orphanet' AS vocabulary_id_2,
                (SELECT latest_update
                 FROM vocabulary
                 WHERE vocabulary_id = 'Orphanet') AS valid_start_date,
	            TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	            NULL AS invalid_reason
FROM sources.mrconso c
JOIN sources.mrconso cc using(cui)
WHERE c.tty = 'PT'
AND cc.tty = 'PT'
AND c.sab = 'ORPHANET'
AND cc.sab = 'SNOMEDCT_US'
AND cc.lat = 'ENG'
;
-- variant 2 - 'dirty' mappings
SELECT DISTINCT c.code as source_code,
       c.str as source_name,
       'Maps to' as relationship_id,
       cc.code as target_code,
       cc.str as target_name
from sources.mrrel r
join sources.mrconso c on c.cui = r.cui2
join sources.mrconso cc on cc.cui = r.cui1
where r.sab != 'ORPHANET'
and rela = 'mapped_to'
and c.tty = 'PT'
and cc.tty = 'PT'
and c.sab = 'ORPHANET'
and cc.lat = 'ENG'
and cc.sab = 'SNOMEDCT_US'
;

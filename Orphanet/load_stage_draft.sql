-- 1. Populate concept_stage table
/*INSERT INTO concept_stage (
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
SELECT DISTINCT vocabulary_pack.CutConceptName(str) AS concept_name,
                'Condition' AS domain_id,
                'Orphanet' AS vocabulary_id,
                '??' AS concept_class_id,
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
/*INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)*/
SELECT DISTINCT m.code,
	            'Orphanet',
	            vocabulary_pack.CutConceptSynonymName(m.str),
	            4180186
from sources.mrconso m
WHERE sab = 'ORPHANET'
and tty = 'SY';

-- semantic types (may be added to synonyms or used as classificators)
-- not sure about concept_class. See sty = 'Pharmacologic substance': select * from sources.mrconso where cui = 'C0022230'
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

WITH umls_map AS
    (SELECT DISTINCT c.code AS concept_code_1,
                cc.code AS concept_code_2,
               /* c.str as source_name,
                cc.str as target_name,*/
                count(cc.code) over (partition by c.code) as t_count
    FROM sources.mrconso c
    JOIN sources.mrconso cc using(cui)
    JOIN concept c1 on c1.concept_code = cc.code
                           and c1.vocabulary_id = 'SNOMED'
                           and c1.concept_class_id in ('Clinical Finding', 'Disorder')
                           and c1.standard_concept = 'S'
    WHERE c.tty = 'PT'
    AND cc.tty = 'PT'
    AND c.sab = 'ORPHANET'
    AND cc.sab = 'SNOMEDCT_US'
    AND cc.lat = 'ENG')
SELECT DISTINCT concept_code_1,
                concept_code_2,
               /* source_name,
                target_name,*/
                'Maps to' AS relationship_id,
                'Orphanet' AS vocabulary_id_1,
	            'SNOMED' AS vocabulary_id_2,
               /* (SELECT latest_update
                 FROM vocabulary
                 WHERE vocabulary_id = 'Orphanet') AS valid_start_date,*/
	            TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	            NULL AS invalid_reason
FROM umls_map
WHERE t_count = 1
;

-- Mapping for manual review:
WITH umls_map AS
    (SELECT DISTINCT c.code AS concept_code_1,
                cc.code AS concept_code_2,
                c.str as source_code_description,
                cc.str as target_concept_name,
                count(cc.code) over (partition by c.code) as t_count
    FROM sources.mrconso c
    JOIN sources.mrconso cc using(cui)
    JOIN concept c1 on c1.concept_code = cc.code
                           and c1.vocabulary_id = 'SNOMED'
                           and c1.concept_class_id in ('Clinical Finding', 'Disorder')
                           and c1.standard_concept = 'S'
    WHERE c.tty = 'PT'
    AND cc.tty = 'PT'
    AND c.sab = 'ORPHANET'
    AND cc.sab = 'SNOMEDCT_US'
    AND cc.lat = 'ENG')
SELECT DISTINCT source_code_description,
        concept_code_1,
        'Orphanet' as vocabulary_id,
		'Maps to' as relationship_id,
        'UMLS' as source,
        cc.concept_id,
		cc.concept_code,
       	cc.concept_name,
       	cc.concept_class_id as target_concept_class_id,
       	cc.standard_concept as target_standard_concept,
       	cc.invalid_reason as target_invalid_reason,
       	cc.domain_id as target_domain_id,
       	cc.vocabulary_id as target_vocabulary_id
FROM umls_map u
JOIN concept cc on u.concept_code_2 = cc.concept_code and cc.vocabulary_id = 'SNOMED'
WHERE t_count > 1
ORDER BY concept_code_1
;

-- variant 2 - 'dirty' mappings from mrrel table
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

-- Mapping using full-text search (preferred):
with tab as (
SELECT DISTINCT vocabulary_pack.CutConceptName(str) AS concept_name,
                'Condition' AS domain_id,
                'Orphanet' AS vocabulary_id,
                '??' AS concept_class_id,
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
and tty = 'PT'),
    cte as (
select distinct t.concept_name, t.concept_code, cr.relationship_id, cc. concept_code as target_code, cc.concept_name as target_name, cc.vocabulary_id as target_vocab,
                (devv5.similarity(t.concept_name, cc.concept_name) * 100)::int AS sim,
                    (dev_schema.overlap_count(STRING_TO_ARRAY(t.concept_name, ' '),
                                          STRING_TO_ARRAY(cc.concept_name, ' '))) * 10     AS ovelap_cnt,
                    devv5.difference(t.concept_name,  cc.concept_name) * 10         AS difference_cnt,
                    COUNT(DISTINCT cr1.concept_id_1) * 20                                 AS onto_cnt,
                    ((devv5.similarity(t.concept_name, cc.concept_name) * 100)::int) +
                    (dev_schema.overlap_count(STRING_TO_ARRAY(t.concept_name, ' '),
                                           STRING_TO_ARRAY(cc.concept_name, ' ')) * 10) -
                    (devv5.difference(t.concept_name, cc.concept_name) * 10) +
                    (COUNT(DISTINCT cr1.concept_id_1) * 20)                               AS intergral_cnt

from tab t
join concept c on plainto_tsquery(t.concept_name) = plainto_tsquery(c.concept_name)
and c.vocabulary_id = 'SNOMED'
join concept_relationship cr on c.concept_id = cr.concept_id_1 and relationship_id like 'Maps to%'
and cr.invalid_reason is null
join concept cc on cc.concept_id = cr.concept_id_2
 JOIN concept_relationship cr1
                           ON cc.concept_id = cr1.concept_id_2
                               AND cr1.relationship_id IN ('Maps to', 'Maps to value', 'Subsumes', 'Is a')
                               AND cr1.invalid_reason IS NULL
group by t.concept_name, t.concept_code, cr.relationship_id, cc.concept_id, cc.concept_name, cc.domain_id, cc.vocabulary_id, cc.concept_class_id, cc.standard_concept, cc.concept_code, cc.valid_start_date, cc.valid_end_date, cc.invalid_reason, cc.concept_name, cc.concept_name, cc.concept_name, cc.concept_name, cc.concept_name)

,tab2 as (
    SELECT *,       row_number() OVER (PARTITION BY concept_code ORDER BY intergral_cnt DESC)  AS rating_in_section
    from cte
)

select *
from tab2 where rating_in_section = 1;
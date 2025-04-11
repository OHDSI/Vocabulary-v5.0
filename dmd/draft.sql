
-- 1. Set latest_update:
-- 2. Truncate stages:
TRUNCATE concept_stage;
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;

-- 3. Populate concept_stage:
/*insert into concept_stage
(concept_name,
 domain_id,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 valid_start_date,
 valid_end_date,
 invalid_reason)
SELECT d.term,
       null,
       null,
       null,
       null,
       c.id,
       c.vocabulary_date::date,
       '2099-12-31',
       null
FROM sources.sct2_concept_full_gb_de c
JOIN sources.sct2_desc_full_gb_de d on d.conceptid = c.id and d.typeid = '900000000000003001'
limit 100;*/

INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT sct2.concept_name,
	'dm+d' AS vocabulary_id,
	sct2.concept_code,
	TO_DATE(effectivestart, 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT vocabulary_pack.CutConceptName(d.term) AS concept_name,
		d.conceptid AS concept_code,
		c.active,
		FIRST_VALUE(c.effectivetime) OVER (
			PARTITION BY c.id ORDER BY c.active DESC,
				c.effectivetime --if there ever were active versions of the concept, take the earliest one
			) AS effectivestart,
		ROW_NUMBER() OVER (
			PARTITION BY d.conceptid
			-- Order of preference:
			-- Active descriptions first, characterised as Preferred Synonym, then take the latest term
			ORDER BY c.active DESC,
				d.active DESC,
				l.active DESC,
				CASE l.acceptabilityid
					WHEN '900000000000548007'
						THEN 1 --Preferred
					WHEN '900000000000549004'
						THEN 2 --Acceptable
					ELSE 99
					END ASC,
				CASE d.typeid
					WHEN '900000000000013009'
						THEN 1 --Synonym (PT)
					WHEN '900000000000003001'
						THEN 2 --Fully specified name
					ELSE 99
					END ASC,
				CASE l.refsetid
					WHEN '900000000000509007'
						THEN 1 --US English language reference set
					WHEN '900000000000508004'
						THEN 2 --UK English language reference set
					ELSE 99 -- Various UK specific refsets
					END,
				l.effectivetime DESC,
				d.term
			) AS rn
	FROM sources.sct2_concept_full_gb_de c
	JOIN sources.sct2_desc_full_gb_de d ON d.conceptid = c.id
	JOIN sources.der2_crefset_language_gb_de l ON l.referencedcomponentid = d.id
	) sct2
WHERE sct2.rn = 1;

ANALYZE concept_stage;

-- For concepts with latest entry in sct2_concept having active = 0, preserve invalid_reason and valid_end date
UPDATE concept_stage cs
SET invalid_reason = 'D',
	valid_end_date = i.effectiveend
FROM (
	SELECT s0.*
	FROM (
		SELECT DISTINCT ON (c.id) c.id,
			TO_DATE(c.effectivetime, 'YYYYMMDD') AS effectiveend,
			c.active
		FROM sources.sct2_concept_full_gb_de c
		ORDER BY c.id,
			TO_DATE(c.effectivetime, 'YYYYMMDD') DESC
		) s0
	WHERE s0.active = 0
	) i
WHERE i.id = cs.concept_code;

update concept_stage cs
set concept_class_id = case
    when concept_code in (select vpid
                          from dev_dmd.vmps)
        then 'VMP'
    when concept_code in (select vppid
                          from dev_dmd.vmpps)
        then 'VMPP'
    when concept_code in (select apid
                          from dev_dmd.amps)
        then 'AMP'
    when concept_code in (select appid
                          from dev_dmd.ampps)
        then 'AMPP'
    when concept_code in (select isid
                          from dev_dmd.ingredient_substances)
        then 'Ingredient'
    when concept_code in (select vtmid
                          from dev_dmd.vtms)
        then 'VTM'
    when concept_code in (select cd
                          from dev_dmd.supplier)
        then 'Supplier'
    when concept_code in (select cd
                          from dev_dmd.forms)
        then 'Form'
    when concept_code in (select sourceid
                          from sources.sct2_rela_full_gb_de
                          where destinationid in ('9191801000001103', -- NHS dm+d trade family
                              '9191901000001109') --NHS dm+d trade family group
                          and active = 1)
    then 'Brand'
else (select c.concept_class_id
      from concept c
      where c.concept_code = cs.concept_code
      and c.vocabulary_id = 'dm+d') end
;

select * from concept_stage where concept_code in (select conceptid
                          from sources.sct2_desc_full_gb_de
                          where term like '% - brand name');

select * from concept_stage where concept_class_id is null
order by valid_start_date desc;



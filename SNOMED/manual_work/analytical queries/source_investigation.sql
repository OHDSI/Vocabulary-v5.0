--We have three SNOMED modules automatically merged into source tables.
-- These modules do not correspond to the dependencies between local and international versions of SNOMED.
-- We need an approach for creating a merged source according to the pre-defined versions.
-- The scripts below are used to compare the content of the source merged of three distinct modules (INT, UK, US)
-- and the default source from the sources schema trimmed to the according effective dates:

--List of SNOMED source tables:
---der2_ssrefset_moduledependency_merged
---sct2_concept_full_merged
---sct2_desc_full_merged
---der2_crefset_language_merged
---sct2_rela_full_merged
---der2_crefset_assreffull_merged

--List of SNOMED test source tables:
---der2_ssrefset_moduledependency_merged_test
---sct2_concept_full_merged_test
---sct2_desc_full_merged_test
---der2_crefset_language_merged_test
---sct2_rela_full_merged_test
---der2_crefset_assreffull_merged_test

--1. Define effective dates for the modules
---	900000000000207008 --Core (international) module --20240801
--- 900000000000012004	-- SNOMED CT model component --20240801
--- 999000011000000103 --UK edition --20241001
--- 731000124108 --US edition --20240901

SELECT moduleid, max (sourceeffectivetime)
FROM sources.der2_ssrefset_moduledependency_merged_test
where moduleid in ('900000000000207008','731000124108', '999000011000000103')
GROUP BY moduleid;

--3. Compare the content of tables:
---sct2_concept_full_merged
WITH trimmed AS (
       SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 statusid
		-- vocabulary_date,
		-- vocabulary_version
	FROM sources.sct2_concept_full_merged
	--WHERE effectivetime <= '20231122'
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240801'
								 WHEN moduleid = '900000000000012004' THEN '20240801'
								 WHEN moduleid = '731000124108' THEN '20240901'
								 WHEN moduleid = '999000011000000103' THEN '20241001' END)
		 AND moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 )
)

-- compare total counts of the test table with test + trimmed
/*sum as (
SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 statusid
		-- vocabulary_date,
		-- vocabulary_version
FROM sources.sct2_concept_full_merged_test
WHERE moduleid NOT IN (
						'999000011000001104', --UK Drug extension
						'999000021000001108') --UK Drug extension reference set module
UNION

SELECT * FROM trimmed
)

SELECT 'test' as source,
       count (*) FROM sources.sct2_concept_full_merged_test m
                 where moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
UNION ALL

SELECT 'test+trimmed' as source,
        count(*) from sum;*/

-- review rows that were changed since the test date
SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 statusid
		-- vocabulary_date,
		-- vocabulary_version
FROM sources.sct2_concept_full_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module

EXCEPT

SELECT * FROM trimmed;

---sct2_desc_full_merged
WITH trimmed AS (
       SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 conceptid,
		 languagecode,
		 typeid,
		 term,
		 casesignificanceid
	FROM sources.sct2_desc_full_merged
 	--WHERE effectivetime <= '20231122'
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240801'
								 WHEN moduleid = '900000000000012004' THEN '20240801'
								 WHEN moduleid = '731000124108' THEN '20240901'
								 WHEN moduleid = '999000011000000103' THEN '20241001' END)
		 AND moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 )
)

-- compare total counts of the test table with test + trimmed
/*sum as (
       SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 conceptid,
		 languagecode,
		 typeid,
		 term,
		 casesignificanceid
FROM sources.sct2_desc_full_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
	UNION

SELECT * FROM trimmed
)

SELECT 'test' as source,
       count (*) FROM sources.sct2_desc_full_merged_test m
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
UNION ALL

SELECT 'test+trimmed' AS source,
        count(*) FROM sum*/

-- review rows that were changed since the test date
SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 conceptid,
		 languagecode,
		 typeid,
		 term,
		 casesignificanceid
FROM sources.sct2_desc_full_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module

EXCEPT

SELECT * FROM trimmed
;

--der2_crefset_language_merged
WITH trimmed AS (
       SELECT DISTINCT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 acceptabilityid,
		 source_file_id
	FROM sources.der2_crefset_language_merged
	--WHERE effectivetime <= '20231122'
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240801'
								 WHEN moduleid = '900000000000012004' THEN '20240801'
								 WHEN moduleid = '731000124108' THEN '20240901'
								 WHEN moduleid = '999000011000000103' THEN '20241001' END)
		 AND moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 )
)

-- compare total counts of the test table with test + trimmed
/*sum as (
       SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 acceptabilityid,
		 source_file_id
FROM sources.der2_crefset_language_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
UNION

SELECT * from trimmed
)

SELECT 'test' as source,
       count (*) FROM sources.der2_crefset_language_merged_test m
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
UNION ALL

SELECT 'test+trimmed' AS source,
        count(*) FROM sum;*/

-- review rows that were changed since the test date
SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 acceptabilityid,
		 source_file_id
FROM sources.der2_crefset_language_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
EXCEPT

SELECT * FROM trimmed

;

---example template:
SELECT 'trimmed' as source, * from sources.der2_crefset_language_merged WHERE id = '80068033-f65b-4bc3-a05d-0b115fd47323'

UNION ALL

SELECT 'test',
       id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 acceptabilityid,
		 source_file_id
FROM sources.der2_crefset_language_merged_test WHERE id = '80068033-f65b-4bc3-a05d-0b115fd47323';
;

--sct2_rela_full_merged
WITH trimmed AS (
       SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 sourceid,
		 destinationid,
		 relationshipgroup,
		 typeid,
		 characteristictypeid,
		 modifierid
	FROM sources.sct2_rela_full_merged
	--	WHERE effectivetime <= '20231122'
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240801'
								 WHEN moduleid = '900000000000012004' THEN '20240801'
								 WHEN moduleid = '731000124108' THEN '20240901'
								 WHEN moduleid = '999000011000000103' THEN '20241001' END)
		 AND moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 )
)

-- compare total counts of the test table with test + trimmed
/*sum as (
       SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 sourceid,
		 destinationid,
		 relationshipgroup,
		 typeid,
		 characteristictypeid,
		 modifierid
FROM sources.sct2_rela_full_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
	UNION

SELECT * FROM trimmed
)

SELECT 'test' as source,
       count (*) FROM sources.sct2_rela_full_merged_test m
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
UNION ALL

SELECT 'test+trimmed' AS source,
        count(*) FROM sum;*/

-- review rows that were changed since the test date
SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 sourceid,
		 destinationid,
		 relationshipgroup,
		 typeid,
		 characteristictypeid,
		 modifierid
FROM sources.sct2_rela_full_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module

EXCEPT

SELECT * FROM trimmed
;

--der2_crefset_assreffull_merged
WITH trimmed AS (
       SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 targetcomponent
	FROM sources.der2_crefset_assreffull_merged
--WHERE effectivetime <= '20231122'
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240801'
								 WHEN moduleid = '900000000000012004' THEN '20240801'
								 WHEN moduleid = '731000124108' THEN '20240901'
								 WHEN moduleid = '999000011000000103' THEN '20241001' END)
		 AND moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 )
)

-- compare total counts of the test table with test + trimmed
/*sum as (
       SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 targetcomponent
FROM sources.der2_crefset_assreffull_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
	UNION

SELECT * FROM trimmed
)

SELECT 'test' as source,
       count (*) FROM sources.der2_crefset_assreffull_merged_test m
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
UNION ALL

SELECT 'test+trimmed' AS source,
        count(*) FROM sum*/

-- review rows that were changed since the test date
SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 targetcomponent
FROM sources.der2_crefset_assreffull_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module

EXCEPT

SELECT * FROM trimmed
;

--der2_ssrefset_moduledependency_merged
WITH trimmed AS (
SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 sourceeffectivetime,
		 targeteffectivetime
	FROM sources.der2_ssrefset_moduledependency_merged
	--WHERE effectivetime <= '20231122'
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240801'
								 WHEN moduleid = '900000000000012004' THEN '20240801'
								 WHEN moduleid = '731000124108' THEN '20240901'
								 WHEN moduleid = '999000011000000103' THEN '20241001' END)
)

-- compare total counts of the test table with test + trimmed
/*sum as (
SELECT  id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 sourceeffectivetime,
		 targeteffectivetime
FROM sources.der2_ssrefset_moduledependency_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module

UNION

SELECT * FROM trimmed
),

test as (
SELECT DISTINCT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 sourceeffectivetime,
		 targeteffectivetime
FROM sources.der2_ssrefset_moduledependency_merged_test
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
	  )

SELECT 'test' as source,
       count (*) FROM test m
WHERE moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108') --UK Drug extension reference set module
UNION all

SELECT 'test+trimmed' AS source,
        count(*) FROM sum
;*/
-- review rows that were changed since the test date
SELECT DISTINCT id,
		 effectivetime,
		 active,
		 moduleid,
		 refsetid,
		 referencedcomponentid,
		 sourceeffectivetime,
		 targeteffectivetime
FROM sources.der2_ssrefset_moduledependency_merged_test
WHERE moduleid IN ( --Unlike other tables, this one contains data concerning other SNOMED modules we don't use, so if you specify module dates above you also need to specify modules here
 '900000000000207008',
 '900000000000012004',
 '731000124108',
 '999000011000000103')

EXCEPT

SELECT * FROM trimmed;
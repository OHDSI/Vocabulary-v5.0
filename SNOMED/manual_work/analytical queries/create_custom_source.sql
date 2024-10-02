-- These scripts are used to create custom SNOMED source with defined SNOMED modules release dates
--- 1) create custom tables in dev_snomed
--- 2) use SNOMED source tables from the sources schema and cut off the content that was released after the desired release dates
--- 3) populate the custom tables with the resulting content

-- Custom tables naming:
--sources.der2_ssrefset_moduledependency_merged => dev_snomed.der2_ssrefset_moduledependency_merged_2024v2
--sources.sct2_concept_full_merged => dev_snomed.sct2_concept_full_merged_2024v2
--sources.sct2_desc_full_merged => dev_snomed.sct2_desc_full_merged_2024v2
--sources.der2_crefset_language_merged => dev_snomed.der2_crefset_language_merged_2024v2
--sources.sct2_rela_full_merged => dev_snomed.sct2_rela_full_merged_2024v2
--sources.der2_crefset_assreffull_merged => dev_snomed.der2_crefset_assreffull_merged_2024v2

-- SNOMED modules settings
---	900000000000207008 --Core (international) module --2024-02-01
--- 900000000000012004	-- SNOMED CT model component --2024-02-01
--- 999000011000000103 --UK edition --2024-04-10
--- 731000124108 --US edition --2024-03-01

--1. sources.der2_ssrefset_moduledependency_merged => dev_snomed.der2_ssrefset_moduledependency_merged_custom_2024v2
--DROP TABLE dev_snomed.der2_ssrefset_moduledependency_merged_2024v2;
CREATE TABLE dev_snomed.der2_ssrefset_moduledependency_merged_2024v2
( id varchar(255),
 effectivetime varchar(10),
 active int,
 moduleid varchar(50),
 refsetid varchar(50),
 referencedcomponentid varchar(50),
 sourceeffectivetime date,
 targeteffectivetime date
);

INSERT INTO dev_snomed.der2_ssrefset_moduledependency_merged_2024v2
(SELECT DISTINCT ON (effectivetime, moduleid, referencedcomponentid) id,
					effectivetime,
					active,
					moduleid,
					refsetid,
					referencedcomponentid,
					sourceeffectivetime,
					targeteffectivetime
FROM sources.der2_ssrefset_moduledependency_merged
WHERE referencedcomponentid = '900000000000012004'
	AND effectivetime IN (CASE
		WHEN moduleid = '900000000000207008' THEN '20240201'
		WHEN moduleid = '731000124108' THEN '20240301'
		WHEN moduleid = '999000011000000103' THEN '20240410'
END));

-- 2. sources.sct2_concept_full_merged => dev_snomed.sct2_concept_full_merged_2024v2
DROP TABLE dev_snomed.sct2_concept_full_merged_2024v2;
CREATE TABLE dev_snomed.sct2_concept_full_merged_2024v2
(id  varchar(50),
 effectivetime varchar(10),
 active int,
 moduleid varchar(50),
 statusid varchar(50),
 vocabulary_date date,
 vocabulary_version varchar(50)
);

INSERT INTO dev_snomed.sct2_concept_full_merged_2024v2
(SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 statusid,
		 vocabulary_date,
		 vocabulary_version
	FROM sources.sct2_concept_full_merged
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240201'
								 WHEN moduleid = '900000000000012004' THEN '20240201'
								 WHEN moduleid = '731000124108' THEN '20240301'
								 WHEN moduleid = '999000011000000103' THEN '20240410'
			 END)
		 AND moduleid NOT IN (
							 '999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 ));

--3. sources.sct2_desc_full_merged => dev_snomed.sct2_desc_full_merged_2024v2
--DROP TABLE dev_snomed.sct2_desc_full_merged_2024v2;
CREATE TABLE dev_snomed.sct2_desc_full_merged_2024v2
(
	 id varchar(50),
	 effectivetime varchar(10),
	 active int,
	 moduleid varchar(50),
	 conceptid varchar(50),
	 languagecode varchar(5),
	 typeid varchar(50),
	 term varchar(255),
	 casesignificanceid varchar(50)
);

INSERT INTO dev_snomed.sct2_desc_full_merged_2024v2
	 (SELECT *
		FROM sources.sct2_desc_full_merged
		WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240201'
									 WHEN moduleid = '900000000000012004' THEN '20240201'
									 WHEN moduleid = '731000124108' THEN '20240301'
									 WHEN moduleid = '999000011000000103' THEN '20240410'
			 END)
		 AND moduleid NOT IN ('999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 ));

-- 4. sources.der2_crefset_language_merged => dev_snomed.der2_crefset_language_merged_2024v2
--DROP TABLE dev_snomed.der2_crefset_language_merged_2024v2;
CREATE TABLE dev_snomed.der2_crefset_language_merged_2024v2
(
	 effectivetime varchar(10),
	 active int,
	 moduleid varchar(50),
	 refsetid varchar(50),
	 referencedcomponentid varchar(50),
	 acceptabilityid varchar(50),
	 source_file_id varchar(10)
);

INSERT INTO dev_snomed.der2_crefset_language_merged_2024v2
	 (SELECT effectivetime, active, moduleid, refsetid, referencedcomponentid, acceptabilityid, source_file_id
		FROM sources.der2_crefset_language_merged
		WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240201'
									 WHEN moduleid = '900000000000012004' THEN '20240201'
									 WHEN moduleid = '731000124108' THEN '20240301'
									 WHEN moduleid = '999000011000000103' THEN '20240410'
			 END)
		 AND moduleid NOT IN ('999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 ));

--5. sources.sct2_rela_full_merged => dev_snomed.sct2_rela_full_merged_2024v2
--DROP TABLE dev_snomed.sct2_rela_full_merged_2024v2;
CREATE TABLE dev_snomed.sct2_rela_full_merged_2024v2
( id  varchar(50),
 effectivetime varchar(10),
 active int,
 moduleid varchar(50),
 sourceid varchar(50),
 destinationid varchar(50),
 relationshipgroup varchar(50),
 typeid varchar(50),
 characreristictypeid varchar(50),
 modifierid varchar(50)
);

INSERT INTO dev_snomed.sct2_rela_full_merged_2024v2
 (SELECT *
	FROM sources.sct2_rela_full_merged
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240201'
								 WHEN moduleid = '900000000000012004' THEN '20240201'
								 WHEN moduleid = '731000124108' THEN '20240301'
								 WHEN moduleid = '999000011000000103' THEN '20240410'
			 END)
		 AND moduleid NOT IN ('999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 ));

--6. sources.der2_crefset_assreffull_merged => dev_snomed.der2_crefset_assreffull_merged_2024v2
--DROP TABLE dev_snomed.der2_crefset_assreffull_merged_2024v2;
CREATE TABLE dev_snomed.der2_crefset_assreffull_merged_2024v2
( id  varchar(255),
 effectivetime varchar(10),
 active int,
 moduleid varchar(50),
 refsetid varchar(50),
 referencedcomponentid varchar(50),
 targetcomponent varchar(50)
);

INSERT INTO dev_snomed.der2_crefset_assreffull_merged_2024v2
(SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, targetcomponent
	FROM sources.der2_crefset_assreffull_merged
	WHERE effectivetime <= (CASE WHEN moduleid = '900000000000207008' THEN '20240201'
								 WHEN moduleid = '900000000000012004' THEN '20240201'
								 WHEN moduleid = '731000124108' THEN '20240301'
								 WHEN moduleid = '999000011000000103' THEN '20240410'
			 END)
		 AND moduleid NOT IN ('999000011000001104', --UK Drug extension
							 '999000021000001108' --UK Drug extension reference set module
			 ));
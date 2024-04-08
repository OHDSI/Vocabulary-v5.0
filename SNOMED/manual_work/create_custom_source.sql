--sources.der2_ssrefset_moduledependency_merged => dev_snomed.der2_ssrefset_moduledependency_merged_custom
--sources.sct2_concept_full_merged => dev_snomed.sct2_concept_full_merged_custom
--sources.sct2_desc_full_merged => dev_snomed.sct2_desc_full_merged_custom
--sources.der2_crefset_language_merged => dev_snomed.der2_crefset_language_merged_custom
--sources.sct2_rela_full_merged => dev_snomed.sct2_rela_full_merged_custom
--sources.der2_crefset_assreffull_merged => dev_snomed.der2_crefset_assreffull_merged_custom

---	900000000000207008 --Core (international) module --2023-07-31
--- 900000000000012004	-- SNOMED CT model component --2023-07-31
--- 999000011000000103 --UK edition --2023-09-27
--- 731000124108 --US edition --2023-09-01

--1. sources.der2_ssrefset_moduledependency_merged => dev_snomed.der2_ssrefset_moduledependency_merged_custom

CREATE TABLE dev_snomed.der2_ssrefset_moduledependency_merged_custom
( id varchar(255),
 effectivetime varchar(10),
 active int,
 moduleid bigint,
 refsetid bigint,
 referencedcomponentid bigint,
 sourceeffectivetime date,
 targeteffectivetime date
);

INSERT INTO der2_ssrefset_moduledependency_merged_custom
(SELECT DISTINCT ON (effectivetime, moduleid, referencedcomponentid) id,
					effectivetime,
					active,
					moduleid,
					refsetid,
					referencedcomponentid,
					sourceeffectivetime,
					targeteffectivetime
FROM sources.der2_ssrefset_moduledependency_merged
WHERE referencedcomponentid = 900000000000012004
	AND effectivetime IN (CASE
		WHEN moduleid = 900000000000207008 THEN '20230731'
		WHEN moduleid = 731000124108 THEN '20230901'
		WHEN moduleid = 999000011000000103 THEN '20230927'
END));

-- 2. sources.sct2_concept_full_merged => dev_snomed.sct2_concept_full_merged_custom

CREATE TABLE dev_snomed.sct2_concept_full_merged_custom
(id  bigint,
 effectivetime varchar(10),
 active int,
 moduleid bigint,
 statusid bigint,
 vocabulary_date date,
 vocabulary_version varchar(50)
);

INSERT INTO dev_snomed.sct2_concept_full_merged_custom
(SELECT id,
		 effectivetime,
		 active,
		 moduleid,
		 statusid,
		 vocabulary_date,
		 vocabulary_version
	FROM sources.sct2_concept_full_merged
	WHERE effectivetime <= (CASE WHEN moduleid = 900000000000207008 THEN '20230731'
								 WHEN moduleid = 900000000000012004 THEN '20230731'
								 WHEN moduleid = 731000124108 THEN '20230901'
								 WHEN moduleid = 999000011000000103 THEN '20230927'
			 END)
		 AND moduleid NOT IN (
							 999000011000001104, --UK Drug extension
							 999000021000001108 --UK Drug extension reference set module
			 ));

--3. sources.sct2_desc_full_merged => dev_snomed.sct2_desc_full_merged_custom

CREATE TABLE dev_snomed.sct2_desc_full_merged_custom
(
	 id  bigint,
	 effectivetime varchar(10),
	 active int,
	 moduleid bigint,
	 conceptid bigint,
	 languagecode varchar(5),
	 typeid bigint,
	 term varchar(255),
	 casesignificanceid bigint
);

INSERT INTO dev_snomed.sct2_desc_full_merged_custom
	 (SELECT *
		FROM sources.sct2_desc_full_merged
		WHERE effectivetime <= (CASE WHEN moduleid = 900000000000207008 THEN '20230731'
									 WHEN moduleid = 900000000000012004 THEN '20230731'
									 WHEN moduleid = 731000124108 THEN '20230901'
									 WHEN moduleid = 999000011000000103 THEN '20230927'
			 END)
		 AND moduleid NOT IN (999000011000001104, --UK Drug extension
							 999000021000001108 --UK Drug extension reference set module
			 ));

-- 4. sources.der2_crefset_language_merged => dev_snomed.der2_crefset_language_merged_custom

CREATE TABLE dev_snomed.der2_crefset_language_merged_custom
(
	 effectivetime varchar(10),
	 active int,
	 moduleid bigint,
	 refsetid bigint,
	 referencedcomponentid bigint,
	 acceptabilityid bigint,
	 source_file_id varchar(10)
);

INSERT INTO dev_snomed.der2_crefset_language_merged_custom
	 (SELECT effectivetime, active, moduleid, refsetid, referencedcomponentid, acceptabilityid, source_file_id
		FROM sources.der2_crefset_language_merged
		WHERE effectivetime <= (CASE WHEN moduleid = 900000000000207008 THEN '20230731'
									 WHEN moduleid = 900000000000012004 THEN '20230731'
									 WHEN moduleid = 731000124108 THEN '20230901'
									 WHEN moduleid = 999000011000000103 THEN '20230927'
			 END)
		 AND moduleid NOT IN (999000011000001104, --UK Drug extension
							 999000021000001108 --UK Drug extension reference set module
			 ));

--5. sources.sct2_rela_full_merged => dev_snomed.sct2_rela_full_merged_custom

CREATE TABLE dev_snomed.sct2_rela_full_merged_custom
( id  bigint,
 effectivetime varchar(10),
 active int,
 moduleid bigint,
 sourceid bigint,
 destinationid bigint,
 relationshipgroup int,
 typeid bigint,
 characreristictypeid bigint,
 modifierid bigint
);

INSERT INTO dev_snomed.sct2_rela_full_merged_custom
 (SELECT *
	FROM sources.sct2_rela_full_merged
	WHERE effectivetime <= (CASE WHEN moduleid = 900000000000207008 THEN '20230731'
								 WHEN moduleid = 900000000000012004 THEN '20230731'
								 WHEN moduleid = 731000124108 THEN '20230901'
								 WHEN moduleid = 999000011000000103 THEN '20230927'
			 END)
		 AND moduleid NOT IN (999000011000001104, --UK Drug extension
							 999000021000001108 --UK Drug extension reference set module
			 ));

--6. sources.der2_crefset_assreffull_merged => dev_snomed.der2_crefset_assreffull_merged_custom

CREATE TABLE dev_snomed.der2_crefset_assreffull_merged_custom
( id  varchar(255),
 effectivetime varchar(10),
 active int,
 moduleid bigint,
 refsetid bigint,
 referencedcomponentid bigint,
 targetcomponent bigint
);

INSERT INTO dev_snomed.der2_crefset_assreffull_merged_custom
(SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, targetcomponent
	FROM sources.der2_crefset_assreffull_merged
	WHERE effectivetime <= (CASE WHEN moduleid = 900000000000207008 THEN '20230731'
								 WHEN moduleid = 900000000000012004 THEN '20230731'
								 WHEN moduleid = 731000124108 THEN '20230901'
								 WHEN moduleid = 999000011000000103 THEN '20230927'
			 END)
		 AND moduleid NOT IN (999000011000001104, --UK Drug extension
							 999000021000001108 --UK Drug extension reference set module
			 ));
-- DROP FUNCTION vocabulary_pack.CreateCustomSnomedSource(varchar, varchar, date, varchar, date, varchar, date);

CREATE OR REPLACE FUNCTION sources.CreateCustomSnomedSource(
    pintid1 character varying,
    pintid2 character varying,
    pintsourceversion DATE,
    pukid character varying,
    puksourceversion DATE,
    pusid character varying,
    pussourceversion DATE)
 RETURNS TEXT
 LANGUAGE plpgsql
AS
$body$
DECLARE
    v_new_snomed_version DATE := CURRENT_DATE;
    v_old_snomed_version DATE;
    v_ret TEXT;
BEGIN
    SELECT snomed_merged_version
      INTO v_old_snomed_version
      FROM sources.snomed_merged_version
     WHERE int_id_1 = pINTId1
       AND int_id_2 = pINTId2
       AND int_source_version = pIntSourceVersion
       AND uk_id = pUKId
       AND uk_source_version = pUKSourceVersion
       AND us_id = pUSId
       AND us_source_version = pUSSourceVersion
      LIMIT 1;

    -- Check if such combination of parameters already exists
    IF v_old_snomed_version IS NOT NULL
    THEN
        v_ret := 'Such SNOMED merged version already exists: ';

        RETURN v_ret || v_old_snomed_version;
    ELSE
        TRUNCATE TABLE sources.snomed_merged_version;

        -- Add new merged version
        INSERT INTO sources.snomed_merged_version (
            snomed_merged_version,
            int_id_1,
            int_id_2,
            int_source_version,
            uk_id,
            uk_source_version,
            us_id,
            us_source_version
        )
        VALUES (
            v_new_snomed_version,
            pINTId1,
            pIntId2,
            pIntSourceVersion,
            pUKId,
            pUKSourceVersion,
            pUSId,
            pUSSourceVersion);

        -- Archive current merged version
        INSERT INTO sources_archive.snomed_merged_version (
               snomed_merged_version,
               int_id_1,
               int_id_2,
               int_source_version,
               uk_id,
               uk_source_version,
               us_id,
               us_source_version)
        VALUES (
            v_new_snomed_version,
            pINTId1,
            pIntId2,
            pIntSourceVersion,
            pUKId,
            pUKSourceVersion,
            pUSId,
            pUSSourceVersion)
        ON CONFLICT DO NOTHING;
    END IF;

    TRUNCATE TABLE
        sources.der2_ssrefset_moduledependency_merged,
        sources.sct2_concept_full_merged,
        sources.sct2_desc_full_merged,
        sources.der2_crefset_language_merged,
        sources.sct2_rela_full_merged,
        sources.der2_crefset_attributevalue_full_merged,
        sources.der2_crefset_assreffull_merged;

    -- MERGE tables
    -- Module Dependency
    INSERT INTO sources.der2_ssrefset_moduledependency_merged(
        id,
        effectivetime,
        active,
        moduleid,
        refsetid,
        referencedcomponentid,
        sourceeffectivetime,
        targeteffectivetime
    )
    SELECT DISTINCT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, sourceeffectivetime, targeteffectivetime
    FROM (
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, sourceeffectivetime, targeteffectivetime
          FROM sources_archive.der2_ssrefset_moduledependency_int
         WHERE moduleid in (pINTId1, pINTId2)
           AND source_version = pINTSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, sourceeffectivetime, targeteffectivetime
          FROM sources_archive.der2_ssrefset_moduledependency_uk
         WHERE moduleid = pUKId
           AND source_version = pUKSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, sourceeffectivetime, targeteffectivetime
          FROM sources_archive.der2_ssrefset_moduledependency_us
         WHERE moduleid in (pINTId1, pUSId)
           AND source_version = pUSSourceVersion
    ) as dependency;

    -- Concept Full
    INSERT INTO sources.sct2_concept_full_merged (
        id,
        effectivetime,
        active,
        moduleid,
        statusid,
        vocabulary_date,
        vocabulary_version
    )
    SELECT DISTINCT id, effectivetime, active, moduleid, statusid, vocabulary_date, vocabulary_version
    FROM (
        SELECT id, effectivetime, active, moduleid, statusid, vocabulary_date, vocabulary_version
          FROM sources_archive.sct2_concept_full_int
         WHERE moduleid in (pINTId1, pIntId2)
           AND source_version = pIntSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, statusid, vocabulary_date, vocabulary_version
          FROM sources_archive.sct2_concept_full_uk
         WHERE moduleid = pUKId
           AND source_version = pUKSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, statusid, vocabulary_date, vocabulary_version
          FROM sources_archive.sct2_concept_full_us
         WHERE moduleid in (pINTId1, pUSId)
           AND source_version = pUSSourceVersion
    ) as concept;

    -- Desc Full
    INSERT INTO sources.sct2_desc_full_merged (
        id,
        effectivetime,
        active,
        moduleid,
        conceptid,
        languagecode,
        typeid,
        term,
        casesignificanceid
    )
    SELECT id, effectivetime, active, moduleid, conceptid, languagecode, typeid, term, casesignificanceid
    FROM (
        SELECT id, effectivetime, active, moduleid, conceptid, languagecode, typeid, term, casesignificanceid
          FROM sources_archive.sct2_desc_full_int
         WHERE moduleid in (pINTId1, pIntId2)
           AND source_version = pIntSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, conceptid, languagecode, typeid, term, casesignificanceid
          FROM sources_archive.sct2_desc_full_uk
         WHERE moduleid = pUKId
           AND source_version = pUKSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, conceptid, languagecode, typeid, term, casesignificanceid
          FROM sources_archive.sct2_desc_full_us
         WHERE moduleid in (pINTId1, pUSId)
           AND source_version = pUSSourceVersion
    ) as desc_full;

    -- Language Refset
    INSERT INTO sources.der2_crefset_language_merged (
        id,
        effectivetime,
        active,
        moduleid,
        refsetid,
        referencedcomponentid,
        acceptabilityid,
        source_file_id
    )
    SELECT DISTINCT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, acceptabilityid, source_file_id
    FROM (
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, acceptabilityid, source_file_id
          FROM sources_archive.der2_crefset_language_int
         WHERE moduleid in (pINTId1, pIntId2)
           AND source_version = pIntSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, acceptabilityid, source_file_id
          FROM sources_archive.der2_crefset_language_uk
         WHERE moduleid = pUKId
           AND source_version = pUKSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, acceptabilityid, source_file_id
          FROM sources_archive.der2_crefset_language_us
         WHERE moduleid in (pINTId1, pUSId)
           AND source_version = pUSSourceVersion
    ) as lang;

    -- Relationship Full
    INSERT INTO sources.sct2_rela_full_merged (
        id,
        effectivetime,
        active,
        moduleid,
        sourceid,
        destinationid,
        relationshipgroup,
        typeid,
        characteristictypeid,
        modifierid
    )
    SELECT DISTINCT id, effectivetime, active, moduleid, sourceid, destinationid, relationshipgroup, typeid, characteristictypeid, modifierid
    FROM (
        SELECT id, effectivetime, active, moduleid, sourceid, destinationid, relationshipgroup, typeid, characteristictypeid, modifierid
          FROM sources_archive.sct2_rela_full_int
         WHERE moduleid in (pINTId1, pIntId2)
           AND source_version = pIntSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, sourceid, destinationid, relationshipgroup, typeid, characteristictypeid, modifierid
          FROM sources_archive.sct2_rela_full_uk
         WHERE moduleid = pUKId
           AND source_version = pUKSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, sourceid, destinationid, relationshipgroup, typeid, characteristictypeid, modifierid
          FROM sources_archive.sct2_rela_full_us
         WHERE moduleid in (pINTId1, pUSId)
           AND source_version = pUSSourceVersion
    ) as rel;

    -- Attribute Value Refset
    INSERT INTO sources.der2_crefset_attributevalue_full_merged (
        id,
        effectivetime,
        active,
        moduleid,
        refsetid,
        referencedcomponentid,
        valueid
    )
    SELECT DISTINCT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, valueid
    FROM (
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, valueid
          FROM sources_archive.der2_crefset_attributevalue_full_int
         WHERE moduleid in (pINTId1, pIntId2)
           AND source_version = pIntSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, valueid
          FROM sources_archive.der2_crefset_attributevalue_full_uk
         WHERE moduleid = pUKId
           AND source_version = pUKSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, valueid
          FROM sources_archive.der2_crefset_attributevalue_full_us
         WHERE moduleid in (pINTId1, pUSId)
           AND source_version = pUSSourceVersion
    ) as attr;

    -- Association Refset
    INSERT INTO sources.der2_crefset_assreffull_merged (
        id,
        effectivetime,
        active,
        moduleid,
        refsetid,
        referencedcomponentid,
        targetcomponent
    )
    SELECT DISTINCT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, targetcomponent
    FROM (
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, targetcomponent
          FROM sources_archive.der2_crefset_assreffull_int
         WHERE moduleid in (pINTId1, pIntId2)
           AND source_version = pIntSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, targetcomponent
          FROM sources_archive.der2_crefset_assreffull_uk
         WHERE moduleid = pUKId
           AND source_version = pUKSourceVersion
        UNION
        SELECT id, effectivetime, active, moduleid, refsetid, referencedcomponentid, targetcomponent
          FROM sources_archive.der2_crefset_assreffull_us
         WHERE moduleid in (pINTId1, pUSId)
           AND source_version = pUSSourceVersion
    ) as refset;

    v_ret := 'SNOMED modules have been successfully merged into all _merged tables. The new merged version: ';

    ANALYZE
        sources.der2_ssrefset_moduledependency_merged,
        sources.sct2_concept_full_merged,
        sources.sct2_desc_full_merged,
        sources.der2_crefset_language_merged,
        sources.sct2_rela_full_merged,
        sources.der2_crefset_attributevalue_full_merged,
        sources.der2_crefset_assreffull_merged;

    RETURN v_ret || v_new_snomed_version;
END;
$body$
LANGUAGE 'plpgsql';

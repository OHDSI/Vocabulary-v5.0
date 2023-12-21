/*
 * Apply this script to a clean* schema to get stage tables that could be
 applied as a patch before running SNOMED's load_stage.sql.
 */
--0. Source dm+d tables
DROP TABLE IF EXISTS vmpps, vmps, ampps, amps, licensed_route, comb_content_v, comb_content_a, virtual_product_ingredient,
    vtms, ont_drug_form, drug_form, ap_ingredient, ingredient_substances, combination_pack_ind, combination_prod_ind,
    unit_of_measure, forms, supplier, fake_supp, df_indicator, dmd2atc, dmd2bnf;

--vtms: Virtual Therapeutic Moiety
CREATE TABLE vtms AS
SELECT
    devv5.py_unescape(unnest(xpath('/VTM/NM/text()', i.xmlfield))::VARCHAR) NM,
    unnest(xpath('/VTM/VTMID/text()', i.xmlfield))::VARCHAR VTMID,
    unnest(xpath('/VTM/VTMIDPREV/text()', i.xmlfield))::VARCHAR VTMIDPREV,
    to_date(unnest(xpath('/VTM/VTMIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') VTMIDDT,
    unnest(xpath('/VTM/INVALID/text()', i.xmlfield))::VARCHAR INVALID
FROM (
         SELECT unnest(xpath('/VIRTUAL_THERAPEUTIC_MOIETIES/VTM', i.xmlfield)) xmlfield
         FROM sources.f_vtm2 i
     ) AS i;

UPDATE vtms SET invalid = '0' WHERE invalid IS NULL;

--Known issue: code duplication. These codes were removed from use according to official dm+d documentation
--At the moment, these codes left as devices, derived from AMPP for compatibility
DELETE FROM vtms
WHERE vtmid IN
      ('9854411000001103', --Medium chain triglycerides - invalid
       '9854511000001104', --Calcium + Magnesium
       '9854611000001100', --Ichthammol + Zinc
       '9854711000001109', --Amiloride + Cyclopenthiazide - invalid
       '9854911000001106') --Meglumine amidotrizoate + Sodium amidotrizoate - invalid
;


--vmpps: Virtual Medicinal Product Pack
CREATE TABLE vmpps AS
SELECT
    devv5.py_unescape(unnest(xpath('/VMPP/NM/text()', i.xmlfield))::VARCHAR) nm,
    unnest(xpath('/VMPP/VPPID/text()', i.xmlfield))::VARCHAR VPPID,
    unnest(xpath('/VMPP/VPID/text()', i.xmlfield))::VARCHAR VPID,
    unnest(xpath('/VMPP/QTYVAL/text()', i.xmlfield))::VARCHAR::numeric QTYVAL,
    unnest(xpath('/VMPP/QTY_UOMCD/text()', i.xmlfield))::VARCHAR QTY_UOMCD,
    unnest(xpath('/VMPP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
    devv5.py_unescape(unnest(xpath('/VMPP/ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM
FROM (
         SELECT unnest(xpath('/VIRTUAL_MED_PRODUCT_PACK/VMPPS/VMPP', i.xmlfield)) xmlfield
         FROM sources.f_vmpp2 i
     ) AS i;

UPDATE vmpps SET invalid = '0' WHERE invalid IS NULL;

CREATE TABLE comb_content_v AS
SELECT
    unnest(xpath('/CCONTENT/PRNTVPPID/text()', i.xmlfield))::VARCHAR PRNTVPPID,
    unnest(xpath('/CCONTENT/CHLDVPPID/text()', i.xmlfield))::VARCHAR CHLDVPPID
FROM (
         SELECT unnest(xpath('/VIRTUAL_MED_PRODUCT_PACK/COMB_CONTENT/CCONTENT', i.xmlfield)) xmlfield
         FROM sources.f_vmpp2 i
     ) AS i
;


--vmps: Virtual Medicinal Product
CREATE TABLE vmps AS
SELECT devv5.py_unescape(unnest(xpath('/VMP/NM/text()', i.xmlfield))::VARCHAR) nm,
       to_date(unnest(xpath('/VMP/VPIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') VPIDDT,
       unnest(xpath('/VMP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
       unnest(xpath('/VMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
       unnest(xpath('/VMP/VPIDPREV/text()', i.xmlfield))::VARCHAR VPIDPREV,
       unnest(xpath('/VMP/VTMID/text()', i.xmlfield))::VARCHAR VTMID,
       devv5.py_unescape(unnest(xpath('/VMP/NMPREV/text()', i.xmlfield))::VARCHAR) NMPREV,
       to_date(unnest(xpath('/VMP/NMDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') NMDT,
       devv5.py_unescape(unnest(xpath('/VMP/ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM,
       unnest(xpath('/VMP/COMBPRODCD/text()', i.xmlfield))::VARCHAR COMBPRODCD,
       unnest(xpath('/VMP/NON_AVAILDT/text()', i.xmlfield))::VARCHAR NON_AVAILDT,
       unnest(xpath('/VMP/DF_INDCD/text()', i.xmlfield))::VARCHAR DF_INDCD,
       unnest(xpath('/VMP/UDFS/text()', i.xmlfield))::VARCHAR::numeric UDFS,
       unnest(xpath('/VMP/UDFS_UOMCD/text()', i.xmlfield))::VARCHAR UDFS_UOMCD,
       unnest(xpath('/VMP/UNIT_DOSE_UOMCD/text()', i.xmlfield))::VARCHAR UNIT_DOSE_UOMCD,
       unnest(xpath('/VMP/PRES_STATCD/text()', i.xmlfield))::VARCHAR PRES_STATCD
FROM (
         SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/VMPS/VMP', i.xmlfield)) xmlfield
         FROM sources.f_vmp2 i
     ) AS i;

UPDATE vmps SET invalid = '0' WHERE invalid IS NULL;

--keep the newest replacement only (*prev)
UPDATE vmps v
SET
    nmprev = NULL,
    vpidprev = NULL
WHERE
    v.vpidprev IS NOT NULL AND
    exists
        (
            SELECT
            FROM vmps u
            WHERE
                    u.vpidprev = v.vpidprev AND
                    v.nmdt < u.nmdt
        )
;


CREATE TABLE virtual_product_ingredient AS
SELECT unnest(xpath('/VPI/VPID/text()', i.xmlfield))::VARCHAR VPID,
       unnest(xpath('/VPI/ISID/text()', i.xmlfield))::VARCHAR ISID,
       unnest(xpath('/VPI/BS_SUBID/text()', i.xmlfield))::VARCHAR BS_SUBID,
       unnest(xpath('/VPI/STRNT_NMRTR_VAL/text()', i.xmlfield))::VARCHAR::numeric STRNT_NMRTR_VAL,
       unnest(xpath('/VPI/STRNT_NMRTR_UOMCD/text()', i.xmlfield))::VARCHAR STRNT_NMRTR_UOMCD,
       unnest(xpath('/VPI/STRNT_DNMTR_VAL/text()', i.xmlfield))::VARCHAR::numeric STRNT_DNMTR_VAL,
       unnest(xpath('/VPI/STRNT_DNMTR_UOMCD/text()', i.xmlfield))::VARCHAR STRNT_DNMTR_UOMCD
FROM (
         SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/VIRTUAL_PRODUCT_INGREDIENT/VPI', i.xmlfield)) xmlfield
         FROM sources.f_vmp2 i
     ) AS i
;

--replace nanoliters with ml in amount
UPDATE virtual_product_ingredient
SET
    strnt_nmrtr_val = strnt_nmrtr_val * 0.000001,
    strnt_nmrtr_uomcd = '258773002' -- mL
WHERE strnt_nmrtr_uomcd = '282113003' -- nL
;


CREATE TABLE ont_drug_form AS
SELECT unnest(xpath('/ONT/VPID/text()', i.xmlfield))::VARCHAR VPID,
       unnest(xpath('/ONT/FORMCD/text()', i.xmlfield))::VARCHAR FORMCD
FROM (
         SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/ONT_DRUG_FORM/ONT', i.xmlfield)) xmlfield
         FROM sources.f_vmp2 i
     ) AS i
;


CREATE TABLE drug_form AS
SELECT unnest(xpath('/DFORM/VPID/text()', i.xmlfield))::VARCHAR VPID,
       unnest(xpath('/DFORM/FORMCD/text()', i.xmlfield))::VARCHAR FORMCD
FROM (
         SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/DRUG_FORM/DFORM', i.xmlfield)) xmlfield
         FROM sources.f_vmp2 i
     ) AS i
;


--amps: Actual Medicinal Product
CREATE TABLE amps AS
SELECT devv5.py_unescape(unnest(xpath('/AMP/NM/text()', i.xmlfield))::VARCHAR) nm,
       unnest(xpath('/AMP/APID/text()', i.xmlfield))::VARCHAR APID,
       unnest(xpath('/AMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
       unnest(xpath('/AMP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
       devv5.py_unescape(unnest(xpath('/AMP/NMPREV/text()', i.xmlfield))::VARCHAR) NMPREV,
       devv5.py_unescape(unnest(xpath('/AMP/ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM,
       to_date(unnest(xpath('/AMP/NMDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') NMDT,
       unnest(xpath('/AMP/SUPPCD/text()', i.xmlfield))::VARCHAR SUPPCD,
       unnest(xpath('/AMP/COMBPRODCD/text()', i.xmlfield))::VARCHAR COMBPRODCD,
       unnest(xpath('/AMP/LIC_AUTHCD/text()', i.xmlfield))::VARCHAR LIC_AUTHCD
FROM (
         SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP', i.xmlfield)) xmlfield
         FROM sources.f_amp2 i
     ) AS i
;

UPDATE amps SET invalid = '0' WHERE invalid IS NULL;


CREATE TABLE ap_ingredient AS
SELECT unnest(xpath('/AP_ING/APID/text()', i.xmlfield))::VARCHAR APID,
       unnest(xpath('/AP_ING/ISID/text()', i.xmlfield))::VARCHAR ISID,
       unnest(xpath('/AP_ING/STRNTH/text()', i.xmlfield))::VARCHAR::numeric STRNTH,
       unnest(xpath('/AP_ING/UOMCD/text()', i.xmlfield))::VARCHAR UOMCD
FROM (
         SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/AP_INGREDIENT/AP_ING', i.xmlfield)) xmlfield
         FROM sources.f_amp2 i
     ) AS i
;


CREATE TABLE licensed_route AS
SELECT
    unnest(xpath('/LIC_ROUTE/APID/text()', i.xmlfield))::VARCHAR APID,
    unnest(xpath('/LIC_ROUTE/ROUTECD/text()', i.xmlfield))::VARCHAR ROUTECD
FROM (
         SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/LICENSED_ROUTE/LIC_ROUTE', i.xmlfield)) xmlfield
         FROM sources.f_amp2 i
     ) AS i
;


--ampps: Actual Medicinal Product Pack
CREATE TABLE ampps AS
SELECT devv5.py_unescape(unnest(xpath('/AMPP/NM/text()', i.xmlfield))::VARCHAR) nm,
       unnest(xpath('/AMPP/APPID/text()', i.xmlfield))::VARCHAR APPID,
       unnest(xpath('/AMPP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
       devv5.py_unescape(unnest(xpath('/AMPP/ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM,
       unnest(xpath('/AMPP/VPPID/text()', i.xmlfield))::VARCHAR VPPID,
       unnest(xpath('/AMPP/APID/text()', i.xmlfield))::VARCHAR APID,
       unnest(xpath('/AMPP/COMBPACKCD/text()', i.xmlfield))::VARCHAR COMBPACKCD,
       to_date(unnest(xpath('/AMPP/DISCDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') DISCDT
FROM (
         SELECT unnest(xpath('/ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP', i.xmlfield)) xmlfield
         FROM sources.f_ampp2 i
     ) AS i
;

UPDATE ampps SET invalid = '0' WHERE invalid IS NULL;


CREATE TABLE comb_content_a AS
SELECT unnest(xpath('/CCONTENT/PRNTAPPID/text()', i.xmlfield))::VARCHAR PRNTAPPID,
       unnest(xpath('/CCONTENT/CHLDAPPID/text()', i.xmlfield))::VARCHAR CHLDAPPID
FROM (
         SELECT unnest(xpath('/ACTUAL_MEDICINAL_PROD_PACKS/COMB_CONTENT/CCONTENT', i.xmlfield)) xmlfield
         FROM sources.f_ampp2 i
     ) AS i
;


--Ingredients
CREATE TABLE ingredient_substances AS
SELECT devv5.py_unescape(unnest(xpath('/ING/NM/text()', i.xmlfield))::VARCHAR) nm,
       unnest(xpath('/ING/ISID/text()', i.xmlfield))::VARCHAR ISID,
       to_date(unnest(xpath('/ING/ISIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') ISIDDT,
       unnest(xpath('/ING/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
       unnest(xpath('/ING/ISIDPREV/text()', i.xmlfield))::VARCHAR ISIDPREV
FROM (
         SELECT unnest(xpath('/INGREDIENT_SUBSTANCES/ING', i.xmlfield)) xmlfield
         FROM sources.f_ingredient2 i
     ) AS i
;

UPDATE ingredient_substances SET invalid = '0' WHERE invalid IS NULL;


--combination packs
CREATE TABLE combination_pack_ind AS
SELECT devv5.py_unescape(unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
       unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD
FROM (
         SELECT unnest(xpath('/LOOKUP/COMBINATION_PACK_IND/INFO', i.xmlfield)) xmlfield
         FROM sources.f_lookup2 i
     ) AS i
;


--combination products
CREATE TABLE combination_prod_ind AS
SELECT devv5.py_unescape(unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
       unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD
FROM (
         SELECT unnest(xpath('/LOOKUP/COMBINATION_PROD_IND/INFO', i.xmlfield)) xmlfield
         FROM sources.f_lookup2 i
     ) AS i
;


--Units
CREATE TABLE unit_of_measure AS
SELECT devv5.py_unescape(unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
       unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD,
       to_date(unnest(xpath('/INFO/CDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') CDDT
FROM (
         SELECT unnest(xpath('/LOOKUP/UNIT_OF_MEASURE/INFO', i.xmlfield)) xmlfield
         FROM sources.f_lookup2 i
     ) AS i
;


--Forms
CREATE TABLE forms AS
SELECT devv5.py_unescape(unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
       unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD,
       to_date(unnest(xpath('/INFO/CDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') CDDT
FROM (
         SELECT unnest(xpath('/LOOKUP/FORM/INFO', i.xmlfield)) xmlfield
         FROM sources.f_lookup2 i
     ) AS i
;


--suppliers
CREATE TABLE supplier AS
WITH supp_temp AS
         (
             SELECT devv5.py_unescape(unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
                    unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD,
                    to_date(unnest(xpath('/INFO/CDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') CDDT,
                    unnest(xpath('/INFO/INVALID/text()', i.xmlfield))::VARCHAR INVALID
             FROM (
                      SELECT unnest(xpath('/LOOKUP/SUPPLIER/INFO', i.xmlfield)) xmlfield
                      FROM sources.f_lookup2 i
                  ) AS i
         ),

     supp_cut AS
         (
             SELECT
                 t.*,
                 regexp_replace(
                         t.info_desc,
                         ',?( (Corporation|Division|Research|EU|Marketing|Medical|Product(s)?|Health(( )?care)?|Europe|(Ph|F)arma(ceutical(s)?(,)?)?|international|group|lp|kg|A\/?S|AG|srl|Ltd|UK|Plc|GmbH|\(.*\)|Inc(.)?|AB|s\.?p?\.?a\.?|(& )?Co(.)?))+( 1)?$'
                     ,'','gim') as name_cut
             FROM supp_temp t
         )

SELECT
    CASE
        WHEN length (name_cut) > 4 THEN name_cut
        ELSE info_desc
        END AS info_desc,
    info_desc AS name_old,
    cd,
    cddt,
    invalid
FROM supp_cut;

UPDATE supplier SET invalid = '0' WHERE invalid IS NULL;

UPDATE supplier
SET info_desc = replace (info_desc, ' Company', '')
WHERE
        info_desc NOT LIKE '%& Company%' AND
        info_desc NOT LIKE '%and Company%';

UPDATE supplier
SET info_desc = replace (info_desc, ' Ltd', '')
;


--some suppliers are non-existing
CREATE TABLE fake_supp AS
SELECT cd, info_desc
FROM supplier
WHERE
        info_desc IN
        (
         'Special Order', 'Extemp Order', 'Drug Tariff Special Order',
         'Flavour Not Specified', 'Approved Prescription Services','Disposable Medical Equipment',
         'Oxygen Therapy'
            ) OR
        info_desc LIKE 'Imported%';


--df_indicator
CREATE TABLE df_indicator AS
SELECT devv5.py_unescape(unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
       unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD
FROM (
         SELECT unnest(xpath('/LOOKUP/DF_INDICATOR/INFO', i.xmlfield)) xmlfield
         FROM sources.f_lookup2 i
     ) AS i
;


--1. Create views of rows to be affected
--1.1. Create view of manual mappings missing from dm+d
DROP TABLE IF EXISTS dmd_missing_mappings_vacc;
CREATE TABLE dmd_missing_mappings_vacc AS
SELECT
    cm1.concept_code_1,
    cm1.concept_code_2,
    cm1.relationship_id,
    cm1.vocabulary_id_2,
    cm1.invalid_reason
FROM dev_snomed.concept_relationship_manual cm1
JOIN concept cd ON
    cd.vocabulary_id = 'dm+d' AND
    cd.concept_code = cm1.concept_code_1
LEFT JOIN concept_relationship_manual cm2 ON
-- We are only interested in mappings that are:
--  1. From the same concept code
--  2. Active
-- Actual mapping target is unimportant, SNOMED always
-- loses in this case.
        cm2.concept_code_1 = cm1.concept_code_1
    AND cm2.vocabulary_id_1 = 'dm+d'
    AND cm2.relationship_id = 'Maps to'
    AND cm2.invalid_reason IS NULL
WHERE
        cm1.vocabulary_id_1 = 'SNOMED'
    AND cm1.vocabulary_id_2 != 'SNOMED'
    AND cm1.relationship_id = 'Maps to'
    AND cm2.concept_code_1 IS NULL
    AND cm1.invalid_reason IS NULL
;
INSERT INTO concept_relationship_manual (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
)
SELECT
    dv.concept_code_1,
    dv.concept_code_2,
    'dm+d',
    dv.vocabulary_id_2,
    dv.relationship_id,
    to_date('01-11-2023', 'DD-MM-YYYY'),
    to_date('31-12-2099', 'DD-MM-YYYY')
FROM dmd_missing_mappings_vacc dv
;
DROP TABLE dmd_missing_mappings_vacc;

--1.2. Create table of concept codes (Devices) that currently map to SNOMED
DROP TABLE IF EXISTS dmd_mapped_to_snomed;
CREATE TABLE dmd_mapped_to_snomed AS
SELECT
    c.concept_id,
    c2.concept_id AS snomed_concept_id,
    c2.domain_id AS snomed_domain_id,
    c.invalid_reason AS invalid_reason,
    c3.concept_id AS replacement_concept_id,
    c3.vocabulary_id AS replacement_vocabulary_id
FROM concept c
JOIN concept_relationship r ON
        c.concept_id = r.concept_id_1
    AND r.relationship_id = 'Maps to'
    AND c.vocabulary_id = 'dm+d'
    AND r.invalid_reason IS NULL
JOIN concept c2 ON
        c2.concept_id = r.concept_id_2
    AND c2.vocabulary_id = 'SNOMED'
-- For deprecated concepts, check if replacement exists
LEFT JOIN concept_relationship r2 ON
        c.concept_id = r2.concept_id_1
    AND c.invalid_reason IS NOT NULL
    AND r2.relationship_id = 'Concept replaced by'
-- Also check for replacement in source dm+d VMPs table, if
-- one not provided explicitly
LEFT JOIN vmps v ON
        r2.concept_id_2 is NULL
    AND v.vpidprev = c.concept_code

LEFT JOIN concept c3 ON
        c3.concept_id = r2.concept_id_2 OR
        (c3.concept_code = v.vpid AND c3.vocabulary_id = 'dm+d')
;
--2. Fill the stage tables
--2.1. Prepare stage tables
TRUNCATE concept_stage;
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;

--2.2. Populate the concept_stage with affected concepts only
INSERT INTO concept_stage (
    concept_id,
    concept_name,
    domain_id,
    vocabulary_id,
    concept_class_id,
    standard_concept,
    concept_code,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    d.concept_id,
    c.concept_name,
    d.snomed_domain_id AS domain_id, -- Use mapping target domain
    'dm+d' AS vocabulary_id,
    c.concept_class_id,
    CASE WHEN d.invalid_reason IS NULL THEN 'S' END AS standard_concept,
    c.concept_code,
    c.valid_start_date,
    CASE
        WHEN d.invalid_reason IS NULL THEN to_date('31-12-2099', 'DD-MM-YYYY')
        ELSE to_date('31-10-2023', 'DD-MM-YYYY')
    END AS valid_end_date,
    d.invalid_reason
FROM dmd_mapped_to_snomed d
JOIN concept c USING (concept_id)
;
--2.3. Populate the concept_relationship_stage with new correct mappings only
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
)
SELECT DISTINCT
    cs.concept_code AS concept_code_1,
    CASE
        WHEN cs.standard_concept = 'S' THEN cs.concept_code
        ELSE t.concept_code
    END AS concept_code_2,
    'dm+d' AS vocabulary_id_1,
    CASE
        WHEN cs.standard_concept = 'S' THEN 'dm+d'
        ELSE t.vocabulary_id
    END AS vocabulary_id_2,
    'Maps to' AS relationship_id,
    to_date('01-11-2023', 'DD-MM-YYYY') AS valid_start_date,
    to_date('31-12-2099', 'DD-MM-YYYY') AS valid_end_date
FROM concept_stage cs
JOIN dmd_mapped_to_snomed dmts ON
    cs.concept_id = dmts.concept_id
-- Join to replacement concept does it map anywhere?
LEFT JOIN concept r ON
    r.concept_id = dmts.replacement_concept_id
LEFT JOIN concept_relationship r2 ON
        r.concept_id = r2.concept_id_1
    AND r2.relationship_id = 'Maps to'
    AND r2.invalid_reason IS NULL
LEFT JOIN concept t ON
    t.concept_id = r2.concept_id_2
WHERE (
    cs.standard_concept = 'S' OR
    t.concept_id IS NOT NULL
)
;
--2.4. Explicitly deprecate old existing mappings
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    c.concept_code AS concept_code_1,
    t.concept_code AS concept_code_2,
    'dm+d' AS vocabulary_id_1,
    t.vocabulary_id AS vocabulary_id_2,
    'Maps to' AS relationship_id,
    r.valid_start_date,
    to_date('31-10-2023', 'DD-MM-YYYY') AS valid_end_date,
    'D' AS invalid_reason
FROM dmd_mapped_to_snomed dm
JOIN concept c USING (concept_id)
JOIN concept_relationship r ON
        r.concept_id_1 = dm.concept_id
    AND r.relationship_id = 'Maps to'
    AND r.invalid_reason IS NULL
JOIN concept t ON
    t.concept_id = r.concept_id_2
--Unless somehow reinforced by a new mapping
LEFT JOIN concept_relationship_stage crs ON
        crs.concept_code_1 = c.concept_code
    AND crs.concept_code_2 = t.concept_code
    AND crs.vocabulary_id_1 = 'dm+d'
    AND crs.vocabulary_id_2 = t.vocabulary_id
    AND crs.relationship_id = 'Maps to'
WHERE crs.concept_code_1 IS NULL
--This should make a 0 rows insert, unless concept_relationship_manual is
--affecting this
;

--3. "Steal" SNOMED concepts that will appear in the new release through
-- concept table surgery
--3.1. Create a table of SNOMED concepts that will be affected
DROP TABLE IF EXISTS snomed_concepts_to_steal;
DROP VIEW IF EXISTS indexed_moduleid_concept;
CREATE MATERIALIZED VIEW indexed_moduleid_concept AS
SELECT
    id,
    moduleid,
    active,
    effectivetime
FROM sources.sct2_concept_full_merged;
CREATE INDEX ON indexed_moduleid_concept (moduleid, effectivetime DESC);
CREATE INDEX ON indexed_moduleid_concept (id, effectivetime DESC);
ANALYSE indexed_moduleid_concept;
CREATE TABLE snomed_concepts_to_steal AS
--Marginal case: what if the concept is stolen by UK?
--If this is the case, it should be excluded from transfer, as
--SNOMED run will restore it's original module
WITH last_non_uk_active AS (
    SELECT
        sc.id,
        first_value(sc.active) OVER
            (PARTITION BY sc.id ORDER BY effectivetime DESC) AS active
    FROM indexed_moduleid_concept sc
    WHERE moduleid NOT IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
),
killed_by_intl AS (
    SELECT id
    FROM last_non_uk_active
    WHERE active = 0
),
current_module AS (
    SELECT
        c.id,
        first_value(moduleid) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS moduleid
    FROM indexed_moduleid_concept c
)
SELECT DISTINCT
    c.concept_id
FROM concept c
JOIN current_module cm ON
        c.concept_code = cm.id :: text
    AND cm.moduleid IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
    AND c.vocabulary_id = 'SNOMED'
JOIN (
    SELECT vtmid as id from vtms
        UNION ALL
    SELECT isid FROM ingredient_substances
        UNION ALL
    SELECT vpid FROM vmps
        UNION ALL
    SELECT apid FROM amps
        UNION ALL
    SELECT vppid FROM vmpps
        UNION ALL
    SELECT appid FROM ampps
) dm_sources ON
        c.concept_code = dm_sources.id
    AND c.vocabulary_id = 'SNOMED'
--Not present in current release of dm+d
LEFT JOIN concept d ON
        d.concept_code = c.concept_code
    AND d.vocabulary_id = 'dm+d'
--Not killed by international release
LEFT JOIN killed_by_intl k ON
    k.id :: text = c.concept_code
WHERE
        d.concept_id IS NULL
    AND c.invalid_reason IS NULL
;
DROP MATERIALIZED VIEW indexed_moduleid_concept
;
SELECT
    VOCABULARY_PACK.SetLatestUpdate(
            pVocabularyName			=> 'dm+d',
            pVocabularyDate			=> to_date('01-11-2023', 'dd-mm-yyyy'),
            pVocabularyVersion		=> 'DMD 2023-05-22',
            pVocabularyDevSchema	=> 'dev_test3'
    )
;

--SETLatestUPDATE for 2 affected vocabularies
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SETLatestUPDATE(
	pVocabularyName			=> 'dm+d',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.f_lookup2 LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.f_lookup2 LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_DMD'
);
	PERFORM VOCABULARY_PACK.SETLatestUPDATE(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_DMD',
	pAppendVocabulary		=> TRUE
);
END $_$;

--Pull ancestors data from non-standard SNOMED concept relations
--needed because of existing non-standard Substances in SNOMED vocabulary
DROP TABLE IF EXISTS ancestor_snomed CASCADE;

CREATE TABLE ancestor_snomed AS
WITH RECURSIVE hierarchy_concepts (ancestor_concept_id,descendant_concept_id,root_ancestor_concept_id,levels_of_separation,full_path) AS
  (
        SELECT
            ancestor_concept_id, descendant_concept_id, ancestor_concept_id AS root_ancestor_concept_id,
            levels_of_separation, ARRAY [descendant_concept_id] AS full_path
        FROM concepts

        UNION ALL

        SELECT
            c.ancestor_concept_id, c.descendant_concept_id, root_ancestor_concept_id,
            hc.levels_of_separation + c.levels_of_separation AS levels_of_separation,
            hc.full_path || c.descendant_concept_id AS full_path
        FROM concepts c
        JOIN hierarchy_concepts hc ON hc.descendant_concept_id = c.ancestor_concept_id
        WHERE c.descendant_concept_id <> ALL (full_path)
    ),

    concepts AS (
        SELECT
            r.concept_id_1 AS ancestor_concept_id,
            r.concept_id_2 AS descendant_concept_id,
            CASE WHEN s.is_hierarchical = 1 AND c1.invalid_reason IS NULL THEN 1 ELSE 0 END AS levels_of_separation
        FROM concept_relationship r
        JOIN relationship s ON s.relationship_id = r.relationship_id AND s.defines_ancestry = 1
        JOIN concept c1 ON c1.concept_id = r.concept_id_1 AND c1.invalid_reason IS NULL AND c1.vocabulary_id = 'SNOMED'
        JOIN concept c2 ON c2.concept_id = r.concept_id_2 AND c2.invalid_reason IS NULL AND c2.vocabulary_id = 'SNOMED'
        WHERE r.invalid_reason IS NULL
        --Do NOT use module relationships due to minor inconsistency IN this relationships
        AND r.relationship_id NOT IN ('Has Module', 'Module of')
    )

    SELECT
        hc.root_ancestor_concept_id AS ancestor_concept_id,
        hc.descendant_concept_id,
        min(hc.levels_of_separation) AS min_levels_of_separation,
        max(hc.levels_of_separation) AS max_levels_of_separation
    FROM hierarchy_concepts hc
    JOIN concept c1 ON c1.concept_id = hc.root_ancestor_concept_id AND c1.invalid_reason IS NULL
    JOIN concept c2 ON c2.concept_id = hc.descendant_concept_id AND c2.invalid_reason IS NULL
    GROUP BY hc.root_ancestor_concept_id, hc.descendant_concept_id

	UNION

SELECT c.concept_id AS ancestor_concept_id,
	c.concept_id AS descendant_concept_id,
	0 AS min_levels_of_separation,
	0 AS max_levels_of_separation
FROM concept c
WHERE
	c.vocabulary_id = 'SNOMED' AND
	c.invalid_reason IS NULL
;
--Adding constraints and indexes to snomed ancestor
ALTER TABLE ancestor_snomed ADD CONSTRAINT xpkancestor_snomed PRIMARY KEY (ancestor_concept_id,descendant_concept_id);
CREATE INDEX idx_sna_descendant ON ancestor_snomed (descendant_concept_id);
CREATE INDEX idx_sna_ancestor ON ancestor_snomed (ancestor_concept_id);
ANALYZE ancestor_snomed;
--AS a result, ancestor_snomed is prepared for future use

--! Step 1. Extract meaningful data FROM XML source. Manual fix to source data discrepancies
DROP TABLE IF EXISTS vmpps, vmps, ampps, amps, licensed_route, comb_content_v, comb_content_a, virtual_product_ingredient,
    vtms, ont_drug_form, drug_form, ingredient_substances, combination_pack_ind, combination_prod_ind,
    unit_of_measure, forms, supplier, fake_supp, df_indicator, history_codes CASCADE;

-- extract history codes for mappping compare 
CREATE TABLE history_codes AS 
SELECT 
unnest(xpath('/VMPS/VMP/IDCURRENT/text()', i.xmlfield))::VARCHAR CURRENT_CODE,
unnest(xpath('/VMPS/VMP/IDPREVIOUS/text()', i.xmlfield))::VARCHAR PREV_CODE,
to_date(unnest(xpath('/VMPS/VMP/STARTDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') START_DATE,
to_date(unnest(xpath('/VMPS/VMP/ENDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') END_DATE
FROM (
	SELECT unnest(xpath('/HISTORY/VMPS', i.xmlfield)) xmlfield
	FROM sources.f_history i 
	) AS i;
   
--vtms: Virtual Therapeutic Moiety
CREATE TABLE vtms AS
SELECT
	unnest(xpath('/VTM/NM/text()', i.xmlfield))::VARCHAR NM,
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
--At the moment, these codes left AS devices, derived from AMPP for compatibility
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
	unnest(xpath('/VMPP/NM/text()', i.xmlfield))::VARCHAR nm,
	unnest(xpath('/VMPP/VPPID/text()', i.xmlfield))::VARCHAR VPPID,
	unnest(xpath('/VMPP/VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('/VMPP/QTYVAL/text()', i.xmlfield))::VARCHAR::numeric QTYVAL,
	unnest(xpath('/VMPP/QTY_UOMCD/text()', i.xmlfield))::VARCHAR QTY_UOMCD,
	unnest(xpath('/VMPP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
	unnest(xpath('/VMPP/ABBREVNM/text()', i.xmlfield))::VARCHAR ABBREVNM
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
	) AS i;

--vmps: Virtual Medicinal Product
CREATE TABLE vmps AS
SELECT unnest(xpath('/VMP/NM/text()', i.xmlfield))::VARCHAR nm,
	to_date(unnest(xpath('/VMP/VPIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') VPIDDT,
	unnest(xpath('/VMP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
	unnest(xpath('/VMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('/VMP/VPIDPREV/text()', i.xmlfield))::VARCHAR VPIDPREV,
	unnest(xpath('/VMP/VTMID/text()', i.xmlfield))::VARCHAR VTMID,
	unnest(xpath('/VMP/NMPREV/text()', i.xmlfield))::VARCHAR NMPREV,
	to_date(unnest(xpath('/VMP/NMDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') NMDT,
	unnest(xpath('/VMP/ABBREVNM/text()', i.xmlfield))::VARCHAR ABBREVNM,
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
	EXISTS
		(
			SELECT
			FROM vmps u
			WHERE
				u.vpidprev = v.vpidprev AND
				v.nmdt < u.nmdt
		);

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
	) AS i;

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
	) AS i;

CREATE TABLE drug_form AS
SELECT unnest(xpath('/DFORM/VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('/DFORM/FORMCD/text()', i.xmlfield))::VARCHAR FORMCD
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/DRUG_FORM/DFORM', i.xmlfield)) xmlfield
	FROM sources.f_vmp2 i
	) AS i;


--amps: Actual Medicinal Product
CREATE TABLE amps AS
SELECT unnest(xpath('/AMP/NM/text()', i.xmlfield))::VARCHAR nm,
	unnest(xpath('/AMP/APID/text()', i.xmlfield))::VARCHAR APID,
	unnest(xpath('/AMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('/AMP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
	unnest(xpath('/AMP/NMPREV/text()', i.xmlfield))::VARCHAR NMPREV,
	unnest(xpath('/AMP/ABBREVNM/text()', i.xmlfield))::VARCHAR ABBREVNM,
	to_date(unnest(xpath('/AMP/NMDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') NMDT,
	unnest(xpath('/AMP/SUPPCD/text()', i.xmlfield))::VARCHAR SUPPCD,
	unnest(xpath('/AMP/COMBPRODCD/text()', i.xmlfield))::VARCHAR COMBPRODCD,
	unnest(xpath('/AMP/LIC_AUTHCD/text()', i.xmlfield))::VARCHAR LIC_AUTHCD
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP', i.xmlfield)) xmlfield
	FROM sources.f_amp2 i
	) AS i;

UPDATE amps SET invalid = '0' WHERE invalid IS NULL;

CREATE TABLE licensed_route AS
SELECT
	unnest(xpath('/LIC_ROUTE/APID/text()', i.xmlfield))::VARCHAR APID,
	unnest(xpath('/LIC_ROUTE/ROUTECD/text()', i.xmlfield))::VARCHAR ROUTECD
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/LICENSED_ROUTE/LIC_ROUTE', i.xmlfield)) xmlfield
	FROM sources.f_amp2 i
	) AS i;

--ampps: Actual Medicinal Product Pack
	CREATE TABLE ampps AS
	SELECT unnest(xpath('/AMPP/NM/text()', i.xmlfield))::VARCHAR nm,
		unnest(xpath('/AMPP/APPID/text()', i.xmlfield))::VARCHAR APPID,
		unnest(xpath('/AMPP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
		unnest(xpath('/AMPP/ABBREVNM/text()', i.xmlfield))::VARCHAR ABBREVNM,
		unnest(xpath('/AMPP/VPPID/text()', i.xmlfield))::VARCHAR VPPID,
		unnest(xpath('/AMPP/APID/text()', i.xmlfield))::VARCHAR APID,
		unnest(xpath('/AMPP/COMBPACKCD/text()', i.xmlfield))::VARCHAR COMBPACKCD,
		to_date(unnest(xpath('/AMPP/DISCDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') DISCDT
	FROM (
		SELECT unnest(xpath('/ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP', i.xmlfield)) xmlfield
		FROM sources.f_ampp2 i
		) AS i;

UPDATE ampps SET invalid = '0' WHERE invalid IS NULL;

CREATE TABLE comb_content_a AS
SELECT unnest(xpath('/CCONTENT/PRNTAPPID/text()', i.xmlfield))::VARCHAR PRNTAPPID,
	unnest(xpath('/CCONTENT/CHLDAPPID/text()', i.xmlfield))::VARCHAR CHLDAPPID
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PROD_PACKS/COMB_CONTENT/CCONTENT', i.xmlfield)) xmlfield
	FROM sources.f_ampp2 i
	) AS i;

--Ingredients
CREATE TABLE ingredient_substances AS
SELECT unnest(xpath('/ING/NM/text()', i.xmlfield))::VARCHAR nm,
	unnest(xpath('/ING/ISID/text()', i.xmlfield))::VARCHAR ISID,
	to_date(unnest(xpath('/ING/ISIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') ISIDDT,
	unnest(xpath('/ING/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
	unnest(xpath('/ING/ISIDPREV/text()', i.xmlfield))::VARCHAR ISIDPREV
FROM (
	SELECT unnest(xpath('/INGREDIENT_SUBSTANCES/ING', i.xmlfield)) xmlfield
	FROM sources.f_ingredient2 i
	) AS i;

UPDATE ingredient_substances SET invalid = '0' WHERE invalid IS NULL;

--combination packs
CREATE TABLE combination_pack_ind AS
SELECT unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR INFO_DESC,
	unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD
FROM (
	SELECT unnest(xpath('/LOOKUP/COMBINATION_PACK_IND/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i;

--combination products
CREATE TABLE combination_prod_ind AS
SELECT unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR INFO_DESC,
	unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD
FROM (
	SELECT unnest(xpath('/LOOKUP/COMBINATION_PROD_IND/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i
;

--Units
CREATE TABLE unit_of_measure AS
SELECT unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR INFO_DESC,
	unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD,
	to_date(unnest(xpath('/INFO/CDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') CDDT
FROM (
	SELECT unnest(xpath('/LOOKUP/UNIT_OF_MEASURE/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i
;

--Forms
CREATE TABLE forms AS
SELECT unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR INFO_DESC,
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
		SELECT unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR INFO_DESC,
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
			REGEXP_REPLACE(
			t.info_desc,
			',?( (Corporation|Division|Research|EU|Marketing|Medical|Product(s)?|Health(( )?care)?|Europe|(Ph|F)arma(ceutical(s)?(,)?)?|international|group|lp|kg|A\/?S|AG|srl|Ltd|UK|Plc|GmbH|\(.*\)|Inc(.)?|AB|s\.?p?\.?a\.?|(& )?Co(.)?))+( 1)?$'
			,'','gim') AS name_cut
		FROM supp_temp t
	)
SELECT
	CASE
		WHEN LENGTH (name_cut) > 4 THEN name_cut
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
	info_desc NOT LIKE '%AND Company%';

UPDATE supplier
SET info_desc = replace (info_desc, ' Ltd', '');

--some suppliers are non-existing
CREATE TABLE fake_supp AS
SELECT cd, info_desc
FROM supplier
WHERE
	info_desc IN
		(
			'Special Order', 'Extemp Order', 'Drug Tariff Special Order',
			'Flavour NOT Specified', 'Approved Prescription Services','Disposable Medical Equipment',
			'Oxygen Therapy'
		) OR
	info_desc LIKE 'Imported%';

--df_indicator
CREATE TABLE df_indicator AS
SELECT unnest(xpath('/INFO/DESC/text()', i.xmlfield))::VARCHAR INFO_DESC,
	unnest(xpath('/INFO/CD/text()', i.xmlfield))::VARCHAR CD
FROM (
	SELECT unnest(xpath('/LOOKUP/DF_INDICATOR/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i;

--Creating indexes
CREATE INDEX idx_vmps ON vmps (LOWER (nm) varchar_pattern_ops);
CREATE INDEX idx_vmps_vpid ON vmps (vpid);
CREATE INDEX idx_amps_vpid ON amps (vpid);
CREATE INDEX idx_vpi_vpid ON virtual_product_ingredient (vpid);
CREATE INDEX idx_vmps_nm ON vmps (nm varchar_pattern_ops);
CREATE INDEX idx_amps_nm ON amps (nm varchar_pattern_ops);
ANALYZE amps;
ANALYZE vmps;
ANALYZE ampps;
ANALYZE vmpps;
ANALYZE virtual_product_ingredient;

--! Step 2. Separating devices
DROP TABLE IF EXISTS devices;

CREATE TABLE devices AS
WITH excluded_patterns AS (
    SELECT UNNEST(ARRAY[
        '%tablets%', '%capsules%', '%covid%', '%vaccine%',
        '%fish oil%', '%ferric%', '%antivenom%', '%immunoglobulin%',
        '%lactobacillis%', '%hydrochloric acid%', '%herbal liquid%',
        '%pollinex%', '%black currant syrup%'
    ]) AS pattern
),
offenders1 AS (
    SELECT DISTINCT apid, nm, vpid
    FROM amps
    WHERE lic_authcd IN ('0000','0003') -- 0000 - none | 0003 - unknown
)
SELECT DISTINCT 
    o.apid, 
    o.nm AS nm_a, 
    o.vpid, 
    v.nm AS nm_v, 
    'any domain, no ing' AS reason --any domain, no ingredient
FROM offenders1 o
JOIN vmps v ON v.vpid = o.vpid
LEFT JOIN virtual_product_ingredient i ON v.vpid = i.vpid
WHERE 
    i.vpid IS NULL
	AND v.nm !~* 'casirivimab|imdevimab|fish oil|econazole'
    AND NOT EXISTS (
        SELECT 1
        FROM excluded_patterns p
        WHERE LOWER(v.nm) LIKE p.pattern
    )
    OR v.nm ILIKE '% oil %'
ORDER BY o.nm;

--known device domain, ingredients not in whitelist (Drug according to RxNorm rules)
INSERT INTO devices
WITH ingred_whitelist AS (
    SELECT v.vpid
    FROM vmps v
    JOIN virtual_product_ingredient i ON i.vpid = v.vpid
    JOIN concept c ON c.vocabulary_id = 'SNOMED' AND c.concept_code = i.isid
    JOIN ancestor_snomed a ON a.descendant_concept_id = c.concept_id
    JOIN concept c2 ON c2.concept_id = a.ancestor_concept_id
    WHERE c2.concept_code IN 
    (
    '350107007', -- Cellulose derived viscosity modifier
    '418407000' -- Cellulose-derived viscosity modifier
    )
)
SELECT 
    a.apid, 
    a.nm AS nm_a, 
    a.vpid, 
    v.nm AS nm_v, 
    'device domain, NOT whitelisted' AS reason
FROM amps a
JOIN vmps v ON v.vpid = a.vpid
LEFT JOIN ingred_whitelist i ON i.vpid = v.vpid
LEFT JOIN amps x ON x.vpid = a.vpid AND x.lic_authcd != '0002' -- 0002 - Devices
WHERE 
    a.lic_authcd = '0002'
    AND v.nm !~* '(ringer|hyal|carmellose|synov|drops|sodium chloride 0)'
    AND i.vpid IS NULL
    AND x.vpid IS NULL
ORDER BY a.nm; 

--known device domain, ingredient not in whitelist (Drug according to RxNorm rules)
INSERT INTO devices
SELECT 
    a.apid, 
    a.nm AS nm_a, 
    a.vpid, 
    v.nm AS nm_v, 
    'device domain, NOT whitelisted' AS reason
FROM amps a
JOIN vmps v ON v.vpid = a.vpid
LEFT JOIN amps x --there are no AMPs WITH same VMP relations that differ IN license
    ON x.vpid = a.vpid AND x.lic_authcd != '0002'-- 0002 - Devices
WHERE 
    a.lic_authcd = '0002'-- 0002 - Devices
    AND v.nm ILIKE '% kit'
    AND x.vpid IS NULL;

--unknown domain, known 'device' ingredient
INSERT INTO devices
WITH offenders1 AS
	(
		SELECT DISTINCT nm, apid, vpid
		FROM amps
		WHERE lic_authcd IN ('0000','0003') -- 0000 - none | 0003 - Unknown
	)
SELECT DISTINCT o.apid, o.nm AS nm_a, o.vpid, v.nm AS nm_v, 'no domain, bad ing' AS reason
FROM offenders1 o
JOIN vmps v ON
	v.vpid = o.vpid
JOIN virtual_product_ingredient i
	ON v.vpid = i.vpid
JOIN ingredient_substances s
	ON s.isid = i.isid
WHERE s.isid IN
(
	'4370008', --Acetone
	'5144811000001100',	--Beeswax white
	'4173211000001108',	--Beeswax yellow
	'395754005',	--Iopamidol
	'412227008',	--Iopanoic acid
	'109224005',	--Iodised oil
	'311731000',	--Hard paraffin
	'5214211000001105',	--Hard paraffin MP 43-46c
	'16750111000001107',	--Hard paraffin MP 45-50c
	'4318311000001106',	--Purified talc
	'5215311000001103',	--Soft soap
	'425780001' -- Soft soap
);

--any domain, known 'device' ingredient
INSERT INTO devices
SELECT DISTINCT 
    a.apid, 
    a.nm AS nm_a, 
    a.vpid, 
    s.nm AS nm_v, 
    'any domain, bad ing' AS reason
FROM ingredient_substances i
JOIN concept c 
    ON c.concept_code = i.isid AND c.vocabulary_id = 'SNOMED'
JOIN ancestor_snomed ca 
    ON ca.descendant_concept_id = c.concept_id
JOIN concept d 
    ON d.concept_id = ca.ancestor_concept_id AND d.concept_code IN (
        '407935004','385420005',--Contrast Media
        '767234009',--Gadolinium (salt) -- contrast
        '255922001',--Dental material
        '764087006',--Product containing genetically modified T-cell
        '89457008',--Radioactive isotope
        '37521911000001102',--Radium-223
        '420884001',--Human mesenchymal stem cell
        '39248411000001101'-- Sodium iodide [I-131]
    )
JOIN virtual_product_ingredient v 
    ON v.isid = i.isid
JOIN vmps s 
    ON s.vpid = v.vpid
JOIN amps a 
    ON a.vpid = v.vpid;

--indication defines domain (regex)
INSERT INTO devices
WITH keywords AS (
    SELECT UNNEST(ARRAY[
        '%dialys%', '%haemofiltration%', '%sunscreen%', '%supplement%', '%food%', '%nutri%', '%oliclino%',
        '%synthamin%', '%kabiven%', '%electrolyt%', '%ehydration%', '%vamin 9%', '%intrafusin%',
        '%vaminolact%', '% glamin %', '%hyperamine%', '%primene %', '%clinimix%', '%aminoven%',
        '%plasma-lyte%', '%tetraspan%', '%tetrastarch%', '%triomel%', '%aminoplasmal%', '%compleven%',
        '%potabl%', '%forceval protein%', '%ethyl chlorid%', '%alcoderm%', '%balsamicum%', '%diprobase%',
        '%diluent%oral%', '%empty%', '%dual pack vials%', '%biscuit%', '% vamin 14 %', '%perflutren%',
        '%ornith%aspart%', '%hepa%merz%', '%gallium citrate%', '%lymphoseek%', '%kbq%', '%ether solvent%',
        'herbal liquid', 'toiletries %', 'artificial%', '% wipes', 'purified %', 'phlexy%', '%kryptoscan%',
        '%mbq%', '%gbq%', '%radium%223%', '%mo-99%', '%catheter%', '%radiopharm%',
        '%radionuclide generator%', '%gluten free bread%', '%cardioplegia%', '%gadodiamide%',
        '%catheter maintenance%', '%industrial%', '%urea c13%', 
		'%mangafodipir trisodium%', '%sodium ioxaglate%', 
		'%sodium oxidronate%', '%meglumine iotalamate%', '%gadoteric acid%', 
		'%lutetium [lu-177]%', '%gadoxetic acid%', 
		'%meglumine ioxaglate%', 
		'%meglumine amidotrizoate%',  '%radium [ra-223]%', 
		'%samarium [sm-153]%', 
		'%tauroselcholic (selenium-75 [se-75]) acid%',  '%ioflupane [i-123]%', 
		'%indium [IN-111]%',
		'%tetrofosmin%', '%perflutren-containing%', 
		'%thallous [tl-201]%', '%gallium [ga-67]%', 
		'%hynic-[d-phe1, tyr3-octreotide]%', '%yttrium [y-90]%', 
		'%meglumine gadopentetate%',  '%collodion%', 
		'%copper tetramibi tetrafluoroborate%', 'emulsifying ointment', '%soap%', '%stocking%','%cylinders%'
    ]) AS pattern
)
SELECT DISTINCT 
    a.apid, 
    a.nm, 
    v.vpid, 
    v.nm, 
    'indication defines domain (regex)' AS reason
FROM vmps v
JOIN amps a ON a.vpid = v.vpid
JOIN keywords k ON (
    LOWER(v.nm) LIKE k.pattern OR
    LOWER(v.nmprev) LIKE k.pattern OR
    LOWER(a.nm) LIKE k.pattern
);

--homeopathic products are not worth analyzing if source does NOT provide ingredients
INSERT INTO devices
SELECT
    a.apid,
    a.nm,
    v.vpid,
    v.nm,
    'homeopathy WITH no ingredient' AS reason
FROM vmps v
JOIN amps a USING (vpid)
LEFT JOIN virtual_product_ingredient i ON i.vpid = v.vpid
WHERE 
    i.vpid IS NULL
    AND (
        v.nm ILIKE '%homeop%' OR
        v.nm ILIKE '%doron %' OR
        v.nm ILIKE '%fragador%' OR
        v.nmprev ILIKE '%homeop%' OR
        v.nm ILIKE '%h+c%'
    );
   
--saline eyedrops
INSERT INTO devices
SELECT
	a.apid,
	a.nm,
	v.vpid,
	v.nm,
	'saline eyedrops' AS reason
FROM vmps v
JOIN amps a USING (vpid)
WHERE v.nm LIKE 'Generic % eye drops %' or v.nm LIKE 'Generic % eye drops';

--SNOMED devices
INSERT INTO devices
SELECT
    a.apid,
    a.nm,
    v.vpid,
    v.nm,
    'SNOMED devices' AS reason
FROM vmps v
JOIN amps a USING (vpid)
JOIN concept c ON v.vpid = c.concept_code
JOIN ancestor_snomed a_s ON a_s.descendant_concept_id = c.concept_id
WHERE
    a_s.ancestor_concept_id IN (
        35622427,--Genetically modified T-cell product
        4222664,--Product containing industrial methylated spirit
        36694441,--Sodium chloride 0.9% catheter maintenance solution pre-filled syringes
        35626947--NHS dm+d appliance
    )
    AND c.vocabulary_id = 'SNOMED'
    AND c.domain_id = 'Device';

-- if at least one vmp per amp is a drug, treat everything AS drug
WITH dev_counts AS (
    SELECT vpid, COUNT(DISTINCT apid) AS device_count
    FROM devices
    GROUP BY vpid
),
amp_counts AS (
    SELECT vpid, COUNT(apid) AS amp_count
    FROM amps
    GROUP BY vpid
),
to_delete AS (
    SELECT dev.vpid
    FROM dev_counts dev
    JOIN amp_counts amp ON dev.vpid = amp.vpid
    WHERE dev.device_count != amp.amp_count
)
DELETE FROM devices
WHERE vpid IN (SELECT vpid FROM to_delete);

--Form indicates domain
INSERT INTO devices
WITH device_forms AS (
    SELECT UNNEST(ARRAY[
        '419202002',  -- {Bone} cement
        '39816711000001105' -- Radiopharmaceutical precursor solution
    ]) AS formcd
)
SELECT
    a.apid,
    a.nm,
    v.vpid,
    v.nm,
    'Form indicates device domain' AS reason
FROM vmps v
JOIN amps a USING (vpid)
JOIN drug_form d ON d.vpid = v.vpid
JOIN device_forms f ON f.formcd = d.formcd;

ANALYZE devices;

--Deduplication of devices
DELETE FROM devices s
USING devices s_int
WHERE
    s.ctid < s_int.ctid -- leave first entry
    AND COALESCE(s.apid, 'x') = COALESCE(s_int.apid, 'x')
    AND COALESCE(s.nm_a, 'x') = COALESCE(s_int.nm_a, 'x')
    AND COALESCE(s.vpid, 'x') = COALESCE(s_int.vpid, 'x')
    AND COALESCE(s.nm_v, 'x') = COALESCE(s_int.nm_v, 'x');

CREATE INDEX devices_vpid ON devices (vpid);
CREATE INDEX devices_apid ON devices (apid);

--Step 3. Fix bugs in source (dosages in wrong units, missing denominators, inconsistent dosage of ingredients etc)
--mg instead of ml when obviously wrong
UPDATE virtual_product_ingredient
SET strnt_nmrtr_uomcd = '258684004' 
WHERE
	(strnt_nmrtr_uomcd,strnt_dnmtr_uomcd) IN
	(
		('258682000','258682000'), --gram - gram
		('258773002','258773002'), --ml - ml
		('258682000','258773002'), --gram - ml
		('258773002','258682000')  --ml - gram
	) AND
	strnt_nmrtr_val > strnt_dnmtr_val; 

WITH vpid_only AS (
    SELECT vpid
    FROM (VALUES
        ('8967511000001107'),  -- formaldehide AND acetic acid vaginal gel
        ('8967611000001106'),  
        ('17995411000001108')  
    ) AS t(vpid)
)
DELETE FROM virtual_product_ingredient vpi --duplicates or excipients
USING vpid_only
WHERE (vpi.vpid = vpid_only.vpid);

UPDATE virtual_product_ingredient
SET strnt_nmrtr_val = strnt_nmrtr_val / 17
WHERE vpid = '10050811000001105'; -- Ammonia solution strong 8.698g / Eucalyptus oil 500mg granules

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 5, -- multiple due to 5 ml IN vmp WHERE IN strength per ml amount
	strnt_dnmtr_val = strnt_dnmtr_val * 5  -- multiple due to 5 ml IN vmp WHERE IN strength per ml amount
WHERE vpid IN ('34821011000001106','3628211000001102'); -- Docusate compound 5ml enema / Sodium citrate compound 5ml enema

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 133, -- amount of 133 ml
	strnt_dnmtr_val = strnt_dnmtr_val * 133  -- amount of 133 ml
WHERE vpid IN ('3788711000001106'); -- Sodium dihydrogen phosphate dihydrate 18.1% / Disodium hydrogen phosphate dodecahydrate 8% 133ml enema

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 10, -- amount of 10 ml
	strnt_dnmtr_val = strnt_dnmtr_val * 10  -- amount of 10 ml
WHERE vpid IN ('9062611000001102'); -- Citric acid 1g/10ml oral solution sachets

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 15, -- amount of 15 ml
	strnt_dnmtr_val = strnt_dnmtr_val * 15  -- amount of 15 ml
WHERE vpid IN ('14204311000001108'); -- Oxybutynin 5mg/15ml bladder irrigation vials

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 25, -- amount of 25 ml
	strnt_dnmtr_val = strnt_dnmtr_val * 25  -- amount of 25 ml
WHERE vpid IN ('4694211000001102'); -- Daunorubicin (liposomal) 50mg/25ml solution for infusion vials

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 4, -- amount of 4 ml
	strnt_dnmtr_val = strnt_dnmtr_val * 4  -- amount of 4 ml
WHERE vpid IN ('14252411000001103'); -- Calcium folinate 200mg/4ml solution for injection vials

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 30, -- amount of 30 ml
	strnt_dnmtr_val = strnt_dnmtr_val * 30  -- amount of 30 ml
WHERE vpid IN ('15125211000001101','15125111000001107','16665111000001100'); -- Oxybutynin 5mg/30ml / Bisacodyl 10mg/30ml enema

UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 5, -- adding 5 to denominator value
       strnt_dnmtr_uomcd = '258682000' -- ading gram to denominator unit
WHERE vpid = '9186611000001108'; -- Testosterone 50mg/5g transdermal gel unit dose tube

UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 1, -- adding dose denominator
       strnt_dnmtr_uomcd = '3317411000001100' -- adding dose denominator
WHERE vpid = '3776211000001106'; -- Ispaghula husk 3.5g/dose effervescent granules gluten free sugar free

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_uomcd = '258684004', -- adding unit mg
	strnt_nmrtr_val = '1500' -- adding amount value
WHERE vpid = '24129011000001102' -- Glucosamine sulfate 1.5g / Ascorbic acid 12mg tablets
AND isid = '734505004';  -- for Glucosamine sulfate

INSERT INTO virtual_product_ingredient (vpid, isid, bs_subid, strnt_nmrtr_val, strnt_nmrtr_uomcd, strnt_dnmtr_val, strnt_dnmtr_uomcd)
VALUES ('4171411000001108','70288006',NULL,'100.0','258684004',NULL,NULL); -- adding to Co-methiamol 100mg/500mg tablets -- 100 mg of Methionine

UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 4000, -- 4000
       strnt_nmrtr_uomcd = '258684004', -- mg 
       strnt_dnmtr_val = NULL, 
       strnt_dnmtr_uomcd = NULL
WHERE vpid = '16603411000001107' -- Aminosalicylic acid gastro-resistant granules 4g sachets sugar free
AND   isid = '255666002'; -- Aminosalicylic acid 

UPDATE virtual_product_ingredient
SET
	strnt_dnmtr_val = '1000',  -- 1000
	strnt_dnmtr_uomcd = '258773002' -- ml
WHERE vpid IN ('14611111000001108','9097011000001109','9096611000001104','9097111000001105'); -- adding denominator for liquids IN 1l

UPDATE virtual_product_ingredient
SET
	strnt_dnmtr_val = '1000', -- 1000
	strnt_dnmtr_uomcd = '258684004' -- mg
WHERE vpid IN ('3864211000001105','4977811000001100','7902811000001102','425136005','3818211000001103'); -- adding denominator for cream AND oinments AS 1g

UPDATE virtual_product_ingredient
SET
	strnt_dnmtr_val = '1000', -- 1000
	strnt_dnmtr_uomcd = '258682000' -- g
WHERE vpid IN ('18411011000001106'); -- adding denominator to Glycerin of Starch BPC 1963

DELETE FROM virtual_product_ingredient 
WHERE vpid = '4210011000001101' AND strnt_nmrtr_val IS NULL; -- remove FROM Iodine alcoholic solution water AND ethanol

UPDATE virtual_product_ingredient
SET strnt_dnmtr_uomcd = '258773002' -- ml
WHERE vpid IN ('13532011000001103','10727111000001103','31363111000001105','13532111000001102','332745002'); -- updating denominator unit to ml for liquids

UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 1,
       strnt_dnmtr_uomcd = '258773002' -- ml
WHERE vpid IN ('35776311000001109','10050811000001105'); -- adding denominator for Ammonia solution strong 8.698g / Eucalyptus oil 500mg granules / Tolnaftate 1% liquid spray

--if vmpp total amount is IN ml, change denominator to ml
UPDATE virtual_product_ingredient
SET strnt_dnmtr_uomcd = '258773002'
WHERE vpid IN
	(
		SELECT i.vpid
			FROM vmpps
			JOIN virtual_product_ingredient i ON
		vmpps.qty_uomcd = '258773002' AND
		vmpps.vpid = i.vpid AND
		i.strnt_dnmtr_uomcd = '258682000'
	);

-- don't include dosages for drugs that don't have dosages for every ingredient
UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = NULL,
	strnt_nmrtr_uomcd = NULL,
	strnt_dnmtr_val = NULL,
	strnt_dnmtr_uomcd = NULL
WHERE vpid IN
	(
		SELECT vpid
		FROM virtual_product_ingredient
		WHERE
			vpid IN (SELECT vpid FROM virtual_product_ingredient WHERE strnt_nmrtr_val IS NULL)
		AND strnt_nmrtr_val IS NOT NULL
	);

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = NULL,
	strnt_nmrtr_uomcd = NULL,
	strnt_dnmtr_val = NULL,
	strnt_dnmtr_uomcd = NULL
WHERE isid = '5375811000001107'; -- pollen extract exclude from ds

-- UPDATE WHERE ml in name but denominator unit in g
WITH vmps_ml AS (
    SELECT vpid
    FROM vmps
    WHERE nm ILIKE '%ml%'
)
UPDATE virtual_product_ingredient v
SET strnt_dnmtr_uomcd = '258773002'
FROM vmps_ml
WHERE 
    v.vpid = vmps_ml.vpid
    AND v.strnt_dnmtr_uomcd = '258682000';

--  updating strength for Carmellose 0.5% eye drops 0.4ml unit dose preservative free
UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 2,
       strnt_dnmtr_val = 0.4
WHERE vpid = '18248211000001104' 
AND   isid = '51224002'; 

--create new temporary ingredients for COVID vaccines
INSERT INTO ingredient_substances (isid, nm)
VALUES
	('OMOP0000000001', 'COVID-19 vaccine, recombinant, full-LENGTH nanoparticle spike (S) protein, adjuvanted WITH Matrix-M'),
	('OMOP0000000002', 'COVID-19 vaccine, whole virus, inactivated, adjuvanted WITH Alum AND CpG 1018'),
	('OMOP0000000003', 'COVID-19 vaccine, recombinant, plant-derived Virus-Like Particle (VLP) spike (S) protein, adjuvanted WITH AS03'),
	('OMOP0000000004', 'ELASOMERAN'),
	('OMOP0000000005', 'Famtozinameran'),
	('OMOP0000000006', 'Imelasomeran');

INSERT INTO virtual_product_ingredient (vpid, isid)
VALUES
	('39478211000001100', 'OMOP0000000001'),
	('39375211000001103', 'OMOP0000000002'),
	('39828011000001104', 'OMOP0000000003'),
	('39326811000001100', '1157170002'), -- Tozinameran
	('40520611000001100', 'OMOP0000000004'),
	('40520611000001100', 'OMOP0000000006'),
	('40658411000001100', 'OMOP0000000004'),
	('40813111000001100', 'OMOP0000000004'),
	('40813111000001100', 'OMOP0000000006'),
	('41344311000001100', 'OMOP0000000004'),
	('41344311000001100', 'OMOP0000000005'),
	('42646211000001100', '42095911000001107') -- Raxtozinameran
;

-- adding missing ingredients if we can automated
CREATE VIEW new_ingr AS 
WITH ingr AS (
	SELECT DISTINCT 
	c.concept_id, 
	c.concept_name
	FROM concept c 
	WHERE c.vocabulary_id like 'RxN%'
	AND c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND LENGTH(c.concept_name) > 3
), 
upd_vpid AS (
SELECT v.vpid,v.nm, ingr.*
FROM vmps v 
	LEFT JOIN virtual_product_ingredient vpi ON v.vpid = vpi.vpid 
	LEFT JOIN devices d ON d.vpid = v.vpid 
	LEFT JOIN ingr ON v.nm ilike '%'||ingr.concept_name||'%'
WHERE vpi.vpid IS NULL
	AND d.vpid IS NULL
	AND v.nm NOT ilike '%Sodium hyaluronate%'
	AND LOWER(ingr.concept_name) NOT IN ('sodium', 'fibrin', 'vitamin d', 'lard', 'protein s',
		'calcium', 'hyaluronate', 'hyaluronidase', 'bran', 'herbal', 'interferon', 'gold', 'folate', 
		'iron', 'magnesium', 'neca', 'copper', 'glucosamine', 'chloric acid', 'ronidazole',
		'vitamin a', 'vitamin e', 'neral', 'gelatin', 'etirdonate','acetate')
ORDER BY v.nm
)
SELECT upd_vpid.vpid, upd_vpid.nm AS vmp_name, 
	upd_vpid.concept_id, upd_vpid.concept_name,
	is2.*
FROM upd_vpid
	LEFT JOIN ingredient_substances is2 
	ON LOWER(concept_name) = LOWER(is2.nm) 
ORDER BY upd_vpid.vpid;

INSERT INTO ingredient_substances (isid, nm)
SELECT DISTINCT 'OMOP00000'||concept_id AS isid, concept_name AS nm
FROM new_ingr
WHERE isid IS NULL;

INSERT INTO virtual_product_ingredient (vpid, isid)
SELECT DISTINCT vpid, 'OMOP00000'||concept_id AS isid
FROM new_ingr
WHERE isid IS null

UNION 

SELECT DISTINCT vpid, isid
FROM new_ingr
WHERE isid IS NOT NULL
;
DROP VIEW new_ingr;

--! Step 4. Preparation for drug_concept_stage population
--Some ingredients changed their isid
--isid considered isidnew, isidprev is an old one
DROP TABLE IF EXISTS ingred_replacement;
CREATE TABLE ingred_replacement AS
SELECT DISTINCT
	isidprev AS isidprev,
	nm AS nmprev,
	isid AS isidnew,
	nm AS nmnew
FROM ingredient_substances is1 
WHERE is1.isidprev IS NOT NULL;

--tree vaccine
INSERT INTO ingred_replacement VALUES ('5375811000001107',NULL,'32869811000001104',NULL); -- Birch (Betula species) pollen allergen extract
INSERT INTO ingred_replacement VALUES ('5375811000001107',NULL,'32869511000001102',NULL); -- Alder (Alnus species) pollen allergen extract
INSERT INTO ingred_replacement VALUES ('5375811000001107',NULL,'32870011000001108',NULL); -- Hazel (Corylus species) pollen allergen extract

--Processing drugs WITH multiple ingredients
--Splitting ON ' + '
DROP TABLE IF EXISTS tms_temp;
CREATE TABLE tms_temp AS
	(
		SELECT v.vtmid, v.nm AS nmprev, nmnew
		FROM vtms v
		LEFT JOIN LATERAL unnest(string_to_array(replace(v.nm,' - invalid',''), ' + ')) AS nmnew ON TRUE
		WHERE v.nm LIKE '%+%'
	);

--Connecting splitted ingredients with ids of separate ingredients
--To be inserted into drug tables
DROP TABLE IF EXISTS ir_insert;
CREATE TABLE ir_insert AS
SELECT
	t.vtmid AS isidprev,
	t.nmprev,
	COALESCE (i.isid, v.vtmid) AS isidnew,
	t.nmnew
FROM tms_temp t
LEFT JOIN vtms v ON
	t.nmnew ILIKE v.nm OR
	'Hepatitis ' || t.nmnew ILIKE v.nm OR
	t.nmnew  || ' vaccine' ILIKE v.nm
LEFT JOIN ingredient_substances i ON
	(
		t.nmnew ILIKE i.nm OR
		'Hepatitis ' || t.nmnew ILIKE i.nm OR
		t.nmnew  || ' vaccine' ILIKE i.nm
	) AND
	i.invalid = '0';

--Creating sequence for concept codes
--Later in code would be a step with exchange to OMOP-like codes. It is easier to keep it AS it was written for backward compatibility
DROP SEQUENCE IF EXISTS new_seq;
CREATE sequence new_seq INCREMENT BY 1 START
	WITH 1 CACHE 20;

--Ingredients wih newly assigned OMOP style concept_codes (if no equivalents)
DROP TABLE IF EXISTS y;
CREATE TABLE y AS
WITH x AS
	(
		SELECT DISTINCT nmnew
		FROM ir_insert
		WHERE isidnew IS NULL
	)
SELECT
	nmnew,
	'OMOP' || nextval ('new_seq') AS isid
FROM x;

--Adding ingredients with fresh OMOP style concept_codes
INSERT INTO ingred_replacement
SELECT DISTINCT
	i.isidprev,
	i.nmprev,
	COALESCE (i.isidnew, y.isid),
	i.nmnew
FROM ir_insert i
LEFT JOIN y ON
	y.nmnew = i.nmnew;

--replaces precise ingredients (salts) with active molecule with few exceptions
INSERT INTO ingred_replacement
SELECT DISTINCT
	v.isid,
	s1.nm,
	s2.isid,
	s2.nm
FROM virtual_product_ingredient v
JOIN ingredient_substances s1 ON
	v.isid = s1.isid
JOIN ingredient_substances s2 ON
	v.bs_subid = s2.isid
LEFT JOIN devices d ON --devices (contrasts) add a lot
	d.vpid = v.vpid
WHERE
	v.bs_subid IS NOT NULL AND
	d.vpid IS NULL AND
	s2.isid NOT IN -- do NOT apply to folic acid, metalic compounds and halogens -- must still be mapped to salts
		(
			SELECT c.concept_code
			FROM concept c
			JOIN ancestor_snomed ca ON
				c.vocabulary_id = 'SNOMED' AND
				ca.ancestor_concept_id IN (
				4143228, -- Metal
				4021618, -- Halogen AND/OR halogen compound
				4213977, -- Leucovorin
				35624387) AND -- Metal and/or metal compound
				ca.descendant_concept_id = c.concept_id
		) AND
	SUBSTRING (LOWER (s1.nm) FROM 1 FOR 7) != 'insulin' -- to not to lose various insulins
;

--if X replaced with Y and Y replaced WITH Z, replace X with Z
UPDATE ingred_replacement x --314
	SET
		(isidnew,nmnew) =
			(
				SELECT
					r.isidnew,
					r.nmnew
				FROM ingred_replacement r
				WHERE x.isidnew = r.isidprev
				  --Only one to one change
                AND r.isidprev NOT IN (SELECT isidprev
FROM ingred_replacement ir
GROUP BY isidprev
HAVING count(DISTINCT isidnew) > 1)
                --Intermediate ingredient does not have multiple ingredients to change
                AND r.isidnew NOT IN (SELECT isidprev
FROM ingred_replacement ir
GROUP BY isidprev
HAVING count(DISTINCT isidnew) > 1
    )
			)
	WHERE x.isidnew IN (SELECT ISIDprev FROM ingred_replacement)
	  --do NOT UPDATE for rows WITH 2 or more replacement ingredients
;

TRUNCATE drug_concept_stage ;
--! Step 5. drug_concept_stage population
--Splitted into a few inserts to facilitate code run
INSERT INTO drug_concept_stage
	(
		concept_name,
		domain_id,
	    vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		source_concept_class_id
	)

--Forms
SELECT DISTINCT
	LEFT (info_desc,255) AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Dose Form' AS concept_class_id,
	NULL AS standard_concept,
	cd AS concept_code,
	COALESCE(cddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	'Form' AS source_concept_class_id
FROM forms

	UNION

--Ingredients
SELECT DISTINCT
	LEFT (nm,255) AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	'S' AS standard_concept,
	isid AS concept_code,
	COALESCE(isiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	'Ingredient'
FROM ingredient_substances

	UNION

--Ingredients (VTMs) -- some are needed
SELECT DISTINCT
	LEFT (nm,255) AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	'S' AS standard_concept,
	vtmid AS concept_code,
	COALESCE(vtmiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	'VTM'
FROM vtms

	UNION ALL

--Generated replacements ingredients
SELECT DISTINCT
	LEFT (nmnew,255) AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	'S' AS standard_concept,
	isid AS concept_code,
	TO_DATE('1970-01-01','YYYY-MM-DD'),
	TO_DATE('20991231','yyyymmdd'),
	NULL AS invalid_reason,
	'Ingredient'
--Ingredients wih newly assigned OMOP style concept_codes (if no equivalents)
FROM y;

--Suppliers
INSERT INTO drug_concept_stage
	(
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		source_concept_class_id
	)
--Suppliers
SELECT DISTINCT
	LEFT (s.info_desc,255) AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Supplier' AS concept_class_id,
	NULL AS standard_concept,
	s.cd AS concept_code,
	COALESCE(cddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	'Supplier'
FROM supplier s
LEFT JOIN fake_supp f ON
	f.cd = s.cd
WHERE
	f.cd IS NULL;

--Units
INSERT INTO drug_concept_stage
	(
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		source_concept_class_id
	)
--Units
SELECT
	DISTINCT LEFT (info_desc,255) AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Unit' AS concept_class_id,
	NULL AS standard_concept,
	cd AS concept_code,
	COALESCE(cddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	'Unit'
FROM unit_of_measure;

INSERT INTO drug_concept_stage
	(
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		source_concept_class_id
	)
--VMP = Virtual Medicinal Product = Clinical Drug (OMOP)
SELECT
	DISTINCT LEFT (v.nm,255) AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Drug Product' AS concept_class_id,
	NULL AS standard_concept,
	v.vpid AS concept_code,
	COALESCE(v.vpiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
	CASE
		WHEN v.invalid = '1' THEN
			(
				SELECT latest_UPDATE - 1
				FROM vocabulary
				WHERE vocabulary_id = 'dm+d'
			)
		ELSE TO_DATE('20991231','yyyymmdd')
	END AS valid_end_date,
	CASE v.invalid
		WHEN '1' THEN 'D'
		ELSE NULL
	END AS invalid_reason,
	'VMP'
FROM vmps v
LEFT JOIN devices d ON
	v.vpid = d.vpid
WHERE d.vpid IS NULL;

INSERT INTO drug_concept_stage
	(
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		source_concept_class_id
	)
--VMP = Virtual Medicinal Product = Device (OMOP)
SELECT DISTINCT
	LEFT (v.nm,255) AS concept_name,
	'Device' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Device' AS concept_class_id,
	'S' AS standard_concept,
	v.vpid AS concept_code,
	COALESCE(v.vpiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	'VMP'
FROM vmps v
JOIN devices d ON
	v.vpid = d.vpid;

INSERT INTO drug_concept_stage
	(
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		source_concept_class_id
	)
--VMPPS = Virtual Medicinal Product Pack = Clinical Drug Box (OMOP)
SELECT DISTINCT LEFT (v.nm,255) AS concept_name,
       'Drug' AS domain_id,
       'dm+d' AS vocabulary_id,
       'Drug Product' AS concept_class_id,
       NULL AS standard_concept,
       v.vppid AS concept_code,
       COALESCE(p.vpiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
       CASE
         WHEN v.invalid = '1' THEN (SELECT latest_UPDATE - 1
                        FROM vocabulary
                        WHERE vocabulary_id = 'dm+d')
         ELSE TO_DATE('20991231','yyyymmdd')
       END AS valid_end_date,
       CASE
         WHEN v.invalid = '1' THEN 'D'
         ELSE NULL
       END AS invalid_reason,
       'VMPP'
FROM vmpps v
  JOIN vmps p ON
--start date etc stored in VMPS
v.vpid = p.vpid
  LEFT JOIN devices d ON v.vpid = d.vpid
WHERE d.vpid IS NULL;

INSERT INTO drug_concept_stage
	(
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		source_concept_class_id
	)
--VMPPS = Virtual Medicinal Product Pack = Device (OMOP)
SELECT DISTINCT LEFT (v.nm,255) AS concept_name,
       'Device' AS domain_id,
       'dm+d' AS vocabulary_id,
       'Device' AS concept_class_id,
       'S' AS standard_concept,
       v.vppid AS concept_code,
       COALESCE(p.vpiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
       'VMPP'
FROM vmpps v
  JOIN vmps p ON
--start date etc stored in VMPS
v.vpid = p.vpid
  JOIN devices d ON v.vpid = d.vpid;

--AMPS = Actual Medicinal Product = Branded Drug (OMOP)
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
--AMPS = Actual Medicinal Product = Branded Drug (OMOP)
SELECT DISTINCT LEFT (a.nm,255),
       'Drug' AS domain_id,
       'dm+d' AS vocabulary_id,
       'Drug Product' AS concept_class_id,
       NULL AS standard_concept,
       a.apid AS concept_code,
       COALESCE(a.nmdt,p.vpiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
       CASE
         WHEN a.invalid = '1' THEN (SELECT latest_UPDATE - 1
                        FROM vocabulary
                        WHERE vocabulary_id = 'dm+d')
         ELSE TO_DATE('20991231','yyyymmdd')
       END AS valid_end_date,
       CASE
         WHEN a.invalid = '1' THEN 'D'
         ELSE NULL
       END AS invalid_reason,
       'AMP'
FROM amps a
  JOIN vmps p ON a.vpid = p.vpid
--start date etc stored in VMPS
  LEFT JOIN devices d ON a.vpid = d.vpid
WHERE d.vpid IS NULL;

--AMPS = Actual Medicinal Product = Device (OMOP)
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
--AMPS = Actual Medicinal Product = Device (OMOP)
SELECT DISTINCT LEFT (a.nm,255),
       'Device' AS domain_id,
       'dm+d' AS vocabulary_id,
       'Device' AS concept_class_id,
       'S' AS standard_concept,
       a.apid AS concept_code,
		TO_DATE('1970-01-01','YYYY-MM-DD') valid_start_date,
		TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
       'AMP'
FROM amps a
WHERE EXISTS (
    SELECT 1 FROM devices d WHERE d.vpid = a.vpid
);

--AMPPS = Actual Medicinal Product Pack = Branded Drug Box (OMOP)
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
--AMPPS = Actual Medicinal Product Pack = Branded Drug Box (OMOP)
SELECT DISTINCT
	LEFT (a1.nm,255) AS concept_name,
    'Drug' AS domain_id,
    'dm+d' AS vocabulary_id,
    'Drug Product' AS concept_class_id,
    NULL AS standard_concept,
    a1.appid AS concept_code,
    TO_DATE('1970-01-01','YYYY-MM-DD') valid_start_date,
    CASE
		WHEN a1.invalid = '1' THEN
			(
				SELECT latest_UPDATE - 1
        		FROM vocabulary
        		WHERE vocabulary_id = 'dm+d'
        	)
		ELSE TO_DATE('20991231','yyyymmdd')
	END AS valid_end_date,
	CASE
		WHEN a1.invalid = '1' THEN 'D'
		ELSE NULL
	END AS invalid_reason,
	'AMPP'
FROM ampps a1
LEFT JOIN devices d ON a1.apid = d.apid
WHERE d.apid IS NULL;

--AMPPS = Actual Medicinal Product Pack = Device
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
--AMPPS = Actual Medicinal Product Pack = Device
SELECT DISTINCT
	LEFT (a1.nm,255) AS concept_name,
       'Device' AS domain_id,
       'dm+d' AS vocabulary_id,
       'Device' AS concept_class_id,
       'S' AS standard_concept,
       a1.appid AS concept_code,
       	TO_DATE('1970-01-01','YYYY-MM-DD') AS valid_start_date,
		TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
       'AMPP'
FROM ampps a1
JOIN devices d ON a1.apid = d.apid;

--source 'Ingredient' is preferred to 'VTM'
INSERT INTO ingred_replacement
SELECT 
	d2.concept_code,
	d2.concept_name,
	d1.concept_code,
	d1.concept_name
FROM drug_concept_stage d1
JOIN drug_concept_stage d2 ON
	d1.source_concept_class_id = 'Ingredient' AND
	d2.source_concept_class_id = 'VTM' AND
	TRIM(LOWER(d1.concept_name)) = TRIM(LOWER(d2.concept_name));

TRUNCATE pc_stage;
--! Step 6. pc_stage population
INSERT INTO pc_stage
(SELECT
	c.prntvppid AS pack_concept_code,
	p2.vppid AS drug_concept_code,
	cast
	(
		CASE
			WHEN p2.qty_uomcd NOT IN
				( --scalable doses
					'258684004', --mg
					'258774008', --microlitre
					'258773002', --ml
					'258770004', --litre
					'732981002', --actuation
					'3317411000001100', --dose
					'3319711000001103', --unit dose
					'258682000' --gram
				)
			THEN p2.qtyval
			ELSE 1
		END AS smallint

	) AS amount,
	NULL::smallint AS box_size
FROM comb_content_v c
JOIN vmpps p1 ON
	c.prntvppid = p1.vppid
LEFT JOIN devices d1 ON --filter devices
	d1.vpid = p1.vpid
JOIN vmpps p2 ON
	c.chldvppid = p2.vppid --extract pack size
LEFT JOIN devices d2 ON --probably redundant check for devices
	d2.vpid = p2.vpid
WHERE
	d1.vpid IS NULL AND
	d2.vpid IS NULL

	UNION ALL

SELECT
	c.prntappid AS pack_concept_code,
	p2.appid AS drug_concept_code,
	cast
	(
		CASE
			WHEN vx.qty_uomcd NOT IN
				( --scalable doses
					'258684004', --mg
					'258774008', --microlitre
					'258773002', --ml
					'258770004', --litre
					'732981002', --actuation
					'3317411000001100', --dose
					'3319711000001103', --unit dose
					'258682000' --gram
				)
			THEN vx.qtyval
			ELSE 1
		END
		AS smallint
	) AS amount,
	NULL::smallint AS box_size
FROM comb_content_a c
JOIN ampps p1 ON
	c.prntappid = p1.appid
LEFT JOIN devices d1 ON --filter devices
	d1.apid = p1.apid
JOIN ampps p2 ON --extract pack size
	c.chldappid = p2.appid
JOIN vmpps vx ON --through vmpp
	vx.vppid = p2.vppid
LEFT JOIN devices d2 ON --probably redundant check for devices
	d2.apid = p2.apid
WHERE
	d1.apid IS NULL AND
	d2.apid IS NULL);

--Modifiers
DROP TABLE IF EXISTS pc_modifier;

--VMPPS, get modifiers indirectly
CREATE TABLE pc_modifier AS
SELECT 
	p.pack_concept_code,
	v.qtyval / sum (p.amount) AS multiplier
FROM pc_stage p
JOIN vmpps v ON
	v.vppid = p.pack_concept_code
WHERE v.qtyval != '1'
GROUP BY p.pack_concept_code, qtyval;

DELETE FROM pc_modifier
WHERE
	multiplier <= 1 or
	multiplier IS NULL;

UPDATE pc_stage p
SET box_size = m.multiplier
FROM pc_modifier m
WHERE m.pack_concept_code = p.pack_concept_code;

UPDATE pc_stage p
SET box_size = m.multiplier
FROM pc_modifier m
JOIN ampps a ON a.vppid = m.pack_concept_code
WHERE a.appid = p.pack_concept_code;

DROP TABLE IF EXISTS pc_modifier;

--AMPPS FROM names
CREATE TABLE pc_modifier AS
SELECT DISTINCT
	p.pack_concept_code,
	REGEXP_REPLACE (TRIM (FROM REGEXP_MATCH (REGEXP_REPLACE (replace (replace (a.nm,' x ','x'),')',''), '1x\(',''), ' [2-9]+x\(.*') :: VARCHAR,'{}" '),'x.*$','') :: INT4 AS multiplier
FROM ampps a
JOIN pc_stage p ON
	p.pack_concept_code = a.appid
WHERE box_size IS NULL;

DELETE FROM pc_modifier
WHERE
	multiplier <= 1 OR
	multiplier IS NULL;

UPDATE pc_stage c
SET
    amount   = (c.amount   / m.multiplier)::INT,
    box_size = m.multiplier::INT
FROM pc_modifier m
WHERE m.pack_concept_code = c.pack_concept_code;

--fix bodyless headers: AMP and VMP ancestors of pack concepts
INSERT INTO pc_stage
--branded pack headers, can have Brand Name, Supplier and PC entry with same AMPs as AMPP counterpart
SELECT DISTINCT
	a.apid AS pack_concept_code,
	ax.apid,
	NULL::INT4 AS amount, --empty for header concepts
	NULL::INT4 AS box_size
FROM pc_stage p
JOIN ampps a ON
	a.appid = p.pack_concept_code
JOIN ampps ax ON
	p.drug_concept_code = ax.appid;

INSERT INTO pc_stage
--clinical pack headers, can have only PC entry with same VMPs as VMPP counterpart
SELECT DISTINCT
	v.vpid AS pack_concept_code,
	vx.vpid,
	NULL::INT4 AS amount, --empty for header
	NULL::INT4 AS box_size
FROM pc_stage p
JOIN vmpps v ON
	v.vppid = p.pack_concept_code
JOIN vmpps vx ON
	vx.vppid = p.drug_concept_code;

TRUNCATE internal_relationship_stage;
--! Step 7. internal_relationship_stage population
INSERT INTO internal_relationship_stage
 -- VMP to ingredient
SELECT DISTINCT
	v.vpid AS cc1,
	COALESCE
		(
			i.isid,	--correct IS
			v.vtmid --VTM
		)
FROM vmps v
LEFT JOIN virtual_product_ingredient i ON i.vpid = v.vpid
LEFT JOIN devices d ON --NOT device
	v.vpid = d.vpid
LEFT JOIN pc_stage p ON --NOT pack header
	v.vpid = p.pack_concept_code
WHERE
	d.vpid IS NULL AND 
	p.pack_concept_code IS NULL;

DELETE FROM internal_relationship_stage s
WHERE concept_code_2 IS NULL;

--replace ingredients deprecated by source
UPDATE internal_relationship_stage ir
SET    concept_code_2 = p.isidnew
FROM   ingred_replacement p
WHERE  ir.concept_code_2 = p.isidprev;

INSERT INTO internal_relationship_stage
--VMP to dose form
WITH multi_pcs AS (
    SELECT pack_concept_code
    FROM pc_stage
    GROUP BY pack_concept_code
    HAVING COUNT(drug_concept_code) <> 1
)
SELECT
    v.vpid,
    v.formcd
FROM drug_form v
LEFT JOIN devices d
    ON d.vpid = v.vpid
LEFT JOIN multi_pcs mp
    ON mp.pack_concept_code = v.vpid
WHERE
    d.vpid IS NULL        -- exclude those present in devices
    AND mp.pack_concept_code IS NULL  -- exclude those with ≠1 mapping in pc_stage
    AND v.formcd <> '3097611000001100';  -- filter out “NOT Applicable”

--Some drugs have missing dose forms at this step. Only concepts without dose forms got by regular way are addressed here.
DROP TABLE IF EXISTS dose_form_fix;

CREATE TABLE dose_form_fix AS
WITH
-- 1) VPIDs, not in devices, not bad in pc_stage and do not have dose forms in internal_relationship_stage
initial AS (
  SELECT DISTINCT
    v.vpid,
    v.nm
  FROM vmps v
  LEFT JOIN devices d
    ON d.vpid = v.vpid
  LEFT JOIN (
    SELECT pack_concept_code
    FROM pc_stage
    GROUP BY pack_concept_code
    HAVING COUNT(drug_concept_code) <> 1
  ) bad_p
    ON bad_p.pack_concept_code = v.vpid
  WHERE
    d.vpid IS NULL
    AND bad_p.pack_concept_code IS NULL
    AND v.vpid NOT IN (
      SELECT i.concept_code_1
      FROM internal_relationship_stage i
      JOIN drug_concept_stage c
        ON c.concept_class_id = 'Dose Form'
       AND c.concept_code = i.concept_code_2
    )
)
-- 2) final select with one case, to create dose code + name
SELECT
  vpid,
  nm,
  CASE
    WHEN nm ILIKE ANY (ARRAY['%viscosurgical%', '%infusion%', '%ampoules%', '%syringes%']) THEN '385219001'
    WHEN nm ILIKE ANY (ARRAY['%syrup%', '%tincture%', '%oral drops%', '%oral spray%']) THEN '385023001'
    WHEN nm ILIKE '%swabs%' THEN '385108009'
    WHEN nm ILIKE ANY (ARRAY['% oil %', '% oil', '%cream%']) THEN '385111005'
    WHEN nm ILIKE ANY (ARRAY['%oral%powder%', '%tri%salts%']) THEN '14945811000001105'
    WHEN nm ILIKE '%inhala%' THEN '385210002'
    WHEN nm ILIKE '%eye%' THEN '385124005'
    WHEN nm ILIKE ANY (ARRAY['%intraves%', '%maint%']) THEN '16605211000001107'
    WHEN nm ILIKE ANY (ARRAY['%powder%', '%crystals%']) THEN '85581007'
    WHEN nm ILIKE '%mouthwash%' THEN '70409003'
    ELSE '420699003'
  END AS dose_code,
  CASE
    WHEN nm ILIKE ANY (ARRAY['%viscosurgical%', '%infusion%', '%ampoules%', '%syringes%']) THEN 'Solution for injection'
    WHEN nm ILIKE ANY (ARRAY['%syrup%', '%tincture%', '%oral drops%', '%oral spray%']) THEN 'Oral solution'
    WHEN nm ILIKE '%swabs%' THEN 'Cutaneous solution'
    WHEN nm ILIKE ANY (ARRAY['% oil %', '% oil', '%cream%']) THEN 'Cutaneous emulsion'
    WHEN nm ILIKE ANY (ARRAY['%oral%powder%', '%tri%salts%']) THEN 'Powder for gastroenteral liquid'
    WHEN nm ILIKE '%inhala%' THEN 'Inhalation vapour'
    WHEN nm ILIKE '%eye%' THEN 'Eye drops'
    WHEN nm ILIKE ANY (ARRAY['%intraves%', '%maint%']) THEN 'Irrigation solution'
    WHEN nm ILIKE ANY (ARRAY['%powder%', '%crystals%']) THEN 'Powder'
    WHEN nm ILIKE '%mouthwash%' THEN 'Mouthwash'
    ELSE 'Liquid'
  END AS dose_name
FROM initial;

INSERT INTO internal_relationship_stage
SELECT vpid, dose_code
FROM dose_form_fix
WHERE dose_code IS NOT NULL;

INSERT INTO internal_relationship_stage
-- AMP to dose form
-- Ingredient relations will be inherited after ds_stage
WITH singly_mapped AS (
    SELECT pack_concept_code
    FROM pc_stage
    GROUP BY pack_concept_code
    HAVING COUNT(drug_concept_code) <> 1
)
SELECT DISTINCT
    a.apid,
    i.concept_code_2
FROM amps a
JOIN internal_relationship_stage i
  ON i.concept_code_1 = a.vpid
JOIN drug_concept_stage dcs
  ON i.concept_code_2 = dcs.concept_code
  AND dcs.concept_class_id = 'Dose Form'
LEFT JOIN devices d
  ON d.apid = a.apid
LEFT JOIN singly_mapped sm
  ON sm.pack_concept_code = a.apid
WHERE
    d.apid IS NULL           -- exclude any AMP already in devices
  AND sm.pack_concept_code IS NULL  -- exclude any AMP with exactly 1 mapping in pc_stage
;

INSERT INTO internal_relationship_stage
--AMP to supplier
SELECT DISTINCT
	a.apid,
	a.suppcd
FROM amps a
LEFT JOIN fake_supp c ON -- supplier is present in dcs
	a.suppcd = c.cd
LEFT JOIN devices d ON
	a.apid = d.apid
WHERE
	d.apid IS NULL AND
	c.cd IS NULL;

INSERT INTO internal_relationship_stage
--VMPP -- if NOT a pack, reuse VMP relations. If a pack, omit.
WITH multi_pcs AS (
  SELECT pack_concept_code
  FROM pc_stage
  GROUP BY pack_concept_code
  HAVING COUNT(drug_concept_code) <> 1
)
SELECT DISTINCT
  p.vppid,
  i.concept_code_2
FROM internal_relationship_stage i
JOIN vmpps p
  ON p.vpid = i.concept_code_1
LEFT JOIN multi_pcs mp
  ON mp.pack_concept_code = p.vppid
WHERE
  mp.pack_concept_code IS NULL;

--AMPP -- if not a pack, reuse AMP relations. If a pack, omit.
INSERT INTO internal_relationship_stage
WITH multi_pcs AS (
    SELECT pack_concept_code
    FROM pc_stage
    GROUP BY pack_concept_code
    HAVING COUNT(drug_concept_code) <> 1
)
SELECT DISTINCT
    p.appid,
    i.concept_code_2
FROM internal_relationship_stage i
JOIN ampps p
    ON p.apid = i.concept_code_1
LEFT JOIN multi_pcs mp
    ON mp.pack_concept_code = p.appid
LEFT JOIN devices d
    ON d.apid = p.apid
WHERE
    mp.pack_concept_code IS NULL  -- exclude multi-mapped pack_concept_codes
    AND d.apid IS NULL;           -- exclude those already IN devices

--Monopacks (1 drug_concept_code per pack)
DROP TABLE IF EXISTS only_1_pack;
CREATE TABLE only_1_pack AS
WITH single_pcs AS (
    SELECT pack_concept_code
    FROM pc_stage
    GROUP BY pack_concept_code
    HAVING COUNT(drug_concept_code) = 1
)
SELECT 
    p.pack_concept_code,
    p.drug_concept_code,
    p.amount
FROM pc_stage p
JOIN single_pcs s
  ON s.pack_concept_code = p.pack_concept_code;

INSERT INTO internal_relationship_stage --monopacks inherit their content's relation entirely, if they don't already have unique
WITH 
-- 1) only WITH 1 drug_concept_code packs
only_1_pack AS (
  SELECT pack_concept_code
  FROM pc_stage
  GROUP BY pack_concept_code
  HAVING COUNT(drug_concept_code) = 1
),
-- 2) all candidates not matter what class pack → concept_2  
candidates AS (
  SELECT DISTINCT
    p.pack_concept_code,
    i.concept_code_2,
    x.concept_class_id
  FROM internal_relationship_stage i
  JOIN pc_stage p 
    ON i.concept_code_1 = p.drug_concept_code
  JOIN only_1_pack o1 
    USING (pack_concept_code)
  JOIN drug_concept_stage x 
    ON x.concept_code = i.concept_code_2
),
-- 3) only for Supplier or Dose Form  
existing_rel AS (
  SELECT
    z.concept_code_1 AS pack_concept_code,
    dz.concept_class_id
  FROM internal_relationship_stage z
  JOIN drug_concept_stage dz 
    ON dz.concept_code = z.concept_code_2
  WHERE dz.concept_class_id IN ('Supplier','Dose Form')
)
SELECT
  c.pack_concept_code,
  c.concept_code_2
FROM candidates c
LEFT JOIN existing_rel e
  ON e.pack_concept_code = c.pack_concept_code
 AND e.concept_class_id = c.concept_class_id
WHERE e.pack_concept_code IS NULL;

WITH only_1_pack AS (
    SELECT pack_concept_code
    FROM pc_stage
    GROUP BY pack_concept_code
    HAVING COUNT(drug_concept_code) = 1
)
DELETE FROM pc_stage p
USING only_1_pack o
WHERE p.pack_concept_code = o.pack_concept_code;

UPDATE pc_stage
SET	amount = 1
WHERE pack_concept_code = '34884711000001100'; -- fix of drug

--! Step 8. Preparation for ds_stage population. Form ds_stage using source relations and name analysis. Replace ingredient relations
DROP TABLE IF EXISTS ds_prototype;

--Create ds_stage for VMPs, inherit everything ELSE later
CREATE TABLE ds_prototype AS
--temporary table
WITH basic AS (
SELECT v.udfs_uomcd,
i.vpid,COALESCE (r.isidnew,i.isid) AS isid,i.strnt_nmrtr_val,i.strnt_nmrtr_uomcd,i.strnt_dnmtr_val,i.strnt_dnmtr_uomcd,v.udfs
FROM virtual_product_ingredient i -- main source table
JOIN vmps v ON
	v.vpid = i.vpid AND
	i.strnt_nmrtr_uomcd NOT IN (
	'258672001', -- cm
	'258731005' -- ppm
	)
LEFT JOIN ingred_replacement r ON
	i.isid = r.isidprev
LEFT JOIN devices d ON --no ds entry for non-drugs
	i.vpid = d.vpid
WHERE d.vpid IS NULL
)
SELECT DISTINCT
	c1.concept_code AS drug_concept_code,
	c1.concept_name AS drug_name,
	c2.concept_code AS ingredient_concept_code,
	c2.concept_name AS ingredient_name,
	b.strnt_nmrtr_val AS amount_value,
	c3.concept_code AS amount_code,
	c3.concept_name AS amount_name,
	b.strnt_dnmtr_val AS denominator_value,
	c4.concept_code AS denominator_code,
	c4.concept_name AS denominator_name,
	NULL::INT4 AS box_size,
	b.udfs AS total, --sometimes contains additional info about size AND amount
	u1.cd AS unit_1_code,
	u1.info_desc AS unit_1_name
FROM basic b 
LEFT JOIN UNIT_OF_MEASURE u1 ON
	b.udfs_uomcd = u1.cd
JOIN drug_concept_stage c1 ON
	c1.concept_code = b.vpid
JOIN drug_concept_stage c2 ON
	c2.concept_code = b.isid
JOIN drug_concept_stage c3 ON
	c3.concept_code = b.strnt_nmrtr_uomcd
LEFT JOIN drug_concept_stage c4 ON
	c4.concept_code = b.strnt_dnmtr_uomcd;

DROP TABLE IF EXISTS vmps_res --try to salvage missing dosages from texts FROM VMPs
;

CREATE TABLE vmps_res AS
WITH ingreds AS
	(
		SELECT concept_code_1, concept_code, concept_name
		FROM internal_relationship_stage i
		JOIN drug_concept_stage c ON
			i.concept_code_2 = c.concept_code AND
			c.concept_class_id = 'Ingredient'
	),
dforms AS
	(
		SELECT concept_code_1, concept_code, concept_name
		FROM internal_relationship_stage i
		JOIN drug_concept_stage c ON
			i.concept_code_2 = c.concept_code AND
			c.concept_class_id = 'Dose Form'
	)
SELECT DISTINCT
	v.vpid AS drug_concept_code,
	replace (v.nm,',','') AS drug_concept_name,
	i.concept_code AS ingredient_concept_code,
	i.concept_name AS ingredient_concept_name,
	f.concept_code AS form_concept_code,
	f.concept_name AS form_concept_name,
	NULL :: VARCHAR (255) AS modified_name
FROM vmps v
LEFT JOIN ds_prototype s ON
	s.drug_concept_code = v.vpid
LEFT JOIN devices d ON
	v.vpid = d.vpid
LEFT JOIN pc_stage p ON
	p.pack_concept_code = v.vpid
LEFT JOIN ingreds i ON
	v.vpid = i.concept_code_1
LEFT JOIN dforms f ON
	v.vpid = f.concept_code_1
WHERE
	d.vpid IS NULL 
	AND p.pack_concept_code IS NULL 
	AND s.drug_concept_code IS NULL;

-- move deprecated gases (given AS 1 ml / 1 ml) to manual work
INSERT INTO vmps_res
SELECT
	drug_concept_code,
	drug_name,
	ingredient_concept_code,
	ingredient_name,
	'3092311000001108',
	'Inhalation gas',
	NULL
FROM ds_prototype
WHERE
	amount_name = 'ml' AND
	amount_value = 1 AND
	total IS NULL AND
	denominator_name != 'litre' AND
	drug_name LIKE '%litres%';

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	drug_concept_code,
	'3092311000001108'
FROM ds_prototype
WHERE
	amount_name = 'ml' AND
	amount_value = 1 AND
	total IS NULL AND
	denominator_name != 'litre' AND
	drug_name LIKE '%litres%';

DELETE
FROM ds_prototype
WHERE
	amount_name = 'ml' AND
	amount_value = 1 AND
	total IS NULL AND
	denominator_name != 'litre';

--help autoparser a little
UPDATE vmps_res SET drug_concept_name = replace (drug_concept_name,'1.5million unit','1500000unit');
UPDATE vmps_res SET drug_concept_name = replace (drug_concept_name,'1.2million unit','1200000unit');

DELETE FROM vmps_res
WHERE
	LOWER(drug_concept_name) LIKE '%homeopath%' OR
	LOWER(ingredient_concept_name) LIKE '%homeopath%' OR
	LOWER(form_concept_name) LIKE '%homeopath%';

UPDATE vmps_res SET ingredient_concept_name = 'Estramustine' WHERE ingredient_concept_name = 'Estramustine phosphate';
UPDATE vmps_res SET ingredient_concept_name = 'Tenofovir' WHERE ingredient_concept_name = 'Tenofovir disoproxil';
UPDATE vmps_res SET ingredient_concept_name = 'Lysine' WHERE ingredient_concept_name = 'L-Lysine';

--cut ingredient at start for single-ingredient
UPDATE vmps_res 
SET	modified_name =
	replace (
		right
		(
			LOWER (drug_concept_name),
			LENGTH (drug_concept_name) - (strpos (LOWER (drug_concept_name), LOWER (ingredient_concept_name))) - LENGTH (ingredient_concept_name)
		)
	, ' / ', '/')
WHERE
	strpos (LOWER (drug_concept_name), LOWER (ingredient_concept_name)) != 0 AND
	drug_concept_code IN
		(
			SELECT drug_concept_code
			FROM vmps_res
			GROUP BY drug_concept_code
			HAVING count (ingredient_concept_code) = 1 --good results only guaranteed for single ingred
		);

UPDATE vmps_res
SET modified_name =
	replace (
		REGEXP_REPLACE (LOWER (drug_concept_name), '^\D+','')
	, ' / ', '/')
WHERE
	strpos (LOWER (drug_concept_name), LOWER (ingredient_concept_name)) = 0 AND
	drug_concept_code IN
		(
			SELECT drug_concept_code
			FROM vmps_res
			GROUP BY drug_concept_code
			HAVING count (ingredient_concept_code) = 1 --good results only guaranteed for single ingred
		);

--cut form FROM the END
UPDATE vmps_res 
SET modified_name =
	CASE
		WHEN modified_name IS NULL THEN NULL
		WHEN strpos (modified_name, LOWER (form_concept_name)) != 0 THEN
			left (modified_name, strpos (modified_name, LOWER (form_concept_name)) - 1)
		ELSE modified_name
	END
WHERE form_concept_code IS NOT NULL;

UPDATE vmps_res
SET modified_name =
	CASE
		WHEN modified_name = '' THEN NULL
		WHEN REGEXP_MATCH (modified_name, '\d', 'im') IS NULL THEN NULL
		ELSE modified_name
	END;

--remove traces of other artifacts
UPDATE vmps_res 
SET modified_name =
	TRIM (FROM REGEXP_REPLACE (REGEXP_REPLACE (modified_name, '^[a-z \(\)]+ ', '', 'im'),' [\w \(\),-.]+$','','im'))
WHERE modified_name IS NOT NULL;

UPDATE vmps_res SET
modified_name = REGEXP_REPLACE (modified_name, ' .*$','')
WHERE modified_name LIKE '% %';

UPDATE vmps_res
SET modified_name = NULL
WHERE
	modified_name LIKE '%ppm%' OR
	modified_name LIKE '%square%';

DROP TABLE IF EXISTS ds_parsed;
--percentage
CREATE TABLE ds_parsed AS
SELECT 
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	TRIM (FROM REGEXP_MATCH (modified_name, '^[\d.]+','im') :: VARCHAR, '{}') :: NUMERIC * 10 AS amount_value,
	'258684004' AS amount_code,
	'mg' AS amount_name,
	1 AS denominator_value,
	'258773002' AS denominator_code,
	'ml' AS denominator_name,
	NULL :: INT4 AS box_size,
	NULL :: NUMERIC AS total,
	NULL :: VARCHAR AS unit_1_code,
	NULL :: VARCHAR AS unit_1_name
FROM vmps_res
WHERE
	modified_name ~ '%' 
	AND
	REGEXP_MATCH (drug_concept_name, ' [0-9.]+ml ') IS NULL

	UNION all
	
--percentage, WITH given total volume
SELECT 
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	TRIM (FROM REGEXP_MATCH (modified_name, '^[\d.]+','im') :: VARCHAR, '{}') :: NUMERIC * 10 * TRIM (FROM REGEXP_MATCH (drug_concept_name, ' [0-9.]+ml ','im') :: VARCHAR, ' ml{}"') :: NUMERIC AS amount_value,
	'258684004' AS amount_code,
	'mg' AS amount_name,
	TRIM (FROM REGEXP_MATCH (drug_concept_name, ' [0-9.]+ml ','im') :: VARCHAR, ' ml{}"') :: NUMERIC AS denominator_value,
	'258773002' AS denominator_code,
	'ml' AS denominator_name,
	NULL AS box_size,
	NULL AS total,
	NULL AS unit_1_code,
	NULL AS unit_1_name
FROM vmps_res
WHERE
	modified_name ~ '%'  AND
	REGEXP_MATCH (drug_concept_name, ' [0-9.]+ml ') IS NOT NULL

	UNION ALL

--numerator/denominator
SELECT 
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	TRIM (FROM REGEXP_MATCH (modified_name, '^[\d.]+','im') :: VARCHAR, '{}') :: NUMERIC AS amount_value,
	NULL AS amount_code,
	TRIM (FROM REGEXP_MATCH (modified_name, '[a-z]+\/','im') :: VARCHAR, '{/}') :: VARCHAR AS amount_name,
	COALESCE(
			TRIM (FROM REGEXP_MATCH (modified_name, '\/[\d.]+','im') :: VARCHAR, '{/}') :: NUMERIC,
			1 ) AS denominator_value,
	NULL AS denominator_code,
	TRIM (FROM REGEXP_MATCH (modified_name, '[a-z]+$','im') :: VARCHAR, '{/}') :: VARCHAR AS denominator_name,
	NULL AS box_size,
	NULL AS total,
	NULL AS unit_1_code,
	NULL AS unit_1_name
FROM vmps_res
WHERE modified_name LIKE '%/%' 

	UNION ALL

--simple amount
SELECT 
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	TRIM (FROM REGEXP_MATCH (modified_name, '^[\d.]+','im') :: VARCHAR, '{}') :: NUMERIC AS amount_value,
	NULL AS amount_code,
	TRIM (FROM REGEXP_MATCH (modified_name, '[a-z]+$','im') :: VARCHAR, '{/}') :: VARCHAR AS denominator_name,
	NULL AS denominator_value,
	NULL AS denominator_code,
	NULL AS denominator_name,
	NULL AS box_size,
	NULL AS total,
	NULL AS unit_1_code,
	NULL AS unit_1_name
FROM vmps_res
WHERE
	modified_name NOT LIKE '%|/%' escape '|' AND
	modified_name NOT LIKE '%|%' escape '|';

UPDATE ds_parsed d SET amount_name = 'gram' WHERE amount_name = 'g';
UPDATE ds_parsed d SET amount_name = TRIM (trailing 's' FROM amount_name) WHERE amount_name LIKE '%s';
UPDATE ds_parsed d SET denominator_name = 'gram' WHERE denominator_name = 'g';
UPDATE ds_parsed d SET denominator_name = TRIM (trailing 's' FROM denominator_name) WHERE denominator_name LIKE '%s';
UPDATE ds_parsed d SET amount_code = (SELECT cd FROM unit_of_measure WHERE d.amount_name = info_desc) WHERE amount_name IS NOT NULL;
UPDATE ds_parsed d SET denominator_code = (SELECT cd FROM unit_of_measure WHERE d.denominator_name = info_desc) WHERE denominator_name IS NOT NULL;

UPDATE ds_parsed d SET --only various Units remain by now
	amount_code = '258666001',
	amount_name = 'unit'
WHERE
	amount_code IS NULL AND
	amount_name IS NOT NULL;

--Table created for manual curation of certain drugs, where doses were picked up from the text
/*DROP TABLE IF EXISTS tomap_vmps_ds_man;
--For manual mapping of missing drug strength
CREATE TABLE tomap_vmps_ds_man AS
SELECT
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	NULL :: NUMERIC AS amount_value,
	NULL :: VARCHAR AS amount_name,
	NULL :: NUMERIC AS denominator_value,
	NULL :: VARCHAR AS denominator_unit
FROM vmps_res
WHERE
	drug_concept_code NOT IN (SELECT drug_concept_code FROM ds_parsed WHERE amount_name IS NOT NULL) AND
	drug_concept_code NOT IN (SELECT drug_concept_code FROM ds_prototype)
	AND drug_concept_name ~* '\d+'
	AND drug_concept_name NOT ilike '%vaccine%'
ORDER BY drug_concept_name, ingredient_concept_name desc;*/

-- proceed with corrections after manual work
DROP TABLE IF EXISTS tomap_vmps_ds;
CREATE TABLE tomap_vmps_ds AS
SELECT * 
FROM tomap_vmps_ds_man;

-- at the moment, they are deleted FROM tomap_vmps_ds
DELETE FROM tomap_vmps_ds WHERE ingredient_concept_code = '0' or (ingredient_concept_code IS NULL AND ingredient_concept_name IS NULL) ;

--Double check: if drug has a parsing already, it is prioritized over manual table
DELETE FROM ds_prototype
WHERE drug_concept_code IN (SELECT drug_concept_code FROM tomap_vmps_ds);

--Double check: Non-existing drugs
DELETE FROM tomap_vmps_ds
WHERE drug_concept_code NOT IN (SELECT concept_code FROM drug_concept_stage WHERE domain_id = 'Drug');

--DELETE from internal_relationship_stage all the relationships with ingredients to recreate it few steps later FROM the manual table (manual table is a priority)
DELETE FROM internal_relationship_stage
WHERE
	concept_code_1 IN (SELECT drug_concept_code FROM tomap_vmps_ds) AND
	concept_code_2 IN (SELECT concept_code FROM drug_concept_stage WHERE concept_class_id = 'Ingredient');

--Filling IN the ds_prototype table from the manual table
INSERT INTO ds_prototype (drug_concept_code, drug_name, ingredient_concept_code, ingredient_name, amount_value,
                          amount_code, amount_name, denominator_value, denominator_code, denominator_name, box_size, total, unit_1_code, unit_1_name)
SELECT
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	amount_value :: NUMERIC,
	NULL :: VARCHAR AS amount_code,
	amount_name,
	denominator_value :: NUMERIC,
	NULL :: VARCHAR AS denominator_code,
	denominator_unit,
	NULL :: INT4,
	NULL :: INT4,
	NULL :: VARCHAR,
	NULL :: VARCHAR
FROM tomap_vmps_ds 
WHERE amount_value IS NOT NULL;

--Working with ds_parsed table
DELETE FROM ds_parsed
WHERE drug_concept_code IN
	(SELECT drug_concept_code FROM tomap_vmps_ds);

INSERT INTO ds_prototype
SELECT *
FROM ds_parsed
WHERE amount_name IS NOT NULL AND drug_concept_code NOT IN (SELECT drug_concept_code FROM ds_prototype);

-- UPDATE ds_prototype with correct codes for units 
UPDATE ds_prototype d
SET amount_code = u.cd
FROM unit_of_measure u
WHERE
  d.amount_name IS NOT NULL
  AND d.amount_name = u.info_desc;
 
UPDATE ds_prototype d
SET denominator_code = u.cd
FROM unit_of_measure u
WHERE
  d.denominator_name IS NOT NULL
  AND d.denominator_name = u.info_desc;
 
--Preparation for ds_stage population
--modify ds_prototype
UPDATE ds_prototype d
SET
  -- amount adjustments
  amount_value = CASE d.amount_code
    WHEN '258770004' THEN d.amount_value * 1000      -- ml ← L
    WHEN '258682000' THEN d.amount_value * 1000      -- mg ← g
    WHEN '258683005' THEN d.amount_value * 1000000   -- mg ← kg
    WHEN '258774008' THEN d.amount_value * 0.001     -- ml ← µL
    ELSE d.amount_value
  END,
  amount_code = CASE d.amount_code
    WHEN '258770004' THEN '258773002'
    WHEN '258682000' THEN '258684004'
    WHEN '258683005' THEN '258684004'
    WHEN '258774008' THEN '258773002'
    ELSE d.amount_code
  END,
  amount_name = CASE d.amount_code
    WHEN '258770004' THEN 'ml'
    WHEN '258682000' THEN 'mg'
    WHEN '258683005' THEN 'mg'
    WHEN '258774008' THEN 'ml'
    ELSE d.amount_name
  END,

  -- denominator adjustments
  denominator_value = CASE d.denominator_code
    WHEN '258770004' THEN d.denominator_value * 1000      -- ml ← L
    WHEN '10693611000001100' THEN d.denominator_value * 0.05  -- ml ← drop
    WHEN '258682000' THEN d.denominator_value * 1000      -- mg ← g
    WHEN '258683005' THEN d.denominator_value * 1000000   -- mg ← kg
    WHEN '258774008' THEN d.denominator_value * 0.001     -- ml ← µL
    ELSE d.denominator_value
  END,
  denominator_code = CASE d.denominator_code
    WHEN '258770004' THEN '258773002'
    WHEN '10693611000001100' THEN '258773002'
    WHEN '258682000' THEN '258684004'
    WHEN '258683005' THEN '258684004'
    WHEN '258774008' THEN '258773002'
    ELSE d.denominator_code
  END,
  denominator_name = CASE d.denominator_code
    WHEN '258770004' THEN 'ml'
    WHEN '10693611000001100' THEN 'ml'
    WHEN '258682000' THEN 'mg'
    WHEN '258683005' THEN 'mg'
    WHEN '258774008' THEN 'ml'
    ELSE d.denominator_name
  END,

  -- total/unit_1 adjustments
  total = CASE d.unit_1_code
    WHEN '258770004' THEN d.total * 1000      -- ml ← L
    WHEN '258682000' THEN d.total * 1000      -- mg ← g
    WHEN '258683005' THEN d.total * 1000000   -- mg ← kg
    WHEN '258774008' THEN d.total * 0.001     -- ml ← µL
    ELSE d.total
  END,
  unit_1_code = CASE d.unit_1_code
    WHEN '258770004' THEN '258773002'
    WHEN '258682000' THEN '258684004'
    WHEN '258683005' THEN '258684004'
    WHEN '258774008' THEN '258773002'
    ELSE d.unit_1_code
  END,
  unit_1_name = CASE d.unit_1_code
    WHEN '258770004' THEN 'ml'
    WHEN '258682000' THEN 'mg'
    WHEN '258683005' THEN 'mg'
    WHEN '258774008' THEN 'ml'
    ELSE d.unit_1_name
  END
WHERE
  d.amount_code       IN ('258770004','258682000','258683005','258774008')
  OR d.denominator_code IN ('258770004','10693611000001100','258682000','258683005','258774008')
  OR d.unit_1_code     IN ('258770004','258682000','258683005','258774008');

--if denominator is 1000 mg (AND total is present AND IN ml), change to 1 ml
UPDATE ds_prototype d
SET --denominator
	denominator_value = 1,
	denominator_code = '258773002',
	denominator_name = 'ml'
WHERE
	d.denominator_code = '258684004' AND
	d.denominator_value = 1000 AND
	d.unit_1_code = '258773002';

--powders, oils etc; remove denominator AND totals
UPDATE ds_prototype d 
SET
	amount_value =
		CASE
			WHEN unit_1_code = amount_code THEN total
			ELSE amount_value
		END,
	denominator_value = NULL,
	denominator_code = NULL,
	denominator_name = NULL,
	total =
		CASE
			WHEN unit_1_code != amount_code THEN total
			ELSE NULL
		END,
	unit_1_code =
		CASE
			WHEN unit_1_code != amount_code THEN unit_1_code
			ELSE NULL
		END,
	unit_1_name =
		CASE
			WHEN unit_1_code != amount_code THEN unit_1_name
			ELSE NULL
		END
WHERE
	amount_value = denominator_value AND
	amount_code = denominator_code;

--respect df_indcd = 2 (continuous)
UPDATE ds_prototype
SET
	(amount_value,amount_code,amount_name) = (NULL,NULL,NULL)
WHERE
	denominator_name IS NULL AND
	(amount_value, amount_name) IN ((1,'mg'),(1000,'mg')) AND
	drug_concept_code IN (SELECT vpid FROM vmps WHERE df_indcd IN ('2','3'));

UPDATE ds_prototype
SET
	denominator_value = NULL
WHERE
	denominator_value = 1 AND
	denominator_name IN ('ml','dose','square cm','mg') AND
	drug_concept_code IN (SELECT vpid FROM vmps WHERE df_indcd IN ('2','3'));

UPDATE ds_prototype
SET
	denominator_value = NULL,
	amount_value = amount_value / 1000
WHERE
	(denominator_value,denominator_name) IN ((1000,'ml'),(1000,'mg')) AND
	drug_concept_code IN (SELECT vpid FROM vmps WHERE df_indcd IN ('2','3'));

UPDATE ds_prototype d
--'1 applicator' IN total fields is redundant
SET
	total = NULL,
	unit_1_code = NULL,
	unit_1_name = NULL
WHERE
	total = 1 AND
	unit_1_code = '732980001';

--if denominator is in mg, ml should NOT be in numerator (mostly oils: 1 ml = 800 mg); --1
--if other numerators are present in mg, all other numerators should be, too --2
WITH has_other_dosage AS (
  -- find all drugs that already have a non-ml dosage record
  SELECT DISTINCT drug_concept_code
  FROM ds_prototype
  WHERE amount_code <> '258773002'
)
UPDATE ds_prototype d
SET
  amount_value = 800 * d.amount_value,
  amount_code  = '258684004',
  amount_name  = 'mg'
FROM has_other_dosage h
WHERE
  d.amount_code = '258773002'     -- only UPDATE those currently IN mL
  AND (
    d.denominator_code = '258684004'  -- CASE 1: denominator is already mg
    OR h.drug_concept_code = d.drug_concept_code  -- CASE 2: drug has another dosage
  );
	
DELETE FROM ds_prototype
WHERE
	(
		LOWER (drug_name) LIKE '%virus%' OR
		LOWER (drug_name) LIKE '%vaccine%' OR
		LOWER (drug_name) LIKE '%antiserum%'
	) AND
	amount_code = '258773002' AND --ml
	denominator_code IS NULL;

--if drug exists as concentration for VMPS, but has total in grams ON VMPP level, convert concentration to MG
UPDATE ds_prototype d
SET
    denominator_code = '258684004',
    denominator_name = 'mg',
    amount_value = d.amount_value / 1000
FROM vmpps vg
LEFT JOIN vmpps vm
  ON vm.vpid = vg.vpid
 AND vm.qty_uomcd = '258773002'  -- has an mL form
WHERE
    d.denominator_value IS NULL
  AND d.denominator_code = '258773002'  -- currently IN mL
  AND d.total IS NULL
  AND d.drug_concept_code = vg.vpid
  AND vg.qty_uomcd = '258682000'  -- has a g form
  AND vm.vpid IS NULL;            -- but no mL form

TRUNCATE ds_stage;
--! Step 9. Populating ds_stage table
--simple numerator only dosage, no denominator
INSERT INTO ds_stage 
WITH excluded_units AS (
  SELECT UNNEST(ARRAY[
    '258774008',  -- µL
    '258773002',  -- mL
    '258770004',  -- L
    '732981002',  -- actuation
    '3317411000001100', -- dose
    '3319711000001103'  -- unit dose
  ]) AS unit_code
)
SELECT DISTINCT
  dp.drug_concept_code,
  dp.ingredient_concept_code,
  dp.amount_value,
  dp.amount_name       AS amount_unit,
  NULL::NUMERIC        AS numerator_value,
  NULL::TEXT           AS numerator_unit,
  NULL::NUMERIC        AS denominator_value,
  NULL::TEXT           AS denominator_unit,
  NULL::INT4           AS box_size
FROM ds_prototype dp
LEFT JOIN excluded_units eu
  ON dp.unit_1_code = eu.unit_code
WHERE
  dp.denominator_code IS NULL
  AND (
    -- 1) unit_1_code is NOT one of the excluded forms (or IS NULL)
    eu.unit_code IS NULL
    -- 2) or numerator equals total IN mL
    OR (
      dp.amount_code = '258773002'  -- mL
      AND dp.amount_value = dp.total
      AND dp.unit_1_code = dp.amount_code
    )
  )
  AND dp.amount_name NOT LIKE '%/%';

--numerator only dosage, but lost denominator
INSERT INTO ds_stage 
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code,
	NULL :: INT4,
	NULL,
	amount_value AS numerator_value,
	amount_name AS numerator_unit,
	total AS denominator_value,
	unit_1_name AS denominator_unit,
	NULL :: NUMERIC
FROM ds_prototype
WHERE
	denominator_code IS NULL AND
	unit_1_code IN --will be IN num/denom instead
		(
			'258774008', --microlitre
			'258773002', --ml
			'258770004', --litre
			'732981002', --actuation
			'3317411000001100', --dose
			'3319711000001103' --unit dose
		)
	AND amount_name NOT LIKE '%/%'
	AND NOT (amount_code = '258773002' AND (amount_value, amount_code) = (total, unit_1_code)); --numerator IN ml, total IN ml, amount equal to total;

--simple numerator+denominator
INSERT INTO ds_stage 
WITH dose_forms(code) AS (
  VALUES
    ('419702001'),  -- patch
    ('733007009'),  -- pessary
    ('733010002'),  -- plaster
    ('3318611000001103'), -- prefilled injection
    ('733013000'),  -- sachet
    ('430293001'),  -- suppository
    ('733021006'),  -- system
    ('3319711000001103'), -- unit dose
    ('415818006'),  -- vial
    ('3318311000001108'), -- pastile
    ('429587008'),  -- lozenge
    ('700476008'),  -- enema
    ('3318711000001107'), -- device
    ('428672001'),  -- bag
    ('732980001'),  -- applicator
    ('3317411000001100'), -- dose
    ('732981002')   -- actuation
)
SELECT DISTINCT
    d.drug_concept_code,
    d.ingredient_concept_code,
    NULL::NUMERIC        AS numerator_value,
    NULL::TEXT           AS numerator_unit,
    d.amount_value,
    d.amount_name        AS amount_unit,
    d.denominator_value,
    d.denominator_name   AS denominator_unit,
    NULL::INT4           AS box_size
FROM ds_prototype d
LEFT JOIN dose_forms df
  ON d.unit_1_code = df.code
WHERE
    d.denominator_code IS NOT NULL
    AND (
      d.unit_1_code IS NULL
      OR (
        df.code IS NOT NULL
        AND d.unit_1_code <> d.denominator_code
        AND d.total = 1
      )
    )
    AND d.amount_name NOT LIKE '%/%';  -- preserve your existing filter if needed

--simple numerator+denominator, total amount provided IN same units AS denominator
INSERT INTO ds_stage 
WITH consistent_drugs AS (
  SELECT
    drug_concept_code
  FROM ds_prototype
  GROUP BY drug_concept_code
  HAVING BOOL_AND(denominator_code = unit_1_code)
)
SELECT DISTINCT
  d.drug_concept_code,
  d.ingredient_concept_code,
  NULL   ::NUMERIC AS numerator_orig_value,
  NULL   ::TEXT    AS numerator_unit,
  (d.amount_value * d.total / d.denominator_value) AS numerator_value,
  d.amount_name,
  d.total           AS denominator_value,
  d.denominator_name,
  NULL   ::INT4     AS box_size
FROM ds_prototype d
JOIN consistent_drugs cd
  ON cd.drug_concept_code = d.drug_concept_code
WHERE
  d.denominator_code = d.unit_1_code;

--AMPs
--Take note that we omit excipients completely and just inherit VMP relations
--if we ever need excipients, we can find them IN AP_INGREDIENT table
INSERT INTO ds_stage
SELECT DISTINCT
	a.apid AS drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
FROM ds_stage d
JOIN amps a ON
	d.drug_concept_code = a.vpid; --this will include packs, both proper components AND monocomponent packs;

--VMPPs
--inherited from VMPs with added box size
DROP TABLE IF EXISTS ds_insert;

CREATE TABLE ds_insert AS --intermediate entry
SELECT DISTINCT
	p.vppid,
	p.nm,
	p.qtyval,
	u.cd AS box_code,
	u.info_desc AS box_name,
	o.*
FROM vmpps p
JOIN UNIT_OF_MEASURE u ON
	p.qty_uomcd = u.cd
JOIN ds_prototype o ON
	o.drug_concept_code = p.vpid;

--replace grams WITH mgs
UPDATE ds_insert d
SET
	qtyval = d.qtyval * 1000,
	box_code = '258684004',
	box_name = 'mg'
WHERE d.box_code = '258682000';

--replace liters WITH mls
UPDATE ds_insert d
SET
	qtyval = d.qtyval * 1000,
	box_code = '258773002',
	box_name = 'ml'
WHERE d.box_code = '258770004';

--any dosage type, nonscalable
INSERT INTO ds_stage 
WITH non_scalable_forms(form_code) AS (
  VALUES
    ('258684004'),  -- mg
    ('258774008'),  -- µL
    ('258773002'),  -- mL
    ('258770004'),  -- L
    ('732981002'),  -- actuation
    ('3317411000001100'), -- dose
    ('3319711000001103')  -- unit dose
)
SELECT DISTINCT
  i.vppid                  AS drug_concept_code,
  d.ingredient_concept_code,
  d.amount_value,
  d.amount_unit,
  d.numerator_value,
  d.numerator_unit,
  d.denominator_value,
  d.denominator_unit,
  COALESCE(i.qtyval, d.box_size) AS box_size
FROM ds_insert i
JOIN ds_stage d
  ON i.drug_concept_code = d.drug_concept_code
LEFT JOIN non_scalable_forms nsf
  ON i.box_code = nsf.form_code
WHERE
  -- exclude any VPPIDs already IN ds_stage
  NOT EXISTS (
    SELECT 1
    FROM ds_stage ds2
    WHERE ds2.drug_concept_code = i.vppid
  )
  AND (
    -- box_code not a non-scalable form
    nsf.form_code IS NULL
    -- or unit dose WITH mL/mg denominator
    OR (
      i.box_code = '3319711000001103'
      AND i.denominator_code IN ('258773002','258684004')
    )
    -- or dose WITH actuation/application denominator
    OR (
      i.box_code = '3317411000001100'
      AND i.denominator_code IN ('732981002','10692211000001108')
    )
  );

-- gives NULL
--simple dosage, same box forms as in VMP or no box form in VMP, scalable
INSERT INTO ds_stage 
WITH scalable_forms(code) AS (
  SELECT UNNEST(ARRAY[
    '258684004',      -- mg
    '258774008',      -- µL
    '258773002',      -- mL
    '258770004',      -- L
    '732981002',      -- actuation
    '3317411000001100', -- dose
    '3319711000001103'  -- unit dose
  ])
),
excluded_drugs AS (
  SELECT DISTINCT drug_concept_code
  FROM ds_stage
)
SELECT DISTINCT
  i.vppid                   AS drug_concept_code,
  d.ingredient_concept_code,
  d.amount_value,
  i.qtyval                  AS amount_unit,
  d.numerator_value,
  d.numerator_unit,
  d.denominator_value,
  d.denominator_unit,
  d.box_size
FROM ds_insert i
-- only “scalable” box_codes
JOIN scalable_forms sf
  ON i.box_code = sf.code
-- must match the same amount_unit in ds_stage
JOIN ds_stage d
  ON i.drug_concept_code = d.drug_concept_code
 AND d.amount_unit       = sf.code
-- exclude any vppid already present AS a drug IN ds_stage
LEFT JOIN excluded_drugs ed
  ON ed.drug_concept_code = i.vppid
WHERE
  -- ensure unit_1_code is either null or equals box_code
  (i.unit_1_code IS NULL OR i.unit_1_code = sf.code)
  -- filter out those already in ds_stage
  AND ed.drug_concept_code IS NULL;

--num/denom dosage, same box forms as in VMP or no box form in VMP, scalable (e.g. solution)
INSERT INTO ds_stage 
WITH scalable_forms(code) AS (
  VALUES
    ('258684004'),      -- mg
    ('258774008'),      -- µL
    ('258773002'),      -- mL
    ('258770004'),      -- L
    ('732981002'),      -- actuation
    ('3317411000001100'), -- dose
    ('3319711000001103')  -- unit dose
),
existing_ds AS (
  SELECT DISTINCT drug_concept_code
  FROM ds_stage
)
SELECT DISTINCT
  i.vppid                              AS drug_concept_code,
  d.ingredient_concept_code,
  d.amount_value,
  d.amount_unit,
  (d.numerator_value * i.qtyval / COALESCE(d.denominator_value, 1))
                                        AS numerator_value,
  d.numerator_unit,
  i.qtyval                             AS denominator_value,
  d.denominator_unit,
  NULL ::INT4                          AS box_size
FROM ds_insert i
JOIN ds_stage d
  ON i.drug_concept_code = d.drug_concept_code
JOIN scalable_forms sf
  ON i.box_code = sf.code
LEFT JOIN existing_ds ed
  ON ed.drug_concept_code = i.vppid
WHERE
  -- only when box and unit_1 align or unit_1 IS NULL
  (i.box_code = i.unit_1_code OR i.unit_1_code IS NULL)
  -- ensure ds_stage has both numerator and denominator units
  AND d.numerator_unit  IS NOT NULL
  AND d.denominator_unit IS NOT NULL
  -- exclude drugs already fully staged
  AND ed.drug_concept_code IS NULL;

INSERT INTO ds_stage
WITH ds_drugs AS (
  SELECT DISTINCT drug_concept_code
  FROM ds_stage
),
to_insert AS (
  -- pick only ds_insert rows for drugs already staged, 
  -- whose vppid is NOT yet staged, WITH non‐null denominator
  SELECT
    d.vppid                       AS drug_concept_code,
    d.ingredient_concept_code,
    d.qtyval,
    d.box_code,
    d.amount_value,
    d.amount_name,
    d.denominator_value,
    d.denominator_name
  FROM ds_insert d
  WHERE
    d.denominator_code IS NOT NULL
    AND EXISTS (
      SELECT 1 
      FROM ds_drugs sd 
      WHERE sd.drug_concept_code = d.drug_concept_code
    )
    AND NOT EXISTS (
      SELECT 1 
      FROM ds_drugs sd2 
      WHERE sd2.drug_concept_code = d.vppid
    )
    AND d.denominator_code = d.box_code
)
SELECT DISTINCT
  ti.drug_concept_code,
  ti.ingredient_concept_code,
  NULL::INT4                   AS col3,
  NULL::VARCHAR                AS col4,
  (ti.amount_value * ti.qtyval / COALESCE(ti.denominator_value,1)) AS numerator_value,
  ti.amount_name              AS numerator_unit,
  ti.qtyval                   AS denominator_value,
  ti.denominator_name         AS denominator_unit,
  NULL::INT4                   AS box_size
FROM to_insert ti;

DROP TABLE if EXISTS valid_ingredients;
-- create temp valid ingredients list 
CREATE TEMP TABLE valid_ingredients AS
SELECT
  i.concept_code_1 AS drug_concept_code,
  i.concept_code_2 AS ingredient_concept_code
FROM internal_relationship_stage i
JOIN drug_concept_stage d2
  ON d2.concept_code = i.concept_code_2
 AND d2.concept_class_id = 'Ingredient'
GROUP BY
  i.concept_code_1,
  i.concept_code_2
HAVING COUNT(*) = 1;

-- delete those which are IN ds already
DELETE FROM valid_ingredients vi
USING ds_stage ds
WHERE vi.drug_concept_code = ds.drug_concept_code;

-- index for quick JOIN
CREATE INDEX idx_valid_ing_drug
  ON valid_ingredients(drug_concept_code);

-- Add VMPP drugs that don't have dosage ON VMP level
INSERT INTO ds_stage
SELECT DISTINCT
  vi.drug_concept_code,
  vi.ingredient_concept_code,
  p.qtyval          AS amount_value,
  u.info_desc       AS amount_unit,
  NULL::INT4        AS col5,
  NULL::VARCHAR     AS col6,
  NULL::INT4        AS col7,
  NULL::VARCHAR     AS col8,
  NULL::INT4        AS col9
FROM valid_ingredients vi
JOIN vmpps p
  ON p.vpid = vi.drug_concept_code
JOIN unit_of_measure u
  ON u.cd = p.qty_uomcd
JOIN drug_concept_stage d2
  ON d2.concept_code = vi.ingredient_concept_code
 AND d2.concept_class_id = 'Ingredient'
JOIN vmps v
  ON v.vpid = vi.drug_concept_code
WHERE
  (
    vi.ingredient_concept_code IN ('387398009','398628008')  -- specific ingredients
    OR d2.concept_name       ILIKE '% oil'
    OR d2.concept_name       ILIKE '% liquid extract'
    OR v.nm                  ILIKE '% powder'
  );
 
INSERT INTO ds_stage
SELECT DISTINCT
    d.vppid                  AS drug_concept_code,
    d.ingredient_concept_code,
     NULL::INT4        AS col5,
  	NULL::VARCHAR     AS col6,
    d.amount_value,
    d.amount_name,
    d.denominator_value,
    d.denominator_name,
    NULL::INT4               AS box_size
FROM ds_insert d
JOIN ds_stage a
  ON d.drug_concept_code = a.drug_concept_code
LEFT JOIN ds_stage b
  ON d.vppid = b.drug_concept_code
WHERE b.drug_concept_code IS NULL
 AND d.amount_value IS NOT NULL
AND d.denominator_value IS NOT NULL;

INSERT INTO ds_stage
SELECT DISTINCT
    d.vppid                  AS drug_concept_code,
    d.ingredient_concept_code,
    d.amount_value,
    d.amount_name,
    NULL::INT4        AS col5,
  	NULL::VARCHAR     AS col6,
    d.denominator_value,
    d.denominator_name,
    NULL::INT4               AS box_size
FROM ds_insert d
JOIN ds_stage a
  ON d.drug_concept_code = a.drug_concept_code
LEFT JOIN ds_stage b
  ON d.vppid = b.drug_concept_code
WHERE b.drug_concept_code IS NULL
 AND d.amount_value IS NOT NULL
AND d.denominator_value IS NULL;

--Doses only ON VMPP level, no VMP entry
WITH counter AS
	(
		SELECT vpid
		FROM virtual_product_ingredient
		GROUP BY vpid
		HAVING count (isid) = 1
	)
INSERT INTO ds_stage
SELECT
	p.vppid AS drug_concept_code,
	COALESCE (r.isidnew,i.isid) AS ingredient_concept_code,
	p.qtyval AS amount_value,
	u.info_desc AS amount_unit,
	NULL :: INT4,
	NULL :: VARCHAR,
	NULL :: INT4,
	NULL :: VARCHAR,
	NULL :: INT4
FROM vmpps p
JOIN virtual_product_ingredient i USING (vpid)
JOIN UNIT_OF_MEASURE u ON u.cd = p.qty_uomcd
JOIN counter o USING (vpid)
LEFT JOIN ingred_replacement r ON r.isidprev = i.isid
LEFT JOIN devices d USING (vpid)
LEFT JOIN ds_stage s ON p.vppid = s.drug_concept_code
LEFT JOIN pc_stage c ON c.pack_concept_code = p.vppid
WHERE
	u.cd IN	(
	'258682000', -- gram
	'258770004', -- litre
	'258773002' -- ml
	) AND
	d.vpid IS NULL AND
	s.drug_concept_code IS NULL AND
	c.pack_concept_code IS NULL;

-- dosed solutions (3319711000001103 unit dose)
INSERT INTO ds_stage
SELECT
	v.vppid,
	d1.ingredient_concept_code,
	d1.amount_value,
	d1.amount_unit,
	d1.numerator_value,
	d1.numerator_unit,
	d1.denominator_value,
	d1.denominator_unit,
	v.qtyval
FROM vmpps v
JOIN ds_stage d1 ON
	v.vpid = d1.drug_concept_code
JOIN drug_concept_stage x ON
	x.concept_code = v.vpid
LEFT JOIN ds_stage d2 ON
	v.vppid = d2.drug_concept_code
WHERE
	d2.drug_concept_code IS NULL AND
	v.qty_uomcd = '3319711000001103';

-- actuations (3317411000001100 dose)
INSERT INTO ds_stage
SELECT
	v.vppid,
	d1.ingredient_concept_code,
	NULL :: INT4 AS amount_value,
	NULL :: VARCHAR AS amount_unit,
	d1.numerator_value * v.qtyval,
	d1.numerator_unit,
	v.qtyval,
	d1.denominator_unit,
	NULL :: INT4
FROM vmpps v
JOIN ds_stage d1 ON
	v.vpid = d1.drug_concept_code
JOIN drug_concept_stage x ON
	x.concept_code = v.vpid
LEFT JOIN ds_stage d2 ON
	v.vppid = d2.drug_concept_code
WHERE
	d2.drug_concept_code IS NULL AND
	v.qty_uomcd = '3317411000001100' AND
	d1.denominator_unit IS NOT NULL;

--inherit AMPPs FROM VMPPs
INSERT INTO ds_stage
SELECT DISTINCT
	a.appid AS drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
FROM ds_stage d
JOIN ampps a ON
	d.drug_concept_code = a.vppid;

--remove denominator values for VMPs AND AMPs WITH df_indcd = 2
UPDATE ds_stage d
SET
	numerator_value = d.numerator_value / d.denominator_value,
	denominator_value = NULL
WHERE
	denominator_unit IS NOT NULL AND
	denominator_value IS NOT NULL AND
	(
	EXISTS
		(
		SELECT
		FROM vmps
		WHERE
			vpid = d.drug_concept_code AND
			df_indcd = '2'
		) OR
	EXISTS
		(
		SELECT
		FROM amps a
		JOIN vmps v ON
			a.vpid = v.vpid
		WHERE
			a.apid = d.drug_concept_code AND
			v.df_indcd = '2'
		));

--udfs is given IN spoonfuls
UPDATE ds_stage d
SET
	numerator_value = d.numerator_value / d.denominator_value,
	denominator_value = NULL
WHERE
	drug_concept_code IN
		(
			SELECT vpid FROM vmps WHERE unit_dose_uomcd IN ('733015007') --spoonful
				UNION ALL
			SELECT apid FROM vmps JOIN amps USING (vpid) WHERE unit_dose_uomcd IN ('733015007') --spoonful
		) AND
	denominator_unit IS NOT NULL AND
	denominator_value IS NOT NULL;

--1-hour patches, 1-actuation inhalers
UPDATE ds_stage d
SET
	denominator_value = NULL,
	box_size = NULL
WHERE
	denominator_value = 1 AND
	denominator_unit IN ('hour', 'dose');

UPDATE ds_stage
SET
	numerator_value =
	CASE
		WHEN box_size > 10 THEN box_size * numerator_value
		ELSE numerator_value
	END,
	denominator_value =
	CASE
		WHEN box_size > 10 THEN box_size
		ELSE NULL
	END,
	box_size = NULL
WHERE
	denominator_unit IN ('application','actuation') AND
	denominator_value = 1;

--split 3511411000001105 Aluminium hydroxide / Magnesium carbonate co-gel
-- --> 3511711000001104 Aluminium hydroxide dried
-- --> 387401007 Magnesium carbonate
DELETE FROM ds_stage --since we don't have exact dosages WHEN we split it
WHERE drug_concept_code IN (SELECT concept_code_1 FROM internal_relationship_stage WHERE concept_code_2 = '3511411000001105'); -- Aluminium hydroxide / Magnesium carbonate co-gel

INSERT INTO internal_relationship_stage
SELECT
	concept_code_1,
	'3511711000001104' -- Aluminium hydroxide dried
FROM internal_relationship_stage
WHERE concept_code_2 = '3511411000001105'; -- Aluminium hydroxide / Magnesium carbonate co-gel

INSERT INTO internal_relationship_stage
SELECT
	concept_code_1,
	'387401007' -- Magnesium carbonate
FROM internal_relationship_stage
WHERE concept_code_2 = '3511411000001105'; -- Aluminium hydroxide / Magnesium carbonate co-gel

DELETE FROM ds_stage d
WHERE ingredient_concept_code IN ('229862008','9832211000001107','24581311000001102','3511411000001105','3577911000001100','4727611000001109','412166009','50213009') --solvents (Syrup, Ether solvent) AND unsplittable ingredients, chloride ion
AND NOT EXISTS --NOT only ingredient
	(
		SELECT x.concept_code_1
		FROM internal_relationship_stage x
		JOIN drug_concept_stage c ON
			c.concept_code = x.concept_code_2 AND
			c.concept_class_id = 'Ingredient'
		WHERE x.concept_code_1 = d.drug_concept_code
		GROUP BY x.concept_code_1
		HAVING count (x.concept_code_2) = 1
	);

DELETE FROM internal_relationship_stage i
WHERE concept_code_2 IN ('229862008','9832211000001107','24581311000001102','3511411000001105','3577911000001100','4727611000001109','412166009','50213009') --solvents (Syrup, Ether solvent) AND unsplittable ingredients, chloride ion
AND NOT EXISTS --NOT only ingredient
	(
		SELECT x.concept_code_1
		FROM internal_relationship_stage x
		JOIN drug_concept_stage c ON
			c.concept_code = x.concept_code_2 AND
			c.concept_class_id = 'Ingredient'
		WHERE x.concept_code_1 = i.concept_code_1
		GROUP BY x.concept_code_1
		HAVING count (x.concept_code_2) = 1
	);

DELETE FROM ds_stage WHERE amount_unit = 'cm'; -- parsing artifact

--replace unit codes WITH names for boiler
UPDATE drug_concept_stage
SET	concept_code = concept_name
WHERE concept_class_id = 'Unit';

--if the ingredient amount is given IN mls, transform to 1000 mg -- unless it's a gas
CREATE OR REPLACE VIEW nongas2fix AS
SELECT DISTINCT ingredient_concept_code
FROM ds_stage
WHERE
	numerator_unit IN ('ml') OR
	amount_unit IN ('ml')

	EXCEPT

SELECT c.concept_code --use SNOMED to find gas descendants
FROM ancestor_snomed a
JOIN concept c ON
	c.concept_id = a.descendant_concept_id
JOIN concept c2 ON
	c2.concept_id = a.ancestor_concept_id AND
	c2.concept_code IN ('74947009','765040008'); --Gases, Inert gases, Gaseous substance

UPDATE ds_stage
SET
	amount_value = amount_value * 1000,
	amount_unit = 'mg'
WHERE
	amount_unit = 'ml' AND
	ingredient_concept_code IN (SELECT ingredient_concept_code FROM nongas2fix);

UPDATE ds_stage
SET
	numerator_value = numerator_value * 1000,
	numerator_unit = 'mg'
WHERE
	numerator_unit = 'ml' AND
	ingredient_concept_code IN (SELECT ingredient_concept_code FROM nongas2fix);

--Remove drugs without or WITH incomplete attributes IN ds_stage attribute 
DELETE FROM ds_stage
WHERE drug_concept_code IN
(SELECT drug_concept_code
	FROM ds_stage
	WHERE COALESCE(amount_value, numerator_value) IS NULL
		-- needs to have at least one value, zeros don't count
		OR COALESCE(amount_unit, numerator_unit) IS NULL
		-- if there is an amount record, there must be a unit
		OR (
			COALESCE(numerator_value, 0) <> 0
			AND COALESCE(numerator_unit, denominator_unit) IS NULL
			));

--reuse only_1_pack to preserve packs WITH only 1 drug AS this exact component
INSERT INTO ds_stage
SELECT DISTINCT
	o.pack_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	NULL :: INT4 AS box_size
FROM ds_stage d
JOIN only_1_pack o ON
	o.drug_concept_code = d.drug_concept_code AND
	o.pack_concept_code NOT IN (SELECT x.drug_concept_code FROM ds_stage x); --orphan concepts may already have had entry despite being a pack (4161311000001109)
	
--replace relations to ingredients IN irs WITH ones FROM ds_stage
DELETE FROM internal_relationship_stage
WHERE
	concept_code_1 IN (SELECT drug_concept_code FROM ds_stage) AND
	concept_code_2 IN (SELECT concept_code FROM drug_concept_stage WHERE concept_class_id = 'Ingredient');

INSERT INTO internal_relationship_stage
SELECT
	drug_concept_code,
	ingredient_concept_code
FROM ds_stage;

--! Step 10. Prepare ingredients to map 
DROP TABLE IF EXISTS tomap_ingredients;

CREATE TABLE tomap_ingredients AS
-- 1) Pre-filter the “source” rows once:
WITH ingredients AS (
  SELECT
    s.concept_code   AS source_code,
    s.concept_name   AS source_name
  FROM drug_concept_stage s
  WHERE s.concept_class_id = 'Ingredient'
    AND s.concept_code NOT IN (SELECT isidprev FROM ingred_replacement)
),
-- 2a) SNOMED→RxNorm mapping (highest precedence = 1)
snomed_map AS (
  SELECT
    i.source_code,
    i.source_name,
    c1.concept_id        AS snomed_id,
    c3.concept_id        AS concept_id,
    c3.concept_name,
    c3.vocabulary_id,
    c3.concept_class_id,
    1                    AS precedence
  FROM ingredients i
  JOIN concept c1
    ON c1.vocabulary_id = 'SNOMED'
   AND c1.concept_code = i.source_code
  JOIN concept_relationship r
    ON r.relationship_id = 'SNOMED - RxNorm eq'
   AND r.invalid_reason IS NULL
   AND r.concept_id_1 = c1.concept_id
  JOIN concept c2
    ON c2.concept_id = r.concept_id_2
   AND c2.concept_class_id != 'Brand Name'
   AND c2.invalid_reason IS NULL
  JOIN concept_relationship r2
    ON r2.relationship_id = 'Form of'
   AND r2.invalid_reason IS NULL
   AND r2.concept_id_1 = c2.concept_id
   AND c2.concept_class_id = 'Precise Ingredient'
  JOIN concept c3
    ON c3.concept_id = r2.concept_id_2
   AND c3.invalid_reason IS NULL
),
-- 2b) Exact‐name mapping (precedence = 2)
exact_name_map AS (
  SELECT
    i.source_code,
    i.source_name,
    null::int8                AS snomed_id,
    cn2.concept_id      AS concept_id,
    cn2.concept_name,
    cn2.vocabulary_id,
    cn2.concept_class_id,
    2                    AS precedence
  FROM ingredients i
  JOIN concept cn2
    ON LOWER(i.source_name) = LOWER(cn2.concept_name)
   AND cn2.standard_concept = 'S'
   AND cn2.vocabulary_id IN ('RxNorm','RxNorm Extension')
   AND cn2.concept_class_id = 'Ingredient'
),
-- 2c) Regex‐stripped mapping (precedence = 3)
regex_map AS (
  SELECT
    i.source_code,
    i.source_name,
    NULL::int8                 AS snomed_id,
    cn.concept_id       AS concept_id,
    cn.concept_name,
    cn.vocabulary_id,
    cn.concept_class_id,
    3                    AS precedence
  FROM ingredients i
  JOIN concept cn
    ON cn.standard_concept = 'S'
   AND cn.vocabulary_id IN ('RxNorm','RxNorm Extension')
   AND cn.concept_class_id  = 'Ingredient'
   AND LOWER(
         REGEXP_REPLACE(
           i.source_name,
           '(^([DL]{1,2}-))|((pollen )?allergen )|( (light|heavy|sodium|anhydrous|dried|solution|distilled|\w*hydrate(d)?|compound|hydrochloride|bromide)$)|"',
           ''
         )
       ) = LOWER(cn.concept_name)
),
-- 3) Search by first name (precence = 4)
regex_map_2 AS (
  SELECT
    i.source_code,
    i.source_name,
    NULL::int8                 AS snomed_id,
    cn.concept_id       AS concept_id,
    cn.concept_name,
    cn.vocabulary_id,
    cn.concept_class_id,
    4                    AS precedence
  FROM ingredients i
  JOIN concept cn
    ON cn.standard_concept = 'S'
   AND cn.vocabulary_id IN ('RxNorm','RxNorm Extension')
   AND cn.concept_class_id  = 'Ingredient'
   AND LOWER(SUBSTRING(i.source_name, '^(\w+)\s')) = LOWER(cn.concept_name)
),
-- 4) UNION all mappings
all_map AS (
  SELECT * FROM snomed_map
  UNION ALL
  SELECT * FROM exact_name_map
  UNION ALL
  SELECT * FROM regex_map
  UNION ALL
  SELECT * FROM regex_map_2
),
-- 5) Pick the best (lowest precedence) per source_code
ranked AS (
  SELECT DISTINCT ON (source_code)
    source_code,
    source_name,
    snomed_id,
    concept_id,
    concept_name,
    vocabulary_id,
    concept_class_id,
    precedence
  FROM all_map
  ORDER BY source_code, precedence
)
-- Final result
SELECT 
r.snomed_id,
i.source_code,
i.source_name,
r.concept_id,
r.concept_name,
r.vocabulary_id,
1 AS precedence,
'ingr_FROM_concept' AS source_attr
FROM ingredients i 
LEFT JOIN ranked r ON i.source_code = r.source_code
ORDER BY i.source_code;

-- use legacy mapping FROM concept
UPDATE tomap_ingredients ti
SET concept_id = cc.concept_id,
precedence = 1
FROM concept c
JOIN concept_relationship cr
  ON cr.concept_id_1   = c.concept_id
  AND cr.relationship_id = 'Maps to'
  AND cr.invalid_reason IS NULL
JOIN concept cc
  ON cc.concept_id     = cr.concept_id_2
  AND cc.standard_concept = 'S'
WHERE
  ti.concept_id IS NULL
  AND c.vocabulary_id = 'dm+d'
  AND ti.source_code  = c.concept_code;
 
 UPDATE tomap_ingredients ti
SET
  concept_id = c2.concept_id,
  precedence = 1
FROM concept c
JOIN concept_relationship cr
  ON cr.concept_id_1 = c.concept_id
  AND cr.relationship_id = 'Maps to'
JOIN concept c2
  ON c2.concept_id     = cr.concept_id_2
  AND c2.standard_concept = 'S'
  AND c2.vocabulary_id   = 'RxNorm'
WHERE
  ti.concept_id IS NULL
  AND c.vocabulary_id = 'SNOMED'
  AND LOWER(c.concept_code) = LOWER(ti.source_code);

/*
DROP TABLE IF EXISTS tomap_ingreds_man;

--Extarct ingredients to map, note VTM shouldn't be mapped
CREATE TABLE tomap_ingreds_man AS
SELECT DISTINCT
	t.source_code,
	t.source_name,
	c.concept_id,
	c.concept_name,
	c.vocabulary_id,
	t.precedence
FROM tomap_ingredients t
LEFT JOIN concept c ON
	c.concept_id = t.concept_id AND
	c.standard_concept = 'S' AND
	c.concept_class_id = 'Ingredient'
WHERE
	t.concept_id IS NULL AND
	t.source_code IN (SELECT concept_code_2 FROM internal_relationship_stage)
*/
 
TRUNCATE relationship_to_concept;
INSERT INTO relationship_to_concept
SELECT DISTINCT
	source_code,
	'dm+d',
	concept_id,
	precedence,
	NULL :: INT4
FROM tomap_ingredients
WHERE
	concept_id IS NOT NULL
AND
	source_code NOT IN (SELECT source_code FROM tomap_ingreds_man) -- man
UNION
SELECT DISTINCT 
tim.source_code,
'dm+d',
tim.concept_id,
tim.precedence,
NULL::int4
FROM tomap_ingreds_man tim -- man
WHERE tim.concept_id IS NOT NULL
;

/*
 -- Extract units to map
 * DROP TABLE IF EXISTS tomap_units_man;

CREATE TABLE tomap_units_man AS
SELECT
	concept_code AS concept_code_1,
	concept_name AS source_name,
	NULL :: INT4 AS concept_id_2,
	NULL :: VARCHAR (255) AS concept_name,
	NULL :: NUMERIC  AS conversion_factor
FROM drug_concept_stage
WHERE concept_class_id = 'Unit' AND
	EXISTS
		(
			SELECT FROM ds_stage
			WHERE
				concept_code = amount_unit OR
				concept_code = numerator_unit OR
				concept_code = denominator_unit
		);
*/

INSERT INTO relationship_to_concept
SELECT
	dcs.concept_name,
	'dm+d' AS vocabulary_id_1,
	concept_id_2,
	1 AS precedence,
	COALESCE (conversion_factor,1)
FROM drug_concept_stage dcs
JOIN tomap_units_man tum--tomap_units_man tum 
	ON dcs.concept_name = tum.source_name 
WHERE dcs.concept_class_id = 'Unit' -- use manual table after check
AND EXISTS
		(
			SELECT FROM ds_stage
			WHERE
				dcs.concept_code = amount_unit OR
				dcs.concept_code = numerator_unit OR
				dcs.concept_code = denominator_unit
		);

/*
-- Extract form to map if need
DROP TABLE IF EXISTS tomap_forms_man
;
CREATE TABLE tomap_forms_man AS
SELECT
	concept_code AS source_code,
	concept_name AS source_name,
	NULL :: INT4 AS mapped_id,
	NULL :: VARCHAR AS mapped_name,
	NULL :: INT4 AS precedence
FROM drug_concept_stage dcs
LEFT JOIN relationship_to_concept rtc ON dcs.concept_code = rtc.concept_code_1
WHERE
	concept_class_id = 'Dose Form'
	 AND rtc.concept_code_1 IS NULL
	 AND dcs.concept_code IN (SELECT DISTINCT concept_code_2 FROM internal_relationship_stage)
;*/

INSERT INTO relationship_to_concept
SELECT DISTINCT 
	dcs.concept_code ,-- dcs.concept_name ,
	'dm+d',
	tfm.concept_id ,-- cc.concept_name ,
	precedence,
NULL::INT4
FROM drug_concept_stage dcs
LEFT JOIN tomap_forms_man tfm ON dcs.concept_code = tfm.source_code
WHERE dcs.concept_class_id = 'Dose Form'
	AND tfm.concept_code IS NOT NULL;

ALTER TABLE ds_stage -- add mapped ingredient's concept_id to aid next step IN dealing WITH duplicates
ADD concept_id INT4;

UPDATE ds_stage
SET concept_id =
	(
		SELECT concept_id_2
		FROM relationship_to_concept
		WHERE
			concept_code_1 = ingredient_concept_code AND
			precedence = 1
	);

--Fix ingredients that got replaced/mapped AS same one (e.g. Sodium ascorbate + Ascorbic acid => Ascorbic acid)
DROP TABLE IF EXISTS ds_split;

CREATE TABLE ds_split AS
SELECT DISTINCT
	drug_concept_code,
	min (ingredient_concept_code :: bigint) over (partition by drug_concept_code, concept_id) :: VARCHAR AS ingredient_concept_code, --one at random
	sum (amount_value) over (partition by drug_concept_code, concept_id) AS amount_value,
	amount_unit,
	sum (numerator_value) over (partition by drug_concept_code, concept_id) AS numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	NULL :: INT4 AS box_size,
	concept_id
FROM ds_stage
WHERE
	(drug_concept_code, concept_id) IN
	(
		SELECT drug_concept_code, concept_id
		FROM ds_stage
		GROUP BY drug_concept_code, concept_id
		HAVING COUNT(*) > 1
	);

DELETE FROM ds_stage
WHERE
	(drug_concept_code, concept_id) IN
	(
		SELECT drug_concept_code, concept_id
		FROM ds_split
	);

INSERT INTO ds_stage
SELECT *
FROM ds_split;

ALTER TABLE ds_stage
DROP COLUMN concept_id;

-- pick one non-null denominator per drug (if multiple exist, take the first arbitrarily)
WITH denom_map AS (
  SELECT DISTINCT ON (drug_concept_code)
    drug_concept_code,
    denominator_value,
    denominator_unit
  FROM ds_stage
  WHERE denominator_unit IS NOT NULL
  ORDER BY drug_concept_code
)
-- if source does NOT give all denominators for all ingredients
UPDATE ds_stage d 
SET
  numerator_value   = d.amount_value,
  numerator_unit    = d.amount_unit,
  amount_value      = NULL,
  amount_unit       = NULL,
  denominator_value = dm.denominator_value,
  denominator_unit  = dm.denominator_unit
FROM denom_map dm
WHERE
  d.drug_concept_code    = dm.drug_concept_code
  AND d.denominator_unit IS NULL;

DELETE FROM internal_relationship_stage -- replace ingredients WITH ones FROM ds_stage (since it was reworked a mano) WHERE applicable
WHERE
	EXISTS (SELECT FROM ds_stage WHERE drug_concept_code = concept_code_1) AND
	EXISTS (SELECT FROM drug_concept_stage WHERE concept_class_id = 'Ingredient' AND concept_code = concept_code_2);

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code
FROM ds_stage;

--1 ml given by source IS NOT always 1 ml IN reality
DROP TABLE IF EXISTS fix_1ml;

CREATE TABLE fix_1ml AS
SELECT vpid
FROM ds_stage, drug_concept_stage, vmps
WHERE
	(denominator_value, denominator_unit) = (1,'ml') AND
	drug_concept_code = concept_code AND
	vpid = drug_concept_code AND
	NOT (concept_name LIKE '%/1ml%' OR concept_name LIKE '% 1ml%') AND
	source_concept_class_id = 'VMP' AND
	((udfs, udfs_uomcd) != (1,'258773002') OR udfs IS NULL);

INSERT INTO fix_1ml
SELECT vppid FROM vmpps, ds_stage
WHERE
	vpid IN (SELECT vpid FROM fix_1ml) AND
	vppid = drug_concept_code AND
	(qtyval, qty_uomcd) != (1,'258773002') AND
	(denominator_value, denominator_unit) = (1,'ml');

INSERT INTO fix_1ml
SELECT apid FROM amps
JOIN fix_1ml USING (vpid);

INSERT INTO fix_1ml
SELECT appid FROM ampps
JOIN fix_1ml ON vpid = vppid;

UPDATE ds_stage
SET
	denominator_value = NULL,
	box_size = NULL
WHERE
	drug_concept_code IN
		(
			SELECT vpid FROM fix_1ml
		);
	
--! Step 11. Find AND map Brand Names, map suppliers
--NOTE: despite that some VMPs AND VMPPs have Brand Names IN their names, we purposefully only build relations FROM AMPs AND AMPPs.
--VMPS are identical to Clinical Drugs by design. They are virtual products that are NOT meant to have Supplier OR a Brand Name
--Also, "Generic %BRAND_NAME%" format is being gradually phased out WITH dm+d UPDATEs
DROP TABLE IF EXISTS amps_to_brands;

CREATE TABLE amps_to_brands
( 
concept_code TEXT, 
concept_name TEXT, 
brand_code TEXT, 
brand_name TEXT, 
mapped_id INT4
);

--finding brand names by name match AND manual work;
DROP TABLE IF EXISTS tofind_brands; 

CREATE TABLE tofind_brands AS
WITH ingred_relat AS
	(
		SELECT i.concept_code_1, i.concept_code_2, d.concept_name
		FROM internal_relationship_stage i
		JOIN drug_concept_stage d ON
			d.concept_class_id = 'Ingredient' AND
			d.concept_code = i.concept_code_2 AND
			i.concept_code_1 IN
				(
					SELECT c1.concept_code
					FROM drug_concept_stage c1
					JOIN internal_relationship_stage ix ON
						ix.concept_code_1 = c1.concept_code
					JOIN drug_concept_stage c2 ON
						c2.concept_class_id = 'Ingredient' AND
						c2.concept_code = ix.concept_code_2
					GROUP BY c1.concept_code
					HAVING count (DISTINCT concept_code_2) = 1
				)
	)
SELECT
	d.concept_code,
	d.concept_name,
	i.concept_code_2,
	i.concept_name AS concept_name_2,
	LENGTH (REGEXP_REPLACE (d.concept_name,' .*$','')) AS min_length
FROM drug_concept_stage d
LEFT JOIN ingred_relat i ON
	i.concept_code_1 = d.concept_code
WHERE
	d.source_concept_class_id = 'AMP' AND
	d.domain_id = 'Drug' AND
	d.concept_code NOT IN (SELECT concept_code FROM amps_to_brands)
	ORDER BY d.concept_code;

--single ingredient, concept is named after ingredient
DELETE FROM tofind_brands 
WHERE concept_name ILIKE REGEXP_REPLACE ((concept_name_2),' .*$', '') || '%';

DELETE FROM tofind_brands
WHERE
	concept_name LIKE 'Vitamin %' OR
	concept_name LIKE 'Arginine %' OR
	concept_name LIKE 'Benzoi%' OR
	REGEXP_MATCH (concept_name,'^([A-Z ]+ [\w.%/]+ (\(.*\) )?\/ )+[A-Z ]+ [\w.%/]+( \(.*\) )? [\w. ]+$','im') IS NOT NULL --listed multiple ingredients AND strengths without a BN
;

DROP TABLE IF EXISTS x_temp;
CREATE INDEX idx_tf_b ON tofind_brands USING GIN ((LOWER(concept_name)) devv5.gin_trgm_ops);
ANALYZE tofind_brands;

DROP TABLE IF EXISTS rx_concept;
CREATE TABLE rx_concept AS
SELECT
	c.concept_id,
	c.concept_name,
	c.vocabulary_id
FROM concept c
WHERE
	c.vocabulary_id IN ('RxNorm', 'RxNorm Extension') AND
	c.concept_class_id = 'Brand Name' AND
	c.invalid_reason IS NULL;

CREATE INDEX IF NOT EXISTS idx_tf_c ON rx_concept USING GIN ((LOWER(concept_name)) devv5.gin_trgm_ops);
ANALYZE rx_concept;

DELETE FROM rx_concept r1
WHERE EXISTS
	(
		SELECT
		FROM rx_concept r2
		WHERE
			LOWER (r1.concept_name) = LOWER (r2.concept_name) AND
			r1.vocabulary_id = 'RxNorm Extension' AND
			(
				r2.vocabulary_id = 'RxNorm' OR --RxE duplicates RxN
				(
					r2.vocabulary_id = 'RxNorm Extension' AND
					r1.concept_id > r2.concept_id
				)
			)
	);
ANALYZE rx_concept;

CREATE UNLOGGED TABLE x_temp AS
SELECT
  b.concept_code,
  b.concept_name,
  c.brand_id,
  c.brand_name,
  c.vocabulary_id,
  LENGTH(c.brand_name)    AS score,
  b.min_length
FROM tofind_brands b
LEFT JOIN LATERAL (
  SELECT
    rx.concept_id   AS brand_id,
    rx.concept_name AS brand_name,
    rx.vocabulary_id
  FROM rx_concept rx
  WHERE
    LOWER(b.concept_name) LIKE LOWER(rx.concept_name) || '%'
    AND LENGTH(rx.concept_name) >= b.min_length
  ORDER BY LENGTH(rx.concept_name) DESC
  LIMIT 1
) c ON TRUE;

--name match;
DROP TABLE IF EXISTS b_temp; 
CREATE TABLE b_temp AS
WITH max_score AS
	(
		SELECT
			concept_code,
			max (score) over (partition by concept_code) AS score
		FROM x_temp x
		WHERE min_length <= score --cut off shorter than first word
	)
SELECT DISTINCT x.concept_code, x.concept_name, x.brand_id, x.brand_name
FROM x_temp x
JOIN max_score m USING (concept_code, score);

--found
DELETE FROM tofind_brands 
WHERE concept_code IN (SELECT concept_code FROM b_temp);

WITH brand_extract AS
	(
		SELECT DISTINCT s.brand_code, b.brand_name
		FROM b_temp b
		LEFT JOIN amps_to_brands s USING (brand_name)
	),
brands_assigned AS --assign OMOP codes
	(
		SELECT
			brand_name,
			COALESCE (brand_code, 'OMOP' || nextval ('new_seq')) AS brand_code
		FROM brand_extract
	)
INSERT INTO amps_to_brands
SELECT
	b.concept_code,
	b.concept_name,
	a.brand_code,
	b.brand_name
FROM b_temp b
JOIN brands_assigned a USING (brand_name)
--Only for drugs without brands already
WHERE b.concept_code NOT IN (
    SELECT concept_code FROM amps_to_brands
    WHERE brand_code IS NOT NULL
    );

DELETE FROM tofind_brands --found
WHERE concept_code IN (SELECT concept_code FROM amps_to_brands);

/*
-- Extract to find brands manually
DROP TABLE IF EXISTS tofind_brands_man;
CREATE TABLE tofind_brands_man AS
SELECT
	tb.concept_code,
	tb.concept_name,
	NULL :: INT4 AS brand_id,
	TRIM (REGEXP_REPLACE (tb.concept_name, ' .*$','')) :: VARCHAR AS brand_name,
	NULL :: INT4 AS ind_to_create
FROM tofind_brands tb
LEFT JOIN concept c ON LOWER(c.concept_name) ilike '%'||TRIM (REGEXP_REPLACE (tb.concept_name, ' .*$',''))||'%' 
AND c.concept_class_id = 'Ingredient' 
AND c.vocabulary_id like 'Rx%'
WHERE c.concept_id IS NULL
ORDER BY tb.concept_name
;*/

--assign codes to manually found brands
INSERT INTO amps_to_brands 
WITH man_brands AS
	(
		SELECT DISTINCT t.brand_id AS brand_code, t.brand_name
		FROM tofind_brands_man t -- man
		JOIN tofind_brands s ON TRIM (REGEXP_REPLACE (s.concept_name, ' .*$','')) = t.brand_name
		WHERE t.ind_to_create IS NOT NULL
	),
brand_codes AS
	(
		SELECT
			COALESCE (brand_code::TEXT, 'OMOP' || nextval ('new_seq')) AS brand_code, --prevent duplicating by reusing codes
			brand_name
		FROM man_brands
	)
SELECT
	t.concept_code,
	t.concept_name,
	o.brand_code,
	t.brand_name
FROM tofind_brands_man t
JOIN brand_codes o ON LOWER (o.brand_name) = LOWER (t.brand_name)
UNION
SELECT concept_code, concept_name, brand_id::text, brand_name
FROM tofind_brands_man
WHERE brand_id IS NOT NULL
;

WITH missing_brand_amps AS (
SELECT DISTINCT dcs.concept_code, dcs.concept_name
FROM drug_concept_stage dcs 
LEFT JOIN amps_to_brands atb 
	ON atb.concept_code = dcs.concept_code 
WHERE atb.concept_code IS NULL
	AND dcs.source_concept_class_id IN ('AMP')
	AND dcs.concept_class_id != 'Device'
)
INSERT INTO amps_to_brands
SELECT DISTINCT mba.concept_code,mba.concept_name, ccc.concept_code , ccc.concept_name, ccc.concept_id
FROM missing_brand_amps mba
LEFT JOIN concept c 
	ON c.concept_code = mba.concept_code
	AND c.vocabulary_id = 'dm+d'
LEFT JOIN concept_relationship cr 
	ON cr.concept_id_1 = c.concept_id 
	AND cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
LEFT JOIN concept cc 
	ON cc.concept_id = cr.concept_id_2 
LEFT JOIN concept_relationship cr1
	ON cr1.concept_id_1 = cc.concept_id 
	AND cr1.relationship_id = 'Has brand name'
	AND cr1.invalid_reason IS NULL
LEFT JOIN concept ccc
	ON ccc.concept_id = cr1.concept_id_2 
	AND ccc.invalid_reason IS NULL
WHERE ccc.concept_id IS NOT NULL
ORDER BY mba.concept_code
;

INSERT INTO drug_concept_stage
(
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
)
--Brand Names
SELECT DISTINCT
	brand_name AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Brand Name' AS concept_class_id,
	NULL AS standard_concept,
	COALESCE(c.concept_code, brand_code) AS concept_code,
	TO_DATE('1970-01-01','YYYY-MM-DD') valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	'Brand Name'
FROM amps_to_brands atb
LEFT JOIN concept c 
ON c.concept_id::TEXT = atb.brand_code;

DROP TABLE IF EXISTS brand_replace;

CREATE TABLE brand_replace AS
--brand names FROM different sources may have the same name, replace WITH the smallest code
--NUMERIC SNOMED codes are therefore preferred over OMOP codes (string comparisment rules)
SELECT DISTINCT
	concept_code,
	min (concept_code) over (partition by concept_name) AS true_code
FROM drug_concept_stage
WHERE concept_class_id = 'Brand Name';

DELETE FROM brand_replace
WHERE true_code = concept_code;

DELETE FROM drug_concept_stage
WHERE concept_code IN (SELECT concept_code FROM brand_replace);

--AMPs to Brand Names
INSERT INTO internal_relationship_stage
SELECT DISTINCT
	s.concept_code,
	COALESCE (r.true_code, s.brand_code)
FROM amps_to_brands s
LEFT JOIN brand_replace r ON
	s.brand_code = r.concept_code;

--AMPPS to Brand Names
INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.appid,
	COALESCE (r.true_code, b.brand_code)
FROM amps_to_brands b
JOIN ampps a ON
	a.apid = b.concept_code
LEFT JOIN brand_replace r ON
	b.brand_code = r.concept_code;

DROP TABLE IF EXISTS tomap_bn;

--Mapping BNs
CREATE TABLE tomap_bn AS
WITH preex_m AS
	(
		SELECT DISTINCT --previously obtained name match
			c.concept_code,
			b.brand_name as concept_name,
			b.brand_id as mapped_id,
			b.brand_name as mapped_name
		FROM b_temp b
		JOIN drug_concept_stage c ON
			b.brand_name = c.concept_name AND
			c.concept_class_id = 'Brand Name' AND
			c.invalid_reason IS NULL
			
			UNION 
			
		SELECT DISTINCT --obtained name match
			c.concept_code,
			b.brand_name,
			b.mapped_id,
			b.brand_name
		FROM amps_to_brands b
		JOIN drug_concept_stage c ON
			b.brand_name = c.concept_name AND
			c.concept_class_id = 'Brand Name' AND
			c.invalid_reason IS NULL
			AND b.mapped_id IS NOT NULL
	)
SELECT DISTINCT
	s.concept_code,
	s.concept_name,
	m.mapped_id,
	m.mapped_name
FROM drug_concept_stage s
LEFT JOIN preex_m m USING (concept_code, concept_name)
WHERE s.concept_class_id = 'Brand Name';

UPDATE tomap_bn t1 --small pattern fix
--Name1 = Name2 + ' XL'
SET
	(mapped_id, mapped_name) =
	(
		SELECT t2.mapped_id, t2.mapped_name
		FROM tomap_bn t2
		WHERE
			t1.concept_name = t2.concept_name || ' XL' AND
			t2.mapped_id IS NOT NULL
	)
WHERE t1.mapped_id IS NULL;

UPDATE tomap_bn t1 --small pattern fix
--Name1 = Name2 + ' XL'
SET
	(mapped_id, mapped_name) =
	(
		SELECT c.concept_id, c.concept_name
		FROM concept c
		WHERE
			t1.concept_name = c.concept_name || ' XL' AND
			c.concept_class_id = 'Brand Name' AND
			c.invalid_reason IS NULL AND
			c.vocabulary_id IN ('RxNorm')
	)
WHERE
	t1.mapped_id IS NULL AND
	t1.concept_name LIKE '% XL';

/*
-- Extract brand name to map
DROP TABLE IF EXISTS tomap_bn_man;

CREATE TABLE tomap_bn_man AS
SELECT 
	t.concept_code,
	t.concept_name,
	c.concept_id AS mapped_id,
    c.concept_code AS target_concept_code,
	c.concept_name AS mapped_name,
    c.concept_class_id AS concept_class_id,
    c.standard_concept AS standard_concept,
    c.invalid_reason AS invalid_reason,
    c.domain_id,
	c.vocabulary_id
FROM tomap_bn t
LEFT JOIN concept c ON
	LOWER (t.concept_name) LIKE LOWER (c.concept_name) || ' %' AND -- this match will have to be checked manually
	c.concept_class_id = 'Brand Name' AND
	c.invalid_reason IS NULL AND
	c.vocabulary_id LIKE 'RxN%'
WHERE
	t.mapped_id IS NULL 
	AND t.concept_code IN (SELECT concept_code_2 FROM internal_relationship_stage)
	; 

ALTER TABLE tomap_bn_man
ALTER COLUMN invalid_reason TYPE VARCHAR(50);

ALTER TABLE tomap_bn_man
ALTER COLUMN standard_concept TYPE VARCHAR(50);
*/ 

INSERT INTO relationship_to_concept
SELECT DISTINCT
	c.concept_code,
	'dm+d',
	mapped_id,
	1,
	NULL :: NUMERIC
FROM tomap_bn t
JOIN drug_concept_stage c ON
	c.concept_name = t.concept_name AND
	c.concept_class_id = 'Brand Name'
WHERE t.mapped_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM tomap_bn_man tbm
WHERE t.concept_code = tbm.concept_code)
UNION 
SELECT DISTINCT
	c.concept_code,
	'dm+d',
	mapped_id,
	1,
	NULL :: NUMERIC
FROM tomap_bn_man tbm
JOIN drug_concept_stage c ON
	lower(c.concept_name) = lower(tbm.concept_name) AND
	c.concept_class_id = 'Brand Name'
WHERE tbm.mapped_id IS NOT NULL;

-- Work with suppliers
-- Following queries prepare table which should be review to decide create or not new Suppliers in RxE
DROP TABLE IF EXISTS tomap_supplier_man;

CREATE TABLE tomap_supplier_man AS
SELECT d.concept_code, d.concept_name,
    c.concept_code AS target_concept_code,
    c.concept_id AS mapped_id,
	c.concept_name AS mapped_name,
    c.concept_class_id AS concept_class_id,
    c.standard_concept AS standard_concept,
    c.invalid_reason AS invalid_reason,
    c.domain_id,
	c.vocabulary_id,
    NULL::INT AS precedence
FROM drug_concept_stage d
LEFT JOIN concept c ON
	c.concept_class_id = 'Supplier' AND
	c.vocabulary_id = 'RxNorm Extension' AND
	c.invalid_reason IS NULL AND
	REGEXP_REPLACE (LOWER (c.concept_name),'\W','') = REGEXP_REPLACE (LOWER (d.concept_name),'\W','')
WHERE
	d.concept_class_id = 'Supplier' AND
	d.concept_code IN (SELECT concept_code_2 FROM internal_relationship_stage)
ORDER BY LENGTH (d.concept_name);

ALTER TABLE tomap_supplier_man
ALTER COLUMN invalid_reason TYPE VARCHAR(50);

ALTER TABLE tomap_supplier_man
ALTER COLUMN standard_concept TYPE VARCHAR(50);

UPDATE drug_concept_stage --replace cut name WITH source-given one
SET concept_name = (SELECT name_old FROM supplier WHERE cd = concept_code)
WHERE concept_class_id = 'Supplier';

--UPDATE obvious misses (simplifies refresh)
UPDATE tomap_supplier_man s
SET concept_name = (SELECT d.concept_name FROM drug_concept_stage d WHERE d.concept_code = s.concept_code AND d.concept_class_id = 'Supplier')
WHERE s.concept_code IN (SELECT concept_code FROM drug_concept_stage);

UPDATE tomap_supplier_man b
SET
  mapped_id   = c.concept_id,
  mapped_name = c.concept_name
FROM concept c
WHERE
  b.mapped_id IS NULL
  AND c.vocabulary_id    = 'RxNorm Extension'
  AND c.concept_class_id = 'Supplier'
  AND c.invalid_reason IS NULL
  AND LOWER(c.concept_name) = LOWER(b.concept_name);

 UPDATE tomap_supplier_man tsm
SET
  mapped_id   = cc.concept_id,
  mapped_name = cc.concept_name
 FROM concept c 
 JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Source - RxNorm eq'
 JOIN concept cc ON cc.concept_id = cr.concept_id_2 AND cc.invalid_reason IS NULL
 WHERE mapped_id IS NULL
AND c.concept_code = tsm.concept_code 
AND c.vocabulary_id = 'dm+d';

--At this stage extract suppliers to recheck and map if need
/*
DROP TABLE tomap_supplier_man_mapping;

CREATE TABLE tomap_supplier_man_mapping AS 
SELECT * FROM tomap_supplier_man 
WHERE mapped_id IS NULL;
*/

-- update mapped suppliers
UPDATE tomap_supplier_man tsm
SET mapped_id = tsm25.mapped_id
FROM tomap_supplier_man_mapping tsm25 --manual table
WHERE
  tsm.mapped_id IS NULL
  AND tsm.concept_code = tsm25.concept_code;

INSERT INTO relationship_to_concept
SELECT DISTINCT 
	concept_code,
	'dm+d',
	mapped_id::INT4,
	precedence AS precedence,
	NULL :: INT4 AS conversion_factor
FROM tomap_supplier_man
WHERE mapped_id IS NOT NULL;

ANALYZE relationship_to_concept;
ANALYZE internal_relationship_stage;

--some drugs IN IRS have duplicating ingredient entries over relationship_to_concept mappings
WITH multiing AS
	(
		SELECT i.concept_code_1, r.concept_id_2, min (i.concept_code_2) AS preserve_this
		FROM internal_relationship_stage i
		JOIN relationship_to_concept r ON
			COALESCE (r.precedence,1) = 1 AND --only precedential mappings matter
			i.concept_code_2 = r.concept_code_1
		GROUP BY i.concept_code_1, concept_id_2
		HAVING count (i.concept_code_2) > 1
	)
DELETE FROM internal_relationship_stage r
WHERE
	(r.concept_code_1, r.concept_code_2) IN
		(
			SELECT a.concept_code_1, b.concept_code_1
			FROM multiing a
			JOIN relationship_to_concept b ON
				a.concept_id_2 = b.concept_id_2 AND
				a.preserve_this != b.concept_code_1
		);

--OMOP replacement: existing OMOP codes AND shift sequence to after last code IN concept
DROP TABLE IF EXISTS code_replace;

CREATE TABLE code_replace AS
SELECT DISTINCT 
	d.concept_code AS old_code,
	COALESCE(c.concept_code,cc.concept_code) AS new_code
FROM drug_concept_stage d
LEFT JOIN concept c ON
	c.vocabulary_id = d.vocabulary_id AND
	--c.invalid_reason IS NULL AND
	c.concept_name = d.concept_name AND
	c.concept_class_id = d.concept_class_id AND
	c.concept_code NOT like 'OMOP%'
LEFT JOIN concept cc ON
	cc.vocabulary_id = d.vocabulary_id AND
	--c.invalid_reason IS NULL AND
	cc.concept_name = d.concept_name AND
	cc.concept_class_id = d.concept_class_id AND
	cc.concept_code like 'OMOP%'
WHERE d.concept_code LIKE 'OMOP%';

DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::INT4)+1 into ex FROM devv5.concept WHERE concept_code LIKE 'OMOP%'  AND concept_code NOT LIKE '% %';
	DROP SEQUENCE IF EXISTS new_vocab;
	EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END $$;

UPDATE code_replace
SET	new_code = 'OMOP' || nextval('new_vocab')
WHERE new_code IS NULL;

UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;

UPDATE relationship_to_concept a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE ds_stage a
SET ingredient_concept_code = b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code;

UPDATE ds_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_2 = b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code;

UPDATE pc_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

--Inherit AMP, VMPP AND AMPP ingredient relations for empty ds_stage entries
INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.apid,
	x.concept_code
FROM internal_relationship_stage d
JOIN amps a ON
	a.vpid = d.concept_code_1
JOIN drug_concept_stage x ON
	x.concept_class_id IN ('Ingredient') AND
	x.concept_code = d.concept_code_2
LEFT JOIN ds_stage s ON
	a.apid = s.drug_concept_code
WHERE s.drug_concept_code IS NULL;

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.vppid,
	x.concept_code
FROM internal_relationship_stage d
JOIN vmpps a ON
	a.vpid = d.concept_code_1
JOIN drug_concept_stage x ON
	x.concept_class_id IN ('Ingredient') AND
	x.concept_code = d.concept_code_2
LEFT JOIN ds_stage s ON
	a.vppid = s.drug_concept_code
WHERE s.drug_concept_code IS NULL;

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.appid,
	x.concept_code
FROM internal_relationship_stage d
JOIN ampps a ON
	a.apid = d.concept_code_1
JOIN drug_concept_stage x ON
	x.concept_class_id IN ('Ingredient') AND
	x.concept_code = d.concept_code_2
LEFT JOIN ds_stage s ON
	a.appid = s.drug_concept_code
WHERE s.drug_concept_code IS NULL;

--Inherit AMP, VMPP AND AMPP Dose Form relations for empty ds_stage entries
INSERT INTO internal_relationship_stage --amp
SELECT DISTINCT
	a.apid,
	x.concept_code
FROM internal_relationship_stage d
JOIN amps a ON
	a.vpid = d.concept_code_1
JOIN drug_concept_stage x ON
	x.concept_class_id = 'Dose Form' AND
	x.concept_code = d.concept_code_2;

INSERT INTO internal_relationship_stage --vmpp
SELECT DISTINCT
	a.vppid,
	x.concept_code
FROM internal_relationship_stage d
LEFT JOIN only_1_pack o ON
	d.concept_code_1 = o.drug_concept_code
JOIN vmpps a ON
	a.vpid = COALESCE (o.pack_concept_code,d.concept_code_1)
JOIN drug_concept_stage x ON
	x.concept_class_id = 'Dose Form' AND
	x.concept_code = d.concept_code_2
WHERE
	NOT EXISTS
		(
			SELECT
			FROM internal_relationship_stage i
			JOIN drug_concept_stage c ON
				i.concept_code_2 = c.concept_code
			WHERE
				c.concept_class_id = 'Dose Form'
		);

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.appid,
	x.concept_code
FROM internal_relationship_stage d
LEFT JOIN only_1_pack o ON
	d.concept_code_1 = o.drug_concept_code
JOIN ampps a ON
	a.apid = COALESCE (o.pack_concept_code,d.concept_code_1)
JOIN drug_concept_stage x ON
	x.concept_class_id = 'Dose Form' AND
	x.concept_code = d.concept_code_2
WHERE
	NOT EXISTS
		(
			SELECT
			FROM internal_relationship_stage i
			JOIN drug_concept_stage c ON
				i.concept_code_2 = c.concept_code
			WHERE
				c.concept_class_id = 'Dose Form'
		);

--ensure correctness of monopacks
DELETE FROM internal_relationship_stage WHERE concept_code_1 IN (SELECT pack_concept_code FROM only_1_pack);

INSERT INTO internal_relationship_stage
SELECT
	pack_concept_code,
	concept_code_2
FROM internal_relationship_stage
JOIN only_1_pack ON
	drug_concept_code = concept_code_1;

--Deduplication of internal_relationship_stage
DELETE FROM internal_relationship_stage s 
WHERE EXISTS (SELECT 1 FROM internal_relationship_stage s_int 
                WHERE COALESCE(s_int.concept_code_1, 'x') = COALESCE(s.concept_code_1, 'x')
                  AND COALESCE(s_int.concept_code_2, 'x') = COALESCE(s.concept_code_2, 'x')
                  AND s_int.ctid > s.ctid);

--optional: remove unused concepts
DELETE FROM drug_concept_stage
WHERE
	concept_class_id IN ('Unit') AND
	concept_name NOT IN
		(
			SELECT DISTINCT amount_unit FROM ds_stage WHERE amount_unit IS NOT NULL
				UNION ALL
			SELECT DISTINCT numerator_unit FROM ds_stage WHERE numerator_unit IS NOT NULL
				UNION ALL
			SELECT DISTINCT denominator_unit FROM ds_stage WHERE denominator_unit IS NOT NULL
		);

UPDATE ds_stage
SET box_size = NULL
WHERE
	denominator_unit IS NOT NULL AND
	--(box_size = 1 OR denominator_value IS NULL)
	denominator_value IS NULL;

--Deduplication of relationship_to_concept
DELETE FROM relationship_to_concept s 
WHERE EXISTS (SELECT 1 FROM relationship_to_concept s_int 
                WHERE COALESCE(s_int.concept_code_1, 'x') = COALESCE(s.concept_code_1, 'x')
                  AND COALESCE(s_int.vocabulary_id_1, 'x') = COALESCE(s.vocabulary_id_1, 'x')
                  AND COALESCE(s_int.concept_id_2, 1) = COALESCE(s.concept_id_2, 1)
                  AND COALESCE(s_int.precedence, 1) = COALESCE(s.precedence, 1)
                  AND COALESCE(s_int.conversion_factor, 1) = COALESCE(s.conversion_factor, 1)
                  AND s_int.ctid > s.ctid);

--Deduplication of drug_concept_stage
DELETE FROM drug_concept_stage s 
WHERE EXISTS (SELECT 1 FROM drug_concept_stage s_int 
                WHERE COALESCE(s_int.concept_name, 'x') = COALESCE(s.concept_name, 'x')
                  AND COALESCE(s_int.vocabulary_id, 'x') = COALESCE(s.vocabulary_id, 'x')
                  AND COALESCE(s_int.concept_class_id, 'x') = COALESCE(s.concept_class_id, 'x')
                  AND COALESCE(s_int.source_concept_class_id, 'x') = COALESCE(s.source_concept_class_id, 'x')
                  AND COALESCE(s_int.standard_concept, 'x') = COALESCE(s.standard_concept, 'x')
                  AND COALESCE(s_int.concept_code, 'x') = COALESCE(s.concept_code, 'x')
                  AND COALESCE(s_int.possible_excipient, 'x') = COALESCE(s.possible_excipient, 'x')
                  AND COALESCE(s_int.domain_id, 'x') = COALESCE(s.domain_id, 'x')
                  AND COALESCE(s_int.valid_start_date) = COALESCE(s.valid_start_date)
                  AND COALESCE(s_int.valid_end_date) = COALESCE(s.valid_end_date)
                  AND COALESCE(s_int.invalid_reason, 'x') = COALESCE(s.invalid_reason, 'x')
                  AND s_int.ctid > s.ctid);

--get supplier relations for packs
INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.appid,
	i.concept_code_2
FROM ampps a
JOIN internal_relationship_stage i ON
	a.apid = i.concept_code_1
JOIN pc_stage p ON
	p.pack_concept_code = a.appid
JOIN drug_concept_stage d ON
	d.concept_code = i.concept_code_2 AND
	d.concept_class_id = 'Supplier'
JOIN drug_concept_stage d1 ON
	d1.concept_code = a.appid AND
	d1.domain_id = 'Drug' AND
	d1.source_concept_class_id = 'AMPP';

--marketed products must have either pc_stage OR ds_stage entry
DELETE FROM internal_relationship_stage irs
WHERE EXISTS (
    SELECT 1
    FROM drug_concept_stage dcs
    WHERE dcs.concept_class_id = 'Supplier'
      AND dcs.concept_code = irs.concept_code_2
)
AND NOT EXISTS (
    SELECT 1
    FROM (
        SELECT drug_concept_code AS code FROM ds_stage
        UNION ALL
        SELECT pack_concept_code AS code FROM pc_stage
    ) AS codes
    WHERE codes.code = irs.concept_code_1
);

--Replaces 'Powder' dose form with more specific forms, guessing FROM name WHERE possible
DROP TABLE IF EXISTS vmps_chain;
CREATE TABLE vmps_chain AS
SELECT DISTINCT
	v.vpid, v.vppid, a.apid, a.appid,
	CASE
		WHEN
			d1.concept_name ILIKE '%oral powder%' OR
			d1.concept_name ILIKE '%sugar%'
		THEN '14945811000001105' --effervescent powder
		WHEN d1.concept_name ILIKE '%topical%'
		THEN '385108009' --cutaneous solution
		WHEN d1.concept_name ILIKE '%endotrach%'
		THEN '11377411000001104' --Powder AND solvent for solution for instillation
		WHEN d1.concept_name ILIKE '% ear %'
		THEN '385136004' --ear drops
		ELSE '85581007' --Powder
	END AS concept_code_2
FROM vmpps v
JOIN ampps a USING (vppid)
JOIN internal_relationship_stage i ON
	v.vpid = i.concept_code_1 AND
	i.concept_code_2 = '85581007' --Powder
JOIN drug_concept_stage d1 ON
	d1.concept_code = i.concept_code_1;

UPDATE internal_relationship_stage i
SET concept_code_2 = (SELECT DISTINCT concept_code_2 FROM vmps_chain WHERE i.concept_code_1 IN (vpid, apid, appid, vppid))
WHERE concept_code_2 = '85581007'; --Powder;

DROP TABLE IF EXISTS amps_chain;
--AMP's have licensed route; some are defining
CREATE TABLE amps_chain AS
SELECT DISTINCT
	a.apid,
	a.appid,
	CASE routecd
		WHEN '26643006' THEN '14945811000001105' --oral powder
		WHEN '6064005' THEN '385108009' --cutaneous solution
		ELSE '85581007' --Powder
	END AS concept_code_2
FROM vmps_chain a
JOIN licensed_route l USING (apid)
WHERE
	a.concept_code_2 = '85581007' AND
	l.apid IN
		(
			SELECT apid
			FROM licensed_route
			WHERE routecd != '3594011000001102'
			GROUP BY apid
			HAVING count (routecd) = 1
		);

UPDATE internal_relationship_stage i
SET concept_code_2 = (SELECT DISTINCT concept_code_2 FROM amps_chain WHERE i.concept_code_1 IN (apid, appid))
WHERE
	concept_code_2 = '85581007' AND --Powder
	EXISTS
		(
			SELECT
			FROM amps_chain
			WHERE concept_code_1 IN (apid,appid)
		);

--same WITH Liquid
DROP TABLE IF EXISTS vmps_chain;
CREATE TABLE vmps_chain AS
SELECT DISTINCT
	v.vpid, v.vppid, a.apid, a.appid,
	CASE
		WHEN
			d1.concept_name ILIKE '% oral%' OR
			d1.concept_name ILIKE '%sugar%' OR
			d1.concept_name ILIKE '% dental%' OR
			d1.concept_name ILIKE '% tincture%' OR
			d1.concept_name ILIKE '% mixture%' OR
			d1.concept_name ILIKE '%oromucos%' OR
			d1.concept_name ILIKE '% elixir%'
		THEN '385023001' --oral solution
		WHEN
			d1.concept_name ILIKE '% instil%' OR
			d1.concept_name ILIKE '%periton%' OR
			d1.concept_name ILIKE '%cardiop%' OR
			d1.concept_name ILIKE '%tracheopul%' OR
			d1.concept_name ILIKE '%extraamn%' OR
			d1.concept_name ILIKE '%smallpox%'
		THEN '385219001' --injectable solution
		WHEN
			d1.concept_name ILIKE '% lotion%' OR
			d1.concept_name ILIKE '% acetone%' OR
			d1.concept_name ILIKE '% scalp%' OR
			d1.concept_name ILIKE '% topical%' OR
			d1.concept_name ILIKE '% skin%' OR
			d1.concept_name ILIKE '% massage%' OR
			d1.concept_name ILIKE '% shower%' OR
			d1.concept_name ILIKE '% rubb%' OR
			d1.concept_name ILIKE '%spirit%'
		THEN '385108009' --cutaneous solution
		WHEN d1.concept_name ILIKE '% vagin%'
		THEN '385166006' --vaginal gel
		WHEN
			d1.concept_name ILIKE '%nasal%' OR
			d1.concept_name ILIKE '%nebul%'
		THEN '385197005' --nebuliser liquid
		ELSE '420699003'
	END AS concept_code_2
FROM vmpps v
JOIN ampps a USING (vppid)
JOIN internal_relationship_stage i ON
	v.vpid = i.concept_code_1 AND
	i.concept_code_2 = '420699003' --Liquid
JOIN drug_concept_stage d1 ON
	d1.concept_code = i.concept_code_1;

UPDATE internal_relationship_stage i
SET concept_code_2 = (SELECT DISTINCT concept_code_2 FROM vmps_chain WHERE i.concept_code_1 IN (vpid, apid, appid, vppid))
WHERE concept_code_2 = '420699003'; --Liquid

DROP TABLE IF EXISTS amps_chain;

CREATE TABLE amps_chain AS
SELECT DISTINCT
	a.apid,
	a.appid,
	CASE routecd
		WHEN '18679011000001101' THEN '385197005' --Nebulizer liquid
		WHEN '26643006' THEN '385023001' --oral solution
		WHEN '372449004' THEN '385023001' --oral solution
		WHEN '58100008' THEN '385219001' --injectable solution
		WHEN '6064005' THEN '385108009' --cutaneous
		ELSE '420699003'
	END AS concept_code_2
FROM vmps_chain a
JOIN licensed_route l USING (apid)
WHERE 
	a.concept_code_2 = '420699003' AND
	l.apid IN 
		(
			SELECT apid 
			FROM licensed_route 
			WHERE routecd != '3594011000001102'
			GROUP BY apid
			HAVING count (routecd) = 1
		);

UPDATE internal_relationship_stage i
SET concept_code_2 = (SELECT DISTINCT concept_code_2 FROM amps_chain WHERE i.concept_code_1 IN (apid, appid))
WHERE 
	concept_code_2 = '420699003' AND --Liquid
	EXISTS
		(
			SELECT
			FROM amps_chain
			WHERE concept_code_1 IN (apid,appid)
		);

--! Step 12. More fixes and shifting OMOP codes to follow sequence IN CONCEPT table
DELETE FROM internal_relationship_stage ir
USING drug_concept_stage dcs
WHERE
  ir.concept_code_1 = dcs.concept_code
  AND dcs.domain_id = 'Device';
 
UPDATE ds_stage 
SET amount_value = NULL
WHERE amount_value IS NOT NULL
AND numerator_value IS NOT NULL;

-- 1) Identify all but one row per duplicate concept_code:
WITH dup AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY concept_code
      ORDER BY concept_name  -- keep the “first” by name; adjust order as needed
    ) AS rn
  FROM drug_concept_stage
)
-- 2) delete every row where rn > 1, i.e. the true duplicates
DELETE FROM drug_concept_stage d
USING dup
WHERE d.ctid = dup.ctid
  AND dup.rn > 1;

DELETE  
FROM ds_stage
WHERE denominator_unit NOT IN (
			SELECT concept_code_1
			FROM relationship_to_concept
			)
		OR numerator_unit NOT IN (
			SELECT concept_code_1
			FROM relationship_to_concept
			)
		OR amount_unit NOT IN (
			SELECT concept_code_1
			FROM relationship_to_concept
			);

INSERT INTO ds_stage		
SELECT a.apid,
ingredient_concept_code,amount_value,amount_unit,numerator_value,numerator_unit,denominator_value,denominator_unit,box_size
FROM amps a
JOIN ds_stage ds ON a.vpid = ds.drug_concept_code 
WHERE a.apid NOT IN (			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Ingredient');
			
INSERT INTO internal_relationship_stage 
SELECT DISTINCT a.apid, concept_code_2
FROM amps a 
JOIN internal_relationship_stage irs ON a.vpid = irs.concept_code_1 
WHERE a.apid NOT IN (			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Ingredient');
INSERT INTO ds_stage		
SELECT a.appid,
ingredient_concept_code,amount_value,amount_unit,numerator_value,numerator_unit,denominator_value,denominator_unit,box_size
FROM ampps a
JOIN ds_stage ds ON a.apid = ds.drug_concept_code 
WHERE a.appid NOT IN (			
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Ingredient');	
			
INSERT INTO internal_relationship_stage 
SELECT DISTINCT a.appid, concept_code_2
FROM ampps a 
JOIN internal_relationship_stage irs ON a.apid = irs.concept_code_1 
WHERE a.appid NOT IN (			
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Ingredient');			

WITH duplicates AS (
  SELECT ctid
  FROM (
    SELECT
      ctid,
      ROW_NUMBER() OVER (
        PARTITION BY concept_code_1, concept_code_2
        ORDER BY ctid
      ) AS rn
    FROM internal_relationship_stage
  ) t
  WHERE t.rn > 1
)
DELETE FROM internal_relationship_stage t
USING duplicates d
WHERE t.ctid = d.ctid;

WITH duplicates AS (
  SELECT ctid
  FROM (
    SELECT
      ctid,
      ROW_NUMBER() OVER (
        PARTITION BY
          drug_concept_code,
          ingredient_concept_code,
          amount_value,
          amount_unit,
          numerator_value,
          numerator_unit,
          denominator_value,
          denominator_unit,
          box_size
        ORDER BY ctid
      ) AS rn
    FROM ds_stage
  ) sub
  WHERE sub.rn > 1
)
DELETE FROM ds_stage d
USING duplicates dup
WHERE d.ctid = dup.ctid;

--Remove relationships to attributes for concepts, processed manually
DELETE FROM ds_stage ds WHERE exists (SELECT 1 FROM concept_relationship_manual crm where crm.concept_code_1 = ds.drug_concept_code and crm.vocabulary_id_1 = 'dm+d');
DELETE FROM internal_relationship_stage irs WHERE exists (SELECT 1 FROM concept_relationship_manual crm where (crm.concept_code_1 = irs.concept_code_1 and crm.vocabulary_id_1 = 'dm+d') or (crm.concept_code_1 = irs.concept_code_2 and crm.vocabulary_id_1 = 'dm+d'));
DELETE FROM pc_stage ps WHERE exists (SELECT 1 FROM concept_relationship_manual crm where crm.concept_code_1 = ps.pack_concept_code and crm.vocabulary_id_1 = 'dm+d');
DELETE FROM relationship_to_concept rtc WHERE exists (SELECT 1 FROM concept_relationship_manual crm where crm.concept_code_1 = rtc.concept_code_1 and crm.vocabulary_id_1 = 'dm+d');

-- Some manual fixes for some drugs inc. vaccine
DELETE FROM drug_concept_stage dcs
WHERE
  dcs.source_concept_class_id IN ('Dose Form', 'Brand Name')
  AND NOT EXISTS (
    SELECT 1
    FROM internal_relationship_stage ir
    WHERE ir.concept_code_2 = dcs.concept_code
  );

DELETE FROM internal_relationship_stage irs
WHERE concept_code_2 IN (
SELECT concept_code_1 
FROM relationship_to_concept rtc 
JOIN drug_concept_stage dcs
on dcs.concept_code = rtc.concept_code_1
WHERE rtc.concept_id_2 = 0
AND dcs.concept_class_id in ('Dose Form','Ingredient')); 
 
DELETE FROM internal_relationship_stage irs1 
WHERE NOT EXISTS (
SELECT 1
FROM internal_relationship_stage irs 
JOIN drug_concept_stage dcs 
ON dcs.concept_code = irs.concept_code_2 
AND dcs.concept_class_id = 'Ingredient'
WHERE irs1.concept_code_1 = irs.concept_code_1);

DELETE FROM ds_stage ds
WHERE NOT EXISTS (SELECT 1
FROM internal_relationship_stage irs 
JOIN drug_concept_stage dcs 
ON dcs.concept_code = irs.concept_code_2 
AND dcs.concept_class_id = 'Ingredient'
WHERE ds.drug_concept_code = irs.concept_code_1);

DELETE FROM relationship_to_concept rtc
WHERE concept_id_2 = 0
AND EXISTS (
SELECT 1 
FROM drug_concept_stage dcs 
WHERE dcs.concept_code = rtc.concept_code_1 
AND dcs.concept_class_id = 'Ingredient');

--Changing column types as they should be for BuildRxE
ALTER TABLE relationship_to_concept ALTER COLUMN conversion_factor TYPE NUMERIC;
ALTER TABLE relationship_to_concept ALTER COLUMN precedence TYPE smallint;
ALTER TABLE pc_stage ALTER COLUMN amount TYPE smallint;
ALTER TABLE pc_stage ALTER COLUMN box_size TYPE smallint;
ALTER TABLE ds_stage ALTER COLUMN amount_value TYPE NUMERIC;
ALTER TABLE ds_stage ALTER COLUMN numerator_value TYPE NUMERIC;
ALTER TABLE ds_stage ALTER COLUMN denominator_value TYPE NUMERIC;
ALTER TABLE ds_stage ALTER COLUMN box_size TYPE smallint;
--At this point, everything should be prepared for BuildRxE run
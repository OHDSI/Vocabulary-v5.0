--! Step 0. Schema preparation, creation of necessary tables
--Working with basic AND stage tables
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

--Pull ancestors data FROM non-standard SNOMED concept relations
--needed because of existing non-standard Substances in SNOMED vocabulary
DROP TABLE IF EXISTS ancestor_snomed CASCADE;

CREATE TABLE ancestor_snomed AS
WITH RECURSIVE hierarchy_concepts (ancestor_concept_id,descendant_concept_id,root_ancestor_concept_id,levels_of_separation,full_path) AS
  (
        SELECT
            ancestor_concept_id, descendant_concept_id, ancestor_concept_id as root_ancestor_concept_id,
            levels_of_separation, ARRAY [descendant_concept_id] AS full_path
        FROM concepts

        UNION ALL

        SELECT
            c.ancestor_concept_id, c.descendant_concept_id, root_ancestor_concept_id,
            hc.levels_of_separation + c.levels_of_separation AS levels_of_separation,
            hc.full_path || c.descendant_concept_id as full_path
        FROM concepts c
        JOIN hierarchy_concepts hc on hc.descendant_concept_id = c.ancestor_concept_id
        WHERE c.descendant_concept_id <> ALL (full_path)
    ),

    concepts AS (
        SELECT
            r.concept_id_1 AS ancestor_concept_id,
            r.concept_id_2 AS descendant_concept_id,
            CASE WHEN s.is_hierarchical = 1 AND c1.invalid_reason IS NULL THEN 1 ELSE 0 END AS levels_of_separation
        FROM concept_relationship r
        JOIN relationship s on s.relationship_id = r.relationship_id AND s.defines_ancestry = 1
        JOIN concept c1 on c1.concept_id = r.concept_id_1 AND c1.invalid_reason IS NULL AND c1.vocabulary_id = 'SNOMED'
        JOIN concept c2 on c2.concept_id = r.concept_id_2 AND c2.invalid_reason IS NULL AND c2.vocabulary_id = 'SNOMED'
        WHERE r.invalid_reason IS NULL
        --Do not use module relationships due to minor inconsistency in this relationships
        AND r.relationship_id NOT IN ('Has Module', 'Module of')
    )

    SELECT
        hc.root_ancestor_concept_id AS ancestor_concept_id,
        hc.descendant_concept_id,
        min(hc.levels_of_separation) AS min_levels_of_separation,
        max(hc.levels_of_separation) AS max_levels_of_separation
    FROM hierarchy_concepts hc
    JOIN concept c1 on c1.concept_id = hc.root_ancestor_concept_id AND c1.invalid_reason IS NULL
    JOIN concept c2 on c2.concept_id = hc.descendant_concept_id AND c2.invalid_reason IS NULL
    GROUP BY hc.root_ancestor_concept_id, hc.descendant_concept_id

	UNION

SELECT c.concept_id AS ancestor_concept_id,
	c.concept_id AS descendant_concept_id,
	0 AS min_levels_of_separation,
	0 AS max_levels_of_separation
FROM concept c
WHERE
	c.vocabulary_id = 'SNOMED' AND
	--EXISTS (SELECT 1 FROM sources.mrconso m WHERE c.concept_code = m.code AND m.sab = 'SNOMEDCT_US') AND
	c.invalid_reason IS NULL
;

--Adding constraints AND indexes to snomed ancestor
ALTER TABLE ancestor_snomed ADD CONSTRAINT xpkancestor_snomed PRIMARY KEY (ancestor_concept_id,descendant_concept_id);
CREATE INDEX idx_sna_descendant on ancestor_snomed (descendant_concept_id);
CREATE INDEX idx_sna_ancestor on ancestor_snomed (ancestor_concept_id);
ANALYZE ancestor_snomed;

--As a result, ancestor_snomed is prepared for future use


--! Step 1. Extract meaningful data FROM XML source. Manual fix to source data discrepancies
--TODO: use NHS's own tool to create CSV tables FROM XML
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

--TODO: May be used in future

CREATE TABLE dmd2atc AS
SELECT unnest(xpath('/VMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('/VMP/ATC/text()', i.xmlfield))::VARCHAR ATC
FROM (
	SELECT unnest(xpath('/BNF_DETAILS/VMPS/VMP', i.xmlfield)) xmlfield
	FROM sources.dmdbonus i
	) AS i
;

/*
--TODO: May be used in future
CREATE TABLE dmd2bnf AS
	(
		SELECT unnest(xpath('/VMP/VPID/text()', i.xmlfield))::VARCHAR DMD_ID,
			unnest(xpath('/VMP/BNF/text()', i.xmlfield))::VARCHAR BNF,
			'VMP' as concept_class_id
		FROM (
			SELECT unnest(xpath('/BNF_DETAILS/VMPS/VMP', i.xmlfield)) xmlfield
			FROM sources.dmdbonus i
			) AS i

			UNION ALL

		SELECT unnest(xpath('/AMP/VPID/text()', i.xmlfield))::VARCHAR DMD_ID,
			unnest(xpath('/AMP/BNF/text()', i.xmlfield))::VARCHAR BNF,
			'AMP' as concept_class_id
		FROM (
			SELECT unnest(xpath('/BNF_DETAILS/AMPS/AMP', i.xmlfield)) xmlfield
			FROM sources.dmdbonus i
			) AS i
	);
 */


--TODO: May be used in future
/*
DELETE FROM comb_content_a
WHERE prntappid in
(
	SELECT prntappid FROM comb_content_a
	GROUP BY prntappid
	HAVING count (chldappid) = 1
)
;
DELETE FROM comb_content_v
WHERE prntvppid in
(
	SELECT prntvppid FROM comb_content_v
	GROUP BY prntvppid
	HAVING count (chldvppid) = 1
)*/

--Creating indexes
CREATE INDEX idx_vmps on vmps (lower (nm) varchar_pattern_ops);
CREATE INDEX idx_vmps_vpid on vmps (vpid);
CREATE INDEX idx_amps_vpid on amps (vpid);
CREATE INDEX idx_vpi_vpid on virtual_product_ingredient (vpid);
CREATE INDEX idx_vmps_nm on vmps (nm varchar_pattern_ops);
CREATE INDEX idx_amps_nm on amps (nm varchar_pattern_ops);
ANALYZE amps;
ANALYZE vmps;
ANALYZE ampps;
ANALYZE vmpps;
ANALYZE virtual_product_ingredient;



--! Step 2. Separating devices
DROP TABLE IF EXISTS devices;
--TODO: improve devices detection using ancestor_snomed

CREATE TABLE devices AS
WITH offenders1 AS
	(
		SELECT DISTINCT nm, apid, vpid
		FROM amps
		WHERE lic_authcd IN ('0000','0003')
	)

SELECT DISTINCT o.apid, o.nm AS nm_a, o.vpid, v.nm AS nm_v, 'any domain, no ing' AS reason --any domain, no ingredient
FROM offenders1 o
JOIN vmps v ON
	v.vpid = o.vpid
LEFT JOIN virtual_product_ingredient i
	ON v.vpid = i.vpid
WHERE
	i.vpid IS NULL
  AND v.nm NOT ILIKE '%covid%'

	AND
	(
		(v.nm NOT LIKE '%tablets'
		AND v.nm NOT ILIKE '%covid%'
		AND lower (v.nm) NOT LIKE '%fish oil%'
		AND v.nm NOT LIKE '%capsules'
		AND v.nm NOT ILIKE '%vaccine%'
		AND lower (v.nm) NOT LIKE '%ferric%'
		AND lower (v.nm) NOT LIKE '%antivenom%'
		AND lower (v.nm) NOT LIKE '%immunoglobulin%'
		AND lower (v.nm) NOT LIKE '%lactobacillis%'
		AND lower (v.nm) NOT LIKE '%hydrochloric acid%'
		AND lower (v.nm) NOT LIKE '%herbal liquid%'
		AND lower (v.nm) NOT LIKE '%pollinex%'
		AND lower (v.nm) NOT LIKE '%black currant syrup%'
		and lower (v.nm) not like '%vaccine%')
		OR v.nm LIKE '% oil %'
	);

ANALYZE devices;

--known device domain, ingredients NOT IN whitelist (Drug according to RxNorm rules)
INSERT INTO devices
WITH ingred_whitelist AS materialized
	(
		SELECT v.vpid
		FROM vmps v
		JOIN virtual_product_ingredient i on
			i.vpid = v.vpid
		JOIN concept c on
			c.vocabulary_id = 'SNOMED' AND
			c.concept_code = i.isid
		JOIN ancestor_snomed a on
			a.descendant_concept_id = c.concept_id
		JOIN concept c2 on
			c2.concept_id = a.ancestor_concept_id AND
			c2.concept_code IN
				(
					'350107007','418407000', --Cellulose-derived viscosity modifier // eyedrops
					'4320669' -- Sodium hyaluronate
				)
	)

SELECT a.apid, a.nm as nm_a, a.vpid, v.nm as nm_v, 'device domain, not whitelisted'
FROM amps a
JOIN vmps v on
	v.vpid = a.vpid
LEFT JOIN ingred_whitelist i on
	i.vpid = v.vpid
WHERE
	lic_authcd = '0002' AND NOT
	v.nm ~* '(ringer|hyal|carmellose|synov|drops|sodium chloride 0)' AND
	i.vpid IS NULL AND

	NOT exists --there are no AMPs with same VMP relations that differ in license
		(
			SELECT
			FROM amps x
			WHERE
				x.vpid = a.vpid AND
				x.lic_authcd != '0002'
		)
;

--known device domain, ingredient NOT IN whitelist (Drug according to RxNorm rules)
INSERT INTO devices
SELECT a.apid, a.nm as nm_a, a.vpid, v.nm as nm_v, 'device domain, not whitelisted'
FROM amps a
JOIN vmps v on
	v.vpid = a.vpid
WHERE
	lic_authcd = '0002' AND
	(lower (v.nm) LIKE '% kit') AND
NOT exists --there are no AMPs with same VMP relations that differ in license
		(
			SELECT
			FROM amps x
			WHERE
				x.vpid = a.vpid AND
				x.lic_authcd != '0002'
		)
;

--unknown domain, known 'device' ingredient
INSERT INTO devices
WITH offenders1 AS
	(
		SELECT DISTINCT nm, apid, vpid
		FROM amps
		WHERE lic_authcd IN ('0000','0003')
	)
SELECT DISTINCT o.apid, o.nm AS nm_a, o.vpid, v.nm AS nm_v, 'no domain, bad ing'
FROM offenders1 o
JOIN vmps v on
	v.vpid = o.vpid
JOIN virtual_product_ingredient i
	ON v.vpid = i.vpid
JOIN ingredient_substances s
	ON s.isid = i.isid
WHERE s.isid in
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
	'5215311000001103'	--Soft soap
);

--any domain, known 'device' ingredient
INSERT INTO devices
SELECT DISTINCT a.apid, a.nm as nm_a, a.vpid, s.nm as nm_v, 'any domain, bad ing'
FROM ancestor_snomed ca
JOIN concept c on
	ca.descendant_concept_id = c.concept_id AND
	c.vocabulary_id = 'SNOMED'
JOIN ingredient_substances i on i.isid = c.concept_code
JOIN virtual_product_ingredient v on v.isid = i.isid
JOIN vmps s on s.vpid = v.vpid
JOIN amps a on a.vpid = v.vpid
JOIN concept d on
	d.concept_id = ca.ancestor_concept_id AND
	d.concept_code in
	(
		'407935004','385420005', --Contrast Media
		'767234009', --Gadolinium (salt) -- also contrast
		'255922001', --Dental material
		'764087006',	--Product containing genetically modified T-cell
		'89457008',	--Radioactive isotope
		'37521911000001102', --Radium-223
		'420884001',	--Human mesenchymal stem cell
		'39248411000001101' -- Sodium iodide [I-131]
	);

--indication defines domain (regex)
INSERT INTO devices
SELECT DISTINCT a.apid, a.nm, v.vpid, v.nm, 'indication defines domain (regex)'
FROM vmps v
JOIN amps a on
	a.vpid = v.vpid
WHERE
	lower (v.nm) LIKE '%dialys%' OR
	lower (v.nm) LIKE '%haemofiltration%' OR
	lower (v.nm) LIKE '%sunscreen%' OR
	lower (v.nm) LIKE '%supplement%' OR
	lower (v.nm) LIKE '%food%' OR
	lower (v.nm) LIKE '%nutri%' OR
	lower (v.nm) LIKE '%oliclino%' OR
	lower (v.nm) LIKE '%synthamin%' OR
	lower (v.nm) LIKE '%kabiven%' OR
	lower (v.nm) LIKE '%electrolyt%' OR
	lower (v.nm) LIKE '%ehydration%' OR
	lower (v.nm) LIKE '%vamin 9%' OR
	lower (v.nm) LIKE '%intrafusin%' OR
	lower (v.nm) LIKE '%vaminolact%' OR
	lower (v.nm) LIKE '% glamin %' OR
	lower (v.nm) LIKE '%ehydration%' OR
	lower (v.nm) LIKE '%hyperamine%' OR
	lower (v.nm) LIKE '%primene %' OR
	lower (v.nm) LIKE '%clinimix%' OR
	lower (v.nm) LIKE '%aminoven%' OR
	lower (v.nm) LIKE '%plasma-lyte%' OR
	lower (v.nm) LIKE '%tetraspan%' OR
	lower (v.nm) LIKE '%tetrastarch%' OR
	lower (v.nm) LIKE '%triomel%' OR
	lower (v.nm) LIKE '%aminoplasmal%' OR
	lower (v.nm) LIKE '%compleven%' OR
	lower (v.nm) LIKE '%potabl%' OR
	lower (v.nm) LIKE '%forceval protein%' OR
	lower (v.nm) LIKE '%ethyl chlorid%' OR
	lower (v.nm) LIKE '%alcoderm%' OR
	lower (v.nm) LIKE '%balsamicum%' OR
	lower (v.nm) LIKE '%diprobase%' OR
	lower (v.nm) LIKE '%diluent%oral%' OR
	lower (v.nm) LIKE '%empty%' OR
	lower (v.nm) LIKE '%dual pack vials%' OR
	lower (v.nm) LIKE '%biscuit%' OR
	lower (v.nm) LIKE '% vamin 14 %' OR
	lower (v.nm) LIKE '%perflutren%' OR
	lower (v.nm) LIKE '%ornith%aspart%' OR
	lower (a.nm) LIKE '%hepa%merz%' OR
	lower (a.nm) LIKE '%gallium citrate%' OR
    lower (a.nm) LIKE '%lymphoseek%' OR
	lower (v.nm) LIKE '%kbq%' OR
	lower (v.nm) LIKE '%ether solvent%' OR
	lower (v.nm) = 'herbal liquid' OR
	lower (v.nm) LIKE 'toiletries %' OR
	lower (v.nm) LIKE 'artificial%' OR
	lower (v.nm) LIKE '% wipes' OR
	lower (v.nm) LIKE 'purified %' OR
	lower (a.nm) LIKE 'phlexy%' OR
	lower (v.nm) LIKE '%lymphoseek%' OR
	lower (a.nm) LIKE '%kryptoscan%' OR
	lower (v.nm) LIKE '%mbq%' OR
	lower (v.nm) LIKE '%gbq%' OR
	lower (v.nm) LIKE '%radium%223%' OR
    lower (v.nm) LIKE '%mo-99%' OR
	lower (v.nm) LIKE '%catheter%' OR
	lower (v.nm) LIKE '%radiopharm%' OR
    lower (v.nm) LIKE '%radionuclide generator%' OR
    lower(v.nm) LIKE '%gluten free bread%' OR
    lower(v.nm) LIKE '%cardioplegia%' OR
    lower(v.nm) LIKE '%gadodiamide%' OR
    lower(v.nm) LIKE '%catheter maintenance%' OR
    lower(v.nm) LIKE '%artificial%' OR
    lower(v.nm) LIKE '%industrial%' OR
    lower(v.nm) LIKE '%urea c13%'
;

--homeopathic products are not worth analyzing if source does not provide ingredients
INSERT INTO devices
SELECT
	a.apid,
	a.nm,
	v.vpid,
	v.nm,
	'homeopathy with no ingredient' as reason
FROM vmps v
JOIN amps a USING (vpid)
WHERE
	v.vpid NOT IN (SELECT vpid FROM virtual_product_ingredient) AND
	(
		lower (v.nm) LIKE '%homeop%' OR
		lower (v.nm) LIKE '%doron %' OR
		lower (v.nm) LIKE '%fragador%' OR
		lower (v.nmprev) LIKE '%homeop%' OR
		lower (v.nm) LIKE '%h+c%'
	);

--saline eyedrops
INSERT INTO devices
SELECT
	a.apid,
	a.nm,
	v.vpid,
	v.nm,
	'saline eyedrops' as reason
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
WHERE
	vpid IN
		(
			SELECT c.concept_code
			FROM ancestor_snomed
			JOIN concept c on
				vocabulary_id = 'SNOMED' AND
				descendant_concept_id = c.concept_id AND
				ancestor_concept_id IN
					(
						35622427,	--Genetically modified T-cell product
						4222664, --Product containing industrial methylated spirit
						36694441, --Sodium chloride 0.9% catheter maintenance solution pre-filled syringes
						35626947 --NHS dm+d appliance
					)
			AND c.domain_id = 'Device'
		);

-- if at least one vmp per amp is a drug, treat everything as drug
WITH x AS
	(
		SELECT vpid, count (DISTINCT apid) AS c1
		FROM devices
		GROUP BY vpid
	),
a_p_v AS
	(
		SELECT vpid, count (apid) AS c2
		FROM amps
		GROUP BY vpid
	)
DELETE FROM devices
WHERE vpid IN
	(
		SELECT vpid
		FROM x
		JOIN a_p_v USING (vpid)
		WHERE c2 != c1
	);

--Form indicates domain
INSERT INTO devices
SELECT
	a.apid,
	a.nm,
	v.vpid,
	v.nm,
	'Form indicates device domain' AS reason
FROM vmps v
JOIN amps a USING (vpid)
JOIN drug_form d ON
	d.vpid = v.vpid AND
	formcd IN
		(
			'419202002' -- {Bone} cement
		)
;

ANALYZE devices;


--! Step 3. Fix bugs in source (dosages in wrong units, missing denominators, inconsistent dosage of ingredients etc)
--Attributed to all tables
UPDATE virtual_product_ingredient
SET strnt_nmrtr_uomcd = '258684004' --mg instead of ml when obviously wrong
WHERE
	(strnt_nmrtr_uomcd,strnt_dnmtr_uomcd) IN
	(
		('258682000','258682000'),
		('258773002','258773002'),
		('258682000','258773002'),
		('258773002','258682000')
	) AND
	strnt_nmrtr_val > strnt_dnmtr_val;

DELETE FROM virtual_product_ingredient --duplicates or excipients
WHERE
	(
		vpid = '3701211000001107' AND
		isid = '422082008'
	) OR
	(
		vpid IN ('8967511000001107','8967611000001106','17995411000001108')
	) OR
	(
		vpid = '326186007' AND
		isid = '77370004'
	);

UPDATE virtual_product_ingredient
   SET strnt_nmrtr_uomcd = '258684004'
WHERE vpid = '19697911000001103';

UPDATE virtual_product_ingredient
SET strnt_nmrtr_val = strnt_nmrtr_val / 17
WHERE vpid = '10050811000001105';

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val / 10,
	strnt_dnmtr_val = strnt_dnmtr_val / 10
WHERE vpid IN ('35750411000001102', '322823002', '4792911000001109');

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 5,
	strnt_dnmtr_val = strnt_dnmtr_val * 5
WHERE vpid IN ('34821011000001106','3628211000001102');

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 133,
	strnt_dnmtr_val = strnt_dnmtr_val * 133
WHERE vpid IN ('3788711000001106');

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 10,
	strnt_dnmtr_val = strnt_dnmtr_val * 10
WHERE vpid IN ('9062611000001102');

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 15,
	strnt_dnmtr_val = strnt_dnmtr_val * 15
WHERE vpid IN ('14204311000001108');

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 25,
	strnt_dnmtr_val = strnt_dnmtr_val * 25
WHERE vpid IN ('4694211000001102');

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = strnt_nmrtr_val * 4,
	strnt_dnmtr_val = strnt_dnmtr_val * 4
WHERE vpid IN ('14252411000001103');

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = 30 * strnt_nmrtr_val,
	strnt_dnmtr_val = 30 * strnt_dnmtr_val
WHERE vpid IN ('15125211000001101','15125111000001107','16665111000001100');

UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 5,
       strnt_dnmtr_uomcd = '258682000'
WHERE vpid = '9186611000001108';

UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 0.004
WHERE vpid = '19693411000001104'
AND   isid = '387293003';

UPDATE vmps
   SET udfs = 500
WHERE vpid = '18146511000001104';

UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 1,
       strnt_dnmtr_uomcd = '3317411000001100'
WHERE vpid = '3776211000001106';

UPDATE virtual_product_ingredient
SET strnt_nmrtr_val = strnt_nmrtr_val / 1000
WHERE vpid = '8034511000001103';

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_uomcd = '258684004',
	strnt_nmrtr_val = '1500'
WHERE
	vpid = '24129011000001102' AND
	isid = '4284011000001105';

UPDATE virtual_product_ingredient
SET	strnt_nmrtr_val = '500'
WHERE
	vpid = '32961211000001109';

INSERT INTO virtual_product_ingredient
VALUES ('4171411000001108','70288006',NULL,'100.0','258684004',NULL,NULL);

UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 4000,
       strnt_nmrtr_uomcd = '258684004',
       strnt_dnmtr_val = NULL,
       strnt_dnmtr_uomcd = NULL
WHERE vpid = '16603411000001107'
AND   isid = '27192005';

UPDATE virtual_product_ingredient
SET
	strnt_dnmtr_val = '1000',
	strnt_dnmtr_uomcd = '258773002'
WHERE vpid IN ('14611111000001108','9097011000001109','9096611000001104','9097111000001105');

UPDATE virtual_product_ingredient
SET
	strnt_dnmtr_val = '1000',
	strnt_dnmtr_uomcd = '258684004'
WHERE vpid IN ('3864211000001105','4977811000001100','7902811000001102','425136005','3818211000001103');

UPDATE virtual_product_ingredient
SET
	strnt_dnmtr_val = '1000',
	strnt_dnmtr_uomcd = '258682000'
WHERE vpid IN ('18411011000001106');

DELETE FROM virtual_product_ingredient WHERE vpid = '4210011000001101' AND strnt_nmrtr_val IS NULL;

UPDATE virtual_product_ingredient
SET strnt_dnmtr_uomcd = '258773002'
WHERE vpid IN ('13532011000001103','10727111000001103','31363111000001105','13532111000001102','332745002');

UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 1,
       strnt_dnmtr_uomcd = '258773002'
WHERE vpid IN ('35776311000001109','10050811000001105');

UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 20,
       strnt_dnmtr_val = 1,
       strnt_dnmtr_uomcd = '258773002'
WHERE vpid = '36017611000001109'
AND   isid = '387206004';

--if vmpp total amount is in ml, change denominator to ml
UPDATE virtual_product_ingredient
SET strnt_dnmtr_uomcd = '258773002'
WHERE vpid IN
	(
		SELECT i.vpid
			FROM vmpps
			JOIN virtual_product_ingredient i on
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

--insulin fix
INSERT INTO virtual_product_ingredient
VALUES ('3474911000001103','421619005',NULL,NULL,NULL,NULL,NULL);

INSERT INTO virtual_product_ingredient
VALUES ('3474911000001103','421884008',NULL,NULL,NULL,NULL,NULL);

DELETE FROM virtual_product_ingredient
WHERE
	vpid = '3474911000001103' AND
	isid = '421491002';

INSERT INTO virtual_product_ingredient
VALUES ('400844000','420609005',NULL,NULL,NULL,NULL,NULL);

INSERT INTO virtual_product_ingredient
VALUES ('400844000','420837001',NULL,NULL,NULL,NULL,NULL);

DELETE FROM virtual_product_ingredient
WHERE
	vpid = '400844000' AND
	isid = '421116002';

UPDATE virtual_product_ingredient
SET
	strnt_nmrtr_val = NULL,
	strnt_nmrtr_uomcd = NULL,
	strnt_dnmtr_val = NULL,
	strnt_dnmtr_uomcd = NULL
WHERE isid = '5375811000001107';

UPDATE virtual_product_ingredient v
SET strnt_dnmtr_uomcd = '258773002'
WHERE
	(SELECT nm FROM vmps WHERE vpid = v.vpid) LIKE '%ml%' AND
	v.strnt_dnmtr_uomcd = '258682000';

UPDATE virtual_product_ingredient
SET
	strnt_dnmtr_uomcd = NULL,
	strnt_dnmtr_val = NULL,
	strnt_nmrtr_uomcd = NULL,
	strnt_nmrtr_val = NULL
WHERE vpid IN ('5376411000001101','5376311000001108','5376211000001100');

UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 2,
       strnt_dnmtr_val = 0.4
WHERE vpid = '18248211000001104'
AND   isid = '51224002';

UPDATE virtual_product_ingredient
SET strnt_nmrtr_uomcd = '258685003'
WHERE vpid = '36458811000001107';

--create new temporary ingredients for COVID vaccines
--COVID-19 vaccine, recombinant, full-length nanoparticle spike (S) protein, adjuvanted with Matrix-M
--COVID-19 vaccine, whole virus, inactivated, adjuvanted with Alum and CpG 1018

INSERT INTO ingredient_substances (isid, nm)
VALUES
	('OMOP0000000001', 'COVID-19 vaccine, recombinant, full-length nanoparticle spike (S) protein, adjuvanted with Matrix-M'),
	('OMOP0000000002', 'COVID-19 vaccine, whole virus, inactivated, adjuvanted with Alum and CpG 1018'),
	('OMOP0000000003', 'COVID-19 vaccine, recombinant, plant-derived Virus-Like Particle (VLP) spike (S) protein, adjuvanted with AS03');

INSERT INTO virtual_product_ingredient (vpid, isid)
VALUES
	('39478211000001100', 'OMOP0000000001'),
	('39375211000001103', 'OMOP0000000002'),
	('39828011000001104', 'OMOP0000000003')
;

--At this step all tables, derived from source should be free of bugs


--! Step 4. Preparation for drug_concept_stage population
--Deduplication of devices
DELETE FROM devices s 
WHERE EXISTS (SELECT 1 FROM devices s_int 
                WHERE coalesce(s_int.apid, 'x') = coalesce(s.apid, 'x')
                  AND coalesce(s_int.nm_a, 'x') = coalesce(s.nm_a, 'x')
                  AND coalesce(s_int.vpid, 'x') = coalesce(s.vpid, 'x')
                  AND coalesce(s_int.nm_v, 'x') = coalesce(s.nm_v, 'x')
                  AND s_int.ctid > s.ctid);

--Some ingredients changed their isid
--isid considered isidnew, isidprev is an old one
DROP TABLE IF EXISTS ingred_replacement;
CREATE TABLE ingred_replacement AS
SELECT DISTINCT
	isidprev AS isidprev,
	nm AS nmprev,
	isid AS isidnew,
	nm AS nmnew
FROM ingredient_substances
	WHERE isidprev IS NOT NULL;

--tree vaccine
INSERT INTO ingred_replacement VALUES ('5375811000001107',NULL,'32869811000001104',NULL);
INSERT INTO ingred_replacement VALUES ('5375811000001107',NULL,'32869511000001102',NULL);
INSERT INTO ingred_replacement VALUES ('5375811000001107',NULL,'32870011000001108',NULL);

--TODO: May be used in future
/*
INSERT INTO ingred_replacement -- Zidovudine + Lamivudine -> Zidovudine
SELECT DISTINCT
	v1.vtmid,
	v2.vtmid
FROM vtms v1
JOIN vtms v2 on
	left (v1.nm, strpos(v1.nm, '+') - 2) = v2.nm or
	left (v1.nm, strpos(v1.nm, '+') - 2) || ' vaccine' = v2.nm
;
INSERT INTO ingred_replacement -- Zidovudine + Lamivudine -> Lamivudine
SELECT DISTINCT
	v1.vtmid,
	v2.vtmid
FROM vtms v1
JOIN vtms v2 on -- I am sorry for this
	reverse (left (reverse (v1.nm), strpos(reverse(v1.nm), '+') - 2)) = v2.nm or
	'Hepatitis ' || reverse (left (reverse (v1.nm), strpos(reverse(v1.nm), '+') - 2)) = v2.nm
;*/

--Processing drugs with multiple ingredients
--Splitting on ' + '
DROP TABLE IF EXISTS tms_temp;
CREATE TABLE tms_temp AS
	(
		SELECT v.vtmid, v.nm AS nmprev, nmnew
		FROM vtms v
		LEFT JOIN LATERAL unnest(string_to_array(replace(v.nm,' - invalid',''), ' + ')) AS nmnew on TRUE
		WHERE nm LIKE '%+%'
	);

--Connecting splitted ingredients with ids of separate ingredients
--To be inserted into drug tables
DROP TABLE IF EXISTS ir_insert;
CREATE TABLE ir_insert AS
SELECT
	t.vtmid AS isidprev,
	t.nmprev,
	coalesce (i.isid, v.vtmid) AS isidnew,
	t.nmnew
FROM tms_temp t
LEFT JOIN vtms v on
	t.nmnew ILIKE v.nm OR
	'Hepatitis ' || t.nmnew ILIKE v.nm OR
	t.nmnew  || ' vaccine' ILIKE v.nm
LEFT JOIN ingredient_substances i on
	(
		t.nmnew ILIKE i.nm OR
		'Hepatitis ' || t.nmnew ILIKE i.nm OR
		t.nmnew  || ' vaccine' ILIKE i.nm
	) AND
	i.invalid = '0';

--Creating sequence for concept codes
--Later in code would be a step with exchange to OMOP-like codes. It is easier to keep it as it was written for backward compatibility
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
	coalesce (i.isidnew, y.isid),
	i.nmnew
FROM ir_insert i
LEFT JOIN y on
	y.nmnew = i.nmnew;

--replaces precise ingredients (salts) with active molecule with few exceptions
INSERT INTO ingred_replacement
SELECT DISTINCT
	v.isid,
	s1.nm,
	s2.isid,
	s2.nm
FROM virtual_product_ingredient v
JOIN ingredient_substances s1 on
	v.isid = s1.isid
JOIN ingredient_substances s2 on
	v.bs_subid = s2.isid
LEFT JOIN devices d on --devices (contrasts) add a lot
	d.vpid = v.vpid
WHERE
	v.bs_subid IS NOT NULL AND
	d.vpid IS NULL AND
	s2.isid NOT IN -- do not apply to folic acid, metalic compounds AND halogens -- must still be mapped to salts
		(
			SELECT c.concept_code
			FROM concept c
			JOIN ancestor_snomed ca on
				c.vocabulary_id = 'SNOMED' AND
				ca.ancestor_concept_id IN (4143228, 4021618, 4213977, 35624387) AND
				ca.descendant_concept_id = c.concept_id
		) AND
	substring (lower (s1.nm) FROM 1 for 7) != 'insulin' -- to not to lose various insulins
;

--Manual corrections
--multiple bs_subids for Naloxone hydrochloride dihydrate
DELETE FROM ingred_replacement
WHERE (isidprev, isidnew) = ('4482911000001101', '21518006');

UPDATE ingred_replacement
SET
	isidnew = '387578003',
	nmnew = 'Sodium hyaluronate'
WHERE
	isidnew = '96278006'
;

--if X replaced with Y AND Y replaced with Z, replace X with Z
UPDATE ingred_replacement x
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
	WHERE x.isidnew in (SELECT ISIDprev FROM ingred_replacement)
	  --do not update for rows with 2 or more replacement ingredients
;



--Keep legacy mappings for the future
--Relationship_to_concept_all
CREATE TABLE IF NOT EXISTS r_to_c_all
(
   concept_name       varchar(255),
   concept_class_id   varchar,
   concept_id         integer,
   precedence         integer,
   conversion_factor  numeric
);

--UPDATE legacy mappings if target was changed
UPDATE r_to_c_all
SET concept_id =
	(
		SELECT DISTINCT c2.concept_id
		FROM concept_relationship r
		JOIN concept c2 on
			c2.concept_id = r.concept_id_2 AND
			r_to_c_all.concept_id = r.concept_id_1 AND
			r.relationship_id in ('Concept replaced by', 'Maps to') AND
			r.invalid_reason IS NULL
	)
WHERE
	exists
		(
			SELECT
			FROM concept
			WHERE
				concept_id = r_to_c_all.concept_id AND
				(
					invalid_reason = 'U' OR
					concept_class_id = 'Precise Ingredient' --RxN could move Ingredient to Precise Ingredient category
				)
		);

--Remove duplicates
DELETE FROM r_to_c_all r1
WHERE
	exists
		(
			SELECT
			FROM r_to_c_all r2
			WHERE
				(r2.concept_name, r2.concept_class_id, r2.concept_id) = (r1.concept_name, r1.concept_class_id, r1.concept_id) AND
				r2.precedence < r1.precedence
		) OR
	r1.concept_id IS NULL OR
	exists
		(
			SELECT
			FROM concept
			WHERE
				concept_id = r1.concept_id AND
				invalid_reason = 'D'
		);

CREATE INDEX devices_vpid on devices (vpid);
CREATE INDEX devices_apid on devices (apid);


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
LEFT JOIN fake_supp f on
	f.cd = s.cd
WHERE
	f.cd IS NULL
;

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
FROM unit_of_measure

	UNION ALL

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
LEFT JOIN devices d on
	v.vpid = d.vpid
WHERE d.vpid IS NULL

	UNION ALL

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
JOIN devices d on
	v.vpid = d.vpid

	UNION ALL

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
  JOIN vmps p on
--start date etc stored in VMPS
v.vpid = p.vpid
  LEFT JOIN devices d on v.vpid = d.vpid
WHERE d.vpid IS NULL

UNION ALL

--VMPPS = Virtual Medicinal Product Pack = Device (OMOP)
SELECT DISTINCT LEFT (v.nm,255) AS concept_name,
       'Device' AS domain_id,
       'dm+d' AS vocabulary_id,
       'Device' AS concept_class_id,
       'S' AS standard_concept,
       v.vppid AS concept_code,
       COALESCE(p.vpiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
       /*CASE v.invalid
         WHEN '1' THEN (SELECT latest_UPDATE - 1
                        FROM vocabulary
                        WHERE vocabulary_id = 'dm+d')
         ELSE*/ TO_DATE('20991231','yyyymmdd')
      /* END*/ AS valid_end_date,
	NULL AS invalid_reason,
       'VMPP'
FROM vmpps v
  JOIN vmps p on
--start date etc stored in VMPS
v.vpid = p.vpid
  JOIN devices d on v.vpid = d.vpid;

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
SELECT DISTINCT /*case
		when s.cd IS NULL then left (a.nm,255)
		else left (a.nm || ' by ' || s.info_desc,255)
	end as concept_name,*/ LEFT (a.nm,255),
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
  JOIN vmps p on
--start date etc stored in VMPS
a.vpid = p.vpid /*LEFT JOIN supplier s on
	a.suppcd = s.cd AND
	not exists (SELECT FROM fake_supp f WHERE f.cd = s.cd)*/
  LEFT JOIN devices d on a.vpid = d.vpid
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
SELECT DISTINCT /*case
		when s.cd IS NULL then left (a.nm,255)
		else left (a.nm || ' by ' || s.info_desc,255)
	end as concept_name,*/ LEFT (a.nm,255),
       'Device' AS domain_id,
       'dm+d' AS vocabulary_id,
       'Device' AS concept_class_id,
       'S' AS standard_concept,
       a.apid AS concept_code,
       --COALESCE(a.nmdt,p.vpiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
		TO_DATE('1970-01-01','YYYY-MM-DD') valid_start_date,
      /* CASE a.invalid
         WHEN '1' THEN (SELECT latest_UPDATE - 1
                        FROM vocabulary
                        WHERE vocabulary_id = 'dm+d')
         ELSE*/ TO_DATE('20991231','yyyymmdd')
       /*END*/ AS valid_end_date,
	NULL AS invalid_reason,
       'AMP'
FROM amps a
JOIN devices d on a.vpid = d.vpid;

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
--when a1.DISCDT IS NOT NULL then a1.DISCDT
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
LEFT JOIN devices d on a1.apid = d.apid
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
       TO_DATE('1970-01-01','YYYY-MM-DD') valid_start_date,
		TO_DATE('20991231','yyyymmdd')
      /* END*/ AS valid_end_date,
	NULL AS invalid_reason,
       'AMPP'
FROM ampps a1
JOIN devices d on a1.apid = d.apid;


--source 'Ingredient' is preferred to 'VTM'
INSERT INTO ingred_replacement
SELECT
	d2.concept_code,
	d2.concept_name,
	d1.concept_code,
	d1.concept_name
FROM drug_concept_stage d1
JOIN drug_concept_stage d2 on
	d1.source_concept_class_id = 'Ingredient' AND
	d2.source_concept_class_id = 'VTM' AND
	TRIM(LOWER(d1.concept_name)) = TRIM(LOWER(d2.concept_name));



--! Step 6. pc_stage population
INSERT INTO pc_stage
(SELECT
	c.prntvppid AS pack_concept_code,
/*	case
		when p2.qty_uomcd NOT IN
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
		then p2.vppid
		else p2.vpid
	end as drug_concept_code,*/ p2.vppid AS drug_concept_code,
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

JOIN vmpps p1 on
	c.prntvppid = p1.vppid
LEFT JOIN devices d1 on --filter devices
	d1.vpid = p1.vpid

JOIN vmpps p2 on
	c.chldvppid = p2.vppid --extract pack size
LEFT JOIN devices d2 on --probably redundant check for devices
	d2.vpid = p2.vpid

WHERE
	d1.vpid IS NULL AND
	d2.vpid IS NULL

	UNION ALL

SELECT
	c.prntappid AS pack_concept_code,
	/*case
		when vx.qty_uomcd NOT IN
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
		then p2.appid
		else p2.apid
	end as drug_concept_code,*/ p2.appid AS drug_concept_code,
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

JOIN ampps p1 on
	c.prntappid = p1.appid
LEFT JOIN devices d1 on --filter devices
	d1.apid = p1.apid

JOIN ampps p2 on --extract pack size
	c.chldappid = p2.appid
JOIN vmpps vx on --through vmpp
	vx.vppid = p2.vppid
LEFT JOIN devices d2 on --probably redundant check for devices
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
JOIN vmpps v on
	v.vppid = p.pack_concept_code
WHERE v.qtyval != '1'
GROUP BY p.pack_concept_code, qtyval
;

DELETE FROM pc_modifier
WHERE
	multiplier <= 1 or
	multiplier IS NULL;

UPDATE pc_stage p
SET box_size = (SELECT m.multiplier FROM pc_modifier m WHERE m.pack_concept_code = p.pack_concept_code)
;

UPDATE pc_stage p
SET box_size =
	(
		SELECT m.multiplier
		FROM pc_modifier m
		JOIN ampps a on
			a.vppid = m.pack_concept_code
		WHERE a.appid = p.pack_concept_code
	);

DROP TABLE IF EXISTS pc_modifier;

--AMPPS FROM names
CREATE TABLE pc_modifier AS
SELECT DISTINCT
	p.pack_concept_code,
	regexp_replace (trim (FROM regexp_match (regexp_replace (replace (replace (a.nm,' x ','x'),')',''), '1x\(',''), ' [2-9]+x\(.*') :: varchar,'{}" '),'x.*$','') :: int4 AS multiplier
FROM ampps a
JOIN pc_stage p on
	p.pack_concept_code = a.appid
WHERE box_size IS NULL;

DELETE FROM pc_modifier
WHERE
	multiplier <= 1 OR
	multiplier IS NULL;

UPDATE pc_stage c SET
	amount = c.amount / (SELECT multiplier FROM pc_modifier p WHERE p.pack_concept_code = c.pack_concept_code) :: int4,
	box_size = (SELECT multiplier FROM pc_modifier p WHERE p.pack_concept_code = c.pack_concept_code) :: int4
WHERE exists (SELECT FROM pc_modifier p WHERE p.pack_concept_code = c.pack_concept_code);

--fix bodyless headers: AMP AND VMP ancestors of pack concepts
INSERT INTO pc_stage
--branded pack headers, can have Brand Name, Supplier AND PC entry with same AMPs as AMPP counterpart
SELECT DISTINCT
	a.apid as pack_concept_code,
	ax.apid,
	NULL::int4 as amount, --empty for header concepts
	NULL::int4 as box_size
FROM pc_stage p
JOIN ampps a on
	a.appid = p.pack_concept_code
JOIN ampps ax on
	p.drug_concept_code = ax.appid;

INSERT INTO pc_stage
--clinical pack headers, can have only PC entry with same VMPs as VMPP counterpart
SELECT DISTINCT
	v.vpid AS pack_concept_code,
	vx.vpid,
	NULL::int4 AS amount, --empty for header
	NULL::int4 AS box_size
FROM pc_stage p
JOIN vmpps v on
	v.vppid = p.pack_concept_code
JOIN vmpps vx on
	vx.vppid = p.drug_concept_code;



--! Step 7. internal_relationship_stage population
INSERT INTO internal_relationship_stage
 -- VMP to ingredient
SELECT DISTINCT
	v.vpid AS cc1,
	coalesce
		(
			i.isid,	--correct IS
			v.vtmid --VTM
		)
FROM vmps v
LEFT JOIN virtual_product_ingredient i on i.vpid = v.vpid
LEFT JOIN devices d on --not device
	v.vpid = d.vpid
LEFT JOIN pc_stage p on
	v.vpid = p.pack_concept_code
WHERE
	d.vpid IS NULL AND --not pack header
	p.pack_concept_code IS NULL;

--replace ingredients deprecated by source
INSERT INTO internal_relationship_stage
SELECT
	i.concept_code_1,
	p.isidnew
FROM internal_relationship_stage i
JOIN ingred_replacement p on
	p.isidprev = i.concept_code_2;

--UPDATE Pantothenic acid loop
UPDATE ingred_replacement
   SET isidnew = '86431009'
WHERE isidprev = '404842009'
AND   isidnew = '126226000';
;

DELETE FROM internal_relationship_stage s
WHERE
	EXISTS
		(
			SELECT
			FROM ingred_replacement x
			WHERE s.concept_code_2 = x.isidprev
		) OR
	concept_code_2 IS NULL;

INSERT INTO internal_relationship_stage
--VMP to dose form
SELECT DISTINCT v.vpid, v.formcd --forms
FROM drug_form v
LEFT JOIN devices d on
	v.vpid = d.vpid
LEFT JOIN pc_stage p on
	v.vpid = p.pack_concept_code AND
	p.pack_concept_code NOT IN
		(
			SELECT pack_concept_code
			FROM pc_stage
			GROUP BY pack_concept_code
			HAVING count (drug_concept_code) = 1
		)
WHERE
	d.vpid IS NULL AND
	p.pack_concept_code IS NULL AND
	v.formcd != '3097611000001100' --Not Applicable
;

--Some drugs have missing dose forms at this step. Only concepts without dose forms got by regular way are addressed here.
--Therefore, this fix should not be moved anywhere, but kept as a part of internal_relationship_stage population
DROP TABLE IF EXISTS dose_form_fix;

--TODO: Consider moving these drugs to manual mapping to avoid manual work in load_stage
CREATE TABLE dose_form_fix AS --salvage missing Dose Forms FROM names
SELECT DISTINCT
	v.vpid,
	v.nm,
	NULL :: varchar AS dose_code,
	NULL :: varchar AS dose_name
FROM vmps v
LEFT JOIN devices d on
	d.vpid = v.vpid
LEFT JOIN pc_stage p on
	p.pack_concept_code = v.vpid AND
	p.pack_concept_code NOT IN
		(
			SELECT pack_concept_code
			FROM pc_stage
			GROUP BY pack_concept_code
			HAVING count (drug_concept_code) = 1
		)
WHERE
	d.vpid IS NULL AND
	p.pack_concept_code IS NULL AND
	v.vpid NOT IN
		(
			SELECT concept_code_1
			FROM internal_relationship_stage i
			JOIN drug_concept_stage c on
				c.concept_class_id = 'Dose Form' AND
				c.concept_code = i.concept_code_2
		);

UPDATE dose_form_fix
SET
	dose_code = '385219001',
	dose_name = 'Solution for injection'
WHERE
	lower (nm) LIKE '%viscosurgical%' OR
	lower (nm) LIKE '%infusion%' OR
	lower (nm) LIKE '%ampoules' OR
	lower (nm) LIKE '%syringes';

UPDATE dose_form_fix
SET
	dose_code = '385023001',
	dose_name = 'Oral solution'
WHERE
	lower (nm) LIKE '%syrup%' OR
	lower (nm) LIKE '%tincture%' OR
	lower (nm) LIKE '%oral drops%' OR
	lower (nm) LIKE '%oral spray%';

UPDATE dose_form_fix
SET
	dose_code = '385108009',
	dose_name = 'Cutaneous solution'
WHERE
	lower (nm) LIKE '%swabs';

UPDATE dose_form_fix
SET
	dose_code = '385111005',
	dose_name = 'Cutaneous emulsion'
WHERE
	lower (nm) LIKE '% oil %' OR
	lower (nm) LIKE '% oil' OR
	lower (nm) LIKE '%cream%';

UPDATE dose_form_fix
SET
	dose_code = '14945811000001105',
	dose_name = 'Powder for gastroenteral liquid'
WHERE
	lower (nm) LIKE '%oral%powder%' OR
	lower (nm) LIKE '%tri%salts%';

UPDATE dose_form_fix
SET
	dose_code = '385210002',
	dose_name = 'Inhalation vapour'
WHERE
	lower (nm) LIKE '%inhala%';

UPDATE dose_form_fix
SET
	dose_code = '385124005',
	dose_name = 'Eye drops'
WHERE
	lower (nm) LIKE '%eye%';

UPDATE dose_form_fix
SET
	dose_code = '16605211000001107',
	dose_name = 'Irrigation solution'
WHERE
	lower (nm) LIKE '%intraves%' OR
	lower (nm) LIKE '%maint%';

UPDATE dose_form_fix
SET
	dose_code = '16605211000001107',
	dose_name = 'Irrigation solution'
WHERE
	lower (nm) LIKE '%intraves%' OR
	lower (nm) LIKE '%maint%';

UPDATE dose_form_fix --will be improved later
SET
	dose_code = '85581007',
	dose_name = 'Powder'
WHERE
	dose_code IS NULL AND ( lower (nm) LIKE '%powder%' OR lower (nm) LIKE '%crystals%');

UPDATE dose_form_fix
SET
	dose_code = '70409003',
	dose_name = 'Mouthwash'
WHERE dose_code IS NULL AND lower (nm) LIKE '%mouthwash%';

UPDATE dose_form_fix --will be improved later
SET
	dose_code = '420699003',
	dose_name = 'Liquid'
WHERE dose_code IS NULL;

INSERT INTO internal_relationship_stage
SELECT vpid, dose_code
FROM dose_form_fix
WHERE dose_code IS NOT NULL;

--'Foam' is too generic AND is related to multiple different dose forms
-- May need to fix with name matching
INSERT INTO internal_relationship_stage
-- AMP to dose form
-- excipients are ignored, so we reuse VMPs for ingredients AND dose forms
-- Ingredient relations will be inherited after ds_stage
SELECT DISTINCT
	a.apid,
	i.concept_code_2
FROM amps a
JOIN internal_relationship_stage i on
	i.concept_code_1 = a.vpid
/*JOIN drug_concept_stage x on
	x.concept_class_id = 'Dose Form' AND
	x.concept_code = i.concept_code_2*/
LEFT JOIN devices d on
	a.apid = d.apid
LEFT JOIN pc_stage p on
	a.apid = p.pack_concept_code AND
	p.pack_concept_code NOT IN
		(
			SELECT pack_concept_code
			FROM pc_stage
			GROUP BY pack_concept_code
			HAVING count (drug_concept_code) = 1
		)
WHERE
	d.apid IS NULL AND
	p.pack_concept_code IS NULL;

INSERT INTO internal_relationship_stage
--AMP to supplier
SELECT DISTINCT
	a.apid,
	a.suppcd
FROM amps a
LEFT JOIN fake_supp c on -- supplier is present in dcs
	a.suppcd = c.cd
LEFT JOIN devices d on
	a.apid = d.apid
WHERE
	d.apid IS NULL AND
	c.cd IS NULL;

INSERT INTO internal_relationship_stage
--VMPP -- if not a pack, reuse VMP relations. If a pack, omit.
SELECT DISTINCT
	p.vppid,
	i.concept_code_2
FROM internal_relationship_stage i
JOIN vmpps p on
	p.vpid = i.concept_code_1
/*JOIN drug_concept_stage x on
	x.concept_class_id = 'Dose Form' AND
	x.concept_code = i.concept_code_2*/
LEFT JOIN pc_stage c on
	c.pack_concept_code = p.vppid AND
	c.pack_concept_code NOT IN
		(
			SELECT pack_concept_code
			FROM pc_stage
			GROUP BY pack_concept_code
			HAVING count (drug_concept_code) = 1
		)
WHERE c.pack_concept_code IS NULL;

--AMPP -- if not a pack, reuse AMP relations. If a pack, omit.
INSERT INTO internal_relationship_stage
SELECT DISTINCT
	p.appid,
	i.concept_code_2
FROM internal_relationship_stage i
JOIN ampps p on
	p.apid = i.concept_code_1
LEFT JOIN pc_stage c on
	c.pack_concept_code = p.appid AND
	c.pack_concept_code NOT IN
		(
			SELECT pack_concept_code
			FROM pc_stage
			GROUP BY pack_concept_code
			HAVING count (drug_concept_code) = 1
		)
LEFT JOIN devices d on
	d.apid = p.apid
WHERE
	c.pack_concept_code IS NULL AND
	d.apid IS NULL;

--Monopacks (1 drug_concept_code per pack)
DROP TABLE IF EXISTS only_1_pack;
CREATE TABLE only_1_pack as
SELECT DISTINCT
	pack_concept_code,
	drug_concept_code,
	amount
FROM pc_stage p
WHERE
	p.pack_concept_code in
		(
			SELECT pack_concept_code
			FROM pc_stage
			GROUP BY pack_concept_code
			HAVING count (drug_concept_code) = 1
		);

INSERT INTO internal_relationship_stage --monopacks inherit their content's relation entirely, if they don't already have unique
SELECT DISTINCT
	p.pack_concept_code,
	i.concept_code_2
FROM internal_relationship_stage i
JOIN pc_stage p on
	i.concept_code_1 = p.drug_concept_code
JOIN only_1_pack using (pack_concept_code)
JOIN drug_concept_stage x on
	x.concept_code = i.concept_code_2
WHERE
	not exists --check if monopack already has this type of relation
		(
			SELECT
			FROM internal_relationship_stage z
			JOIN drug_concept_stage dz on
				dz.concept_code = z.concept_code_2
			WHERE
				z.concept_code_1 = p.pack_concept_code AND
				dz.concept_class_id = x.concept_class_id AND
				dz.concept_class_id in ('Supplier', 'Dose Form')
		)
;

DELETE FROM pc_stage WHERE
	pack_concept_code in
		(
			SELECT pack_concept_code
			FROM only_1_pack
		)
;

UPDATE pc_stage
SET	amount = 1
WHERE pack_concept_code = '34884711000001100';



--! Step 8. Preparation for ds_stage population. Form ds_stage using source relations AND name analysis. Replace ingredient relations
DROP TABLE IF EXISTS ds_prototype;

--Create ds_stage for VMPs, inherit everything else later
CREATE TABLE ds_prototype as
--temporary table
SELECT DISTINCT
	c1.concept_code as drug_concept_code,
	c1.concept_name as drug_name,
	c2.concept_code as ingredient_concept_code,
	c2.concept_name as ingredient_name,
	i.strnt_nmrtr_val as amount_value,
	c3.concept_code as amount_code,
	c3.concept_name as amount_name,
	i.strnt_dnmtr_val as denominator_value,
	c4.concept_code as denominator_code,
	c4.concept_name as denominator_name,
	NULL::int4 as box_size,
	v.udfs as total, --sometimes contains additional info about size AND amount
	u1.cd as unit_1_code,
	u1.info_desc as unit_1_name
/*	,u2.cd as unit_2_code,
	u2.info_desc as unit_2_name*/
FROM virtual_product_ingredient i -- main source table
JOIN vmps v on
	v.vpid = i.vpid AND
	i.strnt_nmrtr_uomcd NOT IN ('258672001','258731005')
	--and	i.strnt_dnmtr_uomcd != '259022006'
LEFT JOIN UNIT_OF_MEASURE u1 on
	v.udfs_uomcd = u1.cd
/*LEFT JOIN UNIT_OF_MEASURE u2 on
	v.unit_dose_uomcd = u2.cd*/
LEFT JOIN ingred_replacement r on
	i.isid = r.isidprev
JOIN drug_concept_stage c1 on
	c1.concept_code = i.vpid
JOIN drug_concept_stage c2 on
	c2.concept_code = coalesce (i.isid, r.isidnew)
JOIN drug_concept_stage c3 on
	c3.concept_code = i.strnt_nmrtr_uomcd
LEFT JOIN drug_concept_stage c4 on
	c4.concept_code = i.strnt_dnmtr_uomcd
LEFT JOIN devices d on --no ds entry for non-drugs
	i.vpid = d.vpid
WHERE
	d.vpid IS NULL;

DROP TABLE IF EXISTS vmps_res --try to salvage missing dosages FROM texts FROM VMPs
;

CREATE TABLE vmps_res as
with ingreds as
	(
		SELECT concept_code_1, concept_code, concept_name
		FROM internal_relationship_stage i
		JOIN drug_concept_stage c on
			i.concept_code_2 = c.concept_code AND
			c.concept_class_id = 'Ingredient'
	),
dforms as
	(
		SELECT concept_code_1, concept_code, concept_name
		FROM internal_relationship_stage i
		JOIN drug_concept_stage c on
			i.concept_code_2 = c.concept_code AND
			c.concept_class_id = 'Dose Form'
	)
SELECT DISTINCT
	v.vpid as drug_concept_code,
	replace (v.nm,',','') as drug_concept_name,
	i.concept_code as ingredient_concept_code,
	i.concept_name as ingredient_concept_name,
	f.concept_code as form_concept_code,
	f.concept_name as form_concept_name,
	NULL :: varchar (255) as modified_name
FROM vmps v
LEFT JOIN ds_prototype s on
	s.drug_concept_code = v.vpid
LEFT JOIN devices d on
	v.vpid = d.vpid
LEFT JOIN pc_stage p on
	p.pack_concept_code = v.vpid
LEFT JOIN ingreds i on
	v.vpid = i.concept_code_1
LEFT JOIN dforms f on
	v.vpid = f.concept_code_1
WHERE
	d.vpid IS NULL AND
	p.pack_concept_code IS NULL AND
	s.drug_concept_code IS NULL
;-- move deprecated gases (given as 1 ml / 1 ml) to manual work

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
	lower(drug_concept_name) LIKE '%homeopath%' OR
	lower(ingredient_concept_name) LIKE '%homeopath%' OR
	lower(form_concept_name) LIKE '%homeopath%';

UPDATE vmps_res SET ingredient_concept_name = 'Estramustine' WHERE ingredient_concept_name = 'Estramustine phosphate';
UPDATE vmps_res SET ingredient_concept_name = 'Tenofovir' WHERE ingredient_concept_name = 'Tenofovir disoproxil';
UPDATE vmps_res SET ingredient_concept_name = 'Lysine' WHERE ingredient_concept_name = 'L-Lysine';

UPDATE vmps_res --cut ingredient at start for single-ingredient
SET	modified_name =
	replace (
		right
		(
			lower (drug_concept_name),
			length (drug_concept_name) - (strpos (lower (drug_concept_name), lower (ingredient_concept_name))) - length (ingredient_concept_name)
		)
	, ' / ', '/')
WHERE
	strpos (lower (drug_concept_name), lower (ingredient_concept_name)) != 0 AND
	drug_concept_code in
		(
			SELECT drug_concept_code
			FROM vmps_res
			GROUP BY drug_concept_code
			HAVING count (ingredient_concept_code) = 1 --good results only guaranteed for single ingred
		)
;

UPDATE vmps_res
SET modified_name =
	replace (
		regexp_replace (lower (drug_concept_name), '^\D+','')
	, ' / ', '/')
WHERE
	strpos (lower (drug_concept_name), lower (ingredient_concept_name)) = 0 AND
	drug_concept_code in
		(
			SELECT drug_concept_code
			FROM vmps_res
			GROUP BY drug_concept_code
			HAVING count (ingredient_concept_code) = 1 --good results only guaranteed for single ingred
		);

UPDATE vmps_res --cut form FROM the end
SET modified_name =
	case
		when modified_name IS NULL then NULL
		when strpos (modified_name, lower (form_concept_name)) != 0 then
			left (modified_name, strpos (modified_name, lower (form_concept_name)) - 1)
		else modified_name
	end
WHERE form_concept_code IS NOT NULL;

UPDATE vmps_res
SET modified_name =
	CASE
		WHEN modified_name = '' THEN NULL
		WHEN regexp_match (modified_name, '\d', 'im') IS NULL THEN NULL
		ELSE modified_name
	END;

UPDATE vmps_res --remove traces of other artifacts
SET modified_name =
	trim (FROM regexp_replace (regexp_replace (modified_name, '^[a-z \(\)]+ ', '', 'im'),' [\w \(\),-.]+$','','im'))
WHERE modified_name IS NOT NULL;

UPDATE vmps_res SET
modified_name = regexp_replace (modified_name, ' .*$','')
WHERE modified_name LIKE '% %';

UPDATE vmps_res
SET modified_name = NULL
WHERE
	modified_name LIKE '%ppm%' OR
	modified_name LIKE '%square%';

DROP TABLE IF EXISTS ds_parsed;
CREATE TABLE ds_parsed as
SELECT --percentage
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	trim (FROM regexp_match (modified_name, '^[\d.]+','im') :: varchar, '{}') :: numeric * 10 as amount_value,
	'258684004' as amount_code,
	'mg' as amount_name,
	1 as denominator_value,
	'258773002' as denominator_code,
	'ml' as denominator_name,
	NULL :: int4 as box_size,
	NULL :: numeric as total,
	NULL :: varchar as unit_1_code,
	NULL :: varchar as unit_1_name
FROM vmps_res
WHERE
	modified_name LIKE '%|%' escape '|' AND
	regexp_match (drug_concept_name, ' [0-9.]+ml ') IS NULL

	UNION ALL

SELECT --percentage, with given total volume
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	trim (FROM regexp_match (modified_name, '^[\d.]+','im') :: varchar, '{}') :: numeric * 10 * trim (FROM regexp_match (drug_concept_name, ' [0-9.]+ml ','im') :: varchar, ' ml{}"') :: numeric as amount_value,
	'258684004' as amount_code,
	'mg' as amount_name,
	trim (FROM regexp_match (drug_concept_name, ' [0-9.]+ml ','im') :: varchar, ' ml{}"') :: numeric as denominator_value,
	'258773002' as denominator_code,
	'ml' as denominator_name,
	NULL as box_size,
	NULL as total,
	NULL as unit_1_code,
	NULL as unit_1_name
FROM vmps_res
WHERE
	modified_name LIKE '%|%' escape '|' AND
	regexp_match (drug_concept_name, ' [0-9.]+ml ') IS NOT NULL

	UNION ALL

SELECT --numerator/denominator
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	trim (FROM regexp_match (modified_name, '^[\d.]+','im') :: varchar, '{}') :: numeric as amount_value,
	NULL as amount_code,
	trim (FROM regexp_match (modified_name, '[a-z]+\/','im') :: varchar, '{/}') :: varchar as amount_name,
	coalesce
		(
			trim (FROM regexp_match (modified_name, '\/[\d.]+','im') :: varchar, '{/}') :: numeric,
			1
		) as denominator_value,
	NULL as denominator_code,
	trim (FROM regexp_match (modified_name, '[a-z]+$','im') :: varchar, '{/}') :: varchar as denominator_name,
	NULL as box_size,
	NULL as total,
	NULL as unit_1_code,
	NULL as unit_1_name
FROM vmps_res
WHERE modified_name LIKE '%|/%' escape '|'

	UNION ALL

SELECT --simple amount
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	trim (FROM regexp_match (modified_name, '^[\d.]+','im') :: varchar, '{}') :: numeric as amount_value,
	NULL as amount_code,
	trim (FROM regexp_match (modified_name, '[a-z]+$','im') :: varchar, '{/}') :: varchar as denominator_name,
	NULL as denominator_value,
	NULL as denominator_code,
	NULL as denominator_name,
	NULL as box_size,
	NULL as total,
	NULL as unit_1_code,
	NULL as unit_1_name
FROM vmps_res
WHERE
	modified_name not LIKE '%|/%' escape '|' AND
	modified_name not LIKE '%|%' escape '|';

UPDATE ds_parsed d SET amount_name = 'gram' WHERE amount_name = 'g';
UPDATE ds_parsed d SET amount_name = trim (trailing 's' FROM amount_name) WHERE amount_name LIKE '%s';
UPDATE ds_parsed d SET denominator_name = 'gram' WHERE denominator_name = 'g';
UPDATE ds_parsed d SET denominator_name = trim (trailing 's' FROM denominator_name) WHERE denominator_name LIKE '%s';
UPDATE ds_parsed d SET amount_code = (SELECT cd FROM unit_of_measure WHERE d.amount_name = info_desc) WHERE amount_name IS NOT NULL;
UPDATE ds_parsed d SET denominator_code = (SELECT cd FROM unit_of_measure WHERE d.denominator_name = info_desc) WHERE denominator_name IS NOT NULL;

UPDATE ds_parsed d SET --only various Units remain by now
	amount_code = '258666001',
	amount_name = 'unit'
WHERE
	amount_code IS NULL AND
	amount_name IS NOT NULL;


--Table created for manual curation of certain drugs, where doses were picked up from the text
/*
--It is recommended to create a backup for this table just in case
--CREATE TABLE tomap_vmps_ds_backup AS (SELECT * FROM tomap_vmps_ds)
--DROP TABLE IF EXISTS tomap_vmps_ds;

--For manual mapping
--If corresponding ingredient code IS NOT present in DCS, manually enter concept_id of passing ingredient FROM Rx* -- OMOP concept will be created automatically
--To fill the table use names (mg, ml, etc) that are present in unit_of_measure table (case-sensitive)
--Use decimal point, not comma
SELECT count(*) FROM tomap_vmps_ds;
-- CREATE TABLE tomap_vmps_ds as
SELECT
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	NULL :: numeric as amount_value,
	NULL :: varchar as amount_name,
	NULL :: numeric as denominator_value,
	NULL :: varchar as denominator_unit
FROM vmps_res
WHERE
	drug_concept_code NOT IN (SELECT drug_concept_code FROM ds_parsed WHERE amount_name IS NOT NULL) AND
	drug_concept_code NOT IN (SELECT drug_concept_code FROM ds_prototype)
	and drug_concept_code NOT IN (SELECT drug_concept_code FROM tomap_vmps_ds)
order by drug_concept_name, ingredient_concept_name desc


--Do a parsing and then reupload to the same table
--TRUNCATE tomap_vmps_ds;

-- at the moment, they are deleted from tomap_vmps_ds
DELETE FROM tomap_vmps_ds WHERE ingredient_concept_code = '0';

;*/

--Double check: if drug has a parsing already, it is prioritized over manual table
DELETE FROM tomap_vmps_ds
WHERE drug_concept_code IN (SELECT drug_concept_code FROM ds_prototype);

--Double check: Non-existing drugs
DELETE FROM tomap_vmps_ds
WHERE drug_concept_code NOT IN (SELECT concept_code FROM drug_concept_stage WHERE domain_id = 'Drug');

--Delete from internal_relationship_stage all the relationships with ingredients to recreate it few steps later from the manual table (manual table is a priority)
DELETE FROM internal_relationship_stage
WHERE
	concept_code_1 in (SELECT drug_concept_code FROM tomap_vmps_ds) AND
	concept_code_2 in (SELECT concept_code FROM drug_concept_stage WHERE concept_class_id = 'Ingredient');


--Creating new ingredients from manually curated table
DROP TABLE IF EXISTS ds_new_ingreds;

CREATE TABLE ds_new_ingreds as
with ings as
	(
		SELECT DISTINCT	cast (ingredient_concept_name as int4) :: int4 as ingredient_id
		FROM tomap_vmps_ds
		WHERE
			ingredient_concept_name IS NOT NULL AND
			ingredient_concept_code IS NULL
	)
SELECT
	c.concept_id as ingredient_id,
	'OMOP' || nextval ('new_seq') as concept_code,
	c.concept_name
FROM ings i
JOIN concept c on
	c.concept_id = 	cast (ingredient_id as int4);

--May be no ingredients
INSERT INTO drug_concept_stage(concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT
	concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	'S' AS standard_concept,
	concept_code,
	to_date ('1970-01-01','YYYY-MM-DD'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL as invalid_reason
FROM ds_new_ingreds
;

--Filling in the ds_prototype table from the manual table
INSERT INTO ds_prototype (drug_concept_code, drug_name, ingredient_concept_code, ingredient_name, amount_value,
                          amount_code, amount_name, denominator_value, denominator_code, denominator_name, box_size, total, unit_1_code, unit_1_name)
SELECT
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	amount_value,
	NULL :: varchar as amount_code,
	amount_name,
	denominator_value,
	NULL :: varchar as denominator_code,
	denominator_unit,
	NULL :: int4,
	NULL :: int4,
	NULL :: varchar,
	NULL :: varchar
FROM tomap_vmps_ds
WHERE amount_value IS NOT NULL;

--Working with ds_parsed table
DELETE FROM ds_parsed
WHERE drug_concept_code in
	(SELECT drug_concept_code FROM tomap_vmps_ds);

INSERT INTO ds_prototype
SELECT *
FROM ds_parsed
WHERE amount_name IS NOT NULL AND drug_concept_code NOT IN (SELECT drug_concept_code FROM ds_prototype);

UPDATE ds_prototype d
SET
	ingredient_concept_code = (SELECT concept_code FROM ds_new_ingreds WHERE ingredient_id :: varchar = d.ingredient_name),
	ingredient_name = (SELECT concept_name FROM ds_new_ingreds WHERE ingredient_id :: varchar = d.ingredient_name)
WHERE
	ingredient_name IS NOT NULL AND
	ingredient_concept_code IS NULL;

UPDATE ds_prototype d SET amount_code = (SELECT cd FROM unit_of_measure WHERE d.amount_name = info_desc) WHERE amount_name IS NOT NULL;
UPDATE ds_prototype d SET denominator_code = (SELECT cd FROM unit_of_measure WHERE d.denominator_name = info_desc) WHERE denominator_name IS NOT NULL;

--New ingredients into internal_relationship_stage
INSERT INTO internal_relationship_stage
SELECT
	d.drug_concept_code,
	coalesce (i.concept_code, d.ingredient_concept_code)
FROM tomap_vmps_ds d
LEFT JOIN ds_new_ingreds i on
	i.ingredient_id :: varchar = d.ingredient_concept_name;


--Preparation for ds_stage population
--modify ds_prototype
--replace liters with mls
UPDATE ds_prototype d
SET --amount
	amount_value = d.amount_value * 1000,
	amount_code = '258773002',
	amount_name = 'ml'
WHERE d.amount_code = '258770004';

UPDATE ds_prototype d
SET --denominator
	denominator_value = d.denominator_value * 1000,
	denominator_code = '258773002',
	denominator_name = 'ml'
WHERE d.denominator_code = '258770004';

UPDATE ds_prototype d
SET --total
	total = d.total * 1000,
	unit_1_code = '258773002',
	unit_1_name = 'ml'
WHERE d.unit_1_code = '258770004';

--replace 'drops' with ml denominator
UPDATE ds_prototype d
SET --total
	denominator_value = d.denominator_value * 0.05, -- 1 pharmaceutical drop ~ 0.05 ml
	denominator_code = '258773002',
	denominator_name = 'ml'
WHERE d.denominator_code = '10693611000001100';

--replace grams with mgs
UPDATE ds_prototype d
SET --amount
	amount_value = d.amount_value * 1000,
	amount_code = '258684004',
	amount_name = 'mg'
WHERE d.amount_code = '258682000';

UPDATE ds_prototype d
SET --denominator
	denominator_value = d.denominator_value * 1000,
	denominator_code = '258684004',
	denominator_name = 'mg'
WHERE d.denominator_code = '258682000';

UPDATE ds_prototype d
SET --total
	total = d.total * 1000,
	unit_1_code = '258684004',
	unit_1_name = 'mg'
WHERE d.unit_1_code = '258682000';

--replace kgs with mgs
UPDATE ds_prototype d
SET --amount
	amount_value = d.amount_value * 1000000,
	amount_code = '258684004',
	amount_name = 'mg'
WHERE d.amount_code = '258683005';

UPDATE ds_prototype d
SET --denominator
	denominator_value = d.denominator_value * 1000000,
	denominator_code = '258684004',
	denominator_name = 'mg'
WHERE d.denominator_code = '258683005';

UPDATE ds_prototype d
SET --total
	total = d.total * 1000000,
	unit_1_code = '258684004',
	unit_1_name = 'mg'
WHERE d.unit_1_code = '258683005';

--replace microliters with mls
UPDATE ds_prototype d
SET --amount
	amount_value = d.amount_value * 0.001,
	amount_code = '258773002',
	amount_name = 'ml'
WHERE d.amount_code = '258774008';

UPDATE ds_prototype d
SET --denominator
	denominator_value = d.denominator_value * 0.001,
	denominator_code = '258773002',
	denominator_name = 'ml'
WHERE d.denominator_code = '258774008';

UPDATE ds_prototype d
SET --total
	total = d.total * 0.001,
	unit_1_code = '258773002',
	unit_1_name = 'ml'
WHERE d.unit_1_code = '258774008';

--if denominator is 1000 mg (and total is present AND in ml), change to 1 ml
UPDATE ds_prototype d
SET --denominator
	denominator_value = 1,
	denominator_code = '258773002',
	denominator_name = 'ml'
WHERE
	d.denominator_code = '258684004' AND
	d.denominator_value = 1000 AND
	d.unit_1_code = '258773002';

UPDATE ds_prototype d --powders, oils etc; remove denominator AND totals
SET
	amount_value =
		case
			when unit_1_code = amount_code then total
			else amount_value
		end,
	denominator_value = NULL,
	denominator_code = NULL,
	denominator_name = NULL,
	total =
		case
			when unit_1_code != amount_code then total
			else NULL
		end,
	unit_1_code =
		case
			when unit_1_code != amount_code then unit_1_code
			else NULL
		end,
	unit_1_name =
		case
			when unit_1_code != amount_code then unit_1_name
			else NULL
		end
WHERE
	amount_value = denominator_value AND
	amount_code = denominator_code;

--respect df_indcd = 2 (continuous)
UPDATE ds_prototype
SET
	(amount_value,amount_code,amount_name) = (NULL,NULL,NULL)
WHERE
	denominator_name IS NULL AND
	(amount_value, amount_name) in ((1,'mg'),(1000,'mg')) AND
	drug_concept_code in (SELECT vpid FROM vmps WHERE df_indcd in ('2','3'));

UPDATE ds_prototype
SET
	denominator_value = NULL
WHERE
	denominator_value = 1 AND
	denominator_name in ('ml','dose','square cm','mg') AND
	drug_concept_code in (SELECT vpid FROM vmps WHERE df_indcd in ('2','3'));

UPDATE ds_prototype
SET
	denominator_value = NULL,
	amount_value = amount_value / 1000
WHERE
	(denominator_value,denominator_name) in ((1000,'ml'),(1000,'mg')) AND
	drug_concept_code in (SELECT vpid FROM vmps WHERE df_indcd in ('2','3'));

UPDATE ds_prototype d
--'1 applicator' in total fields is redundant
SET
	total = NULL,
	unit_1_code = NULL,
	unit_1_name = NULL
WHERE
	total = 1 AND
	unit_1_code = '732980001';

--if denominator is in mg, ml should not be in numerator (mostly oils: 1 ml = 800 mg); --1
--if other numerators are present in mg, all other numerators should be, too --2
UPDATE ds_prototype d
SET
	amount_value = 800 * d.amount_value,
	amount_code = '258684004',
	amount_name = 'mg'
WHERE
	(
		denominator_code = '258684004' AND --mg --1
		amount_code = '258773002' --ml
	)
	OR
	(
		exists --2
			(
				SELECT
				FROM ds_prototype x
				WHERE
					x.drug_concept_code = d.drug_concept_code AND
					x.amount_code != '258773002' --any other dosage
			) AND
		amount_code = '258773002' --ml
	); --these drugs are useless with ml as dosage

DELETE FROM ds_prototype
WHERE
	(
		lower (drug_name) LIKE '%virus%' OR
		lower (drug_name) LIKE '%vaccine%' OR
		lower (drug_name) LIKE '%antiserum%'
	) AND
	amount_code = '258773002' AND --ml
	denominator_code IS NULL;

--if drug exists as concentration for VMPS, but has total in grams on VMPP level, convert concentration to MG
UPDATE ds_prototype d
SET
	denominator_code = '258684004',
	denominator_name = 'mg',
	amount_value = d.amount_value / 1000
WHERE
	d.denominator_value IS NULL AND
	d.denominator_code = '258773002' AND --ml
	d.total IS NULL AND
	d.drug_concept_code in
		(
				SELECT vpid
				FROM vmpps v
				WHERE v.qty_uomcd in ('258682000') --g
		) AND
	d.drug_concept_code NOT IN -- also does not have ML forms
		(
				SELECT vpid
				FROM vmpps v
				WHERE v.qty_uomcd in ('258773002') --ml
		);


--! Step 9. Populating ds_stage table
INSERT INTO ds_stage --simple numerator only dosage, no denominator
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_name as amount_unit,
	NULL :: numeric,
	NULL,
	NULL :: numeric,
	NULL,
	NULL :: int4
FROM ds_prototype
WHERE
	denominator_code IS NULL AND
	(
		(

			(
				unit_1_code NOT IN --will be in num/denom instead
					(
						'258774008', --microlitre
						'258773002', --ml
						'258770004', --litre
						'732981002', --actuation
						'3317411000001100', --dose
						'3319711000001103' --unit dose
					) OR
				unit_1_code IS NULL
			)
		) OR
		(amount_code = '258773002' AND (amount_value, amount_code) = (total, unit_1_code))	--numerator in ml, total in ml, amount equal to total
	)
	and amount_name not LIKE '%/%';

INSERT INTO ds_stage --numerator only dosage, but lost denominator
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code,
	NULL :: int4,
	NULL,
	amount_value as numerator_value,
	amount_name as numerator_unit,
	total as denominator_value,
	unit_1_name as denominator_unit,
	NULL :: numeric
FROM ds_prototype
WHERE
	denominator_code IS NULL AND
	unit_1_code in --will be in num/denom instead
		(
			'258774008', --microlitre
			'258773002', --ml
			'258770004', --litre
			'732981002', --actuation
			'3317411000001100', --dose
			'3319711000001103' --unit dose
		)
	and amount_name not LIKE '%/%'
	and not (amount_code = '258773002' AND (amount_value, amount_code) = (total, unit_1_code)) --numerator in ml, total in ml, amount equal to total;

INSERT INTO ds_stage --literally 2 concepts with mg/g as numerator code
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code,
	NULL :: numeric,
	NULL,
	amount_value as numerator_value,
	'mg' as numerator_unit,
	1 as denominator_value,
	'ml' as denominator_unit,
	NULL :: int4
FROM ds_prototype
WHERE
	denominator_code IS NULL AND
	amount_code = '408168009'; --mg/g

INSERT INTO ds_stage --simple numerator+denominator
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code,
	NULL :: numeric,
	NULL,
	amount_value,
	amount_name,
	denominator_value,
	denominator_name,
	NULL :: int4
FROM ds_prototype d
WHERE
	denominator_code IS NOT NULL AND
	(
		unit_1_code IS NULL OR
		--dose form for some reason
		(
			unit_1_code in
				(
					'419702001', --patch
					'733007009', --pessary
					'733010002', --plaster
					'3318611000001103', --prefilled injection
					'733013000', --sachet
					'430293001', --suppository
					'733021006', --system
					'3319711000001103', --unit dose
					'415818006', --vial
					'3318311000001108', --pastile
					'429587008', --lozenge
					'700476008', --enema
					'3318711000001107', --device
					'428672001', --bag
					'732980001', --applicator
					'3317411000001100', --dose
					'732981002' --actuation
				) AND
			unit_1_code != denominator_code AND
			total = 1
		)
	);

INSERT INTO ds_stage --simple numerator+denominator, total amount provided in same units as denominator
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code,
	NULL :: numeric,
	NULL,
	amount_value * total / denominator_value as numerator_value,
	amount_name,
	total as denominator_value,
	denominator_name,
	NULL :: int4
FROM ds_prototype d
WHERE
	denominator_code = unit_1_code AND
	not exists --all components of drug should follow same rule
		(
			SELECT
			FROM ds_prototype p
			WHERE
				d.drug_concept_code = p.drug_concept_code AND
				denominator_code != unit_1_code
		);

INSERT INTO ds_stage --simple numerator+denominator, total amount provided in same units as numerator
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code,
	NULL :: numeric,
	NULL,
	total as numerator_value,
	amount_name,
	denominator_value * total / amount_value as denominator_value,
	denominator_name,
	NULL :: int4
FROM ds_prototype d
WHERE
	amount_code = unit_1_code AND
	denominator_code != amount_code AND
	not exists --all components of drug should follow same rule
		(
			SELECT
			FROM ds_prototype p
			WHERE
				d.drug_concept_code = p.drug_concept_code AND
				amount_code != unit_1_code
		);

--AMPs
--Take note that we omit excipients completely AND just inherit VMP relations
--if we ever need excipients, we can find them in AP_INGREDIENT table
INSERT INTO ds_stage
SELECT DISTINCT
	a.apid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
FROM ds_stage d
JOIN amps a on
	d.drug_concept_code = a.vpid; --this will include packs, both proper components AND monocomponent packs;

--VMPPs
--inherited FROM VMPs with added box size
DROP TABLE IF EXISTS ds_insert;

CREATE TABLE ds_insert as --intermediate entry
SELECT DISTINCT
	p.vppid,
	p.nm,
	p.qtyval,
	u.cd as box_code,
	u.info_desc as box_name,
	o.*
FROM vmpps p
JOIN UNIT_OF_MEASURE u on
	p.qty_uomcd = u.cd
JOIN ds_prototype o on
	o.drug_concept_code = p.vpid;

--replace grams with mgs
UPDATE ds_insert d
SET
	qtyval = d.qtyval * 1000,
	box_code = '258684004',
	box_name = 'mg'
WHERE d.box_code = '258682000';

--replace liters with mls
UPDATE ds_insert d
SET
	qtyval = d.qtyval * 1000,
	box_code = '258773002',
	box_name = 'ml'
WHERE d.box_code = '258770004';

INSERT INTO ds_stage --any dosage type, nonscalable
SELECT DISTINCT
 	i.vppid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	coalesce (i.qtyval, d.box_size) as box_size
FROM ds_insert i
JOIN ds_stage d on
	i.drug_concept_code = d.drug_concept_code
WHERE
	--(i.box_code = i.unit_1_code OR i.unit_1_code IS NULL) AND
	(i.box_code NOT IN --nonscalable forms only
		(
			'258684004', --mg
			'258774008', --microlitre
			'258773002', --ml
			'258770004', --litre
			'732981002', --actuation
			'3317411000001100', --dose
			'3319711000001103' --unit dose
		) OR
	(
		i.denominator_code in ('258773002','258684004') AND --ml, mg
		i.box_code = '3319711000001103' --unit dose
	) OR
	(
		i.denominator_code in ('732981002','10692211000001108') AND --actuation, application
		i.box_code = '3317411000001100' --dose
	)) AND
	i.vppid NOT IN (SELECT drug_concept_code FROM ds_stage);

INSERT INTO ds_stage --simple dosage, same box forms as in VMP OR no box form in VMP, scalable
SELECT DISTINCT
 	i.vppid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	i.qtyval as amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
FROM ds_insert i
JOIN ds_stage d on
	i.drug_concept_code = d.drug_concept_code
WHERE
	(
		(i.box_code = i.unit_1_code OR i.unit_1_code IS NULL) AND
		d.amount_unit IS NOT NULL AND
		i.box_code in --scalable forms only
			(
				'258684004', --mg
				'258774008', --microlitre
				'258773002', --ml
				'258770004', --litre
				'732981002', --actuation
				'3317411000001100', --dose
				'3319711000001103' --unit dose
			)
	)
	and (i.box_code = d.amount_unit)
	and i.vppid NOT IN (SELECT drug_concept_code FROM ds_stage);

INSERT INTO ds_stage --num/denom dosage, same box forms as in VMP OR no box form in VMP, scalable (e.g. solution)
SELECT DISTINCT
 	i.vppid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value * i.qtyval / coalesce (d.denominator_value,1),
	d.numerator_unit,
	i.qtyval as denominator_value,
	d.denominator_unit,
	NULL :: int4 as box_size
FROM ds_insert i
JOIN ds_stage d on
	i.drug_concept_code = d.drug_concept_code
WHERE
	((
		i.box_code = i.unit_1_code OR
		i.unit_1_code IS NULL
	) AND
	d.numerator_unit IS NOT NULL AND
	d.denominator_unit IS NOT NULL AND
	i.box_code in --scalable forms only
		(
			'258684004', --mg
			'258774008', --microlitre
			'258773002', --ml
			'258770004', --litre
			'732981002', --actuation
			'3317411000001100', --dose
			'3319711000001103' --unit dose
		)
		) AND
	i.vppid NOT IN (SELECT drug_concept_code FROM ds_stage);

INSERT INTO ds_stage
with to_insert as --some additional fixes to num/den given forms
	(
		SELECT DISTINCT
			d.vppid, d.qtyval, d.box_code, d.drug_concept_code,
			d.ingredient_concept_code, d.amount_value, d.amount_name,
			d.denominator_value, d.denominator_code,d.denominator_name
		FROM ds_insert d
		JOIN ds_stage a on
			d.drug_concept_code = a.drug_concept_code
		WHERE
			vppid NOT IN (SELECT drug_concept_code FROM ds_stage) AND
			denominator_code IS NOT NULL
	)
SELECT
	vppid as drug_concept_code,
	ingredient_concept_code,
	NULL :: int4,
	NULL :: varchar,
	amount_value * qtyval / coalesce (denominator_value, 1) as numerator_value,
	amount_name as numerator_unit,
	qtyval as denominator_value,
	denominator_name as denominator_unit,
	NULL :: int4
FROM to_insert
WHERE denominator_code = box_code AND
	vppid NOT IN (SELECT drug_concept_code FROM ds_stage);

--Add VMPP drugs that don't have dosage on VMP level
INSERT INTO ds_stage
with ingred_count as
	(
		SELECT i.concept_code_1
		FROM internal_relationship_stage i
		JOIN drug_concept_stage d2 on
			d2.concept_code = i.concept_code_2 AND
			d2.concept_class_id = 'Ingredient'
		GROUP BY i.concept_code_1
		HAVING count (i.concept_code_2) = 1
	)
SELECT
	p.vppid as drug_concept_code,
	d2.concept_code as ingredient_concept_code,
	p.qtyval as amount_value,
	u.info_desc as amount_unit,
	NULL :: int4,
	NULL :: varchar,
	NULL :: int4,
	NULL :: varchar,
	NULL :: int4
FROM internal_relationship_stage i
JOIN ingred_count c on
	c.concept_code_1 = i.concept_code_1
JOIN drug_concept_stage d2 on
	d2.concept_code = i.concept_code_2 AND
	d2.concept_class_id = 'Ingredient'
JOIN vmps v on
	v.vpid = i.concept_code_1
JOIN vmpps p on
	v.vpid = p.vpid
JOIN UNIT_OF_MEASURE u on
	u.cd = p.qty_uomcd
LEFT JOIN ds_stage s on
	s.drug_concept_code = i.concept_code_1
WHERE
	s.drug_concept_code IS NULL AND
	/*lower (d2.concept_name) not LIKE '%homeopathic%' AND
	lower (v.nm) not LIKE '%generic%' ANDf
	v.df_indcd != '1'*/
		(
			d2.concept_code = '387398009' OR --Podophyllum resin
			d2.concept_code = '398628008' OR --Activated charcoal
			d2.concept_name LIKE '% oil' OR
			d2.concept_name LIKE '% liquid extract' OR
			v.nm LIKE '% powder'
		) AND
	p.vppid NOT IN (SELECT drug_concept_code FROM ds_stage)
;

/*
--The table with the same purpose as tomap_vmps_ds
--CREATE TABLE tomap_vmpps_ds_backup AS (SELECT * FROM tomap_vmpps_ds)
--DROP TABLE IF EXISTS tomap_vmpps_ds;

CREATE TABLE tomap_vmpps_ds as
SELECT DISTINCT
	vppid as drug_concept_code, nm as drug_name, d.ingredient_concept_code, d.ingredient_name, d.amount_value, d.amount_code, d.amount_name, d.denominator_value, d.denominator_code, d.denominator_name, NULL :: int4 as amount
FROM ds_insert d
JOIN ds_stage a on
	d.drug_concept_code = a.drug_concept_code
WHERE
	vppid NOT IN (SELECT drug_concept_code FROM ds_stage) AND
	vppid NOT IN (SELECT drug_concept_code FROM tomap_vmpps_ds)
;
*/

DELETE FROM ds_stage WHERE drug_concept_code in (SELECT drug_concept_code FROM tomap_vmpps_ds);

INSERT INTO ds_stage
SELECT
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_name,
	NULL :: int4,
	NULL :: varchar,
	NULL :: int4,
	NULL :: varchar,
	amount
FROM tomap_vmpps_ds
WHERE denominator_code IS NULL;

INSERT INTO ds_stage
SELECT
	drug_concept_code,
	ingredient_concept_code,
	NULL :: int4,
	NULL :: varchar,
	amount_value,
	amount_name,
	denominator_value,
	denominator_name,
	amount
FROM tomap_vmpps_ds
WHERE denominator_code IS NOT NULL;

--Doses only on VMPP level, no VMP entry
with counter as
	(
		SELECT vpid
		FROM virtual_product_ingredient
		GROUP BY vpid
		HAVING count (isid) = 1
	)
INSERT INTO ds_stage
SELECT
	p.vppid as drug_concept_code,
	coalesce (r.isidnew,i.isid) as ingredient_concept_code,
	p.qtyval as amount_value,
	u.info_desc as amount_unit,
	NULL :: int4,
	NULL :: varchar,
	NULL :: int4,
	NULL :: varchar,
	NULL :: int4
FROM vmpps p
JOIN virtual_product_ingredient i using (vpid)
JOIN UNIT_OF_MEASURE u on u.cd = p.qty_uomcd
JOIN counter o using (vpid)
LEFT JOIN ingred_replacement r on r.isidprev = i.isid
LEFT JOIN devices d using (vpid)
LEFT JOIN ds_stage s on p.vppid = s.drug_concept_code
LEFT JOIN pc_stage c on c.pack_concept_code = p.vppid
WHERE
	u.cd in	( '258682000','258770004','258773002') AND
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
JOIN ds_stage d1 on
	v.vpid = d1.drug_concept_code
JOIN drug_concept_stage x on
	x.concept_code = v.vpid
LEFT JOIN ds_stage d2 on
	v.vppid = d2.drug_concept_code
WHERE
	d2.drug_concept_code IS NULL AND
	v.qty_uomcd = '3319711000001103';

-- actuations (3317411000001100 dose)
INSERT INTO ds_stage
SELECT
	v.vppid,
	d1.ingredient_concept_code,
	NULL :: int4 as amount_value,
	NULL :: varchar as amount_unit,
	d1.numerator_value * v.qtyval,
	d1.numerator_unit,
	v.qtyval,
	d1.denominator_unit,
	NULL :: int4
FROM vmpps v
JOIN ds_stage d1 on
	v.vpid = d1.drug_concept_code
JOIN drug_concept_stage x on
	x.concept_code = v.vpid
LEFT JOIN ds_stage d2 on
	v.vppid = d2.drug_concept_code
WHERE
	d2.drug_concept_code IS NULL AND
	v.qty_uomcd = '3317411000001100' AND
	d1.denominator_unit IS NOT NULL;

--inherit AMPPs FROM VMPPs
INSERT INTO ds_stage
SELECT DISTINCT
	a.appid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
FROM ds_stage d
JOIN ampps a on
	d.drug_concept_code = a.vppid;

--remove denominator values for VMPs AND AMPs with df_indcd = 2
UPDATE ds_stage d
SET
	numerator_value = d.numerator_value / d.denominator_value,
	denominator_value = NULL
WHERE
	denominator_unit IS NOT NULL AND
	denominator_value IS NOT NULL AND
	(
		exists
			(
				SELECT
				FROM vmps
				WHERE
					vpid = d.drug_concept_code AND
					df_indcd = '2'
			) OR
		exists
			(
				SELECT
				FROM amps a
				JOIN vmps v on
					a.vpid = v.vpid
				WHERE
					a.apid = d.drug_concept_code AND
					v.df_indcd = '2'
			)
	);

--udfs is given in spoonfuls
UPDATE ds_stage d
SET
	numerator_value = d.numerator_value / d.denominator_value,
	denominator_value = NULL
WHERE
	drug_concept_code in
		(
			SELECT vpid FROM vmps WHERE unit_dose_uomcd in ('733015007'/*,'258773002'*/) --spoonful, ml
				UNION ALL
			SELECT apid FROM vmps JOIN amps using (vpid) WHERE unit_dose_uomcd in ('733015007'/*,'258773002'*/) --spoonful, ml
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
	denominator_unit in ('hour', 'dose');

UPDATE ds_stage
SET
	numerator_value =
	case
		when box_size > 10 then box_size * numerator_value
		else numerator_value
	end,
	denominator_value =
	case
		when box_size > 10 then box_size
		else NULL
	end,
	box_size = NULL
WHERE
	denominator_unit in ('application','actuation') AND
	denominator_value = 1;

--split 3511411000001105 Aluminium hydroxide / Magnesium carbonate co-gel
-- --> 3511711000001104 Aluminium hydroxide dried
-- --> 387401007 Magnesium carbonate
DELETE FROM ds_stage --since we don't have exact dosages when we split it
WHERE drug_concept_code in (SELECT concept_code_1 FROM internal_relationship_stage WHERE concept_code_2 = '3511411000001105');

INSERT INTO internal_relationship_stage
SELECT
	concept_code_1,
	'3511711000001104'
FROM internal_relationship_stage
WHERE concept_code_2 = '3511411000001105';

INSERT INTO internal_relationship_stage
SELECT
	concept_code_1,
	'387401007'
FROM internal_relationship_stage
WHERE concept_code_2 = '3511411000001105';

DELETE FROM ds_stage d
WHERE ingredient_concept_code in ('229862008','9832211000001107','24581311000001102','3511411000001105','3577911000001100','4727611000001109','412166009','50213009') --solvents (Syrup, Ether solvent) AND unsplittable ingredients, chloride ion
and not exists --not only ingredient
	(
		SELECT x.concept_code_1
		FROM internal_relationship_stage x
		JOIN drug_concept_stage c on
			c.concept_code = x.concept_code_2 AND
			c.concept_class_id = 'Ingredient'
		WHERE x.concept_code_1 = d.drug_concept_code
		GROUP BY x.concept_code_1
		HAVING count (x.concept_code_2) = 1
	);

DELETE FROM internal_relationship_stage i
WHERE concept_code_2 in ('229862008','9832211000001107','24581311000001102','3511411000001105','3577911000001100','4727611000001109','412166009','50213009')
and not exists --not only ingredient
	(
		SELECT x.concept_code_1
		FROM internal_relationship_stage x
		JOIN drug_concept_stage c on
			c.concept_code = x.concept_code_2 AND
			c.concept_class_id = 'Ingredient'
		WHERE x.concept_code_1 = i.concept_code_1
		GROUP BY x.concept_code_1
		HAVING count (x.concept_code_2) = 1
	);

DELETE FROM ds_stage WHERE amount_unit = 'cm'; -- parsing artifact

--replace unit codes with names for boiler
UPDATE drug_concept_stage
SET	concept_code = concept_name
WHERE concept_class_id = 'Unit';

DELETE FROM ds_stage d --removes duplicates among semisolid drug dosages
WHERE
	denominator_unit = 'ml' AND
	exists
		(
			SELECT
			FROM ds_stage x
			WHERE
				denominator_unit != 'ml' AND
				d.drug_concept_code = x.drug_concept_code
		);



UPDATE drug_concept_stage
SET	concept_code = concept_name
WHERE concept_class_id = 'Unit';

DELETE FROM ds_stage d --removes duplicates among inhaled drug dosages
WHERE
	denominator_unit = 'dose' AND
	exists
		(
			SELECT
			FROM ds_stage x
			WHERE
				denominator_unit != 'dose' AND
				d.drug_concept_code = x.drug_concept_code
		);

--if the ingredient amount is given in mls, transform to 1000 mg -- unless it's a gas
CREATE OR REPLACE VIEW nongas2fix AS
SELECT DISTINCT ingredient_concept_code
FROM ds_stage
WHERE
	numerator_unit IN ('ml') OR
	amount_unit IN ('ml')

	EXCEPT

SELECT c.concept_code --use SNOMED to find gas descendants
FROM ancestor_snomed a
JOIN concept c on
	c.concept_id = a.descendant_concept_id
JOIN concept c2 on
	c2.concept_id = a.ancestor_concept_id AND
	c2.concept_code in ('74947009','765040008'); --Gases, Inert gases, Gaseous substance

UPDATE ds_stage
SET
	amount_value = amount_value * 1000,
	amount_unit = 'mg'
WHERE
	amount_unit = 'ml' AND
	ingredient_concept_code in (SELECT ingredient_concept_code FROM nongas2fix);

UPDATE ds_stage
SET
	numerator_value = numerator_value * 1000,
	numerator_unit = 'mg'
WHERE
	numerator_unit = 'ml' AND
	ingredient_concept_code in (SELECT ingredient_concept_code FROM nongas2fix);

--Remove drugs without or with incomplete attributes in ds_stage attribute (check for mappings in relationship to concept file)
--! check the mappings before delete
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

--replace relations to ingredients in irs with ones FROM ds_stage
DELETE FROM internal_relationship_stage
WHERE
	concept_code_1 in (SELECT drug_concept_code FROM ds_stage) AND
	concept_code_2 in (SELECT concept_code FROM drug_concept_stage WHERE concept_class_id = 'Ingredient');

INSERT INTO internal_relationship_stage
SELECT
	drug_concept_code,
	ingredient_concept_code
FROM ds_stage;

--reuse only_1_pack to preserve packs with only 1 drug as this exact component
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
	NULL :: int4 as box_size
FROM ds_stage d
JOIN only_1_pack o on
	o.drug_concept_code = d.drug_concept_code AND
	o.pack_concept_code NOT IN (SELECT x.drug_concept_code FROM ds_stage x); --orphan concepts may already have had entry despite being a pack (4161311000001109)



--! Step 10. Map attributes except Brand Names AND Suppliers to concept
DROP TABLE IF EXISTS tomap_ingredients;

CREATE TABLE tomap_ingredients as
SELECT DISTINCT
	c1.concept_id as snomed_id,
	s.concept_code as source_code,
	s.concept_name as source_name,
	coalesce (c0.concept_id, c4.concept_id, c3.concept_id, c2.concept_id, cn2.concept_id, cn.concept_id) as concept_id,
	coalesce (c0.concept_name, c4.concept_name, c3.concept_name, c2.concept_name, cn2.concept_name, cn.concept_name) as concept_name,
	coalesce (c0.vocabulary_id, c4.vocabulary_id, c3.vocabulary_id, c2.vocabulary_id, cn2.vocabulary_id, cn.vocabulary_id) as vocabulary_id,
	coalesce (c0.concept_class_id, c4.concept_class_id, c3.concept_class_id, c2.concept_class_id, cn2.concept_class_id, cn.concept_class_id) as concept_class_id,
	coalesce (r0.precedence,1) as precedence
FROM drug_concept_stage s

LEFT JOIN r_to_c_all r0 on
	lower (r0.concept_name) = s.concept_name AND
	r0.concept_class_id = 'Ingredient'
LEFT JOIN concept c0 on
	c0.concept_id = r0.concept_id

--mapping with source given relations
LEFT JOIN concept c1 on
	c1.vocabulary_id = 'SNOMED' AND
	c1.concept_code = s.concept_code
LEFT JOIN concept_relationship r on
	r.relationship_id = 'SNOMED - RxNorm eq' AND
	r.concept_id_1 = c1.concept_id AND
	r.invalid_reason IS NULL
LEFT JOIN concept c2 on
	c2.concept_id = r.concept_id_2 AND
	c2.concept_class_id != 'Brand Name' AND
	c2.invalid_reason IS NULL
LEFT JOIN concept_relationship r2 on
	r2.concept_id_1 = c2.concept_id AND
	c2.concept_class_id = 'Precise Ingredient' AND
	r2.invalid_reason IS NULL AND
	r2.relationship_id = 'Form of'
LEFT JOIN concept c3 on
	c3.concept_id = r2.concept_id_2 AND
	c3.invalid_reason IS NULL
LEFT JOIN ds_new_ingreds n on --manual ingredients
	n.concept_code = s.concept_code
LEFT JOIN concept c4 on
	c4.concept_id = n.ingredient_id

--direct (lower) name equivalency
LEFT JOIN concept cn2 on
	s.concept_name = cn2.concept_name AND
	cn2.standard_concept = 'S' AND
	cn2.vocabulary_id in ('RxNorm', 'RxNorm Extension') AND
	cn2.concept_class_id = 'Ingredient'

LEFT JOIN concept cn on
	cn.standard_concept = 'S' AND
	cn.vocabulary_id in ('RxNorm', 'RxNorm Extension') AND
	cn.concept_class_id = 'Ingredient' AND
	lower (regexp_replace (s.concept_name,'(^([DL]){1,2}-)|((pollen )?allergen )|( (light|heavy|sodium|anhydrous|dried|solution|distilled|\w{0,}hydrate(d)?|compound|hydrochloride|bromide)$)|"','')) = lower (cn.concept_name)

WHERE
	s.concept_class_id = 'Ingredient' AND
	s.concept_code NOT IN (SELECT isidprev FROM ingred_replacement);

DELETE FROM tomap_ingredients WHERE concept_class_id = 'Precise Ingredient'; --caused by multiple 'SNOMED - RxNorm eq' relations without proper transition to molecular ingredient

DELETE FROM tomap_ingredients t --remove NULLs FROM ambiguous mappings
WHERE
	t.concept_id IS NULL AND
	1 !=
		(
			SELECT count (1)
			FROM tomap_ingredients x
			WHERE x.source_code = t.source_code
		);

--for ambiguous mappings pick ones with the closest names (e.g. Levenshtein's algorithm)
with lev as
	(
		SELECT source_code, min (devv5.levenshtein (source_name, concept_name)) as dif
		FROM tomap_ingredients
		GROUP BY source_code
	)
DELETE FROM tomap_ingredients t
WHERE
	source_code in
		(
			SELECT source_code
			FROM tomap_ingredients
			GROUP BY source_code
			HAVING count (concept_id) > 1
		) AND
	devv5.levenshtein (source_name, concept_name) > (SELECT dif FROM lev WHERE lev.source_code = t.source_code);

--for ambiguous mappings with the same levenstein distance, pick one with the longest name
DELETE FROM tomap_ingredients WHERE (source_code, concept_id) IN
(SELECT source_code, concept_id FROM
(SELECT *, row_number() over (partition by source_code, source_name, precedence ORDER BY length(concept_name) DESC) AS priority
FROM tomap_ingredients
WHERE
	source_code in
		(
			SELECT source_code
			FROM tomap_ingredients
			GROUP BY source_code
			HAVING count (concept_id) > 1
		)
) a
WHERE a.priority > 1);


/*
--Create backup just in case
--CREATE TABLE tomap_ingreds_man_backup AS (SELECT * FROM tomap_ingreds_man)
DROP TABLE IF EXISTS tomap_ingreds_man;

--Previous version
--CREATE TABLE tomap_ingreds_man as
SELECT DISTINCT
	t.source_code,
	t.source_name,
	c.concept_id,
	c.concept_name,
	c.vocabulary_id,
	t.precedence
FROM tomap_ingredients t
LEFT JOIN concept c on
	c.concept_id = t.concept_id AND
	c.standard_concept = 'S' AND
	c.concept_class_id = 'Ingredient'
WHERE
	t.concept_id IS NULL AND
	t.source_code in (SELECT concept_code_2 FROM internal_relationship_stage) AND
	t.source_code in (SELECT source_code FROM tomap_ingredients) AND
	t.source_code NOT IN (SELECT source_code FROM tomap_ingreds_man)

--Current version to keep mapping from backup
--CREATE TABLE tomap_ingreds_man as
SELECT DISTINCT
	t.source_code,
	t.source_name,
    tb.concept_id,
	c.concept_code,
    c.concept_name,
    c.concept_class_id,
    c.standard_concept,
    c.invalid_reason,
    c.domain_id,
	c.vocabulary_id,
	tb.precedence
FROM tomap_ingredients t
LEFT JOIN tomap_ingreds_man_backup tb on
    tb.source_code = t.source_code
LEFT JOIN concept c on
	c.concept_id = tb.concept_id AND
	c.standard_concept = 'S' AND
	c.concept_class_id = 'Ingredient'
WHERE
	t.concept_id IS NULL AND
	t.source_code in (SELECT concept_code_2 FROM internal_relationship_stage) AND
	t.source_code in (SELECT source_code FROM tomap_ingredients);

--The table was manually curated and reuploaded to the same table
--TRUNCATE tomap_ingreds_man;
*/


DELETE FROM tomap_ingreds_man
WHERE source_code NOT IN (SELECT source_code FROM tomap_ingredients);

INSERT INTO relationship_to_concept
SELECT DISTINCT
	source_code as concept_code_1,
	'dm+d' as vocabulary_id_1,
	concept_id as concept_id_2,
	coalesce (precedence,1),
	NULL :: int4 as conversion_factor
FROM tomap_ingreds_man
WHERE
	concept_id IS NOT NULL AND
	source_code IN (SELECT concept_code FROM drug_concept_stage) AND
	source_code NOT IN (SELECT concept_code_1 FROM relationship_to_concept);

INSERT INTO relationship_to_concept
SELECT DISTINCT
	source_code,
	'dm+d',
	concept_id,
	1,
	NULL :: int4
FROM tomap_ingredients
WHERE
	concept_id IS NOT NULL AND
	source_code NOT IN
		(
			SELECT source_code
			FROM tomap_ingreds_man
			WHERE concept_id IS NOT NULL
		);


/*
DROP TABLE IF EXISTS tomap_units_man
;
-- CREATE TABLE tomap_units_man as
SELECT
	concept_code as concept_code_1,
	concept_name as source_name,
	NULL :: int4 as concept_id_2,
	NULL :: varchar (255) as concept_name,
	NULL :: numeric  as conversion_factor
FROM drug_concept_stage
WHERE concept_class_id = 'Unit' AND
	exists
		(
			SELECT FROM ds_stage
			WHERE
				concept_code = amount_unit OR
				concept_code = numerator_unit OR
				concept_code = denominator_unit
		) AND
	concept_name NOT IN (SELECT source_name FROM tomap_units_man)
;
--Mapped and reuploaded to the same table
--TRUNCATE tomap_units_man;
*/;

INSERT INTO relationship_to_concept
SELECT
	source_name,
	'dm+d' as vocabulary_id_1,
	concept_id_2,
	1 as precedence,
	coalesce (conversion_factor,1)
FROM tomap_units_man;

/*
DROP TABLE IF EXISTS tomap_forms
;
-- CREATE TABLE tomap_forms as
SELECT
	concept_code as source_code,
	concept_name as source_name,
	NULL :: int4 as mapped_id,
	NULL :: varchar as mapped_name,
	NULL :: int4 as precedence
FROM drug_concept_stage
WHERE
	concept_class_id = 'Dose Form' AND
	concept_code NOT IN (SELECT concept_code FROM tomap_forms)
;
*/

INSERT INTO relationship_to_concept
SELECT
	source_code,
	'dm+d' as vocabulary_id_1,
	mapped_id,
	coalesce (precedence,1),
	NULL :: int4
FROM tomap_forms;

ALTER TABLE ds_stage -- add mapped ingredient's concept_id to aid next step in dealing with duplicates
ADD concept_id int4;

UPDATE ds_stage
SET concept_id =
	(
		SELECT concept_id_2
		FROM relationship_to_concept
		WHERE
			concept_code_1 = ingredient_concept_code AND
			precedence = 1
	);

--Fix ingredients that got replaced/mapped as same one (e.g. Sodium ascorbate + Ascorbic acid => Ascorbic acid)
DROP TABLE IF EXISTS ds_split;

CREATE TABLE ds_split as
SELECT DISTINCT
	drug_concept_code,
	min (ingredient_concept_code :: bigint) over (partition by drug_concept_code, concept_id) :: varchar as ingredient_concept_code, --one at random
	sum (amount_value) over (partition by drug_concept_code, concept_id) as amount_value,
	amount_unit,
	sum (numerator_value) over (partition by drug_concept_code, concept_id) as numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	NULL :: int4 as box_size,
	concept_id
FROM ds_stage
WHERE
	(drug_concept_code, concept_id) in
	(
		SELECT drug_concept_code, concept_id
		FROM ds_stage
		GROUP BY drug_concept_code, concept_id
		HAVING COUNT(*) > 1
	);

DELETE FROM ds_stage
WHERE
	(drug_concept_code, concept_id) in
	(
		SELECT drug_concept_code, concept_id
		FROM ds_split
	);

INSERT INTO ds_stage
SELECT *
FROM ds_split;

ALTER TABLE ds_stage
DROP COLUMN concept_id;

UPDATE ds_stage d -- if source does not give all denominators for all ingredients
SET
	(numerator_value, numerator_unit) = (d.amount_value, d.amount_unit),
	(amount_value, amount_unit) = (NULL,NULL),
	(denominator_value, denominator_unit) =
		(
			SELECT DISTINCT x.denominator_value, x.denominator_unit
			FROM ds_stage x
			WHERE
				x.denominator_unit IS NOT NULL AND
				x.drug_concept_code = d.drug_concept_code
		)
WHERE
	d.denominator_unit IS NULL AND
	exists
		(
			SELECT
			FROM ds_stage s
			WHERE
				s.drug_concept_code = d.drug_concept_code AND
				s.denominator_unit IS NOT NULL
		);

--final fix ('dose unit' is ambiguous in source data)
UPDATE ds_stage
SET
	(amount_value, amount_unit) = (numerator_value, numerator_unit),
	(numerator_value, numerator_unit,denominator_value, denominator_unit) = (NULL,NULL,NULL,NULL)
WHERE
	denominator_unit = 'unit dose' AND
	ingredient_concept_code = '38686006';

UPDATE ds_stage
SET	(denominator_value, denominator_unit) = (NULL, 'actuation')
WHERE denominator_unit = 'unit dose';

DELETE FROM internal_relationship_stage -- replace ingredients with ones FROM ds_stage (since it was reworked a mano) WHERE applicable
WHERE
	exists (SELECT FROM ds_stage WHERE drug_concept_code = concept_code_1) AND
	exists (SELECT FROM drug_concept_stage WHERE concept_class_id = 'Ingredient' AND concept_code = concept_code_2);

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	drug_concept_code,
	ingredient_concept_code
FROM ds_stage;

--1 ml given by source IS NOT always 1 ml in reality
DROP TABLE IF EXISTS fix_1ml;

CREATE TABLE fix_1ml as
SELECT vpid
FROM ds_stage, drug_concept_stage, vmps
WHERE
	(denominator_value, denominator_unit) = (1,'ml') AND
	drug_concept_code = concept_code AND
	vpid = drug_concept_code AND
	not (concept_name LIKE '%/1ml%' OR concept_name LIKE '% 1ml%') AND
	source_concept_class_id = 'VMP' AND
	((udfs, udfs_uomcd) != (1,'258773002') OR udfs IS NULL);

INSERT INTO fix_1ml
SELECT vppid FROM vmpps, ds_stage
WHERE
	vpid in (SELECT vpid FROM fix_1ml) AND
	vppid = drug_concept_code AND
	(qtyval, qty_uomcd) != (1,'258773002') AND
	(denominator_value, denominator_unit) = (1,'ml');

INSERT INTO fix_1ml
SELECT apid FROM amps
JOIN fix_1ml using (vpid);

INSERT INTO fix_1ml
SELECT appid FROM ampps
JOIN fix_1ml on vpid = vppid;

UPDATE ds_stage
SET
	denominator_value = NULL,
	box_size = NULL
WHERE
	drug_concept_code in
		(
			SELECT vpid FROM fix_1ml
		);


--! Step 11. Find AND map Brand Names (using SNOMED logic), map suppliers

--NOTE: despite that some VMPs AND VMPPs have Brand Names in their names, we purposefully only build relations FROM AMPs AND AMPPs.
--VMPS are identical to Clinical Drugs by design. They are virtual products that are not meant to have Supplier OR a Brand Name
--Also, "Generic %BRAND_NAME%" format is being gradually phased out with dm+d UPDATEs.

DROP TABLE IF EXISTS brands;

CREATE TABLE brands as --all brand names given by UK SNOMED
	(
		SELECT c2.concept_id as brand_id, c2.concept_code as brand_code, c2.concept_class_id, replace (c2.concept_name, ' - brand name','') as brand_name
		FROM concept_relationship cr
		JOIN concept cx on
			cr.concept_id_1 = cx.concept_id AND
			cx.vocabulary_id = 'SNOMED' AND
			cx.concept_code = '9191801000001103' --NHS dm+d trade family
		JOIN concept c2 on
			cr.concept_id_2 = c2.concept_id
		--Taking only pharmacological products (previous approach resulted in bugs due to changes in Snomed)
	    WHERE c2.concept_class_id = 'Pharma/Biol Product'
	);

UPDATE brands
SET brand_name = regexp_replace(brand_name, ' \(.*\)$', '')
WHERE brand_name ILIKE '%(%';

DROP TABLE IF EXISTS amps_to_brands;

CREATE TABLE amps_to_brands as --AMPs to snomed Brand Names by proper relations
SELECT DISTINCT d.concept_code, d.concept_name, b.brand_code, b.brand_name--, NULL :: int4 mapped_id
FROM drug_concept_stage d
JOIN concept c on
	c.vocabulary_id = 'SNOMED' AND
	c.concept_code = d.concept_code AND
	d.source_concept_class_id = 'AMP' AND
	d.domain_id = 'Drug'
JOIN concept_relationship r on
	c.concept_id = r.concept_id_1
JOIN brands b on
	b.brand_id = r.concept_id_2
WHERE
	d.source_concept_class_id = 'AMP' AND
	d.domain_id = 'Drug';

INSERT INTO amps_to_brands
SELECT DISTINCT d.concept_code, d.concept_name, s.brand_code, s.brand_name
FROM drug_concept_stage d
LEFT JOIN amps_to_brands b1 using (concept_code)
JOIN amps_to_brands s on
	s.concept_name = d.concept_name
WHERE
	d.source_concept_class_id = 'AMP' AND
	d.domain_id = 'Drug' AND
	b1.concept_code IS NULL;

DROP TABLE IF EXISTS tofind_brands; --finding brand names by name match AND manual work;
--AVOF-339
DELETE FROM amps_to_brands WHERE brand_name LIKE 'Co-%';

CREATE TABLE tofind_brands as
with ingred_relat as
	(
		SELECT i.concept_code_1, i.concept_code_2, d.concept_name
		FROM internal_relationship_stage i
		JOIN drug_concept_stage d on
			d.concept_class_id = 'Ingredient' AND
			d.concept_code = i.concept_code_2 AND
			i.concept_code_1 in
				(
					SELECT c1.concept_code
					FROM drug_concept_stage c1
					JOIN internal_relationship_stage ix on
						ix.concept_code_1 = c1.concept_code
					JOIN drug_concept_stage c2 on
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
	i.concept_name as concept_name_2,
	length (regexp_replace (d.concept_name,' .*$','')) as min_length
FROM drug_concept_stage d
LEFT JOIN ingred_relat i on
	i.concept_code_1 = d.concept_code
WHERE
	d.source_concept_class_id = 'AMP' AND
	d.domain_id = 'Drug' AND
	d.concept_code NOT IN (SELECT concept_code FROM amps_to_brands);

DELETE FROM tofind_brands --single ingredient, concept is named after ingredient
WHERE
	/*regexp_match
		(
			lower (concept_name),
			regexp_replace (lower (concept_name_2),' .*$', '')
		) IS NOT NULL*/
	concept_name ILIKE regexp_replace ((concept_name_2),' .*$', '') || '%';

DELETE FROM tofind_brands
WHERE
	concept_name LIKE 'Vitamin %' OR
	concept_name LIKE 'Arginine %' OR
	concept_name LIKE 'Benzoi%' OR
	regexp_match (concept_name,'^([A-Z ]+ [\w.%/]+ (\(.*\) )?\/ )+[A-Z ]+ [\w.%/]+( \(.*\) )? [\w. ]+$','im') IS NOT NULL --listed multiple ingredients AND strengths without a BN
;

DROP TABLE IF EXISTS b_temp;
DROP TABLE IF EXISTS x_temp;
CREATE INDEX idx_tf_b on tofind_brands USING GIN ((lower(concept_name)) devv5.gin_trgm_ops);;
ANALYZE tofind_brands;

DROP TABLE IF EXISTS rx_concept;
CREATE TABLE rx_concept as
SELECT
	c.concept_id,
	c.concept_name,
	c.vocabulary_id
FROM concept c
WHERE
	c.vocabulary_id in ('RxNorm', 'RxNorm Extension') AND
	c.concept_class_id = 'Brand Name' AND
	c.invalid_reason IS NULL;

CREATE INDEX IF NOT EXISTS idx_tf_c ON rx_concept USING GIN ((lower(concept_name)) devv5.gin_trgm_ops);
ANALYZE rx_concept;
DELETE FROM rx_concept r1
WHERE exists
	(
		SELECT
		FROM rx_concept r2
		WHERE
			lower (r1.concept_name) = lower (r2.concept_name) AND
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
		(
			SELECT DISTINCT
				b.concept_code,
				b.concept_name,
				c.concept_id as brand_id,
				c.concept_name as brand_name,
				c.vocabulary_id,
				length (c.concept_name) as score,
				b.min_length --prevent match by cutoff words
			FROM tofind_brands b
			LEFT JOIN rx_concept c on
				lower (b.concept_name) LIKE lower (c.concept_name) || '%'
		);

DROP TABLE IF EXISTS b_temp; --name match;
CREATE TABLE b_temp as
with max_score as
	(
		SELECT
			concept_code,
			max (score) over (partition by concept_code) as score
		FROM x_temp x
		WHERE min_length <= score --cut off shorter than first word
	)
SELECT DISTINCT x.concept_code, x.concept_name, x.brand_id, x.brand_name
FROM x_temp x
JOIN max_score m using (concept_code, score);

DELETE FROM tofind_brands --found
WHERE concept_code in (SELECT concept_code FROM b_temp);

with brand_extract as
	(
		SELECT DISTINCT s.brand_code, b.brand_name
		FROM b_temp b
		LEFT JOIN amps_to_brands s using (brand_name)
	),
brands_assigned as --assign OMOP codes
	(
		SELECT
			brand_name,
			coalesce (brand_code, 'OMOP' || nextval ('new_seq')) as brand_code
		FROM brand_extract
	)
INSERT INTO amps_to_brands
SELECT
	b.concept_code,
	b.concept_name,
	a.brand_code,
	b.brand_name
FROM b_temp b
JOIN brands_assigned a using (brand_name)
--Only for drugs without brands already
WHERE b.concept_code NOT IN (
    SELECT concept_code FROM amps_to_brands
    WHERE brand_code IS NOT NULL
    );


/*
DROP TABLE IF EXISTS tofind_brands_man;
-- CREATE TABLE tofind_brands_man as
SELECT
	concept_code,
	concept_name,
	NULL :: int4 as brand_id,
	trim (regexp_replace (concept_name, ' .*$','')) :: varchar as brand_name

FROM tofind_brands
WHERE concept_code NOT IN (SELECT concept_code FROM tofind_brands_man)
;

TRUNCATE tofind_brands_man;
*/

/*delete from tofind_brands_man
where concept_code not in (select concept_code from tofind_brands)*/
DELETE FROM amps_to_brands
WHERE concept_code IN (SELECT concept_code FROM tofind_brands_man);

INSERT INTO amps_to_brands --assign codes to manually found brands
with man_brands as
	(
		SELECT DISTINCT s.brand_code, t.brand_name
		FROM tofind_brands_man t
		LEFT JOIN amps_to_brands s using (brand_name)
		WHERE t.brand_name IS NOT NULL
	),
brand_codes as
	(
		SELECT
			coalesce (brand_code, 'OMOP' || nextval ('new_seq')) as brand_code, --prevent duplicating by reusing codes
			brand_name
		FROM man_brands
	)
SELECT
	t.concept_code,
	t.concept_name,
	o.brand_code,
	t.brand_name
FROM tofind_brands_man t
JOIN brand_codes o on lower (o.brand_name) = lower (t.brand_name);

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
	brand_code AS concept_code,
	TO_DATE('1970-01-01','YYYY-MM-DD') valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason,
	'Brand Name'
FROM amps_to_brands;

DROP TABLE IF EXISTS brand_replace;

CREATE TABLE brand_replace as
--brand names FROM different sources may have the same name, replace with the smallest code
--numeric SNOMED codes are therefore preferred over OMOP codes (string comparisment rules)
SELECT DISTINCT
	concept_code,
	min (concept_code) over (partition by concept_name) as true_code
FROM drug_concept_stage
WHERE concept_class_id = 'Brand Name';

DELETE FROM brand_replace
WHERE true_code = concept_code;

DELETE FROM drug_concept_stage
WHERE concept_code in (SELECT concept_code FROM brand_replace);

--AMPs to Brand Names
INSERT INTO internal_relationship_stage
SELECT DISTINCT
	s.concept_code,
	coalesce (r.true_code, s.brand_code)
FROM amps_to_brands s
LEFT JOIN brand_replace r on
	s.brand_code = r.concept_code;

--AMPPS to Brand Names
INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.appid,
	coalesce (r.true_code, b.brand_code)
FROM amps_to_brands b
JOIN ampps a on
	a.apid = b.concept_code
LEFT JOIN brand_replace r on
	b.brand_code = r.concept_code;

DROP TABLE IF EXISTS tomap_bn;

--Mapping BNs
CREATE TABLE tomap_bn as
with preex_m as
	(
		SELECT DISTINCT --Manual relations
			c.concept_code as concept_code,
			b.brand_name as concept_name,
			cc.concept_id as mapped_id,
			cc.concept_name as mapped_name
		FROM tofind_brands_man b
		JOIN drug_concept_stage c on
			b.brand_name = c.concept_name AND
			c.concept_class_id = 'Brand Name'
		JOIN concept cc on
			b.brand_id = cc.concept_id

			UNION

		SELECT DISTINCT --previously obtained name match
			c.concept_code,
			b.brand_name,
			b.brand_id,
			b.brand_name
		FROM b_temp b
		JOIN drug_concept_stage c on
			b.brand_name = c.concept_name AND
			c.concept_class_id = 'Brand Name' AND
			c.invalid_reason IS NULL

			UNION

		SELECT DISTINCT --Previous manual map (optional)
			s.concept_code,
			s.concept_name,
			coalesce (c2.concept_id, c.concept_id),
			coalesce (c2.concept_name, c.concept_name)
		FROM brands_by_lena l
		JOIN drug_concept_stage s on
			s.concept_name  = l.brand_name AND
			s.concept_class_id = 'Brand Name'
		JOIN concept c on
			l.concept_id = c.concept_id AND
			(
				c.invalid_reason = 'U' OR
				c.invalid_reason IS NULL
			)
		LEFT JOIN concept_relationship r on
			c.concept_id = r.concept_id_1 AND
			r.relationship_id = 'Concept replaced by' AND
			r.invalid_reason IS NULL
		LEFT JOIN concept c2 on
			c2.concept_id = r.concept_id_2

/*
			union

		SELECT --complete name match
			s.concept_code,
			s.concept_name,
			c.concept_id,
			c.concept_name
		FROM drug_concept_stage s
		JOIN concept c on
			s.concept_class_id = 'Brand Name' AND
			regexp_replace (lower (s.concept_name),'\W','') = regexp_replace (lower (c.concept_name),'\W','') AND
			c.vocabulary_id in ('RxNorm', 'RxNorm Extension') AND
			c.concept_class_id = 'Brand Name' AND
			c.invalid_reason IS NULL*/
	)
SELECT DISTINCT
	s.concept_code,
	s.concept_name,
	m.mapped_id,
	m.mapped_name
FROM drug_concept_stage s
LEFT JOIN preex_m m using (concept_code, concept_name)
WHERE s.concept_class_id = 'Brand Name';

INSERT INTO tomap_bn --complete name match
SELECT
	a.concept_code,
	a.concept_name,
	c.concept_id,
	c.concept_name
FROM tomap_bn a
JOIN concept c on
	regexp_replace (lower (a.concept_name),'\W','') = regexp_replace (lower (c.concept_name),'\W','') AND
	c.vocabulary_id in ('RxNorm', 'RxNorm Extension') AND
	c.concept_class_id = 'Brand Name' AND
	c.invalid_reason IS NULL
WHERE a.mapped_id IS NULL;

DELETE FROM tomap_bn t
WHERE
	mapped_id IS NULL AND
	exists (SELECT FROM tomap_bn x WHERE x.mapped_id IS NOT NULL AND t.concept_code = x.concept_code);

DELETE FROM tomap_bn t
--keep RxN concept instead if RxE
WHERE
	(SELECT vocabulary_id FROM concept WHERE concept_id = t.mapped_id) = 'RxNorm Extension' AND
	exists
		(
			SELECT
			FROM concept c
			JOIN tomap_bn x on
				x.mapped_id = c.concept_id AND
				x.concept_code = t.concept_code AND
				c.vocabulary_id = 'RxNorm'
		);

DELETE FROM tomap_bn b
--keep more correct name
WHERE
	devv5.word_similarity(concept_name, mapped_name) <
		(
			SELECT min (devv5.word_similarity(concept_name, mapped_name))
			FROM tomap_bn b2
			WHERE
				b.concept_code = b2.concept_code
		);

DELETE FROM tomap_bn
--manually extracted brands will have no mappings
WHERE
	concept_name in (SELECT brand_name FROM tofind_brands_man) AND
	mapped_id IS NULL AND
	concept_code LIKE 'OMOP%';

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
			c.vocabulary_id in ('RxNorm')
	)
WHERE
	t1.mapped_id IS NULL AND
	t1.concept_name LIKE '% XL'
;

/*
DROP TABLE IF EXISTS tomap_bn_man;

-- CREATE TABLE tomap_bn_man as
SELECT
	t.concept_code,
	t.concept_name,
	c.concept_id as mapped_id,
    c.concept_code AS target_concept_code,
	c.concept_name as mapped_name,
    c.concept_class_id AS concept_class_id,
    c.standard_concept AS standard_concept,
    c.invalid_reason AS invalid_reason,
    c.domain_id,
	c.vocabulary_id
FROM tomap_bn t
LEFT JOIN concept c on
	lower (t.concept_name) LIKE lower (c.concept_name) || ' %' AND -- this match will have to be checked manually
	c.concept_class_id = 'Brand Name' AND
	c.invalid_reason IS NULL AND
	c.vocabulary_id LIKE 'RxN%'
WHERE
	t.mapped_id IS NULL AND
	t.concept_code NOT IN (SELECT concept_code FROM tomap_bn_man)
;

ALTER TABLE tomap_bn_man
ALTER COLUMN invalid_reason TYPE varchar(50);

ALTER TABLE tomap_bn_man
ALTER COLUMN standard_concept TYPE varchar(50);

--Manual curation and reuploading to the same table
--TRUNCATE tomap_bn_man;
*/

--UPDATE source names
UPDATE tomap_bn_man b
SET
	concept_name = (SELECT concept_name FROM drug_concept_stage WHERE concept_code = b.concept_code);

--UPDATE obvious misses (simplifies refresh)
UPDATE tomap_bn_man b
SET
	(mapped_id, mapped_name) =
	(
		SELECT DISTINCT concept_id, concept_name
		FROM concept
		WHERE
			vocabulary_id in ('RxNorm') AND
			lower (concept_name) = lower (b.concept_name) AND
			concept_class_id = 'Brand Name' AND
			invalid_reason IS NULL
	)
WHERE mapped_id IS NULL;

UPDATE tomap_bn_man b
SET
	(mapped_id, mapped_name) =
	(
		SELECT DISTINCT concept_id, concept_name
		FROM concept
		WHERE
			vocabulary_id in ('RxNorm Extension') AND
			concept_name = b.concept_name AND
			concept_class_id = 'Brand Name' AND
			invalid_reason IS NULL
	)
WHERE mapped_id IS NULL;

DELETE FROM tomap_bn WHERE concept_code in (SELECT concept_code FROM tomap_bn_man WHERE mapped_id IS NOT NULL);

INSERT INTO tomap_bn
SELECT concept_code,concept_name,mapped_id,mapped_name
FROM tomap_bn_man
WHERE mapped_id IS NOT NULL;

INSERT INTO relationship_to_concept
SELECT DISTINCT
	c.concept_code,
	'dm+d',
	mapped_id,
	1,
	NULL :: numeric
FROM tomap_bn t
JOIN drug_concept_stage c on
	c.concept_name = t.concept_name AND
	c.concept_class_id = 'Brand Name'
WHERE t.mapped_id IS NOT NULL
;

/*
DROP TABLE IF EXISTS tomap_supplier_man;

-- CREATE TABLE tomap_supplier_man as
SELECT d.concept_code, d.concept_name,
    c.concept_code AS target_concept_code,
    c.concept_id as mapped_id,
	c.concept_name as mapped_name,
    c.concept_class_id AS concept_class_id,
    c.standard_concept AS standard_concept,
    c.invalid_reason AS invalid_reason,
    c.domain_id,
	c.vocabulary_id,
    NULL::int AS precedence
FROM drug_concept_stage d
LEFT JOIN concept c on
	c.concept_class_id = 'Supplier' AND
	c.vocabulary_id = 'RxNorm Extension' AND
	c.invalid_reason IS NULL AND
	regexp_replace (lower (c.concept_name),'\W','') = regexp_replace (lower (d.concept_name),'\W','')
WHERE
	d.concept_class_id = 'Supplier' AND
	d.concept_code in (SELECT concept_code_2 FROM internal_relationship_stage)
	and d.concept_code NOT IN (SELECT concept_code FROM tomap_supplier_man)
order by length (d.concept_name)
;

ALTER TABLE tomap_supplier_man
ALTER COLUMN invalid_reason TYPE varchar(50);

ALTER TABLE tomap_supplier_man
ALTER COLUMN standard_concept TYPE varchar(50);

--TRUNCATE tomap_supplier_man;
*/

UPDATE drug_concept_stage --replace cut name with source-given one
SET concept_name = (SELECT name_old FROM supplier WHERE cd = concept_code)
WHERE concept_class_id = 'Supplier';

--UPDATE obvious misses (simplifies refresh)
UPDATE tomap_supplier_man s
SET concept_name = (SELECT d.concept_name FROM drug_concept_stage d WHERE d.concept_code = s.concept_code AND d.concept_class_id = 'Supplier')
WHERE s.concept_code in (SELECT concept_code FROM drug_concept_stage);

UPDATE tomap_supplier_man b
SET
	(mapped_id, mapped_name) =
	(
		SELECT DISTINCT concept_id, concept_name
		FROM concept
		WHERE
			vocabulary_id in ('RxNorm') AND
			lower (concept_name) = lower (b.concept_name) AND
			concept_class_id = 'Supplier' AND
			invalid_reason IS NULL
	)
WHERE mapped_id IS NULL;

UPDATE tomap_supplier_man b
SET
	(mapped_id, mapped_name) =
	(
		SELECT DISTINCT concept_id, concept_name
		FROM concept
		WHERE
			vocabulary_id in ('RxNorm Extension') AND
			concept_name = b.concept_name AND
			concept_class_id = 'Supplier' AND
			invalid_reason IS NULL
	)
WHERE mapped_id IS NULL;

INSERT INTO relationship_to_concept
SELECT
	concept_code,
	'dm+d',
	mapped_id,
	precedence as precedence,
	NULL :: int4 as conversion_factor
FROM tomap_supplier_man
WHERE mapped_id IS NOT NULL;

--duplicates within RxE do this
DELETE FROM relationship_to_concept r
WHERE exists
	(
		SELECT
		FROM concept c
		JOIN relationship_to_concept x on
			c.concept_class_id = 'Brand Name' AND
			x.concept_id_2 = c.concept_id AND
			x.concept_code_1 = r.concept_code_1 AND
			x.concept_id_2 < r.concept_id_2
	);

ANALYZE relationship_to_concept;
ANALYZE internal_relationship_stage;

--some drugs in IRS have duplicating ingredient entries over relationship_to_concept mappings
with multiing as
	(
		SELECT i.concept_code_1, r.concept_id_2, min (i.concept_code_2) as preserve_this
		FROM internal_relationship_stage i
		JOIN relationship_to_concept r on
			coalesce (r.precedence,1) = 1 AND --only precedential mappings matter
			i.concept_code_2 = r.concept_code_1
		GROUP BY i.concept_code_1, concept_id_2
		HAVING count (i.concept_code_2) > 1
	)
DELETE FROM internal_relationship_stage r
WHERE
	(r.concept_code_1, r.concept_code_2) in
		(
			SELECT a.concept_code_1, b.concept_code_1
			FROM multiing a
			JOIN relationship_to_concept b on
				a.concept_id_2 = b.concept_id_2 AND
				a.preserve_this != b.concept_code_1
		);



--! Step 12. Some manual fixes for some drugs inc. vaccines
DROP TABLE IF EXISTS covid_vac;

CREATE TABLE covid_vac AS
SELECT vpid AS concept_code
FROM vmps
WHERE vtmid = '39330711000001103'; -- covid vaccines;

INSERT INTO covid_vac
SELECT apid
FROM amps
JOIN covid_vac ON
	concept_code = vpid;

INSERT INTO covid_vac
SELECT vppid
FROM vmpps
JOIN covid_vac ON
	concept_code = vpid;

INSERT INTO covid_vac
SELECT appid
FROM ampps
JOIN covid_vac ON
	concept_code = apid;


/*
DROP TABLE IF EXISTS tomap_varicella
--manually reassign ingredients to distinguish between varicella AND varicella-zoster vaccines
;
-- CREATE TABLE tomap_varicella as
SELECT
	d.source_concept_class_id,
	d.concept_code,
	d.concept_name,
	s.concept_code as ingredient_code,
	s.concept_name as ingredient_name,
	c.concept_id as target_id,
	c.concept_name as target_name
FROM drug_concept_stage d
JOIN internal_relationship_stage i on
	d.concept_code = i.concept_code_1 AND
	concept_code_2 in ('20114111000001107','11170811000001106','38737611000001109')
JOIN drug_concept_stage s on
	i.concept_code_2 = s.concept_code
LEFT JOIN relationship_to_concept r on
	i.concept_code_2 = r.concept_code_1 AND
	r.precedence = 1
LEFT JOIN concept c on
	c.concept_id = r.concept_id_2
WHERE
	d.concept_code NOT IN (SELECT concept_code FROM tomap_varicella)
;

select
	d.source_concept_class_id,
	d.concept_code,
	d.concept_name,
	null as ingredient_code,
	null as ingredient_name,
	null as target_id,
	null as target_name
from drug_concept_stage d
join covid_vac c on
	d.concept_code = c.concept_code
where
	d.concept_code not in (select concept_code from tomap_varicella)
;
*/

DELETE FROM pc_stage WHERE pack_concept_code in (SELECT concept_code FROM tomap_varicella WHERE ingredient_code IS NULL);

DELETE FROM internal_relationship_stage
WHERE concept_code_1 in (select concept_code from tomap_varicella);

DELETE FROM drug_concept_stage
WHERE source_concept_class_id IN ('Ingredient', 'Dose Form', 'Brand Name', 'Supplier') AND concept_code NOT IN (SELECT concept_code_2 FROM internal_relationship_stage);

DELETE FROM relationship_to_concept
WHERE concept_code_1 NOT IN (SELECT concept_code FROM drug_concept_stage);

INSERT INTO relationship_to_concept
SELECT
	concept_code,
	'dm+d',
	target_id,
	1,
	NULL
FROM tomap_varicella;

--Influenza fix to CVX
/*
--nasal
19699211000001101 --> 40213149
--H1N1
16091511000001102 --> 40213186
--Rest
11172111000001100 --> 40213153
11171911000001108 --> 40213153
11172011000001101 --> 40213153
*/

INSERT INTO relationship_to_concept --nasal
SELECT
	concept_code_1,
	'dm+d',
	40213149,
	1,
	NULL
FROM internal_relationship_stage
WHERE concept_code_2 = '19699211000001101'
;

/*
INSERT INTO relationship_to_concept --H1N1
SELECT
	concept_code_1,
	'dm+d',
	40213186,
	1,
	NULL
FROM internal_relationship_stage
WHERE concept_code_2 = '16091511000001102'
;*/

INSERT INTO relationship_to_concept --Rest
SELECT
	concept_code_1,
	'dm+d',
	40213153,
	1,
	NULL
FROM internal_relationship_stage
WHERE concept_code_2 in ('11172111000001100','11171911000001108','11172011000001101','36754911000001103');

DELETE FROM internal_relationship_stage
WHERE concept_code_1 in (SELECT concept_code_1 FROM internal_relationship_stage WHERE concept_code_2 in ('11172111000001100','11171911000001108','11172011000001101',/*'16091511000001102',*/'19699211000001101','36754911000001103'));

DELETE FROM ds_stage
WHERE drug_concept_code in (SELECT drug_concept_code FROM ds_stage WHERE ingredient_concept_code in ('11172111000001100','11171911000001108','11172011000001101',/*'16091511000001102',*/'19699211000001101','36754911000001103'));

--Map 23-valent pneumoc. vaccines to 40213201 pneumococcal polysaccharide vaccine, 23 valent CVX
DELETE FROM internal_relationship_stage
WHERE concept_code_1 in
	(
		SELECT vpid FROM vmps WHERE vpid in ('3439211000001108','3439311000001100') --VMP for 23valent vaccines
			UNION ALL
		SELECT apid FROM amps WHERE vpid in ('3439211000001108','3439311000001100') --AMP
			UNION ALL
		SELECT vppid FROM vmpps WHERE vpid in ('3439211000001108','3439311000001100') --VMPP
			UNION ALL
		SELECT appid FROM vmpps JOIN ampps using (vppid) WHERE vpid in ('3439211000001108','3439311000001100') --AMP
	);

INSERT INTO relationship_to_concept
SELECT DISTINCT
	pneum.vpid,
	'dm+d',
	40213201,
	1,
	NULL :: int4
from
	(
		SELECT vpid FROM vmps WHERE vpid in ('3439211000001108','3439311000001100') --VMP for 23valent vaccines
			UNION ALL
		SELECT apid FROM amps WHERE vpid in ('3439211000001108','3439311000001100') --AMP
			UNION ALL
		SELECT vppid FROM vmpps WHERE vpid in ('3439211000001108','3439311000001100') --VMPP
			UNION ALL
		SELECT appid FROM vmpps JOIN ampps using (vppid) WHERE vpid in ('3439211000001108','3439311000001100') --AMP
	) pneum
;



--! Step 13. More fixes AND shifting OMOP codes to follow sequence in CONCEPT table

DELETE FROM internal_relationship_stage
WHERE concept_code_1 in (SELECT concept_code FROM drug_concept_stage WHERE domain_id = 'Device');

DELETE FROM drug_concept_stage
WHERE
	concept_class_id in ('Ingredient','Dose Form','Supplier','Brand Name') AND
	concept_code NOT IN (SELECT concept_code_2 FROM internal_relationship_stage);

DELETE FROM relationship_to_concept WHERE concept_code_1 NOT IN
	(SELECT concept_code FROM drug_concept_stage);


--OMOP replacement: existing OMOP codes AND shift sequence to after last code in concept
DROP TABLE IF EXISTS code_replace;

CREATE TABLE code_replace as
SELECT
	d.concept_code as old_code,
	c.concept_code as new_code
FROM drug_concept_stage d
LEFT JOIN concept c on
	c.vocabulary_id = d.vocabulary_id AND
	--c.invalid_reason IS NULL AND
	c.concept_name = d.concept_name AND
	c.concept_class_id = d.concept_class_id
WHERE d.concept_code LIKE 'OMOP%';

DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM devv5.concept WHERE concept_code LIKE 'OMOP%'  AND concept_code not LIKE '% %';
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
JOIN amps a on
	a.vpid = d.concept_code_1
JOIN drug_concept_stage x on
	x.concept_class_id in ('Ingredient') AND
	x.concept_code = d.concept_code_2
LEFT JOIN ds_stage s on
	a.apid = s.drug_concept_code
WHERE s.drug_concept_code IS NULL;

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.vppid,
	x.concept_code
FROM internal_relationship_stage d
JOIN vmpps a on
	a.vpid = d.concept_code_1
JOIN drug_concept_stage x on
	x.concept_class_id in ('Ingredient') AND
	x.concept_code = d.concept_code_2
LEFT JOIN ds_stage s on
	a.vppid = s.drug_concept_code
WHERE s.drug_concept_code IS NULL;

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.appid,
	x.concept_code
FROM internal_relationship_stage d
JOIN ampps a on
	a.apid = d.concept_code_1
JOIN drug_concept_stage x on
	x.concept_class_id in ('Ingredient') AND
	x.concept_code = d.concept_code_2
LEFT JOIN ds_stage s on
	a.appid = s.drug_concept_code
WHERE s.drug_concept_code IS NULL;

--Inherit AMP, VMPP AND AMPP Dose Form relations for empty ds_stage entries
INSERT INTO internal_relationship_stage --amp
SELECT DISTINCT
	a.apid,
	x.concept_code
FROM internal_relationship_stage d
JOIN amps a on
	a.vpid = d.concept_code_1
JOIN drug_concept_stage x on
	x.concept_class_id = 'Dose Form' AND
	x.concept_code = d.concept_code_2;

INSERT INTO internal_relationship_stage --vmpp
SELECT DISTINCT
	a.vppid,
	x.concept_code
FROM internal_relationship_stage d
LEFT JOIN only_1_pack o on
	d.concept_code_1 = o.drug_concept_code
JOIN vmpps a on
	a.vpid = coalesce (o.pack_concept_code,d.concept_code_1)
JOIN drug_concept_stage x on
	x.concept_class_id = 'Dose Form' AND
	x.concept_code = d.concept_code_2
WHERE
	not exists
		(
			SELECT
			FROM internal_relationship_stage i
			JOIN drug_concept_stage c on
				i.concept_code_2 = c.concept_code
			WHERE
				c.concept_class_id = 'Dose Form'
		);

INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.appid,
	x.concept_code
FROM internal_relationship_stage d
LEFT JOIN only_1_pack o on
	d.concept_code_1 = o.drug_concept_code
JOIN ampps a on
	a.apid = coalesce (o.pack_concept_code,d.concept_code_1)
JOIN drug_concept_stage x on
	x.concept_class_id = 'Dose Form' AND
	x.concept_code = d.concept_code_2
WHERE
	not exists
		(
			SELECT
			FROM internal_relationship_stage i
			JOIN drug_concept_stage c on
				i.concept_code_2 = c.concept_code
			WHERE
				c.concept_class_id = 'Dose Form'
		);

--ensure correctness of monopacks
DELETE FROM internal_relationship_stage WHERE concept_code_1 in (SELECT pack_concept_code FROM only_1_pack);

INSERT INTO internal_relationship_stage
SELECT
	pack_concept_code,
	concept_code_2
FROM internal_relationship_stage
JOIN only_1_pack on
	drug_concept_code = concept_code_1;

--Deduplication of internal_relationship_stage
DELETE FROM internal_relationship_stage s 
WHERE EXISTS (SELECT 1 FROM internal_relationship_stage s_int 
                WHERE coalesce(s_int.concept_code_1, 'x') = coalesce(s.concept_code_1, 'x')
                  AND coalesce(s_int.concept_code_2, 'x') = coalesce(s.concept_code_2, 'x')
                  AND s_int.ctid > s.ctid);

--optional: remove unused concepts
DELETE FROM drug_concept_stage
WHERE
	concept_class_id in ('Unit') AND
	concept_name NOT IN
		(
			SELECT DISTINCT amount_unit FROM ds_stage WHERE amount_unit IS NOT NULL
				UNION ALL
			SELECT DISTINCT numerator_unit FROM ds_stage WHERE numerator_unit IS NOT NULL
				UNION ALL
			SELECT DISTINCT denominator_unit FROM ds_stage WHERE denominator_unit IS NOT NULL
		)
;
/*UPDATE relationship_to_concept SET precedence = 2 WHERE concept_code_1 in ('3519511000001105','8147711000001108')
;
INSERT INTO relationship_to_concept values ('3519511000001105','dm+d',915553,1,NULL)
;
INSERT INTO relationship_to_concept values ('8147711000001108','dm+d',1353048,1,NULL)*/
;

--No longer needed (refresh 11.2022)
--menotropin split
/*
INSERT INTO drug_concept_stage
--It IS NOT a code FROM source data, it's FROM SNOMED
VALUES (NULL,'Recombinant human luteinizing hormone','Drug','dm+d','Ingredient','S','415248001',to_date ('1970-01-01','YYYY-MM-DD'),to_date ('2099-12-31','YYYY-MM-DD'),NULL,'Ingredient')
;
INSERT INTO relationship_to_concept values ('415248001','dm+d',1589795,1,NULL);

INSERT INTO internal_relationship_stage
SELECT
	concept_code_1,
	'415248001'
FROM internal_relationship_stage
WHERE concept_code_2 = '8203003'
	UNION ALL
SELECT
	concept_code_1,
	'4174011000001101'
FROM internal_relationship_stage
WHERE concept_code_2 = '8203003';
 */

DELETE FROM ds_stage WHERE ingredient_concept_code = '8203003'; --no universally agreed proportion, so can't preserve dosage;

DELETE FROM internal_relationship_stage WHERE concept_code_2 = '8203003';
--DELETE FROM ds_stage WHERE drug_concept_code in ('8981911000001106','8977811000001101','8977711000001109','8977911000001106')


--TODO: either use or delete
/*UPDATE internal_relationship_stage
SET
	concept_code_2 = '385219001'
WHERE
	concept_code_1 in
		(
			'11561211000001103', '11561311000001106', '11561511000001100', '11561711000001105', '11561811000001102', '11561911000001107',
			'11562011000001100', '11562111000001104', '11562611000001107', '11562711000001103', '11562811000001106', '11562911000001101',
			'11563011000001109', '11563111000001105', '11563211000001104', '11563311000001107', '11563411000001100', '11563511000001101',
			'11563611000001102', '11563711000001106', '11927411000001107', '11927511000001106', '11927611000001105', '11927711000001101',
			'11927811000001109', '11928611000001109', '11928711000001100', '11928811000001108', '11928911000001103', '11929011000001107',
			'11929111000001108', '11945311000001106', '13424811000001106', '13424911000001101', '13425011000001101', '13425211000001106',
			'13427011000001108', '13427111000001109', '13427211000001103', '13427311000001106', '13427411000001104', '13427511000001100',
			'13427611000001101', '13427711000001105', '13457911000001106', '13458011000001108', '13458111000001109', '13458211000001103',
			'13458311000001106', '13458411000001104', '13458511000001100', '17213811000001106', '17213911000001101', '17214011000001103',
			'17214511000001106', '17214611000001105', '17214711000001101', '17215411000001108', '17215611000001106', '17215811000001105',
			'17216511000001100', '17216911000001107', '17217011000001106', '17217111000001107', '17243811000001103', '17244111000001107',
			'17244211000001101', '17329211000001106', '17329311000001103', '17329411000001105', '22227211000001107', '22227311000001104',
			'22227411000001106', '22227511000001105', '22227611000001109', '22227711000001100', '22260011000001108', '22260211000001103',
			'22500111000001102', '22500211000001108', '22500311000001100', '22500411000001107', '22745511000001109', '22745611000001108',
			'25556411000001100', '25556511000001101', '25556611000001102', '25556711000001106', '25556811000001103', '25556911000001108',
			'26818911000001104', '26819111000001109', '26819411000001104', '26819611000001101', '26819711000001105', '26819911000001107',
			'26866311000001103', '26866511000001109', '26866911000001102', '26867211000001108', '26867711000001101', '26867911000001104',
			'28235711000001104', '28235811000001107', '28235911000001102', '28236011000001105', '31152311000001103', '31152511000001109',
			'31152611000001108', '31152811000001107', '31152911000001102', '31153011000001105', '347480005', '347485000',
			'347487008', '347489006', '347490002', '34913111000001108', '34913211000001102', '34913311000001105', '34913411000001103',
			'35025311000001100', '35025411000001107', '35025511000001106', '35025611000001105', '35196311000001107', '35196411000001100',
			'35196511000001101', '35196611000001102', '4697111000001103', '4697311000001101', '4697511000001107', '4699211000001103',
			'4699311000001106', '4699411000001104', '4706311000001105', '4706411000001103', '4829311000001106', '4829411000001104',
			'4834411000001100', '4834511000001101', '4863011000001100', '4863111000001104', '4863211000001105', '4863311000001102',
			'4863411000001109', '4863511000001108', '4863611000001107', '4863711000001103', '5005711000001109', '5005811000001101',
			'5005911000001106', '5006011000001103', '5012711000001102', '5013111000001109', '5013511000001100', '5015811000001103',
			'5016511000001108', '5016611000001107', '5017111000001101', '5017211000001107', '5026911000001109', '5027011000001108',
			'5027111000001109', '5027311000001106', '5027511000001100', '5027711000001105', '5043411000001108', '5068011000001100',
			'5068111000001104', '5068211000001105', '5068311000001102', '5069311000001108', '5069411000001101', '5069511000001102',
			'5069611000001103', '5073611000001105', '5073811000001109', '5074111000001100', '5074211000001106', '9319311000001104',
			'9319411000001106', '9320311000001103', '9320411000001105', '9320511000001109', '9320611000001108', '9320911000001102',
			'9321011000001105', '9321111000001106', '9321211000001100', '9367311000001105', '9368111000001109', '9368311000001106',
			'9368511000001100', '9373111000001106', '9373211000001100', '9373311000001108', '9373411000001101', '9373711000001107',
			'9373811000001104', '9373911000001109', '9867211000001100', '9867711000001107', '9867811000001104', '9867911000001109'
		)
and concept_code_2 in ('14964511000001102','385229008')*/

--Manual fixes (refresh 11.2022)
DELETE FROM drug_concept_stage
    WHERE concept_code = '10109701000001106' AND concept_name = 'Lumecare (Carbomer)';


UPDATE ds_stage
SET box_size = NULL
WHERE
	denominator_unit IS NOT NULL AND
	--(box_size = 1 OR denominator_value IS NULL)
	denominator_value IS NULL;

--because of UPDATEs
DELETE FROM relationship_to_concept WHERE concept_code_1 NOT IN (SELECT concept_code FROM drug_concept_stage);



--! Step 14. Manual mapping for attributes, that don't have equivalents
--Manual mapping step
--Major part of relationships in relationship_to_concept table were created automatically
--However, there are still missing mappings (relationships to concept) for certain attributes. Mapping is not required for attributes without links in internal_relationship_stage

--Adding missing mappings from previous iterations
INSERT INTO relationship_to_concept(concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
SELECT dcs.concept_code, dcs.vocabulary_id, r_to_c_all.concept_id,
       coalesce(precedence, 1),
       conversion_factor
FROM r_to_c_all
JOIN drug_concept_stage dcs
ON dcs.concept_name = r_to_c_all.concept_name
    AND dcs.concept_class_id = r_to_c_all.concept_class_id
WHERE dcs.concept_code NOT IN (SELECT concept_code_1 FROM relationship_to_concept);


--Uploaded for manual mapping
--File name: relationship_to_concept_attributes
/*
CREATE TABLE relationship_to_concept_attributes AS
	(SELECT dcs.concept_name, dcs.concept_class_id,
	       NULL AS precedence,
	       c.concept_id AS target_concept_id,
	       c.concept_code AS target_concept_code,
	       c.concept_name AS target_concept_name,
	       c.concept_class_id AS target_concept_class_id,
	       c.standard_concept AS target_standard_concept,
	       c.invalid_reason AS target_invalid_reason,
	       c.domain_id AS target_domain_id,
	       c.vocabulary_id AS target_vocabulary_id
	FROM drug_concept_stage dcs
	LEFT JOIN relationship_to_concept cr ON cr.concept_code_1 = dcs.concept_code
	LEFT JOIN concept c ON LOWER(c.concept_name) = LOWER(dcs.concept_name)
				AND c.concept_class_id = dcs.concept_class_id
				AND c.vocabulary_id LIKE 'RxNorm%'
				AND c.invalid_reason IS NULL
	WHERE cr.concept_code_1 IS NULL
		AND dcs.concept_class_id IN (
			'Ingredient',
			'Brand Name',
			'Dose Form',
			'Supplier'
			)
--If attributes have already been assessed in other manual mapping tables, do not include them
	  --Only dm+d and not OMOP-like concept codes in manual tomap_ tables
	AND dcs.concept_code NOT IN (SELECT concept_code FROM tomap_supplier_man)
	AND dcs.concept_code NOT IN (SELECT source_code FROM tomap_ingreds_man)
	AND dcs.concept_code NOT IN (SELECT source_code FROM tomap_forms)
	AND dcs.concept_code NOT IN (SELECT concept_code FROM tomap_bn_man)

	  --For refreshes to avoid processing the same codes twice
	AND (dcs.concept_name, dcs.concept_class_id) NOT IN (SELECT concept_name, concept_class_id FROM relationship_to_concept_attributes)
	  --There are drugs with these attributes
	AND dcs.concept_code IN (SELECT concept_code_2 FROM internal_relationship_stage)

ORDER BY dcs.concept_class_id)
;

ALTER TABLE relationship_to_concept_attributes
ALTER COLUMN target_standard_concept TYPE varchar(50);

ALTER TABLE relationship_to_concept_attributes
ALTER COLUMN target_invalid_reason TYPE varchar(50);

--Manually map missing concepts and then reupload the table
--TRUNCATE relationship_to_concept_attributes;

 */
--Clean relationship_to_concept from attributes, manually mapped in relationship_to_concept_attributes
with mapping AS (SELECT dcs.concept_code, dcs.concept_name, dcs.concept_class_id
    FROM relationship_to_concept_attributes rtca
    JOIN drug_concept_stage dcs
    ON dcs.concept_name = rtca.concept_name AND dcs.concept_class_id = rtca.concept_class_id
    )

DELETE FROM relationship_to_concept
--SELECT * FROM relationship_to_concept
WHERE concept_code_1 IN (SELECT concept_code FROM mapping)
AND EXISTS(SELECT
           FROM drug_concept_stage dcs
           WHERE dcs.concept_class_id IN (
                                          'Ingredient',
                                          'Brand Name',
                                          'Dose Form',
                                          'Supplier'
               )
    AND dcs.concept_code = relationship_to_concept.concept_code_1
    )
;

--Insertion of manually mapped attributes into relationship_to_concept
INSERT INTO relationship_to_concept
(concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
SELECT DISTINCT dcs.concept_code, dcs.vocabulary_id, rtca.target_concept_id, rtca.precedence::int, NULL::numeric --Change to conversion factor in the rtca if needed
FROM relationship_to_concept_attributes rtca
JOIN drug_concept_stage dcs
    --Concept code changes every time with sequence recreation, therefore use combination of name and concept class id instead
    --Works even if there are duplicate names with different concept codes, if mapping is identical
    ON rtca.concept_class_id = dcs.concept_class_id AND rtca.concept_name = dcs.concept_name
WHERE rtca.target_concept_id != 0 AND rtca.target_concept_id IS NOT NULL
;


--Deduplication of relationship_to_concept
DELETE FROM relationship_to_concept s 
WHERE EXISTS (SELECT 1 FROM relationship_to_concept s_int 
                WHERE coalesce(s_int.concept_code_1, 'x') = coalesce(s.concept_code_1, 'x')
                  AND coalesce(s_int.vocabulary_id_1, 'x') = coalesce(s.vocabulary_id_1, 'x')
                  AND coalesce(s_int.concept_id_2, 'x') = coalesce(s.concept_id_2, 'x')
                  AND coalesce(s_int.precedence, 'x') = coalesce(s.precedence, 'x')
                  AND coalesce(s_int.conversion_factor, 'x') = coalesce(s.conversion_factor, 'x')
                  AND s_int.ctid > s.ctid);

--Deduplication of drug_concept_stage
DELETE FROM drug_concept_stage s 
WHERE EXISTS (SELECT 1 FROM drug_concept_stage s_int 
                WHERE coalesce(s_int.concept_name, 'x') = coalesce(s.concept_name, 'x')
                  AND coalesce(s_int.vocabulary_id, 'x') = coalesce(s.vocabulary_id, 'x')
                  AND coalesce(s_int.concept_class_id, 'x') = coalesce(s.concept_class_id, 'x')
                  AND coalesce(s_int.source_concept_class_id, 'x') = coalesce(s.source_concept_class_id, 'x')
                  AND coalesce(s_int.standard_concept, 'x') = coalesce(s.standard_concept, 'x')
                  AND coalesce(s_int.concept_code, 'x') = coalesce(s.concept_code, 'x')
                  AND coalesce(s_int.possible_excipient, 'x') = coalesce(s.possible_excipient, 'x')
                  AND coalesce(s_int.domain_id, 'x') = coalesce(s.domain_id, 'x')
                  AND coalesce(s_int.valid_start_date, 'x') = coalesce(s.valid_start_date, 'x')
                  AND coalesce(s_int.valid_end_date, 'x') = coalesce(s.valid_end_date, 'x')
                  AND coalesce(s_int.invalid_reason, 'x') = coalesce(s.invalid_reason, 'x')
                  AND s_int.ctid > s.ctid);

--get supplier relations for packs
INSERT INTO internal_relationship_stage
SELECT DISTINCT
	a.appid,
	i.concept_code_2
FROM ampps a
JOIN internal_relationship_stage i on
	a.apid = i.concept_code_1
JOIN pc_stage p on
	p.pack_concept_code = a.appid
JOIN drug_concept_stage d on
	d.concept_code = i.concept_code_2 AND
	d.concept_class_id = 'Supplier'
JOIN drug_concept_stage d1 on
	d1.concept_code = a.appid AND
	d1.domain_id = 'Drug' AND
	d1.source_concept_class_id = 'AMPP';

--marketed products must have either pc_stage OR ds_stage entry
DELETE FROM internal_relationship_stage
WHERE
	concept_code_2 in (SELECT concept_code FROM drug_concept_stage WHERE concept_class_id = 'Supplier') AND
	concept_code_1 NOT IN
		(
			SELECT drug_concept_code
			FROM ds_stage

				UNION ALL

			SELECT pack_concept_code
			FROM pc_stage
		);

--Replaces 'Powder' dose form with more specific forms, guessing FROM name WHERE possible
DROP TABLE IF EXISTS vmps_chain;
CREATE TABLE vmps_chain as
SELECT DISTINCT
	v.vpid, v.vppid, a.apid, a.appid,
	case
		when
			d1.concept_name ILIKE '%oral powder%' OR
			d1.concept_name ILIKE '%sugar%'
		then '14945811000001105' --effervescent powder
		when d1.concept_name ILIKE '%topical%'
		then '385108009' --cutaneous solution
		when d1.concept_name ILIKE '%endotrach%'
		then '11377411000001104' --Powder AND solvent for solution for instillation
		when d1.concept_name ILIKE '% ear %'
		then '385136004' --ear drops
		else '85581007' --Powder
	end as concept_code_2
FROM vmpps v
JOIN ampps a using (vppid)
JOIN internal_relationship_stage i on
	v.vpid = i.concept_code_1 AND
	i.concept_code_2 = '85581007' --Powder
JOIN drug_concept_stage d1 on
	d1.concept_code = i.concept_code_1;

UPDATE internal_relationship_stage i
SET concept_code_2 = (SELECT DISTINCT concept_code_2 FROM vmps_chain WHERE i.concept_code_1 in (vpid, apid, appid, vppid))
WHERE concept_code_2 = '85581007'; --Powder;

DROP TABLE IF EXISTS amps_chain;
--AMP's have licensed route; some are defining
CREATE TABLE amps_chain as
SELECT DISTINCT
	a.apid,
	a.appid,
	case routecd
		when '26643006' then '14945811000001105' --oral powder
		when '6064005' then '385108009' --cutaneous solution
		else '85581007' --Powder
	end as concept_code_2
FROM vmps_chain a
JOIN licensed_route l using (apid)
WHERE
	a.concept_code_2 = '85581007' AND
	l.apid in
		(
			SELECT apid
			FROM licensed_route
			WHERE routecd != '3594011000001102'
			GROUP BY apid
			HAVING count (routecd) = 1
		);

UPDATE internal_relationship_stage i
SET concept_code_2 = (SELECT DISTINCT concept_code_2 FROM amps_chain WHERE i.concept_code_1 in (apid, appid))
WHERE
	concept_code_2 = '85581007' AND --Powder
	exists
		(
			SELECT
			FROM amps_chain
			WHERE concept_code_1 in (apid,appid)
		);

--TODO: tomap_varicella can definately go into dmd_mapped table
DELETE FROM pc_stage WHERE pack_concept_code IN (SELECT concept_code FROM tomap_varicella);
DELETE FROM ds_stage WHERE drug_concept_code IN (SELECT concept_code FROM tomap_varicella);

--same with Liquid
DROP TABLE IF EXISTS vmps_chain;
CREATE TABLE vmps_chain as
SELECT DISTINCT
	v.vpid, v.vppid, a.apid, a.appid,
	case
		when
			d1.concept_name ILIKE '% oral%' OR
			d1.concept_name ILIKE '%sugar%' OR
			d1.concept_name ILIKE '% dental%' OR
			d1.concept_name ILIKE '% tincture%' OR
			d1.concept_name ILIKE '% mixture%' OR
			d1.concept_name ILIKE '%oromucos%' OR
			d1.concept_name ILIKE '% elixir%'
		then '385023001' --oral solution
		when
			d1.concept_name ILIKE '% instil%' OR
			d1.concept_name ILIKE '%periton%' OR
			d1.concept_name ILIKE '%cardiop%' OR
			d1.concept_name ILIKE '%tracheopul%' OR
			d1.concept_name ILIKE '%extraamn%' OR
			d1.concept_name ILIKE '%smallpox%'
		then '385219001' --injectable solution
		when
			d1.concept_name ILIKE '% lotion%' OR
			d1.concept_name ILIKE '% acetone%' OR
			d1.concept_name ILIKE '% scalp%' OR
			d1.concept_name ILIKE '% topical%' OR
			d1.concept_name ILIKE '% skin%' OR
			d1.concept_name ILIKE '% massage%' OR
			d1.concept_name ILIKE '% shower%' OR
			d1.concept_name ILIKE '% rubb%' OR
			d1.concept_name ILIKE '%spirit%'
		then '385108009' --cutaneous solution
		when d1.concept_name ILIKE '% vagin%'
		then '385166006' --vaginal gel
		when
			d1.concept_name ILIKE '%nasal%' OR
			d1.concept_name ILIKE '%nebul%'
		then '385197005' --nebuliser liquid
		else '420699003'
	end as concept_code_2
FROM vmpps v
JOIN ampps a using (vppid)
JOIN internal_relationship_stage i on
	v.vpid = i.concept_code_1 AND
	i.concept_code_2 = '420699003' --Liquid
JOIN drug_concept_stage d1 on
	d1.concept_code = i.concept_code_1;

UPDATE internal_relationship_stage i
SET concept_code_2 = (SELECT DISTINCT concept_code_2 FROM vmps_chain WHERE i.concept_code_1 in (vpid, apid, appid, vppid))
WHERE concept_code_2 = '420699003'; --Liquid

DROP TABLE IF EXISTS amps_chain;

CREATE TABLE amps_chain as
SELECT DISTINCT
	a.apid,
	a.appid,
	case routecd
		when '18679011000001101' then '385197005' --Nebulizer liquid
		when '26643006' then '385023001' --oral solution
		when '372449004' then '385023001' --oral solution
		when '58100008' then '385219001' --injectable solution
		when '6064005' then '385108009' --cutaneous
		else '420699003'
	end as concept_code_2
FROM vmps_chain a
JOIN licensed_route l using (apid)
WHERE 
	a.concept_code_2 = '420699003' AND
	l.apid in 
		(
			SELECT apid 
			FROM licensed_route 
			WHERE routecd != '3594011000001102'
			GROUP BY apid
			HAVING count (routecd) = 1
		);

UPDATE internal_relationship_stage i
SET concept_code_2 = (SELECT DISTINCT concept_code_2 FROM amps_chain WHERE i.concept_code_1 in (apid, appid))
WHERE 
	concept_code_2 = '420699003' AND --Liquid
	exists
		(
			SELECT
			FROM amps_chain
			WHERE concept_code_1 in (apid,appid)
		);


--Change Protease to a correct code
UPDATE internal_relationship_stage
SET concept_code_2 = '387033008'
WHERE concept_code_2 = '14677711000001106';

UPDATE ds_stage
SET ingredient_concept_code = '387033008'
WHERE ingredient_concept_code = '14677711000001106';


--Dropping codes that cause error from pc_stage table
--Included in manual mapping
DELETE FROM pc_stage
WHERE pack_concept_code IN
	(SELECT  p.pack_concept_code
	FROM pc_stage p
	LEFT JOIN ds_stage d ON d.drug_concept_code = p.drug_concept_code
	WHERE d.drug_concept_code IS NULL);

--Dropping codes that cause error from internal_relationship_stage table
--Included in manual mapping
--Manually checked: generic non-real drugs
DELETE FROM internal_relationship_stage
WHERE concept_code_1 IN
	(SELECT concept_code_1
	FROM internal_relationship_stage
	WHERE concept_code_2 IS NULL);


--Manual deletion of incorrect mappings
DELETE FROM relationship_to_concept WHERE concept_code_1 IN
(
'421982008',
'418373003',
'398918002',
'412556009',
'404830004',
'418084002',
'418645008',
'354276001'
    );

--Remove relationships to attributes for concepts, processed manually
DELETE FROM ds_stage WHERE drug_concept_code IN (SELECT source_code FROM dmd_mapped);
DELETE FROM internal_relationship_stage WHERE concept_code_1 IN (SELECT source_code FROM dmd_mapped);
DELETE FROM pc_stage WHERE pack_concept_code IN (SELECT source_code FROM dmd_mapped);
DELETE FROM relationship_to_concept WHERE concept_code_1 IN (SELECT concept_code_1 FROM concept_relationship_manual);


--Changing column types as they should be for BuildRxE
ALTER TABLE relationship_to_concept ALTER COLUMN conversion_factor TYPE numeric;
ALTER TABLE relationship_to_concept ALTER COLUMN precedence TYPE smallint;
ALTER TABLE pc_stage ALTER COLUMN amount TYPE smallint;
ALTER TABLE pc_stage ALTER COLUMN box_size TYPE smallint;
ALTER TABLE ds_stage ALTER COLUMN amount_value TYPE numeric;
ALTER TABLE ds_stage ALTER COLUMN numerator_value TYPE numeric;
ALTER TABLE ds_stage ALTER COLUMN denominator_value TYPE numeric;
ALTER TABLE ds_stage ALTER COLUMN box_size TYPE smallint;


INSERT INTO relationship_to_concept(concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
SELECT source_code,
       'dm+d',
       target_concept_id,
       1,
       NULL
FROM dmd_mapped
WHERE source_code NOT IN (SELECT concept_code_1 FROM concept_relationship_manual) AND target_concept_id != 0;

--At this point, everything should be prepared for BuildRxE run
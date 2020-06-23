-- 0. Pull ancestorship data from non-standard snomed concept relations
--needed because of existing non-standard Substances in SNOMED vocabulary
drop table if exists ancestor_snomed cascade
;
create table ancestor_snomed as
with recursive hierarchy_concepts (ancestor_concept_id,descendant_concept_id, root_ancestor_concept_id, levels_of_separation, full_path) as
  (
        select 
            ancestor_concept_id, descendant_concept_id, ancestor_concept_id as root_ancestor_concept_id,
            levels_of_separation, ARRAY [descendant_concept_id] AS full_path
        from concepts
        union all
        select 
            c.ancestor_concept_id, c.descendant_concept_id, root_ancestor_concept_id,
            hc.levels_of_separation+c.levels_of_separation as levels_of_separation,
            hc.full_path || c.descendant_concept_id as full_path
        from concepts c
        join hierarchy_concepts hc on hc.descendant_concept_id=c.ancestor_concept_id
        WHERE c.descendant_concept_id <> ALL (full_path)
    ),
    concepts as (
        select
            r.concept_id_1 as ancestor_concept_id,
            r.concept_id_2 as descendant_concept_id,
            case when s.is_hierarchical=1 and c1.invalid_reason is null then 1 else 0 end as levels_of_separation
        from concept_relationship r 
        join relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
        join concept c1 on c1.concept_id=r.concept_id_1 and c1.invalid_reason is null AND c1.vocabulary_id='SNOMED'
        join concept c2 on c2.concept_id=r.concept_id_2 and c2.invalid_reason is null AND c2.vocabulary_id='SNOMED'
        where r.invalid_reason is null
    )
    select 
        hc.root_ancestor_concept_id as ancestor_concept_id, 
        hc.descendant_concept_id,
        min(hc.levels_of_separation) as min_levels_of_separation,
        max(hc.levels_of_separation) as max_levels_of_separation
    from hierarchy_concepts hc
    join concept c1 on c1.concept_id=hc.root_ancestor_concept_id and c1.invalid_reason is null
    join concept c2 on c2.concept_id=hc.descendant_concept_id and c2.invalid_reason is null
    GROUP BY hc.root_ancestor_concept_id, hc.descendant_concept_id

	UNION

SELECT c.concept_id AS ancestor_concept_id,
	c.concept_id AS descendant_concept_id,
	0 AS min_levels_of_separation,
	0 AS max_levels_of_separation
FROM concept c
WHERE
	c.vocabulary_id = 'SNOMED' and
	--EXISTS (select 1 from sources.mrconso m where c.concept_code = m.code and m.sab = 'SNOMEDCT_US') and
	c.invalid_reason is null
;
ALTER TABLE ancestor_snomed ADD CONSTRAINT xpkancestor_snomed PRIMARY KEY (ancestor_concept_id,descendant_concept_id);
;
CREATE INDEX idx_sna_descendant ON ancestor_snomed (descendant_concept_id)
;
CREATE INDEX idx_sna_ancestor ON ancestor_snomed (ancestor_concept_id)
;
analyze ancestor_snomed
;

--1. Extract meaningful data from XML source and apply device logic. Manual fix to source data discrepancies
--TODO: use NHS's own tool to create CSV tables from XML

drop table if exists vmpps;
drop table if exists vmps;
drop table if exists ampps;
drop table if exists amps;
drop table if exists licensed_route;
drop table if exists comb_content_v;
drop table if exists comb_content_a;
drop table if exists VIRTUAL_PRODUCT_INGREDIENT;
DROP TABLE IF EXISTS vtms;
drop table if exists ONT_DRUG_FORM;
drop table if exists DRUG_FORM;
drop table if exists ap_ingredient;
drop table if exists INGREDIENT_SUBSTANCES;
drop table if exists COMBINATION_PACK_IND;
drop table if exists COMBINATION_PROD_IND;
drop table if exists UNIT_OF_MEASURE;
drop table if exists FORMS;
drop table if exists SUPPLIER;
drop table if exists DF_INDICATOR;
drop table if exists DMD2ATC;
drop table if exists dmd2bnf;
;
truncate concept_synonym_stage
;
--we are only interested to find brand names that have 'stable' ingredient sets: with one possible ingredient combination
drop table if exists brand_rx
;
create table brand_rx as
with bn_to_i as
	(
		select
			c.concept_id as b_id,
			r.concept_id_2 as i_id,
			c.concept_name as concept_name,
			count (r.concept_id_2) over (partition by c.concept_id) as cnt_direct
		from concept c
		join concept_relationship r on
			r.relationship_id = 'Brand name of' and
			c.concept_id = r.concept_id_1
		join concept c2 on
			c2.concept_class_id = 'Ingredient' and
			c2.concept_id = r.concept_id_2 and
			c2.standard_concept = 'S'
		where
			c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null
	),
bn_to_i_dp as --what possible ingredient sets drug products give us
	(
		select distinct
			c.concept_id as b_id,
			r.concept_id_2 as dp_id,
			d.ingredient_concept_id as i_id,
			count (d.ingredient_concept_id) over (partition by r.concept_id_2) as cnt_drug
		from concept c
		join concept_relationship r on
			r.relationship_id = 'Brand name of' and
			c.concept_id = r.concept_id_1
		join concept c2 on
			c2.concept_class_id != 'Ingredient' and --only combinations and ingredient themselves can have brand names;
			c2.concept_id = r.concept_id_2
		join drug_strength d on
			c2.concept_id = d.drug_concept_id
		join concept c3 on
			d.ingredient_concept_id = c3.concept_id and
			c3.standard_concept = 'S'
		where
			c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null
	)
select distinct
	b.b_id,
	b.concept_name,
	b.i_id
from bn_to_i b
left join bn_to_i_dp d on
	d.b_id = b.b_id and
	b.cnt_direct > d.cnt_drug
where d.b_id is null
;
insert into brand_rx
--preserve also bn that are consistent inside RxN
with bn_to_i as
	(
		select
			c.concept_id as b_id,
			r.concept_id_2 as i_id,
			c.concept_name as concept_name,
			count (r.concept_id_2) over (partition by c.concept_id) as cnt_direct
		from concept c
		join concept_relationship r on
			r.relationship_id = 'Brand name of' and
			c.concept_id = r.concept_id_1
		join concept c2 on
			c2.concept_class_id = 'Ingredient' and
			c2.concept_id = r.concept_id_2 and
			c2.standard_concept = 'S'
		where
			c.concept_id not in (select b_id from brand_rx) and --avoid duplication
			c.vocabulary_id = 'RxNorm' and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null and
			exists 
			-- there are RxNorm Drug products with r.concept_id_2 as an ingredient
				(
					select
					from drug_strength d
					join concept x on
						d.drug_concept_id = x.concept_id and
						x.vocabulary_id = 'RxNorm' and
						x.concept_class_id != 'Ingredient' and
						d.ingredient_concept_id = r.concept_id_2
					-- with that brand name and ingredient
					join concept_relationship cr on
						cr.concept_id_1 = x.concept_id and
						relationship_id = 'Has brand name' and
						cr.concept_id_2 = c.concept_id
					where d.invalid_reason is null
				)
	),
bn_to_i_dp as --what possible ingredient sets drug RxN products give us
	(
		select distinct
			c.concept_id as b_id,
			r.concept_id_2 as dp_id,
			d.ingredient_concept_id as i_id,
			count (d.ingredient_concept_id) over (partition by r.concept_id_2) as cnt_drug
		from concept c
		join concept_relationship r on
			r.relationship_id = 'Brand name of' and
			c.concept_id = r.concept_id_1
		join concept c2 on
			c2.concept_class_id != 'Ingredient' and --only combinations and ingredient themselves can have brand names;
			c2.concept_id = r.concept_id_2
		join drug_strength d on
			c2.concept_id = d.drug_concept_id
		join concept c3 on
			d.ingredient_concept_id = c3.concept_id and
			c3.standard_concept = 'S'
		where
			c.concept_id not in (select b_id from brand_rx) and --avoid duplication
			c.vocabulary_id = 'RxNorm' and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null and
			d.invalid_reason is null
	)
select distinct
	b.b_id,
	b.concept_name,
	b.i_id
from bn_to_i b
left join bn_to_i_dp d on
	d.b_id = b.b_id and
	b.cnt_direct > d.cnt_drug
where d.b_id is null
;
create table vtms as
SELECT
	devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::VARCHAR) NM,
	unnest(xpath('./VTMID/text()', i.xmlfield))::VARCHAR VTMID,
	unnest(xpath('./VTMIDPREV/text()', i.xmlfield))::VARCHAR VTMIDPREV,
	to_date(unnest(xpath('./VTMIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') VTMIDDT,
	unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR INVALID
FROM (
	SELECT unnest(xpath('/VIRTUAL_THERAPEUTIC_MOIETIES/VTM', i.xmlfield)) xmlfield
	FROM sources.f_vtm2 i
	) AS i
;
update vtms set invalid = '0' where invalid is null
;
create table vmpps as
SELECT
	devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::VARCHAR) nm,
	unnest(xpath('./VPPID/text()', i.xmlfield))::VARCHAR VPPID,
	unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('./QTYVAL/text()', i.xmlfield))::VARCHAR::FLOAT QTYVAL,
	unnest(xpath('./QTY_UOMCD/text()', i.xmlfield))::VARCHAR QTY_UOMCD,
	unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR INVALID,
	devv5.py_unescape(unnest(xpath('./ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCT_PACK/VMPPS/VMPP', i.xmlfield)) xmlfield
	FROM sources.f_vmpp2 i
	) AS i
;	
create table licensed_route as
SELECT
	unnest(xpath('./APID/text()', i.xmlfield))::VARCHAR APID,
	unnest(xpath('./ROUTECD/text()', i.xmlfield))::VARCHAR ROUTECD
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/LICENSED_ROUTE/LIC_ROUTE', i.xmlfield)) xmlfield
	FROM sources.f_amp2 i
	) AS i
;
update vmpps set invalid = '0' where invalid is null
;
create table COMB_CONTENT_v as
SELECT
	unnest(xpath('./PRNTVPPID/text()', i.xmlfield))::VARCHAR PRNTVPPID,
	unnest(xpath('./CHLDVPPID/text()', i.xmlfield))::VARCHAR CHLDVPPID
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCT_PACK/COMB_CONTENT/CCONTENT', i.xmlfield)) xmlfield
	FROM sources.f_vmpp2 i
	) AS i
;
create table VMPS as
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::VARCHAR) nm,
	to_date(unnest(xpath('./VPIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') VPIDDT,
	unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR INVALID,
	unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('./VPIDPREV/text()', i.xmlfield))::VARCHAR VPIDPREV,
	unnest(xpath('./VTMID/text()', i.xmlfield))::VARCHAR VTMID,
	devv5.py_unescape(unnest(xpath('./NMPREV/text()', i.xmlfield))::VARCHAR) NMPREV,
	to_date(unnest(xpath('./NMDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') NMDT,
	devv5.py_unescape(unnest(xpath('./ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM,
	unnest(xpath('./COMBPRODCD/text()', i.xmlfield))::VARCHAR COMBPRODCD,
	unnest(xpath('./NON_AVAILDT/text()', i.xmlfield))::VARCHAR NON_AVAILDT,
	unnest(xpath('./DF_INDCD/text()', i.xmlfield))::VARCHAR DF_INDCD,
	unnest(xpath('./UDFS/text()', i.xmlfield))::VARCHAR::FLOAT UDFS,
	unnest(xpath('./UDFS_UOMCD/text()', i.xmlfield))::VARCHAR UDFS_UOMCD,
	unnest(xpath('./UNIT_DOSE_UOMCD/text()', i.xmlfield))::VARCHAR UNIT_DOSE_UOMCD,
	unnest(xpath('./PRES_STATCD/text()', i.xmlfield))::VARCHAR PRES_STATCD
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/VMPS/VMP', i.xmlfield)) xmlfield
	FROM sources.f_vmp2 i
	) AS i
;
update vmps set invalid = '0' where invalid is null
;
--keep the newest replacement only (*prev)
update vmps v
set
	nmprev = null,
	vpidprev = null
where
	v.vpidprev is not null and
	exists
		(
			select
			from vmps u
			where
				u.vpidprev = v.vpidprev and
				v.nmdt < u.nmdt
		)
;
create table VIRTUAL_PRODUCT_INGREDIENT as
SELECT unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('./ISID/text()', i.xmlfield))::VARCHAR ISID,
	unnest(xpath('./BS_SUBID/text()', i.xmlfield))::VARCHAR BS_SUBID,
	unnest(xpath('./STRNT_NMRTR_VAL/text()', i.xmlfield))::VARCHAR::FLOAT STRNT_NMRTR_VAL,
	unnest(xpath('./STRNT_NMRTR_UOMCD/text()', i.xmlfield))::VARCHAR STRNT_NMRTR_UOMCD,
	unnest(xpath('./STRNT_DNMTR_VAL/text()', i.xmlfield))::VARCHAR::FLOAT STRNT_DNMTR_VAL,
	unnest(xpath('./STRNT_DNMTR_UOMCD/text()', i.xmlfield))::VARCHAR STRNT_DNMTR_UOMCD
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/VIRTUAL_PRODUCT_INGREDIENT/VPI', i.xmlfield)) xmlfield
	FROM sources.f_vmp2 i
	) AS i
;
--replace nanoliters with ml in amount
update VIRTUAL_PRODUCT_INGREDIENT
set 
	strnt_nmrtr_val = strnt_nmrtr_val * 0.000001,
	strnt_nmrtr_uomcd = '258773002' -- mL
where strnt_nmrtr_uomcd = '282113003' -- nL
;
create table ONT_DRUG_FORM as
SELECT unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('./FORMCD/text()', i.xmlfield))::VARCHAR FORMCD
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/ONT_DRUG_FORM/ONT', i.xmlfield)) xmlfield
	FROM sources.f_vmp2 i
	) AS i
;
create table DRUG_FORM as
SELECT unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('./FORMCD/text()', i.xmlfield))::VARCHAR FORMCD
FROM (
	SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/DRUG_FORM/DFORM', i.xmlfield)) xmlfield
	FROM sources.f_vmp2 i
	) AS i
;
create table amps as
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::VARCHAR) nm,
	unnest(xpath('./APID/text()', i.xmlfield))::VARCHAR APID,
	unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR INVALID,
	devv5.py_unescape(unnest(xpath('./NMPREV/text()', i.xmlfield))::VARCHAR) NMPREV,
	devv5.py_unescape(unnest(xpath('./ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM,
	to_date(unnest(xpath('./NMDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') NMDT,
	unnest(xpath('./SUPPCD/text()', i.xmlfield))::VARCHAR SUPPCD,
	unnest(xpath('./COMBPRODCD/text()', i.xmlfield))::VARCHAR COMBPRODCD,
	unnest(xpath('./LIC_AUTHCD/text()', i.xmlfield))::VARCHAR LIC_AUTHCD
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP', i.xmlfield)) xmlfield
	FROM sources.f_amp2 i
	) AS i	
;
update amps set invalid = '0' where invalid is null
;
create table ap_ingredient as
SELECT unnest(xpath('./APID/text()', i.xmlfield))::VARCHAR APID,
	unnest(xpath('./ISID/text()', i.xmlfield))::VARCHAR ISID,
	unnest(xpath('./STRNTH/text()', i.xmlfield))::VARCHAR::FLOAT STRNTH,
	unnest(xpath('./UOMCD/text()', i.xmlfield))::VARCHAR UOMCD
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PRODUCTS/AP_INGREDIENT/AP_ING', i.xmlfield)) xmlfield
	FROM sources.f_amp2 i
	) AS i
;
	create table ampps as
	SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::VARCHAR) nm,
		unnest(xpath('./APPID/text()', i.xmlfield))::VARCHAR APPID,
		unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR INVALID,
		devv5.py_unescape(unnest(xpath('./ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM,
		unnest(xpath('./VPPID/text()', i.xmlfield))::VARCHAR VPPID,
		unnest(xpath('./APID/text()', i.xmlfield))::VARCHAR APID,
		unnest(xpath('./COMBPACKCD/text()', i.xmlfield))::VARCHAR COMBPACKCD,
		to_date(unnest(xpath('./DISCDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') DISCDT
	FROM (
		SELECT unnest(xpath('/ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP', i.xmlfield)) xmlfield
		FROM sources.f_ampp2 i
		) AS i
;
update ampps set invalid = '0' where invalid is null
;
create table COMB_CONTENT_A as
SELECT unnest(xpath('./PRNTAPPID/text()', i.xmlfield))::VARCHAR PRNTAPPID,
	unnest(xpath('./CHLDAPPID/text()', i.xmlfield))::VARCHAR CHLDAPPID
FROM (
	SELECT unnest(xpath('/ACTUAL_MEDICINAL_PROD_PACKS/COMB_CONTENT/CCONTENT', i.xmlfield)) xmlfield
	FROM sources.f_ampp2 i
	) AS i
;
create table INGREDIENT_SUBSTANCES as
SELECT devv5.py_unescape(unnest(xpath('./NM/text()', i.xmlfield))::VARCHAR) nm,
	unnest(xpath('./ISID/text()', i.xmlfield))::VARCHAR ISID,
	to_date(unnest(xpath('./ISIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') ISIDDT,
	unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR INVALID,
	unnest(xpath('./ISIDPREV/text()', i.xmlfield))::VARCHAR ISIDPREV
FROM (
	SELECT unnest(xpath('/INGREDIENT_SUBSTANCES/ING', i.xmlfield)) xmlfield
	FROM sources.f_ingredient2 i
	) AS i
;
update INGREDIENT_SUBSTANCES set invalid = '0' where invalid is null
;
create table COMBINATION_PACK_IND as
SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
	unnest(xpath('./CD/text()', i.xmlfield))::VARCHAR CD
FROM (
	SELECT unnest(xpath('/LOOKUP/COMBINATION_PACK_IND/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i
;
create table COMBINATION_PROD_IND as
SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
	unnest(xpath('./CD/text()', i.xmlfield))::VARCHAR CD
FROM (
	SELECT unnest(xpath('/LOOKUP/COMBINATION_PROD_IND/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i
;
create table UNIT_OF_MEASURE as
SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
	unnest(xpath('./CD/text()', i.xmlfield))::VARCHAR CD,
	to_date(unnest(xpath('./CDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') CDDT
FROM (
	SELECT unnest(xpath('/LOOKUP/UNIT_OF_MEASURE/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i
;
create table FORMS as
SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
	unnest(xpath('./CD/text()', i.xmlfield))::VARCHAR CD,
	to_date(unnest(xpath('./CDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') CDDT
FROM (
	SELECT unnest(xpath('/LOOKUP/FORM/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i
;
create table SUPPLIER as
with supp_temp as
	(
		SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
			unnest(xpath('./CD/text()', i.xmlfield))::VARCHAR CD,
			to_date(unnest(xpath('./CDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') CDDT,
			unnest(xpath('./INVALID/text()', i.xmlfield))::VARCHAR INVALID
		FROM (
			SELECT unnest(xpath('/LOOKUP/SUPPLIER/INFO', i.xmlfield)) xmlfield
			FROM sources.f_lookup2 i
			) AS i
	),
supp_cut as
	(
		select 
			t.*,
			regexp_replace(
			t.info_desc,
			',?( (Corporation|Division|Research|EU|Marketing|Medical|Product(s)?|Health(( )?care)?|Europe|(Ph|F)arma(ceutical(s)?(,)?)?|international|group|lp|kg|A\/?S|AG|srl|Ltd|UK|Plc|GmbH|\(.*\)|Inc(.)?|AB|s\.?p?\.?a\.?|(& )?Co(.)?))+( 1)?$'
			,'','gim') as name_cut
		from supp_temp t
	)
select
	case
		when length (name_cut) > 4 then name_cut
		else info_desc
	end as info_desc,
	info_desc as name_old,
	cd,
	cddt,
	invalid
from supp_cut
;
update Supplier set invalid = '0' where invalid is null
;
update SUPPLIER
set info_desc = replace (info_desc, ' Company', '')
where 
	info_desc not like '%& Company%' and
	info_desc not like '%and Company%'
;
update SUPPLIER
set info_desc = replace (info_desc, ' Ltd', '')
;
create table DF_INDICATOR as
SELECT devv5.py_unescape(unnest(xpath('./DESC/text()', i.xmlfield))::VARCHAR) INFO_DESC,
	unnest(xpath('./CD/text()', i.xmlfield))::VARCHAR CD
FROM (
	SELECT unnest(xpath('/LOOKUP/DF_INDICATOR/INFO', i.xmlfield)) xmlfield
	FROM sources.f_lookup2 i
	) AS i
;
--Not used at the time?
CREATE TABLE dmd2atc as
SELECT unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('./ATC/text()', i.xmlfield))::VARCHAR ATC
FROM (
	SELECT unnest(xpath('/BNF_DETAILS/VMPS/VMP', i.xmlfield)) xmlfield
	FROM sources.dmdbonus i
	) AS i
;
create table dmd2bnf as
	(
		SELECT unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR DMD_ID,
			unnest(xpath('./BNF/text()', i.xmlfield))::VARCHAR BNF,
			'VMP' as concept_class_id
		FROM (
			SELECT unnest(xpath('/BNF_DETAILS/VMPS/VMP', i.xmlfield)) xmlfield
			FROM sources.dmdbonus i
			) AS i

			UNION

		SELECT unnest(xpath('./VPID/text()', i.xmlfield))::VARCHAR DMD_ID,
			unnest(xpath('./BNF/text()', i.xmlfield))::VARCHAR BNF,
			'AMP' as concept_class_id
		FROM (
			SELECT unnest(xpath('/BNF_DETAILS/AMPS/AMP', i.xmlfield)) xmlfield
			FROM sources.dmdbonus i
			) AS i
	)
;
drop table if exists fake_supp
;
create table fake_supp as
select cd, info_desc 
from supplier 
where 
	info_desc in 
		(
			'Special Order', 'Extemp Order', 'Drug Tariff Special Order',
			'Flavour Not Specified', 'Approved Prescription Services','Disposable Medical Equipment',
			'Oxygen Therapy'
		) or
	info_desc like 'Imported%'
;/*
delete from comb_content_a 
where prntappid in
(
	select prntappid from comb_content_a
	group by prntappid
	having count (chldappid) = 1
)
;
delete from comb_content_v
where prntvppid in
(
	select prntvppid from comb_content_v
	group by prntvppid
	having count (chldvppid) = 1
)*/
;
create index idx_vmps on vmps (lower (nm) varchar_pattern_ops)
;
create index idx_vmps_vpid on vmps (vpid)
;
create index idx_amps_vpid on amps (vpid)
;
create index idx_vpi_vpid on virtual_product_ingredient (vpid)
;
create index idx_vmps_nm on vmps (nm varchar_pattern_ops)
;
create index idx_amps_nm on amps (nm varchar_pattern_ops)
;
analyze amps
;
analyze vmps
;
analyze ampps
;
analyze vmpps
;
analyze virtual_product_ingredient
;
drop table if exists devices;
--TO DO: improve devices detection using ancestor_snomed
create table devices as
with offenders1 as 
	(
		select distinct nm,apid,vpid
		from amps 
		where lic_authcd in ('0000','0003')
	)
select distinct o.apid, o.nm as nm_a, o.vpid, v.nm as nm_v, 'any domain, no ing' as reason --any domain, no ingred
from offenders1 o 
join vmps v on
	v.vpid = o.vpid
left join VIRTUAL_PRODUCT_INGREDIENT i
	on v.vpid = i.vpid
where 
	i.vpid is null

	and
	(
		(v.nm not like '%tablets'
		and lower (v.nm) not like '%fish oil%'
		and v.nm not like '%capsules'
		and lower (v.nm) not like '%ferric%'
		and lower (v.nm) not like '%antivenom%'
		and lower (v.nm) not like '%immunoglobulin%'
		and lower (v.nm) not like '%lactobacillis%'
		and lower (v.nm) not like '%hydrochloric acid%'
		and lower (v.nm) not like '%herbal liquid%'
		and lower (v.nm) not like '%pollinex%'
		and lower (v.nm) not like '%black currant syrup%'
		and lower (v.nm) not like '%vaccine%')
	
		or lower (v.nm) not like '% essential oil'
		or lower (v.nm) not like '%saliva%'
	)
;
analyze ancestor_snomed
;
--known device domain, ingred not in whitelist (Drug by RxN rules)
insert into devices
with ingred_whitelist as
	(
		select v.vpid
		from vmps v
		join VIRTUAL_PRODUCT_INGREDIENT i on
			i.vpid = v.vpid
		join concept c on
			c.vocabulary_id = 'SNOMED' and
			c.concept_code = i.isid
		join ancestor_snomed a on
			a.descendant_concept_id = c.concept_id
		join concept c2 on
			c2.concept_id = a.ancestor_concept_id and
			c2.concept_code in
				(
					'350107007','418407000', --Cellulose-derived viscosity modifier // eyedrops
					'4320669' -- Sodium hyaluronate
				)
	)
select a.apid, a.nm as nm_a, a.vpid, v.nm as nm_v, 'device domain, not whitelisted'
from amps a 
join vmps v on
	v.vpid = a.vpid
left join ingred_whitelist i on
	i.vpid = v.vpid
where 
	lic_authcd = '0002' and not
	v.nm ~* '(ringer|hyal|carmellose|synov|drops|sodium chloride 0)' and
	i.vpid is null and

	not exists --there are no AMPs with same VMP relations that differ in license
		(
			select
			from amps x 
			where
				x.vpid = a.vpid and
				x.lic_authcd != '0002'
		)
;
--known device domain, ingred not in whitelist (Drug by RxN rules)
insert into devices
select a.apid, a.nm as nm_a, a.vpid, v.nm as nm_v, 'device domain, not whitelisted' 
from amps a 
join vmps v on
	v.vpid = a.vpid
where
	lic_authcd = '0002' and
	(lower (v.nm) like '% kit') and
not exists --there are no AMPs with same VMP relations that differ in license
		(
			select
			from amps x 
			where
				x.vpid = a.vpid and
				x.lic_authcd != '0002'
		)
;
--unknown domain, known 'device' ingredient
insert into devices
with offenders1 as 
	(
		select distinct nm,apid,vpid
		from amps 
		where lic_authcd in ('0000','0003')
	)
select distinct o.apid, o.nm as nm_a, o.vpid, v.nm as nm_v, 'no domain, bad ing' 
from offenders1 o 
join vmps v on
	v.vpid = o.vpid
join VIRTUAL_PRODUCT_INGREDIENT i
	on v.vpid = i.vpid
join ingredient_substances s
	on s.isid = i.isid
where s.isid in 
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
)
;
--any domain, known 'device' ingredient
insert into devices
select distinct a.apid, a.nm as nm_a, a.vpid, s.nm as nm_v, 'any domain, bad ing' 
from ancestor_snomed ca
join concept c on
	ca.descendant_concept_id = c.concept_id and
	c.vocabulary_id = 'SNOMED'
join INGREDIENT_SUBSTANCES i on i.isid = c.concept_code
join VIRTUAL_PRODUCT_INGREDIENT v on v.isid = i.isid
join vmps s on s.vpid = v.vpid
join amps a on a.vpid = v.vpid
join concept d on
	d.concept_id = ca.ancestor_concept_id and
	d.concept_code in
	(
		'407935004','385420005', --Contrast Media
		'767234009', --Gadolinium (salt) -- also contrast
		'255922001', --Dental material
		'764087006',	--Product containing genetically modified T-cell
		'89457008',	--Radioactive isotope
		'37521911000001102', --Radium-223
		'420884001'	--Human mesenchymal stem cell
	)
;
insert into devices
select distinct a.apid, a.nm, v.vpid, v.nm, 'indication defines domain (regex)'
from vmps v 
join amps a on
	a.vpid = v.vpid
where 
	lower (v.nm) like '%dialys%' or
	lower (v.nm) like '%haemofiltration%' or
	lower (v.nm) like '%sunscreen%' or
	lower (v.nm) like '%supplement%' or	
	lower (v.nm) like '%food%' or	
	lower (v.nm) like '%nutri%' or
	lower (v.nm) like '%oliclino%' or
	lower (v.nm) like '%synthamin%' or
	lower (v.nm) like '%kabiven%' or
	lower (v.nm) like '%electrolyt%' or
	lower (v.nm) like '%ehydration%' or
	lower (v.nm) like '%vamin 9%' or
	lower (v.nm) like '%intrafusin%' or
	lower (v.nm) like '%vaminolact%' or
	lower (v.nm) like '% glamin %' or
	lower (v.nm) like '%ehydration%' or
	lower (v.nm) like '%hyperamine%' or
	lower (v.nm) like '%primene %' or
	lower (v.nm) like '%clinimix%' or
	lower (v.nm) like '%aminoven%' or
	lower (v.nm) like '%plasma-lyte%' or
	lower (v.nm) like '%tetraspan%' or
	lower (v.nm) like '%tetrastarch%' or
	lower (v.nm) like '%triomel%' or
	lower (v.nm) like '%aminoplasmal%' or
	lower (v.nm) like '%compleven%' or
	lower (v.nm) like '%potabl%' or
	lower (v.nm) like '%forceval protein%' or
	lower (v.nm) like '%ethyl chlorid%' or
	lower (v.nm) like '%alcoderm%' or
	lower (v.nm) like '%balsamicum%' or
	lower (v.nm) like '%diprobase%' or
	lower (v.nm) like '%diluent%oral%' or
	lower (v.nm) like '%empty%' or
	lower (v.nm) like '%dual pack vials%' or
	lower (v.nm) like '%biscuit%' or
	lower (v.nm) like '% vamin 14 %' or
	lower (v.nm) like '%perflutren%' or
	lower (v.nm) like '%ornith%aspart%' or
	lower (a.nm) like '%hepa%merz%' or
	lower (a.nm) like '%gallium citrate%' or
	lower (v.nm) like '%kbq%' or
	lower (v.nm) like '%ether solvent%' or
	lower (v.nm) = 'herbal liquid' or
	lower (v.nm) like 'toiletries %' or
	lower (v.nm) like 'artificial%' or
	lower (v.nm) like '% wipes' or
	lower (v.nm) like 'purified %' or
	lower (a.nm) like 'phlexy%' or
	lower (v.nm) like '%lymphoseek%' or
	lower (v.nm) like '%radium%223%'
;
insert into devices
--homeopathic products are not woth analyzing if source does not provide ingredients
select
	a.apid,
	a.nm,
	v.vpid,
	v.nm,
	'homeopathy with no ingredient' as reason
from vmps v
join amps a using (vpid) 
where 
	v.vpid not in (select vpid from virtual_product_ingredient) and
	(
		lower (v.nm) like '%homeop%' or
		lower (v.nm) like '%doron %' or
		lower (v.nm) like '%fragador%' or
		lower (v.nmprev) like '%homeop%' or
		lower (v.nm) like '%h+c%'
	)
;
insert into devices
select
	a.apid,
	a.nm,
	v.vpid,
	v.nm,
	'saline eyedrops' as reason
from vmps v
join amps a using (vpid) 

where v.nm like 'Generic % eye drops %' or v.nm like 'Generic % eye drops'
;
insert into devices
select
	a.apid,
	a.nm,
	v.vpid,
	v.nm,
	'SNOMED devices' as reason
from vmps v
join amps a using (vpid)
where
	vpid in
		(
			select c.concept_code
			from ancestor_snomed
			join concept c on
				vocabulary_id = 'SNOMED' and
				descendant_concept_id = c.concept_id and
				ancestor_concept_id in
					(
						35622427,	--Genetically modified T-cell product
						4222664, --Product containing industrial methylated spirit
						36694441 --Sodium chloride 0.9% catheter maintenance solution pre-filled syringes
					)
		)
;
-- if at least one vmp per amp is a drug, treat everything as drug
with x as
	(
		select vpid, count (distinct apid) as c1
		from devices
		group by vpid
	),
a_p_v as
	(
		select vpid, count (apid) as c2
		from amps
		group by vpid
	)
delete from devices 
where vpid in
	(
		select vpid
		from x
		join a_p_v using (vpid)
		where c2 != c1
	)
;
--fix bugs in source (dosages in wrong units, missing denominators, inconsistent dosage of ingredients etc)
update virtual_product_ingredient
set strnt_nmrtr_uomcd = '258684004' --mg instead of ml when obviously wrong
where
	(strnt_nmrtr_uomcd,strnt_dnmtr_uomcd) in
	(
		('258682000','258682000'),
		('258773002','258773002'),
		('258682000','258773002'),
		('258773002','258682000')
	) and
	strnt_nmrtr_val > strnt_dnmtr_val
;
delete from virtual_product_ingredient --duplicates or excipients
where
	(
		vpid = '3701211000001107' and
		isid = '422082008'
	) or
	(
		vpid in ('8967511000001107','8967611000001106','17995411000001108')
	) or
	(
		vpid = '326186007' and
		isid = '77370004'
	)
;
UPDATE virtual_product_ingredient
   SET strnt_nmrtr_uomcd = '258684004'
WHERE vpid = '19697911000001103'
;
update virtual_product_ingredient 
set strnt_nmrtr_val = strnt_nmrtr_val / 17
where vpid = '10050811000001105'
;
update virtual_product_ingredient
set 
	strnt_nmrtr_val = strnt_nmrtr_val / 10,
	strnt_dnmtr_val = strnt_dnmtr_val / 10
where vpid in ('35750411000001102', '322823002', '4792911000001109')
;
update virtual_product_ingredient
set 
	strnt_nmrtr_val = strnt_nmrtr_val * 5,
	strnt_dnmtr_val = strnt_dnmtr_val * 5
where vpid in ('34821011000001106','3628211000001102')
;
update virtual_product_ingredient
set 
	strnt_nmrtr_val = strnt_nmrtr_val * 133,
	strnt_dnmtr_val = strnt_dnmtr_val * 133
where vpid in ('3788711000001106')
;
update virtual_product_ingredient
set 
	strnt_nmrtr_val = strnt_nmrtr_val * 10,
	strnt_dnmtr_val = strnt_dnmtr_val * 10
where vpid in ('9062611000001102')
;
update virtual_product_ingredient
set 
	strnt_nmrtr_val = strnt_nmrtr_val * 15,
	strnt_dnmtr_val = strnt_dnmtr_val * 15
where vpid in ('14204311000001108')
;
update virtual_product_ingredient
set 
	strnt_nmrtr_val = strnt_nmrtr_val * 25,
	strnt_dnmtr_val = strnt_dnmtr_val * 25
where vpid in ('4694211000001102')
;
update virtual_product_ingredient
set 
	strnt_nmrtr_val = strnt_nmrtr_val * 4,
	strnt_dnmtr_val = strnt_dnmtr_val * 4
where vpid in ('14252411000001103')
;
update virtual_product_ingredient
set 
	strnt_nmrtr_val = 30 * strnt_nmrtr_val,
	strnt_dnmtr_val = 30 * strnt_dnmtr_val
where vpid in ('15125211000001101','15125111000001107','16665111000001100')
;
UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 5,
       strnt_dnmtr_uomcd = '258682000'
WHERE vpid = '9186611000001108'
;
UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 0.004
WHERE vpid = '19693411000001104'
AND   isid = '387293003'
;
UPDATE vmps
   SET udfs = 500
WHERE vpid = '18146511000001104'
;
UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 1,
       strnt_dnmtr_uomcd = '3317411000001100'
WHERE vpid = '3776211000001106'
;
update virtual_product_ingredient
set strnt_nmrtr_val = strnt_nmrtr_val / 1000
where vpid = '8034511000001103'
;
update virtual_product_ingredient
set
	strnt_nmrtr_uomcd = '258684004',
	strnt_nmrtr_val = '1500'
where
	vpid = '24129011000001102' and
	isid = '4284011000001105'
;
update virtual_product_ingredient
set	strnt_nmrtr_val = '500'
where
	vpid = '32961211000001109'	
;
insert into virtual_product_ingredient
values ('4171411000001108','70288006',null,'100.0','258684004',null,null)
;
UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 4000,
       strnt_nmrtr_uomcd = '258684004',
       strnt_dnmtr_val = NULL,
       strnt_dnmtr_uomcd = NULL
WHERE vpid = '16603411000001107'
AND   isid = '27192005';
;
update virtual_product_ingredient
set
	strnt_dnmtr_val = '1000',
	strnt_dnmtr_uomcd = '258773002'
where vpid in ('14611111000001108','9097011000001109','9096611000001104','9097111000001105')
;
update virtual_product_ingredient
set
	strnt_dnmtr_val = '1000',
	strnt_dnmtr_uomcd = '258684004'
where vpid in ('3864211000001105','4977811000001100','7902811000001102','425136005','3818211000001103')
;
update virtual_product_ingredient
set
	strnt_dnmtr_val = '1000',
	strnt_dnmtr_uomcd = '258682000'
where vpid in ('18411011000001106')
;
delete from virtual_product_ingredient where vpid = '4210011000001101' and strnt_nmrtr_val is null
;
update virtual_product_ingredient
set strnt_dnmtr_uomcd = '258773002'
where vpid in ('13532011000001103','10727111000001103','31363111000001105','13532111000001102','332745002')
;
UPDATE virtual_product_ingredient
   SET strnt_dnmtr_val = 1,
       strnt_dnmtr_uomcd = '258773002'
WHERE vpid in ('35776311000001109','10050811000001105')
;

;
UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 20,
       strnt_dnmtr_val = 1,
       strnt_dnmtr_uomcd = '258773002'
WHERE vpid = '36017611000001109'
AND   isid = '387206004'
;
--if vmpp total amount is in ml, change denominator to ml
update virtual_product_ingredient
set strnt_dnmtr_uomcd = '258773002'
where vpid in 
	(
		select i.vpid 
			from vmpps 
			join virtual_product_ingredient i on
		vmpps.qty_uomcd = '258773002' and
		vmpps.vpid = i.vpid and
		i.strnt_dnmtr_uomcd = '258682000'
	)
;
-- don't include dosages for drugs that don't have dosages for every ingredient
update virtual_product_ingredient
set
	strnt_nmrtr_val = null,
	strnt_nmrtr_uomcd = null,
	strnt_dnmtr_val = null,
	strnt_dnmtr_uomcd = null
where vpid in
	(
		select vpid
		from virtual_product_ingredient
		where
			vpid in (select vpid from virtual_product_ingredient where strnt_nmrtr_val is null)
		and strnt_nmrtr_val is not null
	)
;
--insulin fix
insert into virtual_product_ingredient 
values ('3474911000001103','421619005',null,null,null,null,null)
;
insert into virtual_product_ingredient 
values ('3474911000001103','421884008',null,null,null,null,null)
;
delete from virtual_product_ingredient
where
	vpid = '3474911000001103' and
	isid = '421491002'
;
insert into virtual_product_ingredient 
values ('400844000','420609005',null,null,null,null,null)
;
insert into virtual_product_ingredient 
values ('400844000','420837001',null,null,null,null,null)
;
delete from virtual_product_ingredient
where
	vpid = '400844000' and
	isid = '421116002'
;
update virtual_product_ingredient 
set
	strnt_nmrtr_val = null,
	strnt_nmrtr_uomcd = null,
	strnt_dnmtr_val = null,
	strnt_dnmtr_uomcd = null
where isid = '5375811000001107'
;
update virtual_product_ingredient v
set strnt_dnmtr_uomcd = '258773002'
where 
	(select nm from vmps where vpid = v.vpid) like '%ml%' and
	v.strnt_dnmtr_uomcd = '258682000'
;
update virtual_product_ingredient 
set 
	strnt_dnmtr_uomcd = null,
	strnt_dnmtr_val = null,
	strnt_nmrtr_uomcd = null,
	strnt_nmrtr_val = null
where vpid in ('5376411000001101','5376311000001108','5376211000001100');
;
UPDATE virtual_product_ingredient
   SET strnt_nmrtr_val = 2,
       strnt_dnmtr_val = 0.4
WHERE vpid = '18248211000001104'
AND   isid = '51224002';
;
update virtual_product_ingredient
set strnt_nmrtr_uomcd = '258685003'
where vpid = '36458811000001107'
;
--2. Build drug_concept_stage
create table devices1 as select distinct apid,nm_a,vpid,nm_v from devices
;
drop table devices
;
alter table devices1 rename to devices
;
drop table if exists ingred_replacement
;
create table ingred_replacement as
select distinct 
	isidprev as isidprev,
	nm as nmprev,
	isid as isidnew,
	nm as nmnew
from ingredient_substances
	where isidprev is not null
;
--tree vaccine
insert into ingred_replacement values ('5375811000001107',null,'32869811000001104',null);
insert into ingred_replacement values ('5375811000001107',null,'32869511000001102',null);
insert into ingred_replacement values ('5375811000001107',null,'32870011000001108',null);
;
/*
insert into ingred_replacement -- Zidovudine + Lamivudine -> Zidovudine
select distinct
	v1.vtmid,
	v2.vtmid
from vtms v1
join vtms v2 on
	left (v1.nm, strpos(v1.nm, '+') - 2) = v2.nm or
	left (v1.nm, strpos(v1.nm, '+') - 2) || ' vaccine' = v2.nm
;
insert into ingred_replacement -- Zidovudine + Lamivudine -> Lamivudine
select distinct
	v1.vtmid,
	v2.vtmid
from vtms v1
join vtms v2 on -- I am sorry for this
	reverse (left (reverse (v1.nm), strpos(reverse(v1.nm), '+') - 2)) = v2.nm or
	'Hepatitis ' || reverse (left (reverse (v1.nm), strpos(reverse(v1.nm), '+') - 2)) = v2.nm
;*/
;
drop table if exists tms_temp
;
create table tms_temp as
	(
		SELECT v.vtmid, v.nm as nmprev, nmnew
		FROM vtms v
		LEFT JOIN LATERAL unnest(string_to_array(replace (v.nm,' - invalid',''), ' + ')) as nmnew on true
		where nm like '%+%'
	)
;
DROP SEQUENCE IF EXISTS new_seq
;
CREATE sequence new_seq increment BY 1 start
	WITH 1 cache 20
;
drop table if exists ir_insert 
;
create table ir_insert as
select
	t.vtmid as isidprev,
	t.nmprev,
	coalesce (i.isid, v.vtmid) as isidnew,
	t.nmnew
from tms_temp t
left join vtms v on
	t.nmnew ilike v.nm or
	'Hepatitis ' || t.nmnew ilike v.nm or
	t.nmnew  || ' vaccine' ilike v.nm
left join ingredient_substances i on
	(
		t.nmnew ilike i.nm or
		'Hepatitis ' || t.nmnew ilike i.nm or
		t.nmnew  || ' vaccine' ilike i.nm
	) and
	i.invalid = '0'
;
drop table if exists y
;
create table y as
with x as
	(
		select distinct nmnew 
		from ir_insert
		where isidnew is null
	)
select 
	nmnew,
	'OMOP' || nextval ('new_seq') as isid
from x
;
insert into ingred_replacement
select distinct
	i.isidprev,
	i.nmprev,
	coalesce (i.isidnew, y.isid),
	i.nmnew
from ir_insert i
left join y on
	y.nmnew = i.nmnew
;
insert into ingred_replacement 
--replaces precise ingredients (salts) with active molecule with few exceptions
select distinct 
	v.isid,
	s1.nm,
	s2.isid,
	s2.nm 
from virtual_product_ingredient v 
join ingredient_substances s1 on
	v.isid = s1.isid
join ingredient_substances s2 on
	v.bs_subid = s2.isid
left join devices d on --devices (contrasts) add a lot
	d.vpid = v.vpid
where
	v.bs_subid is not null and
	d.vpid is null and
	s2.isid not in -- do not apply to folic acid, metalic compounds and halogens -- must still be mapped to salts
		(
			select c.concept_code 
			from concept c
			join ancestor_snomed ca on
				c.vocabulary_id = 'SNOMED' and
				ca.ancestor_concept_id in (4143228,4021618,4213977,35624387) and
				ca.descendant_concept_id = c.concept_id
		) and
	substring (lower (s1.nm) from 1 for 7) != 'insulin' -- to not to lose various insulins
;
--multiple bs_subids for Naloxone hydrochloride dihydrate
delete from ingred_replacement
where (isidprev, isidnew) = ('4482911000001101','21518006')
;
update ingred_replacement
set
	isidnew = '387578003',
	nmnew = 'Sodium hyaluronate'
where
	isidnew = '96278006'
;
--if X replaced with Y and Y replaced with Z, replace X with Z
update ingred_replacement x
	set
		(isidnew,nmnew) =
			(
				select
					r.isidnew,
					r.nmnew
				from ingred_replacement r
				where x.isidnew = r.isidprev
		
			)		
	where x.isidnew in (select ISIDprev from ingred_replacement);
;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'dm+d',
	pVocabularyDate			=> TO_DATE ('20200616', 'yyyymmdd'),
	pVocabularyVersion		=> 'dm+d Version 6.1.0 20200615',
	pVocabularyDevSchema	=> 'DEV_DMD'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_DMD',
	pAppendVocabulary		=> TRUE
);
END $_$;
;
--keep legacy mappings for the future
create table if not exists r_to_c_all
(
   concept_name       varchar(255),
   concept_class_id   varchar,
   concept_id         integer,
   precedence         integer,
   conversion_factor  float8
)
;
--update legacy mappings if target was changed
update r_to_c_all
set concept_id = 
	(
		select distinct c2.concept_id
		from concept_relationship r
		join concept c2 on
			c2.concept_id = r.concept_id_2 and
			r_to_c_all.concept_id = r.concept_id_1 and
			r.relationship_id in ('Concept replaced by','Maps to') and
			r.invalid_reason is null
	)
where
	exists
		(
			select
			from concept
			where 
				concept_id = r_to_c_all.concept_id and
				(
					invalid_reason = 'U' or
					concept_class_id = 'Precise Ingredient' --RxN could move Ingredient to PI cathegory
				)
		)
;
--remove duplicates
delete from r_to_c_all r1
where
	exists 
		(
			select
			from r_to_c_all r2
			where
				(r2.concept_name, r2.concept_class_id, r2.concept_id) = (r1.concept_name, r1.concept_class_id, r1.concept_id) and
				r2.precedence < r1.precedence
		) or
	r1.concept_id is null or
	exists
		(
			select
			from concept
			where 
				concept_id = r1.concept_id and
				invalid_reason = 'D'
		)
;
create index devices_vpid on devices (vpid)
;
create index devices_apid on devices (apid)
;
analyze devices
;
DROP TABLE IF EXISTS drug_concept_stage cascade
;
CREATE TABLE drug_concept_stage AS
SELECT *
FROM concept_stage
WHERE false;

ALTER TABLE drug_concept_stage ADD COLUMN source_concept_class_id VARCHAR(20);

INSERT INTO drug_concept_stage
	(
		concept_name,
		domain_id,vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		source_concept_class_id
	)
--forms
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

--ingreds
SELECT DISTINCT
	LEFT (nm,255) AS concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	'S' AS standard_concept,
	isid AS concept_code,
	COALESCE(isiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
	TO_DATE('20991231','yyyymmdd') AS valid_end_date,
	null AS invalid_reason,
	'Ingredient'
FROM ingredient_substances

	UNION

--ingreds (VTMs) -- some are needed
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

--generated replacements ingredients
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
FROM y;

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
	f.cd IS NULL
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
				SELECT latest_update - 1
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
JOIN devices d ON
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
         WHEN v.invalid = '1' THEN (SELECT latest_update - 1
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
         WHEN '1' THEN (SELECT latest_update - 1
                        FROM vocabulary
                        WHERE vocabulary_id = 'dm+d')
         ELSE*/ TO_DATE('20991231','yyyymmdd')
      /* END*/ AS valid_end_date,
	NULL AS invalid_reason,
       'VMPP'
FROM vmpps v
  JOIN vmps p ON
--start date etc stored in VMPS
v.vpid = p.vpid
  JOIN devices d ON v.vpid = d.vpid;

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
		when s.cd is null then left (a.nm,255)
		else left (a.nm || ' by ' || s.info_desc,255)
	end as concept_name,*/ LEFT (a.nm,255),
       'Drug' AS domain_id,
       'dm+d' AS vocabulary_id,
       'Drug Product' AS concept_class_id,
       NULL AS standard_concept,
       a.apid AS concept_code,
       COALESCE(a.nmdt,p.vpiddt,TO_DATE('1970-01-01','YYYY-MM-DD')) valid_start_date,
       CASE
         WHEN a.invalid = '1' THEN (SELECT latest_update - 1
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
  JOIN vmps p ON
--start date etc stored in VMPS
a.vpid = p.vpid /*left join supplier s on
	a.suppcd = s.cd and
	not exists (select from fake_supp f where f.cd = s.cd)*/
  LEFT JOIN devices d ON a.vpid = d.vpid
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
--AMPS = Actual Medicinal Product = Device (OMOP)
SELECT DISTINCT /*case
		when s.cd is null then left (a.nm,255)
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
         WHEN '1' THEN (SELECT latest_update - 1
                        FROM vocabulary
                        WHERE vocabulary_id = 'dm+d')
         ELSE*/ TO_DATE('20991231','yyyymmdd')
       /*END*/ AS valid_end_date,
	NULL AS invalid_reason,
       'AMP'
FROM amps a
JOIN devices d ON a.vpid = d.vpid;
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
--when a1.DISCDT is not null then a1.DISCDT
		WHEN a1.invalid = '1' THEN
			(
				SELECT latest_update - 1
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
WHERE d.apid IS NULL
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
JOIN devices d ON a1.apid = d.apid;
;
--source 'Ingredient' is preferred to 'VTM'
insert into ingred_replacement
select
	d2.concept_code,
	d2.concept_name,
	d1.concept_code,
	d1.concept_name
from drug_concept_stage d1
join drug_concept_stage d2 on
	d1.source_concept_class_id = 'Ingredient' and
	d2.source_concept_class_id = 'VTM' and
	TRIM(LOWER(d1.concept_name)) = TRIM(LOWER(d2.concept_name))
;
-- 3. Create internal_relationship_stage and pc_stage

drop table if exists pc_stage
;
create table pc_stage as

select
	c.prntvppid as pack_concept_code,
/*	case 
		when p2.qty_uomcd not in 
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
	end as drug_concept_code,*/ p2.vppid as drug_concept_code,
	case 
		when p2.qty_uomcd not in 
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
		then p2.qtyval
		else 1
	end as amount,
	null :: int4 as box_size
from comb_content_v c

join vmpps p1 on 
	c.prntvppid = p1.vppid
left join devices d1 on --filter devices
	d1.vpid = p1.vpid

join vmpps p2 on
	c.chldvppid = p2.vppid --extract pack size
left join devices d2 on --probably redundant check for devices
	d2.vpid = p2.vpid

where 
	d1.vpid is null and
	d2.vpid is null

	union all

select
	c.prntappid as pack_concept_code,
	/*case
		when vx.qty_uomcd not in 
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
	end as drug_concept_code,*/ p2.appid as drug_concept_code,
	case 
		when vx.qty_uomcd not in 
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
		then vx.qtyval
		else 1
	end as amount,
	null :: int4 as box_size
from comb_content_a c

join ampps p1 on
	c.prntappid = p1.appid
left join devices d1 on --filter devices
	d1.apid = p1.apid

join ampps p2 on --extract pack size
	c.chldappid = p2.appid
join vmpps vx on --through vmpp
	vx.vppid = p2.vppid
left join devices d2 on --probably redundant check for devices
	d2.apid = p2.apid

where 
	d1.apid is null and
	d2.apid is null
;
drop table if exists pc_modifier
;
--VMPPS, get modifiers indirectly
create table pc_modifier as
select
	p.pack_concept_code,
	v.qtyval / sum (p.amount) as multiplier
from pc_stage p
join vmpps v on
	v.vppid = p.pack_concept_code
where v.qtyval != '1'
group by p.pack_concept_code, qtyval
;
delete from pc_modifier 
where 
	multiplier <= 1 or
	multiplier is null 
;
update pc_stage p
set box_size = (select m.multiplier from pc_modifier m where m.pack_concept_code = p.pack_concept_code)
;
update pc_stage p
set box_size = 
	(
		select m.multiplier 
		from pc_modifier m 
		join ampps a on 
			a.vppid = m.pack_concept_code
		where a.appid = p.pack_concept_code
	)
;
drop table if exists pc_modifier
;
--AMPPS from names
create table pc_modifier as
select distinct
	p.pack_concept_code,
	regexp_replace (trim (from regexp_match (regexp_replace (replace (replace (a.nm,' x ','x'),')',''), '1x\(',''), ' [2-9]+x\(.*') :: varchar,'{}" '),'x.*$','') :: int4 as multiplier
from ampps a 
join pc_stage p on
	p.pack_concept_code = a.appid	
where box_size is null
;
delete from pc_modifier 
where 
	multiplier <= 1 or
	multiplier is null 
;
update pc_stage c set
	amount = c.amount / (select multiplier from pc_modifier p where p.pack_concept_code = c.pack_concept_code) :: int4,
	box_size = (select multiplier from pc_modifier p where p.pack_concept_code = c.pack_concept_code) :: int4
where exists (select from pc_modifier p where p.pack_concept_code = c.pack_concept_code)
;
--fix bodyless headers: AMP and VMP ancestors of pack concepts
insert into pc_stage
--branded pack headers, can have Brand Name, Supplier and PC entry with same AMPs as AMPP counterpart
select distinct
	a.apid as pack_concept_code,
	ax.apid,
	null::int4 as amount, --empty for header concepts
	null::int4 as box_size
from pc_stage p
join ampps a on
	a.appid = p.pack_concept_code
join ampps ax on
	p.drug_concept_code = ax.appid
;
insert into pc_stage
--clinical pack headers, can have only PC entry with same VMPs as VMPP counterpart
select distinct
	v.vpid as pack_concept_code,
	vx.vpid,
	null::int4 as amount, --empty for header
	null::int4 as box_size
from pc_stage p
join vmpps v on
	v.vppid = p.pack_concept_code
join vmpps vx on
	vx.vppid = p.drug_concept_code
;
drop table if exists internal_relationship_stage
;
create table internal_relationship_stage
	(
		concept_code_1 varchar,
		concept_code_2 varchar
	)
;
insert into internal_relationship_stage
 -- VMP to ingredient
select distinct
	v.vpid as cc1,
	coalesce 
		(
			i.isid,	--correct IS
			v.vtmid --VTM
		)
from vmps v 
left join virtual_product_ingredient i on i.vpid = v.vpid
left join devices d on --not device
	v.vpid = d.vpid
left join pc_stage p on
	v.vpid = p.pack_concept_code
where 
	d.vpid is null and --not pack header
	p.pack_concept_code is null
;
--replace ingredients deprecated by source
insert into internal_relationship_stage
select 
	i.concept_code_1,
	p.isidnew
from internal_relationship_stage i
join ingred_replacement p on
	p.isidprev = i.concept_code_2
;
--Update Pantothenic acid loop
UPDATE ingred_replacement
   SET isidnew = '86431009'
WHERE isidprev = '404842009'
AND   isidnew = '126226000';
;
;
delete from internal_relationship_stage s
where
	exists
		(
			select
			from ingred_replacement x
			where s.concept_code_2 = x.isidprev
		) or
	concept_code_2 is null
;
insert into internal_relationship_stage
--VMP to dose form
select distinct v.vpid, v.formcd --forms
from drug_form v
left join devices d on
	v.vpid = d.vpid
left join pc_stage p on
	v.vpid = p.pack_concept_code and
	p.pack_concept_code not in
		(
			select pack_concept_code
			from pc_stage
			group by pack_concept_code
			having count (drug_concept_code) = 1
		)
where 
	d.vpid is null and
	p.pack_concept_code is null and
	v.formcd != '3097611000001100' --Not Applicable
;
drop table if exists dosefix 
;
create table dosefix as --salvage missing Dose Forms from names
select distinct 
	v.vpid,
	v.nm,
	null :: varchar as dose_code,
	null :: varchar as dose_name
from vmps v
left join devices d on
	d.vpid = v.vpid
left join pc_stage p on
	p.pack_concept_code = v.vpid and
	p.pack_concept_code not in
		(
			select pack_concept_code
			from pc_stage
			group by pack_concept_code
			having count (drug_concept_code) = 1
		)
where 
	d.vpid is null and
	p.pack_concept_code is null and
	v.vpid not in
		(
			select concept_code_1 
			from internal_relationship_stage i
			join drug_concept_stage c on
				c.concept_class_id = 'Dose Form' and
				c.concept_code = i.concept_code_2
		)
;
update dosefix
set
	dose_code = '385219001',
	dose_name = 'Solution for injection'
where 
	lower (nm) like '%viscosurgical%' or
	lower (nm) like '%infusion%' or
	lower (nm) like '%ampoules' or
	lower (nm) like '%syringes'
;
update dosefix
set
	dose_code = '385023001',
	dose_name = 'Oral solution'
where 
	lower (nm) like '%syrup%' or
	lower (nm) like '%tincture%' or
	lower (nm) like '%oral drops%' or
	lower (nm) like '%oral spray%' 
;
update dosefix
set
	dose_code = '385108009',
	dose_name = 'Cutaneous solution'
where
	lower (nm) like '%swabs'
;
update dosefix
set
	dose_code = '385111005',
	dose_name = 'Cutaneous emulsion'
where
	lower (nm) like '% oil %' or
	lower (nm) like '% oil' or
	lower (nm) like '%cream%'
;
update dosefix
set
	dose_code = '14945811000001105',
	dose_name = 'Powder for gastroenteral liquid'
where
	lower (nm) like '%oral%powder%' or
	lower (nm) like '%tri%salts%'
;
update dosefix
set
	dose_code = '385210002',
	dose_name = 'Inhalation vapour'
where
	lower (nm) like '%inhala%'
;
update dosefix
set
	dose_code = '385124005',
	dose_name = 'Eye drops'
where
	lower (nm) like '%eye%'
;
update dosefix
set
	dose_code = '16605211000001107',
	dose_name = 'Irrigation solution'
where
	lower (nm) like '%intraves%' or
	lower (nm) like '%maint%'
;
update dosefix
set
	dose_code = '16605211000001107',
	dose_name = 'Irrigation solution'
where
	lower (nm) like '%intraves%' or
	lower (nm) like '%maint%'
;
update dosefix --will be improved later
set
	dose_code = '85581007',
	dose_name = 'Powder'
where 
	dose_code is null and ( lower (nm) like '%powder%' or lower (nm) like '%crystals%')
;
update dosefix
set
	dose_code = '70409003',
	dose_name = 'Mouthwash'
where dose_code is null and lower (nm) like '%mouthwash%'
;
update dosefix --will be improved later
set
	dose_code = '420699003',
	dose_name = 'Liquid'
where dose_code is null
;
insert into internal_relationship_stage
select vpid, dose_code
from dosefix
where dose_code is not null
;
--'Foam' is too generic and is related to multiple different dose forms
-- May need to fix with name matching
insert into internal_relationship_stage 
-- AMP to dose form 
-- excipients are ignored, so we reuse VMPs for ingredients and dose forms
-- Ingredient relations will be inherited after ds_stage
select distinct
	a.apid,
	i.concept_code_2
from amps a
join internal_relationship_stage i on
	i.concept_code_1 = a.vpid
/*join drug_concept_stage x on
	x.concept_class_id = 'Dose Form' and
	x.concept_code = i.concept_code_2*/
left join devices d on
	a.apid = d.apid
left join pc_stage p on
	a.apid = p.pack_concept_code and
	p.pack_concept_code not in
		(
			select pack_concept_code
			from pc_stage
			group by pack_concept_code
			having count (drug_concept_code) = 1
		)
where 
	d.apid is null and
	p.pack_concept_code is null
;
insert into internal_relationship_stage
--AMP to supplier
select distinct
	a.apid,
	a.suppcd
from amps a
left join fake_supp c on -- supplier is present in dcs
	a.suppcd = c.cd
left join devices d on
	a.apid = d.apid
where 
	d.apid is null and
	c.cd is null
;
insert into internal_relationship_stage
--VMPP -- if not a pack, reuse VMP relations. If a pack, omit.
select distinct
	p.vppid,
	i.concept_code_2
from internal_relationship_stage i
join vmpps p on
	p.vpid = i.concept_code_1
/*join drug_concept_stage x on
	x.concept_class_id = 'Dose Form' and
	x.concept_code = i.concept_code_2*/
left join pc_stage c on
	c.pack_concept_code = p.vppid and
	c.pack_concept_code not in
		(
			select pack_concept_code
			from pc_stage
			group by pack_concept_code
			having count (drug_concept_code) = 1
		)
where c.pack_concept_code is null
;
--AMPP -- if not a pack, reuse AMP relations. If a pack, omit.
insert into internal_relationship_stage
select distinct
	p.appid,
	i.concept_code_2
from internal_relationship_stage i
join ampps p on
	p.apid = i.concept_code_1
left join pc_stage c on
	c.pack_concept_code = p.appid and
	c.pack_concept_code not in
		(
			select pack_concept_code
			from pc_stage
			group by pack_concept_code
			having count (drug_concept_code) = 1
		)
left join devices d on
	d.apid = p.apid
where 
	c.pack_concept_code is null and
	d.apid is null
;
drop table if exists only_1_pack
;
create table only_1_pack as --for later use in other input tables
select distinct
	pack_concept_code,
	drug_concept_code,
	amount
from pc_stage p
where
	p.pack_concept_code in
		(
			select pack_concept_code
			from pc_stage
			group by pack_concept_code
			having count (drug_concept_code) = 1
		)
;
insert into internal_relationship_stage --monopacks inherit their content's relation entirely, if they don't already have unique
select distinct
	p.pack_concept_code,
	i.concept_code_2	
from internal_relationship_stage i
join pc_stage p on
	i.concept_code_1 = p.drug_concept_code
join only_1_pack using (pack_concept_code)
join drug_concept_stage x on
	x.concept_code = i.concept_code_2
where
	not exists --check if monopack already has this type of relation
		(
			select
			from internal_relationship_stage z
			join drug_concept_stage dz on
				dz.concept_code = z.concept_code_2
			where
				z.concept_code_1 = p.pack_concept_code and
				dz.concept_class_id = x.concept_class_id and
				dz.concept_class_id in ('Supplier', 'Dose Form')				
		)
;
delete from pc_stage where
	pack_concept_code in
		(
			select pack_concept_code
			from only_1_pack
		)
;
update pc_stage 
set	amount = 1
where pack_concept_code = '34884711000001100';
-- 3. Form ds_stage using source relations and name analysis. Replace ingredient relations
drop table if exists ds_prototype
;
--Create ds_stage for VMPs, inherit everything else later
create table ds_prototype as
--temporary table
select distinct
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
	null::int4 as box_size,
	v.udfs as total, --sometimes contains additional info about size and amount
	u1.cd as unit_1_code,
	u1.info_desc as unit_1_name
/*	,u2.cd as unit_2_code,
	u2.info_desc as unit_2_name*/
from virtual_product_ingredient i -- main source table
join vmps v on
	v.vpid = i.vpid and
	i.strnt_nmrtr_uomcd not in ('258672001','258731005') 
	--and	i.strnt_dnmtr_uomcd != '259022006'
left join UNIT_OF_MEASURE u1 on
	v.udfs_uomcd = u1.cd
/*left join UNIT_OF_MEASURE u2 on
	v.unit_dose_uomcd = u2.cd*/
left join ingred_replacement r on
	i.isid = r.isidprev
join drug_concept_stage c1 on
	c1.concept_code = i.vpid
join drug_concept_stage c2 on
	c2.concept_code = coalesce (i.isid, r.isidnew)
join drug_concept_stage c3 on
	c3.concept_code = i.strnt_nmrtr_uomcd
left join drug_concept_stage c4 on
	c4.concept_code = i.strnt_dnmtr_uomcd
left join devices d on --no ds entry for non-drugs
	i.vpid = d.vpid
where 
	d.vpid is null
;
drop table if exists vmps_res --try to salvage missing dosages from texts from VMPs
;
create table vmps_res as
with ingreds as
	(
		select concept_code_1, concept_code, concept_name
		from internal_relationship_stage i 
		join drug_concept_stage c on
			i.concept_code_2 = c.concept_code and
			c.concept_class_id = 'Ingredient'
	),
dforms as
	(
		select concept_code_1, concept_code, concept_name
		from internal_relationship_stage i 
		join drug_concept_stage c on
			i.concept_code_2 = c.concept_code and
			c.concept_class_id = 'Dose Form' 
	)
select distinct
	v.vpid as drug_concept_code,
	replace (v.nm,',','') as drug_concept_name,
	i.concept_code as ingredient_concept_code,
	i.concept_name as ingredient_concept_name,
	f.concept_code as form_concept_code,
	f.concept_name as form_concept_name,
	null :: varchar (255) as modified_name
from vmps v
left join ds_prototype s on
	s.drug_concept_code = v.vpid
left join devices d on
	v.vpid = d.vpid
left join pc_stage p on
	p.pack_concept_code = v.vpid
left join ingreds i on
	v.vpid = i.concept_code_1
left join dforms f on
	v.vpid = f.concept_code_1
where 
	d.vpid is null and
	p.pack_concept_code is null and
	s.drug_concept_code is null
;-- move deprecated gases (given as 1 ml / 1 ml) to manual work
insert into vmps_res
select
	drug_concept_code,
	drug_name,
	ingredient_concept_code,
	ingredient_name,
	'3092311000001108',
	'Inhalation gas',
	null
from ds_prototype
where 
	amount_name = 'ml' and
	amount_value = 1 and
	total is null and
	denominator_name != 'litre' and
	drug_name like '%litres%'
;
insert into internal_relationship_stage
select distinct
	drug_concept_code,
	'3092311000001108'
from ds_prototype
where 
	amount_name = 'ml' and
	amount_value = 1 and
	total is null and
	denominator_name != 'litre' and
	drug_name like '%litres%'
;
delete
from ds_prototype
where 
	amount_name = 'ml' and
	amount_value = 1 and
	total is null and
	denominator_name != 'litre'
;
--help autoparser a little
update vmps_res set drug_concept_name = replace (drug_concept_name,'1.5million unit','1500000unit')
;
update vmps_res set drug_concept_name = replace (drug_concept_name,'1.2million unit','1200000unit')
;
delete from vmps_res 
where 
	lower(drug_concept_name) like '%homeopath%' or
	lower(ingredient_concept_name) like '%homeopath%' or
	lower(form_concept_name) like '%homeopath%'
;
update vmps_res set ingredient_concept_name = 'Estramustine' where ingredient_concept_name = 'Estramustine phosphate';
update vmps_res set ingredient_concept_name = 'Tenofovir' where ingredient_concept_name = 'Tenofovir disoproxil';
update vmps_res set ingredient_concept_name = 'Lysine' where ingredient_concept_name = 'L-Lysine';
;
update vmps_res --cut ingred at start for single-ingredient
set	modified_name = 
	replace (
		right 
		(
			lower (drug_concept_name), 
			length (drug_concept_name) - (strpos (lower (drug_concept_name), lower (ingredient_concept_name))) - length (ingredient_concept_name)
		)
	, ' / ', '/')
where 
	strpos (lower (drug_concept_name), lower (ingredient_concept_name)) != 0 and
	drug_concept_code in
		(
			select drug_concept_code
			from vmps_res
			group by drug_concept_code
			having count (ingredient_concept_code) = 1 --good results only guaranteed for single ingred
		)
;
update vmps_res
set modified_name =
	replace (
		regexp_replace (lower (drug_concept_name), '^\D+','')
	, ' / ', '/')
where 
	strpos (lower (drug_concept_name), lower (ingredient_concept_name)) = 0 and
	drug_concept_code in
		(
			select drug_concept_code
			from vmps_res
			group by drug_concept_code
			having count (ingredient_concept_code) = 1 --good results only guaranteed for single ingred
		)
;
update vmps_res --cut form from the end
set modified_name = 
	case
		when modified_name is null then null
		when strpos (modified_name, lower (form_concept_name)) != 0 then
			left (modified_name, strpos (modified_name, lower (form_concept_name)) - 1)
		else modified_name
	end
where form_concept_code is not null
;
update vmps_res
set modified_name = 
	case
		when modified_name = '' then null
		when regexp_match (modified_name, '\d', 'im') is null then null 
		else modified_name
	end
;
update vmps_res --remove traces of other artifacts
set modified_name =
	trim (from regexp_replace (regexp_replace (modified_name, '^[a-z \(\)]+ ', '', 'im'),' [\w \(\),-.]+$','','im'))
where modified_name is not null
;
update vmps_res set
modified_name = regexp_replace (modified_name, ' .*$','')
where modified_name like '% %'
;
update vmps_res
set modified_name = null
where 
	modified_name like '%ppm%' or
	modified_name like '%square%'
;
drop table if exists ds_parsed
;
create table ds_parsed as
select --percentage
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	trim (from regexp_match (modified_name, '^[\d.]+','im') :: varchar, '{}') :: float8 * 10 as amount_value,
	'258684004' as amount_code,
	'mg' as amount_name,
	1 as denominator_value,
	'258773002' as denominator_code,
	'ml' as denominator_name,
	null :: int4 as box_size,
	null :: float8 as total,
	null :: varchar as unit_1_code,
	null :: varchar as unit_1_name
from vmps_res
where 
	modified_name like '%|%' escape '|' and
	regexp_match (drug_concept_name, ' [0-9.]+ml ') is null

	union all

select --percentage, with given total volume
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	trim (from regexp_match (modified_name, '^[\d.]+','im') :: varchar, '{}') :: float8 * 10 * trim (from regexp_match (drug_concept_name, ' [0-9.]+ml ','im') :: varchar, ' ml{}"') :: float8 as amount_value,
	'258684004' as amount_code,
	'mg' as amount_name,
	trim (from regexp_match (drug_concept_name, ' [0-9.]+ml ','im') :: varchar, ' ml{}"') :: float8 as denominator_value,
	'258773002' as denominator_code,
	'ml' as denominator_name,
	null as box_size,
	null as total,
	null as unit_1_code,
	null as unit_1_name
from vmps_res
where 
	modified_name like '%|%' escape '|' and
	regexp_match (drug_concept_name, ' [0-9.]+ml ') is not null

	union all

select --numerator/denominator
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	trim (from regexp_match (modified_name, '^[\d.]+','im') :: varchar, '{}') :: float8 as amount_value,	
	null as amount_code,
	trim (from regexp_match (modified_name, '[a-z]+\/','im') :: varchar, '{/}') :: varchar as amount_name,
	coalesce 
		(
			trim (from regexp_match (modified_name, '\/[\d.]+','im') :: varchar, '{/}') :: float8,
			1
		) as denominator_value,
	null as denominator_code,
	trim (from regexp_match (modified_name, '[a-z]+$','im') :: varchar, '{/}') :: varchar as denominator_name,
	null as box_size,
	null as total,
	null as unit_1_code,
	null as unit_1_name
from vmps_res
where modified_name like '%|/%' escape '|'

	union all

select --simple amount
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	trim (from regexp_match (modified_name, '^[\d.]+','im') :: varchar, '{}') :: float8 as amount_value,	
	null as amount_code,
	trim (from regexp_match (modified_name, '[a-z]+$','im') :: varchar, '{/}') :: varchar as denominator_name,
	null as denominator_value,
	null as denominator_code,
	null as denominator_name,
	null as box_size,
	null as total,
	null as unit_1_code,
	null as unit_1_name
from vmps_res
where 
	modified_name not like '%|/%' escape '|' and
	modified_name not like '%|%' escape '|'
;
update ds_parsed d set amount_name = 'gram' where amount_name = 'g';
update ds_parsed d set amount_name = trim (trailing 's' from amount_name) where amount_name like '%s';
update ds_parsed d set denominator_name = 'gram' where denominator_name = 'g';
update ds_parsed d set denominator_name = trim (trailing 's' from denominator_name) where denominator_name like '%s';
update ds_parsed d set amount_code = (select cd from unit_of_measure where d.amount_name = info_desc) where amount_name is not null;
update ds_parsed d set denominator_code = (select cd from unit_of_measure where d.denominator_name = info_desc) where denominator_name is not null;
;
update ds_parsed d set --only various Units remain by now
	amount_code = '258666001',
	amount_name = 'unit'
where 
	amount_code is null and
	amount_name is not null
;/*
drop table if exists tomap_vmps_ds
;
--For manual mapping
--If corresponding ingredient code is not present in DCS, manually enter concept_id of passing ingredient from Rx* -- OMOP concept will be created automatically
create table tomap_vmps_ds as
select 
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	null :: float8 as amount_value,
	null :: varchar as amount_name,
	null :: float8 as denominator_value,
	null :: varchar as denominator_unit
from vmps_res 
where 
	drug_concept_code not in (select drug_concept_code from ds_parsed where amount_name is not null) and
	drug_concept_code not in (select drug_concept_code from ds_prototype)
	and drug_concept_code not in (select drug_concept_code from tomap_vmps_ds)
order by drug_concept_name, ingredient_concept_name desc
;
WbImport -file=/home/ekorchmar/Documents/dmd/tomap_vmps_ds.csv --file on Eduard's PC
         -type=text
         -table=tomap_vmps_ds
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=drug_concept_code,drug_concept_name,ingredient_concept_code,ingredient_concept_name,amount_value,amount_name,denominator_value,denominator_unit
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;*/
delete from tomap_vmps_ds
where drug_concept_code in (select drug_concept_code from ds_prototype)
;
delete from tomap_vmps_ds
where drug_concept_code not in (select concept_code from drug_concept_stage where domain_id = 'Drug')
;
delete from internal_relationship_stage
where
	concept_code_1 in (select drug_concept_code from tomap_vmps_ds) and
	concept_code_2 in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient')
;
drop table if exists ds_new_ingreds
;
create table ds_new_ingreds as
with ings as
	(
		select distinct	cast (ingredient_concept_name as int4) :: int4 as ingredient_id
		from tomap_vmps_ds
		where 
			ingredient_concept_name is not null and
			ingredient_concept_code is null
	)
select
	c.concept_id as ingredient_id,
	'OMOP' || nextval ('new_seq') as concept_code,
	c.concept_name
from ings i
join concept c on
	c.concept_id = 	cast (ingredient_id as int4)
;
insert into drug_concept_stage
select
	null as concept_id,
	concept_name,
	'Drug' AS domain_id,
	'dm+d' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	'S' AS standard_concept,
	concept_code,
	to_date ('1970-01-01','YYYY-MM-DD'),
	TO_DATE('20991231', 'yyyymmdd'),
	null as invalid_reason,
	'Ingredient'
from ds_new_ingreds
;
insert into ds_prototype
select
	drug_concept_code,
	drug_concept_name,
	ingredient_concept_code,
	ingredient_concept_name,
	amount_value,
	null :: varchar as amount_code,
	amount_name,
	denominator_value,
	null :: varchar as denominator_code,
	denominator_unit,
	null :: int4,
	null :: int4,
	null :: varchar,
	null :: varchar
from tomap_vmps_ds
where amount_value is not null
;
delete from ds_parsed
where drug_concept_code in
	(select drug_concept_code from tomap_vmps_ds)
;
insert into ds_prototype
select * 
from ds_parsed
where amount_name is not null and drug_concept_code not in (select drug_concept_code from ds_prototype)
;
update ds_prototype d
set
	ingredient_concept_code = (select concept_code from ds_new_ingreds where ingredient_id :: varchar = d.ingredient_name),
	ingredient_name = (select concept_name from ds_new_ingreds where ingredient_id :: varchar = d.ingredient_name)
where
	ingredient_name is not null and
	ingredient_concept_code is null
;
update ds_prototype d set amount_code = (select cd from unit_of_measure where d.amount_name = info_desc) where amount_name is not null;
update ds_prototype d set denominator_code = (select cd from unit_of_measure where d.denominator_name = info_desc) where denominator_name is not null;
;
insert into internal_relationship_stage
select
	d.drug_concept_code,
	coalesce (i.concept_code, d.ingredient_concept_code)
from tomap_vmps_ds d
left join ds_new_ingreds i on
	i.ingredient_id :: varchar = d.ingredient_concept_name
;
drop table if exists ds_stage cascade
;
create table ds_stage
	(
		drug_concept_code varchar (255),
		ingredient_concept_code varchar (255),
		amount_value float8,
		amount_unit varchar (255),
		numerator_value float8,
		numerator_unit varchar (255),
		denominator_value float8,
		denominator_unit varchar (255),
		box_size int4
	)
;
--modify ds_prototype
--replace liters with mls
update ds_prototype d
set --amount
	amount_value = d.amount_value * 1000,
	amount_code = '258773002',
	amount_name = 'ml'
where d.amount_code = '258770004'
;
update ds_prototype d
set --denominator
	denominator_value = d.denominator_value * 1000,
	denominator_code = '258773002',
	denominator_name = 'ml'
where d.denominator_code = '258770004'
;
update ds_prototype d
set --total
	total = d.total * 1000,
	unit_1_code = '258773002',
	unit_1_name = 'ml'
where d.unit_1_code = '258770004'
;
--replace 'drops' with ml denominator
update ds_prototype d
set --total
	denominator_value = d.denominator_value * 0.05, -- 1 pharmaceutical drop ~ 0.05 ml
	denominator_code = '258773002',
	denominator_name = 'ml'
where d.denominator_code = '10693611000001100'
;
--replace grams with mgs
update ds_prototype d
set --amount
	amount_value = d.amount_value * 1000,
	amount_code = '258684004',
	amount_name = 'mg'
where d.amount_code = '258682000'
;
update ds_prototype d
set --denominator
	denominator_value = d.denominator_value * 1000,
	denominator_code = '258684004',
	denominator_name = 'mg'
where d.denominator_code = '258682000'
;
update ds_prototype d
set --total
	total = d.total * 1000,
	unit_1_code = '258684004',
	unit_1_name = 'mg'
where d.unit_1_code = '258682000'
;
--replace kgs with mgs
update ds_prototype d
set --amount
	amount_value = d.amount_value * 1000000,
	amount_code = '258684004',
	amount_name = 'mg'
where d.amount_code = '258683005'
;
update ds_prototype d
set --denominator
	denominator_value = d.denominator_value * 1000000,
	denominator_code = '258684004',
	denominator_name = 'mg'
where d.denominator_code = '258683005'
;
update ds_prototype d
set --total
	total = d.total * 1000000,
	unit_1_code = '258684004',
	unit_1_name = 'mg'
where d.unit_1_code = '258683005'
;
--replace microliters with mls
update ds_prototype d
set --amount
	amount_value = d.amount_value * 0.001,
	amount_code = '258773002',
	amount_name = 'ml'
where d.amount_code = '258774008'
;
update ds_prototype d
set --denominator
	denominator_value = d.denominator_value * 0.001,
	denominator_code = '258773002',
	denominator_name = 'ml'
where d.denominator_code = '258774008'
;
update ds_prototype d
set --total
	total = d.total * 0.001,
	unit_1_code = '258773002',
	unit_1_name = 'ml'
where d.unit_1_code = '258774008'
;
--if denominator is 1000 mg (and total is present and in ml), change to 1 ml
update ds_prototype d
set --denominator
	denominator_value = 1,
	denominator_code = '258773002',
	denominator_name = 'ml'
where
	d.denominator_code = '258684004' and
	d.denominator_value = 1000 and
	d.unit_1_code = '258773002'
;
update ds_prototype d --powders, oils etc; remove denominator and totals
set
	amount_value = 
		case
			when unit_1_code = amount_code then total
			else amount_value
		end,
	denominator_value = null,
	denominator_code = null,
	denominator_name = null,
	total = 
		case
			when unit_1_code != amount_code then total
			else null
		end,
	unit_1_code = 
		case
			when unit_1_code != amount_code then unit_1_code
			else null
		end,
	unit_1_name = 
		case
			when unit_1_code != amount_code then unit_1_name
			else null
		end
where
	amount_value = denominator_value and
	amount_code = denominator_code
;
--respect df_indcd = 2 (continuous)
update ds_prototype 
set
	(amount_value,amount_code,amount_name) = (null,null,null)
where
	denominator_name is null and
	(amount_value, amount_name) in ((1,'mg'),(1000,'mg')) and
	drug_concept_code in (select vpid from vmps where df_indcd in ('2','3'))
;
update ds_prototype 
set
	denominator_value = null
where
	denominator_value = 1 and
	denominator_name in ('ml','dose','square cm','mg') and
	drug_concept_code in (select vpid from vmps where df_indcd in ('2','3'))
;
update ds_prototype 
set
	denominator_value = null,
	amount_value = amount_value / 1000
where
	(denominator_value,denominator_name) in ((1000,'ml'),(1000,'mg')) and
	drug_concept_code in (select vpid from vmps where df_indcd in ('2','3'))
;
update ds_prototype d
--'1 applicator' in total fields is redundant
set
	total = null,
	unit_1_code = null,
	unit_1_name = null
where
	total = 1 and
	unit_1_code = '732980001'
;
--if denominator is in mg, ml should not be in numerator (mostly oils: 1 ml = 800 mg); --1
--if other numerators are present in mg, all other numerators should be, too --2
update ds_prototype d
set
	amount_value = 800 * d.amount_value,
	amount_code = '258684004',
	amount_name = 'mg'
where
	(
		denominator_code = '258684004' and --mg --1
		amount_code = '258773002' --ml
	)
	OR
	(
		exists --2
			(
				select
				from ds_prototype x
				where 
					x.drug_concept_code = d.drug_concept_code and
					x.amount_code != '258773002' --any other dosage
			) and
		amount_code = '258773002' --ml
	)
; --these drugs are useless with ml as dosage
delete from ds_prototype
where 
	(
		lower (drug_name) like '%virus%' or
		lower (drug_name) like '%vaccine%' or
		lower (drug_name) like '%antiserum%'
	) and 
	amount_code = '258773002' and --ml
	denominator_code is null
;
--if drug exists as concentration for VMPS, but has total in grams on VMPP level, convert concentration to MG
update ds_prototype d
set
	denominator_code = '258684004',
	denominator_name = 'mg',
	amount_value = d.amount_value / 1000
where
	d.denominator_value is null and
	d.denominator_code = '258773002' and --ml
	d.total is null and
	d.drug_concept_code in
		(	
				select vpid
				from vmpps v
				where v.qty_uomcd in ('258682000') --g
		) and
	d.drug_concept_code not in -- also does not have ML forms
		(	
				select vpid
				from vmpps v
				where v.qty_uomcd in ('258773002') --ml
		)
;
insert into ds_stage --simple numerator only dosage, no denominator
select distinct
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_name as amount_unit,
	null :: float8,
	null,
	null :: float8,
	null,
	null :: int4
from ds_prototype
where
	denominator_code is null and
	(
		(
			
			(
				unit_1_code not in --will be in num/denom instead
					(
						'258774008', --microlitre
						'258773002', --ml
						'258770004', --litre
						'732981002', --actuation
						'3317411000001100', --dose
						'3319711000001103' --unit dose
					) or
				unit_1_code is null
			)
		) or
		(amount_code = '258773002' and (amount_value, amount_code) = (total, unit_1_code))	--numerator in ml, total in ml, amount equal to total
	)
	and amount_name not like '%/%'
;		
insert into ds_stage --numerator only dosage, but lost denominator
select distinct
	drug_concept_code,
	ingredient_concept_code,
	null :: int4,
	null,
	amount_value as numerator_value,
	amount_name as numerator_unit,
	total as denominator_value,
	unit_1_name as denominator_unit,
	null :: float8
from ds_prototype
where
	denominator_code is null and
	unit_1_code in --will be in num/denom instead
		(
			'258774008', --microlitre
			'258773002', --ml
			'258770004', --litre
			'732981002', --actuation
			'3317411000001100', --dose
			'3319711000001103' --unit dose
		)
	and amount_name not like '%/%'
	and not (amount_code = '258773002' and (amount_value, amount_code) = (total, unit_1_code)) --numerator in ml, total in ml, amount equal to total
;
insert into ds_stage --literally 2 concepts with mg/g as numerator code
select distinct
	drug_concept_code,
	ingredient_concept_code,
	null :: float8,
	null,
	amount_value as numerator_value,
	'mg' as numerator_unit,
	1 as denominator_value,
	'ml' as denominator_unit,
	null :: int4
from ds_prototype
where
	denominator_code is null and
	amount_code = '408168009' --mg/g
;
insert into ds_stage --simple numerator+denominator
select distinct
	drug_concept_code,
	ingredient_concept_code,
	null :: float8,
	null,
	amount_value,
	amount_name,
	denominator_value,
	denominator_name,
	null :: int4
from ds_prototype d
where
	denominator_code is not null and
	(
		unit_1_code is null or
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
				) and
			unit_1_code != denominator_code and
			total = 1
		)
	)
;
insert into ds_stage --simple numerator+denominator, total amount provided in same units as denominator
select distinct
	drug_concept_code,
	ingredient_concept_code,
	null :: float8,
	null,
	amount_value * total / denominator_value as numerator_value,
	amount_name,
	total as denominator_value,
	denominator_name,
	null :: int4
from ds_prototype d
where
	denominator_code = unit_1_code and
	not exists --all components of drug should follow same rule
		(
			select
			from ds_prototype p
			where
				d.drug_concept_code = p.drug_concept_code and
				denominator_code != unit_1_code
		)
;
insert into ds_stage --simple numerator+denominator, total amount provided in same units as numerator
select distinct
	drug_concept_code,
	ingredient_concept_code,
	null :: float8,
	null,
	total as numerator_value,
	amount_name,
	denominator_value * total / amount_value as denominator_value,
	denominator_name,
	null :: int4
from ds_prototype d
where
	amount_code = unit_1_code and
	denominator_code != amount_code and
	not exists --all components of drug should follow same rule
		(
			select
			from ds_prototype p
			where
				d.drug_concept_code = p.drug_concept_code and
				amount_code != unit_1_code
		)
;
--AMPs
--Take note that we omit excipients completely and just inherit VMP relations
--if we ever need excipients, we can find them in AP_INGREDIENT table
insert into ds_stage
select distinct
	a.apid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
from ds_stage d
join amps a on
	d.drug_concept_code = a.vpid --this will include packs, both proper components and monocomponent packs
;
--VMPPs
--inherited from VMPs with added box size
drop table if exists ds_insert
;
create table ds_insert as --intermediate entry
select distinct
	p.vppid,
	p.nm,
	p.qtyval,
	u.cd as box_code,
	u.info_desc as box_name,
	o.*
from vmpps p
join UNIT_OF_MEASURE u on
	p.qty_uomcd = u.cd
join ds_prototype o on
	o.drug_concept_code = p.vpid
;
--replace grams with mgs
update ds_insert d
set 
	qtyval = d.qtyval * 1000,
	box_code = '258684004',
	box_name = 'mg'
where d.box_code = '258682000'
;
--replace liters with mls
update ds_insert d
set
	qtyval = d.qtyval * 1000,
	box_code = '258773002',
	box_name = 'ml'
where d.box_code = '258770004'
;
insert into ds_stage --any dosage type, nonscalable
select distinct
 	i.vppid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	coalesce (i.qtyval, d.box_size) as box_size
from ds_insert i
join ds_stage d on
	i.drug_concept_code = d.drug_concept_code
where
	--(i.box_code = i.unit_1_code or i.unit_1_code is null) and
	(i.box_code not in --nonscalable forms only
		(
			'258684004', --mg
			'258774008', --microlitre
			'258773002', --ml
			'258770004', --litre
			'732981002', --actuation
			'3317411000001100', --dose
			'3319711000001103' --unit dose
		) or
	(
		i.denominator_code in ('258773002','258684004') and --ml, mg
		i.box_code = '3319711000001103' --unit dose
	) or
	(
		i.denominator_code in ('732981002','10692211000001108') and --actuation, application
		i.box_code = '3317411000001100' --dose
	)) and
	i.vppid not in (select drug_concept_code from ds_stage)
;
insert into ds_stage --simple dosage, same box forms as in VMP or no box form in VMP, scalable
select distinct
 	i.vppid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	i.qtyval as amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
from ds_insert i
join ds_stage d on
	i.drug_concept_code = d.drug_concept_code
where
	(
		(i.box_code = i.unit_1_code or i.unit_1_code is null) and
		d.amount_unit is not null and
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
	and i.vppid not in (select drug_concept_code from ds_stage)
;
insert into ds_stage --num/denom dosage, same box forms as in VMP or no box form in VMP, scalable (e.g. solution)
select distinct
 	i.vppid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value * i.qtyval / coalesce (d.denominator_value,1),
	d.numerator_unit,
	i.qtyval as denominator_value,
	d.denominator_unit,
	null :: int4 as box_size
from ds_insert i
join ds_stage d on
	i.drug_concept_code = d.drug_concept_code
where
	((
		i.box_code = i.unit_1_code or 
		i.unit_1_code is null
	) and
	d.numerator_unit is not null and
	d.denominator_unit is not null and
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
		) and
	i.vppid not in (select drug_concept_code from ds_stage)
;
insert into ds_stage
with to_insert as --some additional fixes to num/den given forms
	(
		select distinct 
			d.vppid, d.qtyval, d.box_code, d.drug_concept_code,
			d.ingredient_concept_code, d.amount_value, d.amount_name,
			d.denominator_value, d.denominator_code,d.denominator_name
		from ds_insert d
		join ds_stage a on
			d.drug_concept_code = a.drug_concept_code
		where 
			vppid not in (select drug_concept_code from ds_stage) and 
			denominator_code is not null
	)
select
	vppid as drug_concept_code,
	ingredient_concept_code,
	null :: int4,
	null :: varchar,
	amount_value * qtyval / coalesce (denominator_value, 1) as numerator_value,
	amount_name as numerator_unit,
	qtyval as denominator_value,
	denominator_name as denominator_unit,
	null :: int4
from to_insert 
where denominator_code = box_code and
	vppid not in (select drug_concept_code from ds_stage)
;
--Add VMPP drugs that don't have dosage on VMP level
insert into ds_stage
with ingred_count as
	(
		select i.concept_code_1
		from internal_relationship_stage i
		join drug_concept_stage d2 on
			d2.concept_code = i.concept_code_2 and
			d2.concept_class_id = 'Ingredient'
		group by i.concept_code_1
		having count (i.concept_code_2) = 1
	)
select 
	p.vppid as drug_concept_code,
	d2.concept_code as ingredient_concept_code,	
	p.qtyval as amount_value,
	u.info_desc as amount_unit,
	null :: int4,
	null :: varchar,
	null :: int4,
	null :: varchar,
	null :: int4
from internal_relationship_stage i
join ingred_count c on
	c.concept_code_1 = i.concept_code_1
join drug_concept_stage d2 on
	d2.concept_code = i.concept_code_2 and
	d2.concept_class_id = 'Ingredient'
join vmps v on
	v.vpid = i.concept_code_1
join vmpps p on
	v.vpid = p.vpid
join UNIT_OF_MEASURE u on
	u.cd = p.qty_uomcd
left join ds_stage s on
	s.drug_concept_code = i.concept_code_1
where
	s.drug_concept_code is null and
	/*lower (d2.concept_name) not like '%homeopathic%' and
	lower (v.nm) not like '%generic%' andf
	v.df_indcd != '1'*/
		(
			d2.concept_code = '387398009' or --Podophyllum resin
			d2.concept_code = '398628008' or --Activated charcoal
			d2.concept_name like '% oil' or
			d2.concept_name like '% liquid extract' or
			v.nm like '% powder'
		) and
	p.vppid not in (select drug_concept_code from ds_stage)
;/*
drop table if exists tomap_vmpps_ds
;
create table tomap_vmpps_ds as
select distinct 
	vppid as drug_concept_code, nm as drug_name, d.ingredient_concept_code, d.ingredient_name, d.amount_value, d.amount_code, d.amount_name, d.denominator_value, d.denominator_code, d.denominator_name, null :: int4 as amount
from ds_insert d
join ds_stage a on
	d.drug_concept_code = a.drug_concept_code
where 
	vppid not in (select drug_concept_code from ds_stage) and
	vppid not in (select drug_concept_code from tomap_vmpps_ds)
;
WbImport -file=/home/ekorchmar/Documents/dmd/tomap_vmpps_ds.csv
         -type=text
         -table=tomap_vmpps_ds
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=drug_concept_code,drug_name,ingredient_concept_code,ingredient_name,amount_value,amount_code,amount_name,denominator_value,denominator_code,denominator_name,amount
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;*/
delete from ds_stage where drug_concept_code in (select drug_concept_code from tomap_vmpps_ds)
;
insert into ds_stage
select 
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_name,
	null :: int4,
	null :: varchar,
	null :: int4,
	null :: varchar,
	amount
from tomap_vmpps_ds 
where denominator_code is null
;
insert into ds_stage
select 
	drug_concept_code,
	ingredient_concept_code,
	null :: int4,
	null :: varchar,
	amount_value,
	amount_name,
	denominator_value,
	denominator_name,
	amount
from tomap_vmpps_ds 
where denominator_code is not null
;
--Doses only on VMPP level, no VMP entry
with counter as 
	(
		select vpid
		from virtual_product_ingredient
		group by vpid
		having count (isid) = 1
	)
insert into ds_stage
select
	p.vppid as drug_concept_code,
	coalesce (r.isidnew,i.isid) as ingredient_concept_code,
	p.qtyval as amount_value,
	u.info_desc as amount_unit,
	null :: int4,
	null :: varchar,
	null :: int4,
	null :: varchar,
	null :: int4
from vmpps p
join virtual_product_ingredient i using (vpid)
join UNIT_OF_MEASURE u on u.cd = p.qty_uomcd
join counter o using (vpid)
left join ingred_replacement r on r.isidprev = i.isid
left join devices d using (vpid)
left join ds_stage s on p.vppid = s.drug_concept_code
left join pc_stage c on c.pack_concept_code = p.vppid
where
	u.cd in	( '258682000','258770004','258773002') and
	d.vpid is null and
	s.drug_concept_code is null and
	c.pack_concept_code is null
;
-- dosed solutions (3319711000001103 unit dose)
insert into ds_stage
select
	v.vppid,
	d1.ingredient_concept_code,
	d1.amount_value,
	d1.amount_unit,
	d1.numerator_value,
	d1.numerator_unit,
	d1.denominator_value,
	d1.denominator_unit,
	v.qtyval
from vmpps v
join ds_stage d1 on
	v.vpid = d1.drug_concept_code
join drug_concept_stage x on
	x.concept_code = v.vpid
left join ds_stage d2 on
	v.vppid = d2.drug_concept_code
where
	d2.drug_concept_code is null and
	v.qty_uomcd = '3319711000001103'
;
-- actuations (3317411000001100 dose)
insert into ds_stage
select
	v.vppid,
	d1.ingredient_concept_code,
	null :: int4 as amount_value,
	null :: varchar as amount_unit,
	d1.numerator_value * v.qtyval,
	d1.numerator_unit,
	v.qtyval, 
	d1.denominator_unit,
	null :: int4
from vmpps v
join ds_stage d1 on
	v.vpid = d1.drug_concept_code
join drug_concept_stage x on
	x.concept_code = v.vpid
left join ds_stage d2 on
	v.vppid = d2.drug_concept_code
where
	d2.drug_concept_code is null and
	v.qty_uomcd = '3317411000001100' and
	d1.denominator_unit is not null
;
--inherit AMPPs from VMPPs
insert into ds_stage
select distinct
	a.appid as drug_concept_code,
	d.ingredient_concept_code,
	d.amount_value,amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
from ds_stage d
join ampps a on
	d.drug_concept_code = a.vppid
;
--remove denominator values for VMPs and AMPs with df_indcd = 2
update ds_stage d
set
	numerator_value = d.numerator_value / d.denominator_value,
	denominator_value = null
where
	denominator_unit is not null and
	denominator_value is not null and
	(
		exists
			(
				select
				from vmps
				where
					vpid = d.drug_concept_code and
					df_indcd = '2'
			) or
		exists
			(
				select
				from amps a
				join vmps v on
					a.vpid = v.vpid
				where
					a.apid = d.drug_concept_code and
					v.df_indcd = '2'
			)
	)
;
--udfs is given in spoonfuls
update ds_stage d
set
	numerator_value = d.numerator_value / d.denominator_value,
	denominator_value = null
where
	drug_concept_code in 
		(
			select vpid from vmps where unit_dose_uomcd in ('733015007'/*,'258773002'*/) --spoonful, ml
				union all
			select apid from vmps join amps using (vpid) where unit_dose_uomcd in ('733015007'/*,'258773002'*/) --spoonful, ml
		) and 
	denominator_unit is not null and
	denominator_value is not null
;
--1-hour patches, 1-actuation inhalers 
update ds_stage d
set 
	denominator_value = null,
	box_size = null
where
	denominator_value = 1 and
	denominator_unit in ('hour', 'dose')
;
update ds_stage
set	
	numerator_value =
	case 
		when box_size > 10 then box_size * numerator_value
		else numerator_value
	end,
	denominator_value = 
	case
		when box_size > 10 then box_size
		else null
	end,
	box_size = null
where
	denominator_unit in ('application','actuation') and
	denominator_value = 1
;
--split 3511411000001105 Aluminium hydroxide / Magnesium carbonate co-gel
-- --> 3511711000001104 Aluminium hydroxide dried
-- --> 387401007 Magnesium carbonate
delete from ds_stage --since we don't have exact dosages when we split it
where drug_concept_code in (select concept_code_1 from internal_relationship_stage where concept_code_2 = '3511411000001105')
;
insert into internal_relationship_stage
select 
	concept_code_1,
	'3511711000001104'
from internal_relationship_stage
where concept_code_2 = '3511411000001105'
;
insert into internal_relationship_stage
select 
	concept_code_1,
	'387401007'
from internal_relationship_stage
where concept_code_2 = '3511411000001105'
;
delete from ds_stage d
where ingredient_concept_code in ('229862008','9832211000001107','24581311000001102','3511411000001105','3577911000001100','4727611000001109','412166009','50213009') --solvents (Syrup, Ether solvent) and unsplittable ingredients, chloride ion
and not exists --not only ingredient
	(
		select x.concept_code_1
		from internal_relationship_stage x
		join drug_concept_stage c on
			c.concept_code = x.concept_code_2 and
			c.concept_class_id = 'Ingredient'
		where x.concept_code_1 = d.drug_concept_code
		group by x.concept_code_1
		having count (x.concept_code_2) = 1
	)
;
delete from internal_relationship_stage i
where concept_code_2 in ('229862008','9832211000001107','24581311000001102','3511411000001105','3577911000001100','4727611000001109','412166009','50213009')
and not exists --not only ingredient
	(
		select x.concept_code_1
		from internal_relationship_stage x
		join drug_concept_stage c on
			c.concept_code = x.concept_code_2 and
			c.concept_class_id = 'Ingredient'
		where x.concept_code_1 = i.concept_code_1
		group by x.concept_code_1
		having count (x.concept_code_2) = 1
	)
;
delete from ds_stage where amount_unit = 'cm' -- parsing artifact
;
--replace unit codes with names for boiler
update drug_concept_stage
set	concept_code = concept_name
where concept_class_id = 'Unit'
;
delete from ds_stage d --removes duplicates among semisolid drug dosages
where
	denominator_unit = 'ml' and
	exists
		(
			select
			from ds_stage x
			where 
				denominator_unit != 'ml' and
				d.drug_concept_code = x.drug_concept_code
		)
;
update ds_stage
set	ingredient_concept_code = 
	(
		select distinct isidnew from ingred_replacement where isidprev = ingredient_concept_code
	)
where ingredient_concept_code in (select isidprev from ingred_replacement)
;
update drug_concept_stage
set	concept_code = concept_name
where concept_class_id = 'Unit'
;
delete from ds_stage d --removes duplicates among inhaled drug dosages
where
	denominator_unit = 'dose' and
	exists
		(
			select
			from ds_stage x
			where 
				denominator_unit != 'dose' and
				d.drug_concept_code = x.drug_concept_code
		)
;
--if the ingredient amount is given in mls, transform to 1000 mg -- unless it's a gas
create or replace view nongas2fix as
SELECT distinct ingredient_concept_code
FROM ds_stage
WHERE 
	numerator_unit IN ('ml') or
	amount_unit IN ('ml')
	
	except

select c.concept_code --use SNOMED to find gas descendants
from ancestor_snomed a
join concept c on
	c.concept_id = a.descendant_concept_id 
join concept c2 on
	c2.concept_id = a.ancestor_concept_id and
	c2.concept_code in ('74947009','290032000') --Gases, Inert gases, Gaseous substance
;
update ds_stage
set
	amount_value = amount_value * 1000,
	amount_unit = 'mg'
where
	amount_unit = 'ml' and
	ingredient_concept_code in (select ingredient_concept_code from nongas2fix)
;
update ds_stage
set
	numerator_value = numerator_value * 1000,
	numerator_unit = 'mg'
where
	numerator_unit = 'ml' and
	ingredient_concept_code in (select ingredient_concept_code from nongas2fix)
;
--replace relations to ingredients in irs with ones from ds_stage
delete from internal_relationship_stage
where
	concept_code_1 in (select drug_concept_code from ds_stage) and
	concept_code_2 in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient')
;
insert into internal_relationship_stage
select
	drug_concept_code,
	ingredient_concept_code
from ds_stage
;
--reuse only_1_pack to preserve packs with only 1 drug as this exact component
insert into ds_stage
select distinct
	o.pack_concept_code,
	d.ingredient_concept_code,
	d.amount_value,
	d.amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	null :: int4 as box_size
from ds_stage d
join only_1_pack o on
	o.drug_concept_code = d.drug_concept_code and
	o.pack_concept_code not in (select x.drug_concept_code from ds_stage x) --orphan concepts may already have had entry despite being a pack (4161311000001109)
;

-- 4. Map attributes except Brand Names and Suppliers to concept

drop table if exists tomap_ingredients
;
create table tomap_ingredients as
select distinct 
	c1.concept_id as snomed_id,
	s.concept_code as source_code,
	s.concept_name as source_name,
	coalesce (c0.concept_id, c4.concept_id, c3.concept_id, c2.concept_id, cn2.concept_id, cn.concept_id) as concept_id,
	coalesce (c0.concept_name, c4.concept_name, c3.concept_name, c2.concept_name, cn2.concept_name, cn.concept_name) as concept_name,
	coalesce (c0.vocabulary_id, c4.vocabulary_id, c3.vocabulary_id, c2.vocabulary_id, cn2.vocabulary_id, cn.vocabulary_id) as vocabulary_id,
	coalesce (c0.concept_class_id, c4.concept_class_id, c3.concept_class_id, c2.concept_class_id, cn2.concept_class_id, cn.concept_class_id) as concept_class_id,
	coalesce (r0.precedence,1) as precedence
from drug_concept_stage s 

left join r_to_c_all r0 on
	lower (r0.concept_name) = s.concept_name and
	r0.concept_class_id = 'Ingredient'
left join concept c0 on
	c0.concept_id = r0.concept_id

--mapping with source given relations
left join concept c1 on
	c1.vocabulary_id = 'SNOMED' and
	c1.concept_code = s.concept_code
left join concept_relationship r on
	r.relationship_id = 'SNOMED - RxNorm eq' and
	r.concept_id_1 = c1.concept_id and
	r.invalid_reason is null
left join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.concept_class_id != 'Brand Name' and
	c2.invalid_reason is null
left join concept_relationship r2 on
	r2.concept_id_1 = c2.concept_id and
	c2.concept_class_id = 'Precise Ingredient' and
	r2.invalid_reason is null and
	r2.relationship_id = 'Form of'
left join concept c3 on
	c3.concept_id = r2.concept_id_2 and
	c3.invalid_reason is null
left join ds_new_ingreds n on --manual ingredients
	n.concept_code = s.concept_code
left join concept c4 on
	c4.concept_id = n.ingredient_id

--direct (lower) name equivalency
left join concept cn2 on
	s.concept_name = cn2.concept_name and
	cn2.standard_concept = 'S' and
	cn2.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
	cn2.concept_class_id = 'Ingredient'

left join concept cn on
	cn.standard_concept = 'S' and
	cn.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
	cn.concept_class_id = 'Ingredient' and
	lower (regexp_replace (s.concept_name,'(^([DL]){1,2}-)|((pollen )?allergen )|( (light|heavy|sodium|anhydrous|dried|solution|distilled|\w{0,}hydrate(d)?|compound|hydrochloride|bromide)$)|"','')) = lower (cn.concept_name)

where
	s.concept_class_id = 'Ingredient' and
	s.concept_code not in (select isidprev from ingred_replacement)
;
delete from tomap_ingredients where concept_class_id = 'Precise Ingredient' --caused by multiple 'SNOMED - RxNorm eq' relations without proper transition to molecular ingredient
;
delete from tomap_ingredients t --remove nulls from ambiguous mappings
where
	t.concept_id is null and
	1 !=
		(
			select count (1)
			from tomap_ingredients x
			where x.source_code = t.source_code
		)
;
--for ambiguous mappings pick ones with the closest names (e.g. Levenshtein's algorithm)
with lev as
	(
		select source_code, min (devv5.levenshtein (source_name, concept_name)) as dif
		from tomap_ingredients
		group by source_code
	)
delete from tomap_ingredients t
where 
	source_code in
		(
			select source_code 
			from tomap_ingredients
			group by source_code 
			having count (concept_id) > 1
		) and 
	devv5.levenshtein (source_name, concept_name) > (select dif from lev where lev.source_code = t.source_code)
;
DROP TABLE IF EXISTS relationship_to_concept CASCADE
;
CREATE TABLE relationship_to_concept
(
   concept_code_1     varchar(50),
   vocabulary_id_1    varchar(20),
   concept_id_2       integer,
   precedence         integer,
   conversion_factor  float8
)
;/*
drop table if exists tomap_ingreds_man
;
--create table tomap_ingreds_man as
select distinct 
	t.source_code,
	t.source_name,
	c.concept_id,
	c.concept_name,
	c.vocabulary_id,
	t.precedence
from tomap_ingredients t
left join concept c on
	c.concept_id = t.concept_id and
	c.standard_concept = 'S' and
	c.concept_class_id = 'Ingredient'
where
	t.concept_id is null and
	t.source_code in (select concept_code_2 from internal_relationship_stage) and
	t.source_code in (select source_code from tomap_ingredients) and
	t.source_code not in (select source_code from tomap_ingreds_man)
;
WbImport -file=/home/ekorchmar/Documents/dmd/tomap_ingreds_man.csv
         -type=text
         -table=tomap_ingreds_man
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=source_code,source_name,concept_id,concept_name,vocabulary_id,precedence
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;*/
delete from tomap_ingreds_man
where source_code not in (select source_code from tomap_ingredients)
;
insert into relationship_to_concept
select distinct
	source_code as concept_code_1,
	'dm+d' as vocabulary_id_1,
	concept_id as concept_id_2,
	coalesce (precedence,1),
	null :: int4 as conversion_factor
from tomap_ingreds_man
where 
	concept_id is not null and
	source_code in (select concept_code from drug_concept_stage) and
	source_code not in (select concept_code_1 from relationship_to_concept)
;
insert into relationship_to_concept 
select distinct
	source_code,
	'dm+d',
	concept_id,
	1,
	null :: int4
from tomap_ingredients
where 
	concept_id is not null and
	source_code not in
		(
			select source_code
			from tomap_ingreds_man
			where concept_id is not null
		)
;/*
drop table if exists tomap_units_man
;
-- create table tomap_units_man as
select
	concept_code as concept_code_1,
	concept_name as source_name,
	null :: int4 as concept_id_2,
	null :: varchar (255) as concept_name,
	null :: float8  as conversion_factor
from drug_concept_stage
where concept_class_id = 'Unit' and
	exists
		(
			select from ds_stage
			where 
				concept_code = amount_unit or
				concept_code = numerator_unit or
				concept_code = denominator_unit
		) and
	concept_name not in (select source_name from tomap_units_man)
;
WbImport -file=/home/ekorchmar/Documents/dmd/tomap_units_man.csv
         -type=text
         -table=tomap_units_man
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=concept_code_1,source_name,concept_id_2,concept_name,conversion_factor
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100
;*/;
insert into relationship_to_concept
select
	source_name,
	'dm+d' as vocabulary_id_1,
	concept_id_2,
	1 as precedence,
	coalesce (conversion_factor,1)
from tomap_units_man
;/*
drop table if exists tomap_forms
;
-- create table tomap_forms as
select
	concept_code as source_code,
	concept_name as source_name,
	null :: int4 as mapped_id,
	null :: varchar as mapped_name,
	null :: int4 as precedence
from drug_concept_stage
where 
	concept_class_id = 'Dose Form' and
	concept_code not in (select concept_code from tomap_forms)
;
WbImport -file=/home/ekorchmar/Documents/dmd/tomap_forms.csv
         -type=text
         -table=tomap_forms
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=source_code,source_name,mapped_id,mapped_name,precedence
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100
;*/;
insert into relationship_to_concept
select
	source_code,
	'dm+d' as vocabulary_id_1,
	mapped_id,
	coalesce (precedence,1),
	null :: int4
from tomap_forms
;
alter table ds_stage -- add mapped ingredient's concept_id to aid next step in dealing with dublicates
add concept_id int4
;
update ds_stage
set concept_id =
	(
		select concept_id_2
		from relationship_to_concept
		where
			concept_code_1 = ingredient_concept_code and
			precedence = 1
	)
;
--Fix ingredients that got replaced/mapped as same one (e.g. Sodium ascorbate + Ascorbic acid => Ascorbic acid)
drop table if exists ds_split
;
create table ds_split as
select distinct
	drug_concept_code,
	min (ingredient_concept_code :: bigint) over (partition by drug_concept_code, concept_id) :: varchar as ingredient_concept_code, --one at random
	sum (amount_value) over (partition by drug_concept_code, concept_id) as amount_value,
	amount_unit,
	sum (numerator_value) over (partition by drug_concept_code, concept_id) as numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	null :: int4 as box_size,
	concept_id
from ds_stage
where
	(drug_concept_code, concept_id) in
	(
		SELECT drug_concept_code, concept_id
		FROM ds_stage
		GROUP BY drug_concept_code, concept_id
		HAVING COUNT(*) > 1
	)
;
delete from ds_stage
where
	(drug_concept_code, concept_id) in
	(
		SELECT drug_concept_code, concept_id
		FROM ds_split
	)
;
insert into ds_stage 
select *
from ds_split
;
alter table ds_stage
drop column concept_id
;
update ds_stage d -- if source does not give all denominators for all ingredients
set
	(numerator_value, numerator_unit) = (d.amount_value, d.amount_unit),
	(amount_value, amount_unit) = (null,null),
	(denominator_value, denominator_unit) = 
		(
			select distinct x.denominator_value, x.denominator_unit
			from ds_stage x
			where
				x.denominator_unit is not null and
				x.drug_concept_code = d.drug_concept_code
		)
where
	d.denominator_unit is null and
	exists
		(
			select
			from ds_stage s
			where
				s.drug_concept_code = d.drug_concept_code and
				s.denominator_unit is not null
		)
;
--final fix ('dose unit' is ambiguous in source data)
update ds_stage
set
	(amount_value, amount_unit) = (numerator_value, numerator_unit),
	(numerator_value, numerator_unit,denominator_value, denominator_unit) = (null,null,null,null)
where
	denominator_unit = 'unit dose' and
	ingredient_concept_code = '38686006'
;
update ds_stage
set	(denominator_value, denominator_unit) = (null, 'actuation')
where denominator_unit = 'unit dose'
;
delete from internal_relationship_stage -- replace ingredients with ones from ds_stage (since it was reworked a mano) where aplicable
where
	exists (select from ds_stage where drug_concept_code = concept_code_1) and
	exists (select from drug_concept_stage where concept_class_id = 'Ingredient' and concept_code = concept_code_2)
;
insert into internal_relationship_stage
select distinct
	drug_concept_code,
	ingredient_concept_code
from ds_stage
;
--1 ml given by source is not always 1 ml in reality
drop table if exists fix_1ml
;
create table fix_1ml as
select vpid
from ds_stage, drug_concept_stage, vmps
where 
	(denominator_value, denominator_unit) = (1,'ml') and
	drug_concept_code = concept_code and
	vpid = drug_concept_code and
	not (concept_name like '%/1ml%' or concept_name like '% 1ml%') and
	source_concept_class_id = 'VMP' and
	((udfs, udfs_uomcd) != (1,'258773002') or udfs is null)
;
insert into fix_1ml
select vppid from vmpps, ds_stage
where 
	vpid in (select vpid from fix_1ml) and
	vppid = drug_concept_code and
	(qtyval, qty_uomcd) != (1,'258773002') and
	(denominator_value, denominator_unit) = (1,'ml')
;
insert into fix_1ml
select apid from amps
join fix_1ml using (vpid)
;
insert into fix_1ml
select appid from ampps
join fix_1ml on vpid = vppid
;
update ds_stage
set
	denominator_value = null,
	box_size = null
where
	drug_concept_code in 
		(
			select vpid from fix_1ml
		)
;
-- 5. Find and map Brand Names (using SNOMED logic), map suppliers

--NOTE: despite that some VMPs and VMPPs have Brand Names in their names, we purposefully only build relations from AMPs and AMPPs.
--VMPS are identical to Clinical Drugs by design. They are virtual products that are not meant to have Supplier or a Brand Name
--Also, "Generic %BRAND_NAME%" format is being gradually phased out with dm+d updates.

drop table if exists brands
;
create table brands as --all brand names given by UK SNOMED
	(
		select c2.concept_id as brand_id, c2.concept_code as brand_code, replace (c2.concept_name, ' - brand name','') as brand_name
		from concept_relationship cr
		join concept cx on
			cr.concept_id_1 = cx.concept_id and
			cx.vocabulary_id = 'SNOMED' and
			cx.concept_code = '9191801000001103' --NHS dm+d trade family
		join concept c2 on
			cr.concept_id_2 = c2.concept_id
	)
;
drop table if exists amps_to_brands
;
create table amps_to_brands as --AMPs to snomed Brand Names by proper relations
select distinct d.concept_code, d.concept_name, b.brand_code, b.brand_name--, null :: int4 mapped_id
from drug_concept_stage d
join concept c on
	c.vocabulary_id = 'SNOMED' and
	c.concept_code = d.concept_code and
	d.source_concept_class_id = 'AMP' and
	d.domain_id = 'Drug'
join concept_relationship r on
	c.concept_id = r.concept_id_1
join brands b on
	b.brand_id = r.concept_id_2
where
	d.source_concept_class_id = 'AMP' and
	d.domain_id = 'Drug'
;
insert into amps_to_brands
select distinct d.concept_code, d.concept_name, s.brand_code, s.brand_name
from drug_concept_stage d
left join amps_to_brands b1 using (concept_code)
join amps_to_brands s on
	s.concept_name = d.concept_name
where
	d.source_concept_class_id = 'AMP' and
	d.domain_id = 'Drug' and
	b1.concept_code is null
;
drop table if exists tofind_brands --finding brand names by name match and manual work
;
--AVOF-339
delete from amps_to_brands where brand_name = 'Co-careldopa'
;
create table tofind_brands as
with ingred_relat as
	(
		select i.concept_code_1, i.concept_code_2, d.concept_name
		from internal_relationship_stage i
		join drug_concept_stage d on
			d.concept_class_id = 'Ingredient' and
			d.concept_code = i.concept_code_2 and
			i.concept_code_1 in
				(
					select c1.concept_code
					from drug_concept_stage c1
					join internal_relationship_stage ix on
						ix.concept_code_1 = c1.concept_code
					join drug_concept_stage c2 on
						c2.concept_class_id = 'Ingredient' and
						c2.concept_code = ix.concept_code_2
					group by c1.concept_code
					having count (distinct concept_code_2) = 1
				)
	)
select 
	d.concept_code, 
	d.concept_name, 
	i.concept_code_2, 
	i.concept_name as concept_name_2,
	length (regexp_replace (d.concept_name,' .*$','')) as min_length
from drug_concept_stage d
left join ingred_relat i on
	i.concept_code_1 = d.concept_code
where
	d.source_concept_class_id = 'AMP' and
	d.domain_id = 'Drug' and
	d.concept_code not in (select concept_code from amps_to_brands)
;
delete from tofind_brands --single ingredient, concept is named after ingredient
where
	/*regexp_match 
		(
			lower (concept_name),
			regexp_replace (lower (concept_name_2),' .*$', '')
		) is not null*/
	concept_name ilike regexp_replace ((concept_name_2),' .*$', '') || '%'
;
delete from tofind_brands 
where 
	concept_name like 'Vitamin %' or
	concept_name like 'Arginine %' or
	concept_name like 'Benzoi%' or
	regexp_match (concept_name,'^([A-Z ]+ [\w.%/]+ (\(.*\) )?\/ )+[A-Z ]+ [\w.%/]+( \(.*\) )? [\w. ]+$','im') is not null --listed multiple ingredients and strengths without a BN
;
drop table if exists b_temp
;
drop table if exists x_temp
;
create index idx_tf_b on tofind_brands (lower(concept_name))
;
analyze tofind_brands
;
drop table if exists rx_concept
;
create table rx_concept as
select 
	c.concept_id,
	c.concept_name,
	c.vocabulary_id
from concept c
where
	c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
	c.concept_class_id = 'Brand Name' and
	c.invalid_reason is null
;
create index if not exists idx_tf_c on rx_concept (lower(concept_name))
;
analyze rx_concept
;
delete from rx_concept r1 
where exists
	(
		select
		from rx_concept r2
		where 
			lower (r1.concept_name) = lower (r2.concept_name) and
			r1.vocabulary_id = 'RxNorm Extension' and
			(
				r2.vocabulary_id = 'RxNorm' or --RxE duplicates RxN
				(
					r2.vocabulary_id = 'RxNorm Extension' and
					r1.concept_id > r2.concept_id
				)
			)
	)
;
	create unlogged table x_temp as
		(
			select distinct
				b.concept_code, 
				b.concept_name,
				c.concept_id as brand_id,
				c.concept_name as brand_name,
				c.vocabulary_id,
				length (c.concept_name) as score,
				b.min_length --prevent match by cutoff words
			from tofind_brands b
			left join rx_concept c on
				lower (b.concept_name) like lower (c.concept_name) || '%'	
		)
;
drop table if exists b_temp --name match
;
create table b_temp as
with max_score as
	(
		select 
			concept_code,
			max (score) over (partition by concept_code) as score
		from x_temp x
		where min_length <= score --cut off shorter than first word
	)
select distinct x.concept_code, x.concept_name, x.brand_id, x.brand_name
from x_temp x
join max_score m using (concept_code, score)
;
delete from b_temp
where brand_id in (40816247,21017606,21016413) --RxE duplicating RxN
;
delete from tofind_brands --found
where concept_code in (select concept_code from b_temp)
;
with brand_extract as
	(
		select distinct s.brand_code, b.brand_name
		from b_temp b
		left join amps_to_brands s using (brand_name)
	),
brands_assigned as --assign OMOP codes
	(
		select 
			brand_name,
			coalesce (brand_code, 'OMOP' || nextval ('new_seq')) as brand_code
		from brand_extract
	)
insert into amps_to_brands
select
	b.concept_code, 
	b.concept_name,
	a.brand_code,
	b.brand_name
from b_temp b
join brands_assigned a using (brand_name)
;/*
drop table if exists tofind_brands_man
;
-- create table tofind_brands_man as
select
	concept_code, 
	concept_name,
	null :: int4 as brand_id,
	trim (regexp_replace (concept_name, ' .*$','')) :: varchar as brand_name
from tofind_brands
where concept_code not in (select concept_code from tofind_brands_man)
;
WbImport -file=/home/ekorchmar/Documents/dmd/tofind_brands_man.csv
         -type=text
         -table=tofind_brands_man
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=concept_code,concept_name,brand_id,brand_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;*/
;
delete from tofind_brands_man
where concept_code not in (select concept_code from tofind_brands)
;
insert into amps_to_brands --assign codes to manually found brands
with man_brands as
	(
		select distinct s.brand_code, t.brand_name
		from tofind_brands_man t
		left join amps_to_brands s using (brand_name)
		where t.brand_name is not null
	),
brand_codes as
	(
		select 
			coalesce (brand_code, 'OMOP' || nextval ('new_seq')) as brand_code, --prevent duplicating by reusing codes
			brand_name
		from man_brands
	)
select
	t.concept_code,
	t.concept_name,
	o.brand_code,
	t.brand_name
from tofind_brands_man t
join brand_codes o on lower (o.brand_name) = lower (t.brand_name)
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
SELECT distinct
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
FROM amps_to_brands
;
drop table if exists brand_replace
;
create table brand_replace as 
--brand names from different sources may have the same name, replace with the smallest code
--numeric SNOMED codes are therefore preferred over OMOP codes (string comparisment rules)
select distinct
	concept_code,
	min (concept_code) over (partition by concept_name) as true_code
from drug_concept_stage
where concept_class_id = 'Brand Name'
;
delete from brand_replace
where true_code = concept_code
;
delete from drug_concept_stage
where concept_code in (select concept_code from brand_replace)
;
--AMPs to Brand Names
insert into internal_relationship_stage
select distinct
	s.concept_code,
	coalesce (r.true_code, s.brand_code)
FROM amps_to_brands s
left join brand_replace r on
	s.brand_code = r.concept_code
;
--AMPPS to Brand Names
insert into internal_relationship_stage
select distinct
	a.appid,
	coalesce (r.true_code, b.brand_code)
from amps_to_brands b
join ampps a on
	a.apid = b.concept_code
left join brand_replace r on
	b.brand_code = r.concept_code
;
drop table if exists tomap_bn
;
--Mapping BNs
create table tomap_bn as
with preex_m as
	(
		select distinct --Manual relations
			c.concept_code as concept_code,
			b.brand_name as concept_name,
			cc.concept_id as mapped_id,
			cc.concept_name as mapped_name
		from tofind_brands_man b
		join drug_concept_stage c on
			b.brand_name = c.concept_name and
			c.concept_class_id = 'Brand Name'
		join concept cc on
			b.brand_id = cc.concept_id

			union

		select distinct --previously obtained name match
			c.concept_code,
			b.brand_name,
			b.brand_id,
			b.brand_name	
		from b_temp b
		join drug_concept_stage c on
			b.brand_name = c.concept_name and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null

			union

		select distinct --Previous manual map (optional)
			s.concept_code,
			s.concept_name,
			coalesce (c2.concept_id, c.concept_id),
			coalesce (c2.concept_name, c.concept_name)
		from brands_by_lena l
		join drug_concept_stage s on
			s.concept_name  = l.brand_name and
			s.concept_class_id = 'Brand Name'
		join concept c on
			l.concept_id = c.concept_id and
			(
				c.invalid_reason = 'U' or
				c.invalid_reason is null
			)
		left join concept_relationship r on
			c.concept_id = r.concept_id_1 and
			r.relationship_id = 'Concept replaced by' and
			r.invalid_reason is null
		left join concept c2 on
			c2.concept_id = r.concept_id_2
		
/*			
			union
	
		select --complete name match
			s.concept_code,
			s.concept_name,
			c.concept_id,
			c.concept_name
		from drug_concept_stage s
		join concept c on
			s.concept_class_id = 'Brand Name' and
			regexp_replace (lower (s.concept_name),'\W','') = regexp_replace (lower (c.concept_name),'\W','') and
			c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason IS NULL*/
	)
select distinct
	s.concept_code,
	s.concept_name,
	m.mapped_id,
	m.mapped_name
from drug_concept_stage s
left join preex_m m using (concept_code, concept_name)
where s.concept_class_id = 'Brand Name'
;
insert into tomap_bn --complete name match
select 
	a.concept_code,
	a.concept_name,
	c.concept_id,
	c.concept_name
from tomap_bn a
join concept c ON 
	regexp_replace (lower (a.concept_name),'\W','') = regexp_replace (lower (c.concept_name),'\W','') and
	c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
	c.concept_class_id = 'Brand Name' and
	c.invalid_reason IS NULL
where a.mapped_id is null
;
delete from tomap_bn t
where 
	mapped_id is null and
	exists (select from tomap_bn x where x.mapped_id is not null and t.concept_code = x.concept_code)
;
delete from tomap_bn
--keep more correct name
where 
	concept_code in
		(
			select concept_code from tomap_bn
			group by concept_code
			having count(mapped_id) > 1
		) and
	concept_name != mapped_name
;
delete from tomap_bn t
--keep RxN concept instead if RxE
where 
	(select vocabulary_id from concept where concept_id = t.mapped_id) = 'RxNorm Extension' and
	exists
		(
			select
			from concept c
			join tomap_bn x on
				x.mapped_id = c.concept_id and
				x.concept_code = t.concept_code and
				c.vocabulary_id = 'RxNorm'
		)
;
delete from tomap_bn
--manually extracted brands will have no mappings
where 
	concept_name in (select brand_name from tofind_brands_man) and
	mapped_id is null and
	concept_code like 'OMOP%'
;
update tomap_bn t1 --small pattern fix
--Name1 = Name2 + ' XL'
set
	(mapped_id, mapped_name) = 
	(
		select t2.mapped_id, t2.mapped_name
		from tomap_bn t2
		where
			t1.concept_name = t2.concept_name || ' XL' and
			t2.mapped_id is not null
	)
where t1.mapped_id is null
;
update tomap_bn t1 --small pattern fix
--Name1 = Name2 + ' XL'
set
	(mapped_id, mapped_name) = 
	(
		select c.concept_id, c.concept_name
		from concept c
		where
			t1.concept_name = c.concept_name || ' XL' and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null and
			c.vocabulary_id in ('RxNorm')
	)
where
	t1.mapped_id is null and
	t1.concept_name like '% XL'
;/*
drop table if exists tomap_bn_man
;
-- create table tomap_bn_man as
select 
	t.concept_code,
	t.concept_name,
	c.concept_id as mapped_id,
	c.concept_name as mapped_name,
	c.vocabulary_id
from tomap_bn t
left join concept c on
	lower (t.concept_name) like lower (c.concept_name) || ' %' and -- this match will have to be checked manually
	c.concept_class_id = 'Brand Name' and
	c.invalid_reason is null and
	c.vocabulary_id like 'RxN%'
where
	t.mapped_id is null and
	t.concept_code not in (select concept_code from tomap_bn_man)
;
WbImport -file=/home/ekorchmar/Documents/dmd/tomap_bn_man.csv
         -type=text
         -table=tomap_bn_man
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=concept_code,concept_name,mapped_id,mapped_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;*/
;
--update source names
update tomap_bn_man b
set
	concept_name = (select concept_name from drug_concept_stage where concept_code = b.concept_code)
;
--update obvious misses (simplifies refresh)
update tomap_bn_man b
set
	(mapped_id, mapped_name) =
	(
		select distinct concept_id, concept_name
		from concept
		where
			vocabulary_id in ('RxNorm') and
			lower (concept_name) = lower (b.concept_name) and
			concept_class_id = 'Brand Name' and
			invalid_reason is null
	)
where mapped_id is null
;
update tomap_bn_man b
set
	(mapped_id, mapped_name) =
	(
		select distinct concept_id, concept_name
		from concept
		where
			vocabulary_id in ('RxNorm Extension') and
			concept_name = b.concept_name and
			concept_class_id = 'Brand Name' and
			invalid_reason is null
	)
where mapped_id is null
;
delete from tomap_bn where concept_code in (select concept_code from tomap_bn_man where mapped_id is not null)
;
insert into tomap_bn
select concept_code,concept_name,mapped_id,mapped_name
from tomap_bn_man
where mapped_id is not null
;
insert into relationship_to_concept
select distinct
	c.concept_code,
	'dm+d',
	mapped_id,
	1,
	null :: float
from tomap_bn t
join drug_concept_stage c on
	c.concept_name = t.concept_name and
	c.concept_class_id = 'Brand Name'
where t.mapped_id is not null
;/*
drop table if exists tomap_supplier_man
;
-- create table tomap_supplier_man as
select d.concept_code, d.concept_name, c.concept_id as mapped_id, c.concept_name as mapped_name
from drug_concept_stage d 
left join concept c on
	c.concept_class_id = 'Supplier' and
	c.vocabulary_id = 'RxNorm Extension' and
	c.invalid_reason is null and
	regexp_replace (lower (c.concept_name),'\W','') = regexp_replace (lower (d.concept_name),'\W','')
where
	d.concept_class_id = 'Supplier' and
	d.concept_code in (select concept_code_2 from internal_relationship_stage)
	and d.concept_code not in (select concept_code from tomap_supplier_man)
order by length (d.concept_name)
;
WbImport -file=/home/ekorchmar/Documents/dmd/tomap_supplier_man.csv
         -type=text
         -table=tomap_supplier_man
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=concept_code,concept_name,mapped_id,mapped_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
*/
;
update drug_concept_stage --replace cut name with source-given one
set concept_name = (select name_old from supplier where cd = concept_code)
where concept_class_id = 'Supplier'
;
--update obvious misses (simplifies refresh)
update tomap_supplier_man s
set concept_name = (select d.concept_name from drug_concept_stage d where d.concept_code = s.concept_code and d.concept_class_id = 'Supplier')
where s.concept_code in (select concept_code from drug_concept_stage)
;
update tomap_supplier_man b
set
	(mapped_id, mapped_name) =
	(
		select distinct concept_id, concept_name
		from concept
		where
			vocabulary_id in ('RxNorm') and
			lower (concept_name) = lower (b.concept_name) and
			concept_class_id = 'Supplier' and
			invalid_reason is null
	)
where mapped_id is null
;
update tomap_supplier_man b
set
	(mapped_id, mapped_name) =
	(
		select distinct concept_id, concept_name
		from concept
		where
			vocabulary_id in ('RxNorm Extension') and
			concept_name = b.concept_name and
			concept_class_id = 'Supplier' and
			invalid_reason is null
	)
where mapped_id is null
;
insert into relationship_to_concept
select
	concept_code,
	'dm+d',
	mapped_id,
	1 as precedence,
	null :: int4 as conversion_factor
from tomap_supplier_man
where mapped_id is not null
;
--dublicates within RxE do this
delete from relationship_to_concept r
where exists
	(
		select
		from concept c
		join relationship_to_concept x on
			c.concept_class_id = 'Brand Name' and
			x.concept_id_2 = c.concept_id and
			x.concept_code_1 = r.concept_code_1 and
			x.concept_id_2 < r.concept_id_2
	)
;
analyze relationship_to_concept
;
analyze internal_relationship_stage
;
--some drugs in IRS have duplicating ingredient entries over relationship_to_concept mappings
with multiing as
	(
		select i.concept_code_1, r.concept_id_2, min (i.concept_code_2) as preserve_this
		from internal_relationship_stage i
		join relationship_to_concept r on
			coalesce (r.precedence,1) = 1 and --only precedential mappings matter
			i.concept_code_2 = r.concept_code_1
		group by i.concept_code_1, concept_id_2
		having count (i.concept_code_2) > 1
	)
delete from internal_relationship_stage r
where
	(r.concept_code_1, r.concept_code_2) in 
		(
			select a.concept_code_1, b.concept_code_1
			from multiing a
			join relationship_to_concept b on
				a.concept_id_2 = b.concept_id_2 and
				a.preserve_this != b.concept_code_1
		)
;
-- 6. Some manual fixes for some drugs inc. vaccines
/*
drop table if exists tomap_varicella
--manually reassign ingredients to distinguish between varicella and varicella-zoster vaccines
;
-- create table tomap_varicella as
select 
	d.source_concept_class_id,
	d.concept_code,
	d.concept_name,
	s.concept_code as ingredient_code,
	s.concept_name as ingredient_name,
	c.concept_id as target_id,
	c.concept_name as target_name
from drug_concept_stage d
join internal_relationship_stage i on
	d.concept_code = i.concept_code_1 and
	concept_code_2 in ('20114111000001107','11170811000001106')
join drug_concept_stage s on
	i.concept_code_2 = s.concept_code
left join relationship_to_concept r on
	i.concept_code_2 = r.concept_code_1 and
	r.precedence = 1
join concept c on
	c.concept_id = r.concept_id_2
where	
	d.concept_code not in (select concept_code from tomap_varicella)
;
WbImport -file=/home/ekorchmar/Documents/dmd/tomap_varicella.csv
         -type=text
         -table=tomap_varicella
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=source_concept_class_id,concept_code,concept_name,ingredient_code,ingredient_name,target_id,target_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=10;
*/
;
delete from internal_relationship_stage
where concept_code_1 in (select concept_code from tomap_varicella where ingredient_code is null)
;
insert into relationship_to_concept
select 
	concept_code,
	'dm+d',
	target_id,
	1,
	null
from tomap_varicella
where ingredient_code is null
;
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
;
insert into relationship_to_concept --nasal 
select
	concept_code_1, 
	'dm+d',
	40213149,
	1,
	null
from internal_relationship_stage
where concept_code_2 = '19699211000001101'
;/*
insert into relationship_to_concept --H1N1
select
	concept_code_1, 
	'dm+d',
	40213186,
	1,
	null
from internal_relationship_stage
where concept_code_2 = '16091511000001102'
;*/
insert into relationship_to_concept --Rest
select
	concept_code_1, 
	'dm+d',
	40213153,
	1,
	null
from internal_relationship_stage
where concept_code_2 in ('11172111000001100','11171911000001108','11172011000001101')
;
delete from internal_relationship_stage
where concept_code_1 in (select concept_code_1 from internal_relationship_stage where concept_code_2 in ('11172111000001100','11171911000001108','11172011000001101',/*'16091511000001102',*/'19699211000001101'))
;
delete from ds_stage
where drug_concept_code in (select drug_concept_code from ds_stage where ingredient_concept_code in ('11172111000001100','11171911000001108','11172011000001101',/*'16091511000001102',*/'19699211000001101'))
;
--Map 23-valent pneumoc. vaccines to 40213201 pneumococcal polysaccharide vaccine, 23 valent CVX
delete from internal_relationship_stage
where concept_code_1 in
	(
		select vpid from vmps where vpid in ('3439211000001108','3439311000001100') --VMP for 23valent vaccines
			union all
		select apid from amps where vpid in ('3439211000001108','3439311000001100') --AMP
			union all
		select vppid from vmpps where vpid in ('3439211000001108','3439311000001100') --VMPP
			union all
		select appid from vmpps join ampps using (vppid) where vpid in ('3439211000001108','3439311000001100') --AMP	
	)
;
insert into relationship_to_concept
select distinct
	pneum.vpid,
	'dm+d',
	40213201,
	1,
	null :: int4
from
	(
		select vpid from vmps where vpid in ('3439211000001108','3439311000001100') --VMP for 23valent vaccines
			union all
		select apid from amps where vpid in ('3439211000001108','3439311000001100') --AMP
			union all
		select vppid from vmpps where vpid in ('3439211000001108','3439311000001100') --VMPP
			union all
		select appid from vmpps join ampps using (vppid) where vpid in ('3439211000001108','3439311000001100') --AMP	
	) pneum
;
-- 7. Final fixes and shifting OMOP codes to follow sequence in CONCEPT table

delete from internal_relationship_stage
where concept_code_1 in (select concept_code from drug_concept_stage where domain_id = 'Device')
;
delete from drug_concept_stage
where 
	concept_class_id in ('Ingredient','Dose Form','Supplier','Brand Name') and
	concept_code not in (select concept_code_2 from internal_relationship_stage)
;
--OMOP replacement: existing OMOP codes and shift sequence to after last code in devv5.concept
drop table if exists code_replace
;
create table code_replace as
select
	d.concept_code as old_code,
	c.concept_code as new_code
from drug_concept_stage d 
left join concept c on
	c.vocabulary_id = d.vocabulary_id and
	--c.invalid_reason is null and
	c.concept_name = d.concept_name and
	c.concept_class_id = d.concept_class_id
where d.concept_code like 'OMOP%'
;
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM devv5.concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %';
	DROP SEQUENCE IF EXISTS new_vocab;
	EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END $$
;
update code_replace
set	new_code = 'OMOP' || nextval('new_vocab')
where new_code is null
;
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
WHERE a.drug_concept_code = b.old_code
;
--FINAL FIXES
;
--Inherit AMP, VMPP and AMPP ingredient relations for empty ds_stage entries
insert into internal_relationship_stage
select distinct
	a.apid,
	x.concept_code
from internal_relationship_stage d
join amps a on
	a.vpid = d.concept_code_1
join drug_concept_stage x on
	x.concept_class_id in ('Ingredient') and
	x.concept_code = d.concept_code_2
left join ds_stage s on
	a.apid = s.drug_concept_code
where s.drug_concept_code is null
;
insert into internal_relationship_stage
select distinct
	a.vppid,
	x.concept_code
from internal_relationship_stage d
join vmpps a on
	a.vpid = d.concept_code_1
join drug_concept_stage x on
	x.concept_class_id in ('Ingredient') and
	x.concept_code = d.concept_code_2
left join ds_stage s on
	a.vppid = s.drug_concept_code
where s.drug_concept_code is null
;
insert into internal_relationship_stage
select distinct
	a.appid,
	x.concept_code
from internal_relationship_stage d
join ampps a on
	a.apid = d.concept_code_1
join drug_concept_stage x on
	x.concept_class_id in ('Ingredient') and
	x.concept_code = d.concept_code_2
left join ds_stage s on
	a.appid = s.drug_concept_code
where s.drug_concept_code is null
;
--Inherit AMP, VMPP and AMPP Dose Form relations for empty ds_stage entries
insert into internal_relationship_stage --amp
select distinct
	a.apid,
	x.concept_code
from internal_relationship_stage d
join amps a on
	a.vpid = d.concept_code_1
join drug_concept_stage x on
	x.concept_class_id = 'Dose Form' and
	x.concept_code = d.concept_code_2
;
insert into internal_relationship_stage --vmpp
select distinct
	a.vppid,
	x.concept_code
from internal_relationship_stage d
left join only_1_pack o on
	d.concept_code_1 = o.drug_concept_code
join vmpps a on
	a.vpid = coalesce (o.pack_concept_code,d.concept_code_1)
join drug_concept_stage x on
	x.concept_class_id = 'Dose Form' and
	x.concept_code = d.concept_code_2
where
	not exists
		(
			select
			from internal_relationship_stage i
			join drug_concept_stage c on
				i.concept_code_2 = c.concept_code
			where
				c.concept_class_id = 'Dose Form'
		)
;
insert into internal_relationship_stage
select distinct
	a.appid,
	x.concept_code
from internal_relationship_stage d
left join only_1_pack o on
	d.concept_code_1 = o.drug_concept_code
join ampps a on
	a.apid = coalesce (o.pack_concept_code,d.concept_code_1)
join drug_concept_stage x on
	x.concept_class_id = 'Dose Form' and
	x.concept_code = d.concept_code_2
where
	not exists
		(
			select
			from internal_relationship_stage i
			join drug_concept_stage c on
				i.concept_code_2 = c.concept_code
			where
				c.concept_class_id = 'Dose Form'
		)
;
--ensure correctness of monopacks
delete from internal_relationship_stage where concept_code_1 in (select pack_concept_code from only_1_pack)
;
insert into internal_relationship_stage
select
	pack_concept_code,
	concept_code_2
from internal_relationship_stage
join only_1_pack on
	drug_concept_code = concept_code_1
;
drop table if exists irs_shuffle
;
create table irs_shuffle as
select distinct
	concept_code_1,
	concept_code_2
from internal_relationship_stage
;
drop table internal_relationship_stage
;
alter table irs_shuffle
rename to internal_relationship_stage
;
--optional: remove unused concepts
delete from drug_concept_stage
where 
	concept_class_id in ('Unit') and
	concept_name not in 
		(
			select distinct amount_unit from ds_stage where amount_unit is not null
				union all
			select distinct numerator_unit from ds_stage where numerator_unit is not null
				union all
			select distinct denominator_unit from ds_stage where denominator_unit is not null
		)
;
/*update relationship_to_concept set precedence = 2 where concept_code_1 in ('3519511000001105','8147711000001108')
;
insert into relationship_to_concept values ('3519511000001105','dm+d',915553,1,null)
;
insert into relationship_to_concept values ('8147711000001108','dm+d',1353048,1,null)*/
;
--menotropin split
insert into drug_concept_stage
--It is NOT a code from source data, it's from SNOMED
values (null,'Recombinant human luteinizing hormone','Drug','dm+d','Ingredient','S','415248001',to_date ('1970-01-01','YYYY-MM-DD'),to_date ('2099-12-31','YYYY-MM-DD'),null,'Ingredient')
;
insert into relationship_to_concept values ('415248001','dm+d',1589795,1,null)
;
insert into internal_relationship_stage 
select 
	concept_code_1,
	'415248001'
from internal_relationship_stage 
where concept_code_2 = '8203003'
	union all
select 
	concept_code_1,
	'4174011000001101'
from internal_relationship_stage 
where concept_code_2 = '8203003'
;
delete from ds_stage where ingredient_concept_code = '8203003' --no universally agreed proportion, so can't preserve dosage
;
delete from internal_relationship_stage where concept_code_2 = '8203003'
;
--delete from ds_stage where drug_concept_code in ('8981911000001106','8977811000001101','8977711000001109','8977911000001106')
;
/*update internal_relationship_stage
set
	concept_code_2 = '385219001'
where
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
;
update ds_stage 
set box_size = null 
where
	denominator_unit is not null and
	--(box_size = 1 or denominator_value is null)
	denominator_value is null
;
--because of updates
delete from relationship_to_concept where concept_code_1 not in (select concept_code from drug_concept_stage)
;
--get supplier relations for packs
insert into internal_relationship_stage
select distinct
	a.appid,
	i.concept_code_2
from ampps a
join internal_relationship_stage i on
	a.apid = i.concept_code_1
join pc_stage p on
	p.pack_concept_code = a.appid
join drug_concept_stage d on
	d.concept_code = i.concept_code_2 and
	d.concept_class_id = 'Supplier'
join drug_concept_stage d1 on
	d1.concept_code = a.appid and
	d1.domain_id = 'Drug' and
	d1.source_concept_class_id = 'AMPP'
;
--marketed products must have either pc_stage or ds_stage entry
delete from internal_relationship_stage
where
	concept_code_2 in (select concept_code from drug_concept_stage where concept_class_id = 'Supplier') and
	concept_code_1 not in 
		(
			select drug_concept_code 
			from ds_stage
			
				union all
			
			select pack_concept_code
			from pc_stage
		)
;
--Replaces 'Powder' dose form with more specific forms, guessing from name where possible
drop table if exists vmps_chain;
create table vmps_chain as 
select distinct
	v.vpid, v.vppid, a.apid, a.appid,
	case
		when 
			d1.concept_name ilike '%oral powder%' or
			d1.concept_name ilike '%sugar%'
		then '14945811000001105' --effervescent powder
		when d1.concept_name ilike '%topical%'
		then '385108009' --cutaneous solution
		when d1.concept_name ilike '%endotrach%'
		then '11377411000001104' --Powder and solvent for solution for instillation
		when d1.concept_name ilike '% ear %'
		then '385136004' --ear drops
		else '85581007' --Powder
	end as concept_code_2
from vmpps v
join ampps a using (vppid)
join internal_relationship_stage i on
	v.vpid = i.concept_code_1 and
	i.concept_code_2 = '85581007' --Powder
join drug_concept_stage d1 on 
	d1.concept_code = i.concept_code_1
;
update internal_relationship_stage i
set concept_code_2 = (select distinct concept_code_2 from vmps_chain where i.concept_code_1 in (vpid, apid, appid, vppid))
where concept_code_2 = '85581007' --Powder
;
drop table if exists amps_chain
;
--AMP's have licensed route; some are defining
create table amps_chain as
select distinct
	a.apid,
	a.appid,
	case routecd
		when '26643006' then '14945811000001105' --oral powder
		when '6064005' then '385108009' --cutaneous solution
		else '85581007' --Powder
	end as concept_code_2
from vmps_chain a
join licensed_route l using (apid)
where 
	a.concept_code_2 = '85581007' and
	l.apid in 
		(
			select apid 
			from licensed_route 
			where routecd != '3594011000001102'
			group by apid
			having count (routecd) = 1
		)
;
update internal_relationship_stage i
set concept_code_2 = (select distinct concept_code_2 from amps_chain where i.concept_code_1 in (apid, appid))
where 
	concept_code_2 = '85581007' and --Powder
	exists
		(
			select
			from amps_chain
			where concept_code_1 in (apid,appid)
		)
;
--same with Liquid
drop table if exists vmps_chain;
create table vmps_chain as 
select distinct
	v.vpid, v.vppid, a.apid, a.appid,
	case
		when 
			d1.concept_name ilike '% oral%' or
			d1.concept_name ilike '%sugar%' or
			d1.concept_name ilike '% dental%' or
			d1.concept_name ilike '% tincture%' or
			d1.concept_name ilike '% mixture%' or
			d1.concept_name ilike '%oromucos%' or
			d1.concept_name ilike '% elixir%'
		then '385023001' --oral solution
		when 
			d1.concept_name ilike '% instil%' or
			d1.concept_name ilike '%periton%' or
			d1.concept_name ilike '%cardiop%' or
			d1.concept_name ilike '%tracheopul%' or
			d1.concept_name ilike '%extraamn%' or
			d1.concept_name ilike '%smallpox%'
		then '385219001' --injectable solution
		when 			
			d1.concept_name ilike '% lotion%' or
			d1.concept_name ilike '% acetone%' or
			d1.concept_name ilike '% scalp%' or
			d1.concept_name ilike '% topical%' or
			d1.concept_name ilike '% skin%' or
			d1.concept_name ilike '% massage%' or
			d1.concept_name ilike '% shower%' or
			d1.concept_name ilike '% rubb%' or
			d1.concept_name ilike '%spirit%'
		then '385108009' --cutaneous solution
		when d1.concept_name ilike '% vagin%'
		then '385166006' --vaginal gel
		when 
			d1.concept_name ilike '%nasal%' or
			d1.concept_name ilike '%nebul%'
		then '385197005' --nebuliser liquid
		else '420699003'
	end as concept_code_2
from vmpps v
join ampps a using (vppid)
join internal_relationship_stage i on
	v.vpid = i.concept_code_1 and
	i.concept_code_2 = '420699003' --Liquid
join drug_concept_stage d1 on 
	d1.concept_code = i.concept_code_1
;
update internal_relationship_stage i
set concept_code_2 = (select distinct concept_code_2 from vmps_chain where i.concept_code_1 in (vpid, apid, appid, vppid))
where concept_code_2 = '420699003' --Liquid
;
drop table if exists amps_chain
;
create table amps_chain as
select distinct
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
from vmps_chain a
join licensed_route l using (apid)
where 
	a.concept_code_2 = '420699003' and
	l.apid in 
		(
			select apid 
			from licensed_route 
			where routecd != '3594011000001102'
			group by apid
			having count (routecd) = 1
		)
;
update internal_relationship_stage i
set concept_code_2 = (select distinct concept_code_2 from amps_chain where i.concept_code_1 in (apid, appid))
where 
	concept_code_2 = '420699003' and --Liquid
	exists
		(
			select
			from amps_chain
			where concept_code_1 in (apid,appid)
		)
;

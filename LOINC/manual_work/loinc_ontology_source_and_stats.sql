--------------------------------------------Source tables----------------------------------------------
--23 835
--SNOMED source
CREATE TABLE snomed_identifier_full (
    alternateIdentifier varchar(255), --loinc_code (attributes too?)
    effectiveTime varchar(255),
    active varchar(255),
    moduleId varchar(255),
    identifierSchemeId varchar(255),
    referencedComponentId varchar(255) --snomed_code: this code is used in all other tables
);

SELECT *
FROM snomed_identifier_full;


CREATE TABLE snomed_relationship_full (
    id varchar(255),
    effectiveTime varchar(255),
    active varchar(255),
    moduleId varchar(255),
    sourceId varchar(255), --snomed_code
    destinationId varchar(255), --snomed_attribure code
    referencedComponentId varchar(255), --not need column! not exist in source
    relationshipGroup varchar(255), --relationship type (component/specimen and etc.)
    typeId	varchar(255),
    characteristicTypeId varchar(255),
    modifierId varchar(255)
);

select distinct destinationId
from snomed_relationship_full
where typeId NOT IN ('704326004',
                     '116680003')
and sourceId in (select referencedComponentId from snomed_identifier_full)
and destinationId not in (select snomed_attr_code from snomed_loinc_mapping_from_source);

--19 strange codes, looks like attributes matching
SELECT *
FROM snomed_relationship_full
where sourceId not in (select referencedComponentId from snomed_identifier_full);


--TODO: take manually, 2 codes
SELECT distinct destinationId, typeId
FROM snomed_relationship_full
where destinationId not in (select snomed_attr_code from snomed_loinc_mapping_from_source)
and typeId NOT IN ('704326004', '116680003');

------------------------------------------Mapping of attributes from SNOMED source------------------------
--we don't have 6 SNOMED components
CREATE TABLE snomed_loinc_mapping_from_source AS (with tab as (SELECT c.concept_id as loinc_id, --id of the real concept
                    si.alternateIdentifier, --loinc_code of the real concept
                    c.concept_name, --loinc name of the real concept
                    sr.destinationId as snomed_attr_code,
                    c1.concept_name as snomed_attr_name,
                    CASE
                        WHEN sr.typeId = '370130000'
                            THEN 'Property'
                        WHEN sr.typeId = '246093002'
                            THEN 'Component'
                        WHEN sr.typeId = '246501002'
                            THEN 'Method'
                        WHEN sr.typeId = '370132008'
                            THEN 'Scale'
                        WHEN sr.typeId IN ('370133003', '704319004', '704327008')
                            THEN 'Specimen'
                        WHEN sr.typeId = '370134009'
                            THEN 'Time'
                        --In LOINC Terms it is a part of component. Examples: post dialysis, after exercise
                        --not used in the final table
                        WHEN sr.typeId = '704326004'
                            THEN 'Precondition'
                        END as relationship
             FROM snomed_relationship_full sr
                      join snomed_identifier_full si ON sr.sourceId = si.referencedComponentId
                      left join concept c ON c.concept_code = si.alternateIdentifier and c.vocabulary_id = 'LOINC'
                      left join concept c1 ON c1.concept_code = sr.destinationId and c1.vocabulary_id = 'SNOMED'

             where sr.typeId != '116680003' --Is a
)
select distinct c.concept_code as loinc_code, --loinc attribute code
       c.concept_name as loinc_name, --loinc attribute name
       relationship,
       snomed_attr_code,
       snomed_attr_name
from tab
left join concept_relationship cr ON loinc_id = cr.concept_id_1 and invalid_reason IS NULL and relationship_id = 'Has component'
left join concept c ON c.concept_id = cr.concept_id_2
where relationship = 'Component'

union

select distinct c.concept_code as loinc_code,
       c.concept_name as loinc_name,
       relationship,
       snomed_attr_code,
       snomed_attr_name
from tab
left join concept_relationship cr ON loinc_id = cr.concept_id_1 and invalid_reason IS NULL and relationship_id = 'Has property'
left join concept c ON c.concept_id = cr.concept_id_2
where relationship = 'Property'

union

select distinct c.concept_code as loinc_code,
       c.concept_name as loinc_name,
       relationship,
       snomed_attr_code,
       snomed_attr_name
from tab
left join concept_relationship cr ON loinc_id = cr.concept_id_1 and invalid_reason IS NULL and relationship_id = 'Has method'
left join concept c ON c.concept_id = cr.concept_id_2
where relationship = 'Method'

union

select distinct c.concept_code as loinc_code,
       c.concept_name as loinc_name,
       relationship,
       snomed_attr_code,
       snomed_attr_name
from tab
left join concept_relationship cr ON loinc_id = cr.concept_id_1 and invalid_reason IS NULL and relationship_id = 'Has scale type'
left join concept c ON c.concept_id = cr.concept_id_2
where relationship = 'Scale'

union

select distinct c.concept_code as loinc_code,
       c.concept_name as loinc_name,
       relationship,
       snomed_attr_code,
       snomed_attr_name
from tab
left join concept_relationship cr ON loinc_id = cr.concept_id_1 and invalid_reason IS NULL and relationship_id = 'Has system'
left join concept c ON c.concept_id = cr.concept_id_2
where relationship = 'Specimen'

union

select distinct c.concept_code as loinc_code,
       c.concept_name as loinc_name,
       relationship,
       snomed_attr_code,
       snomed_attr_name
from tab
left join concept_relationship cr ON loinc_id = cr.concept_id_1 and invalid_reason IS NULL and relationship_id = 'Has time aspect'
left join concept c ON c.concept_id = cr.concept_id_2
where relationship = 'Time')
;

--to many mappings, excluding precoodition
select *
from snomed_loinc_mapping_from_source
where loinc_code IN (select loinc_code from snomed_loinc_mapping_from_source group by loinc_code having count(*) > 1);

--different loincs with the same target
select *
from snomed_loinc_mapping_from_source
where snomed_attr_code IN (select snomed_attr_code from snomed_loinc_mapping_from_source group by snomed_attr_code having count(*) > 1);

-----------------------------------------Table with all SNOMED attributes-----------------------------------------------------
CREATE TABLE snomed_attr AS (
    WITH tmp_rel AS (
		-- get relationships from latest records that are active
		SELECT sourceid::TEXT,
			destinationid::TEXT,
			REPLACE(term, ' (attribute)', '') AS term
		FROM (
			SELECT r.sourceid,
				r.destinationid,
				d.term,
				ROW_NUMBER() OVER (
					PARTITION BY r.id ORDER BY r.effectivetime DESC,
						d.id DESC -- fix for AVOF-650
					) AS rn, -- get the latest in a sequence of relationships, to decide whether it is still active
				r.active
			FROM sources.sct2_rela_full_merged r
			JOIN sources.sct2_desc_full_merged d ON d.conceptid = r.typeid
			) AS s0
		WHERE rn = 1
			AND active = 1
			AND sourceid IS NOT NULL
			AND destinationid IS NOT NULL
			AND term <> 'PBCL flag true'

		UNION ALL

		--add relationships from concept to module
		SELECT cs.concept_code::TEXT,
			moduleid::TEXT,
			'Has Module' AS term
		FROM sources.sct2_concept_full_merged c
		JOIN concept_stage cs ON cs.concept_code = c.id::TEXT
			AND cs.vocabulary_id = 'SNOMED'
		WHERE c.moduleid IN (
				900000000000207008, --Core (international) module
				999000011000000103, --UK edition
				731000124108, --US edition
				999000011000001104, --SNOMED CT United Kingdom drug extension module
				900000000000012004, --SNOMED CT model component
				999000021000001108 --SNOMED CT United Kingdom drug extension reference set module
				)

		UNION ALL

		--add relationship from concept to status
		SELECT st.concept_code::TEXT,
			st.statusid::TEXT,
			'Has status'
		FROM (
			SELECT cs.concept_code,
				statusid::TEXT,
				ROW_NUMBER() OVER (
					PARTITION BY id ORDER BY TO_DATE(effectivetime, 'YYYYMMDD') DESC
					) rn
			FROM sources.sct2_concept_full_merged c
			JOIN concept_stage cs ON cs.concept_code = c.id::TEXT
				AND cs.vocabulary_id = 'SNOMED'
			WHERE c.statusid IN (
					900000000000073002, --Defined
					900000000000074008 --Primitive
					)
			) st
		WHERE st.rn = 1
		)
SELECT distinct /*concept_code_1,*/
	concept_code_2,
	/*vocabulary_id_1,*/
	/*vocabulary_id_2,*/
	relationship_id/*,*/
	/*valid_start_date,*/
	/*valid_end_date,
	invalid_reason*/
FROM (
	--convert SNOMED to OMOP-type relationship_id
	--TODO: this deserves a massive overhaul using raw typeid instead of extracted terms; however, it works in current state with no reported issues
	SELECT DISTINCT sourceid AS concept_code_1,
		destinationid AS concept_code_2,
		'SNOMED' AS vocabulary_id_1,
		'SNOMED' AS vocabulary_id_2,
		CASE
			WHEN term = 'Access'
				THEN 'Has access'
			WHEN term = 'Associated aetiologic finding'
				THEN 'Has etiology'
			WHEN term = 'After'
				THEN 'Followed by'
			WHEN term = 'Approach'
				THEN 'Has surgical appr' -- looks like old version
			WHEN term = 'Associated finding'
				THEN 'Has asso finding'
			WHEN term = 'Associated morphology'
				THEN 'Has asso morph'
			WHEN term = 'Associated procedure'
				THEN 'Has asso proc'
			WHEN term = 'Associated with'
				THEN 'Finding asso with'
			WHEN term = 'AW'
				THEN 'Finding asso with'
			WHEN term = 'Causative agent'
				THEN 'Has causative agent'
			WHEN term = 'Clinical course'
				THEN 'Has clinical course'
			WHEN term = 'Component'
				THEN 'Has component'
			WHEN term = 'Direct device'
				THEN 'Has dir device'
			WHEN term = 'Direct morphology'
				THEN 'Has dir morph'
			WHEN term = 'Direct substance'
				THEN 'Has dir subst'
			WHEN term = 'Due to'
				THEN 'Has due to'
			WHEN term = 'Episodicity'
				THEN 'Has episodicity'
			WHEN term = 'Extent'
				THEN 'Has extent'
			WHEN term = 'Finding context'
				THEN 'Has finding context'
			WHEN term = 'Finding informer'
				THEN 'Using finding inform'
			WHEN term = 'Finding method'
				THEN 'Using finding method'
			WHEN term = 'Finding site'
				THEN 'Has finding site'
			WHEN term = 'Has active ingredient'
				THEN 'Has active ing'
			WHEN term = 'Has definitional manifestation'
				THEN 'Has manifestation'
			WHEN term = 'Has dose form'
				THEN 'Has dose form'
			WHEN term = 'Has focus'
				THEN 'Has focus'
			WHEN term = 'Has interpretation'
				THEN 'Has interpretation'
			WHEN term = 'Has measured component'
				THEN 'Has meas component'
			WHEN term = 'Has specimen'
				THEN 'Has specimen'
			WHEN term = 'Stage'
				THEN 'Has stage'
			WHEN term = 'Indirect device'
				THEN 'Has indir device'
			WHEN term = 'Indirect morphology'
				THEN 'Has indir morph'
			WHEN term = 'Instrumentation'
				THEN 'Using device' -- looks like an old version
			WHEN term IN (
					'Intent',
					'Has intent'
					)
				THEN 'Has intent'
			WHEN term = 'Interprets'
				THEN 'Has interprets'
			WHEN term = 'Is a'
				THEN 'Is a'
			WHEN term = 'Laterality'
				THEN 'Has laterality'
			WHEN term = 'Measurement method'
				THEN 'Has measurement'
			WHEN term = 'Measurement Method'
				THEN 'Has measurement' -- looks like misspelling
			WHEN term = 'Method'
				THEN 'Has method'
			WHEN term = 'Morphology'
				THEN 'Has asso morph' -- changed to the same thing as 'Has Morphology'
			WHEN term = 'Occurrence'
				THEN 'Has occurrence'
			WHEN term = 'Onset'
				THEN 'Has clinical course' -- looks like old version
			WHEN term = 'Part of'
				THEN 'Part of'
			WHEN term = 'Pathological process'
				THEN 'Has pathology'
			WHEN term = 'Pathological process (qualifier value)'
				THEN 'Has pathology'
			WHEN term = 'Priority'
				THEN 'Has priority'
			WHEN term = 'Procedure context'
				THEN 'Has proc context'
			WHEN term = 'Procedure device'
				THEN 'Has proc device'
			WHEN term = 'Procedure morphology'
				THEN 'Has proc morph'
			WHEN term = 'Procedure site - Direct'
				THEN 'Has dir proc site'
			WHEN term = 'Procedure site - Indirect'
				THEN 'Has indir proc site'
			WHEN term = 'Procedure site'
				THEN 'Has proc site'
			WHEN term = 'Property'
				THEN 'Has property'
			WHEN term = 'Recipient category'
				THEN 'Has recipient cat'
			WHEN term = 'Revision status'
				THEN 'Has revision status'
			WHEN term = 'Route of administration'
				THEN 'Has route of admin'
			WHEN term = 'Route of administration - attribute'
				THEN 'Has route of admin'
			WHEN term = 'Scale type'
				THEN 'Has scale type'
			WHEN term = 'Severity'
				THEN 'Has severity'
			WHEN term = 'Specimen procedure'
				THEN 'Has specimen proc'
			WHEN term = 'Specimen source identity'
				THEN 'Has specimen source'
			WHEN term = 'Specimen source morphology'
				THEN 'Has specimen morph'
			WHEN term = 'Specimen source topography'
				THEN 'Has specimen topo'
			WHEN term = 'Specimen substance'
				THEN 'Has specimen subst'
			WHEN term = 'Subject relationship context'
				THEN 'Has relat context'
			WHEN term = 'Surgical approach'
				THEN 'Has surgical appr'
			WHEN term = 'Temporal context'
				THEN 'Has temporal context'
			WHEN term = 'Temporally follows'
				THEN 'Occurs after' -- looks like an old version
			WHEN term = 'Time aspect'
				THEN 'Has time aspect'
			WHEN term = 'Using access device'
				THEN 'Using acc device'
			WHEN term = 'Using device'
				THEN 'Using device'
			WHEN term = 'Using energy'
				THEN 'Using energy'
			WHEN term = 'Using substance'
				THEN 'Using subst'
			WHEN term = 'Following'
				THEN 'Followed by'
			WHEN term = 'VMP non-availability indicator'
				THEN 'Has non-avail ind'
			WHEN term = 'Has ARP'
				THEN 'Has ARP'
			WHEN term = 'Has VRP'
				THEN 'Has VRP'
			WHEN term = 'Has trade family group'
				THEN 'Has trade family grp'
			WHEN term = 'Flavour'
				THEN 'Has flavor'
			WHEN term = 'Discontinued indicator'
				THEN 'Has disc indicator'
			WHEN term = 'VRP prescribing status'
				THEN 'VRP has prescr stat'
			WHEN term = 'Has specific active ingredient'
				THEN 'Has spec active ing'
			WHEN term = 'Has excipient'
				THEN 'Has excipient'
			WHEN term = 'Has basis of strength substance'
				THEN 'Has basis str subst'
			WHEN term = 'Has VMP'
				THEN 'Has VMP'
			WHEN term = 'Has AMP'
				THEN 'Has AMP'
			WHEN term = 'Has dispensed dose form'
				THEN 'Has disp dose form'
			WHEN term = 'VMP prescribing status'
				THEN 'VMP has prescr stat'
			WHEN term = 'Legal category'
				THEN 'Has legal category'
			WHEN term = 'Caused by'
				THEN 'Caused by'
			WHEN term = 'Precondition'
				THEN 'Has precondition'
			WHEN term = 'Inherent location'
				THEN 'Has inherent loc'
			WHEN term = 'Technique'
				THEN 'Has technique'
			WHEN term = 'Relative to part of'
				THEN 'Has relative part'
			WHEN term = 'Process output'
				THEN 'Has process output'
			WHEN term = 'Property type'
				THEN 'Has property type'
			WHEN term = 'Inheres in'
				THEN 'Inheres in'
			WHEN term = 'Direct site'
				THEN 'Has direct site'
			WHEN term = 'Characterizes'
				THEN 'Characterizes'
					--added 20171116
			WHEN term = 'During'
				THEN 'During'
			WHEN term = 'Has BoSS'
				THEN 'Has basis str subst' -- use existing relationship
			WHEN term = 'Has manufactured dose form'
				THEN 'Has dose form' -- use existing relationship
			WHEN term = 'Has presentation strength denominator unit'
				THEN 'Has denominator unit'
			WHEN term = 'Has presentation strength denominator value'
				THEN 'Has denomin value'
			WHEN term = 'Has presentation strength numerator unit'
				THEN 'Has numerator unit'
			WHEN term = 'Has presentation strength numerator value'
				THEN 'Has numerator value'
					--added 20180205
			WHEN term = 'Has basic dose form'
				THEN 'Has basic dose form'
			WHEN term = 'Has disposition'
				THEN 'Has disposition'
			WHEN term = 'Has dose form administration method'
				THEN 'Has admin method'
			WHEN term = 'Has dose form intended site'
				THEN 'Has intended site'
			WHEN term = 'Has dose form release characteristic'
				THEN 'Has release charact'
			WHEN term = 'Has dose form transformation'
				THEN 'Has transformation'
			WHEN term = 'Has state of matter'
				THEN 'Has state of matter'
			WHEN term = 'Temporally related to'
				THEN 'Temp related to'
					--added 20180622
			WHEN term = 'Has NHS dm+d basis of strength substance'
				THEN 'Has basis str subst'
			WHEN term = 'Has unit of administration'
				THEN 'Has unit of admin'
			WHEN term = 'Has precise active ingredient'
				THEN 'Has prec ingredient'
			WHEN term = 'Has unit of presentation'
				THEN 'Has unit of presen'
			WHEN term = 'Has concentration strength numerator value'
				THEN 'Has conc num val'
			WHEN term = 'Has concentration strength denominator value'
				THEN 'Has conc denom val'
			WHEN term = 'Has concentration strength denominator unit'
				THEN 'Has conc denom unit'
			WHEN term = 'Has concentration strength numerator unit'
				THEN 'Has conc num unit'
			WHEN term = 'Is modification of'
				THEN 'Modification of'
			WHEN term = 'Count of base of active ingredient'
				THEN 'Has count of ing'
					--20190204
			WHEN term = 'Has realization'
				THEN 'Has pathology'
			WHEN term = 'Plays role'
				THEN 'Plays role'
					--20190823
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) VMP (Virtual Medicinal Product) route of administration'
				THEN 'Has route'
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) controlled drug category'
				THEN 'Has CD category'
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) VMP (Virtual Medicinal Product) ontology form and route'
				THEN 'Has ontological form'
			WHEN term = 'VMP combination product indicator'
				THEN 'Has combi prod ind'
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) dose form indicator'
				THEN 'Has form continuity'
					--20200312
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) additional monitoring indicator'
				THEN 'Has add monitor ind'
			WHEN term = 'Has NHS dm+d (dictionary of medicines and devices) AMP (actual medicinal product) availability restriction indicator'
				THEN 'Has AMP restr ind'
			WHEN term = 'Has NHS dm+d parallel import indicator'
				THEN 'Paral imprt ind'
			WHEN term = 'Has NHS dm+d freeness indicator'
				THEN 'Has free indicator'
			WHEN term = 'Units'
				THEN 'Has unit'
			WHEN term = 'Process duration'
				THEN 'Has proc duration'
					--20201023
			WHEN term = 'Relative to'
				THEN 'Relative to'
			WHEN term = 'Count of active ingredient'
				THEN 'Has count of act ing'
			WHEN term = 'Has product characteristic'
				THEN 'Has prod character'
			WHEN term = 'Has ingredient characteristic'
				THEN 'Has prod character'
			WHEN term = 'Has surface characteristic'
				THEN 'Surf character of'
			WHEN term = 'Has device intended site'
				THEN 'Has dev intend site'
			WHEN term = 'Has device characteristic'
				THEN 'Has prod character'
			WHEN term = 'Has compositional material'
				THEN 'Has comp material'
			WHEN term = 'Has filling'
				THEN 'Has filling'
					--January 2022
			WHEN term = 'Has coating material'
				THEN 'Has coating material'
			WHEN term = 'Has absorbability'
				THEN 'Has absorbability'
			WHEN term = 'Process extends to'
				THEN 'Process extends to'
			WHEN term = 'Has ingredient qualitative strength'
				THEN 'Has strength'
			WHEN term = 'Has surface texture'
				THEN 'Has surface texture'
			WHEN term = 'Is sterile'
				THEN 'Is sterile'
			WHEN term = 'Has target population'
				THEN 'Has targ population'
			WHEN term = 'Has Module'
				THEN 'Has Module'
			WHEN term = 'Has status'
				THEN 'Has status'
			ELSE term --'non-existing'
			END AS relationship_id,
		/*(
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'SNOMED'
			) AS valid_start_date,*/
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM tmp_rel
	) sn
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = sn.concept_code_1
			AND crs.concept_code_2 = sn.concept_code_2
			AND crs.relationship_id = sn.relationship_id
		)
and relationship_id != 'Is a');

ALTER TABLE snomed_attr
ADD name text;

update snomed_attr
set name = concept_name
from devv5.concept
where concept_code_2 = concept_code and vocabulary_id = 'SNOMED';

select distinct concept_code_2 as code, name, relationship_id, partname
from snomed_attr
join sources.loinc_partlink_primary on name = partname
where relationship_id = 'Has component';

select *
from snomed_attr
where concept_code_2 not in (select destinationId from snomed_relationship_full)
and concept_code_2 not in (select snomed_attr_code from snomed_loinc_mapping_from_ody where snomed_attr_code is not null);

-----------------------------Attributes matching based on name similarity-------------------------------------------------
--drop table names_sim_component;
create table names_sim_component AS (
SELECT distinct cs2.concept_code AS concept_code_1,
       cs2.concept_name AS concept_name_1,
	c4.concept_code AS concept_code_2,
                c4.concept_name AS concept_name_2,
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
-- get LOINC Components for all LOINC Measurements
FROM concept_relationship_stage crs
JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
	AND cs1.vocabulary_id = crs.vocabulary_id_1 -- LOINC Measurement
	AND cs1.vocabulary_id = 'LOINC'
	AND cs1.standard_concept = 'S'
	AND cs1.invalid_reason IS NULL
	AND cs1.concept_name !~* 'susceptibility|protein\.monoclonal' -- susceptibility may have property other than 'Susc'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.relationship_id = 'Is a'
			AND crs_int.vocabulary_id_2 = 'SNOMED'
			AND crs_int.concept_code_1 = cs1.concept_code
		) -- exclude duplicates
JOIN concept_stage cs2 ON cs2.concept_code = crs.concept_code_2
	AND cs2.vocabulary_id = crs.vocabulary_id_2 -- LOINC Component
-- get SNOMED Measurements using name similarity (LOINC Component||' measurement' = SNOMED Measurement)
JOIN concept c ON LOWER(c.concept_name) = COALESCE(LOWER(SPLIT_PART(cs2.concept_name, '^', 1)) || ' measurement', LOWER(SPLIT_PART(cs2.concept_name, '.', 1)) || ' measurement', LOWER(cs2.concept_name) || ' measurement') -- SNOMED Measurement
	AND c.vocabulary_id = 'SNOMED'
	AND c.domain_id = 'Measurement'
	AND c.standard_concept = 'S'
	AND c.concept_code NOT IN (
		'16298007',
		'24683000'
		) -- 'Rate measurement', 'Uptake measurement'
JOIN vocabulary v ON v.vocabulary_id = 'LOINC' -- get valid_start_date
	-- weed out LOINC Measurements with inapplicable properties in the SNOMED architecture context
JOIN sources.loinc j ON j.loinc_num = cs1.concept_code
	AND j.property !~ 'Rto|Ratio|^\w.Fr|Imp|Prid|Zscore|Susc|^-$' -- ratio/interpretation/identifier/z-score/susceptibility-related concepts
JOIN devv5.concept c3 ON c3.concept_code = c.concept_code and c3.vocabulary_id = 'SNOMED'
JOIN devv5.concept_relationship cr ON cr.concept_id_1 = c3.concept_id and cr.relationship_id = 'Has component' and cr.invalid_reason is null
JOIN devv5.concept c4 ON cr.concept_id_2 = c4.concept_id
WHERE crs.relationship_id = 'Has component'
	AND crs.vocabulary_id_1 = 'LOINC'
	AND crs.vocabulary_id_2 = 'LOINC'
	AND crs.invalid_reason IS NULL
);


-------------------------------Our attributes matching results----------------------------------------------
drop table snomed_loinc_mapping_from_ody;
CREATE TABLE snomed_loinc_mapping_from_ody AS (
    select distinct p.partnumber as loinc_code,
                p.partname as loinc_name,
                p.parttypename as relationship,
                coalesce(m.referencedcomponentid, s.attr_code, s1.attr_code, s2.attr_code, ns.concept_code_2, sa.concept_code_2) as snomed_attr_code,
                coalesce(c.concept_name, s.attr_name, s1.attr_name, s2.attr_name, ns.concept_name_2, sa.name) as snomed_attr_name
from sources.loinc_partlink_primary p  --table with primary attributes
left join sources.scccrefset_mapcorrorfull_int m --table with attributes matching
    ON p.partnumber = m.maptarget and m.attributeid IN (
		'246093002',
		'704319004',
		'704327008',
		'718497002'
		)
left join devv5.concept c --name taking for snomed
    ON m.referencedcomponentid = c.concept_code and c.vocabulary_id = 'SNOMED'
left join lc_attr l --join to the table with loinc attributes from load_stage
    ON p.loincnumber = l.lc_code and p.parttypename = 'COMPONENT' and l.relationship_id = 'Has component'
left join sn_attr s --join to the table with snomed attributes from load_stage
    on l.attr_code = s.attr_code and l.relationship_id = 'Has component'

left join lc_attr l1 ON p.loincnumber = l1.lc_code and p.parttypename = 'SCALE' and l1.relationship_id = 'Has scale type'
left join sn_attr s1 on l1.attr_code = s1.attr_code and l1.relationship_id = 'Has scale type'

left join lc_attr l2 ON p.loincnumber = l2.lc_code and p.parttypename = 'SYSTEM' and l2.relationship_id = 'Has dir proc site'
left join sn_attr s2 on l2.attr_code = s2.attr_code and l2.relationship_id = 'Has dir proc site'

left join names_sim_component ns --take matching based on name similarity (loinc attr name = snomed concept name)
    ON ns.concept_code_1 = p.partnumber

left join snomed_attr sa --NEW. Similar names_sim_component but by attributes names (loinc attr name = snomed attr name)
    on sa.name = p.partname and sa.relationship_id = 'Has component'

union

    --the same exercise for loinc_partlink_supplementary table
select distinct p.partnumber,
                p.partname,
                p.parttypename,
                coalesce(m.referencedcomponentid, s.attr_code, s1.attr_code, s2.attr_code, ns.concept_code_2, sa.concept_code_2),
                coalesce(c.concept_name, s.attr_name, s1.attr_name, s2.attr_name, ns.concept_name_2, sa.name)/*,
                case when coalesce(c.concept_name, s.attr_name, s1.attr_name, s2.attr_name, ns.concept_name_2, sa.name) = sa.name
                then 'snomed_attr'
                 when coalesce(c.concept_name, s.attr_name, s1.attr_name, s2.attr_name, ns.concept_name_2, sa.name) = ns.concept_name_2
                then 'names_sim_component'
                 when coalesce(c.concept_name, s.attr_name, s1.attr_name, s2.attr_name, ns.concept_name_2, sa.name) = s2.attr_name
                then 'sn_attr_system'
                when coalesce(c.concept_name, s.attr_name, s1.attr_name, s2.attr_name, ns.concept_name_2, sa.name) = s1.attr_name
                then 'sn_attr_scale'
                 when coalesce(c.concept_name, s.attr_name, s1.attr_name, s2.attr_name, ns.concept_name_2, sa.name) = s.attr_name
                then 'sn_attr_component'
               else 'concept'
                    end as flag*/
from sources.loinc_partlink_supplementary p
left join sources.scccrefset_mapcorrorfull_int m ON p.partnumber = m.maptarget and m.attributeid IN (
		'246093002',
		'704319004',
		'704327008',
		'718497002'
		)
left join devv5.concept c ON m.referencedcomponentid = c.concept_code and c.vocabulary_id = 'SNOMED'
left join lc_attr l ON p.loincnumber = l.lc_code and p.parttypename = 'COMPONENT' and l.relationship_id = 'Has component'
left join sn_attr s on l.attr_code = s.attr_code and l.relationship_id = 'Has component'

left join lc_attr l1 ON p.loincnumber = l1.lc_code and p.parttypename = 'SCALE' and l1.relationship_id = 'Has scale type'
left join sn_attr s1 on l1.attr_code = s1.attr_code and l1.relationship_id = 'Has scale type'

left join lc_attr l2 ON p.loincnumber = l2.lc_code and p.parttypename = 'SYSTEM' and l2.relationship_id = 'Has dir proc site'
left join sn_attr s2 on l2.attr_code = s2.attr_code and l2.relationship_id = 'Has dir proc site'

left join names_sim_component ns ON ns.concept_code_1 = p.partnumber

left join snomed_attr sa on sa.name = p.partname and sa.relationship_id = 'Has component'

   --Bad result with this type
    where p.linktypename != 'Search'
);

--stats
--2,153 absent in SNOMED source
select distinct loinc_code
from snomed_loinc_mapping_from_ody
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source);

--without common targets 7,971 covered loinc attributes
--7,861 with the same targets
select *
from snomed_loinc_mapping_from_ody
where snomed_attr_code IS NOT NULL
and loinc_code IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and snomed_attr_code NOT IN (select distinct snomed_attr_code from snomed_loinc_mapping_from_source)
and snomed_attr_code IN (select concept_code from devv5.concept where vocabulary_id = 'SNOMED' and invalid_reason IS NULL);


--135 different targets
select od.loinc_code as loinc_code,
       od.loinc_name as loinc_name,
       od.snomed_attr_code as ody_code,
       od.snomed_attr_name as ody_name,
       od.relationship as rels,
       sn.snomed_attr_code as sn_code,
       sn.snomed_attr_name as sn_name
from snomed_loinc_mapping_from_ody od
join snomed_loinc_mapping_from_source sn ON od.loinc_code = sn.loinc_code and od.snomed_attr_code != sn.snomed_attr_code
where od.snomed_attr_code IS NOT NULL
and od.snomed_attr_code IN (select concept_code from devv5.concept where vocabulary_id = 'SNOMED' and invalid_reason IS NULL);

select *
from snomed_loinc_mapping_from_source
where loinc_code IN (select distinct loinc_code from snomed_loinc_mapping_from_ody)
and snomed_attr_code IN (select distinct snomed_attr_code from snomed_loinc_mapping_from_ody);


--delivery: component to component
with tab as (select distinct loinc_code
from snomed_loinc_mapping_from_ody
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and loinc_code IN (select maptarget from sources.scccrefset_mapcorrorfull_int)

union

select distinct loinc_code
from snomed_loinc_mapping_from_ody o
/*join sources.loinc_partlink_primary p ON p.partnumber = o.loinc_code and p.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int)*/
left join sources.loinc_partlink_supplementary s ON s.partnumber = o.loinc_code
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and s.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int)

union

select distinct loinc_code
from snomed_loinc_mapping_from_ody o
left join sources.loinc_partlink_primary p ON p.partnumber = o.loinc_code
/*join sources.loinc_partlink_supplementary s ON s.partnumber = o.loinc_code and s.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int)*/
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and p.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int))

select distinct loinc_code, loinc_name, relationship, snomed_attr_code, snomed_attr_name
from snomed_loinc_mapping_from_ody
/*left join sources.loinc_partlink_supplementary p ON p.partnumber = loinc_code*/
where loinc_code not in (select loinc_code from tab)
and snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and snomed_attr_code NOT IN ('105590001', '116646001', '34829007', '300899005', '96178004')
and snomed_attr_code IN (select concept_code from devv5.concept
                                    where vocabulary_id = 'SNOMED' and invalid_reason IS NULL)

union

select distinct loinc_code, loinc_name, relationship, snomed_attr_code, snomed_attr_name
from snomed_loinc_mapping_from_ody
/*left join sources.loinc_partlink_primary p ON p.partnumber = loinc_code*/
where loinc_code not in (select loinc_code from tab)
and snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and snomed_attr_code NOT IN ('105590001', '116646001', '34829007', '300899005', '96178004')
and snomed_attr_code IN (select concept_code from devv5.concept
                                    where vocabulary_id = 'SNOMED' and invalid_reason IS NULL)
;



--delivery: measurement to component
with tab as (select distinct loinc_code
from snomed_loinc_mapping_from_ody
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and loinc_code IN (select maptarget from sources.scccrefset_mapcorrorfull_int)

union

select distinct loinc_code
from snomed_loinc_mapping_from_ody o
/*join sources.loinc_partlink_primary p ON p.partnumber = o.loinc_code and p.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int)*/
left join sources.loinc_partlink_supplementary s ON s.partnumber = o.loinc_code
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and s.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int)

union

select distinct loinc_code
from snomed_loinc_mapping_from_ody o
left join sources.loinc_partlink_primary p ON p.partnumber = o.loinc_code
/*join sources.loinc_partlink_supplementary s ON s.partnumber = o.loinc_code and s.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int)*/
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and p.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int))

select distinct loincnumber, longcommonname, relationship, snomed_attr_code, snomed_attr_name
from snomed_loinc_mapping_from_ody
left join sources.loinc_partlink_supplementary p ON p.partnumber = loinc_code
where loinc_code not in (select loinc_code from tab)
and snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and snomed_attr_code NOT IN ('105590001', '116646001', '34829007', '300899005', '96178004')
and snomed_attr_code IN (select concept_code from devv5.concept
                                    where vocabulary_id = 'SNOMED' and invalid_reason IS NULL)
and loincnumber IS NOT NULL

union

select distinct loincnumber, longcommonname, relationship, snomed_attr_code, snomed_attr_name
from snomed_loinc_mapping_from_ody
left join sources.loinc_partlink_primary p ON p.partnumber = loinc_code
where loinc_code not in (select loinc_code from tab)
and snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and snomed_attr_code NOT IN ('105590001', '116646001', '34829007', '300899005', '96178004')
and snomed_attr_code IN (select concept_code from devv5.concept
                                    where vocabulary_id = 'SNOMED' and invalid_reason IS NULL)
and loincnumber IS NOT NULL
;


select distinct loinc_code
from snomed_loinc_mapping_from_ody o
/*join sources.loinc_partlink_primary p ON p.partnumber = o.loinc_code and p.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int)*/
join sources.loinc_partlink_supplementary s ON s.partnumber = o.loinc_code and s.loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int)
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source);

select distinct loinc_code
from snomed_loinc_mapping_from_ody
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select distinct loinc_code from snomed_loinc_mapping_from_source)
and loinc_code IN (select concept_code_1 from names_sim_component);

select *
from sources.loinc_partlink_primary
where loincnumber IN (select maptarget from sources.scccrefset_expressionassociation_int) limit 1;

select *
from sources.scccrefset_expressionassociation_int limit 1;

select *
from snomed_loinc_mapping_from_ody
where snomed_attr_code IS NOT NULL
and loinc_code NOT IN (select loinc_code from snomed_loinc_mapping_from_source);

--stats
select *
from snomed_loinc_mapping_from_source
where loinc_code not in (select loinc_code from snomed_loinc_mapping_from_ody where snomed_attr_code IS NOT NULL);

select distinct linktypename, count(*)
from sources.loinc_partlink_primary
group by linktypename;

select *
from sources.loinc_partlink_supplementary
where partnumber = 'LP17763-1';

with tab as (select distinct
                partnumber, partname, parttypename
from sources.loinc_partlink_primary

union

select distinct p.partnumber,
                p.partname,
                p.parttypename
from sources.loinc_partlink_supplementary p)

select *
from tab
where partnumber not in (select loinc_code from snomed_loinc_mapping_from_ody)
/*and partnumber not in (select partnumber from sources.loinc_partlink_supplementary where linktypename = 'Search')*/;

--sources.loinc_partlink_supplementary
select *
from sources.loinc_partlink_primary limit 1;


select loinc_code, loinc_name, relationship, snomed_attr_code, snomed_attr_name
from snomed_loinc_mapping_from_ody
where snomed_attr_code IS NULL --without pair
and loinc_code NOT IN (select loinc_code from snomed_loinc_mapping_from_source) --mapping for them not exist in the snomed source
and relationship IN ('COMPONENT', 'METHOD', 'TIME', 'SYSTEM', 'PROPERTY', 'SCALE') --main axes
and loinc_code IN (select partnumber
                        from sources.loinc_partlink_primary
                        where linktypename = 'Primary')  --only primary attributes
and loinc_code IN --only valid Lab Tests
    (select c.concept_code
                          from concept c
                          join concept_relationship cr ON cr.concept_id_1 = c.concept_id and cr.invalid_reason IS NULL
                          join concept cc ON cc.concept_id = cr.concept_id_2 and cc.concept_class_id = 'Lab Test' and cc.invalid_reason IS NULL
                             --with snomed hierarchy
                          /*join devv5.concept_ancestor ca ON ca.descendant_concept_id = cc.concept_id
                          join concept c2 ON c2.concept_id = ca.ancestor_concept_id and c2.vocabulary_id = 'SNOMED'*/
                          where c.vocabulary_id = 'LOINC'
                            --users counts
                          /*and cc.concept_code IN (select concept_code from helsinki_loinc_code_counts)
                          and cc.concept_code IN (select concept_code from loinc_colorado)
                          and cc.concept_code IN (select concept_code from loinc_counts_across_network)
                          and cc.concept_code IN (select concept_code from loinc_frequency_dfci)
                          and cc.concept_code IN (select concept_code from stanford_loinc_codes)*/
                   )
  --exclude panels
and loinc_name not like '%panel%'
  --exclude ratio
and loinc_name not like '%/%'

and loinc_name not like '% Ab%'

and loinc_name !~* 'gene|deletion|Chromosome'

and relationship NOT IN ('SYSTEM', 'PROPERTY', 'METHOD', 'TIME', 'SCALE')

and loinc_code NOT IN (select concept_code
                   from concept
                   join concept_relationship ON concept_id = concept_id_2 and relationship_id = 'Has component'
                   join devv5.concept_ancestor ON concept_id_1 = descendant_concept_id
                                                      and ancestor_concept_id = '37074284' --Drug toxicology
                   where vocabulary_id = 'LOINC'
                   )

and loinc_name !~* 'CD'

and loinc_name !~* 'virus|bacter|DNA|sp '
/*order by random()
limit 30*/
;


--automapping only with components that have smomed measurement
--381
select loinc_name,
/*split_part(loinc_name, ' Ab.', 1) as agent,
       split_part(loinc_name, ' Ab.', 2) as type,*/
       sa.name
from snomed_loinc_mapping_from_ody
join snomed_attr sa on (
    split_part(sa.name, ' IgG', 1) = split_part(loinc_name, ' Ab.', 1)
        OR
    split_part(sa.name, ' antibody', 1) = split_part(loinc_name, ' Ab.', 1)
        OR
    split_part(sa.name, ' Ab', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.name, ' immunoglobulin G', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.name, ' immunoglobulin A', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.name, ' IgA', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.name, ' immunoglobulin E', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.name, ' IgE', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.name, ' IgM', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.name, ' immunoglobulin M', 1) = split_part(loinc_name, ' Ab.', 1)
                        )
                           and sa.relationship_id = 'Has component'
                            and (sa.name LIKE '%antibody%'
                                     or sa.name LIKE '%immunoglobulin E%'
                                     or sa.name LIKE '%immunoglobulin G%'
                                     or sa.name LIKE '%immunoglobulin A%'
                                     or sa.name LIKE '%immunoglobulin M%'
                                     or sa.name LIKE '% Ab%'
                                or sa.name LIKE '% IgM%'
                                or sa.name LIKE '% IgG%'
                                or sa.name LIKE '% IgA%'
                                or sa.name LIKE '% IgE%')
where snomed_attr_code IS NULL --without pair
and loinc_code NOT IN (select loinc_code from snomed_loinc_mapping_from_source) --mapping for them not exist in the snomed source
and relationship IN ('COMPONENT', 'METHOD', 'TIME', 'SYSTEM', 'PROPERTY', 'SCALE') --main axes
and loinc_code IN (select partnumber
                        from sources.loinc_partlink_primary
                        where linktypename = 'Primary')  --only primary attributes
and loinc_code IN --only valid Lab Tests
    (select c.concept_code
                          from concept c
                          join concept_relationship cr ON cr.concept_id_1 = c.concept_id and cr.invalid_reason IS NULL
                          join concept cc ON cc.concept_id = cr.concept_id_2 and cc.concept_class_id = 'Lab Test' and cc.invalid_reason IS NULL
                             --with snomed hierarchy
                          /*join devv5.concept_ancestor ca ON ca.descendant_concept_id = cc.concept_id
                          join concept c2 ON c2.concept_id = ca.ancestor_concept_id and c2.vocabulary_id = 'SNOMED'*/
                          where c.vocabulary_id = 'LOINC'
                            --users counts
                          /*and cc.concept_code IN (select concept_code from helsinki_loinc_code_counts)
                          and cc.concept_code IN (select concept_code from loinc_colorado)
                          and cc.concept_code IN (select concept_code from loinc_counts_across_network)
                          and cc.concept_code IN (select concept_code from loinc_frequency_dfci)
                          and cc.concept_code IN (select concept_code from stanford_loinc_codes)*/
                   )
  --exclude panels
and loinc_name not like '%panel%'
  --exclude ratio
and loinc_name not like '%/%'

and loinc_name like '% Ab%' and loinc_name not like '(%';


--automapping on Substance class
--877
select loinc_name,
/*split_part(loinc_name, ' Ab.', 1) as agent,
       split_part(loinc_name, ' Ab.', 2) as type,*/
       sa.concept_name
from snomed_loinc_mapping_from_ody
join concept sa on (
    split_part(sa.concept_name, ' IgG', 1) = split_part(loinc_name, ' Ab.', 1)
        OR
    split_part(sa.concept_name, ' antibody', 1) = split_part(loinc_name, ' Ab.', 1)
        OR
    split_part(sa.concept_name, ' Ab', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' immunoglobulin G', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' immunoglobulin A', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' IgA', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' immunoglobulin E', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' IgE', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' IgM', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' immunoglobulin M', 1) = split_part(loinc_name, ' Ab.', 1)
                        )
                           and sa.vocabulary_id = 'SNOMED'
                       and sa.concept_class_id = 'Substance'
                            and (sa.concept_name LIKE '%antibody%'
                                     or sa.concept_name LIKE '%immunoglobulin E%'
                                     or sa.concept_name LIKE '%immunoglobulin G%'
                                     or sa.concept_name LIKE '%immunoglobulin A%'
                                     or sa.concept_name LIKE '%immunoglobulin M%'
                                     or sa.concept_name LIKE '% Ab%'
                                or sa.concept_name LIKE '% IgM%'
                                or sa.concept_name LIKE '% IgG%'
                                or sa.concept_name LIKE '% IgA%'
                                or sa.concept_name LIKE '% IgE%')
where snomed_attr_code IS NULL --without pair
and loinc_code NOT IN (select loinc_code from snomed_loinc_mapping_from_source) --mapping for them not exist in the snomed source
and relationship IN ('COMPONENT', 'METHOD', 'TIME', 'SYSTEM', 'PROPERTY', 'SCALE') --main axes
and loinc_code IN (select partnumber
                        from sources.loinc_partlink_primary
                        where linktypename = 'Primary')  --only primary attributes
and loinc_code IN --only valid Lab Tests
    (select c.concept_code
                          from concept c
                          join concept_relationship cr ON cr.concept_id_1 = c.concept_id and cr.invalid_reason IS NULL
                          join concept cc ON cc.concept_id = cr.concept_id_2 and cc.concept_class_id = 'Lab Test' and cc.invalid_reason IS NULL
                             --with snomed hierarchy
                          /*join devv5.concept_ancestor ca ON ca.descendant_concept_id = cc.concept_id
                          join concept c2 ON c2.concept_id = ca.ancestor_concept_id and c2.vocabulary_id = 'SNOMED'*/
                          where c.vocabulary_id = 'LOINC'
                            --users counts
                          /*and cc.concept_code IN (select concept_code from helsinki_loinc_code_counts)
                          and cc.concept_code IN (select concept_code from loinc_colorado)
                          and cc.concept_code IN (select concept_code from loinc_counts_across_network)
                          and cc.concept_code IN (select concept_code from loinc_frequency_dfci)
                          and cc.concept_code IN (select concept_code from stanford_loinc_codes)*/
                   )
  --exclude panels
and loinc_name not like '%panel%'
  --exclude ratio
and loinc_name not like '%/%'

and loinc_name like '% Ab%' and loinc_name not like '(%';


--out
-- it is possible to map viruses -- 356
with tab as (select loinc_name,
/*split_part(loinc_name, ' Ab.', 1) as agent,
       split_part(loinc_name, ' Ab.', 2) as type,*/
       sa.concept_name
from snomed_loinc_mapping_from_ody
join concept sa on (
    split_part(sa.concept_name, ' IgG', 1) = split_part(loinc_name, ' Ab.', 1)
        OR
    split_part(sa.concept_name, ' antibody', 1) = split_part(loinc_name, ' Ab.', 1)
        OR
    split_part(sa.concept_name, ' Ab', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' immunoglobulin G', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' immunoglobulin A', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' IgA', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' immunoglobulin E', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' IgE', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' IgM', 1) = split_part(loinc_name, ' Ab.', 1)
    OR
    split_part(sa.concept_name, ' immunoglobulin M', 1) = split_part(loinc_name, ' Ab.', 1)
                        )
                           and sa.vocabulary_id = 'SNOMED'
                       and sa.concept_class_id = 'Substance'
                            and (sa.concept_name LIKE '%antibody%'
                                     or sa.concept_name LIKE '%immunoglobulin E%'
                                     or sa.concept_name LIKE '%immunoglobulin G%'
                                     or sa.concept_name LIKE '%immunoglobulin A%'
                                     or sa.concept_name LIKE '%immunoglobulin M%'
                                     or sa.concept_name LIKE '% Ab%'
                                or sa.concept_name LIKE '% IgM%'
                                or sa.concept_name LIKE '% IgG%'
                                or sa.concept_name LIKE '% IgA%'
                                or sa.concept_name LIKE '% IgE%')
where snomed_attr_code IS NULL --without pair
and loinc_code NOT IN (select loinc_code from snomed_loinc_mapping_from_source) --mapping for them not exist in the snomed source
and relationship IN ('COMPONENT', 'METHOD', 'TIME', 'SYSTEM', 'PROPERTY', 'SCALE') --main axes
and loinc_code IN (select partnumber
                        from sources.loinc_partlink_primary
                        where linktypename = 'Primary')  --only primary attributes
and loinc_code IN --only valid Lab Tests
    (select c.concept_code
                          from concept c
                          join concept_relationship cr ON cr.concept_id_1 = c.concept_id and cr.invalid_reason IS NULL
                          join concept cc ON cc.concept_id = cr.concept_id_2 and cc.concept_class_id = 'Lab Test' and cc.invalid_reason IS NULL
                             --with snomed hierarchy
                          /*join devv5.concept_ancestor ca ON ca.descendant_concept_id = cc.concept_id
                          join concept c2 ON c2.concept_id = ca.ancestor_concept_id and c2.vocabulary_id = 'SNOMED'*/
                          where c.vocabulary_id = 'LOINC'
                            --users counts
                          /*and cc.concept_code IN (select concept_code from helsinki_loinc_code_counts)
                          and cc.concept_code IN (select concept_code from loinc_colorado)
                          and cc.concept_code IN (select concept_code from loinc_counts_across_network)
                          and cc.concept_code IN (select concept_code from loinc_frequency_dfci)
                          and cc.concept_code IN (select concept_code from stanford_loinc_codes)*/
                   )
  --exclude panels
and loinc_name not like '%panel%'
  --exclude ratio
and loinc_name not like '%/%'

and loinc_name like '% Ab%' and loinc_name not like '(%')

select loinc_code,
       loinc_name,
       relationship,
       split_part(loinc_name, ' Ab.', 1) as agent,
       split_part(loinc_name, ' Ab.', 2) as type
from snomed_loinc_mapping_from_ody
where snomed_attr_code IS NULL --without pair
  and loinc_name not in (select loinc_name from tab)
and loinc_code NOT IN (select loinc_code from snomed_loinc_mapping_from_source) --mapping for them not exist in the snomed source
and relationship IN ('COMPONENT', 'METHOD', 'TIME', 'SYSTEM', 'PROPERTY', 'SCALE') --main axes
and loinc_code IN (select partnumber
                        from sources.loinc_partlink_primary
                        where linktypename = 'Primary')  --only primary attributes
and loinc_code IN --only valid Lab Tests
    (select c.concept_code
                          from concept c
                          join concept_relationship cr ON cr.concept_id_1 = c.concept_id and cr.invalid_reason IS NULL
                          join concept cc ON cc.concept_id = cr.concept_id_2 and cc.concept_class_id = 'Lab Test' and cc.invalid_reason IS NULL
                             --with snomed hierarchy
                          /*join devv5.concept_ancestor ca ON ca.descendant_concept_id = cc.concept_id
                          join concept c2 ON c2.concept_id = ca.ancestor_concept_id and c2.vocabulary_id = 'SNOMED'*/
                          where c.vocabulary_id = 'LOINC'
                            --users counts
                          /*and cc.concept_code IN (select concept_code from helsinki_loinc_code_counts)
                          and cc.concept_code IN (select concept_code from loinc_colorado)
                          and cc.concept_code IN (select concept_code from loinc_counts_across_network)
                          and cc.concept_code IN (select concept_code from loinc_frequency_dfci)
                          and cc.concept_code IN (select concept_code from stanford_loinc_codes)*/
                   )
  --exclude panels
and loinc_name not like '%panel%'
  --exclude ratio
and loinc_name not like '%/%'

and loinc_name like '% Ab%' and loinc_name not like '(%'

order by random()
limit 30;

--for us
--479 Abciximab induced platelet Ab.IgM, Acarbose induced platelet Ab.IgG and ect is possible to map on  4019736 115574009 Drug induced platelet antibody
--147 induced neutrophil to map on 35624339	767021001	Neutrophil Ab



--------------------------------This is a part of loinc refresh now-------------------------
/*with tab3 as (with tab as (SELECT distinct c.concept_id as loinc_id, --id of the real concept
                    si.alternateIdentifier, --loinc_code of the real concept
                    c.concept_name, --loinc name of the real concept
                    c2.concept_id as snomed_id,
                    c2.concept_code as snomed_code,
                    c2.concept_name as snomed_name,
                    c1.concept_code as component_code,
                    c1.concept_name as component_name,
                    c3.concept_code as specimen_code,
                    c3.concept_name as specimen_name,
                    c4.concept_code as method_code,
                    c4.concept_name as method_name,
                    c5.concept_code as property_code,
                    c5.concept_name as property_name,
                    c6.concept_code as scale_code,
                    c6.concept_name as scale_name,
                    c7.concept_code as time_code,
                    c7.concept_name as time_name
             FROM snomed_relationship_full sr
                      join snomed_identifier_full si ON sr.sourceId = si.referencedComponentId
                      left join concept c ON c.concept_code = si.alternateIdentifier and c.vocabulary_id = 'LOINC'
                      left join concept c1 ON c1.concept_code = sr.destinationId and c1.vocabulary_id = 'SNOMED'
                      join concept_relationship cr ON c1.concept_id = cr.concept_id_1
                                                               and cr.relationship_id = 'Component of'
                                                               and cr.invalid_reason IS NULL
                      join concept c2 ON cr.concept_id_2 = c2.concept_id and c2.vocabulary_id = 'SNOMED'
                                                                                    and c2.invalid_reason IS NULL

                      left join concept_relationship cr1 ON c2.concept_id = cr1.concept_id_1
                                                               and cr1.relationship_id IN ('Has specimen', 'Has direct site')
                                                               and cr1.invalid_reason IS NULL
                      left join concept c3 ON cr1.concept_id_2 = c3.concept_id and c3.vocabulary_id = 'SNOMED'

                      left join concept_relationship cr2 ON c2.concept_id = cr2.concept_id_1
                                                               and cr2.relationship_id = 'Has method'
                                                               and cr2.invalid_reason IS NULL
                      left join concept c4 ON cr2.concept_id_2 = c4.concept_id and c4.vocabulary_id = 'SNOMED'

                      left join concept_relationship cr3 ON c2.concept_id = cr3.concept_id_1
                                                               and cr3.relationship_id = 'Has property'
                                                               and cr3.invalid_reason IS NULL
                      left join concept c5 ON cr3.concept_id_2 = c5.concept_id and c5.vocabulary_id = 'SNOMED'

                      left join concept_relationship cr4 ON c2.concept_id = cr4.concept_id_1
                                                               and cr4.relationship_id = 'Has scale type'
                                                               and cr4.invalid_reason IS NULL
                      left join concept c6 ON cr4.concept_id_2 = c6.concept_id and c6.vocabulary_id = 'SNOMED'

                      left join concept_relationship cr5 ON c2.concept_id = cr5.concept_id_1
                                                               and cr5.relationship_id = 'Has time aspect'
                                                               and cr5.invalid_reason IS NULL
                      left join concept c7 ON cr5.concept_id_2 = c7.concept_id and c7.vocabulary_id = 'SNOMED'

             where sr.typeId != '116680003' --Is a

             and c.concept_id NOT IN (select concept_id_1 from concept_relationship
                where relationship_id = 'Is a'
                  and invalid_reason IS NULL
                 and concept_id_2 IN (select concept_id from concept where vocabulary_id = 'SNOMED'))
    ),
           tab1 as (
         SELECT distinct c.concept_id as loinc_id, --id of the real concept
                    si.alternateIdentifier as loinc_code, --loinc_code of the real concept
                    c.concept_name, --loinc name of the real concept
                    c1.concept_code as component_code,
                    c1.concept_name as component_name,
                    c2.concept_code as specimen_code,
                    c2.concept_name as specimen_name,
                    c3.concept_code as method_code,
                    c3.concept_name as method_name,
                    c4.concept_code as property_code,
                    c4.concept_name as property_name,
                    c5.concept_code as scale_code,
                    c5.concept_name as scale_name,
                    c6.concept_code as time_code,
                    c6.concept_name as time_name/*,
                    CASE
                        WHEN sr.typeId = '370130000'
                            THEN 'Property'
                        WHEN sr.typeId = '246093002'
                            THEN 'Component'
                        WHEN sr.typeId = '246501002'
                            THEN 'Method'
                        WHEN sr.typeId = '370132008'
                            THEN 'Scale'
                        WHEN sr.typeId IN ('370133003', '704319004', '704327008')
                            THEN 'Specimen'
                        WHEN sr.typeId = '370134009'
                            THEN 'Time'
                        --In LOINC Terms it is a part of component. Examples: post dialysis, after exercise
                        --not used in the final table
                        WHEN sr.typeId = '704326004'
                            THEN 'Precondition'
                        END as relationship*/
             FROM snomed_relationship_full sr
                      join snomed_identifier_full si ON sr.sourceId = si.referencedComponentId and sr.typeId = '246093002'  --Component
                      left join concept c ON c.concept_code = si.alternateIdentifier and c.vocabulary_id = 'LOINC'
                      left join concept c1 ON c1.concept_code = sr.destinationId and c1.vocabulary_id = 'SNOMED'

                      left join snomed_relationship_full sr1 ON sr.sourceId = sr1.sourceId
                                                                    and sr1.typeId IN ('370133003', '704319004', '704327008') --Specimen
                      left join concept c2 ON c2.concept_code = sr1.destinationId and c2.vocabulary_id = 'SNOMED'

                      left join snomed_relationship_full sr2 ON sr.sourceId = sr2.sourceId
                                                                    and sr2.typeId = '246501002' --Method
                      left join concept c3 ON c3.concept_code = sr2.destinationId and c3.vocabulary_id = 'SNOMED'

                      left join snomed_relationship_full sr3 ON sr.sourceId = sr3.sourceId
                                                             and sr3.typeId = '370130000' --Property
                      left join concept c4 ON c4.concept_code = sr3.destinationId and c4.vocabulary_id = 'SNOMED'

                      left join snomed_relationship_full sr4 ON sr.sourceId = sr4.sourceId
                                                                        and sr4.typeId = '370132008' --Scale
                      left join concept c5 ON c5.concept_code = sr4.destinationId and c5.vocabulary_id = 'SNOMED'

                      left join snomed_relationship_full sr5 ON sr.sourceId = sr5.sourceId
                                                             and sr5.typeId = '370134009'
                      left join concept c6 ON c6.concept_code = sr5.destinationId and c6.vocabulary_id = 'SNOMED'

         where sr.typeId != '116680003' --Is a

             and c.concept_id NOT IN (select concept_id_1 from concept_relationship
                where relationship_id = 'Is a'
                  and invalid_reason IS NULL
                 and concept_id_2 IN (select concept_id from concept where vocabulary_id = 'SNOMED'))

         ),
           ax1 as (select t.loinc_id as concept_id,
                    alternateIdentifier as concept_code,
                    t.concept_name as concept_name,
                    snomed_code as target_concept_code,
                    snomed_name as target_concept_name,
                    t.component_code as target_component_code,
                    t.component_name as target_component_name,
                    t.specimen_code as target_specimen_code,
                    t.specimen_name as target_specimen_name,
                    t.method_code as target_method_code,
                    t.method_name as target_method_name,
                    t.property_code as target_property_code,
                    t.property_name as target_property_name,
                    t.scale_code as target_scale_code,
                    t.scale_name as target_scale_name,
                    t.time_code as target_time_code,
                    t.time_name as target_time_name,
                    t1.component_code,
                    t1.component_name,
                    t1.specimen_code,
                    t1.specimen_name,
                    t1.method_code,
                    t1.method_name,
                    t1.property_code,
                    t1.property_name,
                    t1.scale_code,
                    t1.scale_name,
                    t1.time_code,
                    t1.time_name
             from tab t
join tab1 t1 ON t.loinc_id = t1.loinc_id  --all
                    AND t.component_code = t1.component_code
                    AND t.specimen_code = t1.specimen_code
                    AND t.method_code = t1.method_code
                    AND t.property_code = t1.property_code
                    AND t.scale_code = t1.scale_code
                    AND t.time_code = t1.time_code),
           ax2 as (select t.loinc_id as concept_id,
                    alternateIdentifier as concept_code,
                    t.concept_name as concept_name,
                    snomed_code as target_concept_code,
                    snomed_name as target_concept_name,
                    t.component_code as target_component_code,
                    t.component_name as target_component_name,
                    t.specimen_code as target_specimen_code,
                    t.specimen_name as target_specimen_name,
                    t.method_code as target_method_code,
                    t.method_name as target_method_name,
                    t.property_code as target_property_code,
                    t.property_name as target_property_name,
                    t.scale_code as target_scale_code,
                    t.scale_name as target_scale_name,
                    t.time_code as target_time_code,
                    t.time_name as target_time_name,
                    t1.component_code,
                    t1.component_name,
                    t1.specimen_code,
                    t1.specimen_name,
                    t1.method_code,
                    t1.method_name,
                    t1.property_code,
                    t1.property_name,
                    t1.scale_code,
                    t1.scale_name,
                    t1.time_code,
                    t1.time_name                   --scale
                    from tab t
                    join tab1 t1 ON t.loinc_id = t1.loinc_id
                    AND t.component_code = t1.component_code
                    AND t.specimen_code = t1.specimen_code
                    /*AND t.method_code = t1.method_code*/
                    /*AND t.property_code = t1.property_code*/
                    AND t.scale_code = t1.scale_code
                    /*AND t.time_code = t1.time_code*/),

           ax3 as (select t.loinc_id as concept_id,
                    alternateIdentifier as concept_code,
                    t.concept_name as concept_name,
                    snomed_code as target_concept_code,
                    snomed_name as target_concept_name,
                    t.component_code as target_component_code,
                    t.component_name as target_component_name,
                    t.specimen_code as target_specimen_code,
                    t.specimen_name as target_specimen_name,
                    t.method_code as target_method_code,
                    t.method_name as target_method_name,
                    t.property_code as target_property_code,
                    t.property_name as target_property_name,
                    t.scale_code as target_scale_code,
                    t.scale_name as target_scale_name,
                    t.time_code as target_time_code,
                    t.time_name as target_time_name,
                    t1.component_code,
                    t1.component_name,
                    t1.specimen_code,
                    t1.specimen_name,
                    t1.method_code,
                    t1.method_name,
                    t1.property_code,
                    t1.property_name,
                    t1.scale_code,
                    t1.scale_name,
                    t1.time_code,
                    t1.time_name                  --time
                    from tab t
                    join tab1 t1 ON t.loinc_id = t1.loinc_id
                    AND t.component_code = t1.component_code
                    AND t.specimen_code = t1.specimen_code
                    /*AND t.method_code = t1.method_code*/
                    AND t.property_code = t1.property_code
                    /*AND t.scale_code = t1.scale_code*/
                    AND t.time_code = t1.time_code),
           ax4 as (select t.loinc_id as concept_id,
                    alternateIdentifier as concept_code,
                    t.concept_name as concept_name,
                    snomed_code as target_concept_code,
                    snomed_name as target_concept_name,
                    t.component_code as target_component_code,
                    t.component_name as target_component_name,
                    t.specimen_code as target_specimen_code,
                    t.specimen_name as target_specimen_name,
                    t.method_code as target_method_code,
                    t.method_name as target_method_name,
                    t.property_code as target_property_code,
                    t.property_name as target_property_name,
                    t.scale_code as target_scale_code,
                    t.scale_name as target_scale_name,
                    t.time_code as target_time_code,
                    t.time_name as target_time_name,
                    t1.component_code,
                    t1.component_name,
                    t1.specimen_code,
                    t1.specimen_name,
                    t1.method_code,
                    t1.method_name,
                    t1.property_code,
                    t1.property_name,
                    t1.scale_code,
                    t1.scale_name,
                    t1.time_code,
                    t1.time_name                  --method
                    from tab t
                    join tab1 t1 ON t.loinc_id = t1.loinc_id
                    /*AND t.component_code = t1.component_code
                    AND t.specimen_code = t1.specimen_code*/
                    AND t.method_code = t1.method_code
                    /*AND t.property_code = t1.property_code
                    AND t.scale_code = t1.scale_code
                    AND t.time_code = t1.time_code*/),

           ax5 as (select t.loinc_id as concept_id,
                    alternateIdentifier as concept_code,
                    t.concept_name as concept_name,
                    snomed_code as target_concept_code,
                    snomed_name as target_concept_name,
                    t.component_code as target_component_code,
                    t.component_name as target_component_name,
                    t.specimen_code as target_specimen_code,
                    t.specimen_name as target_specimen_name,
                    t.method_code as target_method_code,
                    t.method_name as target_method_name,
                    t.property_code as target_property_code,
                    t.property_name as target_property_name,
                    t.scale_code as target_scale_code,
                    t.scale_name as target_scale_name,
                    t.time_code as target_time_code,
                    t.time_name as target_time_name,
                    t1.component_code,
                    t1.component_name,
                    t1.specimen_code,
                    t1.specimen_name,
                    t1.method_code,
                    t1.method_name,
                    t1.property_code,
                    t1.property_name,
                    t1.scale_code,
                    t1.scale_name,
                    t1.time_code,
                    t1.time_name,                --property + com +specimen
                    ROW_NUMBER() OVER (PARTITION BY t.loinc_id ORDER BY count(*) DESC) AS row_num
                    from tab t
                    join tab1 t1 ON t.loinc_id = t1.loinc_id
                    AND t.component_code = t1.component_code
                    AND t.specimen_code = t1.specimen_code
                    /*AND t.method_code = t1.method_code*/
                    AND t.property_code = t1.property_code
                    /*AND t.scale_code = t1.scale_code
                    AND t.time_code = t1.time_code*/
           left join concept_relationship cr ON cr.concept_id_1 = t.snomed_id and relationship_id = 'Subsumes' and invalid_reason IS NULL

         where t.loinc_id NOT IN (select concept_id from ax2)

               and (t1.method_code IS NOT NULL
                    OR (t1.method_code IS NULL and snomed_name !~* 'automated|immunoassay|immunoflourescence|immunosorbent')
               )
               group by t.loinc_id, alternateIdentifier, t.concept_name, snomed_code, snomed_name, t.component_code, t.component_name, t.specimen_code, t.specimen_name, t.method_code, t.method_name, t.property_code, t.property_name, t.scale_code, t.scale_name, t.time_code, t.time_name, t1.component_code, t1.component_name, t1.specimen_code, t1.specimen_name, t1.method_code, t1.method_name, t1.property_code, t1.property_name, t1.scale_code, t1.scale_name, t1.time_code, t1.time_name
         ),

           ax6 as (select t.loinc_id as concept_id,
                    alternateIdentifier as concept_code,
                    t.concept_name as concept_name,
                    snomed_code as target_concept_code,
                    snomed_name as target_concept_name,
                    t.component_code as target_component_code,
                    t.component_name as target_component_name,
                    t.specimen_code as target_specimen_code,
                    t.specimen_name as target_specimen_name,
                    t.method_code as target_method_code,
                    t.method_name as target_method_name,
                    t.property_code as target_property_code,
                    t.property_name as target_property_name,
                    t.scale_code as target_scale_code,
                    t.scale_name as target_scale_name,
                    t.time_code as target_time_code,
                    t.time_name as target_time_name,
                    t1.component_code,
                    t1.component_name,
                    t1.specimen_code,
                    t1.specimen_name,
                    t1.method_code,
                    t1.method_name,
                    t1.property_code,
                    t1.property_name,
                    t1.scale_code,
                    t1.scale_name,
                    t1.time_code,
                    t1.time_name,               -- com +specimen
                    ROW_NUMBER() OVER (PARTITION BY t.loinc_id ORDER BY count(*) DESC) AS row_num
                    from tab t
                    join tab1 t1 ON t.loinc_id = t1.loinc_id AND t.component_code = t1.component_code AND t.specimen_code = t1.specimen_code
                    left join concept_relationship cr ON cr.concept_id_1 = t.snomed_id and relationship_id = 'Subsumes' and invalid_reason IS NULL
                    /*AND t.method_code = t1.method_code*/
                    /*AND t.property_code = t1.property_code*/
                    /*AND t.scale_code = t1.scale_code
                    AND t.time_code = t1.time_code*/

         where t.loinc_id NOT IN (select concept_id from ax2)

         and t.loinc_id NOT IN (select concept_id from ax5)

         and (t.property_code IS NULL OR t1.property_code IS NULL
             OR t.property_code = t1.property_code
             )

           and (t.scale_code IS NULL OR t1.scale_code IS NULL
             OR t.scale_code = t1.scale_code
             )

           and (t1.method_code IS NOT NULL
                    OR (t1.method_code IS NULL and snomed_name !~* 'automated|immunoassay|immunoflourescence|immunosorbent')
               )

           and snomed_code NOT IN ('104193001', --Bacterial culture, urine, with colony count
                               '104230007', --Bacterial culture, urine, by commercial kit
                               '104194007',  --Bacterial culture, urine, with organism identification
                                '395030005',  --Skin biopsy C3 level
                                '104309001', --Cytomegalovirus IgM antibody assay
                                '313604004' --Cytomegalovirus IgG antibody measurement
                               )
           and snomed_name !~* 'C3c|C3a|C3d|C3b|C4d|C4a|C4b|C5a'

         and regexp_replace(t.concept_name, '[^0-9]', '', 'g') = regexp_replace(snomed_name, '[^0-9]', '', 'g')

               group by t.loinc_id, alternateIdentifier, t.concept_name, snomed_code, snomed_name, t.component_code, t.component_name, t.specimen_code, t.specimen_name, t.method_code, t.method_name, t.property_code, t.property_name, t.scale_code, t.scale_name, t.time_code, t.time_name, t1.component_code, t1.component_name, t1.specimen_code, t1.specimen_name, t1.method_code, t1.method_name, t1.property_code, t1.property_name, t1.scale_code, t1.scale_name, t1.time_code, t1.time_name
         ),

           ax7 as (select t.loinc_id as concept_id,
                    alternateIdentifier as concept_code,
                    t.concept_name as concept_name,
                    snomed_code as target_concept_code,
                    snomed_name as target_concept_name,
                    t.component_code as target_component_code,
                    t.component_name as target_component_name,
                    t.specimen_code as target_specimen_code,
                    t.specimen_name as target_specimen_name,
                    t.method_code as target_method_code,
                    t.method_name as target_method_name,
                    t.property_code as target_property_code,
                    t.property_name as target_property_name,
                    t.scale_code as target_scale_code,
                    t.scale_name as target_scale_name,
                    t.time_code as target_time_code,
                    t.time_name as target_time_name,
                    t1.component_code,
                    t1.component_name,
                    t1.specimen_code,
                    t1.specimen_name,
                    t1.method_code,
                    t1.method_name,
                    t1.property_code,
                    t1.property_name,
                    t1.scale_code,
                    t1.scale_name,
                    t1.time_code,
                    t1.time_name               -- com + property
                    from tab t
                    join tab1 t1 ON t.loinc_id = t1.loinc_id
                    AND t.component_code = t1.component_code
                    /*AND t.specimen_code = t1.specimen_code*/
                    /*AND t.method_code = t1.method_code*/
                    AND t.property_code = t1.property_code
                    /*AND t.scale_code = t1.scale_code
                    AND t.time_code = t1.time_code*/

         where t.loinc_id NOT IN (select concept_id from ax2)
         and t.loinc_id NOT IN (select concept_id from ax5)
         and t.loinc_id NOT IN (select concept_id from ax6)

            and (t.specimen_code IS NULL OR t1.specimen_code IS NULL
             OR t.specimen_code = t1.specimen_code
                OR (t.specimen_code ~* 'serum' and t1.specimen_code ~* 'serum')
                OR (t.specimen_code ~* 'phar|Sputum|Bronchoalveolar' and t1.specimen_code ~* 'throat|respiratory|phar')
                OR (t.specimen_code ~* 'blood' and t1.specimen_code ~* 'blood')
                OR (t.specimen_code ~* 'urine' and t1.specimen_code ~* 'urine')
                OR (t.specimen_code ~* 'plasma' and t1.specimen_code ~* 'plasma')
                OR (t.specimen_code ~* 'fluid' and t1.specimen_code ~* 'fluid')
                OR (t.specimen_code ~* 'Naso' and t1.specimen_code ~* 'nose')
                OR (t.specimen_code ~* 'Serum|Plasma' and t1.specimen_code ~* 'spot')
                OR (t.specimen_code ~* 'dial|fluid' and t1.specimen_code ~* 'Dialysate')
             )
         ),
           ax8 as (select t.loinc_id as concept_id,
                    alternateIdentifier as concept_code,
                    t.concept_name as concept_name,
                    snomed_code as target_concept_code,
                    snomed_name as target_concept_name,
                    t.component_code as target_component_code,
                    t.component_name as target_component_name,
                    t.specimen_code as target_specimen_code,
                    t.specimen_name as target_specimen_name,
                    t.method_code as target_method_code,
                    t.method_name as target_method_name,
                    t.property_code as target_property_code,
                    t.property_name as target_property_name,
                    t.scale_code as target_scale_code,
                    t.scale_name as target_scale_name,
                    t.time_code as target_time_code,
                    t.time_name as target_time_name,
                    t1.component_code,
                    t1.component_name,
                    t1.specimen_code,
                    t1.specimen_name,
                    t1.method_code,
                    t1.method_name,
                    t1.property_code,
                    t1.property_name,
                    t1.scale_code,
                    t1.scale_name,
                    t1.time_code,
                    t1.time_name               -- com
                    from tab t
                    join tab1 t1 ON t.loinc_id = t1.loinc_id
                    AND t.component_code = t1.component_code
                    /*AND t.specimen_code = t1.specimen_code*/
                    /*AND t.method_code = t1.method_code*/
                    /*AND t.property_code = t1.property_code*/
                    /*AND t.scale_code = t1.scale_code
                    AND t.time_code = t1.time_code*/

         where t.loinc_id NOT IN (select concept_id from ax2)
         and t.loinc_id NOT IN (select concept_id from ax5)
         and t.loinc_id NOT IN (select concept_id from ax6)
         and t.loinc_id NOT IN (select concept_id from ax7)
         )
select *
from ax1

union

select *
from ax2

union

select *
from ax3

union

select *
from ax4

union

select concept_id,
       concept_code,
       concept_name,
       target_concept_code,
       target_concept_name,
       target_component_code,
       target_component_name,
       target_specimen_code,
       target_specimen_name,
       target_method_code,
       target_method_name,
       target_property_code,
       target_property_name,
       target_scale_code,
       target_scale_name,
       target_time_code,
       target_time_name,
       component_code,
       component_name,
       specimen_code,
       specimen_name,
       method_code,
       method_name,
       property_code,
       property_name,
       scale_code,
       scale_name,
       time_code,
       time_name
from ax5
where row_num = '1'

union

select concept_id,
       concept_code,
       concept_name,
       target_concept_code,
       target_concept_name,
       target_component_code,
       target_component_name,
       target_specimen_code,
       target_specimen_name,
       target_method_code,
       target_method_name,
       target_property_code,
       target_property_name,
       target_scale_code,
       target_scale_name,
       target_time_code,
       target_time_name,
       component_code,
       component_name,
       specimen_code,
       specimen_name,
       method_code,
       method_name,
       property_code,
       property_name,
       scale_code,
       scale_name,
       time_code,
       time_name
              from ax6
where target_concept_code NOT IN (select target_concept_code
                                    from ax6
                                    where property_name = 'Presence' and  target_concept_name ~* 'level')
    and target_concept_code NOT IN (select target_concept_code
                                    from ax6
                                    where property_name != 'Presence' and  target_concept_name ~* 'screening')
    and (concept_name, target_concept_name) not in (select concept_name, target_concept_name
                                                            from ax6
                                                            where concept_name ~* 'manual' and target_concept_name ~* 'automated')
    and (concept_name, target_concept_name) not in (select concept_name, target_concept_name
                                                            from ax6
                                                            where concept_name !~* 'automated' and target_concept_name ~* 'automated')
    and row_num = '1'



union

select *
from ax7

/*union

select *
from ax8*/
    )

    select *
    from tab3
where concept_id NOT IN (select concept_id from tab3 group by concept_id having count(*) > 1)
;*/

--Immunofluorescence Immunoblot = immunoassay, immunoflourescence   43844-0  61241000237103
-- 30526-8    52491000237106
-- Automated = automated





------------------------------Parts of LOINC load_stage that participate in attributes matching--------------------------

/*SELECT DISTINCT s.maptarget AS concept_code_1, -- LOINC Attribute code
                cs.concept_name as concept_name_1,
	s.referencedcomponentid AS concept_code_2, -- SNOMED Attribute code
                c.concept_name as concept_name_2,
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'LOINC - SNOMED eq' AS relationship_id,
	NULL AS invalid_reason
FROM sources.scccrefset_mapcorrorfull_int s
JOIN devv5.concept cs ON cs.concept_code = s.maptarget --LOINC Attribute
	AND cs.vocabulary_id = 'LOINC'
	AND cs.invalid_reason IS NULL
JOIN concept c ON c.concept_code = s.referencedcomponentid --SNOMED Attribute
	AND c.vocabulary_id = 'SNOMED'
	AND c.invalid_reason IS NULL
JOIN vocabulary v ON cs.vocabulary_id = v.vocabulary_id --valid_start_date
WHERE s.attributeid IN (
		'246093002',
		'704319004',
		'704327008',
		'718497002'
		);


select *
from sources.scccrefset_mapcorrorfull_int;


WITH t1 AS (
		SELECT s0.maptarget, -- LOINC Measurement code
			s0.tuples [1] AS sn_key, -- LOINC to SNOMED relationship_id identifier
			s0.tuples [2] AS sn_value -- related SNOMED Attribute
		FROM (
			SELECT ea.maptarget,
				STRING_TO_ARRAY(UNNEST(STRING_TO_ARRAY(SUBSTRING(ea.expression, devv5.instr(ea.expression, ':') + 1), ',')), '=') AS tuples
			FROM sources.scccrefset_expressionassociation_int ea
			) AS s0
		)
SELECT DISTINCT a.maptarget AS concept_code_1, -- LOINC Measurement code
                cs.concept_name as concept_name_1,
	c2.concept_code AS concept_code_2, -- SNOMED Attribute code
                c2.concept_name as concept_name_2,
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	CASE
		WHEN c1.concept_name IN (
				'Time aspect',
				'Process duration'
				)
			THEN 'Has time aspect'
		WHEN c1.concept_name IN (
				'Component',
				'Process output'
				)
			THEN 'Has component'
		WHEN c1.concept_name = 'Direct site'
			THEN 'Has dir proc site'
		WHEN c1.concept_name = 'Inheres in'
			THEN 'Inheres in'
		WHEN c1.concept_name = 'Property type'
			THEN 'Has property'
		WHEN c1.concept_name = 'Scale type'
			THEN 'Has scale type'
		WHEN c1.concept_name = 'Technique'
			THEN 'Has technique'
		WHEN c1.concept_name = 'Precondition'
			THEN 'Has precondition'
		END AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM t1 a
JOIN concept_stage cs ON cs.concept_code = a.maptarget -- LOINC Lab test
	AND cs.invalid_reason IS NULL
	AND cs.vocabulary_id = 'LOINC'
JOIN concept c1 ON c1.concept_code = a.sn_key -- LOINC to SNOMED relationship_id identifier
	AND c1.vocabulary_id = 'SNOMED'
	AND c1.concept_name IN (
		'Time aspect',
		'Process duration',
		'Component',
		'Process output',
		'Direct site',
		'Inheres in',
		'Property type',
		'Scale type',
		'Technique',
		'Precondition'
		)
JOIN concept c2 ON c2.concept_code = a.sn_value -- SNOMED Attribute
	AND c2.vocabulary_id = 'SNOMED'
	AND (
		c2.invalid_reason IS NULL
		OR c2.concept_code = '41598000'
		) --Estrogen. This concept is invalid, but is used as component
JOIN vocabulary v ON cs.vocabulary_id = v.vocabulary_id;


select *
FROM sources.scccrefset_expressionassociation_int;*/


select * from sources.loinc_part
where partnumber not in (select partnumber from sources.loinc_partlink_primary)
and partnumber not in (select partnumber from sources.loinc_partlink_supplementary);


select * from sources.loinc_partlink_primary limit 1;

select distinct parttypename from sources.loinc_part;


select distinct partnumber, partname, parttypename, linktypename
from sources.loinc_partlink_primary;

select distinct partnumber, partname, parttypename, linktypename
from sources.loinc_partlink_supplementary;


select distinct p.partnumber, p.partname, p.parttypename, p.linktypename
from sources.loinc_partlink_primary p
    except
select distinct s.partnumber, s.partname, s.parttypename, s.linktypename
from sources.loinc_partlink_supplementary s;

select distinct p.partnumber, p.partname, p.parttypename
from sources.loinc_partlink_primary p
    except
select distinct s.partnumber, s.partname, s.parttypename
from sources.loinc_partlink_supplementary s;

select distinct s.partnumber, s.partname, s.parttypename
from sources.loinc_partlink_supplementary s
except
select distinct p.partnumber, p.partname, p.parttypename
from sources.loinc_partlink_primary p;


with tab as (select distinct s.partnumber, s.partname, s.parttypename
from sources.loinc_partlink_supplementary s
union
select distinct p.partnumber, p.partname, p.parttypename
from sources.loinc_partlink_primary p)

select count(*)
from tab
where partnumber NOT IN (select partnumber
                        from sources.loinc_partlink_primary)
and partnumber IN (select partnumber
                        from sources.loinc_partlink_supplementary
    where linktypename = 'DetailedModel');


select distinct p.partnumber, p.partname, p.parttypename, p.linktypename
from sources.loinc_partlink_primary p
where (p.partnumber, p.partname, p.parttypename) IN (select partnumber, partname, parttypename
    from sources.loinc_partlink_supplementary)
and (p.partnumber, p.partname, p.parttypename, p.linktypename) NOT IN (select partnumber, partname, parttypename, linktypename
    from sources.loinc_partlink_supplementary);

select distinct linktypename from sources.loinc_partlink_supplementary;
select distinct linktypename from sources.loinc_partlink_primary;

select distinct loinc_code
from snomed_loinc_mapping_from_ody
where snomed_attr_name is not null;


--to many
select *
from snomed_loinc_mapping_from_ody
where snomed_attr_name is not null
/*and loinc_code in (select loinc_code
from snomed_loinc_mapping_from_ody group by loinc_code having count(*) > 1)*/;
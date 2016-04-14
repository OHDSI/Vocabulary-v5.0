-- Todo:
-- drug_strength
-- Brands
-- mapping Ingredients
-- mapping Forms
-- mapping units

-- 1. Update latest_update field to new date 
/*
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
*/
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20160325','yyyymmdd'), vocabulary_version='dm+d Version 3.2.0' WHERE vocabulary_id='dm+d'; 
COMMIT;

-- 2. Create drug_concept_stage

drop table drug_concept_stage;
CREATE TABLE drug_concept_stage NOLOGGING AS SELECT * FROM concept_stage WHERE 1=0;
ALTER TABLE drug_concept_stage ADD insert_id NUMBER;   
INSERT /*+ APPEND */
      INTO  drug_concept_stage (concept_id,
                               concept_name,
                               domain_id,
                               vocabulary_id,
                               concept_class_id,
                               standard_concept,
                               concept_code,
                               valid_start_date,
                               valid_end_date,
                               invalid_reason,
                               insert_id)
   --Forms
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Dose Form' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), '1970-01-01'), 'YYYY-MM-DD') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason,
          3 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/FORM/INFO'))) t
   UNION ALL
   --deprecated Forms
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Dose Form' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          NVL(TO_DATE (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), 'YYYY-MM-DD') - 1, (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')) AS valid_end_date,
          'U' AS invalid_reason,
          4 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/FORM/INFO'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
  UNION ALL
   --Ingredients
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'ING/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Ingredient' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'ING/ISID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'ING/ISIDDT'), '1970-01-01'), 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'ING/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'ING/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          7 AS insert_id
     FROM f_ingredient2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('INGREDIENT_SUBSTANCES/ING'))) t
   UNION ALL
   --deprecated Ingredients
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'ING/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Ingredient' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'ING/ISIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          NVL(TO_DATE (EXTRACTVALUE (VALUE (t), 'ING/ISIDDT'), 'YYYY-MM-DD') - 1, (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')) AS valid_end_date,
          'U' AS invalid_reason,
          8 AS insert_id
     FROM f_ingredient2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('INGREDIENT_SUBSTANCES/ING'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'ING/ISIDPREV') IS NOT NULL
   UNION ALL
   --VTMs (Ingredients)
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VTM/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Ingredient' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VTM/VTMID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'VTM/VTMIDDT'), '1970-01-01'), 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VTM/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VTM/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          9 AS insert_id
     FROM f_vtm2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
   UNION ALL
   --deprecated VTMs
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VTM/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Ingredient' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VTM/VTMIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          NVL(TO_DATE (EXTRACTVALUE (VALUE (t), 'VTM/VTMIDDT'), 'YYYY-MM-DD') - 1, (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')) AS valid_end_date,
          'U' AS invalid_reason,
          10 AS insert_id
     FROM f_vtm2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'VTM/VTMIDPREV') IS NOT NULL
   UNION ALL
   --VMPs (generic or clinical drugs)
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VMP/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Clinical Drug' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMP/VPID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'VMP/VTMIDDT'), '1970-01-01'), 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          11 AS insert_id
     FROM f_vmp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
   UNION ALL
   --deprecated VMPs
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VMP/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Clinical Drug' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMP/VPIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          NVL(TO_DATE (EXTRACTVALUE (VALUE (t), 'VMP/VPIDDT'), 'YYYY-MM-DD') - 1, (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')) AS valid_end_date,
          'U' AS invalid_reason,
          12 AS insert_id
     FROM f_vmp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'VMP/VPIDPREV') IS NOT NULL
   UNION ALL
   -- AMPs (branded drugs)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'AMP/DESC'), 1, 255)
             AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Branded Drug' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'AMP/APID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'AMP/NMDT'), '1970-01-01'),
                   'YYYY-MM-DD')
             AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          13 AS insert_id
     FROM f_amp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t
   UNION ALL
   --VMPPs (clinical packs)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'VMPP/NM'), 1, 255)
             AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Clinical Pack' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMPP/VPPID') AS concept_code,
          TO_DATE ('1970-01-01', 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMPP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMPP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          14 AS insert_id
     FROM f_vmpp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT (
                   'VIRTUAL_MED_PRODUCT_PACK/VMPPS/VMPP'))) t
   UNION ALL
   --AMPPs (branded packs)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'AMPP/NM'), 1, 255)
             AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Branded Pack' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'AMPP/APPID') AS concept_code,
          TO_DATE ('1970-01-01', 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMPP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMPP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          15 AS insert_id
     FROM f_ampp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT (
                   'ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP'))) t;
COMMIT;                   
                   
-- Delete duplicates, first of all concepts with invalid_reason='D', then 'U', last of all 'NULL'
DELETE FROM drug_concept_stage
  WHERE ROWID NOT IN (SELECT LAST_VALUE (ROWID) OVER (PARTITION BY concept_code ORDER BY invalid_reason, ROWID ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
FROM drug_concept_stage);                   
COMMIT;    

-- Delete all concepts that exists in SNOMED with concept_class_id = 'Physical Object'. They are devices, not drugs
DELETE FROM drug_concept_stage d
WHERE EXISTS (
  SELECT 1
  FROM concept c
  WHERE c.concept_code = d.concept_code
     AND c.vocabulary_id = 'SNOMED'
     AND c.concept_class_id = 'Physical Object'
);
COMMIT;					   

-- Remove all the drugs that have no entry in f_vmp2 or f_amp2. They are devices
delete from drug_concept_stage where concept_code in (
  select concept_code from drug_concept_stage where concept_class_id like 'Branded%' or concept_class_id like 'Clinical%'
minus
  select apid from f_amp2_ex
minus 
  select vpid from f_vmp2_ex
);

-- Remove combination 
-- !!!! Check whether the singletons all exist and whether they aer mapped
delete from drug_concept_stage where concept_name like '% + %' and concept_class_id='Ingredient';

-- Remove duplicate Ingredients
  select 
    i.concept_code, i.concept_name, 
    ins.concept_code, ins.concept_name
  from drug_concept_stage i
  join devv5.concept s1 on s1.vocabulary_id='SNOMED' and s1.concept_code=i.concept_code
  join devv5.concept_relationship r on r.concept_id_1=s1.concept_id and r.invalid_reason is null and r.relationship_id in ('Subsumes', 'Active ing of')
  join devv5.concept s2 on s2.concept_id=r.concept_id_2 and s2.vocabulary_id='SNOMED' 
  join drug_concept_stage ins on ins.concept_code=s2.concept_code and ins.concept_class_id='Ingredient'
  where i.concept_class_id='Ingredient'
union
  select 
    i.concept_code, i.concept_name, 
    ins.concept_code, ins.concept_name
  from drug_concept_stage i
  join devv5.concept s1 on s1.vocabulary_id='SNOMED' and s1.concept_code=i.concept_code
  join devv5.concept s2 on instr(lower(s2.concept_name), lower(s1.concept_name))>0 and s2.vocabulary_id='SNOMED' and s1.concept_name!=s2.concept_name
  join drug_concept_stage ins on ins.concept_code=s2.concept_code and ins.concept_class_id='Ingredient'
  where i.concept_class_id='Ingredient'
;







create index x_drug_concept_stage on drug_concept_stage(concept_code);

-- 2. Create internal relationships
-- From SNOMED
truncate table internal_relationship_stage;
insert into internal_relationship_stage
with ds as (
  select d.concept_code, s.concept_id
  from drug_concept_stage d
  join devv5.concept s on s.vocabulary_id='SNOMED' and s.concept_code=d.concept_code
)
select distinct
  c1.concept_code as concept_code_1, 'dm+d' as vocabulary_id_1,
  c2.concept_code as concept_code_2, 'dm+d' as vocabulary_id_2
from ds c1
join devv5.concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null
join ds c2 on c2.concept_id=r.concept_id_2
join drug_concept_stage d on d.concept_code=c1.concept_code and (d.concept_class_id like 'Clinical%' or d.concept_class_id='Branded%')
;

commit;

-- 3. Create relationships to RxNorm
-- Ingredients

insert into relationship_to_concept;
select count(distinct concept_code_1) from (
select concept_code_1, vocabulary_id_1, concept_id_2, 
  row_number() over (partition by concept_code_1 order by 1) as precedence,
  null as conversion_factor
from (
  select distinct
    dmd.concept_code as concept_code_1, dmd.vocabulary_id as vocabulary_id_1,
    rxn.concept_id as concept_id_2
  from drug_concept_stage dmd
  join devv5.concept s on s.vocabulary_id='SNOMED' and s.concept_code=dmd.concept_code
  join devv5.concept_relationship r on r.concept_id_1=s.concept_id and r.invalid_reason is null
  join devv5.concept rxn on rxn.concept_id=r.concept_id_2 and rxn.vocabulary_id='RxNorm' and rxn.concept_class_id='Ingredient' and rxn.standard_concept='S'
  where dmd.concept_class_id='Ingredient'
union
-- Take 2 jumps
  select distinct
    dmd.concept_code as concept_code_1, dmd.vocabulary_id as vocabulary_id_1,
    rxn.concept_id as concept_id_2
  from drug_concept_stage dmd
  join devv5.concept s on s.vocabulary_id='SNOMED' and s.concept_code=dmd.concept_code
  join devv5.concept_relationship r on r.concept_id_1=s.concept_id and r.invalid_reason is null
-- if the resulting RxConcept is not a standard RxNorm ingredient, but instead a precise ingredient, a 'U' concept, a Brand Name, an NDFRT code , 
  join devv5.concept_relationship rp on rp.concept_id_1=r.concept_id_2 and rp.invalid_reason is null and rp.relationship_id in ('Form of', 'Concept replaced by', 'Brand name of', 'NDFRT - RxNorm eq')
  join devv5.concept rxn on rxn.concept_id=rp.concept_id_2 and rxn.vocabulary_id='RxNorm' and rxn.concept_class_id='Ingredient'
  where dmd.concept_class_id='Ingredient'
)
);

  select distinct
dmd.concept_name, rxn.concept_name,
    dmd.concept_code as concept_code_1, dmd.vocabulary_id as vocabulary_id_1,
    rxn.concept_id as concept_id_2
;
select dmd.concept_name, s.concept_name, rxn.concept_name 
  from drug_concept_stage dmd
  join internal_relationship_stage di on di.concept_code_2=dmd.concept_code
-- limit to onesie drugs only
  join (
    select concept_code_1 from internal_relationship_stage join drug_concept_stage on concept_code_2=concept_code and concept_class_id='Ingredient' group by concept_code_1 having count(8)=1
  ) onesie on onesie.concept_code_1=di.concept_code_1
  join devv5.concept s on s.vocabulary_id='SNOMED' and s.concept_code=di.concept_code_1
left  join devv5.concept_relationship r on r.concept_id_1=s.concept_id and r.invalid_reason is null and r.relationship_id in ('SNOMED - ATC eq')
left  join devv5.concept rxn on rxn.concept_id=r.concept_id_2 and rxn.vocabulary_id='ATC' -- and rxn.concept_class_id='Ingredient'
  where dmd.concept_class_id='Ingredient'
;
select * from drug_concept_stage where concept_class_id='Ingredient';
select * from internal_relationship_stage join drug_concept_stage on concept_code_2=concept_code where concept_code_1='324880001';
select *
from internal_relationship_stage di 
join drug_concept_stage d on d.concept_code=di.concept_code_1
join drug_concept_stage i on i.concept_code=di.concept_code_2 and i.concept_class_id='Ingredient'
join (
  select concept_code_1 from internal_relationship_stage join drug_concept_stage on concept_code_2=concept_code and concept_class_id='Ingredient' group by concept_code_1 having count(8)=1
) onesie on onesie.concept_code_1=di.concept_code_1
;
--choose the closest by hierarchy concept --how will "first value" work with duplicates??
create table anc_lev as
select c.concept_id, min (a.MAX_LEVELS_OF_SEPARATION) S_level from concept c
join concept_relationship r on concept_id = concept_id_1 and relationship_id='Maps to'
join concept_ancestor a on a.DESCENDANT_CONCEPT_ID = r.concept_id_2 
join concept cr on a.ANCESTOR_CONCEPT_ID = cr.concept_id

where cr.vocabulary_id in ('RxNorm' , 'RxNorm Extension') and cr.invalid_reason is null 
and r.invalid_reason is null
and c.invalid_reason is null and c.vocabulary_id = 'GRR'
and cr.VALID_START_DATE < TO_DATE ('20161222', 'yyyymmdd')
group by c.concept_id
;
create table rel_anc as
select c.concept_id as s_c_1, cr.concept_id, a.MAX_LEVELS_OF_SEPARATION S_level from concept c
join concept_relationship r on concept_id = concept_id_1 and relationship_id='Maps to'
join concept_ancestor a on a.DESCENDANT_CONCEPT_ID = r.concept_id_2 
join concept cr on a.ANCESTOR_CONCEPT_ID = cr.concept_id

where cr.vocabulary_id in ('RxNorm' , 'RxNorm Extension') and cr.invalid_reason is null 
and r.invalid_reason is null
and c.invalid_reason is null and c.vocabulary_id = 'GRR'
and cr.VALID_START_DATE < TO_DATE ('20161222', 'yyyymmdd')
;
--add codes
create table rel_fin as 
select a.* from rel_anc a join anc_lev b  on a.s_level = b.s_level and b.concept_id = a.s_c_1
;
drop table q_to_rn;
create table q_to_rn
 as 
 select c.concept_code as Q_DCODE,  f.concept_id as r_did
 from rel_fin f join concept c  on c.concept_id = s_c_1
;
--calculate weight
drop table cnc_rel_class;
create table cnc_rel_class as
select ri.*, ci.concept_class_id as concept_class_id_1 , c2.concept_class_id as concept_class_id_2 
from concept_relationSHIp ri 
join concept ci on ci.concept_id = ri.concept_id_1 
join concept c2 on c2.concept_id = ri.concept_id_2 
where ci.vocabulary_id like  'RxNorm%' and ri.invalid_reason is null and ci.invalid_reason is null 
and  c2.vocabulary_id like 'RxNorm%'  and c2.invalid_reason is null 
;
--define order as combination of attributes number and each attribute weight
drop table attrib_cnt; 
create table attrib_cnt as
select concept_id_1, count (1)|| max(weight) as weight  from (
--need to go throught Drug Form / Component to get the Brand Name
select distinct concept_id_1, 3 as weight from 
r_bn
union ALL
select concept_id_1, 1 from cnc_rel_class where concept_class_id_2 in ('Supplier')
union ALL
select concept_id_1, 5 from cnc_rel_class where concept_class_id_2 in ('Dose Form')
union ALL
select distinct drug_concept_id, 6 from (
select * from drug_strength where nvl (numerator_value, amount_value) is not null)
--remove comments when Box_size will be present 
union
select distinct drug_concept_id, 2 from  (
select * from drug_strength where Box_size is not null)
union ALL
select distinct drug_concept_id, 4 from  (
select * from drug_strength where DENOMINATOR_VALUE is not null)
) group by concept_id_1
union
select concept_id , '0' from concept where concept_class_id ='Ingredient' and vocabulary_id like 'RxNorm%'
;
--duplicates analysis
--drop table Q_DCODE_to_hlc
create table Q_DCODE_to_hlc as
select q.Q_DCODE from q_to_rn q join concept c on concept_id = q.R_DID where ( CONCEPT_CLASS_ID in 
('Branded Drug Box', 'Quant Branded Box', 'Quant Branded Drug', 'Branded Drug', 'Marketed Product', 'Branded Pack', 'Clinical Pack' , 
'Clinical Drug Box', 'Quant Clinical Box', 'Clinical Branded Drug',  'Clinical Drug', 'Marketed Product')
or concept_name like '% / %' ) and c.standard_concept = 'S' 
;
--drop table dupl;
create table dupl as(
select st.*, c.concept_class_id,attrib_cnt.*  from q_to_rn q join attrib_cnt on r_did  = concept_id_1 
join drug_concept_stage ds on Q_DCODE = ds.concept_code
join concept c on c.concept_id = q.R_DID 
join (select drug_concept_code, count (1) as cnt from ds_stage group by drug_concept_code having count(1) >1)st on drug_concept_code = Q_DCODE 
where Q_DCODE not in (select Q_DCODE from Q_DCODE_to_hlc)
)
;
 --best map
drop table best_map;
create table best_map as 
select distinct  first_value(concept_id_1) over (partition by q_dcode order by weight desc) as r_did , q_dcode
from attrib_cnt join q_to_rn on r_did  = concept_id_1 
where Q_DCODE not in ( select drug_concept_code from dupl)
union select CONCEPT_ID_1, drug_concept_code from dupl where WEIGHT = 0
;
--before generic update was run (not a perfect idea because we can't make the whole script in the devv5 but only copying stage tables)
--run ancestor on the data get with RxE builder
exec devv5.psmallconceptancestor
;
--r_bn
create table r_bn nologging as
select r.concept_id_1 as concept_id, r.concept_id_2 as bn_id from concept_relationship r
join concept d on d.concept_id=r.concept_id_1 and d.vocabulary_id in ('RxNorm', 'RxNorm Extension') and d.standard_concept='S'
join concept f on f.concept_id=r.concept_id_2 and f.concept_class_id ='Brand Name' and f.invalid_reason is null
where r.invalid_reason is null and r.relationship_id='Has brand name'
;
--choose the closest by hierarchy concept --how will "first value" work with duplicates??
drop table anc_lev;
create table anc_lev as
select c.concept_id, min (a.MAX_LEVELS_OF_SEPARATION) S_level from concept c
join concept_relationship r on concept_id = concept_id_1 and relationship_id='Maps to'
join concept_ancestor a on a.DESCENDANT_CONCEPT_ID = r.concept_id_2 
join concept cr on a.ANCESTOR_CONCEPT_ID = cr.concept_id

where cr.vocabulary_id in ('RxNorm' , 'RxNorm Extension') and cr.invalid_reason is null 
and r.invalid_reason is null
and c.invalid_reason is null and c.vocabulary_id = (select vocabulary_id from drug_concept_stage where rownum=1)
and cr.VALID_START_DATE <  (SELECT latest_update FROM vocabulary_conversion WHERE vocabulary_id_v5=(select vocabulary_id from drug_concept_stage where rownum=1)) --exclude RxNorm concepts made in this release --not a problem because in dev_vocab schema there will be no other vocabularies updated
group by c.concept_id
;
drop table rel_anc;
create table rel_anc as
select c.concept_id as s_c_1, cr.concept_id, a.MAX_LEVELS_OF_SEPARATION S_level from concept c
join concept_relationship r on concept_id = concept_id_1 and relationship_id='Maps to'
join concept_ancestor a on a.DESCENDANT_CONCEPT_ID = r.concept_id_2 
join concept cr on a.ANCESTOR_CONCEPT_ID = cr.concept_id

where cr.vocabulary_id in ('RxNorm' , 'RxNorm Extension') and cr.invalid_reason is null 
and r.invalid_reason is null
and c.invalid_reason is null and c.vocabulary_id = (select vocabulary_id from drug_concept_stage where rownum=1)
and cr.VALID_START_DATE <  (SELECT latest_update FROM vocabulary_conversion WHERE vocabulary_id_v5=(select vocabulary_id from drug_concept_stage where rownum=1)) --exclude RxNorm concepts made in this release --not a problem because in dev_vocab schema there will be no other vocabularies updated
;
--add codes
drop table rel_fin;
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
select concept_id, count (1)|| max(weight) as weight  from (
--need to go throught Drug Form / Component to get the Brand Name
select distinct concept_id, 3 as weight from 
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
) group by concept_id
union
select concept_id , '0' from concept where concept_class_id ='Ingredient' and vocabulary_id like 'RxNorm%'
;
--duplicates analysis
drop table Q_DCODE_to_hlc;
create table Q_DCODE_to_hlc as
select q.Q_DCODE from q_to_rn q join concept c on concept_id = q.R_DID where ( CONCEPT_CLASS_ID in 
('Branded Drug Box', 'Quant Branded Box', 'Quant Branded Drug', 'Branded Drug', 'Marketed Product', 'Branded Pack', 'Clinical Pack' , 
'Clinical Drug Box', 'Quant Clinical Box', 'Clinical Branded Drug',  'Clinical Drug', 'Marketed Product')
or concept_name like '% / %' ) and c.standard_concept = 'S' 
;
drop table dupl;
create table dupl as(
select st.*, c.concept_class_id,attrib_cnt.*  from q_to_rn q join attrib_cnt on r_did  = concept_id 
join drug_concept_stage ds on Q_DCODE = ds.concept_code
join concept c on c.concept_id = q.R_DID 
join (select drug_concept_code, count (1) as cnt from ds_stage group by drug_concept_code having count(1) >1)st on drug_concept_code = Q_DCODE 
where Q_DCODE not in (select Q_DCODE from Q_DCODE_to_hlc)
)
;
 --best map
drop table best_map;
create table best_map as 
select distinct  first_value(concept_id) over (partition by q_dcode order by weight desc) as r_did , q_dcode
from attrib_cnt join q_to_rn on r_did  = concept_id
where Q_DCODE not in ( select drug_concept_code from dupl)
union select CONCEPT_ID, drug_concept_code from dupl where WEIGHT = 0
;
--postprocessing with all excess information removal
--still a question - should we keep all the Attributes for local vocabularies
--convention made for now - not to keep, so the query looks like this:
-- all the newly generated concepts should be removed 
--devices already added in RxE builder
delete from concept_stage where concept_code like '%OMOP%' 
;
--make devices standard
update concept_stage set standard_concept = 'S' where domain_id = 'Device'
;
commit
;
--only mappings (results of "best_map") should exist in concept_relationship_stage
truncate table concept_relationship_stage
;
-- Write concept_relationship_stage
truncate table concept_relationship_stage;
insert /*+ APPEND */ into concept_relationship_stage
						(concept_code_1,
						concept_code_2,
						vocabulary_id_1,
						vocabulary_id_2,
						relationship_id,
						valid_start_date,
						valid_end_date,
						invalid_reason)
select 
  q_dcode as concept_code_1,
  c.concept_code as concept_code_2,  
  (select vocabulary_id from drug_concept_stage where rownum=1) as vocabulary_id_1,
  c.vocabulary_id as vocabulary_id_2,
  'Maps to' as relationship_id,
  (SELECT latest_update FROM vocabulary_conversion WHERE vocabulary_id_v5=(select vocabulary_id from drug_concept_stage where rownum=1)) as valid_start_date,
  TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
  null as invalid_reason
from best_map m
join concept c on c.concept_id=m.r_did and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
;
commit
;
--add mapping of Devices to itself (do we have it in RxE build?)
insert /*+ APPEND */ into concept_relationship_stage
						(concept_code_1,
						concept_code_2,
						vocabulary_id_1,
						vocabulary_id_2,
						relationship_id,
						valid_start_date,
						valid_end_date,
						invalid_reason)
select 
  concept_code as concept_code_1,
  concept_code as concept_code_2,  
  (select vocabulary_id from drug_concept_stage where rownum=1) as vocabulary_id_1,
   (select vocabulary_id from drug_concept_stage where rownum=1)  as vocabulary_id_2,
  'Maps to' as relationship_id,
  (SELECT latest_update FROM vocabulary_conversion WHERE vocabulary_id_v5=(select vocabulary_id from drug_concept_stage where rownum=1)) as valid_start_date,
  TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
  null as invalid_reason
from concept_stage  where domain_id ='Device'
;
commit
;
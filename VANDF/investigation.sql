-- source table
create table dev_vsavitskaya.vandf_source (
class_id text,
preferred_label text,
synonyms text,
definitions text,
obsolete text,
cui varchar(255),
semantic_type text,
parents text,
dcsa text,
ddf text,
drug_class_type text,
exclude_di_check text,
has_ingredient text,
ingredient_of text,
inverse_of_isa text,
isa text,
ndc text,
ndf_transmit_to_cmop text,
nf_name text,
nfi text,
parent_class text,
Semantic_type_UMLS_property text,
SNGL_OR_MULT_SRC_PRD text,
VA_class_name text,
VA_dispense_unit text,
VA_generic_name text,
vac text,
vmo text
);


-- table with name comparison between VANDF and RxNorm
create temp table vandf_rx as
select c.concept_id as vandf_id, c.concept_name as vandf_name, c2.concept_id as rx_id, c2.concept_name as rx_name, c2.concept_class_id from concept_stage c
join concept_relationship cr on c.concept_id = cr.concept_id_1
join concept c2 on cr.concept_id_2 = c2.concept_id
where c.vocabulary_id = 'VANDF'
and cr.relationship_id = 'Maps to';


select *
from vandf_rx;


-- doses comparison for other drugs, except solutions with 'mcg' and '%'
select count(*), dose from (
select *, case when vandf_reg = RX_reg then 'true' else 'false' end as dose
from (
select regexp_replace(regexp_matches(vandf_name, '[0-9]?\.?[0-9]+[M]')::text, 'M', '')::varchar as vandf_reg, vandf_name,
       regexp_replace(regexp_replace(regexp_replace(regexp_matches(RX_name, '[0-9]?\.?[0-9]+ ?[M]')::text, 'M', ''), ' ', ''), '"', '', 'g')::varchar as RX_reg, rx_name from vandf_rx
where vandf_name!~*'.*[0-9]MG.*[0-9]\.?[0-9]?MG\/[0-9].*'
AND vandf_name!~*'.*[0-9]+.* [0-9]+.*'
and vandf_name!~*'.*[0-9]MG\/[0-9]+ML.*'
and vandf_name!~*'.*[0-9]MG\/[0-9]\.?[0-9]?.*'
and vandf_name!~*'mcg|%') g) gg
group by dose;


-- doses comparison for solutions with 'mcg'
select count(*), dose from (
select *, case when vandf_reg = RX_reg then 'true' else 'false' end as dose
from (
select ((regexp_replace(regexp_replace(regexp_matches(vandf_name, '[0-9]+')::varchar, '}', ''), '{', ''))::numeric/1000) as vandf_reg, vandf_name,
       (regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_matches(RX_name, '[0-9]?\.?[0-9]+ ?[M]')::text, 'M', ''), ' ', ''), '"', '', 'g')::varchar,'}', ''), '{', ''))::numeric as RX_reg, rx_name from vandf_rx
where vandf_name!~*'.*[0-9]MG.*[0-9]\.?[0-9]?MG\/[0-9].*'
AND vandf_name!~*'.*[0-9]+.* [0-9]+.*'
and vandf_name!~*'.*[0-9]MG\/[0-9]+ML.*'
and vandf_name~*'mcg') g) gg
group by dose;


-- doses comparison for solutions with '%'
select count(*), dose from (
select *, case when vandf_reg = RX_reg then 'true' else 'false' end as dose
from (
select (regexp_replace(regexp_replace(regexp_matches(vandf_name, '[0-9]\.?[0-9]?[0-9]?')::varchar, '{', ''), '}', ''))::numeric*10 as vandf_reg, vandf_name,
       (regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_matches(RX_name, '[0-9]?\.?[0-9]+ ?[M]')::text, 'M', ''), ' ', ''), '"', '', 'g')::varchar,'{', ''), '}', ''))::numeric as RX_reg, rx_name from vandf_rx
where vandf_name!~*'.*[0-9]MG.*[0-9]\.?[0-9]?MG\/[0-9].*'
AND vandf_name!~*'.*[0-9]+.* [0-9]+.*'
and vandf_name!~*'.*[0-9]MG\/[0-9]+ML.*'
and vandf_name!~*'.*[0-9]MG\/[0-9]\.?[0-9]?.*'
and vandf_name~*'%'
and rx_name~*'mg\/ml') g) gg
group by dose;


-- table, which shows duplicate concepts (by name) and their relationships in crs
create temp table analysiss as
select concept_id, concept_code, concept_name,
       concept_id_1, concept_id_2, relationship_id, checkk
from (
select * from (
select *, case when cr.relationship_id is null then 1 else 2 end as checkk
from devv5.concept c
left join devv5.concept_relationship cr on concept_id = concept_id_1
where concept_name in (
select concept_name from (
select *
from devv5.concept c
left join devv5.concept_relationship cr on concept_id = concept_id_1
where cr.invalid_reason is null
  and c.invalid_reason is null
and vocabulary_id = 'VANDF'
) g
group by 1
having count(1)>1)
and c.invalid_reason is null
and vocabulary_id = 'VANDF'
and cr.invalid_reason is null) gg) ggg
where concept_name in (
    select concept_name from (
                            select * from (
select *, case when cr.relationship_id is null then 1 else 2 end as checkk
from devv5.concept c
left join devv5.concept_relationship cr on concept_id = concept_id_1
where concept_name in (
select concept_name from (
select *
from devv5.concept c
left join devv5.concept_relationship cr on concept_id = concept_id_1
where cr.invalid_reason is null
  and c.invalid_reason is null
and vocabulary_id = 'VANDF'
) g
group by 1
having count(1)>1)
and c.invalid_reason is null
and vocabulary_id = 'VANDF'
and cr.invalid_reason is null
) g2
where checkk = 1) gg)
    ;


select *
from analysiss
left join devv5.concept c on analysiss.concept_id_2 = c.concept_id;
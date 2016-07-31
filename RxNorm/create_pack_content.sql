drop table pc purge;
create table pc as
select 
  pc.pack_id as pack_concept_id, 
  cont.concept_id as drug_concept_id, 
  pc.amount,
  cast(null as number) as box_size
from (
  select pack_id,
    regexp_substr(pack_name, '^[0-9]+') as amount,
    translate(regexp_substr(pack_name, '\([0-9]+ [A-Za-z]+\)'), 'a()', 'a') as quant,
    pack_name as drug
  from (
    select distinct
      pack_id,
      trim(regexp_substr(pack_name, '[^;]+', 1, levels.column_value)) as pack_name
    from (
      select
        pack.concept_id as pack_id, regexp_replace(replace(replace(nvl(r.str, pack.concept_name), ') / ', ';'), '{'), '\) } Pack( \[.+\])?') as pack_name
      from concept pack
      left join dev_rxnorm.rxnconso r on r.rxcui=pack.concept_code and r.sab='RXNORM' and r.tty like '%PCK'
      where pack.vocabulary_id='RxNorm' and pack.concept_class_id like '%Pack' and pack.invalid_reason is null
    ),
    table(cast(multiset(select level from dual connect by level <= length (regexp_replace(pack_name, '[^;]+')) + 1) as sys.OdciNumberList)) levels
  )
) pc
left join (
  select concept_id_1, concept_id_2, concept_id, concept_name
  from concept_relationship r join concept on concept_id=r.concept_id_2 
  where r.relationship_id='Contains' and r.invalid_reason is null
) cont on cont.concept_id_1=pc.pack_id and instr(pc.drug, cont.concept_name)>0
;
commit;

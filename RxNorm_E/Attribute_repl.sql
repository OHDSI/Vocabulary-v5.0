--Creating manual table with concept_code_1 representing attribute (Brand Name,Supplier, Dose Form) that you want to replace by another already existing one (concept_code_2)

insert into concept_relationship_stage
(CONCEPT_CODE_1,CONCEPT_CODE_2,VOCABULARY_ID_1,VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE)
select distinct
cr1.concept_code_2,cr2.concept_code_2,cr1.vocabulary_id_2,cr2.vocabulary_id_2,'Concept replaced by',cr1.valid_start_date,cr1.valid_end_date
from suppliers_to_repl s 
join concept_relationship_stage cr1 on s.concept_code_1=cr1.concept_code_1 and cr1.relationship_id='Source - RxNorm eq'
join concept_relationship_stage cr2 on s.concept_code_2=cr2.concept_code_1 and cr2.relationship_id='Source - RxNorm eq'
;
update concept_stage
set invalid_reason='U',valid_end_date=trunc(sysdate)
where concept_code in (
select cr1.concept_code_2 
from suppliers_to_repl s 
join concept_relationship_stage cr1 on s.concept_code_1=cr1.concept_code_1 and cr1.relationship_id='Source - RxNorm eq')
;

--create temporary table with old mappings and fresh concepts (after all 'Concept replaced by')
create table rxe_tmp_replaces nologging as
with
src_codes as (
    --get concepts and all their links, which targets to 'U'
    select crs.concept_code_2 as src_code, crs.vocabulary_id_2 as src_vocab, 
    cs.concept_code upd_code, cs.vocabulary_id upd_vocab, 
    cs.concept_class_id upd_class_id, 
    crs.relationship_id src_rel
    From concept_stage cs, concept_relationship_stage crs
    where cs.concept_code=crs.concept_code_1
    and cs.vocabulary_id=crs.vocabulary_id_2
    and cs.invalid_reason='U'
    and cs.vocabulary_id='RxNorm Extension'
    and crs.invalid_reason is null
    and crs.relationship_id not in ('Concept replaced by','Concept replaces')
),
fresh_codes as (
    --get all fresh concepts (with recursion until the last fresh)
    select connect_by_root concept_code_1 as upd_code,
    connect_by_root vocabulary_id_1 upd_vocab,
    concept_code_2 new_code,
    vocabulary_id_2 new_vocab
    from (
        select * from concept_relationship_stage crs
        where crs.relationship_id='Concept replaced by'
        and crs.invalid_reason is null
    ) 
    where connect_by_isleaf = 1
    connect by nocycle prior concept_code_2 = concept_code_1 and prior vocabulary_id_2 = vocabulary_id_1
)
select src.src_code, src.src_vocab, src.upd_code, src.upd_vocab, src.upd_class_id, src.src_rel, fr.new_code, fr.new_vocab
from src_codes src, fresh_codes fr
where src.upd_code=fr.upd_code
and src.upd_vocab=fr.upd_vocab
and not (src.src_vocab='RxNorm' and fr.new_vocab='RxNorm');

--deprecate old relationships
update concept_relationship_stage crs set crs.invalid_reason='D', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (crs.concept_code_2, crs.vocabulary_id_2, crs.concept_code_1, crs.vocabulary_id_1, crs.relationship_id) 
in (
    select r.src_code, r.src_vocab, r.upd_code, r.upd_vocab, r.src_rel from rxe_tmp_replaces r 
    where r.upd_class_id in ('Brand Name','Ingredient','Supplier','Dose Form')
);

--build new ones relationships or update existing
merge into concept_relationship_stage crs
using (
    select * from rxe_tmp_replaces r where 
    r.upd_class_id in ('Brand Name','Ingredient','Supplier','Dose Form')
) i
on (
    i.src_code=crs.concept_code_2
    and i.src_vocab=crs.vocabulary_id_2
    and i.new_code=crs.concept_code_1
    and i.new_vocab=crs.vocabulary_id_1
    and i.src_rel=crs.relationship_id
)
when matched then 
    update set crs.invalid_reason=null, crs.valid_end_date=to_date ('20991231', 'YYYYMMDD') where crs.invalid_reason is not null
when not matched then insert
(
    crs.concept_code_2,
    crs.vocabulary_id_2,
    crs.concept_code_1,
    crs.vocabulary_id_1,
    crs.relationship_id,
    crs.valid_start_date,
    crs.valid_end_date,
    crs.invalid_reason    
)
values
(
    i.src_code,
    i.src_vocab,
    i.new_code,
    i.new_vocab,
    i.src_rel,
    (SELECT latest_update FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'),
    to_date ('20991231', 'YYYYMMDD'),
    null  
);
commit;

--get duplicates for some reason 
delete from concept_relationship_stage a where exists (
  select 1 from  (
    select concept_code_1,concept_code_2,relationship_id, max(rowid) as rid from concept_relationship_stage group by concept_code_1,concept_code_2,relationship_id having count(1)>1
  ) x 
  where a.concept_code_1= x.concept_code_1 and a.concept_code_2=x.concept_code_2 and a.relationship_id=x.relationship_id and x.rid=a.rowid
);

drop table rxe_tmp_replaces;

--Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
/
COMMIT;

--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
/
COMMIT;

--Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
/
COMMIT;
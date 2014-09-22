-- insert into concept
select distinct
  1 /* seq_concept.nextval */ as concept_id,
  first_value(m.source_code_description) over (partition by m.source_vocabulary_id, m.source_code order by length(m.source_code_description) desc) as concept_name,
  case 
    when m.source_vocabulary_id=2 then -- Snomed
      case
        when substr(m.source_code, 1, 1)='V' then 'V code'
        when substr(m.source_code, 1, 1)='E' then 'E code'
        else 'Diagnosis code'
      end
    when m.source_vocabulary_id=9 then -- NDC
      case 
        when length(m.source_code)=11 then '11-digit NDC'
        when length(m.source_code)=9 then '9-digit NDC'
        else 'NDC'
      end
    when m.source_vocabulary_id=10 then v.vocabulary_code -- GPI
    when m.source_vocabulary_id=16 then v.vocabulary_code -- Multum
    when m.source_vocabulary_id=17 then -- Read
      case
        when m.target_vocabulary_id=0 then 'Condition'
        else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
          'Condition', 1, 'Observation', 2, 'Procedure', 3, 'Race', 4, 'Provider', 5, 'Device', 6, 'Drug', 7, 'Measurement', 8, 10))
      end 
    when m.source_vocabulary_id=18 then -- Oxmis
      case
        when m.target_vocabulary_id=0 then 'Condition'
        else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
          'Condition', 1, 'Procedure', 2, 'Observation', 3, 'Measurement', 4, 'Device', 5, 10))
      end 
    when m.source_vocabulary_id=28 then v.vocabulary_code -- VA Product
    when m.source_vocabulary_id=34 then  -- ICD-10-CM
      case
        when m.target_vocabulary_id=0 then 'Condition'
        else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
          'Condition', 1, 'Observation', 2, 'Procedure', 3, 10))
      end
    when m.source_vocabulary_id=35 then -- ICD-10-PCS
      case
        when m.target_vocabulary_id=0 then 'Procedure'
         else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
          'Procedure', 1, 10))
      end
    when m.source_vocabulary_id=46	then -- NLM Mesh
      case
        when m.target_vocabulary_id=0 then 'Condition'
        else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
          'Condition', 1, 'Drug', 2, 'Procedure', 3, 'Measurement', 4, 'Observation', 5, 10))
      end 
    when m.source_vocabulary_id=50 then -- FDA SPL
      case
        when m.target_concept_id=0 then 'Drug'
        else c.concept_class
      end 
    when m.source_vocabulary_id=53 then --  FDB Genseqno
      case
        when m.target_concept_id=0 then 'Drug'
        else c.concept_class
      end 
    when m.source_vocabulary_id=56 then 'Drug'-- Gemscript
    else m.mapping_type end
  as class_code,
  v.vocabulary_code as vocabulary_code,
  m.source_code as concept_code,
  to_date('19700101', 'YYYYMMDD') as valid_start_date,
  to_date('20991231', 'YYYYMMDD') as valid_end_date,
  null as invalid_reason,
  null as standard_concept,
  null as domain_code
from dev.source_to_concept_map m
join vocabulary_id_to_code v on v.vocabulary_id=m.source_vocabulary_id
left join dev.concept c on c.concept_id=m.target_concept_id
where m.source_vocabulary_id=53 -- in (2, 9, 10, 16, 17, 18, 34, 35, 46, 50, 53, 56) -- vocabulary_id=10, 17 missing source_code_descriptions
;


-- insert into concept_relationship;
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_code,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_id_to_code v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_code=v1.vocabulary_code and src.concept_code=m.source_code
join concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
;
;
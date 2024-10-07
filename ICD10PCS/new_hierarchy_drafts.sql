-- Mapping ICD10PCS to SNOMED through concept_attributes:
with icd10pcs_split as (select concept_code, concept_name,
       split_part(concept_synonym_name, ' @ ', 3) as method,
       split_part(concept_synonym_name, ' @ ', 4) as procedure_site,
           split_part(concept_synonym_name, ' @ ', 5) as access,
           split_part(concept_synonym_name, ' @ ', 6) as device
    from devv5.concept_synonym s
    join devv5.concept c using(concept_id)
where c.concept_class_id = 'ICD10PCS'),


snomed_split as (select c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       regexp_replace(c2.concept_name, ' - action', '') as method,
       regexp_replace(c3.concept_name, ' structure', '') as procedure_site,
       regexp_replace(c4.concept_name, ' approach', '') as access,
       c5.concept_name as device
from concept c1
left join concept_relationship cr2 on c1.concept_id = cr2.concept_id_1 and cr2.relationship_id = 'Has method' and cr2.invalid_reason is null
left join concept_relationship cr3 on c1.concept_id = cr3.concept_id_1 and cr3.relationship_id in ('Has proc site', 'Has dir proc site') and cr3.invalid_reason is null
left join concept_relationship cr4 on c1.concept_id = cr4.concept_id_1 and cr4.relationship_id = 'Has access' and cr4.invalid_reason is null
left join concept_relationship cr5 on c1.concept_id = cr5.concept_id_1 and cr5.relationship_id in ('Using device', 'Has dir device') and cr5.invalid_reason is null
left join concept c2 on c2.concept_id = cr2.concept_id_2
left join concept c3 on c3.concept_id = cr3.concept_id_2
left join concept c4 on c4.concept_id = cr4.concept_id_2
left join concept c5 on c5.concept_id = cr5.concept_id_2
where c1.vocabulary_id = 'SNOMED'
and c1.standard_concept = 'S'
and c1.domain_id = 'Procedure'
)

select distinct i.concept_code,
       i.concept_name,
       s.concept_code as target_code,
       s.concept_name as target_name,
       devv5.similarity(i.concept_name, s.concept_name) as similarity
from icd10pcs_split i
join snomed_split s on lower(i.method) = lower(s.method) and
                       lower(i.procedure_site) = lower(s.procedure_site); /*and
                       lower(i.access) = lower (s.access) /*or
                       lower(i.device) = lower (s.device))*/
order by i.concept_code,similarity desc;
; and
                       (lower(i.access) = lower (s.access) or
                       lower(i.device) = lower (s.device));*/


-- Mapping of ICD10PCS codes to SNOMED using UMLS CCSR_ICD10PCS classification:
--- We can map the rest of CCSR_ICD10PCS to SNOMED and join to this table
with a as (select m.code  as icd_code,
                  m.str   as icd_name,
                  m1.cui,
                  m1.code as intermediate_code,
                  m1.str  as intermediate_name
           from sources.mrrel r
                    join sources.mrconso m on m.aui = r.aui2
                    join sources.mrconso m1 on m1.aui = r.aui1
           where m.sab = 'ICD10PCS'
             and m1.sab = 'CCSR_ICD10PCS'
             and m.tty in ('PT')
),

s as (
    select * from sources.mrconso
             where sab = 'SNOMEDCT_US'
             and tty = 'PT'
)

select  icd_code,
        icd_name,
        intermediate_code,
        intermediate_name,
       s.code as snomed_code,
       s.str as snomed_name
from a
left join s on a.cui = s.cui;
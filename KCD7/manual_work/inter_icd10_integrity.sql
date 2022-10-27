--Run the ICD10
--Run and check ICD10CM
--1 Upload the refresh_lookup_done
--2 Run the script
--Compare number of rows in uploaded csv and script output
--Drop flagged rows from G-frive
--Manually asses Qualitu of Discr tagged mappings


--Detect codes with no mapping in ICD10
with no_map_by_icd10 as (SELECT distinct r.*,cc.*
FROM refresh_lookup_done r
left JOIN devv5.concept c
on trim(lower(r.icd_code)) = trim(lower(c.concept_code))
and c.vocabulary_id ='ICD10'
 LEFT  JOIN devv5.concept_relationship cr
                 on c.concept_id = cr.concept_id_1
                          and cr.relationship_id in ( 'Maps to','Maps to value')
                 and cr.invalid_reason is null
            left  JOIN devv5.concept cc
                  on cr.concept_id_2 = cc.concept_id
                      and cr.invalid_reason is null
                      and cr.relationship_id in ( 'Maps to','Maps to value')
where cc.concept_id is null)
,
to_be_dropped as (
    SELECT distinct b.id,
                    b.icd_code,
                    b.icd_name,
                    b.repl_by_relationship,
                    b.repl_by_id,
                    b.repl_by_code,
                    b.repl_by_name,
                    b.repl_by_domain,
                    b.repl_by_vocabulary,
                    case when a.icd_code is null then 'drop' else null end as flag -- drop rows where mapping will come from ICD10
    from no_map_by_icd10 a
             RIGHT JOIN refresh_lookup_done b
                        on a.id=b.id/*a.icd_code = b.icd_code
                            and a.repl_by_id = b.repl_by_id*/
)
,
discr as  (
SELECT distinct aa.*,
                case when aa.icd_code=r.icd_code and r.repl_by_id<>aa.repl_by_id and aa.repl_by_relationship=r.repl_by_relationship then 'discr' else null end as dicrep --detect rows where possible micctargeting occur (when code exists in several ICD10 like vocabs)
FROM to_be_dropped aa
LEFT JOIN dev_icd10cm.refresh_lookup_done r
ON aa.icd_code=r.icd_code
    and aa.repl_by_relationship=r.repl_by_relationship
order by aa.id)
SELECT id,
       icd_code,
       repl_by_id,
       flag,
       string_agg(distinct dicrep,'X') as dicrep,
       icd_name,
       repl_by_relationship,
       repl_by_id,
       repl_by_code,
       repl_by_name,
       repl_by_domain,
       repl_by_vocabulary


FROM discr
group by  id,
       icd_code,
       icd_name,
       repl_by_relationship,
       repl_by_id,
       repl_by_code,
       repl_by_name,
       repl_by_domain,
       repl_by_vocabulary,
       flag
order by id
;
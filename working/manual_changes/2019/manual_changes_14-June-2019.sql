--fix dates
update concept_relationship r set valid_start_date = to_date ('20190527', 'yyyymmdd')
where exists  (
select 1 from  concept a, concept b 
where b.concept_id = r.concept_id_2 and a.concept_id = r.concept_id_1 
and 'HemOnc' in (a.vocabulary_id, b.vocabulary_id)
) 
and r.valid_start_date = to_date ('20190127', 'yyyymmdd');

update concept set valid_start_date = to_date ('20190527', 'yyyymmdd') 
where valid_start_date = to_date ('20190127', 'yyyymmdd') 
and vocabulary_id ='HemOnc';

update concept set valid_start_date = to_date ('20190528', 'yyyymmdd') 
where valid_start_date = to_date ('20190128', 'yyyymmdd') 
and vocabulary_id ='HemOnc';

update concept set valid_start_date = to_date ('20190529', 'yyyymmdd') 
where valid_start_date = to_date ('20190129', 'yyyymmdd') 
and vocabulary_id ='HemOnc';
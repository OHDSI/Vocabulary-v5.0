--**********************
--**********QA**********
--**********************

--all the selects below should return null

select distinct crs.vocabulary_id_1, crs.vocabulary_id_2 from concept_relationship_stage crs
left join vocabulary v1 on v1.vocabulary_id=crs.vocabulary_id_1 and v1.latest_update is not null
left join vocabulary v2 on v2.vocabulary_id=crs.vocabulary_id_2 and v2.latest_update is not null
where coalesce(v1.latest_update, v2.latest_update) is null;


select distinct cs.vocabulary_id from concept_stage cs
left join vocabulary v on v.vocabulary_id=cs.vocabulary_id and v.latest_update is not null
where v.latest_update is null;


select * From concept_relationship_stage where valid_start_date is null or valid_end_date is null or (invalid_reason is null and valid_end_date<>to_date ('20991231', 'yyyymmdd'))
or (invalid_reason is not null and valid_end_date=to_date ('20991231', 'yyyymmdd'));


select * from concept_stage where valid_start_date is null or valid_end_date is null
or (invalid_reason is null and valid_end_date <> to_date ('20991231', 'yyyymmdd') and vocabulary_id not in ('CPT4', 'HCPCS', 'ICD9Proc'))
or (invalid_reason is not null and valid_end_date = to_date ('20991231', 'yyyymmdd'))
or valid_start_date < to_date ('19000101', 'yyyymmdd'); -- some concepts have a real date < 1970


select relationship_id from concept_relationship_stage
except
select relationship_id from relationship;


select concept_class_id from concept_stage
except
select concept_class_id from concept_class;


select domain_id from concept_stage
except
select domain_id from domain;


select vocabulary_id from concept_stage
except
select vocabulary_id from vocabulary;


select * from concept_stage where concept_name is null or domain_id is null or concept_class_id is null or concept_code is null or valid_start_date is null or valid_end_date is null
or valid_end_date is null or concept_name<>trim(concept_name) or concept_code<>trim(concept_code);

select concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  from concept_relationship_stage
group by concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id  having count(*)>1;

select concept_code, vocabulary_id  from concept_stage
group by concept_code, vocabulary_id  having count(*)>1;


select pack_concept_code, pack_vocabulary_id, drug_concept_code, drug_vocabulary_id, amount from pack_content_stage
group by pack_concept_code, pack_vocabulary_id, drug_concept_code, drug_vocabulary_id, amount
having count(*)>1;


select drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value From drug_strength_stage
group by drug_concept_code, vocabulary_id_1, ingredient_concept_code, vocabulary_id_2, amount_value
having count(*)>1;

SELECT crm.*
FROM concept_relationship_stage crm
	 LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
	 LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
	 LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
	 LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2 AND cs2.vocabulary_id = crm.vocabulary_id_2
	 LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
	 LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
	 LEFT JOIN relationship rl ON rl.relationship_id = crm.relationship_id
WHERE    (c1.concept_code IS NULL AND cs1.concept_code IS NULL)
	 OR (c2.concept_code IS NULL AND cs2.concept_code IS NULL)
	 OR v1.vocabulary_id IS NULL
	 OR v2.vocabulary_id IS NULL
	 OR rl.relationship_id IS NULL
	 OR crm.valid_start_date > CURRENT_DATE
	 OR crm.valid_end_date < crm.valid_start_date;



--GenericUpdate; devv5 - static variable
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

select * from QA_TESTS.GET_CHECKS();
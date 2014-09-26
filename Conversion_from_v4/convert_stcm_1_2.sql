--insert to concept from dev.concept  
insert into concept(
  CONCEPT_ID, 
	CONCEPT_NAME, 
	DOMAIN_CODE, 
	CLASS_CODE, 
	VOCABULARY_CODE, 
	STANDARD_CONCEPT, 
	CONCEPT_CODE, 
	VALID_START_DATE, 
	VALID_END_DATE, 
	INVALID_REASON) 
  select c.concept_id,
  c.concept_name, 
  d.domain_code, --
  cl.class_code,
  v.vocabulary_code,
  case when c.concept_level=0 then 'S' else null end as standard_concept,   
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
join dev.concept dc on dc.concept_id=r.concept_id_1
join domain d on d.domain_concept_id=dc.concept_id 
join vocabulary_id_to_code v on v.vocabulary_id=c.vocabulary_id
join class_old_to_new cl on cl.original=c.concept_class
;

commit;

--insert to concept_relationship from concept_relationship  
insert into concept_relationship(
CONCEPT_ID_1,
CONCEPT_ID_2,
RELATIONSHIP_CODE,
VALID_START_DATE,
VALID_END_DATE,
INVALID_REASON) 
  select c.concept_id_1,
  c.concept_id_2, 
  v.relationship_code, 
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept_relationship c
join relationship_id_to_code v on v.relationship_id=c.relationship_id
;

insert into concept_ancestor select * from dev.concept_ancestor;
--delete absent concept_id (which exist in dev.concept and don't in prototype.concept)


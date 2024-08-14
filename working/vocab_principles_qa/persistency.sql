-- All concepts previously added to the concept table are present in the current release:
--- This check should retrieve null
select *
from dev_dev.concept c1
where not exists (
       select 1
       from devv5.concept c2
       where c1.concept_id = c2.concept_id
);

-- All relationships previously added to the concept_relationship table are present in the current release:
--- This check should retrieve null
select *
from dev_dev.concept_relationship c1
where not exists (
       select 1
       from devv5.concept_relationship c2
       where (c1.concept_id_1, c1.concept_id_2, c1.relationship_id) = (c2.concept_id_1, c2.concept_id_2, c2.relationship_id)
);
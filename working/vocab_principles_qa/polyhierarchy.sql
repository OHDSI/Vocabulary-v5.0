--concepts changing their domains when going down the hierarchy
--place where change occurrs
select c.vocabulary_id as anc_vocabulary_id, c.domain_id as anc_domain_id, c.concept_class_id as anc_concept_class_id,
c2.vocabulary_id as desc_vocabulary_id, c2.domain_id as desc_domain_id , c2.concept_class_id as desc_concept_class_id, count(1)
from concept c
join concept_ancestor ca on c.concept_id = ca.ancestor_concept_id
join concept c2 on c2.concept_id = ca.descendant_concept_id
where ca.min_levels_of_separation in (0,1) -- some ATCs-RxNorm have min_levels_of_separation=0
and ca.ancestor_concept_id != ca.descendant_concept_id
and c.domain_id != c2.domain_id
group by c.vocabulary_id , c.domain_id , c.concept_class_id ,
c2.vocabulary_id , c2.domain_id , c2.concept_class_id
order by count(1) desc;

-- classifications without Standard descendants
--grouped
select c.domain_id,c.vocabulary_id, COUNT(1) from concept_ancestor ca
join concept c on ca.ancestor_concept_id = c.concept_id and c.standard_concept ='C'
left join concept c2 on c2.concept_id = ca.descendant_concept_id and c2.standard_concept ='S'
where c2.concept_id is null
GROUP BY c.domain_id,c.vocabulary_id
order by count(1) desc
;
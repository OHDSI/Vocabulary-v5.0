-- 1.These checks returns additional SNOMED-SNOMED relationships that are created due to the SNOMED Vet input in SNOMED hierarchy
--- Comparison of full ancestor in vet schema and manual ancestor for SNOMED, OMOP Extension, MedDRA, ICD9Proc (in a separate schema)
select distinct
       ca.descendant_concept_id,
       c2.concept_name,
       ca.ancestor_concept_id,
       c1.concept_name,
       min_levels_of_separation,
       max_levels_of_separation
from dev_veterinary.concept_ancestor ca
join dev_veterinary.concept c1 on c1.concept_id = ca.ancestor_concept_id and c1.vocabulary_id = 'SNOMED'
join dev_veterinary.concept c2 on c2.concept_id = ca.descendant_concept_id and c2.vocabulary_id = 'SNOMED'
where (ca.ancestor_concept_id, ca.descendant_concept_id) not in (
select ca1.ancestor_concept_id, ca1.descendant_concept_id
from dev_mkhitrun.concept_ancestor ca1
)
order by descendant_concept_id, min_levels_of_separation;

-- 2. This check reviews the cases where SNOMED Vet concepts is located between two SNOMED concepts on the concept_ancestor:
select distinct a.concept_id as ancestor_id,
               a.concept_code as ancestor_code,
               a.concept_name as ancestor_name,
               a.vocabulary_id as ancest_vocab,
      cc.concept_id as vet_id,
      cc.concept_name as vet_name,
      cc.vocabulary_id as vet_vocab,
      c.concept_id as descendant_id,
      c.concept_name as descendant_name,
      c.vocabulary_id as descendant_vocab
from dev_veterinary.concept_ancestor ca
join dev_veterinary.concept c on c.concept_id = ca.descendant_concept_id and c.vocabulary_id = 'SNOMED'
join dev_veterinary.concept cc on cc.concept_id = ca.ancestor_concept_id and cc.vocabulary_id = 'SNOMED Veterinary'
join dev_veterinary.concept_ancestor ca1 on ca1.descendant_concept_id = cc.concept_id
left join dev_veterinary.concept a on a.concept_id = ca1.ancestor_concept_id and a.vocabulary_id = 'SNOMED'
;


/************************************************
* 9. Populate relationship_to_concept *
************************************************/

-- 9.1 Forms
-- insert mapped forms back to aut_form_mapped
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',concept_id_2,precedence
from aut_form_mapped a
join drug_concept_stage dc on dc.concept_name = coalesce (a.new_name,a.concept_name)
where dc.concept_class_id = 'Dose Form'
and not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  dc.concept_code)
;
--9.2 Units
-- insert mapped forms back to aut_unit_mapped
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor
from aut_unit_mapped a
where not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  a.concept_code_1)
;
--9.3 Ingredients
--insert mappings back to aut_ingredient_mapped or aut_parsed_ingr (for ingredients that need parsing)
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',cast(concept_id_2 as int), precedence
from aut_ingredient_mapped a
join drug_concept_stage dc on dc.concept_name = a.concept_name and concept_class_id = 'Ingredient'
where not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  dc.concept_code)
;

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',concept_id_2, rank() over (partition by dc.concept_code order by concept_id_2)
from aut_parsed_ingr a
join drug_concept_stage dc
on lower(dc.concept_name) = lower(a.ing_name) and dc.concept_class_id = 'Ingredient'
where not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  dc.concept_code);

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',concept_id_2, rank() over (partition by dc.concept_code order by concept_id_2)
from aut_parsed_ingr a
join drug_concept_stage dc
on lower(dc.concept_name) = lower(a.concept_name) and dc.concept_class_id = 'Ingredient'
where not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  dc.concept_code);

-- 9.4 BN
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',cast(concept_id_2 as int), precedence
from aut_bn_mapped a
join drug_concept_stage dc on dc.concept_name = a.concept_name and concept_class_id = 'Brand Name'
where not exists (select 1 from relationship_to_concept rtc2 where rtc2.concept_code_1 =  dc.concept_code)
;

-- 9.5 Supplier
-- insert mappings back to aut_supplier_mapped
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct dc.concept_code,'JMDC',a.concept_id_2, rank() over (partition by dc.concept_code order by a.concept_id_2)
from aut_suppliers_mapped a
join drug_concept_stage dc on concept_name = concept_name
where a.concept_id is not null
and dc.concept_code not in (select concept_code_1 from relationship_to_concept);
drop table if exists rxn_info_sheet;
create table rxn_info_sheet as
with info_sheet as
(
--1. Concepts that have active distinctive relations to attributes that are no longer active;
--- Brand Names
	select
		'W' as info_level,
		'Branded concepts that have active relations to deprecated Brand Names' as description,
		count (c.concept_code) as err_cnt
	from concept_stage c
	join concept_relationship_stage r on
		c.domain_id = 'Drug' and
		c.standard_concept = 'S' and
		r.concept_code_1 = c.concept_code and
		r.vocabulary_id_1 = c.vocabulary_id and
		r.relationship_id = 'Has brand name' and
		r.invalid_reason is null
	join concept_stage c2 on
		(r.concept_code_2, r.vocabulary_id_2) = (c2.concept_code, c2.vocabulary_id) and
		c2.invalid_reason is not null
	--Check if concept has anoter active attribute of same type
	--May be caused by our mishandling of RxNorm: we need to Investigate why active relations to inactive attributes exist in the first place!
	left join concept_relationship_stage rc on
		rc.concept_code_1 = r.concept_code_1 and
		rc.relationship_id = 'Has brand name' and
		rc.invalid_reason is null and
		rc.concept_code_2 in
			(
				select concept_code
				from concept_stage
				where invalid_reason is null
			)
	where
		c.vocabulary_id = 'RxNorm' and
		rc.concept_code_1 is null

		union all

--- Dose Form
	select
		'W',
		'Formulated concepts that have active relations to deprecated Dose Forms' as description,
		count (c.concept_code) as err_cnt
	from concept c
	join concept_relationship_stage r on
		c.domain_id = 'Drug' and
		c.standard_concept = 'S' and
		r.concept_code_1 = c.concept_code and
		r.vocabulary_id_1 = c.vocabulary_id and
		r.relationship_id = 'RxNorm has dose form' and
		r.invalid_reason is null
	join concept_stage c2 on
		(r.concept_code_2, r.vocabulary_id_2) = (c2.concept_code, c2.vocabulary_id) and
		c2.invalid_reason is not null
	--Check if concept has anoter active attribute of same type
	--May be caused by our mishandling of RxNorm: we need to Investigate why active relations to inactive attributes exist in the first place!
	left join concept_relationship_stage rc on
		rc.concept_code_1 = r.concept_code_1 and
		rc.relationship_id = 'RxNorm has dose form' and
		rc.invalid_reason is null and
		rc.concept_code_2 in
			(
				select concept_code
				from concept_stage
				where invalid_reason is null
			)
	where
		c.vocabulary_id = 'RxNorm' and
		rc.concept_code_1 is null

			union all

--2. Broken drug_strength entries; concepts that omit specifying important units in denominator/numerator pairings etc.
	select
		'E',
		'Drug concepts with misformulated strength',
		count (drug_concept_code)
	from drug_strength_stage
	join concept_stage on
		vocabulary_id = 'RxNorm' and
		vocabulary_id_1 = 'RxNorm' and
		drug_concept_code = concept_code
	where
		(
			coalesce (amount_unit_concept_id, numerator_unit_concept_id) is not null and
			coalesce (amount_value, numerator_value) is null
		) or
		(
			numerator_value is not null and
			denominator_unit_concept_id is null and
			numerator_unit_concept_id != 8554 --%
		)

		union all

--3. Components that duplicate existing RxNorm components; RxNorm components may specify differing precise ingredients but be completely identical otherwise. Known to have broken RxE in the past.
	select
		'W',
		'Identical strength entries for clinical components',
		count (c.concept_code)
	from concept_stage c
	join drug_strength_stage d on
		d.drug_concept_code = c.concept_code and
		c.concept_class_id = 'Clinical Drug Comp' and
		c.standard_concept = 'S' and
		c.vocabulary_id = 'RxNorm'
	join drug_strength_stage d2 on
		d2.ingredient_concept_code = d.ingredient_concept_code and
		coalesce (d2.amount_value,d2.numerator_value) = coalesce (d.amount_value,d.numerator_value) and
		coalesce (d2.amount_unit_concept_id,d2.numerator_unit_concept_id) = coalesce (d.amount_unit_concept_id,d.numerator_unit_concept_id) and
		(
			coalesce (d.denominator_unit_concept_id,d2.denominator_unit_concept_id) is null or
			d.denominator_unit_concept_id = d2.denominator_unit_concept_id
		) and
		d.drug_concept_code != d2.drug_concept_code
	join concept_stage c2 on
		d2.drug_concept_code = c2.concept_code and
		c2.concept_class_id = 'Clinical Drug Comp' and
		c2.standard_concept = 'S' and
		c2.vocabulary_id = 'RxNorm' and
		c2.concept_code > c.concept_code

		union all

--4. Drug concepts have entries in drug_strength with precise ingredients as content targets. Usually arise when concepts change class from Ingredient to Precise Ingredient.
	select
		'E',
		'Drug concepts have entries in drug_strength with precise ingredients as content targets',
		count (c.concept_code)
	from drug_strength_stage d
	join concept_stage c on
		c.concept_code = d.ingredient_concept_code and
		c.vocabulary_id = d.vocabulary_id_2  and
		c.concept_class_id = 'Precise Ingredient' and
		d.vocabulary_id_1 = 'RxNorm'

		union all

--5. New concepts by class
	select
		'I',
		'New concepts by class: ' || c.concept_class_id,
		count (c.concept_code)
	from concept_stage c
	left join concept d using (vocabulary_id, concept_code)
	where 
		d.concept_id is null and
		c.invalid_reason is null and
		c.vocabulary_id = 'RxNorm'
	group by c.concept_class_id

		union all

--6. Deprecated concepts by class
	select
		'I',
		'Deprecated concepts by class: ' || c.concept_class_id,
		count (c.concept_code)
	from concept_stage c
	join concept d using (vocabulary_id, concept_code)
	where
		d.concept_id is null and
		c.invalid_reason = 'D' and
		d.invalid_reason is null and
		c.vocabulary_id = 'RxNorm'
	group by c.concept_class_id

		union all

--7. Updated concepts by class
	select
		'I',
		'Updated concepts by class: ' || c.concept_class_id,
		count (c.concept_code)
	from concept_stage c
	join concept d using (vocabulary_id, concept_code)
	where
		d.concept_id is null and
		c.invalid_reason = 'U' and
		d.invalid_reason is null and
		c.vocabulary_id = 'RxNorm'
	group by c.concept_class_id

		union all

--8. Present persistent relation between Ingredient and a Brand Name concept that are not encountered as a combination; may be erroneous or be caused by persistent valid relation to a deprecated concept.
	select
		'W',
		'Relation between Ingredient and a Brand Name is not supported by a standard branded component',
		count (c.concept_code)
	from concept_stage c
	join concept_relationship_stage r on
		(c.concept_code, c.vocabulary_id) = (r.concept_code_1, r.vocabulary_id_1) and
		c.standard_concept = 'S' and
		r.invalid_reason is null and
		c.concept_class_id = 'Ingredient' and
		c.vocabulary_id = 'RxNorm'
	join concept_stage b on
		(b.concept_code, b.vocabulary_id) = (r.concept_code_2, r.vocabulary_id_2) and
		b.concept_class_id = 'Brand Name' and
		b.vocabulary_id = 'RxNorm'
	where
		not exists
			(
				select
				from concept_stage x
				join concept_relationship_stage r1 on
					(x.concept_code, x.vocabulary_id) = (r1.concept_code_1, r1.vocabulary_id_1) and
					x.concept_class_id = 'Branded Drug Comp' and
					x.standard_concept = 'S' and
					(r1.concept_code_2, r1.vocabulary_id_2) = (c.concept_code, c.vocabulary_id) and
					r1.invalid_reason is not null
				join concept_relationship_stage r2 on
					(x.concept_code, x.vocabulary_id) = (r2.concept_code_1, r2.vocabulary_id_1) and
					(r2.concept_code_2, r2.vocabulary_id_2) = (b.concept_code, b.vocabulary_id) and
					r2.invalid_reason is not null
			)
			
		union all

--9. Usually shows Ingredients becoming precise Ingredients, possible vice versa. Known to have broken RxE in the past.
	select
		'I',
		'Concepts changed class: ' || s.concept_class_id || ' to '|| c.concept_class_id,
		count (s.concept_code)
	from concept_stage c
	join concept s on
		c.vocabulary_id = 'RxNorm' and
		s.vocabulary_id = 'RxNorm' and
		c.concept_code = s.concept_code and
		c.concept_class_id != s.concept_class_id
	group by c.concept_class_id, s.concept_class_id

		union all

	select
		'E',
		'Multiple instances of the same ingredient per drug',
		count (drug_concept_code)
	from drug_strength_stage
	where vocabulary_id_1 = 'RxNorm'
	group by drug_concept_code, ingredient_concept_code
	having count (ingredient_concept_code)> 1

		union all

--10. Known problems in basic tables that don't have corresponding entries in stage tables.
	select
		'W',
		'Errors in basic tables not adressed in current release: valid relations to invalid concepts',
		count (c.concept_id)
	from concept c
	join concept_relationship r on
		r.invalid_reason is null and
		c.concept_id = r.concept_id_1 and
		c.standard_concept = 'S' and
		c.vocabulary_id = 'RxNorm'
	join concept c2 on
		c2.concept_id = r.concept_id_2 and
		c2.invalid_reason is not null and
		c2.vocabulary_id = 'RxNorm'
	left join concept_relationship_stage s on
		(s.concept_code_1, s.vocabulary_id_1) = (c.concept_code, c.vocabulary_id) and
		(s.concept_code_2, s.vocabulary_id_2) = (c2.concept_code, c2.vocabulary_id) and
		r.relationship_id = s.relationship_id
	where
		r.relationship_id not in ('Concept replaces','Mapped from') and
		s.relationship_id is null

		union all

	select
		'W',
		'Errors in basic tables not adressed in current release: valid relations to invalid concepts (excluding having correct relationships of the same type)',
		count (c.concept_id)
	from concept c
	join concept_relationship r on
		r.invalid_reason is null and
		c.concept_id = r.concept_id_1 and
		c.standard_concept = 'S' and
		c.vocabulary_id = 'RxNorm' and
		c.concept_class_id in
		(
			'Clinical Drug Form',
			'Branded Drug',
			'Clinical Drug',
			'Quant Clinical Drug',
			'Quant Branded Drug',
			'Branded Drug Comp',
			'Branded Drug Form',
			'Clinical Drug Comp'
		) -- drug concept
	join concept c2 on
		c2.concept_id = r.concept_id_2 and
		c2.invalid_reason is not null and
		c2.vocabulary_id = 'RxNorm' and
		c2.concept_class_id in ('Ingredient','Brand Name','Dose Form') -- attribute concept
	--check for duplication
	left join concept_relationship r2 on
		r.concept_id_1 = r2.concept_id_1 and
		r2.invalid_reason is null and
		r2.relationship_id = r.relationship_id and
		r2.concept_id_2 != r.concept_id_2 and
		r2.concept_id_2 in (select concept_id from concept where invalid_reason is null)
	left join concept_relationship_stage s on
		(s.concept_code_1, s.vocabulary_id_1) = (c.concept_code, c.vocabulary_id) and
		(s.concept_code_2, s.vocabulary_id_2) = (c2.concept_code, c2.vocabulary_id) and
		r.relationship_id = s.relationship_id
	where
		r.relationship_id not in ('Concept replaces','Mapped from') and
		s.relationship_id is null and
		r2.relationship_id is null

	union all

	select
		'W',
		'Errors in basic tables not adressed in current release: Concept that served as a mapping target deprecates without replacement',
		count (c.concept_id)
	from concept c
	join concept_relationship r on
		r.concept_id_2 = c.concept_id and
		r.concept_id_1 != r.concept_id_2 and
		r.relationship_id = 'Maps to' and
		r.invalid_reason is null and
		c.standard_concept = 'S'
	join concept_stage s on
		(s.concept_code, s.vocabulary_id) = (c.concept_code, c.vocabulary_id) and
		s.standard_concept is null
	left join concept_relationship_stage x on
		x.relationship_id in ('Concept replaced by','Maps to') and
		(s.concept_code, s.vocabulary_id) = (x.concept_code_1, x.vocabulary_id_1) and
		x.invalid_reason is null
	where x.relationship_id is null 
)
select info_level, description, sum (err_cnt) as err_cnt
from info_sheet
where err_cnt != 0
group by info_level, description
order by info_level, description
;
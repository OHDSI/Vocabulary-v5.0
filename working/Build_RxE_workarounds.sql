drop table if exists workaround_cleanup
;
create unlogged table workaround_cleanup as
--gather all Clinical Drug Comps which have duplicates within 0.05 dosage
with dup_list as
	(
		select
			c.concept_id,
			c.concept_name,
			s.numerator_value / 10 ^ floor (log (s.numerator_value)) as normal_value,
			c2.concept_id as dup_concept_id,
			c2.concept_name as dup_concept_name,
			s2.numerator_value / 10 ^ floor (log (s2.numerator_value)) as dup_normal_value
		from concept c
		join concept c2 on
			c.concept_class_id = 'Clinical Drug Comp' and
			c2.concept_class_id = 'Clinical Drug Comp' and
			c.standard_concept = 'S' and
			c2.standard_concept = 'S' and
			c.concept_id != c2.concept_id
		join drug_strength s on
			s.drug_concept_id = c.concept_id
		join drug_strength s2 on
			s2.drug_concept_id = c2.concept_id and
			s2.denominator_unit_concept_id = s.denominator_unit_concept_id and
			s2.numerator_unit_concept_id = s.numerator_unit_concept_id and
			s2.ingredient_concept_id = s.ingredient_concept_id and
			s2.numerator_value > s.numerator_value and
			s2.numerator_value * 0.95 < s.numerator_value
	),
--unify comp groups by lowest member
dup_groups as
	(
		select
			d1.concept_id as group_id,
			d1.dup_concept_id as dup_concept_id,
			d1.dup_normal_value as dup_normal_value
		from dup_list d1
		--don't create groups from not the lowest
		left join dup_list d3 on
			d1.concept_id = d3.dup_concept_id
		where d3.dup_concept_id is null

			union

		--get subsequent duplicates over medium level members
		select distinct
			d1.concept_id as group_id,
			d2.dup_concept_id,
			d2.dup_normal_value
		from dup_list d1
		join dup_list d2 on
			d2.concept_id = d2.dup_concept_id
		--don't create groups from not the lowest
		left join dup_list d3 on
			d1.concept_id = d3.dup_concept_id
		where d3.dup_concept_id is null

			union
		--add self
		select distinct
			d1.concept_id as group_id,
			d1.concept_id,
			d1.normal_value
		from dup_list d1
		--don't create groups from not the lowest
		left join dup_list d3 on
			d1.concept_id = d3.dup_concept_id
		where d3.dup_concept_id is null
	),
--Find the best (simplest) target in group and exclude the rest
dup_ranked as
	(
		select
			group_id,
			dup_concept_id,
			dup_concept_id =
				(
					first_value (dup_concept_id) over
						(
							partition by group_id
							order by
							--Measures how "simple" a number looks
								dup_normal_value % 0.05 asc,
								dup_normal_value % 0.1 asc,
								dup_normal_value % 0.25 asc,
								dup_normal_value % 0.5 asc
						)
				) as best_in_group
		from dup_groups
	),
--This excludes concepts that stem from duplicate components
blacklist as
	(
		select
			drug_concept_id as component_concept_id,
			ingredient_concept_id
		from drug_strength a
		join dup_ranked on
			not best_in_group and
			drug_concept_id = dup_concept_id
	),
exclusion as
	(
		select a.descendant_concept_id
		from concept_ancestor a
		join blacklist b on
			component_concept_id = ancestor_concept_id
	--Sometimes drugs may have more than one component with same ingredient as ancestor (NaCl 8.8 & NaCl 9); exclude those.
		/*where not exists
			(
				select 1
				from concept_ancestor x
				join drug_strength d on
					x.descendant_concept_id = a.descendant_concept_id and
					d.ingredient_concept_id = b.ingredient_concept_id and
					d.drug_concept_id = x.ancestor_concept_id and
					x.ancestor_concept_id != b.component_concept_id
				join concept c on
					d.drug_concept_id = c.concept_id and
					c.concept_class_id = 'Clinical Drug Comp'
			)*/
	)
select c.concept_id as bad_concept_id, 'Contributing Drug Component is a dublicate' as exclusion_criterion
from concept c
where exists	
	(select 1 from exclusion where c.concept_id = descendant_concept_id)

	union all

--This will remove concepts that have valid relation to inactive attributes; Build_RxE would otherwise treat them as duplicate concepts of another class
select concept_id as bad_concept_id, 'Valid relation to invalid attribute' as exclusion_criterion
from concept c
where
    c.invalid_reason is null and
    c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
    c.domain_id = 'Drug' and
    c.concept_class_id != 'Ingredient' and
    c.concept_id in
    (
    	select concept_id_2
        from concept_relationship r
        join concept c on
            r.relationship_id = 'Brand name of' and
            c.concept_id = r.concept_id_1 and
            c.concept_class_id = 'Brand Name' and
            c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
            c.invalid_reason is not null and
            r.invalid_reason is null
            --some may still have another valid attribute
            and not exists
            	(
            		select 1
            		from concept_relationship xr
            		join concept xc on
            			r.concept_id_2 = xr.concept_id_2 and
            			r.concept_id_1 != xr.concept_id_1 and
            			xr.relationship_id = 'Brand name of' and
            			xc.invalid_reason is null and
            			xr.invalid_reason is null and
            			xr.concept_id_1 = xc.concept_id
            	)

			union all

        select concept_id_2
        from concept_relationship r
        join concept c on
            r.relationship_id = 'RxNorm dose form of' and
            c.concept_id = r.concept_id_1 and
            c.concept_class_id = 'Dose Form' and
            c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
            c.invalid_reason is not null and
            r.invalid_reason is null
            --some may still have another valid attribute
          	and not exists

            	(
            		select 1
            		from concept_relationship xr
            		join concept xc on
            			r.concept_id_2 = xr.concept_id_2 and
            			r.concept_id_1 != xr.concept_id_1 and
            			xr.relationship_id = 'RxNorm dose form of' and
            			xc.invalid_reason is null and
            			xr.invalid_reason is null and
            			xr.concept_id_1 = xc.concept_id
            	)

                         union all
               
        select concept_id_2
        from concept_relationship r
        join concept c on
            r.relationship_id = 'Supplier of' and
            c.concept_id = r.concept_id_1 and
            c.concept_class_id = 'Supplier' and
            c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
            c.invalid_reason is not null and
            r.invalid_reason is null
            --some may still have another valid attribute
            and not exists
            	(
            		select 1
            		from concept_relationship xr
            		join concept xc on
            			r.concept_id_2 = xr.concept_id_2 and
            			r.concept_id_1 != xr.concept_id_1 and
            			xr.relationship_id = 'Supplier of' and
            			xc.invalid_reason is null and
            			xr.invalid_reason is null and
            			xr.concept_id_1 = xc.concept_id
            	)
    )
;
update concept c
set
	standard_concept = NULL,
	invalid_reason = 'D',
	valid_end_date = current_date - 1
where
	exists
		(
			select 1
			from workaround_cleanup
			where
				c.concept_id = bad_concept_id
		)
;
delete from concept_relationship r
where
	exists
		(
			select 1
			from workaround_cleanup
			where
				bad_concept_id = r.concept_id_1
		)
;
delete from concept_relationship r
where
	exists
		(
			select 1
			from workaround_cleanup
			where
				bad_concept_id = r.concept_id_2
		)
;
delete from drug_strength
where
	exists
		(
			select 1
			from workaround_cleanup
			where
				drug_concept_id = bad_concept_id
		)
;

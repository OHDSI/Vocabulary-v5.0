insert into drug_concept_stage --devices
select
	d.prd_name,
	'LPD_Belgium' as vocabulary_id,
	'Device' as concept_class_id,
	null as source_concept_class_id,
	'S' as standard_concept,
	d.prd_id as concept_code,
	null as possible_excipient,
	'Device' as domain_id,
	trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
from source_data d
join devices_mapped m
	on m.prd_name = d.prd_name;
	
insert into drug_concept_stage --drugs
select
	d.prd_name,
	'LPD_Belgium' as vocabulary_id,
	'Drug Product' as concept_class_id,
	null as source_concept_class_id,
	'S' as standard_concept,
	d.prd_id as concept_code,
	null as possible_excipient,
	'Drug' as domain_id,
	trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
from source_data d
where prd_name not in (select prd_name from devices_mapped);

drop sequence conc_stage_seq;
create sequence conc_stage_seq 
MINVALUE 100
  MAXVALUE 1000000
  START WITH 100
  INCREMENT BY 1
  CACHE 20;  

create table brands_temp as select distinct nvl (mast_prd_name, concept_name) as name from brands_mapped;
insert into drug_concept_stage --bn
select
	name,
	'LPD_Belgium' as vocabulary_id,
	'Brand Name' as concept_class_id,
	null as source_concept_class_id,
	null as standard_concept,
	'OMOP' || conc_stage_seq.nextval as concept_code,
	null as possible_excipient,
	'Drug' as domain_id,
	trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
from brands_temp;

drop table brands_temp;

create table ingred_temp as select distinct concept_name as name from products_to_ingreds;
insert into drug_concept_stage --in
select
	TRIM(name),
	'LPD_Belgium' as vocabulary_id,
	'Ingredient' as concept_class_id,
	null as source_concept_class_id,
	'S' as standard_concept,
	'OMOP' || conc_stage_seq.nextval as concept_code,
	null as possible_excipient,
	'Drug' as domain_id,
	trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
from ingred_temp;

drop table ingred_temp;

insert into drug_concept_stage
with units as --units
	(
		select distinct UNIT_NAME1 as name
		from source_data d
		UNION
		select distinct UNIT_NAME2 as name
		from source_data d
		UNION
		select distinct UNIT_NAME3 as name
		from source_data d
	)	
select
	name,
	'LPD_Belgium' as vocabulary_id,
	'Unit' as concept_class_id,
	null as source_concept_class_id,
	null as standard_concept,
	name as concept_code,
	null as possible_excipient,
	'Drug' as domain_id,
	trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
from units where name is not null
;
insert into drug_concept_stage values ('actuat','LPD_Belgium','Unit',null,null,'actuat',null,'Drug', trunc(sysdate), TO_DATE('2099/12/31', 'yyyy/mm/dd'), null)
;
insert into drug_concept_stage --dose form
select distinct
	drug_form,
	'LPD_Belgium' as vocabulary_id,
	'Dose Form' as concept_class_id,
	null as source_concept_class_id,
	null as standard_concept,
	'g'||gal_id,
	null as possible_excipient,
	'Drug' as domain_id,
	trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
from source_data
where gal_id not in ('-1','28993') -- unknown or IUD
;

insert into internal_relationship_stage --ingreds
select
	d.prd_id,
	c.concept_code
from source_data d
join products_to_ingreds p
	on
		d.prd_name = p.prd_name
join drug_concept_stage c
	on
		c.concept_name = p.concept_name and
		concept_class_id = 'Ingredient'
where d.prd_name not in (select prd_name from devices_mapped)		
;
delete from internal_relationship_stage where concept_code_2 = 'OMOP3380918' and concept_code_1 in (10541251,10541252);
;
insert into internal_relationship_stage --brands
select
	d.prd_id,
	c.concept_code
from source_data d
join brands_mapped p
	on
		d.prd_name = p.prd_name
join drug_concept_stage c
	on
		c.concept_name = p.concept_name and
		concept_class_id = 'Brand Name'
where d.prd_name not in (select prd_name from devices_mapped)
;
insert into internal_relationship_stage --dose forms
select distinct
	d.prd_id,
	'g'||d.gal_id
from source_data d
where d.prd_name not in (select prd_name from devices_mapped) and d.gal_id not in ('-1','28993')
;
create table sup_temp as select distinct MANUFACTURER_NAME from supplier_mapped
;
insert into drug_concept_stage --in
select
	MANUFACTURER_NAME,
	'LPD_Belgium' as vocabulary_id,
	'Supplier' as concept_class_id,
	null as source_concept_class_id,
	'S' as standard_concept,
	'OMOP' || conc_stage_seq.nextval as concept_code,
	null as possible_excipient,
	'Drug' as domain_id,
	trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
from sup_temp;
;
drop table sup_temp
;
insert into internal_relationship_stage --suppliers
select distinct
	d.prd_id,
	c.concept_code
from source_data d
join drug_concept_stage c on c.concept_class_id = 'Supplier' and c.concept_name = d.manufacturer_name
where d.prd_name not in (select prd_name from devices_mapped) and d.gal_id != '-1' 
;
DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Unit'
AND   concept_code = 'unknown';

;

insert into ds_stage
with a as 
	(select distinct prd_name from PRODUCTS_TO_INGREDS group by prd_name having count (PRODUCTS_TO_INGREDS.concept_id) = 1),
simple as
	(
		select d.*
		from source_data d
		join a on a.prd_name = d.prd_name
		where
			(
			    d.PRD_DOSAGE != '0' or
			    d.PRD_DOSAGE2 != '0' or
			    d.PRD_DOSAGE3 != '0'
 			) and
			d.UNIT_NAME1 not like '%!%%' escape '!' and
			(d.UNIT_NAME1 not like '%/%' or unit_name1 = '% v/v') and
			d.prd_name not in (select * from devices_mapped)
	),
percents as
	(
		select d.*
		from source_data d
		join a on a.prd_name = d.prd_name
		where
			(
			    d.PRD_DOSAGE != '0' or
			    d.PRD_DOSAGE2 != '0' or
			    d.PRD_DOSAGE3 != '0'
 			) and
			d.UNIT_NAME1 = '%' and
			d.prd_name not in (select * from devices_mapped)
	),
transderm as
	(
		select d.*
		from source_data d
		join a on a.prd_name = d.prd_name
		where
			(
			    d.PRD_DOSAGE != '0' or
			    d.PRD_DOSAGE2 != '0' or
			    d.PRD_DOSAGE3 != '0'
 			) and
			d.UNIT_NAME1 like 'm_g/%h' and
			d.prd_name not in (select * from devices_mapped)
	)
select
	c1.concept_code as drug_concept_code,
	c2.concept_code as ingredient_concept_code,
	replace (simple.PRD_DOSAGE,',','.') as amount_value,
	simple.unit_name1 as amount_unit,
	null as numerator_value,
	null as numerator_unit,
	null as denominator_value,
	null as denominator_unit,
	null as box_size
from simple
join drug_concept_stage c1 on simple.prd_name = c1.concept_name and concept_class_id = 'Drug Product'
join PRODUCTS_TO_INGREDS p on p.prd_name = simple.prd_name
join drug_concept_stage c2 on p.concept_name = c2.concept_name
UNION
select
	c1.concept_code as drug_concept_code,
	c2.concept_code as ingredient_concept_code,
	null as amount_value,
	null as amount_unit,
	10 * to_number(replace (percents.prd_dosage,',','.')) as numerator_value,
	'mg' as denominator_unit, --mg
	1 as numerator_value,
	'ml' as denominator_unit, --ml
	null as box_size
from percents
join drug_concept_stage c1 on percents.prd_name = c1.concept_name and concept_class_id = 'Drug Product'
join PRODUCTS_TO_INGREDS p on p.prd_name = percents.prd_name
join drug_concept_stage c2 on p.concept_name = c2.concept_name
UNION
select
	c1.concept_code as drug_concept_code,
	c2.concept_code as ingredient_concept_code,
	replace (transderm.PRD_DOSAGE,',','.') as amount_value,
	case
		when transderm.unit_id like 'mg%' then 'mg' --mg
		else 'mcg' --mcg
	end as amount_unit,
	null as numerator_value,
	null as denominator_unit,
	null as numerator_value,
	null as denominator_unit,
	null as box_size
from transderm
join drug_concept_stage c1 on transderm.prd_name = c1.concept_name and concept_class_id = 'Drug Product'
join PRODUCTS_TO_INGREDS p on p.prd_name = transderm.prd_name
join drug_concept_stage c2 on p.concept_name = c2.concept_name;;


insert into relationship_to_concept --ingredients
select distinct
	d.concept_code,
	'LPD_Belgium' as vocabulary_id,
	c.concept_id,
	c.precedence,
	null as conversion_factor
from ingred_mapped c
join drug_concept_stage d on d.concept_class_id = 'Ingredient' and d.concept_name = c.concept_name;
;
insert into relationship_to_concept --brands
select distinct
	d.concept_code,
	'LPD_Belgium' as vocabulary_id,
	c.concept_id,
	null, null
from brands_mapped c
join drug_concept_stage d on d.concept_class_id = 'Brand Name' and nvl (c.mast_prd_name, c.concept_name) = d.concept_name;
;
insert into relationship_to_concept --units
select distinct
	d.concept_code,
	'LPD_Belgium' as vocabulary_id,
	c.concept_id,
	c.precedence,
	c.conversion_factor
from drug_concept_stage d
join units_mapped c on d.concept_class_id = 'Unit' and d.concept_name = c.unit_name;

insert into relationship_to_concept --forms
select distinct
	d.concept_code,
	'LPD_Belgium' as vocabulary_id,
	c.concept_id,
	c.precedence,
	null
from drug_concept_stage d
join forms_mapped c on d.concept_class_id = 'Dose Form' and d.concept_name = c.drug_form;
;
delete from internal_relationship_stage
where
	concept_code_2 in 
		(
			select d.concept_code from concept c
			join drug_concept_stage d on d.concept_name = c.concept_name 
			where concept_id in (19136048,36878798,19049024,1036525,19125390,1394027,19066891,19010961,42899013,42899196,19043395,36878798)
		)
;
insert into relationship_to_concept
select distinct
	d.concept_code,
	'LPD_Belgium' as vocabulary_id,
	c.concept_id,
	null,
	null
from drug_concept_stage d
join supplier_mapped c on d.concept_class_id = 'Supplier' and d.concept_name = c.manufacturer_name where c.concept_name is not null;
; --forms-guessing
insert into internal_relationship_stage
select distinct
	prd_id,
	case
		when prd_name like '%INJECT%' or prd_name like '%SERINGU%' or prd_name like '%STYLO%' or prd_name like '% INJ %' then 'g29010'
		when prd_name like '%SOLUTION%' or prd_name like '%AMPOULES%' or prd_name like '%GOUTTES%' or prd_name like '%GUTT%' then 'g28919'
		when prd_name like '%POUR SUSPE%' then 'g29027'
		when prd_name like '%COMPRI%' or prd_name like '%TABS %' or prd_name like '% DRAG%' then 'g28901'
		when prd_name like '%POUDRE%' or prd_name like '% PDR %' then 'g28929'
		when prd_name like '%GELUL%' or prd_name like '%CAPS %' then 'g29033'
		when prd_name like '%SPRAY%' then 'g28926'
		when prd_name like '%CREME%' or prd_name like '%CREAM%' then 'g28920'
		when prd_name like '%LAVEMENTS%' or prd_name like '%LAVEMENTS%' then 'g28909'
		when prd_name like '%POMM%' then 'g28910' 
		when prd_name like '%INHALAT%' then 'g28988'
		when prd_name like '%EFFERVESCENTS%' or prd_name like '%AMP%' then 'g28919' 
		when prd_name like '% COMP%' or prd_name like '%TAB%' then 'g28901'
		when prd_name like '%PERFUS%' then 'g28987'
		when prd_name like '%BUCCAL%' then 'g29009'
		else 'boo'
	end
from source_data
where prd_id not in (select concept_code_1 from internal_relationship_stage where concept_code_2 like 'g%')
and prd_name not in (select * from devices_mapped)
;
delete from internal_relationship_stage where concept_code_2 = 'boo';
;

create table map_auto as
with unmapped as 
	(
		select distinct
			d.count,
			d.prd_id,
			regexp_replace (d.prd_name, ' (\d+) (\d+ ?(MG|MCG|G|UI|IU))', ' \1.\2') as fixed_name,
			c.concept_id,
			c.concept_name
		from source_data d
		left join products_to_ingreds c on c.prd_name = d.prd_name
		where 
			prd_id not in (select drug_concept_code from ds_stage)
			and d.prd_name not in (select * from devices_mapped)
			and regexp_like (d.prd_name,' \d+?(MCG|MG|G) ')
			and concept_id is not null
			and regexp_substr (d.prd_name,'(\d+)\.?(\d+)? ?(MCG|MG|G|UI|IU) ',1,3) is null
	),
list as
	(
		select prd_id 
		from unmapped
		where count > 1
		group by prd_id having count (concept_id) < 3
	)
select distinct	
	u.count,
	u.prd_id,
	u.fixed_name,	
	--amount 1
	regexp_replace (regexp_substr (u.fixed_name, '(\d+)?\.?(\d+ ?(MG|MCG|G|UI|IU)) ',1,1),'[A-Z ]') as a1,
	--unit 1
	lower (regexp_substr (regexp_substr (u.fixed_name, '(\d+)?\.?(\d+ ?(MG|MCG|G|UI|IU)) ',1,1),'[A-Z]+')) as u1,
	--amount 2
	regexp_replace (regexp_substr (u.fixed_name, '(\d+)?\.?(\d+ ?(MG|MCG|G|UI|IU)) ',1,2),'[A-Z ]') as a2,
	--unit 2
	lower (regexp_substr (regexp_substr (u.fixed_name, '(\d+)?\.?(\d+ ?(MG|MCG|G|UI|IU)) ',1,2),'[A-Z]+')) as u2,

	min (u.concept_id) over (partition by u.prd_id) as i1,
	max (u.concept_id) over (partition by u.prd_id) as i2
from unmapped u where prd_id in (select * from list) 
;
update map_auto set i2 = null where i1 = i2;
;
alter table map_auto add UC1 number;
alter table map_auto add UC2 number;
;
update map_auto set u1 = 'IU' where u1 = 'iu';
update map_auto set u2 = 'IU' where u2 = 'iu';
;
update map_auto set uc1 = 8504 where u1 = 'g';
update map_auto set uc1 = 8576 where u1 = 'mg';
update map_auto set uc1 = 9655 where u1 = 'mcg';
update map_auto set uc1 = 8718 where u1 = 'IU';
;
update map_auto set uc2 = 8504 where u2 = 'g';
update map_auto set uc2 = 8576 where u2 = 'mg';
update map_auto set uc2 = 9655 where u2 = 'mcg';
update map_auto set uc2 = 8718 where u2 = 'IU';
;
insert into ds_stage 
select m.PRD_ID,d.concept_code,A1,U1,null,null,null,null,null from map_auto m
join concept c on m.i1 = c.concept_id
join drug_concept_stage d on c.concept_name = d.concept_name and d.concept_class_id = 'Ingredient'
where a2 is null and i2 is null;
;
drop table temp_dcs;
create table temp_dcs as
with options as
	(
		select COUNT,PRD_ID,I1,A1,U1,I2,A2,U2,uc1,uc2 from map_auto m where a2 is not null and i2 is not null
		UNION
		select COUNT,PRD_ID,I2,A1,U1,I1,A2,U2,uc1,uc2 from map_auto m where a2 is not null and i2 is not null
	),
matches as
	(
		select distinct 
			o.prd_id, d.drug_concept_id	
		from drug_strength d
		join options o
			on
		d.ingredient_concept_id = o.i1 and
		d.amount_value = o.a1 and
		d.amount_unit_concept_id = o.uc1 and
			(
				select drug_concept_id 
				from drug_strength x 
				where
					x.ingredient_concept_id = o.i2 and
					x.amount_value = o.a2 and
					x.amount_unit_concept_id = o.uc2 and
					x.drug_concept_id = d.drug_concept_id
			) is not null
		where 
			a2 is not null and 
			i2 is not null
	),
double_trouble as
	(
		select d.drug_concept_id
		from drug_strength d
		where drug_concept_id in (select drug_concept_id from matches)
		group by d.drug_concept_id having count (distinct d.ingredient_concept_id || ' ' || d.amount_value) = 2
	)
select distinct
	m.prd_id,
	dcs.concept_code,
	ds.amount_value,
	case
		when ds.amount_unit_concept_id = 8504 then 'g'
		when ds.amount_unit_concept_id = 8576 then 'mg'
		when ds.amount_unit_concept_id = 9655 then 'mcg'
		when ds.amount_unit_concept_id = 8718 then 'IU'
		else null
	end as amount_unit
from matches m
join double_trouble dt on dt.drug_concept_id = m.drug_concept_id
join drug_strength ds on m.drug_concept_id = ds.drug_concept_id
join concept c on ds.ingredient_concept_id = c.concept_id
join drug_concept_stage dcs on dcs.concept_name = c.concept_name and dcs.concept_class_id = 'Ingredient'
;
delete from temp_dcs t where --hctz always the smallest, except for bisoprolol combinations
	prd_id in (select prd_id from temp_dcs group by prd_id having count (concept_code) = 4) and
		(
			prd_id in (select prd_id from temp_dcs where concept_code = 'OMOP5301') and 
			prd_id not in (select prd_id from temp_dcs where concept_code = 'OMOP5701')
		) and
		(
			(concept_code = 'OMOP5301' and t.amount_value > (select amount_value from temp_dcs where prd_id = t.prd_id and concept_code != 'OMOP5301' and amount_value != t.amount_value)) or
			(t.amount_value < (select amount_value from temp_dcs where prd_id = t.prd_id and concept_code = 'OMOP5301' and amount_value != t.amount_value))
		)
;
delete from temp_dcs t where --caffeine < ergotamine
	prd_id in (select prd_id from temp_dcs where concept_code = 'OMOP5319') and
	prd_id in (select prd_id from temp_dcs where concept_code = 'OMOP4695') and
	(
		concept_code = 'OMOP5319' and amount_value < (select amount_value from temp_dcs where prd_id = t.prd_id and concept_code = 'OMOP4695' and amount_value != t.amount_value) or
		concept_code = 'OMOP4695' and amount_value > (select amount_value from temp_dcs where prd_id = t.prd_id and concept_code = 'OMOP5319' and amount_value != t.amount_value)
	)
;
insert into ds_stage 
select s.*, null,null,null,null,null from temp_dcs s
where prd_id not in (select prd_id from temp_dcs group by prd_id having count (concept_code) = 4);
drop table map_auto
;

delete from ds_stage where amount_unit = 'g' and amount_value > 3 and drug_concept_code in (select prd_id from source_data where unit_name1 = 'unknown'); --topical cremes

delete from ds_stage where drug_concept_code in (select prd_id from ds_manual);
delete from internal_relationship_stage 
where
	concept_code_1 in (select prd_id from ds_manual) and
	concept_code_2 in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient');


create table ingred_temp as select distinct concept_id, trim (concept_name) as name from ds_manual where TRIM(concept_name) not in (select trim(concept_name) from drug_concept_stage where concept_class_id = 'Ingredient');
insert into drug_concept_stage --in
select
	TRIM(name),
	'LPD_Belgium' as vocabulary_id,
	'Ingredient' as concept_class_id,
	null as source_concept_class_id,
	'S' as standard_concept,
	'OMOP' || conc_stage_seq.nextval as concept_code,
	null as possible_excipient,
	'Drug' as domain_id,
	trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
from ingred_temp;

insert into internal_relationship_stage 
select distinct
	d.prd_id,
	c.concept_code
from ds_manual d
join drug_concept_stage c on
	concept_class_id = 'Ingredient' and
	c.concept_name = d.concept_name;
	
insert into relationship_to_concept --ingredients
select distinct
	d.concept_code,
	'LPD_Belgium' as vocabulary_id,
	c.concept_id,
	null as precedence,
	null as conversion_factor
from ingred_temp c
join drug_concept_stage d on d.concept_class_id = 'Ingredient' and d.concept_name = c.name
;
insert into ds_stage
select distinct
	d.prd_id,
	c.concept_code,
	case --amount
		when denominator_value is not null then null
		else amount_value
	end,
	case
		when denominator_value is not null then null
		else amount_unit
	end,
	case --numerator
		when denominator_value is null then null
		else amount_value
	end,
	case
		when denominator_value is null then null
		else amount_unit
	end,
	denominator_value,
	denominator_unit,
	box_size
from ds_manual d
join drug_concept_stage c on
	concept_class_id = 'Ingredient' and
	c.concept_name = d.concept_name
where amount_value is not null;

update ds_stage d
set box_size = to_number (reverse
	(
		regexp_substr ((select reverse (prd_name) from source_data where prd_id = d.drug_concept_code and prd_name like '% C %'),'\d+',1,1)
	)
)
where (box_size is null and denominator_unit != 'actuat');
update ds_stage set box_size = null where box_size = 1;
drop table ingred_temp;
delete from ds_stage where 0 IN (numerator_value,amount_value,denominator_value);

insert into relationship_to_concept --ingredients fix
with ingreds_unmapped as
	(
		select dcs.concept_code, cc.concept_id from drug_concept_stage dcs
		join concept cc on lower (cc.concept_name) = lower (dcs.concept_name) and cc.concept_class_id = dcs.concept_class_id and cc.vocabulary_id like 'RxNorm%'
		left join relationship_to_concept cr on dcs.concept_code = cr.concept_code_1
		where concept_code_1 is null and cc.invalid_reason is null
		and dcs.concept_class_id in ('Ingredient')
	)
select distinct
	c.concept_code,
	'LPD_Belgium' as vocabulary_id,
	c.concept_id,
	null as precedence,
	null as conversion_factor
from ingreds_unmapped c;

delete from ds_stage where
	drug_concept_code in (
		SELECT drug_concept_code
    	FROM (SELECT drug_concept_code, ingredient_concept_code
        FROM ds_stage
        GROUP BY drug_concept_code, ingredient_concept_code  HAVING COUNT(1) > 1)
        ) and
        ingredient_concept_code = 'OMOP3161973' and amount_value = 40;
--delete from ds_stage where drug_concept_code in (8317575,8358514,8358515);
--insert into ds_stage values ('8358514','OMOP3163179',50,'mg',null,null,null,null,4);
--insert into ds_stage values ('8358515','OMOP3163179',50,'mg',null,null,null,null,4);
--insert into ds_stage values ('8317575','OMOP3163179',50,'mg',null,null,null,null,4);
delete from ds_stage where lower(numerator_unit) IN ('ml') OR lower(amount_unit) IN ('ml');
update relationship_to_concept a set a.conversion_factor = 1 where conversion_factor is null and a.concept_code_1 in (select concept_code from drug_concept_stage where concept_class_id = 'Unit');
delete FROM relationship_to_concept 
where 
	((concept_code_1, concept_id_2) in 
		(
			SELECT concept_code_1, concept_id_2
            FROM relationship_to_concept
            GROUP BY concept_code_1, concept_id_2 HAVING COUNT(1) > 1)
        ) and
        precedence is null;

create table irs_dupefix as
select distinct concept_code_1, concept_code_2 FROM internal_relationship_stage;
drop table internal_relationship_stage;
rename irs_dupefix to internal_relationship_stage;

create table dcs_dupefix as
select distinct CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,SOURCE_CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON FROM drug_concept_stage;
drop table drug_concept_stage;
rename dcs_dupefix to drug_concept_stage;

delete from internal_relationship_stage 
where 
	concept_code_1 in
		(
			select concept_code from drug_concept_stage  dcs
			join (
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
			left join ds_stage on drug_concept_code = concept_code_1 
			where drug_concept_code is null
			union 
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
			where concept_code_1 not in (SELECT concept_code_1
			                                  FROM internal_relationship_stage
			                                    JOIN drug_concept_stage   ON concept_code_2 = concept_code  AND concept_class_id = 'Dose Form')
			) s on s.concept_code_1 = dcs.concept_code
			where dcs.concept_class_id = 'Drug Product' and invalid_reason is null 
		) and
	concept_code_2 in 
		(
			select concept_code
			from drug_concept_stage
			where concept_class_id = 'Supplier'
		);

declare
 ex number;
begin
select max(iex)+1 into ex from (  
    
    select cast(replace(concept_code, 'OMOP') as integer) as iex from concept where concept_code like 'OMOP%'  and concept_code not like '% %'
);
  begin
    execute immediate 'create sequence new_vocab increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
    exception
      when others then null;
  end;
end;
/

drop table code_replace;
 create table code_replace as 
 select 'OMOP'||new_vocab.nextval as new_code, concept_code as old_code from (
select distinct  concept_code from drug_concept_stage where concept_code like '%OMOP%' order by (cast ( regexp_substr( concept_code, '\d+') as int))
)
;
update drug_concept_stage a set concept_code = (select new_code from code_replace b where a.concept_code = b.old_code) 
where a.concept_code like '%OMOP%' 
;
commit
;
update relationship_to_concept a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%'
;commit
;
update ds_stage a  set ingredient_concept_code = (select new_code from code_replace b where a.ingredient_concept_code = b.old_code)
where a.ingredient_concept_code like '%OMOP%' 
;
commit
;
update ds_stage a  set drug_concept_code = (select new_code from code_replace b where a.drug_concept_code = b.old_code)
where a.drug_concept_code like '%OMOP%' 
;commit
;
update internal_relationship_stage a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%'
;commit
;
update internal_relationship_stage a  set concept_code_2 = (select new_code from code_replace b where a.concept_code_2 = b.old_code)
where a.concept_code_2 like '%OMOP%' 
;
commit
;
update pc_stage a  set DRUG_CONCEPT_CODE = (select new_code from code_replace b where a.DRUG_CONCEPT_CODE = b.old_code)
where a.DRUG_CONCEPT_CODE like '%OMOP%' 
;
update drug_concept_stage set standard_concept=null where concept_code in (select concept_code from drug_concept_stage 
join internal_relationship_stage on concept_code_1 = concept_code
where concept_class_id ='Ingredient' and standard_concept is not null);

commit;
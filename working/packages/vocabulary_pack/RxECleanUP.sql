CREATE OR REPLACE FUNCTION vocabulary_pack.rxecleanup()
  RETURNS void
  LANGUAGE plpgsql
AS
$body$
/*
 Clean up for RxE (create 'Concept replaced by' between RxE and Rx)
 AVOF-1456
 Usage:
 1. update the vocabulary (e.g. RxNorm) with generic_update
 2. run this script like
 DO $_$
 BEGIN
     PERFORM VOCABULARY_PACK.RxECleanUP();
 END $_$;
 3. run generic_update
*/
BEGIN
	--1. Update latest_update field to new date
--1. Update latest_update field to new date
DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.SetLatestUpdate(
		pVocabularyName			=> 'RxNorm Extension',
		pVocabularyDate			=> CURRENT_DATE,
		pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
		pVocabularyDevSchema	=> 'DEV_RXE'
	);
		PERFORM VOCABULARY_PACK.SetLatestUpdate(
		pVocabularyName			=> 'RxNorm',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_RXNORM',
		pAppendVocabulary		=> TRUE
	);
	END $_$;

	--2. Truncate all working tables
	TRUNCATE TABLE concept_stage;
	TRUNCATE TABLE concept_relationship_stage;
	TRUNCATE TABLE concept_synonym_stage;
	TRUNCATE TABLE pack_content_stage;
	TRUNCATE TABLE drug_strength_stage;


	--3. Collect all replacements to be made in a single table
	--3.1. Filter out concepts with more '/' than needed
	create or replace view broken_ing as
	with ing_count as
		(
			select 
				concept_name,
				drug_concept_id,
				count(ingredient_concept_id) as i_count, 
				(length(concept_name) - length(replace(concept_name, ' / ', ''))) / 3 as slash_count
			from drug_strength
			join concept on
				standard_concept = 'S' and
				concept_id = drug_concept_id and
				vocabulary_id = 'RxNorm'
			group by drug_concept_id, concept_name
		)
	select drug_concept_id from ing_count i
	where
		i.slash_count > i.i_count - 1
	;
	--3.2. Create attribute portraits of every concept
	drop table if exists rx_portrait cascade;
	create table rx_portrait as
	select distinct
		c.concept_code,
		c.concept_class_id,
		c.concept_name, 
		c.vocabulary_id,
		c.valid_start_date,
	
		-- Ingredient & Dosage:
		id.ingredient_concept_id,
		id.amount_value,
		id.amount_unit_concept_id,
		id.numerator_value,
		id.numerator_unit_concept_id,
		id.denominator_value,
		id.denominator_unit_concept_id,
	
		count(id.ingredient_concept_id) over (partition by id.drug_concept_id) as i_count, -- todo: replace with list of ingredients
	
		-- Dose form info
		cd.concept_code as dose_code,
	
		-- Brand name info
		cb.concept_code as brand_code,

		null :: varchar as ingredient_list, 
		null :: varchar as portrait
	
	from concept c
	-- Get ingredients
	join drug_strength id on
		id.drug_concept_id = c.concept_id

	-- Get df
	left join concept_relationship d on
		d.concept_id_1 = c.concept_id and
		d.invalid_reason is null and
		d.relationship_id = 'RxNorm has dose form'
	left join concept cd on
		cd.concept_id = d.concept_id_2

	-- Get bn
	left join concept_relationship b on
		b.concept_id_1 = c.concept_id and
		b.invalid_reason is null and
		b.relationship_id = 'Has brand name'
	left join concept cb on
		cb.concept_id = b.concept_id_2

	-- Filter out broken ingredients
	left join broken_ing x on
		x.drug_concept_id = c.concept_id

	where 
		c.standard_concept = 'S' and
		c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
		c.concept_class_id != 'Ingredient' and
		id.box_size is NULL and -- RxN does not have this
		x.drug_concept_id is null
	;
	drop table if exists atom_replacement
	;
	--3.3. Collect attribute replacement
	create table atom_replacement as
	SELECT cs.concept_id as rxe_id, cs.concept_code as rxe_code, c.concept_id as rx_id, c.concept_code as rx_code, c.concept_class_id
	FROM concept cs
	join concept c on
		upper(cs.concept_name) = upper(c.concept_name)
		AND cs.concept_class_id = c.concept_class_id
		AND c.invalid_reason IS NULL
		AND c.vocabulary_id = 'RxNorm'
		AND cs.vocabulary_id = 'RxNorm Extension'
		AND cs.invalid_reason IS NULL
		and c.concept_class_id in
			('Brand Name', 'Ingredient', 'Dose Form')
	;
	-- replace BN with new ones:
	update rx_portrait b
	set brand_code = a.rx_code
	from atom_replacement a
	where
		a.rxe_code = b.brand_code
	;
	-- replace DF with new ones:
	update rx_portrait b
	set dose_code = a.rx_code
	from atom_replacement a
	where
		a.rxe_code = b.dose_code
	;
	-- replace Ingredients:
	update rx_portrait b
	set ingredient_concept_id = a.rx_id
	from atom_replacement a
	where
		a.rxe_id = b.ingredient_concept_id
	;
	create index rx_portrait_idx on rx_portrait (concept_code, ingredient_concept_id);
	analyze rx_portrait
	;
	-- 3.4. List all ingredients per drug
	update rx_portrait r1
	set ingredient_list = (
		select concatenated
		from
			(
				select concept_code, string_agg(ingredient_concept_id :: varchar, '-') as concatenated
				from (
					select concept_code, ingredient_concept_id
					from rx_portrait r2
					where r2.concept_code = r1.concept_code
					order by r2.ingredient_concept_id
				) rx_ordered
				group by concept_code
			) subquery
		limit 1
	)
	;
	-- 3.5. Find pairs that match on everything but dosages
	update rx_portrait
	set 	
		portrait = '(' || ingredient_list || ')-' || ingredient_concept_id :: varchar || '-' || coalesce(dose_code, '0') || '-' || coalesce(brand_code, '0')
	;
	create index rx_portrait_idx0 on rx_portrait (concept_code, vocabulary_id);
	create index rx_portrait_idx2 on rx_portrait (portrait);
	analyze rx_portrait
	;
	drop table if exists portrait_match
	;
	create table portrait_match
	(
		rxe_code varchar,
		rxn_code varchar,
		PRIMARY KEY (rxe_code, rxn_code) 
	)
	;
	insert into portrait_match
	select distinct r1.concept_code as rxe_code, r2.concept_code as rxn_code
	from rx_portrait r1 join
	rx_portrait r2 using (portrait, concept_class_id)
	where
		r1.concept_code != r2.concept_code and
		r1.vocabulary_id = 'RxNorm Extension' and
		r2.vocabulary_id = 'RxNorm'
	;
	analyze portrait_match
	;
	-- 3.6. Match simple amount dosages
	drop table if exists full_match
	;
	create table full_match as
	with any_match as
	(
		select distinct 
			r1.concept_code as rxe_code,
			r2.concept_code as rxn_code,
			r2.concept_name,
			r2.valid_start_date,
			r1.i_count,
			count(rxn_code) over (partition by r1.concept_code, r2.concept_code) as matches_per_pair,
			case
				when r1.amount_value/r2.amount_value >= 1 then r1.amount_value/r2.amount_value
				else r2.amount_value/r1.amount_value
			end as imprecision
		from rx_portrait r1 
		join rx_portrait r2 using (portrait, concept_class_id)
		join portrait_match rx on
			r1.concept_code = rxe_code and r2.concept_code = rxn_code
		where
			r1.ingredient_concept_id = r2.ingredient_concept_id and
			r1.amount_unit_concept_id = r2.amount_unit_concept_id and
			r1.amount_value/r2.amount_value between 1/1.05 and 1.05 and
			r2.denominator_unit_concept_id is null
	)
	select distinct
		rxe_code,
		rxn_code,
		concept_name,
		valid_start_date,
		i_count,
		max(imprecision) over (partition by rxe_code, rxn_code) as imprecision
	from any_match
	where i_count = matches_per_pair
	;
	--3.7. Match numerator/denominator dosages:
	with any_match as
	(
		select distinct
			r1.concept_code as rxe_code, 
			r2.concept_code as rxn_code,
			r2.concept_name,
			r2.valid_start_date,
			r1.i_count, 
			count(rxn_code) over (partition by r1.concept_code, r2.concept_code) as matches_per_pair,
			case
				when (r1.numerator_value / coalesce(r1.denominator_value, 1)) / (r2.numerator_value / coalesce(r2.denominator_value, 1)) >= 1 then (r1.numerator_value / coalesce(r1.denominator_value, 1)) / (r2.numerator_value / coalesce(r2.denominator_value, 1))
				else (r2.numerator_value / coalesce(r2.denominator_value, 1)) / (r1.numerator_value / coalesce(r1.denominator_value, 1))
			end as imprecision
		from rx_portrait r1 
		join rx_portrait r2 using (portrait, concept_class_id)
		join portrait_match rx on
			r1.concept_code = rxe_code and r2.concept_code = rxn_code
		where
			r1.ingredient_concept_id = r2.ingredient_concept_id and
			r1.numerator_unit_concept_id = r2.numerator_unit_concept_id and
			r1.denominator_unit_concept_id = r2.denominator_unit_concept_id and
			coalesce(r1.denominator_value, 0) = coalesce(r2.denominator_value, 0) and
			(r1.numerator_value / coalesce(r1.denominator_value, 1)) / (r2.numerator_value / coalesce(r2.denominator_value, 1)) between 1/1.05 and 1.05
	)
	insert into full_match
	select distinct
		rxe_code,
		rxn_code,
		concept_name,
		valid_start_date,
		i_count,
		max(imprecision) over (partition by rxe_code, rxn_code) as imprecision
	from any_match
	where i_count = matches_per_pair
	;
	--3.8. Filter out better matches
	delete from full_match f
	where imprecision !=
		(
			select min(x.imprecision)
			from full_match x
			where x.rxe_code = f.rxe_code
		)
	;
	delete from full_match f
	where ctid !=
		(
			select distinct min(ctid) over (partition by rxe_code order by valid_start_date asc, length(concept_name) asc, concept_name asc)
			from full_match x
			where x.rxe_code = f.rxe_code
		)
	;
	drop table if exists concept_replacement_full
	;
	--3.9. Get final replacement table:
	create table concept_replacement_full as
	select rxe_code as concept_code_1, 'RxNorm Extension' as vocabulary_id_1, rxn_code as concept_code_2, 'RxNorm' as vocabulary_id_2
	from full_match

		union all

	select rxe_code as concept_code_1, 'RxNorm Extension' as vocabulary_id_1, rx_code as concept_code_2, 'RxNorm' as vocabulary_id_2
	from atom_replacement
	;

	--4. Load full list of RxNorm Extension concepts and set 'X' for duplicates
	INSERT INTO concept_stage
	SELECT *
	FROM concept
	WHERE vocabulary_id = 'RxNorm Extension';

	UPDATE concept_stage cs
	SET invalid_reason = 'X',
		standard_concept = NULL,
		valid_end_date = CURRENT_DATE,
		concept_id=c.concept_id
	FROM concept_replacement_full r
	join concept c on
		(r.concept_code_1, r.vocabulary_id_1) = (c.concept_code, c.vocabulary_id)
	where
		(r.concept_code_1, r.vocabulary_id_1) = (cs.concept_code, cs.vocabulary_id);

	--5. Load full list of RxNorm Extension relationships
	INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT c1.concept_code,
		c2.concept_code,
		c1.vocabulary_id,
		c2.vocabulary_id,
		r.relationship_id,
		r.valid_start_date,
		r.valid_end_date,
		r.invalid_reason
	FROM concept c1,
		concept c2,
		concept_relationship r
	WHERE c1.concept_id = r.concept_id_1
		AND c2.concept_id = r.concept_id_2
		AND (
			(
				c1.vocabulary_id = 'RxNorm Extension'
				AND c2.vocabulary_id = 'RxNorm'
				)
			OR (
				c1.vocabulary_id = 'RxNorm'
				AND c2.vocabulary_id = 'RxNorm Extension'
				)
			)
		AND r.invalid_reason IS NULL;

	--6. Deprecate old relationships
	UPDATE concept_relationship_stage crs
	SET invalid_reason = 'D',
		valid_end_date = CURRENT_DATE
	FROM concept_stage cs
	WHERE cs.concept_code IN (
			crs.concept_code_1,
			crs.concept_code_2
			) --with reverse
		AND cs.invalid_reason = 'X';

	--7. Add new replacements
	INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date
		)
	SELECT concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		'Concept replaced by',
		CURRENT_DATE,
		TO_DATE('20991231', 'yyyymmdd')
	FROM concept_replacement_full;

	--7. Update concept_stage (set 'U' for all 'X')
	UPDATE concept_stage
	SET invalid_reason = 'U'
	WHERE invalid_reason = 'X';

	--8. RxNorm concepts steal all relations from RxE concepts they replace:
	--8.1 All active relations to RxE concepts
	with full_replace as
		(
			select concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2
			from concept_replacement_full
		
				union
		
			select c.concept_code, c.vocabulary_id, c2.concept_code, c2.vocabulary_id
			from concept_relationship r
			join concept c on
				r.relationship_id = 'Concept replaced by' and
				c.concept_id = r.concept_id_1 and
				r.invalid_reason is null and
				c.vocabulary_id = 'RxNorm Extension'
			join concept c2 on
				c2.concept_id = r.concept_id_2 and
				c2.vocabulary_id = 'RxNorm'
		)
	insert into concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	select distinct
		r.concept_code_2,
		t.concept_code,
		r.vocabulary_id_2,
		t.vocabulary_id,
		cr.relationship_id,
		CURRENT_DATE,
		cr.valid_end_date,
		NULL
	
	from full_replace r
	join concept c on
		c.vocabulary_id = r.vocabulary_id_1 and
		c.concept_code = r.concept_code_1
	join concept_relationship cr on
		cr.concept_id_1 = c.concept_id and
		cr.invalid_reason is null
	join concept t on
		t.concept_id = cr.concept_id_2
	
	left join full_replace rc on
		(rc.concept_code_1, rc.vocabulary_id_1) = (t.concept_code, t.vocabulary_id)


	where rc.concept_code_1 is null and
	(
		t.vocabulary_id = 'RxNorm Extension'
	--8.2 All active mapped from and rx-source eq relations to other vocabs
		or
		(
			cr.relationship_id in ('Mapped from', 'RxNorm - Source eq') and
			t.vocabulary_id != 'RxNorm Extension'
		)
	) and
	--Prevent dublicates:
	not exists
	(
		select 1
		from concept_relationship_stage
		where
			(
					concept_code_1,
					concept_code_2,
					vocabulary_id_1,
					vocabulary_id_2,
					relationship_id,
					coalesce(invalid_reason,'N')
			) = (
				r.concept_code_2,
				t.concept_code,
				r.vocabulary_id_2,
				t.vocabulary_id,
				cr.relationship_id,
				'N'
			)
	)
	;
	-- Remove dublicates
	delete from concept_relationship_stage r1
	where ctid not in
	(
		select min(ctid)
		over
			(
				partition by
					concept_code_1,
					concept_code_2,
					vocabulary_id_1,
					vocabulary_id_2,
					relationship_id,
					invalid_reason
			)
	)
	;
	--9. Replaced RxE concepts lose all relations that are not Maps to or Concept replaced by
	with full_replace as
		(
			select concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2
			from concept_replacement_full
		
				union
		
			select c.concept_code, c.vocabulary_id, c2.concept_code, c2.vocabulary_id
			from concept_relationship r
			join concept c on
				r.relationship_id = 'Concept replaced by' and
				c.concept_id = r.concept_id_1 and
				r.invalid_reason is null and
				c.vocabulary_id = 'RxNorm Extension'
			join concept c2 on
				c2.concept_id = r.concept_id_2 and
				c2.vocabulary_id = 'RxNorm'
		)
	update concept_relationship_stage crs
	set
		invalid_reason = 'D',
		valid_end_date = CURRENT_DATE - 1
	from full_replace f
	where
		crs.invalid_reason is null and
		(crs.concept_code_1, crs.vocabulary_id_1) = (f.concept_code_1, f.vocabulary_id_1) and
		crs.relationship_id not in ('Maps to', 'Concept replaced by')
	;

	--10. Working with replacement mappings
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.CheckReplacementMappings();
	END $_$;

	--Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	END $_$;
	
	--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
	DO $_$
	BEGIN
		PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
	END $_$;

	--11. AddFreshMAPSTO creates RxNorm(ATC)-RxNorm links that need to be removed
	DELETE
	FROM concept_relationship_stage crs_o
	WHERE (
			crs_o.concept_code_1,
			crs_o.vocabulary_id_1,
			crs_o.concept_code_2,
			crs_o.vocabulary_id_2
			) IN (
			SELECT crs.concept_code_1,
				crs.vocabulary_id_1,
				crs.concept_code_2,
				crs.vocabulary_id_2
			FROM concept_relationship_stage crs
			LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
				AND v1.latest_update IS NOT NULL
			LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2
				AND v2.latest_update IS NOT NULL
			WHERE COALESCE(v1.latest_update, v2.latest_update) IS NULL
			);

	--12. Fill concept_synonym_stage
	INSERT INTO concept_synonym_stage
	SELECT cs.concept_id,
		cs.concept_synonym_name,
		c.concept_code,
		c.vocabulary_id,
		cs.language_concept_id
	FROM concept_synonym cs
	JOIN concept c ON c.concept_id = cs.concept_id
		AND c.vocabulary_id = 'RxNorm Extension';

$body$
  VOLATILE
  COST 100;

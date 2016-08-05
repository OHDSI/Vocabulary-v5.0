/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

DECLARE
   vCnt          INTEGER;
   vCnt_old      INTEGER;
   vSumMax       INTEGER;
   vSumMax_old   INTEGER;
   vSumMin       INTEGER;
   vIsOverLoop   BOOLEAN;

   FUNCTION IsSameTableData (pTable1 IN VARCHAR2, pTable2 IN VARCHAR2)
      RETURN BOOLEAN
   IS
      vRefCursor   SYS_REFCURSOR;
      vDummy       CHAR (1);

      res          BOOLEAN;
   BEGIN
      OPEN vRefCursor FOR
            'select null as col1 from ( select * from '
         || pTable1
         || ' minus select * from '
         || pTable2
         || ' )';

      FETCH vRefCursor INTO vDummy;

      res := vRefCursor%NOTFOUND;

      CLOSE vRefCursor;

      RETURN res;
   END;
BEGIN
   -- Clean up before
   BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE concept_ancestor_calc PURGE';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   BEGIN
      EXECUTE IMMEDIATE 'drop table concept_ancestor_calc_bkp purge';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   BEGIN
      EXECUTE IMMEDIATE 'drop table new_concept_ancestor_calc purge';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   -- Seed the table by loading all first-level (parent-child) relationships

   EXECUTE IMMEDIATE
      'create table concept_ancestor_calc NOLOGGING as
    select 
	r.concept_id_1 as ancestor_concept_id,
	r.concept_id_2 as descendant_concept_id,
    case when s.is_hierarchical=1 and c1.standard_concept is not null then 1 else 0 end as min_levels_of_separation,
    case when s.is_hierarchical=1 and c2.standard_concept is not null then 1 else 0 end as max_levels_of_separation
    from concept_relationship r 
    join relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
	join concept c1 on c1.concept_id=r.concept_id_1 and c1.invalid_reason is null
	join concept c2 on c2.concept_id=r.concept_id_2 and c2.invalid_reason is null
    where r.invalid_reason is null';

   /********** Repeat till no new records are written *********/
   FOR i IN 1 .. 100
   LOOP
      -- create all new combinations

      EXECUTE IMMEDIATE
         'create table new_concept_ancestor_calc NOLOGGING as
        select 
            uppr.ancestor_concept_id,
            lowr.descendant_concept_id,
            uppr.min_levels_of_separation+lowr.min_levels_of_separation as min_levels_of_separation,
            uppr.min_levels_of_separation+lowr.min_levels_of_separation as max_levels_of_separation    
        from concept_ancestor_calc uppr 
        join concept_ancestor_calc lowr on uppr.descendant_concept_id=lowr.ancestor_concept_id
        union all select * from concept_ancestor_calc';

      vCnt := SQL%ROWCOUNT;

      EXECUTE IMMEDIATE 'drop table concept_ancestor_calc purge';

      -- Shrink and pick the shortest path for min_levels_of_separation, and the longest for max

      EXECUTE IMMEDIATE
         'create table concept_ancestor_calc NOLOGGING as
        select 
            ancestor_concept_id,
            descendant_concept_id,
            min(min_levels_of_separation) as min_levels_of_separation,
            max(max_levels_of_separation) as max_levels_of_separation
        from new_concept_ancestor_calc
        group by ancestor_concept_id, descendant_concept_id ';

      EXECUTE IMMEDIATE
         'select count(*), sum(max_levels_of_separation), sum(min_levels_of_separation) from concept_ancestor_calc'
         INTO vCnt, vSumMax, vSumMin;

      EXECUTE IMMEDIATE 'drop table new_concept_ancestor_calc purge';

      IF vIsOverLoop
      THEN
         IF vCnt = vCnt_old AND vSumMax = vSumMax_old
         THEN
            IF IsSameTableData (pTable1   => 'concept_ancestor_calc',
                                pTable2   => 'concept_ancestor_calc_bkp')
            THEN
               EXIT;
            ELSE
               RETURN;
            END IF;
         ELSE
            RETURN;
         END IF;
      ELSIF vCnt = vCnt_old
      THEN
         EXECUTE IMMEDIATE
            'create table concept_ancestor_calc_bkp NOLOGGING as select * from concept_ancestor_calc ';

         vIsOverLoop := TRUE;
      END IF;

      vCnt_old := vCnt;
      vSumMax_old := vSumMax;
   END LOOP;     /********** Repeat till no new records are written *********/

   EXECUTE IMMEDIATE 'truncate table concept_ancestor';

   -- drop concept_ancestor indexes before mass insert.
   EXECUTE IMMEDIATE
      'alter table concept_ancestor disable constraint XPKCONCEPT_ANCESTOR';

   EXECUTE IMMEDIATE
      'insert /*+ APPEND */ into concept_ancestor
    select a.* from concept_ancestor_calc a
    join concept c1 on a.ancestor_concept_id=c1.concept_id
    join concept c2 on a.descendant_concept_id=c2.concept_id
    where c1.standard_concept is not null and c2.standard_concept is not null 
    ';

   COMMIT;

   -- Add connections to self for those vocabs having at least one concept in the concept_relationship table
   INSERT /*+ APPEND */
      INTO  concept_ancestor
   SELECT c.concept_id AS ancestor_concept_id,
          c.concept_id AS descendant_concept_id,
          0 AS MIN_LEVELS_OF_SEPARATION,
          0 AS MAX_LEVELS_OF_SEPARATION
     FROM concept c
    WHERE     c.vocabulary_id IN (SELECT c1.vocabulary_id
                                    FROM concept_relationship r,
                                         concept c1
                                   WHERE c1.concept_id = r.concept_id_1
                                  UNION
                                  SELECT c2.vocabulary_id
                                    FROM concept_relationship r,
                                         concept c2
                                   WHERE c2.concept_id = r.concept_id_2)
          AND c.invalid_reason IS NULL
          AND c.standard_concept IS NOT NULL;
   COMMIT;

   EXECUTE IMMEDIATE
      'alter table concept_ancestor enable constraint XPKCONCEPT_ANCESTOR';

   -- Clean up
   EXECUTE IMMEDIATE 'drop table concept_ancestor_calc purge';

   EXECUTE IMMEDIATE 'drop table concept_ancestor_calc_bkp purge';
   
   DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_ancestor', estimate_percent  => null, cascade  => true);


	-- Update existing records and add missing relationships between concepts for RxNorm
	--update
	merge into concept_ancestor ca
	using (
		select 
		c.concept_id as ancestor_concept_id,
		rxn_down.descendant_concept_id as descendant_concept_id,
		min(c_up.min_levels_of_separation+jump.min_jump_level+rxn_down.min_levels_of_separation+rxn_up.min_levels_of_separation) as min_levels_of_separation,
		max(c_up.max_levels_of_separation+jump.max_levels_of_separation+rxn_down.max_levels_of_separation+rxn_up.max_levels_of_separation) as max_levels_of_separation
		from (
			select concept_id, vocabulary_id, jump_concept_id, min_jump_level, max_levels_of_separation from (
				select in_class.concept_id, in_class.vocabulary_id, jump.concept_id as jump_concept_id, min_levels_of_separation, max_levels_of_separation,
				first_value(min_levels_of_separation) over(partition by in_class.concept_id order by min_levels_of_separation) as min_jump_level 
				from concept_ancestor top_class 
				join concept in_class on in_class.concept_id=top_class.ancestor_concept_id and in_class.vocabulary_id!='RxNorm' and in_class.standard_concept='C'
				join concept jump on jump.concept_id=top_class.descendant_concept_id and jump.vocabulary_id='RxNorm' and jump.concept_class_id not in ('Branded Pack', 'Clinical Pack')
			) where min_jump_level=min_levels_of_separation    
		) jump
		
		join concept_ancestor c_up on c_up.descendant_concept_id=jump.concept_id
		join concept c on c.concept_id=c_up.ancestor_concept_id and c.vocabulary_id=jump.vocabulary_id and c.standard_concept='C'


		join concept_ancestor rxn_down on rxn_down.ancestor_concept_id=jump.jump_concept_id

		join concept_ancestor rxn_up on rxn_up.descendant_concept_id=jump.jump_concept_id
		join concept top_rxn on top_rxn.concept_id=rxn_up.ancestor_concept_id and top_rxn.vocabulary_id='RxNorm' and top_rxn.concept_class_id='Ingredient'
		group by c.concept_id, rxn_down.descendant_concept_id
	) i on (ca.ancestor_concept_id=i.ancestor_concept_id and ca.descendant_concept_id=i.descendant_concept_id)
	when matched then
		update set ca.min_levels_of_separation=i.min_levels_of_separation, ca.max_levels_of_separation=i.max_levels_of_separation
		where ca.min_levels_of_separation<>i.min_levels_of_separation or ca.max_levels_of_separation<>i.max_levels_of_separation;
	commit;

	--insert
	merge into concept_ancestor ca
	using (
		select 
		c.concept_id as ancestor_concept_id,
		top_rxn.concept_id as descendant_concept_id,
		min((c_up.min_levels_of_separation+jump.min_jump_level)-rxn_up.min_levels_of_separation) as min_levels_of_separation,
		max((c_up.max_levels_of_separation+jump.max_levels_of_separation)-rxn_up.max_levels_of_separation) as max_levels_of_separation
		from (
			select concept_id, vocabulary_id, jump_concept_id, min_jump_level, max_levels_of_separation, jump_concept_name from (
				select in_class.concept_id, in_class.vocabulary_id, jump.concept_id as jump_concept_id, min_levels_of_separation, max_levels_of_separation,
				jump.concept_name as jump_concept_name,
				first_value(min_levels_of_separation) over(partition by in_class.concept_id order by min_levels_of_separation) as min_jump_level 
				from concept_ancestor top_class 
				join concept in_class on in_class.concept_id=top_class.ancestor_concept_id and in_class.vocabulary_id!='RxNorm' and in_class.standard_concept='C'
				join concept jump on jump.concept_id=top_class.descendant_concept_id and jump.vocabulary_id='RxNorm' and jump.concept_class_id not in ('Branded Pack', 'Clinical Pack')
			) where min_jump_level=min_levels_of_separation    
		) jump 

		join concept_ancestor c_up on c_up.descendant_concept_id=jump.concept_id
		join concept c on c.concept_id=c_up.ancestor_concept_id and c.vocabulary_id=jump.vocabulary_id and c.standard_concept='C'

		join concept_ancestor rxn_up on rxn_up.descendant_concept_id=jump.jump_concept_id
		join concept top_rxn on top_rxn.concept_id=rxn_up.ancestor_concept_id and top_rxn.vocabulary_id='RxNorm' 
		and 
		(
			(jump_concept_name like '% / %' and (
				(top_rxn.concept_class_id not in ('Ingredient', 'Clinical Drug Comp') and lower(c.concept_name) not like '%combination%')
				or
				lower(c.concept_name) like '%combination%'
				)
			)
			or
			jump_concept_name not like '% / %'
		)
		group by c.concept_id, top_rxn.concept_id
	) i on (ca.ancestor_concept_id=i.ancestor_concept_id and ca.descendant_concept_id=i.descendant_concept_id)
	when not matched then 
		insert values (i.ancestor_concept_id, i.descendant_concept_id, i.min_levels_of_separation, i.max_levels_of_separation);
	commit;

	-- Update existing records and add missing relationships between concepts for RxNorm Extension
	--update	
	merge into concept_ancestor ca
	using (
		select 
		c.concept_id as ancestor_concept_id,
		rxn_down.descendant_concept_id as descendant_concept_id,
		min(c_up.min_levels_of_separation+jump.min_jump_level+rxn_down.min_levels_of_separation+rxn_up.min_levels_of_separation) as min_levels_of_separation,
		max(c_up.max_levels_of_separation+jump.max_levels_of_separation+rxn_down.max_levels_of_separation+rxn_up.max_levels_of_separation) as max_levels_of_separation
		from (
			select concept_id, vocabulary_id, jump_concept_id, min_jump_level, max_levels_of_separation from (
				select in_class.concept_id, in_class.vocabulary_id, jump.concept_id as jump_concept_id, min_levels_of_separation, max_levels_of_separation,
				first_value(min_levels_of_separation) over(partition by in_class.concept_id order by min_levels_of_separation) as min_jump_level 
				from concept_ancestor top_class 
				join concept in_class on in_class.concept_id=top_class.ancestor_concept_id and in_class.vocabulary_id!='RxNorm Extension' and in_class.standard_concept='C'
				join concept jump on jump.concept_id=top_class.descendant_concept_id and jump.vocabulary_id='RxNorm Extension' and jump.concept_class_id not in ('Branded Pack', 'Clinical Pack')
			) where min_jump_level=min_levels_of_separation    
		) jump
		
		join concept_ancestor c_up on c_up.descendant_concept_id=jump.concept_id
		join concept c on c.concept_id=c_up.ancestor_concept_id and c.vocabulary_id=jump.vocabulary_id and c.standard_concept='C'


		join concept_ancestor rxn_down on rxn_down.ancestor_concept_id=jump.jump_concept_id

		join concept_ancestor rxn_up on rxn_up.descendant_concept_id=jump.jump_concept_id
		join concept top_rxn on top_rxn.concept_id=rxn_up.ancestor_concept_id and top_rxn.vocabulary_id='RxNorm Extension' and top_rxn.concept_class_id='Ingredient'
		group by c.concept_id, rxn_down.descendant_concept_id
	) i on (ca.ancestor_concept_id=i.ancestor_concept_id and ca.descendant_concept_id=i.descendant_concept_id)
	when matched then
		update set ca.min_levels_of_separation=i.min_levels_of_separation, ca.max_levels_of_separation=i.max_levels_of_separation
		where ca.min_levels_of_separation<>i.min_levels_of_separation or ca.max_levels_of_separation<>i.max_levels_of_separation;
	commit;

	--insert
	merge into concept_ancestor ca
	using (
		select 
		c.concept_id as ancestor_concept_id,
		top_rxn.concept_id as descendant_concept_id,
		min((c_up.min_levels_of_separation+jump.min_jump_level)-rxn_up.min_levels_of_separation) as min_levels_of_separation,
		max((c_up.max_levels_of_separation+jump.max_levels_of_separation)-rxn_up.max_levels_of_separation) as max_levels_of_separation
		from (
			select concept_id, vocabulary_id, jump_concept_id, min_jump_level, max_levels_of_separation, jump_concept_name from (
				select in_class.concept_id, in_class.vocabulary_id, jump.concept_id as jump_concept_id, min_levels_of_separation, max_levels_of_separation,
				jump.concept_name as jump_concept_name,
				first_value(min_levels_of_separation) over(partition by in_class.concept_id order by min_levels_of_separation) as min_jump_level 
				from concept_ancestor top_class 
				join concept in_class on in_class.concept_id=top_class.ancestor_concept_id and in_class.vocabulary_id!='RxNorm Extension' and in_class.standard_concept='C'
				join concept jump on jump.concept_id=top_class.descendant_concept_id and jump.vocabulary_id='RxNorm Extension' and jump.concept_class_id not in ('Branded Pack', 'Clinical Pack')
			) where min_jump_level=min_levels_of_separation    
		) jump 

		join concept_ancestor c_up on c_up.descendant_concept_id=jump.concept_id
		join concept c on c.concept_id=c_up.ancestor_concept_id and c.vocabulary_id=jump.vocabulary_id and c.standard_concept='C'

		join concept_ancestor rxn_up on rxn_up.descendant_concept_id=jump.jump_concept_id
		join concept top_rxn on top_rxn.concept_id=rxn_up.ancestor_concept_id and top_rxn.vocabulary_id='RxNorm Extension' 
		and 
		(
			(jump_concept_name like '% / %' and (
				(top_rxn.concept_class_id not in ('Ingredient', 'Clinical Drug Comp') and lower(c.concept_name) not like '%combination%')
				or
				lower(c.concept_name) like '%combination%'
				)
			)
			or
			jump_concept_name not like '% / %'
		)
		group by c.concept_id, top_rxn.concept_id
	) i on (ca.ancestor_concept_id=i.ancestor_concept_id and ca.descendant_concept_id=i.descendant_concept_id)
	when not matched then 
		insert values (i.ancestor_concept_id, i.descendant_concept_id, i.min_levels_of_separation, i.max_levels_of_separation);
	commit;

	DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_ancestor', estimate_percent  => null, cascade  => true);
	
	--replace all RxNorm internal links so only "neighbor" concepts are connected
	--create table with neighbor relationships
	EXECUTE IMMEDIATE q'[
		create table rxnorm_allowed_rel nologging as (
		select 'Brand Name' c_class_1, 'RxNorm ing of' relationship_id, 'Branded Drug Box' c_class_2 from dual union all
		select 'Brand Name', 'RxNorm ing of', 'Branded Drug Comp' from dual union  all
		select 'Brand Name', 'RxNorm ing of', 'Branded Drug Form' from dual union  all
		select 'Brand Name', 'RxNorm ing of', 'Branded Drug' from dual union  all
		select 'Brand Name', 'RxNorm ing of', 'Marketed Product' from dual union  all
		select 'Brand Name', 'RxNorm ing of', 'Quant Branded Box' from dual union  all
		select 'Brand Name', 'RxNorm ing of', 'Quant Branded Drug' from dual union  all
		select 'Branded Drug Box', 'Has marketed form', 'Marketed Product' from dual union  all
		select 'Branded Drug Box', 'Has quantified form', 'Quant Branded Box' from dual union  all
		select 'Branded Drug Comp', 'Constitutes', 'Branded Drug' from dual union  all
		select 'Branded Drug Form', 'RxNorm inverse is a', 'Branded Drug' from dual union  all
		select 'Branded Drug', 'Available as box', 'Branded Drug Box' from dual union  all
		select 'Branded Drug', 'Has marketed form', 'Marketed Product' from dual union  all
		select 'Branded Drug', 'Has quantified form', 'Quant Branded Drug' from dual union  all
		select 'Branded Pack', 'Contains', 'Branded Drug' from dual union  all
		select 'Branded Pack', 'Contains', 'Clinical Drug' from dual union  all
		select 'Branded Pack', 'Contains', 'Quant Branded Drug' from dual union  all
		select 'Branded Pack', 'Contains', 'Quant Clinical Drug' from dual union all
		select 'Branded Pack', 'Has marketed form', 'Marketed Product' from dual union  all
		select 'Clinical Drug Box', 'Has marketed form', 'Marketed Product' from dual union  all
		select 'Clinical Drug Box', 'Has quantified form', 'Quant Clinical Box' from dual union all
		select 'Clinical Drug Box', 'Has tradename', 'Branded Drug Box' from dual union all
		select 'Clinical Drug Comp', 'Constitutes', 'Clinical Drug' from dual union all
		select 'Clinical Drug Comp', 'Has tradename', 'Branded Drug Comp' from dual union all
		select 'Clinical Drug Form', 'Has tradename', 'Branded Drug Form' from dual union all
		select 'Clinical Drug Form', 'RxNorm inverse is a', 'Clinical Drug' from dual union all
		select 'Clinical Drug', 'Available as box', 'Clinical Drug Box' from dual union all
		select 'Clinical Drug', 'Has marketed form', 'Marketed Product' from dual union all
		select 'Clinical Drug', 'Has quantified form', 'Quant Clinical Drug' from dual union all
		select 'Clinical Drug', 'Has tradename', 'Branded Drug' from dual union all
		select 'Clinical Pack', 'Contains', 'Branded Drug' from dual union all
		select 'Clinical Pack', 'Contains', 'Clinical Drug' from dual union all
		select 'Clinical Pack', 'Contains', 'Quant Branded Drug' from dual union all
		select 'Clinical Pack', 'Contains', 'Quant Clinical Drug' from dual union all
		select 'Clinical Pack', 'Has marketed form', 'Marketed Product' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Branded Drug Box' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Branded Drug Form' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Branded Drug' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Branded Pack' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Box' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Form' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Clinical Drug' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Clinical Pack' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Marketed Product' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Quant Branded Box' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Quant Branded Drug' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Box' from dual union all
		select 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Drug' from dual union all
		select 'Ingredient', 'Has brand name', 'Brand Name' from dual union all
		select 'Ingredient', 'RxNorm ing of', 'Clinical Drug Comp' from dual union all
		select 'Ingredient', 'RxNorm ing of', 'Clinical Drug Form' from dual union all
		select 'Supplier', 'Supplier of', 'Marketed Product' from dual union all
		select 'Quant Branded Box', 'Has marketed form', 'Marketed Product' from dual union all
		select 'Quant Branded Drug', 'Available as box', 'Quant Branded Box' from dual union all
		select 'Quant Branded Drug', 'Has marketed form', 'Marketed Product' from dual union all
		select 'Quant Clinical Box', 'Has marketed form', 'Marketed Product' from dual union all
		select 'Quant Clinical Box', 'Has tradename', 'Quant Branded Box' from dual union all
		select 'Quant Clinical Drug', 'Available as box', 'Quant Clinical Box' from dual union all
		select 'Quant Clinical Drug', 'Has marketed form', 'Marketed Product' from dual union all
		select 'Quant Clinical Drug', 'Has tradename', 'Quant Branded Drug' from dual
	)]';

	--create table with wrong relationships (non-neighbor relationships)
	EXECUTE IMMEDIATE q'[
		create table rxnorm_wrong_rel nologging as
		select c1.concept_class_id, r.concept_id_1, r.concept_id_2, r.relationship_id From concept c1, concept c2, concept_relationship r
		where c1.concept_id=r.concept_id_1
		and c2.concept_id=r.concept_id_2
		and r.invalid_reason is null
		and c1.vocabulary_id='RxNorm'
		and c2.vocabulary_id='RxNorm'
		and r.relationship_id not in ('Maps to','Precise ing of','Concept replaces','Mapped from','Concept replaced by')
		and c2.concept_class_id not like '%Pack'
		and (c1.concept_class_id,c2.concept_class_id) not in (select c_class_1, c_class_2 from rxnorm_allowed_rel)
	]';

	--add missing neighbor relationships (if not exists)
	EXECUTE IMMEDIATE q'[
	merge into concept_relationship r
	using (
		select ca1.ancestor_concept_id c_id1, ca2.ancestor_concept_id c_id2, rra.relationship_id From rxnorm_wrong_rel wr,
		concept_ancestor ca1, concept_ancestor ca2, rxnorm_allowed_rel rra, concept c_dest 
		where 
		 ca1.descendant_concept_id=ca2.ancestor_concept_id
		and ca1.ancestor_concept_id=wr.concept_id_1 and ca2.descendant_concept_id=wr.concept_id_2
		and ca2.ancestor_concept_id<>ca2.descendant_concept_id
		and ca2.ancestor_concept_id<>ca1.ancestor_concept_id
		and c_dest.concept_id=ca2.ancestor_concept_id
		and rra.c_class_1=wr.concept_class_id
		and rra.c_class_2=c_dest.concept_class_id
	) i on (r.concept_id_1=i.c_id1 and r.concept_id_2=i.c_id2 and r.relationship_id=i.relationship_id)
	when not matched then insert
		(concept_id_1,
		concept_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason)
	values (
		i.c_id1,
		i.c_id2,
		i.relationship_id,
		trunc(sysdate),
		to_date ('20991231', 'YYYYMMDD'),
		null
	)
	]';
	commit;

	--deprecate wrong relationships
	EXECUTE IMMEDIATE q'[
	update concept_relationship set valid_end_date=trunc(sysdate), invalid_reason='D'
	where (concept_id_1, concept_id_2, relationship_id) in (select concept_id_1, concept_id_2, relationship_id From rxnorm_wrong_rel)
	and invalid_reason is null
	]';
	commit;

	--clean up
	EXECUTE IMMEDIATE 'drop table rxnorm_allowed_rel purge';
	EXECUTE IMMEDIATE 'drop table rxnorm_wrong_rel purge';
end;
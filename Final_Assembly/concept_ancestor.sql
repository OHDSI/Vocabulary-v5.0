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


	-- Update existing records and add missing relationships between concepts
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

	DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_ancestor', estimate_percent  => null, cascade  => true);
end;
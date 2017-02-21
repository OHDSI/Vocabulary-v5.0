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
   z number;

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
    --check if table exists
    SELECT COUNT (*)
           INTO z
           FROM user_tables
          WHERE table_name = 'CONCEPT_ANCESTOR';
    
    IF Z=0 THEN
    --table doesn't exists, creating...
      EXECUTE IMMEDIATE 'CREATE TABLE CONCEPT_ANCESTOR NOLOGGING AS SELECT * FROM DEVV5.CONCEPT_ANCESTOR WHERE 1=0';
      EXECUTE IMMEDIATE 'ALTER TABLE CONCEPT_ANCESTOR ADD CONSTRAINT xpkconcept_ancestor PRIMARY KEY (ancestor_concept_id,descendant_concept_id)';
    END IF;

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

   BEGIN
      EXECUTE IMMEDIATE 'drop table rxnorm_allowed_rel purge';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   BEGIN
      EXECUTE IMMEDIATE 'drop table rxnorm_wrong_rel purge';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;
   
   BEGIN
      EXECUTE IMMEDIATE 'drop table pair_tbl purge';
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

    --create temp table 'pair'
    EXECUTE IMMEDIATE q'[CREATE TABLE pair_tbl
    NOLOGGING
    AS
       SELECT DISTINCT /* there are many redundant pairs*/
                      class_rxn.ancestor_concept_id AS class_concept_id, rxn_up.concept_id AS rxn_concept_id
         FROM concept_ancestor class_rxn
              -- get all hierarchical relationships between concepts 'C' ...
              JOIN concept dc ON dc.concept_id = class_rxn.ancestor_concept_id AND dc.standard_concept = 'C' AND dc.domain_id = 'Drug'
              -- ... and 'S'
              JOIN concept rxn
                 ON     rxn.concept_id = class_rxn.descendant_concept_id
                    AND rxn.standard_concept = 'S'
                    AND rxn.domain_id = 'Drug'
                    --AND rxn.concept_class_id NOT IN ('Branded Pack', 'Clinical Pack')
                    AND rxn.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
              -- connect all concepts inside the rxn hierachy. Some of them might be above the jump
              JOIN concept_ancestor in_rxn ON in_rxn.descendant_concept_id = rxn.concept_id
              JOIN concept rxn_up
                 ON     rxn_up.concept_id = in_rxn.ancestor_concept_id
                    AND rxn_up.standard_concept = 'S'
                    AND rxn_up.domain_id = 'Drug'
                    --AND rxn_up.concept_class_id NOT IN ('Branded Pack', 'Clinical Pack')
                    AND rxn_up.vocabulary_id IN ('RxNorm', 'RxNorm Extension')]';

    --and index
    EXECUTE IMMEDIATE 'CREATE INDEX idx_pair ON pair_tbl (class_concept_id) NOLOGGING';    
    DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'pair_tbl', cascade  => true);

    --Update existing records and add missing relationships between concepts for RxNorm/RxE
    EXECUTE IMMEDIATE q'[
    merge into concept_ancestor ca
    using (
    select distinct
    pair.class_concept_id as ancestor_concept_id, -- concept in drug class
    pair.rxn_concept_id as descendant_concept_id, -- concept in RxNorm hierarchy above cross-over from class to RxNorm (jump)
    min(to_bottom.min_levels_of_separation+to_ing.min_levels_of_separation) as min_levels_of_separation, -- levels in class plus the distance from ingredient to RxNorm concept
    max(to_bottom.max_levels_of_separation+to_ing.max_levels_of_separation) as max_levels_of_separation
    from pair_tbl pair
    -- get distance from class concept to lowest possible class concept
    join (
        select  ancestor_concept_id, max(min_levels_of_separation) as min_levels_of_separation, max(max_levels_of_separation) as max_levels_of_separation
        from concept_ancestor
        join concept on concept_id=descendant_concept_id and standard_concept='C' and domain_id='Drug'
        group by ancestor_concept_id
    ) to_bottom on to_bottom.ancestor_concept_id=pair.class_concept_id
    -- get distance from rxn concept to highest possible (Ingredient) rxn concept
    join concept_ancestor to_ing on to_ing.descendant_concept_id=pair.rxn_concept_id
    join concept ing on ing.concept_id=to_ing.ancestor_concept_id and ing.vocabulary_id in ('RxNorm', 'RxNorm Extension') and ing.concept_class_id='Ingredient'
    group by pair.class_concept_id, pair.rxn_concept_id
    ) i on (ca.ancestor_concept_id=i.ancestor_concept_id and ca.descendant_concept_id=i.descendant_concept_id)
    when matched then
            update set ca.min_levels_of_separation=i.min_levels_of_separation, ca.max_levels_of_separation=i.max_levels_of_separation
            where ca.min_levels_of_separation<>i.min_levels_of_separation or ca.max_levels_of_separation<>i.max_levels_of_separation
    when not matched then 
            insert values (i.ancestor_concept_id, i.descendant_concept_id, i.min_levels_of_separation, i.max_levels_of_separation)
    ]';             
    commit;
    
	DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_ancestor', estimate_percent  => null, cascade  => true);
	
	--replace all RxNorm internal links so only "neighbor" concepts are connected
	--create table with neighbor relationships
	EXECUTE IMMEDIATE q'[
		create table rxnorm_allowed_rel nologging as (
            select * From (
				with t as (
				select 'Brand Name' c_class_1, 'Brand name of' relationship_id, 'Branded Drug Box' c_class_2 from dual union all
				select 'Brand Name', 'Brand name of', 'Branded Drug Comp' from dual union all
				select 'Brand Name', 'Brand name of', 'Branded Drug Form' from dual union all
				select 'Brand Name', 'Brand name of', 'Branded Drug' from dual union all
				select 'Brand Name', 'Brand name of', 'Branded Pack' from dual union all
				select 'Brand Name', 'Brand name of', 'Branded Pack Box' from dual union all
				select 'Brand Name', 'Brand name of', 'Marketed Product' from dual union all
				select 'Brand Name', 'Brand name of', 'Quant Branded Box' from dual union all
				select 'Brand Name', 'Brand name of', 'Quant Branded Drug' from dual union all
				select 'Branded Drug Box', 'Has marketed form', 'Marketed Product' from dual union all
				select 'Branded Drug Box', 'Has quantified form', 'Quant Branded Box' from dual union all
				select 'Branded Drug Comp', 'Constitutes', 'Branded Drug' from dual union all
				select 'Branded Drug Form', 'RxNorm inverse is a', 'Branded Drug' from dual union all
				select 'Branded Drug', 'Available as box', 'Branded Drug Box' from dual union all
				select 'Branded Drug', 'Has marketed form', 'Marketed Product' from dual union all
				select 'Branded Drug', 'Has quantified form', 'Quant Branded Drug' from dual union all
				select 'Clinical Drug Box', 'Has marketed form', 'Marketed Product' from dual union
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
				select 'Marketed Product', 'Has marketed form', 'Marketed Product' from dual union all 
				select 'Supplier', 'Supplier of', 'Marketed Product' from dual union all
				select 'Quant Branded Box', 'Has marketed form', 'Marketed Product' from dual union all
				select 'Quant Branded Drug', 'Available as box', 'Quant Branded Box' from dual union all
				select 'Quant Branded Drug', 'Has marketed form', 'Marketed Product' from dual union all
				select 'Quant Clinical Box', 'Has marketed form', 'Marketed Product' from dual union all
				select 'Quant Clinical Box', 'Has tradename', 'Quant Branded Box' from dual union all
				select 'Quant Clinical Drug', 'Available as box', 'Quant Clinical Box' from dual union all
				select 'Quant Clinical Drug', 'Has marketed form', 'Marketed Product' from dual union all
				select 'Quant Clinical Drug', 'Has tradename', 'Quant Branded Drug' from dual
            ) 
            select * from t 
            union all 
			--add reverse
            select c_class_2, r.reverse_relationship_id, c_class_1 
            from t rra, relationship r
            where rra.relationship_id=r.relationship_id
        )
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
		and r.relationship_id not in ('Maps to','Precise ing of','Has precise ing','Concept replaces','Mapped from','Concept replaced by')
		and (c1.concept_class_id not like '%Pack' or c2.concept_class_id not like '%Pack')
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
 
	--create direct links between Branded* and Brand Names
    MERGE INTO concept_relationship r
         USING (SELECT DISTINCT c1.concept_id                    AS concept_id_1,
                                c2.concept_id                    AS concept_id_2,
                                'Has brand name'                 AS relationship_id,
                                TRUNC (SYSDATE)                  AS valid_start_date,
                                TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date
                  FROM concept_ancestor     ca,
                       concept_relationship r,
                       concept              c1,
                       concept              c2,
                       concept              c3
                 WHERE     ca.ancestor_concept_id = r.concept_id_1
                       AND r.invalid_reason IS NULL
                       AND relationship_id = 'Has brand name'
                       AND ca.descendant_concept_id = c1.concept_id
                       AND c1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                       AND c1.concept_class_id IN ('Branded Drug Box',
                                                   'Quant Branded Box',
                                                   'Branded Drug Comp',
                                                   'Quant Branded Drug',
                                                   'Branded Drug Form',
                                                   'Branded Drug',
                                                   'Marketed Product',
                                                   'Branded Pack',
                                                   'Branded Pack Box')
                       AND r.concept_id_2 = c2.concept_id
                       AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                       AND c2.concept_class_id = 'Brand Name'
                       AND c3.concept_id = r.concept_id_1
                       AND c3.concept_class_id <> 'Ingredient') i
            ON (r.concept_id_1 = i.concept_id_1 AND r.concept_id_2 = i.concept_id_2 AND r.relationship_id = i.relationship_id)
    WHEN NOT MATCHED
    THEN
       INSERT     (concept_id_1,
                   concept_id_2,
                   relationship_id,
                   valid_start_date,
                   valid_end_date,
                   invalid_reason)
           VALUES (i.concept_id_1,
                   i.concept_id_2,
                   i.relationship_id,
                   i.valid_start_date,
                   i.valid_end_date,
                   NULL)
    WHEN MATCHED
    THEN
       UPDATE SET r.invalid_reason = NULL, r.valid_end_date = i.valid_end_date
               WHERE r.invalid_reason IS NOT NULL;

     --reverse
    MERGE INTO concept_relationship r
         USING (SELECT DISTINCT c1.concept_id                    AS concept_id_1,
                                c2.concept_id                    AS concept_id_2,
                                'Brand name of'                  AS relationship_id,
                                TRUNC (SYSDATE)                  AS valid_start_date,
                                TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date
                  FROM concept_ancestor     ca,
                       concept_relationship r,
                       concept              c1,
                       concept              c2,
                       concept              c3
                 WHERE     ca.ancestor_concept_id = r.concept_id_2
                       AND r.invalid_reason IS NULL
                       AND relationship_id = 'Brand name of'
                       AND ca.descendant_concept_id = c2.concept_id
                       AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                       AND c2.concept_class_id IN ('Branded Drug Box',
                                                   'Quant Branded Box',
                                                   'Branded Drug Comp',
                                                   'Quant Branded Drug',
                                                   'Branded Drug Form',
                                                   'Branded Drug',
                                                   'Marketed Product',
                                                   'Branded Pack',
                                                   'Branded Pack Box')
                       AND r.concept_id_1 = c1.concept_id
                       AND c1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                       AND c1.concept_class_id = 'Brand Name'
                       AND c3.concept_id = r.concept_id_2
                       AND c3.concept_class_id <> 'Ingredient') i
            ON (r.concept_id_1 = i.concept_id_1 AND r.concept_id_2 = i.concept_id_2 AND r.relationship_id = i.relationship_id)
    WHEN NOT MATCHED
    THEN
       INSERT     (concept_id_1,
                   concept_id_2,
                   relationship_id,
                   valid_start_date,
                   valid_end_date,
                   invalid_reason)
           VALUES (i.concept_id_1,
                   i.concept_id_2,
                   i.relationship_id,
                   i.valid_start_date,
                   i.valid_end_date,
                   NULL)
    WHEN MATCHED
    THEN
       UPDATE SET r.invalid_reason = NULL, r.valid_end_date = i.valid_end_date
               WHERE r.invalid_reason IS NOT NULL;
	COMMIT;

	--clean up
	EXECUTE IMMEDIATE 'drop table rxnorm_allowed_rel purge';
	EXECUTE IMMEDIATE 'drop table rxnorm_wrong_rel purge';
	EXECUTE IMMEDIATE 'drop table pair_tbl purge';   
end;
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
END;
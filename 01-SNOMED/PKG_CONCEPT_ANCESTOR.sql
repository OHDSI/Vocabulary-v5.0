
--log table
CREATE TABLE APPLICATION_LOG
(
  DT              DATE,
  AL_NAME         VARCHAR2(100 BYTE),
  PROCEDURE_NAME  VARCHAR2(100 BYTE),
  AL_DETAIL       VARCHAR2(4000 BYTE)
);

--procedure for filling logs
CREATE OR REPLACE PROCEDURE add_application_log (
   pApplication_name   IN application_log.al_name%TYPE,
   pProcedure_name     IN application_log.procedure_name%TYPE DEFAULT NULL,
   pDetail             IN VARCHAR2 DEFAULT NULL)
IS
   -- 22-SEP-2014. Created. Detail application logging.
   vApplication_name   application_log.al_name%TYPE;
   vProcedure_name     application_log.procedure_name%TYPE;
   vDetail             application_log.al_detail%TYPE;
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   vApplication_name := SUBSTRB (pApplication_name, 1, 100);
   vProcedure_name := SUBSTRB (pProcedure_name, 1, 100);
   vDetail := SUBSTRB (pDetail, 1, 4000);

   INSERT INTO application_log (dt, al_name, procedure_name, al_detail)
        VALUES (sysdate, vApplication_name, vProcedure_name, vDetail);

   COMMIT;
END add_application_log;
/


--spec for SNOMED ancestor
CREATE OR REPLACE package pkg_concept_ancestor is
  -- Created : 21.09.2014 17:17:32
  -- Purpose : Script to create hieararchy tree 
  
  function IsSameTableData (pTable1 in varchar2, pTable2 in varchar2 ) return boolean;

  procedure calc;
  
end pkg_concept_ancestor;
/


--body
CREATE OR REPLACE package body pkg_concept_ancestor is

  ------------------------------------------------------------------------
  function IsSameTableData (pTable1 in varchar2, pTable2 in varchar2 ) return boolean
  is
    vRefCursor sys_refcursor;
    vDummy char(1);
    
    res boolean;
  begin
    open vRefCursor for 'select null as col1 from ( select * from ' || pTable1 ||' minus select * from ' || pTable2 || ' )';
      fetch vRefCursor into vDummy;
      res := vRefCursor%NOTFOUND;
    close vRefCursor;
    
    return res;
  end IsSameTableData;
  ------------------------------------------------------------------------
  procedure calc
  is
    vApplication_name constant varchar2(20) := 'SNOMED_ANSESTOR';
    vProcedure_name constant varchar2(50) := 'CALC';
    
    vCnt integer;
    vCnt_old integer;
    vSumMax integer;
    vSumMax_old integer;
    vSumMin integer;
    vIsOverLoop boolean;
  begin
    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'Start' );

    -- Clean up before
    begin execute immediate 'drop table snomed_ancestor_calc purge'; exception when others then null; end;
    begin execute immediate 'drop table snomed_ancestor_calc_bkp purge'; exception when others then null; end;
    begin execute immediate 'drop table new_snomed_ancestor_calc purge'; exception when others then null; end;

    -- Seed the table by loading all first-level (parent-child) relationships
    
    execute immediate 'create table snomed_ancestor_calc as
    select 
      r.concept_code_1 as ancestor_concept_code,
      r.concept_code_2 as descendant_concept_code,
      case when s.is_hierarchical=1 then 1 else 0 end as min_levels_of_separation,
      case when s.is_hierarchical=1 then 1 else 0 end as max_levels_of_separation
    from concept_relationship_stage r 
    join relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
    and r.vocabulary_id_1=''SNOMED''';
   
    /********** Repeat till no new records are written *********/
    for i in 1 .. 100
    loop
      -- create all new combinations
      add_application_log ( pApplication_name => vApplication_name
                           ,pProcedure_name => vProcedure_name
                           ,pDetail => 'Begin new_snomed_ancestor_calc i=' || i );
                           
      execute immediate ' create table new_snomed_ancestor_calc as
        select 
            uppr.ancestor_concept_code,
            lowr.descendant_concept_code,
            uppr.min_levels_of_separation+lowr.min_levels_of_separation as min_levels_of_separation,
            uppr.min_levels_of_separation+lowr.min_levels_of_separation as max_levels_of_separation    
        from snomed_ancestor_calc uppr 
        join snomed_ancestor_calc lowr on uppr.descendant_concept_code=lowr.ancestor_concept_code
        union all select * from snomed_ancestor_calc ';
      
      --execute immediate 'select count(*) as cnt from new_snomed_ancestor_calc' into vCnt;
      vCnt:=SQL%ROWCOUNT;

      add_application_log ( pApplication_name => vApplication_name
                           ,pProcedure_name => vProcedure_name
                           ,pDetail => 'End new_snomed_ancestor_calc i=' || i || ' cnt=' || vCnt );

      execute immediate 'drop table snomed_ancestor_calc purge';
      
      -- Shrink and pick the shortest path for min_levels_of_separation, and the longest for max     
      add_application_log ( pApplication_name => vApplication_name
                     ,pProcedure_name => vProcedure_name
                     ,pDetail => 'Begin snomed_ancestor_calc i=' || i );
                     
      execute immediate 'create table snomed_ancestor_calc as
        select 
            ancestor_concept_code,
            descendant_concept_code,
            min(min_levels_of_separation) as min_levels_of_separation,
            max(max_levels_of_separation) as max_levels_of_separation
        from new_snomed_ancestor_calc
        group by ancestor_concept_code, descendant_concept_code ';

      execute immediate 'select count(*), sum(max_levels_of_separation), sum(min_levels_of_separation) from snomed_ancestor_calc' into vCnt, vSumMax, vSumMin;
      
      add_application_log ( pApplication_name => vApplication_name
       ,pProcedure_name => vProcedure_name
       ,pDetail => 'End snomed_ancestor_calc i=' || i  || ' cnt=' || vCnt || ' SumMax=' || vSumMax || ' SumMin=' || vSumMin );

      execute immediate 'drop table new_snomed_ancestor_calc purge';
      
      if vIsOverLoop then
          add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'loop exit i=' || i );
          
          if vCnt = vCnt_old and vSumMax = vSumMax_old
            then
              if IsSameTableData ( pTable1 => 'snomed_ancestor_calc',pTable2 => 'snomed_ancestor_calc_bkp' )
                then
                  add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name
                          ,pDetail => 'Table same. loop exit i=' || i );
                  exit;
                else
                  add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name
                          ,pDetail => 'Table different. loop return i=' || i );
                  return;
              end if;
            else
              add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name
                , pDetail => 'Table count different. loop return i=' || i );
              return;
          end if;
      elsif vCnt = vCnt_old then
        add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'count same. loop i=' || i );
        execute immediate 'create table snomed_ancestor_calc_bkp as select * from snomed_ancestor_calc ';
        vIsOverLoop := true;
      end if;               
      
      vCnt_old := vCnt;
      vSumMax_old := vSumMax;
    end loop; /********** Repeat till no new records are written *********/
    
    add_application_log ( pApplication_name => vApplication_name
                     ,pProcedure_name => vProcedure_name
                     --,pDetail => 'Remove all non-Standard concepts (standard_concept is null)' );
                     ,pDetail => 'Get all concepts' );

    execute immediate 'truncate table snomed_ancestor';
    
    -- drop snomed_ancestor indexes before mass insert.
    execute immediate 'alter table snomed_ancestor disable constraint XPKSNOMED_ANCESTOR';

    execute immediate 'insert into snomed_ancestor
    select a.* from snomed_ancestor_calc a
    join concept_stage c1 on a.ancestor_concept_code=c1.concept_code and c1.vocabulary_id=''SNOMED''
    join concept_stage c2 on a.descendant_concept_code=c2.concept_code and c2.vocabulary_id=''SNOMED''
';
    commit;
    
    -- Create snomed_ancestor indexes after mass insert.
    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'Enable snomed_ancestor PK' );
    execute immediate 'alter table snomed_ancestor enable constraint XPKSNOMED_ANCESTOR';

    -- Clean up       
    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'Clean up' );
   -- execute immediate 'drop table new_snomed_ancestor_calc purge';    
    execute immediate 'drop table snomed_ancestor_calc purge';
    execute immediate 'drop table snomed_ancestor_calc_bkp purge';

    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'End' );
  
   commit;
  exception when others then
    add_application_log ( pApplication_name => 'SNOMED_ANSESTOR'
                         ,pProcedure_name => 'CALC SqlCode=' || sqlcode
                         ,pDetail => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace );
    raise;
    
  end calc;
  ------------------------------------------------------
  

end pkg_concept_ancestor;
/

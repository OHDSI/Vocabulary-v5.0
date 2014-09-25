create or replace package pkg_concept_ancestor is
  -- Created : 21.09.2014 17:17:32
  -- Purpose : Script to create hieararchy tree 
  --
  -- 25-sep-2014: Adapted to ver.5
  
  
  -- Public type declarations
  --type <TypeName> is <Datatype>;
  
  -- Public constant declarations
  --<ConstantName> constant <Datatype> := <Value>;

  -- Public variable declarations
  --<VariableName> <Datatype>;

  -- Public function and procedure declarations
  --function <FunctionName>(<Parameter> <Datatype>) return <Datatype>;
  procedure calc;


end pkg_concept_ancestor;
/
create or replace package body pkg_concept_ancestor is

  -- Private type declarations
  --type <TypeName> is <Datatype>;
  
  -- Private constant declarations
  --<ConstantName> constant <Datatype> := <Value>;

  -- Private variable declarations
  --<VariableName> <Datatype>;

  -- Function and procedure implementations
  procedure calc
  is
    vApplication_name constant varchar2(20) := 'CONCEPT_ANSESTOR';
    vProcedure_name constant varchar2(50) := 'CALC';
    
    vCnt integer;
    vSum integer;
    vCnt_old integer;
  begin
    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'Start' );

    -- Clean up before
    begin execute immediate 'drop table concept_ancestor_calc purge';
    exception when others then null; end;
    
    begin execute immediate 'drop table new_concept_ancestor_calc purge';
    exception when others then null; end;

    -- Seed the table by loading all first-level (parent-child) relationships
    execute immediate 'create table concept_ancestor_calc as
select 
  r.concept_id_1 as ancestor_concept_id,
  r.concept_id_2 as descendant_concept_id,
  case when s.is_hierarchical=1 and c1.standard_concept is not null then 1 else 0 end as min_levels_of_separation,
  case when s.is_hierarchical=1 and c1.standard_concept is not null then 1 else 0 end as max_levels_of_separation
from concept_relationship r 
join relationship s on s.relationship_code = r.relationship_code and s.defines_ancestry=1
join concept c1 on c1.concept_id=r.concept_id_1 and c1.invalid_reason is null
join concept c2 on c2.concept_id=r.concept_id_2 and c1.invalid_reason is null
where r.invalid_reason is null ';
   
    /********** Repeat till no new records are written *********/
    for i in 1 .. 100
    loop
      -- create all new combinations
      add_application_log ( pApplication_name => vApplication_name
                           ,pProcedure_name => vProcedure_name
                           ,pDetail => 'Begin new_concept_ancestor_calc i=' || i );
                           
      execute immediate ' create table new_concept_ancestor_calc as
select 
	uppr.ancestor_concept_id,
	lowr.descendant_concept_id,
	uppr.min_levels_of_separation+lowr.min_levels_of_separation as min_levels_of_separation,
	uppr.min_levels_of_separation+lowr.min_levels_of_separation as max_levels_of_separation	
from concept_ancestor_calc uppr 
join concept_ancestor_calc lowr on uppr.descendant_concept_id=lowr.ancestor_concept_id
union all select * from concept_ancestor_calc ';
      
      execute immediate 'select count(*) as cnt from new_concept_ancestor_calc' into vCnt;

      add_application_log ( pApplication_name => vApplication_name
                           ,pProcedure_name => vProcedure_name
                           ,pDetail => 'End new_concept_ancestor_calc i=' || i || ' cnt=' || vCnt );

      execute immediate 'drop table concept_ancestor_calc purge';
      
      -- Shrink and pick the shortest path for min_levels_of_separation, and the longest for max     
      add_application_log ( pApplication_name => vApplication_name
                     ,pProcedure_name => vProcedure_name
                     ,pDetail => 'Begin concept_ancestor_calc i=' || i );
                     
      execute immediate 'create table concept_ancestor_calc as
select 
	ancestor_concept_id,
	descendant_concept_id,
	min(min_levels_of_separation) as min_levels_of_separation,
	max(max_levels_of_separation) as max_levels_of_separation
from new_concept_ancestor_calc
group by ancestor_concept_id, descendant_concept_id ';

      execute immediate 'select count(*), sum(max_levels_of_separation) from concept_ancestor_calc' into vCnt, vSum;
      add_application_log ( pApplication_name => vApplication_name
                     ,pProcedure_name => vProcedure_name
                     ,pDetail => 'End concept_ancestor_calc i=' || i  || ' cnt=' || vCnt || ' sum=' || vSum );
                     
      execute immediate 'drop table new_concept_ancestor_calc purge';
                     
      if vCnt = vCnt_old
        then add_application_log ( pApplication_name => vApplication_name
                     ,pProcedure_name => vProcedure_name
                     ,pDetail => 'loop exit i=' || i );
             exit;
        else vCnt_old := vCnt;
      end if;
    end loop; /********** Repeat till no new records are written *********/
    
    add_application_log ( pApplication_name => vApplication_name
                     ,pProcedure_name => vProcedure_name
                     ,pDetail => 'Remove all non-Standard concepts (concept_level=0)' );

    execute immediate 'truncate table concept_ancestor';
    
    -- drop concept_ancestor indexes before mass insert.
    execute immediate 'alter table concept_ancestor disable constraint CONCEPT_ANCESTOR_PK';

    execute immediate 'insert into concept_ancestor
  select a.* from concept_ancestor_calc a
    join concept_stage c1 on a.ancestor_concept_id=c1.concept_id
    join concept_stage c2 on a.descendant_concept_id=c2.concept_id
       where c1.STANDARD_CONCEPT is not null and c2.STANDARD_CONCEPT is not null 
        ';
    commit;
    
    -- Create concept_ancestor indexes after mass insert.
    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'Enable PK CONCEPT_ANCESTOR' );
    execute immediate 'alter table concept_ancestor enable constraint CONCEPT_ANCESTOR_PK';

    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name
      ,pDetail => 'Add connections to self for those vocabs having at least one concept.' );

    -- Add connections to self for those vocabs having at least one concept in the concept_relationship table
    insert into concept_ancestor
    select 
      t.concept_id as ancestor_concept_id,
      t.concept_id as descendant_concept_id,
      0 as min_levels_of_separation,
      0 as max_levels_of_separation
    from concept_stage t
    where t.VOCABULARY_CODE in (
      select c.VOCABULARY_CODE from concept_relationship_stage r, concept_stage c where c.concept_id=r.concept_id_1
      union
      select c.VOCABULARY_CODE from concept_relationship_stage r, concept_stage c where c.concept_id=r.concept_id_2
    )
    and t.invalid_reason is null and t.STANDARD_CONCEPT is not null
      ;    
    commit;
    -- Clean up       
    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'Clean up' );
    execute immediate 'drop table concept_ancestor_calc purge';

    add_application_log ( pApplication_name => vApplication_name, pProcedure_name => vProcedure_name, pDetail => 'End' );
  exception when others then
    add_application_log ( pApplication_name => 'CONCEPT_ANSESTOR'
                         ,pProcedure_name => 'CALC SqlCode=' || sqlcode
                         ,pDetail => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace );
    raise;
  end calc;
  ------------------------------------------------------
  

end pkg_concept_ancestor;
/

--1. remove non-digit rows
delete From FY_TABLE_5 where not regexp_like(drg_code, '^[[:digit:]]+$');

--2. remove double quotes
update FY_TABLE_5 set drg_name=substr(drg_name,2,length(drg_name)-2) where substr(drg_name,1,1)='"' and substr(drg_name,-1,1)='"';

--3. directly update concept
declare
ex number;
begin
        
    --create sequence
    select max(c.concept_id)+1 into ex from concept c where concept_id<500000000; -- Last valid below HOI concept_id
    begin
        execute immediate 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    exception when others then null;
    end;
        
    for cYears in (select distinct drg_version from FY_TABLE_5 order by drg_version) loop
        --1. undeprecate active concepts
        update concept c set c.invalid_reason=null, c.valid_end_date=TO_DATE ('20991231', 'yyyymmdd')  
        where 
        c.vocabulary_id='DRG'
        and c.invalid_reason = 'D'
        and c.valid_start_date<=TO_DATE (cYears.drg_version||'1001', 'yyyymmdd')
        and (c.concept_code, lower(c.concept_name)) in (select f.drg_code, lower(f.drg_name) from FY_TABLE_5 f where f.drg_version=cYears.drg_version)
        and c.concept_id in (select c_int.concept_id from concept c_int where c_int.vocabulary_id='DRG' and c_int.invalid_reason is null);
                
        --2. deprecate missing concepts
        update concept c set c.invalid_reason='D', c.valid_end_date=TO_DATE (cYears.drg_version||'0930', 'yyyymmdd')  
        where 
        c.vocabulary_id='DRG'
        and c.invalid_reason is null
        and c.valid_start_date<=TO_DATE (cYears.drg_version||'1001', 'yyyymmdd')
        and c.concept_code not in (select drg_code from FY_TABLE_5 f where f.drg_version=cYears.drg_version);

        --3. if concept not exists or exists, but names are different, then deprecate old record and create the new one        
        update concept c set c.invalid_reason='D', c.valid_end_date=TO_DATE (cYears.drg_version||'0930', 'yyyymmdd')  
        where 
        c.vocabulary_id='DRG'
        and c.invalid_reason is null
        and c.valid_start_date<=TO_DATE (cYears.drg_version||'1001', 'yyyymmdd')
        and exists (
            select 1 from FY_TABLE_5 f where f.drg_version=cYears.drg_version 
            and c.concept_code=f.drg_code 
            and lower(c.concept_name)<>lower(f.drg_name)
        );

        execute immediate q'[
        INSERT /*+ APPEND */ INTO concept (concept_id,
            concept_name,
            domain_id,
            vocabulary_id,
            concept_class_id,
            standard_concept,
            concept_code,
            valid_start_date,
            valid_end_date,
            invalid_reason)
        SELECT v5_concept.NEXTVAL,
            f.drg_name as concept_name,
            'Observation' as domain_id,
            'DRG' as vocabulary_id,
            'MS-DRG' as concept_class_id,
            'S' as standard_concept,
            f.drg_code as concept_code,
            TO_DATE (f.drg_version||'1001', 'yyyymmdd') AS valid_start_date,
            TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
            null as invalid_reason
        FROM FY_TABLE_5 f where f.drg_version=:1
        and not exists (
                select 1 from concept c_int where c_int.vocabulary_id='DRG' 
                and c_int.invalid_reason is null
                and c_int.concept_code=f.drg_code
        )    
        ]' using cYears.drg_version;
        
    end loop;
    
    COMMIT;
    execute immediate 'DROP SEQUENCE v5_concept';
end;
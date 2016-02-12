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
        
    for cDate in (select distinct drg_version from FY_TABLE_5 order by drg_version) loop      
        --1. deprecate missing concepts
        update concept c set c.invalid_reason='D', c.valid_end_date=cDate.drg_version-1
        where 
        c.vocabulary_id='DRG'
        and c.invalid_reason is null
        and c.valid_start_date<=cDate.drg_version
        and c.concept_code not in (select drg_code from FY_TABLE_5 f where f.drg_version=cDate.drg_version);

        --2. if concept not exists or exists, but names are different, then deprecate old record and create the new one        
        update concept c set c.invalid_reason='U', c.valid_end_date=cDate.drg_version-1
        where 
        c.vocabulary_id='DRG'
        and c.invalid_reason is null
        and c.valid_start_date<=cDate.drg_version
        and exists (
            select 1 from FY_TABLE_5 f where f.drg_version=cDate.drg_version
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
            f.drg_version AS valid_start_date,
            TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
            null as invalid_reason
        FROM FY_TABLE_5 f where f.drg_version=:1
        and not exists (
                select 1 from concept c_int where c_int.vocabulary_id='DRG' 
                and c_int.invalid_reason is null
                and c_int.concept_code=f.drg_code
        )    
        ]' using cDate.drg_version;
        
    end loop;
	
	--3. add 'Concept replaced by' for 'U'
	insert into concept_relationship
		select distinct c1.concept_id as concept_id_1, 
		last_value(c2.concept_id) over (partition by c1.concept_id order by c2.invalid_reason ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as concept_id_2,
		'Concept replaced by' as relationship_id,
		c1.valid_start_date as valid_start_date,
		last_value(c2.valid_end_date) over (partition by c1.concept_id order by c2.invalid_reason ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as valid_end_date,
		null as invalid_reason
		from concept c1, concept c2
		where c1.concept_code=c2.concept_code
		and c1.vocabulary_Id='DRG'
		and c2.vocabulary_Id='DRG'
		and c1.invalid_reason = 'U'
		and nvl(c2.invalid_reason,'X') in ('X','D')
		and not exists (
			select 1 from concept_relationship r_int where r_int.concept_id_1=c1.concept_id and r_int.relationship_id='Concept replaced by'
		);		

    COMMIT;
    execute immediate 'DROP SEQUENCE v5_concept';
end;
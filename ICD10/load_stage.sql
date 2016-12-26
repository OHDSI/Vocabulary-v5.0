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
* Authors: Timur Vakhitov, Dmitry Dymshyts, Christian Reich
* Date: 2016
**************************************************************************/

--1. Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'ICD10',
                                          pVocabularyDate        => TO_DATE ('20150922', 'yyyymmdd'),
                                          pVocabularyVersion     => '2016 Release',
                                          pVocabularyDevSchema   => 'DEV_ICD10');
END;
COMMIT;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create temporary tables with classes and modifiers from XML source
--modifier classes

create table modifier_classes nologging as
    SELECT t.modifierclass_code, t.modifierclass_modifier, t.superclass_code, t1.*
    FROM ICDCLAML i, 
    XMLTABLE ('/ClaML/ModifierClass' PASSING i.xmlfield 
    COLUMNS
    modifierclass_code VARCHAR2(100) PATH '@code',
    modifierclass_modifier VARCHAR2(100) PATH '@modifier',
    superclass_code VARCHAR2(100) PATH 'SuperClass/@code',
    rubric XMLType path 'Rubric'
    ) t,
    XMLTABLE ('Rubric' PASSING t.rubric 
    COLUMNS
    rubric_id VARCHAR2(100) PATH '@id',  
    rubric_kind VARCHAR2(100) PATH '@kind',
    Label VARCHAR2(100) PATH 'Label'
    ) t1; 
  
--classes
drop table classes;
create table classes nologging as
    SELECT t.class_code, t1.rubric_kind, t.superclass_code, cast(substr(t1.Label,1,1000) as varchar(1000)) as Label
    FROM ICDCLAML i, 
    XMLTABLE ('/ClaML/Class' PASSING i.xmlfield 
    COLUMNS
    class_code VARCHAR2(100) PATH '@code',
    superclass_code VARCHAR2(100) PATH 'SuperClass/@code',
    rubric XMLType path 'Rubric'
    ) t,
    XMLTABLE ('Rubric' PASSING t.rubric 
    COLUMNS
    rubric_kind VARCHAR2(100) PATH '@kind',
    Label CLOB PATH 'Label'
    ) t1;

exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'classes');
--exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'modifier_classes');	

--modify classes_table replacing  preferred name to preferredLong where it's possible
create table classes_temp as
select a.CLASS_CODE,a.RUBRIC_KIND,a.SUPERCLASS_CODE, nvl (b.LABEL, a.label) as label from classes a 
 left join classes b on a.class_code =b.class_code and a.rubric_kind = 'preferred' and b.rubric_kind = 'preferredLong'
 where a.rubric_kind != 'preferredLong'
 ;
truncate table classes
;
insert into classes select * from classes_temp
;
drop table classes_temp purge
;
--4. Fill the concept_stage
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
with
codes_need_modified as (
    --define all the concepts having modifiers, use filter a.RUBRIC_KIND ='modifierlink'
    select  distinct a.CLASS_CODE, a.label,a.SUPERCLASS_CODE, b.CLASS_CODE as concept_code, b.label as concept_name, b.SUPERCLASS_CODE as super_concept_code 
     from classes a 
    join classes b on b.class_code like a.class_code|| '%' 
      where a.RUBRIC_KIND =  'modifierlink' and b.RUBRIC_KIND = 'preferred' and b.class_code not like '%-%'
),
codes as (
    select a.*, b.MODIFIERCLASS_CODE, b.label as modifer_name from codes_need_modified a 
    left join modifier_classes b on class_code = regexp_replace (regexp_replace (MODIFIERCLASS_MODIFIER, '^(I\d\d)|(S\d\d)'), '_\d') and b.RUBRIC_KIND ='preferred' 
    and MODIFIERCLASS_MODIFIER !='I70M10_4' --looks like a bug
),
concepts_modifiers as (
    --add all the modifiers using patterns described in a table
    --'I70M10_4' with or without gangrene related to gout, seems to be a bug, modifier says [See site code at the beginning of this chapter]
    select a.concept_code||b.MODIFIERCLASS_CODE as concept_code, case when b.MODIFER_NAME = 'Kimmelstiel-Wilson syndromeN08.3' --only one modifier that has capital letter in it
    then regexp_replace (a.concept_name, '[A-Z]\d\d(\.|-|$).*')||', '||  regexp_replace (b.MODIFER_NAME, '[A-Z]\d\d(\.|-|$).*') -- remove related code (A52.7)
    else  regexp_replace (a.concept_name, '[A-Z]\d\d(\.|-|$).*')||', '|| lower( regexp_replace (b.MODIFER_NAME, '[A-Z]\d\d(\.|-|$).*'))
     end 
    as concept_name from codes a 
    join codes b on (
        (regexp_substr (a.label, '\D\d\d') = b.concept_code  and a.label=b.label and a.class_code != b.class_code)
        or (a.label = '[See at the beginning of this block for subdivisions]' and a.label=b.label and a.class_code != b.class_code and b.concept_code ='K25')
        or (a.label= '[See site code at the beginning of this chapter]' and a.label =b.label and a.class_code != b.class_code and b.concept_code like '_00' and regexp_substr (b.concept_code, '^\D')=regexp_substr (a.concept_code, '^\D')
            and a.concept_code not like 'M91%' -- seems to be ICD10 bag, M91% don't need additional modifiers  
            and a.concept_code not like 'M21.4%'   --Flat foot [pes planus] (acquired)
           )
    ) where (
        (a.concept_code not like '%.%' and b.MODIFIERCLASS_CODE like '%.%') 
        or (a.concept_code  like '%.%' and b.MODIFIERCLASS_CODE not like '%.%')
    )
    union 
    --basic modifiers having relationship modifier - concept
    select a.concept_code||a.MODIFIERCLASS_CODE as concept_code, a.concept_name||', '|| a.MODIFER_NAME from codes a
    where (
        (a.concept_code not like '%.%' and a.MODIFIERCLASS_CODE like '%.%') 
        or (a.concept_code  like '%.%' and a.MODIFIERCLASS_CODE not like '%.%')
    ) and a.MODIFIERCLASS_CODE is not null
)
select concept_name,
    null as domain_id,
    'ICD10' as vocabulary_id,
    case 
        when length(concept_code)=3 then 'ICD10 Hierarchy'
    else 
        'ICD10 code' 
    end as concept_class_id,
    null as standard_concept,
    concept_code,
    (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD10')
             AS valid_start_date,
    to_date('20991231','YYYYMMDD') as valid_end_date,
    null as invalid_reason
from (
    --full list of concepts 
    select * from concepts_modifiers
    union
    select class_code, case when label like 'Emergency use of%' then label else   regexp_replace (label,'[A-Z]\d\d(\.|-|$).*')  -- remove related code (A52.7) i.e.  Late syphilis of kidneyA52.7 but except of cases like "Emergency use of U07.0"
     end as concept_name
     from classes where RUBRIC_KIND ='preferred' and class_code not like '%-%'
) where regexp_like (concept_code, '[A-Z]\d\d.*')
;
COMMIT;	


delete from concept_stage where regexp_like
(concept_code, 'M(21.3|21.5|21.6|21.7|21.8|24.3|24.7|54.2|54.3|54.4|54.5|54.6|65.3|65.4|70.2|70.3|70.4|70.5|70.6|70.7|71.2|72.0|72.1|72.2|76.1|76.2|76.3|76.4|76.5|76.6|76.7|76.8|76.9|77.0|77.1|77.2|77.3|77.4|77.5|79.4|85.2|88.0|94.0)+\d+')
;
COMMIT;	
drop table name_impr
;
create table name_impr as 
select c.concept_code, cs.concept_name ||' '|| lower (c.concept_name) as new_name from concept_stage c
left join classes cl on c.concept_code = cl.CLASS_CODE
left join concept_stage cs on cl.SUPERCLASS_CODE = cs.concept_code
where  regexp_like (c.concept_code , '((Y06)|(Y07)).+')
and RUBRIC_KIND = 'preferred'
union
select c.concept_code, c.concept_name ||' as the cause of abnormal reaction of the patient, or of later complication, without mention of misadventure at the time of the procedure' from concept_stage c
where  regexp_like (c.concept_code , '((Y83)|(Y84)).+')
union
select c.concept_code, 'Adverse effects in the therapeutic use of ' || lower (concept_name) from concept_stage c
where concept_code>='Y40' and concept_code<'Y60'
union
select c.concept_code, replace (cs.concept_name, 'during%')  ||' '|| lower (c.concept_name) from concept_stage c
left join classes cl on c.concept_code = cl.CLASS_CODE
left join concept_stage cs on cl.SUPERCLASS_CODE = cs.concept_code
where  regexp_like (c.concept_code , '((Y60)|(Y61)|(Y62)).+')
and RUBRIC_KIND = 'preferred'
;
update concept_stage a set concept_name = (select new_name from name_impr b where a.concept_code = b.concept_code)
where exists (select 1 from name_impr b where a.concept_code = b.concept_code)
;
commit
;

--5. Create file with mappings for medical coder from the existing one
SELECT *
  FROM concept c, concept_relationship r
 WHERE     c.concept_id = r.concept_id_1
       AND c.vocabulary_id = 'ICD10'
       AND r.invalid_reason IS NULL;

--6. Append file from medical coder to concept_relationship_stage
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--7. Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--8. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--9. Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--10. Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--11. Add "subsumes" relationship between concepts where the concept_code is like of another
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT c1.concept_code AS concept_code_1,
          c2.concept_code AS concept_code_2,
          c1.vocabulary_id AS vocabulary_id_1,
          c1.vocabulary_id AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = c1.vocabulary_id)
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_stage c1, concept_stage c2
    WHERE     c2.concept_code LIKE c1.concept_code || '%'
          AND c1.concept_code <> c2.concept_code
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept_relationship_stage r_int
                   WHERE     r_int.concept_code_1 = c1.concept_code
                         AND r_int.concept_code_2 = c2.concept_code
                         AND r_int.relationship_id = 'Subsumes');
COMMIT;

--12. update domain_id for ICD10 from SNOMED
--create 1st temporary table ICD10_domain with direct mappings
create table filled_domain NOLOGGING as
	with domain_map2value as (--ICD10 have direct "Maps to value" mapping
		SELECT c1.concept_code, c2.domain_id
		FROM concept_relationship_stage r, concept_stage c1, concept c2
		WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
		AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
		AND r.vocabulary_id_1='ICD10' AND r.vocabulary_id_2='SNOMED'
		AND r.relationship_id='Maps to value'
		AND r.invalid_reason is null
	)
	select 
	d.concept_code,
	--some rules for domain_id
	case    when d.domain_id in ('Procedure', 'Measurement') 
				and exists (select 1 from domain_map2value t where t.concept_code=d.concept_code and t.domain_id in ('Meas Value' , 'Spec Disease Status'))
				then 'Measurement'
			when d.domain_id = 'Procedure' and exists (select 1 from domain_map2value t where t.concept_code=d.concept_code and t.domain_id = 'Condition')
				then 'Condition'
			when d.domain_id = 'Condition' and exists (select 1 from domain_map2value t where t.concept_code=d.concept_code and t.domain_id = 'Procedure')
				then 'Condition' 
			when d.domain_id = 'Observation' 
				then 'Observation'                 
			else d.domain_id
	end domain_id
	FROM 
	( select concept_code, --simplify domain_id
		case when domain_id='Condition/Measurement' then 'Condition'
			 when domain_id='Condition/Procedure' then 'Condition'
			 when domain_id='Condition/Observation' then 'Observation'
			 when domain_id='Observation/Procedure' then 'Observation'
			 when domain_id='Measurement/Observation' then 'Observation'
			 when domain_id='Measurement/Procedure' then 'Measurement'
			 else domain_id
		end domain_id
		from (--ICD10 have direct "Maps to" mapping
			select concept_code, listagg(domain_id,'/') within group (order by domain_id) domain_id from (
				SELECT distinct c1.concept_code, c2.domain_id
				FROM concept_relationship_stage r, concept_stage c1, concept c2
				WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
				AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
				AND r.vocabulary_id_1='ICD10' AND r.vocabulary_id_2='SNOMED'
				AND r.relationship_id='Maps to'
				AND r.invalid_reason is null
			)
			group by concept_code
		)
	) d;

--create 2d temporary table with ALL ICD10 domains	
--if domain_id is empty we use previous and next domain_id or its combination	
create table ICD10_domain NOLOGGING as
    select concept_code, 
    case when domain_id is not null then domain_id 
    else 
        case when prev_domain=next_domain then prev_domain --prev and next domain are the same (and of course not null both)
            when prev_domain is not null and next_domain is not null then  
                case when prev_domain<next_domain then prev_domain||'/'||next_domain 
                else next_domain||'/'||prev_domain 
                end -- prev and next domain are not same and not null both, with order by name
            else coalesce (prev_domain,next_domain,'Unknown')
        end
    end domain_id
    from (
            select concept_code, LISTAGG(domain_id, '/') WITHIN GROUP (order by domain_id) domain_id, prev_domain, next_domain from (

                        select distinct c1.concept_code, r1.domain_id,
                            (select MAX(fd.domain_id) KEEP (DENSE_RANK LAST ORDER BY fd.concept_code) from filled_domain fd where fd.concept_code<c1.concept_code and r1.domain_id is null) prev_domain,
                            (select MIN(fd.domain_id) KEEP (DENSE_RANK FIRST ORDER BY fd.concept_code) from filled_domain fd where fd.concept_code>c1.concept_code and r1.domain_id is null) next_domain
                        from concept_stage c1
                        left join filled_domain r1 on r1.concept_code=c1.concept_code
                        where c1.vocabulary_id='ICD10'
            )
            group by concept_code,prev_domain, next_domain
    );
	
-- INDEX was set as UNIQUE to prevent concept_code duplication
CREATE UNIQUE INDEX idx_ICD10_domain ON ICD10_domain (concept_code) NOLOGGING;

--13. Simplify the list by removing Observations
update ICD10_domain set domain_id=trim('/' FROM replace('/'||domain_id||'/','/Observation/','/'))
where '/'||domain_id||'/' like '%/Observation/%'
and instr(domain_id,'/')<>0;

--reducing some domain_id if his length>20
update ICD10_domain set domain_id='Condition/Meas' where domain_id='Condition/Measurement';
update ICD10_domain set domain_id='Procedure' where domain_id = 'Procedure/Spec Disease Status';
update ICD10_domain set domain_id='Measurement' where domain_id='Measurement/Procedure/Spec Disease Status';
update ICD10_domain set domain_id='Measurement' where domain_id='Measurement/Spec Disease Status';
update ICD10_domain set domain_id='Measurement' where domain_id='Meas Value/Measurement/Procedure';
update ICD10_domain set domain_id='Measurement' where domain_id='Meas Value/Measurement';
update ICD10_domain set domain_id='Condition' where domain_id='Condition/Spec Disease Status';
COMMIT;

--14. update each domain_id with the domains field from ICD10_domain.
UPDATE concept_stage c
   SET (domain_id) =
          (SELECT domain_id
             FROM ICD10_domain rd
            WHERE rd.concept_code = c.concept_code)
 WHERE c.vocabulary_id = 'ICD10';
COMMIT;

--15. Clean up
DROP TABLE ICD10_domain PURGE;
DROP TABLE filled_domain PURGE;
DROP TABLE modifier_classes PURGE;
DROP TABLE classes PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		



/*

--name analysis, figure out what goes to the synonim table, what - need to be improved
select a.concept_code, a.concept_name as new_name, b.concept_name as old_name , c.concept_name as ICD10CM_name,  UTL_MATCH.JARO_WINKLER_SIMILARITY (a.concept_name , b.concept_name) as JARO_WINKLER_SIMIL, 
UTL_MATCH.EDIT_DISTANCE_SIMILARITY (a.concept_name , b.concept_name) as EDIT_DISTANCE_SIMIL, 
UTL_MATCH.EDIT_DISTANCE(a.concept_name , b.concept_name) as EDIT_DISTANCE,
regexp_replace (b.concept_name , a.concept_name) as difference, -- shows how to improve names
 regexp_substr (b.concept_name , a.concept_name) as similarity 
 from concept_stage a
  join devv5.concept b on a.concept_code = b.concept_code
  join devv5.concept c on a.concept_code = c.concept_code
where b.vocabulary_id = 'ICD10' and b.invalid_reason is null and lower ( a.concept_name) != lower (b.concept_name) 
and c.vocabulary_id = 'ICD10CM' and C.invalid_reason is null
and not regexp_like (a.concept_name, '-') --to avoid the crash of regexp_replace (a.concept_name , b.concept_name), not the best decision, we lose for about 200 concepts
*/

/*
1. create core tables of Read (keyv2, RCSCTMAP2_UK)
Read code distrbution file
Open the site https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/1/subpack/21/releases.
- Download the latest release xx.
- Extract the nhs_readv2_xxxxx\V2\Unified\Keyv2.all file.

Read code to SNOMED CT mapping file
nhs_datamigration_VV.0.0_YYYYMMDD000001.zip from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/9/subpack/9/releases (Subscription "NHS Data Migration"). "VV" stands for the current version number, "YYYYMMDD" for the release date.
- Download the latest release xx.
- Extract nhs_datamigration_xxxxx\Mapping Tables\Updated\Clinically Assured\rcsctmap2_uk_YYYYMMDD000001.txt
-- Update latest_update field to new date 
update vocabulary set latest_update=to_date('YYYYMMDD','yyyymmdd') where vocabulary_id='Read'; commit;

*/
--2. fill CONCEPT_STAGE and concept_relationship_stage from Read
INSERT INTO CONCEPT_STAGE (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT
	      NULL,
          coalesce(kv2.description_long, kv2.description, kv2.description_short),
          NULL,
          'Read',
          'Read',
          NULL,
          kv2.readcode || kv2.termcode,
          (select latest_update from vocabulary where vocabulary_id='Read'),
          TO_DATE ('20991231', 'yyyymmdd'),
          NULL
     FROM keyv2 kv2;
COMMIT;

INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
										vocabulary_id_1,
										vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          NULL,
          NULL,
          RSCCT.ReadCode || RSCCT.TermCode,
          -- pick the best map: mapstatus=1, then is_assured=1, then target concept is fresh, then newest date
          FIRST_VALUE (
             RSCCT.conceptid)
          OVER (
             PARTITION BY RSCCT.readcode || RSCCT.termcode
             ORDER BY
                RSCCT.mapstatus DESC,
                RSCCT.is_assured DESC,
                RSCCT.effectivedate DESC),
          'Maps to',
		  'Read',
		  'SNOMED',
          (select latest_update from vocabulary where vocabulary_id='Read'),
          TO_DATE ('20991231', 'yyyymmdd'),
          NULL
     FROM RCSCTMAP2_UK RSCCT;
COMMIT;

--3. load SNOMED 01-SNOMED\load_stage.sql
--4. update domain_id for Read from SNOMED
--create temporary table read_domain
--if domain_id is empty we use previous and next domain_id or its combination
create table read_domain as
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
        with filled_domain as
        (
            select c1.concept_code, c2.domain_id
            FROM concept_relationship_stage r, concept_stage c1, concept c2
            WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
            AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
            AND r.vocabulary_id_1='Read' AND r.vocabulary_id_2='SNOMED'
        )

        select c1.concept_code, c2.domain_id,
            (select MAX(fd.domain_id) KEEP (DENSE_RANK LAST ORDER BY fd.concept_code) from filled_domain fd where fd.concept_code<c1.concept_code and c2.domain_id is null) prev_domain,
            (select MIN(fd.domain_id) KEEP (DENSE_RANK FIRST ORDER BY fd.concept_code) from filled_domain fd where fd.concept_code>c1.concept_code and c2.domain_id is null) next_domain
        from concept_stage c1
        left join concept_relationship_stage r on r.concept_code_1=c1.concept_code and r.vocabulary_id_1=c1.vocabulary_id
        left join concept c2 on c2.concept_code=r.concept_code_2 and r.vocabulary_id_2=c2.vocabulary_id and c2.vocabulary_id='SNOMED'
        where c1.vocabulary_id='Read'
    );
    
CREATE INDEX idx_read_domain ON read_domain (concept_code);

--5 Simplify the list by removing Observations
update read_domain set domain_id=trim('/' FROM replace('/'||domain_id||'/','/Observation/','/'))
where '/'||domain_id||'/' like '%/Observation/%'
and instr(domain_id,'/')<>0;

--reducing some domain_id if his length>20
update read_domain set domain_id='Meas/Procedure' where domain_id='Measurement/Procedure';
update read_domain set domain_id='Condition/Meas' where domain_id='Condition/Measurement';

COMMIT;

/*check for new domains (must not return any rows!)

select domain_id from read_domain 
minus
select domain_id from domain;
*/

--6 update each domain_id with the domains field from read_domain.
UPDATE concept_stage c
   SET (domain_id) =
          (SELECT domain_id
             FROM read_domain rd
            WHERE rd.concept_code = c.concept_code)
 WHERE c.vocabulary_id = 'Read';
COMMIT;

--7 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;


--8------ run Vocabulary-v5.0\generic_update.sql ---------------
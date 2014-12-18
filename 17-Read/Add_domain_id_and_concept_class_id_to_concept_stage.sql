--1. create temporary table read_domains
create table read_domains as
    select concept_code,   
    case when domains='Measurement/Procedure' then 'Meas/Procedure'
        when domains='Condition/Measurement' then 'Condition/Meas'
        when domains='Condition/Observation/Spec Anatomic Site' then 'Condition'
        when domains='Condition/Spec Anatomic Site' then 'Condition'
        when domains='Device/Observation/Procedure/Spec Anatomic Site' then 'Procedure'
        when domains='Observation/Procedure/Spec Anatomic Site' then 'Procedure'
        else domains
    end domains from (
        select concept_code, LISTAGG(domain_id, '/') WITHIN GROUP (order by domain_id) domains from (
               SELECT c1.concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
                UNION
                SELECT SUBSTR(c1.concept_code, 1, 6) AS concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
                UNION
                SELECT SUBSTR(c1.concept_code, 1, 5) AS concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
                UNION
                SELECT SUBSTR(c1.concept_code, 1, 4) AS concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
                UNION
                SELECT SUBSTR(c1.concept_code, 1, 3) AS concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
        )
        group by concept_code
);      

CREATE INDEX idx_read_domains ON read_domains (concept_code);

--2. Simplify the list by removing Observations where is Measurement, Meas Value, Speciment, Spec Anatomic Site, Relationship
update read_domains set domains=trim('/' FROM replace('/'||domains||'/','/Observation/','/'))
where '/'||domains||'/' like '%/Observation/%'
and instr(domains,'/')<>0;


--check for new domains:
select domains from read_domains 
minus
select domain_id from domain;

--3. update each domain_id with the domains field from read_domains. If null take the 6-letter code, if still null take the 5-letter code etc.
update concept_stage cs set (domain_id)=
    (select coalesce(d7.domains, d6.domains, d5.domains, d4.domains, d3.domains, 'Observation')
    from concept_stage c
    left join read_domains d7 on d7.concept_code=c.concept_code
    left join read_domains d6 on d6.concept_code=substr(c.concept_code, 1, 6)
    left join read_domains d5 on d5.concept_code=substr(c.concept_code, 1, 5)
    left join read_domains d4 on d4.concept_code=substr(c.concept_code, 1, 4)
    left join read_domains d3 on d3.concept_code=substr(c.concept_code, 1, 3)
    where c.CONCEPT_CODE=cs.CONCEPT_CODE
    and c.vocabulary_id=cs.vocabulary_id
) where cs.vocabulary_id='Read';   

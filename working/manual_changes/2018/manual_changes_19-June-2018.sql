--set standard_concept='S' for NDC with domain_id = 'Device'
update concept set standard_concept='S' where vocabulary_id = 'NDC' and domain_id = 'Device' and invalid_reason is null;
--add self mappings
insert into concept_relationship
select concept_id, concept_id, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null from concept where vocabulary_id = 'NDC' and domain_id = 'Device' and standard_concept='S' and invalid_reason is null
union all
select concept_id, concept_id, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null from concept where vocabulary_id = 'NDC' and domain_id = 'Device' and standard_concept='S' and invalid_reason is null;

--set CPT4 with concept_class_id = 'CPT4' alive
update concept set invalid_reason = null, standard_concept = 'S' where vocabulary_id ='CPT4' and invalid_reason is not null and concept_class_id = 'CPT4';

--new relationship
DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Has unit of administration (SNOMED)';
    pRelationship_id constant varchar(100):='Has unit of admin' ;
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='Unit of admin of';

    pRelationship_name_rev constant varchar(100):='Unit of administration of (SNOMED)';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    ALTER TABLE relationship DROP CONSTRAINT FPK_RELATIONSHIP_REVERSE;
    
    --direct
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
    DROP SEQUENCE v5_concept;
END $$;

--fix typo for 'VMP has prescr stat' (reverse_relationship_id was 'Is a')
update relationship set reverse_relationship_id='VMP prescr stat of' where relationship_id='VMP has prescr stat';
--fix typo for 'VMP has prescr stat' (reverse_relationship_id was 'VRP has prescr stat')
update relationship set reverse_relationship_id='VMP has prescr stat' where relationship_id='VMP prescr stat of';

--undeprecate self mappings for some deprecated concepts of ICD9Proc
update concept_relationship 
set valid_end_date=TO_DATE ('20991231', 'YYYYMMDD'), invalid_reason=null
where concept_id_1 in (
    select concept_id from concept where vocabulary_id = 'ICD9Proc' and invalid_reason is not null and concept_code <> '81.09'
)
and relationship_id in ('Maps to','Mapped from');
--undeprecate and set standard_concept='S
update concept set invalid_reason = null, standard_concept = 'S' where vocabulary_id = 'ICD9Proc' and invalid_reason is not null and concept_code <> '81.09';
--just undeprecate '81.09'
update concept set invalid_reason = null where vocabulary_id = 'ICD9Proc' and concept_code = '81.09';

--add some ABMS concepts
do $_$
begin
	insert into concept values (32411, 'Clinical Cytogenetics and Genomics','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32411, 32411, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32411, 32411, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;

	insert into concept values (32412, 'Clinical Genetics and Genomics (MD)','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32412, 32412, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32412, 32412, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;

	insert into concept values (32413, 'Clinical Molecular Genetics and Genomics','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32413, 32413, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32413, 32413, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;

	insert into concept values (32414, 'Consultation-Liaison Psychiatry','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32414, 32414, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32414, 32414, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;

	insert into concept values (32415, 'Diagnostic Medical Physics','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32415, 32415, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32415, 32415, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;

	insert into concept values (32416, 'Laboratory Genetics and Genomics','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32416, 32416, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32416, 32416, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;

	insert into concept values (32417, 'Nuclear Medical Physics','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32417, 32417, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32417, 32417, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;

	insert into concept values (32418, 'Pediatric Hospital Medicine','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32418, 32418, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32418, 32418, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;

	insert into concept values (32419, 'Therapeutic Medical Physics','Provider Specialty','ABMS','Specialty','S','OMOP generated',TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
	insert into concept_relationship
	select 32419, 32419, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null
	union all
	select 32419, 32419, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null;
end $_$;

--undeprecate some HCPCS concepts and add/update self mappings
update concept_relationship set valid_end_date=TO_DATE ('20991231', 'YYYYMMDD'), invalid_reason=null
where concept_id_1 in
(
  select concept_id from concept where vocabulary_id ='HCPCS' and invalid_reason = 'D'
  and concept_code not in (
      select concept_code from concept where vocabulary_id ='CDT'
  )
  and concept_class_id <> 'HCPCS Class'
)
and relationship_id in ('Maps to','Mapped from')
and concept_id_1=concept_id_2;

insert into concept_relationship
with t as
(
  select concept_id from concept c where vocabulary_id ='HCPCS' and invalid_reason = 'D'
  and concept_code not in (
      select concept_code from concept where vocabulary_id ='CDT'
  )
  and concept_class_id <> 'HCPCS Class'
  and not exists (
 	select 1 from concept_relationship r where concept_id_1=c.concept_id and relationship_id = 'Maps to' and concept_id_1=concept_id_2
  )
)
select concept_id, concept_id, 'Maps to', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null from t
union all
select concept_id, concept_id, 'Mapped from', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null from t;

update concept set invalid_reason = null, standard_concept ='S' where vocabulary_id ='HCPCS' and invalid_reason = 'D'
and concept_code not in (
	select concept_code from concept where vocabulary_id ='CDT'
)
and concept_class_id <> 'HCPCS Class';
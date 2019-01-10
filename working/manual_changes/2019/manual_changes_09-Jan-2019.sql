--Add new concept_class_id='Disposition' (AVOF-1369)
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Disposition';
    pConcept_class_name constant varchar(100):= 'Disposition';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--icd10cm duplicated concepts removal (AVOF-610)
DO $_$
DECLARE
A record;
BEGIN
  for A in (
    select c1.concept_id src_concept_id, c2.concept_id trgt_concept_id, c2.invalid_reason trgt_invalid_reason
    from concept c1
    join concept c2 on lower (c1.concept_code) = lower (c2.concept_code) and c1.concept_code <> c2.concept_code and c2.vocabulary_id = 'ICD10CM'
    where c1.vocabulary_id = 'ICD10CM' and c1.concept_code ~ '[a-x]'
  ) loop
    
    if A.trgt_invalid_reason is null then --if target concept is fresh
      --create the replacement record
      insert into concept_relationship values (A.src_concept_id, A.trgt_concept_id, 'Concept replaced by', current_date, to_date('20991231','yyyymmdd'),null);
      insert into concept_relationship values (A.trgt_concept_id, A.src_concept_id, 'Concept replaces', current_date, to_date('20991231','yyyymmdd'),null);
      --mark source concept as 'U' and break the name and concept_code
      update concept set concept_name='Duplicate of ICD10CM Concept, do not use, use replacement from CONCEPT_RELATIONSHIP table instead', concept_code=concept_id::varchar,
        invalid_reason='U' where concept_id=A.src_concept_id;
    else
    --target concept was deprecated
      --create deprecated replacement record
      insert into concept_relationship values (A.src_concept_id, A.trgt_concept_id, 'Concept replaced by', current_date, current_date,'D');
      insert into concept_relationship values (A.trgt_concept_id, A.src_concept_id, 'Concept replaces', current_date, current_date,'D');
      --mark source concept as 'D' and break the name and concept_code
      update concept set concept_name='Duplicate of ICD10CM Concept, do not use, use replacement from CONCEPT_RELATIONSHIP table instead', concept_code=concept_id::varchar
        where concept_id=A.src_concept_id;
    end if;
  
  end loop;
END $_$;
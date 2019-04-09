--Overhaul Visits, Places of Service, Providers, Specialties [AVOF-1435]

--rename domain 'Provider Specialty' to 'Provider'
do $$
declare
	cOldDomain constant varchar(100):='Provider Specialty';
	cNewDomain constant varchar(100):='Provider';
begin
	alter table concept drop constraint fpk_concept_domain;
	update concept set concept_name=cNewDomain where domain_id='Metadata' and vocabulary_id='Domain' and concept_name=cOldDomain;
	update domain set domain_id=cNewDomain where domain_id=cOldDomain;
	update concept set domain_id=cNewDomain where domain_id=cOldDomain;
	alter table concept add constraint fpk_concept_domain foreign key (domain_id) references domain (domain_id);
end $$;

--rename vocabulary 'Specialty' to 'Medicare Specialty'
do $$
declare
	cOldVocabulary constant varchar(100):='Specialty';
	cNewVocabulary constant varchar(100):='Medicare Specialty';
begin
	alter table vocabulary drop constraint fpk_vocabulary_concept;
	alter table concept drop constraint fpk_concept_vocabulary;
	update concept set vocabulary_id=cNewVocabulary where vocabulary_id=cOldVocabulary;
	update concept set concept_name=cNewVocabulary where vocabulary_id='Vocabulary' and concept_id=(select concept_id from vocabulary where vocabulary_id=cOldVocabulary);
	update vocabulary set vocabulary_id=cNewVocabulary /*, vocabulary_name = cNewVocabulary*/ where vocabulary_id=cOldVocabulary;
	update vocabulary_conversion set vocabulary_id_v5=cNewVocabulary where vocabulary_id_v5=cOldVocabulary;
	update vocabulary_access set vocabulary_id=cNewVocabulary where vocabulary_id=cOldVocabulary;
	alter table vocabulary add constraint fpk_vocabulary_concept foreign key (vocabulary_concept_id) references concept (concept_id);
	alter table concept add constraint fpk_concept_vocabulary foreign key (vocabulary_id) references vocabulary (vocabulary_id);
end $$;

--rename vocabulary 'Place of Service' to 'CMS Place of Service'
do $$
declare
	cOldVocabulary constant varchar(100):='Place of Service';
	cNewVocabulary constant varchar(100):='CMS Place of Service';
begin
	alter table vocabulary drop constraint fpk_vocabulary_concept;
	alter table concept drop constraint fpk_concept_vocabulary;
	update concept set vocabulary_id=cNewVocabulary where vocabulary_id=cOldVocabulary;
	update concept set concept_name=cNewVocabulary where vocabulary_id='Vocabulary' and concept_id=(select concept_id from vocabulary where vocabulary_id=cOldVocabulary);
	update vocabulary set vocabulary_id=cNewVocabulary /*, vocabulary_name = cNewVocabulary*/ where vocabulary_id=cOldVocabulary;
	update vocabulary_conversion set vocabulary_id_v5=cNewVocabulary where vocabulary_id_v5=cOldVocabulary;
	update vocabulary_access set vocabulary_id=cNewVocabulary where vocabulary_id=cOldVocabulary;
	alter table vocabulary add constraint fpk_vocabulary_concept foreign key (vocabulary_concept_id) references concept (concept_id);
	alter table concept add constraint fpk_concept_vocabulary foreign key (vocabulary_id) references vocabulary (vocabulary_id);
end $$;

--add new vocabulary='Provider'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Provider',
	pVocabulary_name		=> 'OMOP Provider',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL, --NULL or 'Y'
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;

--add new vocabulary='Supplier'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Supplier',
	pVocabulary_name		=> 'OMOP Supplier',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL, --NULL or 'Y'
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;

--rename concept class name 'Visit' to 'OMOP Visit'
do $$
declare
	cOldClass constant varchar(100):='Visit';
	cNewClass constant varchar(100):='OMOP Visit';
begin
	update concept set concept_name=cNewClass where domain_id='Metadata' and vocabulary_id='Concept Class' and concept_name=cOldClass;
	update concept_class set concept_class_name=cNewClass where concept_class_id=cOldClass;
end $$;


--add new concept_class_id='Provider'
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Provider';
    pConcept_class_name constant varchar(100):= 'OMOP Provider';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--add new concept_class_id='Physician Specialty'
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='Physician Specialty';
    pConcept_class_name constant varchar(100):= 'OMOP Physician Specialty';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

--add new concepts
INSERT INTO concept VALUES (32577,'Physician','Provider','Provider','Physician Specialty','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32578,'Counselor','Provider','Provider','Provider','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32579,'Supplier/Commercial Service Provider','Provider','Supplier','Provider','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32580,'Allied Health Professional','Provider','Provider','Provider','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept VALUES (32581,'Nurse','Provider','Provider','Provider','S','OMOP generated',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),NULL);
INSERT INTO concept_synonym VALUES (32577,'Physician',4180186);
INSERT INTO concept_synonym VALUES (32578,'Counselor',4180186);
INSERT INTO concept_synonym VALUES (32579,'Supplier/Commercial Service Provider',4180186);
INSERT INTO concept_synonym VALUES (32580,'Therapist/Technologist/Specialist',4180186);
INSERT INTO concept_synonym VALUES (32581,'Nurse',4180186);


--manual work
--deprecate all existing links between the concepts in concept_classes-x or domain-w, with the exception of 45756773 'Concept replaces' 45756774
update concept_relationship r1 set valid_end_date=to_date('20190201','yyyymmdd'), invalid_reason='D'
where (r1.concept_id_1, r1.concept_id_2) in (
  select r.concept_id_1, r.concept_id_2 from 
  (select concept_id from dev_test.classes union select concept_id from dev_test.domains) cd
  join concept_relationship r on cd.concept_id in (r.concept_id_1, r.concept_id_2) and r.invalid_reason is null
  where not (
  (r.concept_id_1=45756773 and r.concept_id_2=45756774 and r.relationship_id='Concept replaces')
  or
  (r.concept_id_2=45756773 and r.concept_id_1=45756774 and r.relationship_id='Concept replaced by')
  )
)
--not exists in new_relationships
and not exists (
  select 1 from dev_test.new_relationships n_r 
  where n_r.concept_id_1=r1.concept_id_1 
  and n_r.concept_id_2=r1.concept_id_2 
  and n_r.relationship_id=r1.relationship_id
) 
--reverse
and not exists (
  select 1 from dev_test.new_relationships n_r
  join relationship rel on rel.relationship_id=n_r.relationship_id
  where n_r.concept_id_2=r1.concept_id_1 
  and n_r.concept_id_1=r1.concept_id_2 
  and rel.reverse_relationship_id=r1.relationship_id
);

--add relationship 45756773 'Mapped from' 45756774
insert into concept_relationship values (45756773, 45756774, 'Mapped from', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);
insert into concept_relationship values (45756774, 45756773, 'Maps to', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);

--working with non-standard concepts
do $$
declare
A record;
begin
  for A in (
    select c.concept_id from dev_test.nonstandard n
    join concept c on c.concept_id=n.concept_id and c.standard_concept is not null
  ) loop
    update concept set standard_concept=null where concept_id=A.concept_id;
    --deprecate 'Maps to' and 'Mapped from' to self
    update concept_relationship set valid_end_date=to_date('20190201','yyyymmdd'), invalid_reason='D' 
    	where concept_id_1=concept_id_2 and concept_id_1=A.concept_id and relationship_id in ('Maps to','Mapped from') and invalid_reason is null;
    --deprecate 'Maps to' if our concept is target concept
    update concept_relationship set valid_end_date=to_date('20190201','yyyymmdd'), invalid_reason='D' 
    	where concept_id_1<>concept_id_2 and concept_id_2=A.concept_id and relationship_id='Maps to' and invalid_reason is null;
    --deprecate 'Mapped from' if our concept is source concept (reverse)
    update concept_relationship set valid_end_date=to_date('20190201','yyyymmdd'), invalid_reason='D' 
    	where concept_id_1<>concept_id_2 and concept_id_1=A.concept_id and relationship_id='Mapped from' and invalid_reason is null; 
  end loop;
end $$;

--add new relationships
do $$
declare
A record;
begin
  for A in (
    select 
    case r.concept_id_1 
      when 1 then 32577
      when 2 then 32578
      when 3 then 32579
      when 4 then 32580
      when 5 then 32581
      else r.concept_id_1
    end concept_id_1,
    r.concept_id_2, r.relationship_id,
    c1.standard_concept trgt_standard_concept, c1.invalid_reason trgt_invalid_reason, 
    c2.standard_concept src_standard_concept, c2.invalid_reason src_invalid_reason 
    from dev_test.new_relationships r
    join concept c1 on c1.concept_id=r.concept_id_1
    join concept c2 on c2.concept_id=r.concept_id_2
    left join concept_relationship cr on cr.concept_id_1=r.concept_id_1 and cr.concept_id_2=r.concept_id_2 and cr.relationship_id=r.relationship_id
    where cr.concept_id_1 is null --exclude already existing records --ИСПРАВИТЬ!! ССЫЛКА МОЖЕТ БЫТЬ В ТАБЛИЦЕ, НО УБИТА. ЕЕ НАДО ВОСКРЕСИТЬ!!
  ) loop
  if A.relationship_id='Subsumes' then
    insert into concept_relationship values (A.concept_id_1, A.concept_id_2, 'Subsumes', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);
    insert into concept_relationship values (A.concept_id_2, A.concept_id_1, 'Is a', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);
  else
    if coalesce(A.src_standard_concept,'C')='C' and A.trgt_standard_concept='S' and A.trgt_invalid_reason is null then
      insert into concept_relationship values (A.concept_id_1, A.concept_id_2, 'Mapped from', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);
      insert into concept_relationship values (A.concept_id_2, A.concept_id_1, 'Maps to', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);    
    elseif A.trgt_invalid_reason is null then
      --manual correction for standard_concept
      update concept set standard_concept='S' where concept_id=A.concept_id_1;
      update concept set standard_concept=null where concept_id=A.concept_id_2;
      insert into concept_relationship values (A.concept_id_1, A.concept_id_2, 'Mapped from', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);
      insert into concept_relationship values (A.concept_id_2, A.concept_id_1, 'Maps to', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);
    else
      insert into concept_relationship values (A.concept_id_1, A.concept_id_2, 'Mapped from', to_date('20190201','yyyymmdd'), to_date('20190201','yyyymmdd'),'D');
      insert into concept_relationship values (A.concept_id_2, A.concept_id_1, 'Maps to', to_date('20190201','yyyymmdd'), to_date('20190201','yyyymmdd'),'D');  
    end if;
  end if;
  end loop;
    --one concept have invalid_reason='U', so prolong relationship
    insert into concept_relationship values (45756773, 44777688, 'Mapped from', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);
    insert into concept_relationship values (44777688, 45756773, 'Maps to', to_date('20190201','yyyymmdd'), to_date('20991231','yyyymmdd'),null);
end $$;

--create 'Maps to' to self for all 'S'
WITH to_be_upserted AS (
    SELECT c.concept_id, c.valid_start_date, lat.relationship_id FROM concept c
    LEFT JOIN concept_relationship cr ON cr.concept_id_1=c.concept_id AND cr.concept_id_1=cr.concept_id_2 AND cr.relationship_id='Maps to' AND cr.invalid_reason IS NULL
    CROSS JOIN LATERAL (SELECT case when generate_series=1 then 'Maps to' ELSE 'Mapped from' END AS relationship_id FROM generate_series(1,2)) lat
    WHERE c.standard_concept='S' AND c.invalid_reason IS NULL AND cr.concept_id_1 IS NULL
),
to_be_updated AS (
    UPDATE concept_relationship cr
    SET invalid_reason = NULL, valid_end_date = TO_DATE ('20991231', 'yyyymmdd')
    FROM to_be_upserted up
    WHERE cr.invalid_reason IS NOT NULL
    AND cr.concept_id_1 = up.concept_id AND cr.concept_id_2 = up.concept_id AND cr.relationship_id = up.relationship_id
    RETURNING cr.*
)
    INSERT INTO concept_relationship
    SELECT tpu.concept_id, tpu.concept_id, tpu.relationship_id, tpu.valid_start_date, TO_DATE ('20991231', 'yyyymmdd'), NULL 
    FROM to_be_upserted tpu 
    WHERE (tpu.concept_id, tpu.concept_id, tpu.relationship_id) 
    NOT IN (
        SELECT up.concept_id_1, up.concept_id_2, up.relationship_id FROM to_be_updated up
        UNION ALL
        SELECT cr_int.concept_id_1, cr_int.concept_id_2, cr_int.relationship_id FROM concept_relationship cr_int 
        WHERE cr_int.concept_id_1=cr_int.concept_id_2 AND cr_int.relationship_id IN ('Maps to','Mapped from')
    );

--update names (preserve old names in synonyms)
update concept c set concept_name=n.new_name
from dev_test.newconceptnames n
where n.concept_id=c.concept_id;

--fix synonyms
delete from concept_synonym where concept_synonym_name<>trim(concept_synonym_name) and concept_id in (38004684,38004685,38004686,38004698);

--new synonyms
insert into concept_synonym
select concept_id, concept_synonym_name, 4180186 From dev_test.synonyms s where concept_id not in (select concept_id from devv5.concept_synonym);

--update domains
update concept c set domain_id=d.domain_id
from dev_test.domains d
where d.concept_id=c.concept_id;

--update classes
update concept c set concept_class_id=cl.concept_class_id
from dev_test.classes cl
where cl.concept_id=c.concept_id;

--change concept_code from 'OMOP generated' to OMOP||nextvalue [AVOF-1438]
update concept c set concept_code='OMOP'||i.new_concept_code
from (
	select concept_id, row_number() over() + (select max(replace(concept_code, 'OMOP','')::int4) from concept where concept_code like 'OMOP%'  and concept_code not like '% %') as new_concept_code
	from concept where domain_id <> 'Metadata' and concept_code= 'OMOP generated'
) as i
where c.concept_id=i.concept_id;
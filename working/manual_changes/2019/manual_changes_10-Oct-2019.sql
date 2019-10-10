--add new UCUM concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32708, 'trillion copies per milliliter', 'Unit', 'UCUM', 'Unit', 'S', '10*12.{copies}/mL', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32709, 'million copies per milliliter', 'Unit', 'UCUM', 'Unit', 'S', '10*6.{copies}/mL', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32710, 'liter per minute per square meter', 'Unit', 'UCUM', 'Unit', 'S', 'L/min/m2', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

--concept_name to concept_synonym insertion for new and existing UCUM concepts
insert into concept_synonym
select c.concept_id, c.concept_name, 4180186
from concept c
         left join concept_synonym cs
                   on c.concept_id = cs.concept_id
                       and c.concept_name = cs.concept_synonym_name
where c.vocabulary_id = 'UCUM'
  and c.concept_name <> 'Duplicate of UCUM Concept, do not use, use replacement from CONCEPT_RELATIONSHIP table instead'
  and cs.concept_id is null;

--concept_relationship insertion
insert into concept_relationship values(32708,32708,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32708,32708,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32709,32709,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32709,32709,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32710,32710,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32710,32710,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);

--add new UCUM http://forums.ohdsi.org/t/units-mutations-per-megabase/6856

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32608, 'mutations per megabase', 'Unit', 'UCUM', 'Unit', 'S', '{mutations}/{megabase}', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept_relationship values(32608,32608,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32608,32608,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);

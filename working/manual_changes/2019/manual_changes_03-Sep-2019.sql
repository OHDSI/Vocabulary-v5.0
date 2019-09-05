--new concept https://forums.ohdsi.org/t/new-concept-ids-for-cost-and-payer-plan-in-korea/7841
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32693, 'Health examination', 'Visit', 'Visit', 'Visit', 'S', 'HE', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept_relationship values(32693,32693,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32693,32693,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
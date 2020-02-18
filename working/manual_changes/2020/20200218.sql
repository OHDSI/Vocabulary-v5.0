--32738
SELECT MAX (concept_id) + 1 FROM devv5.concept WHERE concept_id >= 31967 AND concept_id < 72245;

--add new UCUM concepts
--32738: cm/s
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32738, 'centimeter per second', 'Unit', 'UCUM', 'Unit', 'S', 'cm/s', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
--32739: mL/m2
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32739, 'milliliter per square meter', 'Unit', 'UCUM', 'Unit', 'S', 'ml/m2', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

--concept_relationship insertion
insert into concept_relationship values(32738,32738,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32739,32739,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
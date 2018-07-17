--fix UCUM names: picomol -> picomole
update concept set concept_name='picomole per gram hemoglobin' where concept_id=44777641;
update concept set concept_name='picomole per hour and milligram of hemoglobin' where concept_id=44777642;
update concept set concept_name='picomole per kilogram' where concept_id=44777643;

--add new UCUM: ug/mmol
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32408, 'microgram per millimole', 'Unit', 'UCUM', 'Unit', 'S', 'ug/mmol', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

--AVOF-907
delete from concept_synonym cs where cs.concept_id in (select c.concept_id from concept c where c.vocabulary_id='ICD10' and c.concept_name like 'Invalid%');
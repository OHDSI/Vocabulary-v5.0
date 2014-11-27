-- Add combination of Measurement and Procedure
insert into concept (concept_id,  concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (56, 'Measurement/Procedure', 'Metadata', 'Domain', 'Domain', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into domain (domain_id, domain_name, domain_concept_id)
values ('Meas/Procedure', 'Measurement/Procedure', 56);
--Add new RxE form 'Plant Bud for Smoking'
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32723, 'Plant Bud for Smoking', 'Drug', 'RxNorm Extension', 'Dose Form', null, 'OMOP4860404', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);

insert into concept_synonym (concept_id, concept_synonym_name, language_concept_id)
values (32723, 'Plant Bud for Smoking',4180186);
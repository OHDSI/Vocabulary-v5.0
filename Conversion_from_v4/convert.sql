-- add vocabualary_ids 65 and 66
insert into vocabulary (vocabulary_id, vocabulary_name) values (65, 'Currency');
insert into vocabulary (vocabulary_id, vocabulary_name) values (66, 'Concept Relationship');


-- create relationship concepts


insert into concept (concept_id,  concept_name, concept_level, concept_class, vocabulary_id, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (seq_concept.nextval, 'Avaible in biobank', 1, 'Biobank Flag', 60, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);


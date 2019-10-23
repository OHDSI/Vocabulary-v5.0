--Includes all necessary inserts for the proper work of load stage

--Some concepts should be inserted before other load_stage
INSERT INTO concept(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES
       (2100000000, 'LOINC System', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000001, 'LOINC Component', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000002, 'LOINC Scale', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000003, 'LOINC Time', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000004, 'LOINC Method', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000005, 'LOINC Property', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000006, 'LOINC Attribute', 'Metadata', 'Concept Class', 'Concept Class', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000007, 'Has system', 'Metadata', 'Relationship', 'Relationship', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL),
       (2100000008, 'System of', 'Metadata', 'Relationship', 'Relationship', NULL, 'OMOP generated', '1970-01-01', '2099-12-31', NULL)
       ;

INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id) VALUES
('LOINC System', 'LOINC System', 2100000000),
('LOINC Component', 'LOINC Component', 2100000001),
('LOINC Scale', 'LOINC Scale', 2100000002),
('LOINC Time', 'LOINC Time', 2100000003),
('LOINC Method', 'LOINC Method', 2100000004),
('LOINC Property', 'LOINC Property', 2100000005),
('LOINC Attribute', 'LOINC Attribute', 2100000006)
;

INSERT INTO relationship(relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id) VALUES
('Has system', 'Has system', 0, 0, 'System of', 2100000007),
('System of', 'System of', 0, 0, 'Has system', 2100000008);
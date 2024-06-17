--domain_id and concept_class_id to attributes equivalency
--SNOMED attributes to be used for mapping (all of Domain-Class permutations are possible)
--Table to be populated wit STY associated with CDISC CUIs
TRUNCATE TABLE concept_class_lookup;
CREATE TABLE concept_class_lookup
(attribute varchar, --sty from meta_mrsty
concept_class varchar,
domain_id varchar);




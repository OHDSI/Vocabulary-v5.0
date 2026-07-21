DELETE FROM dev_veterinary.concept_manual where vocabulary_id != 'SNOMED Veterinary';
DELETE FROM dev_veterinary.concept_relationship_synonym where vocabulary_id != 'SNOMED Veterinary'
DELETE FROM dev_veterinary.concept_relationship_manual where vocabulary_id_1 != 'SNOMED Veterinary' and vocabulary_id_2 != 'SNOMED Veterinary'

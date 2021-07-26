-- Create new vocabulary OMOP Genomic
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'OMOP Genomic',
	pVocabulary_name		=> 'OMOP Genomic vocabulary',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

-- remove constraints for changing relationship_ids
ALTER TABLE relationship drop CONSTRAINT fpk_relationship_reverse;
ALTER TABLE concept_relationship drop CONSTRAINT xpk_concept_relationship;
ALTER TABLE concept_relationship drop CONSTRAINT fpk_concept_relationship_id;
ALTER TABLE relationship drop CONSTRAINT fpk_relationship_concept;

-- update relationship_ids
update relationship
set reverse_relationship_id = 'Is transcribed to'
where relationship_concept_id = 32919;

update relationship
set relationship_id = 'Is transcribed to'
where relationship_concept_id = 32920;

update relationship
set reverse_relationship_id = 'Is translated to'
where relationship_concept_id = 32921;

update relationship
set relationship_id = 'Is translated to'
where relationship_concept_id = 32922;

update concept_relationship
set relationship_id = 'Is transcribed to'
where relationship_id = 'Is transcribed from';

update concept_relationship
set relationship_id = 'Is translated to'
where relationship_id = 'Is translated from';

--add constraints for changed relationship_ids
ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_concept FOREIGN KEY (relationship_concept_id) REFERENCES concept (concept_id);
ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE concept_relationship ADD CONSTRAINT xpk_concept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id);
ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_id FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);

-- remove constraints for changing concept_classes
ALTER TABLE concept drop CONSTRAINT fpk_concept_class;
ALTER TABLE concept_class drop CONSTRAINT xpk_concept_class;
ALTER TABLE concept_class drop CONSTRAINT fpk_concept_class_concept;


-- update concept_classes
update concept_class
set concept_class_id = 'DNA Variant',
concept_class_name = 'DNA Variant'
where concept_class_concept_id = 32924;

update concept 
set concept_class_id = 'DNA Variant'
where concept_class_id = 'Genomic Variant';

update concept_class
set concept_class_id = 'Genetic Variation',
concept_class_name = 'Genetic Variation'
where concept_class_concept_id = 32925;

update concept 
set concept_class_id = 'Genetic Variation'
where concept_class_id = 'Gene';

update concept_class
set concept_class_id = 'RNA Variant',
concept_class_name = 'RNA Variant'
where concept_class_concept_id = 32923;

update concept 
set concept_class_id = 'RNA Variant'
where concept_class_id = 'Transcript Variant';


--add constraints for changed concept_classes
ALTER TABLE concept_class ADD CONSTRAINT xpk_concept_class PRIMARY KEY (concept_class_id);
ALTER TABLE concept_class ADD CONSTRAINT fpk_concept_class_concept FOREIGN KEY (concept_class_concept_id) REFERENCES concept (concept_id);
ALTER TABLE concept ADD CONSTRAINT fpk_concept_class FOREIGN KEY (concept_class_id) REFERENCES concept_class (concept_class_id);


-- replace concept_code and vocabulary for genomic concepts
update concept c
set concept_code = omop_can_code,
vocabulary_id = 'OMOP Genomic'
from dev_dkaduk.upd_concept_june a 
where a.concept_id = c.concepT_id;

-- replace 'OMOP Extension' vocabulary to 'OMOP Genomic' for genomic concepts
update concept c
set vocabulary_id = 'OMOP Genomic'
where vocabulary_id = 'OMOP Extension'
and concept_class_id like '%Variant';

-- replace 'HGNC' vocabulary to 'OMOP Genomic' for genomic concepts
update concept c
set vocabulary_id = 'OMOP Genomic'
where vocabulary_id = 'HGNC'
;




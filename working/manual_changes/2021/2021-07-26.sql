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

-- change hierarchy direction
update relationship
set is_hierarchical = 1,
defines_ancestry = 1 
where relationship_concept_id = 32919;

update relationship
set is_hierarchical = 0,
defines_ancestry = 0
where relationship_concept_id = 32920;

update relationship
set is_hierarchical = 1,
defines_ancestry = 1 
where relationship_concept_id = 32921;

update relationship
set is_hierarchical = 0,
defines_ancestry = 0
where relationship_concept_id = 32922;


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





/************************

 ####### #     # ####### ######      #####  ######  #     #           #######    ###                                           
 #     # ##   ## #     # #     #    #     # #     # ##   ##    #    # #           #  #    # #####  ###### #    # ######  ####  
 #     # # # # # #     # #     #    #       #     # # # # #    #    # #           #  ##   # #    # #       #  #  #      #      
 #     # #  #  # #     # ######     #       #     # #  #  #    #    # ######      #  # #  # #    # #####    ##   #####   ####  
 #     # #     # #     # #          #       #     # #     #    #    #       #     #  #  # # #    # #        ##   #           # 
 #     # #     # #     # #          #     # #     # #     #     #  #  #     #     #  #   ## #    # #       #  #  #      #    # 
 ####### #     # ####### #           #####  ######  #     #      ##    #####     ### #    # #####  ###### #    # ######  ####  
                                                                              

script to create the required indexes within OMOP data model, version 5.0 for SQL Server database

last revised: 12 Oct 2014

author:  Patrick Ryan

description:  These indices are considered a minimal requirement to ensure adequate performance of analyses.

*************************/


/************************

Standardized vocabulary

************************/

CREATE INDEX idx_concept_concept_id ON concept (concept_id ASC);
CREATE INDEX idx_concept_code ON concept (concept_code ASC);
CREATE INDEX idx_concept_vocabluary_id ON concept (vocabulary_id ASC);
CREATE INDEX idx_concept_domain_id ON concept (domain_id ASC);
CREATE INDEX idx_concept_class_id ON concept (concept_class_id ASC);

CREATE INDEX idx_vocabulary_vocabulary_id ON vocabulary (vocabulary_id ASC);

CREATE INDEX idx_domain_domain_id ON domain (domain_id ASC);

CREATE INDEX idx_concept_class_class_id ON concept_class (concept_class_id ASC);

CREATE INDEX idx_concept_relationship_id_1 ON concept_relationship (concept_id_1 ASC); 
CREATE INDEX idx_concept_relationship_id_2 ON concept_relationship (concept_id_2 ASC); 
CREATE INDEX idx_concept_relationship_id_3 ON concept_relationship (relationship_id ASC); 

CREATE INDEX idx_relationship_relationship_id ON relationship (relationship_id ASC);

CREATE INDEX idx_concept_synonym_id ON concept_synonym (concept_id ASC);

CREATE INDEX idx_concept_ancestor_id_1 ON concept_ancestor (ancestor_concept_id ASC);
CREATE INDEX idx_concept_ancestor_id_2 ON concept_ancestor (descendant_concept_id ASC);

CREATE INDEX idx_source_to_concept_map_id_1 ON source_to_concept_map (source_vocabulary_id ASC);
CREATE INDEX idx_source_to_concept_map_id_2 ON source_to_concept_map (target_vocabulary_id ASC);
CREATE INDEX idx_source_to_concept_map_id_3 ON source_to_concept_map (target_concept_id ASC);
CREATE INDEX idx_source_to_concept_map_code ON source_to_concept_map (source_code ASC);

CREATE INDEX idx_drug_strength_id_1 ON drug_strength (drug_concept_id ASC);
CREATE INDEX idx_drug_strength_id_2 ON drug_strength (ingredient_concept_id ASC);

CREATE INDEX idx_cohort_definition_id ON cohort_definition (cohort_definition_id ASC);
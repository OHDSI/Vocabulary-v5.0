/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/


DROP TABLE concept CASCADE CONSTRAINTS PURGE;
DROP TABLE relationship CASCADE CONSTRAINTS PURGE;
DROP TABLE concept_relationship PURGE;
DROP TABLE concept_ancestor PURGE;
DROP TABLE concept_synonym PURGE;
DROP TABLE source_to_concept_map PURGE;
DROP TABLE drug_strength PURGE;
DROP TABLE VOCABULARY PURGE;

--add table RELATIONSHIP

CREATE TABLE relationship
(
  relationship_id       INTEGER                 NOT NULL,                     
  relationship_name     VARCHAR2(256 BYTE)      NOT NULL,                                 
  is_hierarchical       INTEGER                 NOT NULL,                     
  defines_ancestry      INTEGER                 DEFAULT 1                     NOT NULL,
  reverse_relationship  INTEGER                                            
) NOLOGGING;  

COMMENT ON TABLE relationship IS 'A list of relationship between concepts. Some of these relationships are generic (e.g. "Subsumes" relationship), others are domain-specific.';

COMMENT ON COLUMN relationship.relationship_id IS 'The type of relationship captured by the relationship record.';

COMMENT ON COLUMN relationship.relationship_name IS 'The text that describes the relationship type.';

COMMENT ON COLUMN relationship.is_hierarchical IS 'Defines whether a relationship defines concepts into classes or hierarchies. Values are Y for hierarchical relationship or NULL if not';

COMMENT ON COLUMN relationship.defines_ancestry IS 'Defines whether a hierarchical relationship contributes to the concept_ancestor table. These are subsets of the hierarchical relationships. Valid values are Y or NULL.';

COMMENT ON COLUMN relationship.reverse_relationship IS 'relationship ID of the reverse relationship to this one. Corresponding records of reverse relationships have their concept_id_1 and concept_id_2 swapped.';

CREATE UNIQUE INDEX XPKRELATIONSHIP_TYPE ON relationship
(relationship_id);

ALTER TABLE relationship ADD (
  CONSTRAINT xpkrelationship_type
  PRIMARY KEY
  (relationship_id)
  USING INDEX xpkrelationship_type
  ENABLE VALIDATE);

--add table drug_strength

CREATE TABLE drug_strength
(
   drug_concept_id            INTEGER NOT NULL,
   ingredient_concept_id      INTEGER NOT NULL,
   amount_value               NUMBER,
   amount_unit                VARCHAR2 (60 BYTE),
   concentration_value        NUMBER,
   concentration_enum_unit    VARCHAR2 (60 BYTE),
   concentration_denom_unit   VARCHAR2 (60 BYTE),
   valid_start_date           DATE NOT NULL,
   valid_end_date             DATE NOT NULL,
   invalid_reason             VARCHAR2 (1 BYTE)
);

--add table vocabulary

CREATE TABLE VOCABULARY
(
   VOCABULARY_ID     INTEGER NOT NULL,
   VOCABULARY_NAME   VARCHAR2 (256 BYTE) NOT NULL
);

--fill tables

INSERT INTO devv5.relationship_conversion (relationship_id,
                                           relationship_id_new)
   SELECT   ROWNUM
          + (SELECT MAX (relationship_id)
               FROM devv5.relationship_conversion)
             AS rn,
          relationship_id
     FROM ( (SELECT relationship_id FROM devv5.relationship
             UNION ALL
             SELECT reverse_relationship_id FROM devv5.relationship)
           MINUS
           SELECT relationship_id_new FROM devv5.relationship_conversion);
COMMIT;

CREATE TABLE t_concept_class_conversion

AS
   (SELECT concept_class, concept_class_id_new
      FROM devv5.concept_class_conversion
     WHERE concept_class_id_new NOT IN (  SELECT concept_class_id_new
                                            FROM devv5.concept_class_conversion
                                        GROUP BY concept_class_id_new
                                          HAVING COUNT (*) > 1))
   UNION ALL
   (  SELECT concept_class_id_new AS concept_class, concept_class_id_new
        FROM devv5.concept_class_conversion
    GROUP BY concept_class_id_new
      HAVING COUNT (*) > 1)
   UNION ALL
   (SELECT concept_class_id AS concept_class,
           concept_class_id AS concept_class_id_new
      FROM devv5.concept
    MINUS
    SELECT concept_class_id_new, concept_class_id_new
      FROM devv5.concept_class_conversion);
           
 INSERT INTO relationship (relationship_id,
                          relationship_name,
                          is_hierarchical,
                          defines_ancestry,
                          reverse_relationship)
   SELECT rc.relationship_id,
          r.relationship_name,
          r.is_hierarchical,
          r.defines_ancestry,
          rc_rev.relationship_id
     FROM devv5.relationship r,
          devv5.relationship_conversion rc,
          devv5.relationship_conversion rc_rev
    WHERE     r.relationship_id = rc.relationship_id_new
          AND r.reverse_relationship_id = rc_rev.relationship_id_new;
COMMIT;

CREATE TABLE concept NOLOGGING as
SELECT concept_id,
                     concept_name,
                     concept_level,
                     concept_class,
                     vocabulary_id,
                     concept_code,
                     valid_start_date,
                     valid_end_date,
                     invalid_reason
FROM (
    select distinct
      c.concept_id, c.concept_name,
      case c.vocabulary_id 
        when 'SNOMED' then -- full hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when c.descendant_concept_id is null then 1 -- if it has no children then leaf
                when p.ancestor_concept_id is null then 3 -- if it has no parents then top guy
                else 2 -- in the middle
              end
          end
        when 'ICD9CM' then 0 -- all source
        when 'ICD9Proc' then  -- hierarchy, but no top guys
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when c.descendant_concept_id is null then 1 -- if it has no children then leaf
                else 2 -- in the middle
              end
          end
        when 'CPT4' then -- full hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when c.descendant_concept_id is null then 1 -- if it has no children then leaf
                when p.ancestor_concept_id is null then 3 -- if it has no parents then top guy
                else 2 -- in the middle
              end
          end
        when 'LOINC' then -- full hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when c.descendant_concept_id is null then 1 -- if it has no children then leaf
                when p.ancestor_concept_id is null then 3 -- if it has no parents then top guy
                else 2 -- in the middle
              end
          end
        when 'NDFRT' then -- full hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when p.ancestor_concept_id is null then 4 -- if it has no parents then top guy
                else 3 -- in the middle
              end
          end
        when 'RxNorm' then -- specialized hierarchy
          case 
            when c.standard_concept is null then 0
            else
              case concept_class_id
                when 'Ingredient' then 2
                when 'Clinical Drug' then 1
                when 'Branded Drug Box' then 1
                when 'Clinical Drug Box' then 1
                when 'Quant Branded Box' then 1
                when 'Quant Clinical Box' then 1
                when 'Quant Clinical Drug' then 1
                when 'Quant Branded Drug' then 1
                when 'Clinical Drug Comp' then 1
                when 'Branded Drug Comp' then 1
                when 'Branded Drug Form' then 1
                when 'Clinical Drug Form' then 1
				else 0
              end
          end
        when 'DPD' then -- same as RxNorm
          case 
            when c.standard_concept is null then 0
            else
              case concept_class_id
                when 'Ingredient' then 2
                when 'Clinical Drug' then 1
                when 'Branded Drug Box' then 1
                when 'Clinical Drug Box' then 1
                when 'Quant Branded Box' then 1
                when 'Quant Clinical Box' then 1
                when 'Quant Clinical Drug' then 1
                when 'Quant Branded Drug' then 1
                when 'Clinical Drug Comp' then 1
                when 'Branded Drug Comp' then 1
                when 'Branded Drug Form' then 1
                when 'Clinical Drug Form' then 1
				else 0
              end
          end		  
        when 'NDC' then 0
        when 'GPI' then 0
        when 'Race' then -- 2 level hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when c.descendant_concept_id is null then 1 -- if it has no children then leaf
                else 2 -- on top
              end
          end
        when 'MedDRA' then -- specialized hierarchy
          case 
            when c.standard_concept is null then 0
            else
              case concept_class_id
                when 'LLT' then 1
                when 'PT' then 2
                when 'HLT' then 3
                when 'HLGT' then 4
                when 'SOC' then 5
              end
          end
        when 'Multum' then 0
        when 'Read' then 0
        when 'OXMIS' then 0
        when 'Indication' then 
          case 
            when c.standard_concept is null then 0
            else 3 -- Drug hierarchy on top of Ingredient (level 2)
          end
        when 'ETC' then
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when p.ancestor_concept_id is null then 4 -- if it has no parents then top guy
                else 3 -- in the middle
              end
          end
        when 'ATC' then 
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when p.ancestor_concept_id is null then 4 -- if it has no parents then top guy
                else 3 -- in the middle
              end
          end
        when 'Multilex' then 
          case 
            when c.standard_concept is null then 0
            else
              case concept_class_id
                when 'Ingredient' then 2
                when 'Clinical Drug' then 1
                when 'Branded Drug' then 1
                when 'Clinical Pack' then 1
                when 'Branded Pack' then 1
                else 0
              end
          end
        when 'Visit' then -- flat list
          case 
            when c.standard_concept is null then 0
            else 2 -- on top of place of service
          end
        when 'SMQ' then
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when c.descendant_concept_id is null then 1 -- if it has no children then leaf
                when p.ancestor_concept_id is null then 3 -- if it has no parents then top guy
                else 2 -- in the middle
              end
          end
        when 'VA Class' then 
          case 
            when c.standard_concept is null then 0
            else 
              case 
                when p.ancestor_concept_id is null then 4 -- if it has no parents then top guy
                else 3 -- in the middle
              end
          end
        when 'Cohort' then 0
        when 'ICD10' then 0
        when 'ICD10PCS' then
          case 
            when c.standard_concept is null then 0
            else 1
          end		
        when 'MDC' then 
          case 
            when c.standard_concept is null then 0
            else 2 -- on top of DRG (level 1)
          end
        when 'MeSH' then 0
        when 'Specialty' then
          case 
            when c.standard_concept is null then 0
            else 2 -- on top of DRG (level 1)
          end
        when 'SPL' then
          case 
            when c.standard_concept is null then 0
            else 3 -- on top of Ingredient (level 2)
          end
        when 'GCN_SEQNO' then 0
        when 'CCS' then 0
        when 'OPCS4' then 1
        when 'Gemscript' then 0
        when 'HES Specialty' then 0
        when 'ICD10CM' then 0
		when 'DA_France' then -- specialized hierarchy
          case 
            when c.standard_concept is null then 0
            else
              case concept_class_id
                when 'Ingredient' then 2
                when 'Clinical Drug' then 1
                when 'Branded Drug Box' then 1
                when 'Clinical Drug Box' then 1
                when 'Quant Branded Box' then 1
                when 'Quant Clinical Box' then 1
                when 'Quant Clinical Drug' then 1
                when 'Quant Branded Drug' then 1
                when 'Clinical Drug Comp' then 1
                when 'Branded Drug Comp' then 1
                when 'Branded Drug Form' then 1
                when 'Clinical Drug Form' then 1
                else 0
              end
        end		
        when 'NFC' then 4
		else -- flat list
          case
            when c.standard_concept is null then 0
            else 1
          end
      end as concept_level,
      ccc.concept_class,
              vc.vocabulary_id_v4 as vocabulary_id,
              c.concept_code,
              c.valid_start_date,
              c.valid_end_date,
              c.invalid_reason
    from devv5.concept c
    join t_concept_class_conversion ccc on ccc.concept_class_id_new = c.concept_class_id
    join devv5.vocabulary_conversion vc on vc.vocabulary_id_v5 = c.vocabulary_id
    left join devv5.concept_ancestor p on p.descendant_concept_id = c.concept_id and p.ancestor_concept_id!=p.descendant_concept_id -- get parents
    left join devv5.concept_ancestor c on c.ancestor_concept_id = c.concept_id and c.ancestor_concept_id!=c.descendant_concept_id -- get children
    WHERE EXISTS (SELECT 1 -- where there is at least one standard concept in the same vocabulary
                        FROM devv5.concept c_int
                       WHERE     c_int.vocabulary_id = c.vocabulary_id
                             AND standard_concept in ('C', 'S')
                  )  
    OR c.concept_code in ('OMOP generated','No matching concept')
);    

DROP TABLE t_concept_class_conversion PURGE;

COMMENT ON TABLE concept IS 'A list of all valid terminology concepts across domains and their attributes. Concepts are derived from existing standards.';

COMMENT ON COLUMN concept.concept_id IS 'A system-generated identifier to uniquely identify each concept across all concept types.';

COMMENT ON COLUMN concept.concept_name IS 'An unambiguous, meaningful and descriptive name for the concept.';

COMMENT ON COLUMN concept.concept_level IS 'The level of hierarchy associated with the concept. Different concept levels are assigned to concepts to depict their seniority in a clearly defined hierarchy, such as drugs, conditions, etc. A concept level of 0 is assigned to concepts that are not part of a standard vocabulary, but are part of the vocabulary for reference purposes (e.g. drug form).';

COMMENT ON COLUMN concept.concept_class IS 'The category or class of the concept along both the hierarchical tree as well as different domains within a vocabulary. Examples are ''Clinical Drug'', ''Ingredient'', ''Clinical Finding'' etc.';

COMMENT ON COLUMN concept.vocabulary_id IS 'A foreign key to the vocabulary table indicating from which source the concept has been adapted.';

COMMENT ON COLUMN concept.concept_code IS 'The concept code represents the identifier of the concept in the source data it originates from, such as SNOMED-CT concept IDs, RxNorm RXCUIs etc. Note that concept codes are not unique across vocabularies.';

COMMENT ON COLUMN concept.valid_start_date IS 'The date when the was first recorded.';

COMMENT ON COLUMN concept.valid_end_date IS 'The date when the concept became invalid because it was deleted or superseded (updated) by a new concept. The default value is 31-Dec-2099.';

COMMENT ON COLUMN concept.invalid_reason IS 'Concepts that are replaced with a new concept are designated "Updated" (U) and concepts that are removed without replacement are "Deprecated" (D).';

CREATE INDEX concept_code ON concept (concept_code, vocabulary_id) NOLOGGING;
CREATE UNIQUE INDEX XPKconcept ON concept (concept_id) NOLOGGING;

ALTER TABLE concept ADD (
  CHECK ( invalid_reason IN ('D', 'U'))
  ENABLE VALIDATE,
  CONSTRAINT XPKCONCEPT
  PRIMARY KEY
  (concept_id)
  USING INDEX XPKCONCEPT
  ENABLE VALIDATE);      

--add table concept_relationship

CREATE TABLE concept_relationship NOLOGGING as
SELECT concept_id_1,
                                  concept_id_2,
                                  relationship_id,
                                  valid_start_date,
                                  valid_end_date,
                                  invalid_reason
FROM (                                  
   SELECT r.concept_id_1,
          r.concept_id_2,
          rc.relationship_id AS relationship_id,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM devv5.concept_relationship r, devv5.relationship_conversion rc
    WHERE     r.relationship_id = rc.relationship_id_new
          AND EXISTS
                 (SELECT 1
                    FROM concept c_int
                   WHERE c_int.concept_id = r.concept_id_1)
          AND EXISTS
                 (SELECT 1
                    FROM concept c_int
                   WHERE c_int.concept_id = r.concept_id_2)
);


INSERT /*+ APPEND */
      INTO  concept_relationship (concept_id_1,
                                  concept_id_2,
                                  relationship_id,
                                  valid_start_date,
                                  valid_end_date,
                                  invalid_reason)
   SELECT c.concept_id AS concept_id_1,
          d.domain_concept_id AS concept_id_2,
          360 AS relationship_id,                                  --Is domain
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM devv5.concept c, devv5.domain d
    WHERE     c.domain_id = d.domain_id
          AND EXISTS
                 (SELECT 1
                    FROM concept c_int
                   WHERE c_int.concept_id = c.concept_id)
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept_relationship r_int
                   WHERE     r_int.concept_id_1 = c.concept_id
                         AND r_int.concept_id_2 = d.domain_concept_id
                         AND relationship_id = 360)
   UNION ALL
   SELECT d.domain_concept_id AS concept_id_1,
          c.concept_id AS concept_id_2,
          359 AS relationship_id,                            --Domain subsumes
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM devv5.concept c, devv5.domain d
    WHERE     c.domain_id = d.domain_id
          AND EXISTS
                 (SELECT 1
                    FROM concept c_int
                   WHERE c_int.concept_id = c.concept_id)    
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept_relationship r_int
                   WHERE     r_int.concept_id_1 = d.domain_concept_id
                         AND r_int.concept_id_2 = c.concept_id
                         AND relationship_id = 359);
COMMIT;

COMMENT ON TABLE concept_relationship IS 'A list of relationship between concepts. Some of these relationships are generic (e.g. ''Subsumes'' relationship), others are domain-specific.';

COMMENT ON COLUMN concept_relationship.concept_id_1 IS 'A foreign key to the concept in the concept table associated with the relationship. relationships are directional, and this field represents the source concept designation.';

COMMENT ON COLUMN concept_relationship.concept_id_2 IS 'A foreign key to the concept in the concept table associated with the relationship. relationships are directional, and this field represents the destination concept designation.';

COMMENT ON COLUMN concept_relationship.relationship_id IS 'The type of relationship as defined in the relationship table.';

COMMENT ON COLUMN concept_relationship.valid_start_date IS 'The date when the the relationship was first recorded.';

COMMENT ON COLUMN concept_relationship.valid_end_date IS 'The date when the relationship became invalid because it was deleted or superseded (updated) by a new relationship. Default value is 31-Dec-2099.';

COMMENT ON COLUMN concept_relationship.invalid_reason IS 'Reason the relationship was invalidated. Possible values are D (deleted), U (replaced with an update) or NULL when valid_end_date has the default  value.';

CREATE UNIQUE INDEX xpkconcept_relationship ON concept_relationship
(concept_id_1, concept_id_2, relationship_id) NOLOGGING; 


ALTER TABLE concept_relationship ADD (
  CHECK ( invalid_reason IN ('D', 'U'))
  ENABLE VALIDATE,
  CHECK ( invalid_reason IN ('D', 'U'))
  ENABLE VALIDATE,
  CHECK (invalid_reason in ('D', 'U'))
  ENABLE VALIDATE,
  CONSTRAINT xpkconcept_relationship
  PRIMARY KEY
  (concept_id_1, concept_id_2, relationship_id)
  USING INDEX xpkconcept_relationship
  ENABLE VALIDATE);

 
ALTER TABLE concept_relationship ADD (
  CONSTRAINT concept_REL_CHILD_FK 
  FOREIGN KEY (concept_id_2) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE,
  CONSTRAINT concept_REL_PARENT_FK 
  FOREIGN KEY (concept_id_1) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE,
  CONSTRAINT concept_REL_REL_type_FK 
  FOREIGN KEY (relationship_id) 
  REFERENCES relationship (relationship_id)
  ENABLE VALIDATE);


--add table concept_ancestor

CREATE TABLE concept_ancestor NOLOGGING as
SELECT ancestor_concept_id,
                              descendant_concept_id,
                              max_levels_of_separation,
                              min_levels_of_separation
FROM (
   SELECT ca.ancestor_concept_id,
          ca.descendant_concept_id,
          ca.max_levels_of_separation,
          ca.min_levels_of_separation
     FROM devv5.concept_ancestor ca
    WHERE     EXISTS
                 (SELECT 1
                    FROM concept c_int
                   WHERE c_int.concept_id = ca.ancestor_concept_id)
          AND EXISTS
                 (SELECT 1
                    FROM concept c_int
                   WHERE c_int.concept_id = ca.descendant_concept_id)
);


COMMENT ON TABLE concept_ancestor IS 'A specialized table containing only hierarchical relationship between concepts that may span several generations.';

COMMENT ON COLUMN concept_ancestor.ancestor_concept_id IS 'A foreign key to the concept code in the concept table for the higher-level concept that forms the ancestor in the relationship.';

COMMENT ON COLUMN concept_ancestor.descendant_concept_id IS 'A foreign key to the concept code in the concept table for the lower-level concept that forms the descendant in the relationship.';

COMMENT ON COLUMN concept_ancestor.max_levels_of_separation IS 'The maximum separation in number of levels of hierarchy between ancestor and descendant concepts. This is an optional attribute that is used to simplify hierarchic analysis. ';

COMMENT ON COLUMN concept_ancestor.min_levels_of_separation IS 'The minimum separation in number of levels of hierarchy between ancestor and descendant concepts. This is an optional attribute that is used to simplify hierarchic analysis.';

CREATE UNIQUE INDEX xpkconcept_ancestor ON concept_ancestor
(ancestor_concept_id, descendant_concept_id) NOLOGGING;

ALTER TABLE concept_ancestor ADD (
  CONSTRAINT xpkconcept_ancestor
  PRIMARY KEY
  (ancestor_concept_id, descendant_concept_id)
  USING INDEX xpkconcept_ancestor
  ENABLE VALIDATE);

ALTER TABLE concept_ancestor ADD (
  CONSTRAINT concept_ancestor_FK 
  FOREIGN KEY (ancestor_concept_id) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE,
  CONSTRAINT concept_descendant_FK 
  FOREIGN KEY (descendant_concept_id) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE);

--add table concept_synonym

CREATE TABLE concept_synonym NOLOGGING as
SELECT concept_synonym_id,
                             concept_id,
                             concept_synonym_name
FROM (
   SELECT ROWNUM AS concept_synonym_id,
          cs.concept_id,
          cs.concept_synonym_name
     FROM devv5.concept_synonym cs
    WHERE EXISTS
             (SELECT 1
                FROM concept c_int
               WHERE c_int.concept_id = cs.concept_id)
);     

COMMENT ON TABLE concept_synonym IS 'A table with synonyms for concepts that have more than one valid name or description.';

COMMENT ON COLUMN concept_synonym.concept_synonym_id IS 'A system-generated unique identifier for each concept synonym.';

COMMENT ON COLUMN concept_synonym.concept_id IS 'A foreign key to the concept in the concept table. ';

COMMENT ON COLUMN concept_synonym.concept_synonym_name IS 'The alternative name for the concept.';

CREATE UNIQUE INDEX xpkconcept_synonym ON concept_synonym
(concept_synonym_id) NOLOGGING;

ALTER TABLE concept_synonym ADD (
  CONSTRAINT xpkconcept_synonym
  PRIMARY KEY
  (concept_synonym_id)
  USING INDEX xpkconcept_synonym
  ENABLE VALIDATE);

ALTER TABLE concept_synonym ADD (
  CONSTRAINT concept_synonym_concept_FK 
  FOREIGN KEY (concept_id) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE);

--concepts with direct mappings
CREATE TABLE source_to_concept_map NOLOGGING AS
SELECT SOURCE_CODE,
                                   SOURCE_vocabulary_id,
                                   SOURCE_CODE_DESCRIPTION,
                                   TARGET_concept_id,
                                   TARGET_vocabulary_id,
                                   MAPPING_type,
                                   PRIMARY_MAP,
                                   valid_start_date,
                                   valid_end_date,
                                   invalid_reason
FROM (
   SELECT DISTINCT c1.concept_code AS SOURCE_CODE,
                   vc1.vocabulary_id_v4 AS SOURCE_vocabulary_id,
                   c1.concept_name AS SOURCE_CODE_DESCRIPTION,
                   c2.concept_id AS TARGET_concept_id,
                   vc2.vocabulary_id_v4 AS TARGET_vocabulary_id,
                   c2.domain_id AS MAPPING_type,
                   'Y' AS PRIMARY_MAP,
                   r.valid_start_date AS valid_start_date,
                   r.valid_end_date AS valid_end_date,
                   r.invalid_reason AS invalid_reason
     FROM devv5.concept c1,
          devv5.concept c2,
          devv5.concept_relationship r,
          devv5.vocabulary_conversion vc1,
          devv5.vocabulary_conversion vc2
    WHERE     c1.concept_id = r.concept_id_1
          AND c2.concept_id = r.concept_id_2
          AND r.relationship_id = 'Maps to'
          AND c1.vocabulary_id = vc1.vocabulary_id_v5
          AND c2.vocabulary_id = vc2.vocabulary_id_v5
          AND NOT (    c1.concept_name LIKE '%do not use%'
                   AND c1.vocabulary_id IN ('ICD9CM', 'ICD10', 'MedDRA')
                   AND c1.invalid_reason IS NOT NULL)
          AND EXISTS
                 (SELECT 1
                    FROM concept c_int
                   WHERE c_int.concept_id = c2.concept_id)
);

--unmapped concepts
INSERT /*+ APPEND */
      INTO  source_to_concept_map (SOURCE_CODE,
                                   SOURCE_vocabulary_id,
                                   SOURCE_CODE_DESCRIPTION,
                                   TARGET_concept_id,
                                   TARGET_vocabulary_id,
                                   MAPPING_type,
                                   PRIMARY_MAP,
                                   valid_start_date,
                                   valid_end_date,
                                   invalid_reason)
   SELECT DISTINCT c1.concept_code AS SOURCE_CODE,
                   vc1.vocabulary_id_v4 AS SOURCE_vocabulary_id,
                   c1.concept_name AS SOURCE_CODE_DESCRIPTION,
                   0 AS TARGET_concept_id,
                   0 AS TARGET_vocabulary_id,
                   'Unmapped' AS MAPPING_type,
                   'Y' AS PRIMARY_MAP,
                   c1.valid_start_date AS valid_start_date,
                   c1.valid_end_date AS valid_end_date,
                   NULL AS invalid_reason
     FROM devv5.concept c1
          LEFT JOIN devv5.concept_relationship r
             ON     r.concept_id_1 = c1.concept_id
                AND r.relationship_id = 'Maps to'
                AND r.invalid_reason IS NULL
          JOIN devv5.vocabulary_conversion vc1
             ON vc1.vocabulary_id_v5 = c1.vocabulary_id
    WHERE     r.concept_id_1 IS NULL
          AND c1.concept_code <> 'OMOP generated'
          AND c1.concept_id IN (  SELECT MIN (c2.concept_id) --remove duplicates
                                    FROM devv5.concept c2
                                GROUP BY c2.vocabulary_id,
                                         c2.concept_code,
                                         c2.valid_end_date)
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept c_int
                   WHERE c_int.concept_id = c1.concept_id)
          AND NOT EXISTS
                 (SELECT 1
                    FROM source_to_concept_map s_int
                   WHERE     s_int.source_code = c1.concept_code
                         AND s_int.source_vocabulary_id =
                                vc1.vocabulary_id_v4)
          AND NOT (    c1.concept_name LIKE '%do not use%'
                   AND c1.vocabulary_id IN ('ICD9CM', 'ICD10', 'MedDRA')
                   AND c1.invalid_reason IS NOT NULL)
          AND c1.concept_class_id <> 'Concept Class';
COMMIT;

CREATE INDEX SOURCE_TO_concept_SOURCE_idX ON source_to_concept_map
(SOURCE_CODE) NOLOGGING;

CREATE UNIQUE INDEX xpksource_to_concept_map ON source_to_concept_map
(SOURCE_vocabulary_id, TARGET_concept_id, SOURCE_CODE, valid_end_date) NOLOGGING;

ALTER TABLE source_to_concept_map ADD (
  CHECK (primary_map in ('Y'))
  ENABLE VALIDATE,
  CHECK (invalid_reason in ('D', 'U'))
  ENABLE VALIDATE,
  CONSTRAINT xpksource_to_concept_map
  PRIMARY KEY
  (SOURCE_vocabulary_id, TARGET_concept_id, SOURCE_CODE, valid_end_date)
  USING INDEX xpksource_to_concept_map
  ENABLE VALIDATE);

ALTER TABLE source_to_concept_map ADD (
  CONSTRAINT SOURCE_TO_concept_concept 
  FOREIGN KEY (TARGET_concept_id) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE);

          
INSERT INTO drug_strength
   SELECT s.drug_concept_id,
          s.ingredient_concept_id,
          s.amount_value,
          au.concept_code AS amount_unit,
          s.numerator_value AS concentration_value,
          nu.concept_code AS concentration_enum_unit,
          du.concept_code AS concentration_denom_unit,
          s.valid_start_date,
          s.valid_end_date,
          s.invalid_reason
     FROM devv5.drug_strength s
          LEFT JOIN concept au ON au.concept_id = s.amount_unit_concept_id
          LEFT JOIN concept nu ON nu.concept_id = s.numerator_unit_concept_id
          LEFT JOIN concept du
             ON du.concept_id = s.denominator_unit_concept_id;
COMMIT;

INSERT INTO VOCABULARY
   SELECT vocabulary_id_v4, vocabulary_id_v5 FROM devv5.vocabulary_conversion;
COMMIT;
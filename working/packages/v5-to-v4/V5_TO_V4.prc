CREATE OR REPLACE PROCEDURE DEVV4.v5_to_v4 
is
begin

execute immediate 'DROP TABLE concept CASCADE CONSTRAINTS PURGE';
execute immediate 'DROP TABLE relationship CASCADE CONSTRAINTS PURGE';
execute immediate 'DROP TABLE concept_relationship PURGE';
execute immediate 'DROP TABLE concept_ancestor PURGE';
execute immediate 'DROP TABLE concept_synonym PURGE';
execute immediate 'DROP TABLE source_to_concept_map PURGE';
execute immediate 'DROP TABLE drug_strength PURGE';
execute immediate 'DROP TABLE PACK_CONTENT PURGE';
execute immediate 'DROP TABLE VOCABULARY PURGE';

--add table RELATIONSHIP
execute immediate '
CREATE TABLE relationship
(
  relationship_id       INTEGER                 NOT NULL,                     
  relationship_name     VARCHAR2(256 BYTE)      NOT NULL,                                 
  is_hierarchical       INTEGER                 NOT NULL,                     
  defines_ancestry      INTEGER                 DEFAULT 1                     NOT NULL,
  reverse_relationship  INTEGER                                            
) NOLOGGING
';


execute immediate '
CREATE UNIQUE INDEX XPKRELATIONSHIP_TYPE ON relationship
(relationship_id)
';

execute immediate '
ALTER TABLE relationship ADD (
  CONSTRAINT xpkrelationship_type
  PRIMARY KEY
  (relationship_id)
  USING INDEX xpkrelationship_type
  ENABLE VALIDATE)
';

--add table drug_strength
execute immediate '
CREATE TABLE drug_strength
(
   drug_concept_id            INTEGER NOT NULL,
   ingredient_concept_id      INTEGER NOT NULL,
   amount_value               NUMBER,
   amount_unit                VARCHAR2 (60 BYTE),
   concentration_value        NUMBER,
   concentration_enum_unit    VARCHAR2 (60 BYTE),
   concentration_denom_unit   VARCHAR2 (60 BYTE),
   box_size                   NUMBER,
   valid_start_date           DATE NOT NULL,
   valid_end_date             DATE NOT NULL,
   invalid_reason             VARCHAR2 (1 BYTE)
) NOLOGGING
';

execute immediate '
CREATE TABLE PACK_CONTENT
(
  PACK_CONCEPT_ID  NUMBER                       NOT NULL,
  DRUG_CONCEPT_ID  NUMBER                       NOT NULL,
  AMOUNT           VARCHAR2(4000 BYTE),
  BOX_SIZE         NUMBER
) NOLOGGING
';

--add table vocabulary
execute immediate '
CREATE TABLE VOCABULARY
(
   VOCABULARY_ID     INTEGER NOT NULL,
   VOCABULARY_NAME   VARCHAR2 (256 BYTE) NOT NULL
)
';

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
execute immediate '
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
      FROM devv5.concept_class_conversion)
';
           
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

execute immediate q'[
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
    select
      c.concept_id, c.concept_name,
      case c.vocabulary_id 
        when 'SNOMED' then -- full hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case
                -- get children
                when not exists (select 1 from devv5.concept_ancestor ca where ca.ancestor_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)
                    then 1 -- if it has no children then leaf
                -- get parents
                when not exists (select 1 from devv5.concept_ancestor ca where ca.descendant_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)
                    then 3 -- if it has no parents then top guy
                else 2 -- in the middle
              end
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
    WHERE (EXISTS (SELECT 1 -- where there is at least one standard concept in the same vocabulary
                        FROM devv5.concept c_int
                       WHERE     c_int.vocabulary_id = c.vocabulary_id
                             AND standard_concept in ('C', 'S')
                  )  
    OR c.concept_code in ('OMOP generated','No matching concept'))
    and c.vocabulary_id='SNOMED'
    
    union all
    select
      c.concept_id, c.concept_name,
      case c.vocabulary_id 
        when 'ICD9Proc' then  -- hierarchy, but no top guys
          case 
            when c.standard_concept is null then 0
            else 
              case
                -- get children 
                when not exists (select 1 from devv5.concept_ancestor ca where ca.ancestor_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id) 
                    then 1 -- if it has no children then leaf
                else 2 -- in the middle
              end
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
    WHERE (EXISTS (SELECT 1 -- where there is at least one standard concept in the same vocabulary
                        FROM devv5.concept c_int
                       WHERE     c_int.vocabulary_id = c.vocabulary_id
                             AND standard_concept in ('C', 'S')
                  )  
    OR c.concept_code in ('OMOP generated','No matching concept'))
    and c.vocabulary_id='ICD9Proc'
    
    union all
    select
      c.concept_id, c.concept_name,
      case c.vocabulary_id 
        when 'CPT4' then -- full hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case 
                -- get children
                when not exists (select 1 from devv5.concept_ancestor ca where ca.ancestor_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)
                    then 1 -- if it has no children then leaf
                -- get parents
                when not exists (select 1 from devv5.concept_ancestor ca where ca.descendant_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)
                    then 3 -- if it has no parents then top guy
                else 2 -- in the middle
              end
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
    WHERE (EXISTS (SELECT 1 -- where there is at least one standard concept in the same vocabulary
                        FROM devv5.concept c_int
                       WHERE     c_int.vocabulary_id = c.vocabulary_id
                             AND standard_concept in ('C', 'S')
                  )  
    OR c.concept_code in ('OMOP generated','No matching concept'))
    and c.vocabulary_id='CPT4'    
    
    union all
    select
      c.concept_id, c.concept_name,
      case c.vocabulary_id 
        when 'LOINC' then -- full hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case
                -- get children
                when not exists (select 1 from devv5.concept_ancestor ca where ca.ancestor_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)
                    then 1 -- if it has no children then leaf
                -- get parents
                when not exists (select 1 from devv5.concept_ancestor ca where ca.descendant_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)
                    then 3 -- if it has no parents then top guy
                else 2 -- in the middle
              end
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
    WHERE (EXISTS (SELECT 1 -- where there is at least one standard concept in the same vocabulary
                        FROM devv5.concept c_int
                       WHERE     c_int.vocabulary_id = c.vocabulary_id
                             AND standard_concept in ('C', 'S')
                  )  
    OR c.concept_code in ('OMOP generated','No matching concept'))
    and c.vocabulary_id='LOINC'     
    
    union all
    select
      c.concept_id, c.concept_name,
      case c.vocabulary_id 
        when 'NDFRT' then -- full hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case 
                -- get parents 
                when not exists (select 1 from devv5.concept_ancestor ca where ca.descendant_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)              
                    then 4 -- if it has no parents then top guy
                else 3 -- in the middle
              end
          end
        when 'ETC' then
          case 
            when c.standard_concept is null then 0
            else 
              case 
                -- get parents 
                when not exists (select 1 from devv5.concept_ancestor ca where ca.descendant_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id) 
                    then 4 -- if it has no parents then top guy
                else 3 -- in the middle
              end
          end
        when 'ATC' then 
          case 
            when c.standard_concept is null then 0
            else 
              case
                -- get parents 
                when not exists (select 1 from devv5.concept_ancestor ca where ca.descendant_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)                  
                    then 4 -- if it has no parents then top guy
                else 3 -- in the middle
              end
          end
        when 'SMQ' then
          case 
            when c.standard_concept is null then 0
            else 
              case 
                -- get childrens 
                when not exists (select 1 from devv5.concept_ancestor ca where ca.ancestor_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)    
                    then 1 -- if it has no children then leaf
                -- get parents 
                when not exists (select 1 from devv5.concept_ancestor ca where ca.descendant_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)    
                    then 3 -- if it has no parents then top guy
                else 2 -- in the middle
              end
          end
        when 'VA Class' then 
          case 
            when c.standard_concept is null then 0
            else 
              case 
                -- get parents 
                when not exists (select 1 from devv5.concept_ancestor ca where ca.descendant_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id) 
                    then 4 -- if it has no parents then top guy
                else 3 -- in the middle
              end
          end            
        when 'Race' then -- 2 level hierarchy
          case 
            when c.standard_concept is null then 0
            else 
              case 
                -- get childrens 
                when not exists (select 1 from devv5.concept_ancestor ca where ca.ancestor_concept_id = c.concept_id and ca.ancestor_concept_id <> ca.descendant_concept_id)    
                    then 1 -- if it has no children then leaf
                else 2 -- on top
              end
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
    WHERE (EXISTS (SELECT 1 -- where there is at least one standard concept in the same vocabulary
                        FROM devv5.concept c_int
                       WHERE     c_int.vocabulary_id = c.vocabulary_id
                             AND standard_concept in ('C', 'S')
                  )  
    OR c.concept_code in ('OMOP generated','No matching concept'))
    and c.vocabulary_id in ('NDFRT','ETC','ATC','SMQ','VA Class','Race')
    
    union all
    select
      c.concept_id, c.concept_name,
      case c.vocabulary_id 
        when 'ICD9CM' then 0 -- all source
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
		when 'DPD' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end			  
        when 'RxNorm Extension' then -- same as RxNorm
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
		when 'dm+d' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end	                 
        when 'NDC' then 0
        when 'GPI' then 0
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
		when 'Gemscript' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end
		when 'GRR' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end	                   
        when 'HES Specialty' then 0
        when 'ICD10CM' then 0
		when 'BDPM' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end	        
		when 'EphMRA ATC' then 3 -- Classification
		when 'DA_France' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end	
		when 'AMIS' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end		            	
        when 'NFC' then 4
		when 'AMT' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end	
		when 'LPD_Australia' then -- specialized hierarchy
            case when c.domain_id = 'Drug' then 0
            else case when c.standard_concept = 'S' then 1 else 0 end 
            end	                    
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
    WHERE (EXISTS (SELECT 1 -- where there is at least one standard concept in the same vocabulary
                        FROM devv5.concept c_int
                       WHERE     c_int.vocabulary_id = c.vocabulary_id
                             AND standard_concept in ('C', 'S')
                  )  
    OR c.concept_code in ('OMOP generated','No matching concept'))
    and c.vocabulary_id not in ('SNOMED','ICD9Proc','CPT4','LOINC','NDFRT','ETC','ATC','SMQ','VA Class','Race')        
)
]';    

execute immediate 'DROP TABLE t_concept_class_conversion PURGE';

execute immediate 'CREATE INDEX concept_code ON concept (concept_code, vocabulary_id) NOLOGGING';

execute immediate 'CREATE UNIQUE INDEX XPKconcept ON concept (concept_id) NOLOGGING';

execute immediate q'[
ALTER TABLE concept ADD (
  CHECK ( invalid_reason IN ('D', 'U'))
  ENABLE VALIDATE,
  CONSTRAINT XPKCONCEPT
  PRIMARY KEY
  (concept_id)
  USING INDEX XPKCONCEPT
  ENABLE VALIDATE)
  ]';      

--add table concept_relationship
execute immediate '
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
)
';


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

execute immediate '
CREATE UNIQUE INDEX xpkconcept_relationship ON concept_relationship
(concept_id_1, concept_id_2, relationship_id) NOLOGGING
'; 

execute immediate q'[
ALTER TABLE concept_relationship ADD (
  CHECK ( invalid_reason IN ('D', 'U'))
  ENABLE VALIDATE,
  CONSTRAINT xpkconcept_relationship
  PRIMARY KEY
  (concept_id_1, concept_id_2, relationship_id)
  USING INDEX xpkconcept_relationship
  ENABLE VALIDATE)
  ]';

execute immediate ' 
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
  ENABLE VALIDATE)
';


--add table concept_ancestor
execute immediate '
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
)
';

execute immediate '
CREATE UNIQUE INDEX xpkconcept_ancestor ON concept_ancestor
(ancestor_concept_id, descendant_concept_id) NOLOGGING
';

execute immediate '
ALTER TABLE concept_ancestor ADD (
  CONSTRAINT xpkconcept_ancestor
  PRIMARY KEY
  (ancestor_concept_id, descendant_concept_id)
  USING INDEX xpkconcept_ancestor
  ENABLE VALIDATE)
  ';

execute immediate '
ALTER TABLE concept_ancestor ADD (
  CONSTRAINT concept_ancestor_FK 
  FOREIGN KEY (ancestor_concept_id) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE,
  CONSTRAINT concept_descendant_FK 
  FOREIGN KEY (descendant_concept_id) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE)
';

--add table concept_synonym
execute immediate '
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
)
';     

execute immediate '
CREATE UNIQUE INDEX xpkconcept_synonym ON concept_synonym
(concept_synonym_id) NOLOGGING
';

execute immediate '
ALTER TABLE concept_synonym ADD (
  CONSTRAINT xpkconcept_synonym
  PRIMARY KEY
  (concept_synonym_id)
  USING INDEX xpkconcept_synonym
  ENABLE VALIDATE)
';

execute immediate '
ALTER TABLE concept_synonym ADD (
  CONSTRAINT concept_synonym_concept_FK 
  FOREIGN KEY (concept_id) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE)
';

--concepts with direct mappings
execute immediate q'[
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
)
]';

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
                   case when c1.invalid_reason='U' then 'D' else c1.invalid_reason end
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

execute immediate '
CREATE INDEX SOURCE_TO_concept_SOURCE_idX ON source_to_concept_map
(SOURCE_CODE) NOLOGGING
';

execute immediate '
CREATE UNIQUE INDEX xpksource_to_concept_map ON source_to_concept_map
(SOURCE_vocabulary_id, TARGET_concept_id, SOURCE_CODE, valid_end_date) NOLOGGING
';

execute immediate q'[
ALTER TABLE source_to_concept_map ADD (
  CHECK (primary_map in ('Y'))
  ENABLE VALIDATE,
  CHECK (invalid_reason in ('D', 'U'))
  ENABLE VALIDATE,
  CONSTRAINT xpksource_to_concept_map
  PRIMARY KEY
  (SOURCE_vocabulary_id, TARGET_concept_id, SOURCE_CODE, valid_end_date)
  USING INDEX xpksource_to_concept_map
  ENABLE VALIDATE)
]';

execute immediate '
ALTER TABLE source_to_concept_map ADD (
  CONSTRAINT SOURCE_TO_concept_concept 
  FOREIGN KEY (TARGET_concept_id) 
  REFERENCES concept (concept_id)
  ENABLE VALIDATE)
';

          
INSERT /*+ APPEND */
      INTO  drug_strength
   SELECT s.drug_concept_id,
          s.ingredient_concept_id,
          s.amount_value,
          au.concept_code AS amount_unit,
          s.numerator_value AS concentration_value,
          nu.concept_code AS concentration_enum_unit,
          du.concept_code AS concentration_denom_unit,
          s.box_size,
          s.valid_start_date,
          s.valid_end_date,
          s.invalid_reason
     FROM devv5.drug_strength s
          JOIN concept au ON au.concept_id = s.amount_unit_concept_id
          LEFT JOIN concept nu ON nu.concept_id = s.numerator_unit_concept_id
          LEFT JOIN concept du ON du.concept_id = s.denominator_unit_concept_id;

COMMIT;

INSERT /*+ APPEND */
      INTO  pack_content
   SELECT s.pack_concept_id,
          s.drug_concept_id,
          s.amount,
          s.box_size
     FROM devv5.pack_content s
          JOIN concept au ON au.concept_id = s.pack_concept_id
          JOIN concept nu ON nu.concept_id = s.drug_concept_id;
COMMIT;

INSERT INTO VOCABULARY
   SELECT vocabulary_id_v4, vocabulary_id_v5 FROM devv5.vocabulary_conversion;
COMMIT;
end;
/
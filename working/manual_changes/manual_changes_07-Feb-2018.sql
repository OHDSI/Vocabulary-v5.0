--add new UCUM: Vector-genome
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32018, 'Vector-genome', 'Unit', 'UCUM', 'Unit', 'S', '{vector-genome}', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
commit;

--Add new relationship_ids (batch-version) for updated SNOMED
/*
Has basic dose form	Has basic dose form (SNOMED)	0	0	Basic dose form of	Basic dose form of (SNOMED)	0	0
Has disposition	Has disposition (SNOMED)	0	0	Disposition of	Disposition of (SNOMED)	0	0
Has admin method	Has dose form administration method (SNOMED)	0	0	Admin method of	Dose form administration method of (SNOMED)	0	0
Has intended site	Has dose form intended site (SNOMED)	0	0	Intended site of	Dose form intended site of (SNOMED)	0	0
Has release charact	Has dose form release characteristic (SNOMED)	0	0	Release charact of	Dose form release characteristic of (SNOMED)	0	0
Has transformation	Has dose form transformation (SNOMED)	0	0	Transformation of	Dose form transformation of (SNOMED)	0	0
Has state of matter	Has state of matter (SNOMED)	0	0	State of matter of	State of matter of (SNOMED)	0	0
Temp related to	Temporally related to (SNOMED)	0	0	Has temp finding	Has temporal finding (SNOMED)	0	0

*/
/*
CREATE TABLE new_relationships
(
    RELATIONSHIP_ID              VARCHAR2 (20) NOT NULL,
    RELATIONSHIP_NAME            VARCHAR2 (255) NOT NULL,
    IS_HIERARCHICAL              VARCHAR2 (1) NOT NULL,
    DEFINES_ANCESTRY             VARCHAR2 (1) NOT NULL,
    REVERSE_RELATIONSHIP_ID      VARCHAR2 (20) NOT NULL,
    REVERSE_RELATIONSHIP_NAME    VARCHAR2 (255) NOT NULL,
    REVERSE_IS_HIERARCHICAL      VARCHAR2 (1) NOT NULL,
    REVERSE_DEFINES_ANCESTRY     VARCHAR2 (1) NOT NULL
);
*/
DECLARE
    z    number;
    ex   number;
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 571191 AND concept_id < 581479;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'ALTER TABLE relationship DISABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    
    FOR rels in (SELECT * FROM dev_snomed.new_relationships) LOOP
        --direct
        EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
        INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
          VALUES (z, rels.relationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
        INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
          VALUES (rels.relationship_id, rels.relationship_name, rels.is_hierarchical, rels.defines_ancestry, rels.reverse_relationship_id, z);

        --reverse
        EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;
        INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
          VALUES (z, rels.reverse_relationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
        INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
          VALUES (rels.reverse_relationship_id, rels.reverse_relationship_name, rels.reverse_is_hierarchical, rels.reverse_defines_ancestry, rels.relationship_id, z);

    END LOOP;
    
    EXECUTE IMMEDIATE 'ALTER TABLE relationship ENABLE CONSTRAINT FPK_RELATIONSHIP_REVERSE';
    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    /*DROP TABLE new_relationships;*/
END;

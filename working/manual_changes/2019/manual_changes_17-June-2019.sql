--add new vocabulary='NAACCR'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'NAACCR',
	pVocabulary_name		=> 'NAACCR Data Dictionary',
	pVocabulary_reference	=> 'http://datadictionary.naaccr.org/?c=10',
	pVocabulary_version		=> 'NAACCR v18',
	pOMOP_req				=> NULL, --NULL or 'Y'
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--new relationships for NAACCR
DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Procedure Schema to ICDO Condition (NAACCR)';
    pRelationship_id constant varchar(100):='Proc Schema to ICDO';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='ICDO to Proc Schema';
    
    pRelationship_name_rev constant varchar(100):='ICDO Condition to Procedure Schema (NAACCR)';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    ALTER TABLE relationship DROP CONSTRAINT FPK_RELATIONSHIP_REVERSE;
    
    --direct
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Schema to ICDO Condition (NAACCR)';
    pRelationship_id constant varchar(100):='Schema to ICDO';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='ICDO to Schema';
    
    pRelationship_name_rev constant varchar(100):='ICDO Condition to Schema (NAACCR)';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    ALTER TABLE relationship DROP CONSTRAINT FPK_RELATIONSHIP_REVERSE;
    
    --direct
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Schema to Value (NAACCR)';
    pRelationship_id constant varchar(100):='Schema to Value';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='Value to Schema';
    
    pRelationship_name_rev constant varchar(100):='Value to Schema (NAACCR)';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    ALTER TABLE relationship DROP CONSTRAINT FPK_RELATIONSHIP_REVERSE;
    
    --direct
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Schema to Variable (NAACCR)';
    pRelationship_id constant varchar(100):='Schema to Variable';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='Variable to Schema';
    
    pRelationship_name_rev constant varchar(100):='Variable to Schema (NAACCR)';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    ALTER TABLE relationship DROP CONSTRAINT FPK_RELATIONSHIP_REVERSE;
    
    --direct
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pRelationship_id, pRelationship_name, pIs_hierarchical, pDefines_ancestry, pReverse_relationship_id, z);

    --reverse
    SELECT nextval('v5_concept') INTO z;
    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pRelationship_name_rev, 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
      VALUES (pReverse_relationship_id, pRelationship_name_rev, pIs_hierarchical_rev, pDefines_ancestry_rev, pRelationship_id, z);

    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
    DROP SEQUENCE v5_concept;
END $$;

--new classes for NAACCR
DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='NAACCR Proc Schema';
    pConcept_class_name constant varchar(100):= 'NAACCR Procedure Schema';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='NAACCR Procedure';
    pConcept_class_name constant varchar(100):= 'NAACCR Procedure';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='NAACCR Value';
    pConcept_class_name constant varchar(100):= 'NAACCR Value';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='NAACCR Schema';
    pConcept_class_name constant varchar(100):= 'NAACCR Schema';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;

DO $$
DECLARE
    z    int;
    ex   int;
    pConcept_class_id constant varchar(100):='NAACCR Variable';
    pConcept_class_name constant varchar(100):= 'NAACCR Variable';
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 31967 AND concept_id < 72245;
    
    EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';
    SELECT nextval('v5_concept') INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pConcept_class_name, 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
      VALUES (pConcept_class_id, pConcept_class_name, z);

    DROP SEQUENCE v5_concept;
END $$;
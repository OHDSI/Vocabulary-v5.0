SELECT devv5.FastRecreateSchema ();
-- Some inserts to make code below viable

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CAP',
	pVocabulary_name		=> 'College of American Pathologists',
	pVocabulary_reference	=> 'https://fileshare.cap.org/human.aspx?Arg12=filelist&Arg06=136884410',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> 'Y',
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> 'mailto:contact@ohdsi.org?subject=License%20required%20for%20CAP&body=Describe%20your%20situation%20and%20your%20need%20for%20this%20vocabulary.',
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;


--new class for cap
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAP Value',
	pConcept_class_name	=>'CAP Value'
);
END $_$;

--new class for cap
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAP Variable',
	pConcept_class_name	=>'CAP Variable'
);
END $_$;

--new class for cap
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAP Header',
	pConcept_class_name	=>'CAP Header'
);
END $_$;

--new class for cap
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'CAP Protocol',
	pConcept_class_name	=>'CAP Protocol'
);
END $_$;

--new relationship for cap
DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='CAP value of';
    pRelationship_id constant varchar(100):='CAP value of';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='Has CAP value';

    pRelationship_name_rev constant varchar(100):='Has CAP value';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept WHERE concept_id >= 31967 AND concept_id < 72245;

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

SELECT * FROM relationship;
DO $$
DECLARE
    z    int;
    ex   int;
    pRelationship_name constant varchar(100):='Has CAP parent item';
    pRelationship_id constant varchar(100):='Has CAP parent item';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='CAP parent item of';

    pRelationship_name_rev constant varchar(100):='CAP parent item of';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept WHERE concept_id >= 31967 AND concept_id < 72245;

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
    pRelationship_name constant varchar(100):='Has protocol';
    pRelationship_id constant varchar(100):='Has protocol';
    pIs_hierarchical constant int:=0;
    pDefines_ancestry constant int:=0;
    pReverse_relationship_id constant varchar(100):='Protocol of';

    pRelationship_name_rev constant varchar(100):='Protocol of';
    pIs_hierarchical_rev constant int:=0;
    pDefines_ancestry_rev constant int:=0;
BEGIN
    DROP SEQUENCE IF EXISTS v5_concept;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept WHERE concept_id >= 31967 AND concept_id < 72245;

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


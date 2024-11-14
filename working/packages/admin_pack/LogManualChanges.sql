CREATE OR REPLACE FUNCTION admin_pack.LogManualChanges ()
RETURNS VOID AS
$BODY$
    /*
    Log manual changes
    
    All changes in manual tables are stored in admin_pack schema, with an indication of who created the record and who changed it
    Then this information after the run in devv5 will fall into the "basic" manual tables
    
    Must run at the start of generic_update
    */
DECLARE
    iUserID INT4;
    ALL_PRIVILEGES RECORD;
    iRet INT8;
    iTargetSchemaName TEXT;
    iSpecificVocabularyID TEXT;
    iWrongVocabularyAffected TEXT;
BEGIN
    --delete obsolete (no longer existing in manual table) records and all records, that currently do not differ from the master table (for example, the relationship was deprecated in the manual table and then restored again)
    IF SESSION_USER <> 'devv5' 
    THEN
        EXECUTE FORMAT ($$
            DELETE
            FROM concept_relationship_manual logged_crm
            WHERE (
                NOT EXISTS (
                    SELECT 1
                    FROM %1$I.concept_relationship_manual local_crm
                    WHERE local_crm.concept_code_1 = logged_crm.concept_code_1
                      AND local_crm.concept_code_2 = logged_crm.concept_code_2
                      AND local_crm.vocabulary_id_1 = logged_crm.vocabulary_id_1
                      AND local_crm.vocabulary_id_2 = logged_crm.vocabulary_id_2
                      AND local_crm.relationship_id = logged_crm.relationship_id
                )
                OR EXISTS (
                    SELECT 1
                    FROM devv5.base_concept_relationship_manual base_crm
                    WHERE logged_crm.concept_code_1 = base_crm.concept_code_1
                      AND logged_crm.concept_code_2 = base_crm.concept_code_2
                      AND logged_crm.vocabulary_id_1 = base_crm.vocabulary_id_1
                      AND logged_crm.vocabulary_id_2 = base_crm.vocabulary_id_2
                      AND logged_crm.relationship_id = base_crm.relationship_id
                      AND ROW(logged_crm.valid_start_date, logged_crm.valid_end_date, logged_crm.invalid_reason) 
                          IS NOT DISTINCT FROM
                          ROW(base_crm.valid_start_date, base_crm.valid_end_date, base_crm.invalid_reason)
                )
            )
            AND logged_crm.dev_schema_name = %1$L;

            DELETE
            FROM concept_manual logged_cm
            WHERE (
                NOT EXISTS (
                    SELECT 1
                    FROM %1$I.concept_manual local_cm
                    WHERE local_cm.concept_code = logged_cm.concept_code
                      AND local_cm.vocabulary_id = logged_cm.vocabulary_id
                )
                OR EXISTS (
                    SELECT 1
                    FROM devv5.base_concept_manual base_cm
                    WHERE logged_cm.concept_code = base_cm.concept_code
                      AND logged_cm.vocabulary_id = base_cm.vocabulary_id
                      AND ROW(logged_cm.concept_name, logged_cm.domain_id, logged_cm.concept_class_id, logged_cm.standard_concept, logged_cm.valid_start_date, logged_cm.valid_end_date, logged_cm.invalid_reason)
                          IS NOT DISTINCT FROM
                          ROW(base_cm.concept_name, base_cm.domain_id, base_cm.concept_class_id, base_cm.standard_concept, base_cm.valid_start_date, base_cm.valid_end_date, base_cm.invalid_reason)
                )
            )
            AND logged_cm.dev_schema_name = %1$L;

            DELETE
            FROM concept_synonym_manual logged_csm
            WHERE (
                NOT EXISTS (
                    SELECT 1
                    FROM %1$I.concept_synonym_manual local_csm
                    WHERE local_csm.synonym_name = logged_csm.synonym_name
                      AND local_csm.synonym_concept_code = logged_csm.synonym_concept_code
                      AND local_csm.synonym_vocabulary_id = logged_csm.synonym_vocabulary_id
                      AND local_csm.language_concept_id = logged_csm.language_concept_id
                )
                OR EXISTS (
                    SELECT 1
                    FROM devv5.base_concept_synonym_manual base_csm
                    WHERE logged_csm.synonym_name = base_csm.synonym_name
                      AND logged_csm.synonym_concept_code = base_csm.synonym_concept_code
                      AND logged_csm.synonym_vocabulary_id = base_csm.synonym_vocabulary_id
                      AND logged_csm.language_concept_id = base_csm.language_concept_id
                )
            )
            AND logged_csm.dev_schema_name = %1$L
        $$, SESSION_USER);
    END IF;

    --quick check the fact of manual changes (relationships, concepts and synonyms), if there are none, then there is no point in requesting virtual authorization
    --manual relationships
    EXECUTE FORMAT ($$
        SELECT * 
        FROM (
            -- manual relationships
            SELECT 1 
            FROM %1$I.concept_relationship_manual local_crm
            LEFT JOIN devv5.base_concept_relationship_manual base_crm 
            USING (
                concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id
            )
            WHERE ROW(local_crm.valid_start_date, local_crm.valid_end_date, local_crm.invalid_reason)
                  IS DISTINCT FROM
                  ROW(base_crm.valid_start_date, base_crm.valid_end_date, base_crm.invalid_reason)
            
            UNION ALL
            
            -- manual concepts
            SELECT 1 
            FROM %1$I.concept_manual local_cm
            LEFT JOIN devv5.base_concept_manual base_cm 
            USING (concept_code, vocabulary_id)
            WHERE ROW(local_cm.concept_name, local_cm.domain_id, local_cm.concept_class_id, local_cm.standard_concept, local_cm.valid_start_date, local_cm.valid_end_date, local_cm.invalid_reason)
                  IS DISTINCT FROM
                  ROW(base_cm.concept_name, base_cm.domain_id, base_cm.concept_class_id, base_cm.standard_concept, base_cm.valid_start_date, base_cm.valid_end_date, base_cm.invalid_reason)
            
            UNION ALL
            
            -- manual synonyms
            SELECT 1 
            FROM %1$I.concept_synonym_manual local_csm
            LEFT JOIN devv5.base_concept_synonym_manual base_csm 
            USING (
                synonym_name,
                synonym_concept_code,
                synonym_vocabulary_id,
                language_concept_id
            )
            WHERE base_csm.synonym_concept_code IS NULL
        ) s0
        LIMIT 1
    $$, SESSION_USER);

    GET DIAGNOSTICS iRet = ROW_COUNT;

    IF iRet = 0 
    THEN
        --exit when no changes found
        RETURN;
    END IF;

    IF SESSION_USER <> 'devv5' 
    THEN
        --if we're under dev-schema
        --start session
        iUserID := GetUserID();
        
        --check privileges
        ALL_PRIVILEGES := GetAllPrivileges();
        
        IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_ANY_VOCABULARY) 
           AND CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_SPECIFIC_VOCABULARY) 
        THEN
            EXECUTE FORMAT ($$
                SELECT 
                    CASE 
                        WHEN CheckUserSpecificVocabulary(local_crm.vocabulary_id_1)
                        THEN local_crm.vocabulary_id_2
                        ELSE local_crm.vocabulary_id_1
                    END
                  FROM 
                      %1$I.concept_relationship_manual local_crm
                  LEFT JOIN 
                      devv5.base_concept_relationship_manual base_crm 
                  USING (
                      concept_code_1,
                      concept_code_2,
                      vocabulary_id_1,
                      vocabulary_id_2,
                      relationship_id
                  )
                WHERE 
                    NOT CheckUserSpecificVocabulary(local_crm.vocabulary_id_1)
                    AND NOT CheckUserSpecificVocabulary(local_crm.vocabulary_id_2)
                    AND ROW(local_crm.valid_start_date, local_crm.valid_end_date, local_crm.invalid_reason)
                        IS DISTINCT FROM
                        ROW(base_crm.valid_start_date, base_crm.valid_end_date, base_crm.invalid_reason)
                LIMIT 1
            $$, SESSION_USER)
            INTO iSpecificVocabularyID;
            
            GET DIAGNOSTICS iRet = ROW_COUNT;
            IF iRet>0 THEN
                RAISE EXCEPTION 'You do not have privileges to work with vocabulary: %',iSpecificVocabularyID;
            END IF;
        ELSEIF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_ANY_VOCABULARY) AND NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_SPECIFIC_VOCABULARY) THEN
            RAISE EXCEPTION 'You do not have privileges to work with manual relationships';
        END IF;
        
        --check for updated vocabularies, they must be affected by SetLatestUpdate
        EXECUTE FORMAT ($$
            SELECT * 
            FROM (
                -- manual relationships
                SELECT 
                    'You have an updated/new manual relationship with vocabularies that were not affected by SetLatestUpdate: ' || 
                    local_crm.vocabulary_id_1 || ' ' || 
                    local_crm.relationship_id || ' ' || 
                    local_crm.vocabulary_id_2 AS message
                FROM 
                    %1$I.concept_relationship_manual local_crm
                JOIN 
                    %1$I.vocabulary v1 ON v1.vocabulary_id = local_crm.vocabulary_id_1
                JOIN 
                    %1$I.vocabulary v2 ON v2.vocabulary_id = local_crm.vocabulary_id_2
                LEFT JOIN 
                    devv5.base_concept_relationship_manual base_crm USING (
                        concept_code_1,
                        concept_code_2,
                        vocabulary_id_1,
                        vocabulary_id_2,
                        relationship_id
                    )
                WHERE 
                    COALESCE(v1.latest_update, v2.latest_update) IS NULL
                    AND ROW(local_crm.valid_start_date, local_crm.valid_end_date, local_crm.invalid_reason)
                        IS DISTINCT FROM
                        ROW(base_crm.valid_start_date, base_crm.valid_end_date, base_crm.invalid_reason)
                
                UNION ALL
                
                -- manual concepts
                SELECT 
                    'You have an updated/new manual concept with a vocabulary that was not affected by SetLatestUpdate: ' || 
                    local_cm.vocabulary_id AS message
                FROM 
                    %1$I.concept_manual local_cm
                JOIN 
                    %1$I.vocabulary v USING (vocabulary_id)
                LEFT JOIN 
                    devv5.base_concept_manual base_cm USING (
                        concept_code,
                        vocabulary_id
                    )
                WHERE 
                    v.latest_update IS NULL
                    AND ROW(local_cm.concept_name, local_cm.domain_id, local_cm.concept_class_id, local_cm.standard_concept, local_cm.valid_start_date, local_cm.valid_end_date, local_cm.invalid_reason)
                        IS DISTINCT FROM
                        ROW(base_cm.concept_name, base_cm.domain_id, base_cm.concept_class_id, base_cm.standard_concept, base_cm.valid_start_date, base_cm.valid_end_date, base_cm.invalid_reason)
                
                UNION ALL
                
                -- manual synonyms
                SELECT 
                    'You have an updated/new manual synonym with a vocabulary that was not affected by SetLatestUpdate: ' || 
                    local_csm.synonym_vocabulary_id AS message
                FROM 
                    %1$I.concept_synonym_manual local_csm
                JOIN 
                    %1$I.vocabulary v ON v.vocabulary_id = local_csm.synonym_vocabulary_id
                LEFT JOIN 
                    devv5.base_concept_synonym_manual base_csm USING (
                        synonym_name,
                        synonym_concept_code,
                        synonym_vocabulary_id,
                        language_concept_id
                    )
                WHERE 
                    v.latest_update IS NULL
                    AND base_csm.synonym_concept_code IS NULL
            ) s0
            LIMIT 1
        $$, SESSION_USER)
        INTO iWrongVocabularyAffected;

        GET DIAGNOSTICS iRet = ROW_COUNT;

        IF iRet>0 THEN
            RAISE EXCEPTION '%',iWrongVocabularyAffected;
        END IF;

        --working with manual relationships
        --insert new records, update existing
        EXECUTE FORMAT ($$
            INSERT INTO concept_relationship_manual AS logged_crm
            SELECT 
                local_crm.*,
                CLOCK_TIMESTAMP(),
                %2$L,
                NULL,
                NULL,
                %1$L
            FROM 
                %1$I.concept_relationship_manual local_crm
            LEFT JOIN 
                devv5.base_concept_relationship_manual base_crm 
            USING (
                concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id
            )
            WHERE 
                ROW(local_crm.valid_start_date, local_crm.valid_end_date, local_crm.invalid_reason)
                IS DISTINCT FROM
                ROW(base_crm.valid_start_date, base_crm.valid_end_date, base_crm.invalid_reason)
            ON CONFLICT ON CONSTRAINT idx_pk_crm
            DO UPDATE
            SET 
                valid_start_date = excluded.valid_start_date,
                valid_end_date = excluded.valid_end_date,
                invalid_reason = excluded.invalid_reason,
                modified = CLOCK_TIMESTAMP(),
                modified_by = %2$L
            WHERE 
                ROW(logged_crm.valid_start_date, logged_crm.valid_end_date, logged_crm.invalid_reason)
                IS DISTINCT FROM
                ROW(excluded.valid_start_date, excluded.valid_end_date, excluded.invalid_reason)
        $$, SESSION_USER, iUserID);

        --working with manual concepts
        IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_ANY_VOCABULARY) AND CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_SPECIFIC_VOCABULARY) THEN
            EXECUTE FORMAT ($$
                SELECT 
                    local_cm.vocabulary_id
                FROM 
                    %1$I.concept_manual local_cm
                LEFT JOIN 
                    devv5.base_concept_manual base_cm 
                USING (
                    concept_code,
                    vocabulary_id
                )
                WHERE 
                    NOT CheckUserSpecificVocabulary(local_cm.vocabulary_id)
                    AND ROW(
                        local_cm.concept_name, 
                        local_cm.domain_id, 
                        local_cm.concept_class_id, 
                        local_cm.standard_concept, 
                        local_cm.valid_start_date, 
                        local_cm.valid_end_date, 
                        local_cm.invalid_reason
                    ) IS DISTINCT FROM
                    ROW(
                        base_cm.concept_name, 
                        base_cm.domain_id, 
                        base_cm.concept_class_id, 
                        base_cm.standard_concept, 
                        base_cm.valid_start_date, 
                        base_cm.valid_end_date, 
                        base_cm.invalid_reason
                    )
                LIMIT 1
            $$, SESSION_USER)
            INTO iSpecificVocabularyID;
            
            GET DIAGNOSTICS iRet = ROW_COUNT;
            
            IF iRet > 0 
            THEN
                RAISE EXCEPTION 'You do not have privileges to work with vocabulary: %',iSpecificVocabularyID;
            END IF;
            
        ELSEIF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_ANY_VOCABULARY) 
               AND NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_SPECIFIC_VOCABULARY) 
        THEN
            RAISE EXCEPTION 'You do not have privileges to work with manual concepts';
        END IF;

        --insert new records, update existing
        EXECUTE FORMAT ($$
            INSERT INTO concept_manual AS logged_cm
            SELECT 
                local_cm.*,
                CLOCK_TIMESTAMP(),
                %2$L,
                NULL,
                NULL,
                %1$L
            FROM 
                %1$I.concept_manual local_cm
            LEFT JOIN 
                devv5.base_concept_manual base_cm 
            USING (
                concept_code,
                vocabulary_id
            )
            WHERE 
                ROW(
                    local_cm.concept_name, 
                    local_cm.domain_id, 
                    local_cm.concept_class_id, 
                    local_cm.standard_concept, 
                    local_cm.valid_start_date, 
                    local_cm.valid_end_date, 
                    local_cm.invalid_reason
                ) IS DISTINCT FROM
                ROW(
                    base_cm.concept_name, 
                    base_cm.domain_id, 
                    base_cm.concept_class_id, 
                    base_cm.standard_concept, 
                    base_cm.valid_start_date, 
                    base_cm.valid_end_date, 
                    base_cm.invalid_reason
                )
            ON CONFLICT ON CONSTRAINT idx_pk_cm
            DO UPDATE
            SET 
                concept_name = excluded.concept_name,
                domain_id = excluded.domain_id,
                concept_class_id = excluded.concept_class_id,
                standard_concept = excluded.standard_concept,
                valid_start_date = excluded.valid_start_date,
                valid_end_date = excluded.valid_end_date,
                invalid_reason = excluded.invalid_reason,
                modified = CLOCK_TIMESTAMP(),
                modified_by = %2$L
            WHERE 
                ROW(
                    logged_cm.concept_name, 
                    logged_cm.domain_id, 
                    logged_cm.concept_class_id, 
                    logged_cm.standard_concept, 
                    logged_cm.valid_start_date, 
                    logged_cm.valid_end_date, 
                    logged_cm.invalid_reason
                ) IS DISTINCT FROM
                ROW(
                    excluded.concept_name, 
                    excluded.domain_id, 
                    excluded.concept_class_id, 
                    excluded.standard_concept, 
                    excluded.valid_start_date, 
                    excluded.valid_end_date, 
                    excluded.invalid_reason
                )
        $$, SESSION_USER, iUserID);

        --working with manual synonyms
        IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_ANY_VOCABULARY) 
           AND CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_SPECIFIC_VOCABULARY) 
        THEN
            EXECUTE FORMAT ($$
                SELECT 
                    local_csm.synonym_vocabulary_id
                FROM 
                    %1$I.concept_synonym_manual local_csm
                LEFT JOIN 
                    devv5.base_concept_synonym_manual base_csm 
                USING (
                    synonym_name,
                    synonym_concept_code,
                    synonym_vocabulary_id,
                    language_concept_id
                )
                WHERE 
                    NOT CheckUserSpecificVocabulary(local_csm.synonym_vocabulary_id)
                    AND base_csm.synonym_concept_code IS NULL
                LIMIT 1
            $$, SESSION_USER)
            INTO iSpecificVocabularyID;
            
            GET DIAGNOSTICS iRet = ROW_COUNT;
            
            IF iRet > 0 
            THEN
                RAISE EXCEPTION 'You do not have privileges to work with vocabulary: %', iSpecificVocabularyID;
            END IF;
            
        ELSEIF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_ANY_VOCABULARY) 
               AND NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_SPECIFIC_VOCABULARY) 
        THEN
            RAISE EXCEPTION 'You do not have privileges to work with manual synonyms';
        END IF;

        --insert new records
        --NOTE: no update here because synonyms don't have that option
        EXECUTE FORMAT ($$
            INSERT INTO concept_synonym_manual AS logged_csm
            SELECT 
                local_csm.*,
                CLOCK_TIMESTAMP(),
                %2$L,
                NULL,
                NULL,
                %1$L
            FROM 
                %1$I.concept_synonym_manual local_csm
            LEFT JOIN 
                devv5.base_concept_synonym_manual base_csm 
            USING (
                synonym_name,
                synonym_concept_code,
                synonym_vocabulary_id,
                language_concept_id
            )
            WHERE 
                base_csm.synonym_concept_code IS NULL
            ON CONFLICT 
                DO NOTHING
        $$, SESSION_USER, iUserID);

        ANALYZE concept_relationship_manual,
            concept_manual,
            concept_synonym_manual;
    ELSE
        --if we're under devv5
        SELECT LOWER(v.dev_schema_name)
          INTO iTargetSchemaName
          FROM devv5.vocabulary v
         WHERE v.latest_update IS NOT NULL
        LIMIT 1;

        --working with manual relationships
        --check that all new/updated relationships are in the log table
        --if not - raise an error
        PERFORM 
        FROM 
            devv5.concept_relationship_manual local_crm
        LEFT JOIN 
            devv5.base_concept_relationship_manual base_crm 
        USING (
            concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id
        )
        WHERE 
            ROW(local_crm.valid_start_date, local_crm.valid_end_date, local_crm.invalid_reason)
                IS DISTINCT FROM
                ROW(base_crm.valid_start_date, base_crm.valid_end_date, base_crm.invalid_reason)
            AND NOT EXISTS (
                SELECT 1
                FROM concept_relationship_manual logged_crm
                WHERE 
                    logged_crm.concept_code_1 = local_crm.concept_code_1
                    AND logged_crm.concept_code_2 = local_crm.concept_code_2
                    AND logged_crm.vocabulary_id_1 = local_crm.vocabulary_id_1
                    AND logged_crm.vocabulary_id_2 = local_crm.vocabulary_id_2
                    AND logged_crm.relationship_id = local_crm.relationship_id
                    AND logged_crm.valid_start_date = local_crm.valid_start_date
                    AND logged_crm.valid_end_date = local_crm.valid_end_date
                    AND logged_crm.invalid_reason IS NOT DISTINCT FROM local_crm.invalid_reason
                    AND logged_crm.dev_schema_name = iTargetSchemaName
            )
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION 'There are unlogged manual relationships, please run the generic_update in dev-schema %', iTargetSchemaName;
        END IF;

        --insert new records, update existing
        INSERT INTO devv5.base_concept_relationship_manual AS base_crm
        SELECT 
            logged_crm.concept_code_1,
            logged_crm.concept_code_2,
            logged_crm.vocabulary_id_1,
            logged_crm.vocabulary_id_2,
            logged_crm.relationship_id,
            logged_crm.valid_start_date,
            logged_crm.valid_end_date,
            logged_crm.invalid_reason,
            0,
            0,
            logged_crm.created,
            logged_crm.created_by,
            logged_crm.modified,
            logged_crm.modified_by
        FROM 
            concept_relationship_manual logged_crm
        WHERE 
            logged_crm.dev_schema_name = iTargetSchemaName
            AND EXISTS (
                SELECT 1
                FROM devv5.concept_relationship_manual local_crm
                WHERE 
                    local_crm.concept_code_1 = logged_crm.concept_code_1
                    AND local_crm.concept_code_2 = logged_crm.concept_code_2
                    AND local_crm.vocabulary_id_1 = logged_crm.vocabulary_id_1
                    AND local_crm.vocabulary_id_2 = logged_crm.vocabulary_id_2
                    AND local_crm.relationship_id = logged_crm.relationship_id
            )
        ON CONFLICT ON CONSTRAINT idx_pk_base_crm
        DO UPDATE
        SET 
            valid_start_date = excluded.valid_start_date,
            valid_end_date = excluded.valid_end_date,
            invalid_reason = excluded.invalid_reason,
            modified = COALESCE(excluded.modified, excluded.created),
            modified_by = COALESCE(excluded.modified_by, excluded.created_by)
        WHERE 
            ROW(base_crm.valid_start_date, base_crm.valid_end_date, base_crm.invalid_reason)
            IS DISTINCT FROM
            ROW(excluded.valid_start_date, excluded.valid_end_date, excluded.invalid_reason);

        --working with manual concepts
        --check that all new/updated concepts are in the log table
        --if not - raise an error
        PERFORM 
        FROM 
            devv5.concept_manual local_cm
        LEFT JOIN 
            devv5.base_concept_manual base_cm 
        USING (
            concept_code,
            vocabulary_id
        )
        WHERE 
            ROW(local_cm.concept_name, local_cm.domain_id, local_cm.concept_class_id, local_cm.standard_concept, local_cm.valid_start_date, local_cm.valid_end_date, local_cm.invalid_reason)
            IS DISTINCT FROM
            ROW(base_cm.concept_name, base_cm.domain_id, base_cm.concept_class_id, base_cm.standard_concept, base_cm.valid_start_date, base_cm.valid_end_date, base_cm.invalid_reason)
            AND NOT EXISTS (
                SELECT 1
                FROM concept_manual logged_cm
                WHERE 
                    logged_cm.concept_code = local_cm.concept_code
                    AND logged_cm.vocabulary_id = local_cm.vocabulary_id
                    AND logged_cm.dev_schema_name = iTargetSchemaName
                    --according to the logic of the manual table of concepts - any of these fields can be null
                    AND ROW(logged_cm.concept_name, logged_cm.domain_id, logged_cm.concept_class_id, logged_cm.standard_concept, logged_cm.valid_start_date, logged_cm.valid_end_date, logged_cm.invalid_reason)
                    IS NOT DISTINCT FROM
                    ROW(local_cm.concept_name, local_cm.domain_id, local_cm.concept_class_id, local_cm.standard_concept, local_cm.valid_start_date, local_cm.valid_end_date, local_cm.invalid_reason)
            )
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION 'There are unlogged manual concepts, please run the generic_update in dev-schema %', iTargetSchemaName;
        END IF;

        --insert new records, update existing
        INSERT INTO devv5.base_concept_manual AS base_cm
        SELECT 
            logged_cm.concept_name,
            logged_cm.domain_id,
            logged_cm.vocabulary_id,
            logged_cm.concept_class_id,
            logged_cm.standard_concept,
            logged_cm.concept_code,
            logged_cm.valid_start_date,
            logged_cm.valid_end_date,
            logged_cm.invalid_reason,
            0,
            logged_cm.created,
            logged_cm.created_by,
            logged_cm.modified,
            logged_cm.modified_by
        FROM 
            concept_manual logged_cm
        WHERE 
            logged_cm.dev_schema_name = iTargetSchemaName
            AND EXISTS (
                SELECT 1
                FROM devv5.concept_manual local_cm
                WHERE 
                    local_cm.concept_code = logged_cm.concept_code
                    AND local_cm.vocabulary_id = logged_cm.vocabulary_id
            )
        ON CONFLICT ON CONSTRAINT idx_pk_base_cm
        DO UPDATE
        SET 
            concept_name = excluded.concept_name,
            domain_id = excluded.domain_id,
            concept_class_id = excluded.concept_class_id,
            standard_concept = excluded.standard_concept,
            valid_start_date = excluded.valid_start_date,
            valid_end_date = excluded.valid_end_date,
            invalid_reason = excluded.invalid_reason,
            modified = COALESCE(excluded.modified, excluded.created),
            modified_by = COALESCE(excluded.modified_by, excluded.created_by)
        WHERE 
            ROW(
                base_cm.concept_name, 
                base_cm.domain_id, 
                base_cm.concept_class_id, 
                base_cm.standard_concept, 
                base_cm.valid_start_date, 
                base_cm.valid_end_date, 
                base_cm.invalid_reason
            )
            IS DISTINCT FROM
            ROW(
                excluded.concept_name, 
                excluded.domain_id, 
                excluded.concept_class_id, 
                excluded.standard_concept, 
                excluded.valid_start_date, 
                excluded.valid_end_date, 
                excluded.invalid_reason
            );

        --working with manual synonyms
        --check that all new synonyms are in the log table
        --if not - raise an error
        PERFORM 
        FROM 
            devv5.concept_synonym_manual local_csm
        LEFT JOIN 
            devv5.base_concept_synonym_manual base_csm 
        USING (
            synonym_name,
            synonym_concept_code,
            synonym_vocabulary_id,
            language_concept_id
        )
        WHERE 
            base_csm.synonym_concept_code IS NULL
            AND NOT EXISTS (
                SELECT 1
                FROM concept_synonym_manual logged_csm
                WHERE 
                    logged_csm.synonym_name = local_csm.synonym_name
                    AND logged_csm.synonym_concept_code = local_csm.synonym_concept_code
                    AND logged_csm.synonym_vocabulary_id = local_csm.synonym_vocabulary_id
                    AND logged_csm.language_concept_id = local_csm.language_concept_id
                    AND logged_csm.dev_schema_name = iTargetSchemaName
            )
        LIMIT 1;

        IF FOUND 
        THEN
            RAISE EXCEPTION 'There are unlogged manual synonyms, please run the generic_update in dev-schema %', iTargetSchemaName;
        END IF;

        --insert new records
        --NOTE: no update here because synonyms don't have that option
        INSERT INTO devv5.base_concept_synonym_manual AS base_csm
        SELECT 
            logged_csm.synonym_name,
            logged_csm.synonym_concept_code,
            logged_csm.synonym_vocabulary_id,
            logged_csm.language_concept_id,
            0,
            logged_csm.created,
            logged_csm.created_by,
            NULL, --always NULL
            NULL  --always NULL
        FROM 
            concept_synonym_manual logged_csm
        WHERE 
            logged_csm.dev_schema_name = iTargetSchemaName
            AND EXISTS (
                --load only actual synonyms, because there could potentially be a situation when the synonym is in the log, but then (without the generic_update) it was removed in the dev-schema
                SELECT 1
                FROM devv5.concept_synonym_manual local_csm
                WHERE 
                    local_csm.synonym_name = logged_csm.synonym_name
                    AND local_csm.synonym_concept_code = logged_csm.synonym_concept_code
                    AND local_csm.synonym_vocabulary_id = logged_csm.synonym_vocabulary_id
                    AND local_csm.language_concept_id = logged_csm.language_concept_id
            )
        ON CONFLICT DO NOTHING;

        --delete obsolete
        DELETE
        FROM 
            devv5.base_concept_synonym_manual base_csm
        USING 
            devv5.vocabulary v
        WHERE 
            v.vocabulary_id = base_csm.synonym_vocabulary_id
            AND v.latest_update IS NOT NULL
            AND NOT EXISTS (
                -- missing synonyms
                SELECT 1
                FROM devv5.concept_synonym_manual local_csm
                WHERE 
                    local_csm.synonym_name = base_csm.synonym_name
                    AND local_csm.synonym_concept_code = base_csm.synonym_concept_code
                    AND local_csm.synonym_vocabulary_id = base_csm.synonym_vocabulary_id
                    AND local_csm.language_concept_id = base_csm.language_concept_id
            )
            AND EXISTS (
                -- only for actual concepts
                SELECT 1
                FROM devv5.concept_synonym_manual local_csm
                WHERE 
                    local_csm.synonym_concept_code = base_csm.synonym_concept_code
                    AND local_csm.synonym_vocabulary_id = base_csm.synonym_vocabulary_id
            );
    END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;
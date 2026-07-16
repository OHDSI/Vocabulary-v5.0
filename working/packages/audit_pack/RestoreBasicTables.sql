CREATE OR REPLACE FUNCTION audit.RestoreBasicTables(iLogID INT4)
RETURNS VOID AS
$BODY$
DECLARE
    r RECORD;
    pDevv5 BOOLEAN:=(CURRENT_SCHEMA='devv5');
    pCurrent_max_log_id INT4;
    pTruncate_id INT4;
    pCurrentPct INT2;
    pProcessedPct INT2:=0;
    pTables TEXT[]:=ARRAY['concept','concept_relationship','concept_synonym','drug_strength','pack_content','relationship','vocabulary','vocabulary_conversion','concept_class','domain', 'concept_metadata', 'concept_relationship_metadata'];
    pExcludeTables TEXT[]:=ARRAY['base_concept_manual', 'base_concept_relationship_manual', 'base_concept_synonym_manual'];
    t TEXT;
    pCreateDDLFK TEXT;
    pCreateDDLIdx TEXT;
BEGIN
    IF iLogID IS NULL THEN
        RAISE EXCEPTION 'Please specify the LogID';
    END IF;

    SELECT MAX(log_id), MAX(log_id) FILTER (WHERE tg_operation='T') INTO pCurrent_max_log_id, pTruncate_id FROM audit.logged_actions WHERE table_name <> ALL(pExcludeTables) AND log_id>=iLogID;
    
    IF pCurrent_max_log_id IS NULL THEN
        RAISE EXCEPTION 'Record with log_id=% not found in the LOG table',iLogID;
    END IF;

    IF pTruncate_id IS NOT NULL THEN
        RAISE EXCEPTION 'There was a TRUNCATE operation (log_id=%) after the specified LogID (%), can not restore. Please choose another LogID',pTruncate_id,iLogID;
    END IF;

    IF iLogID=pCurrent_max_log_id THEN
        RAISE EXCEPTION 'There is no data to restore, because the log_id you selected is the maximum for the log table';
    END IF;

    IF pDevv5 THEN
        --disable triggers to prevent log flooding
        FOREACH t IN ARRAY pTables LOOP
            EXECUTE FORMAT('ALTER TABLE %I DISABLE TRIGGER USER',t);
        END LOOP;

    ELSE
        --check current schema
        RAISE NOTICE 'Checking current schema...';
        PERFORM FROM (
            (
                SELECT 1
                FROM devv5.concept c1
                FULL JOIN concept c2 USING (concept_id)
                WHERE 
                    ROW(c1.concept_name, c1.domain_id, c1.vocabulary_id, c1.concept_class_id, c1.standard_concept, c1.concept_code, c1.valid_start_date, c1.valid_end_date, c1.invalid_reason)
                    IS DISTINCT FROM 
                    ROW(c2.concept_name, c2.domain_id, c2.vocabulary_id, c2.concept_class_id, c2.standard_concept, c2.concept_code, c2.valid_start_date, c2.valid_end_date, c2.invalid_reason)
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.concept_relationship cr1
                FULL JOIN concept_relationship cr2 USING (
                        concept_id_1,
                        concept_id_2,
                        relationship_id
                        )
                WHERE
                    ROW(cr1.valid_start_date, cr1.valid_end_date, cr1.invalid_reason)
                    IS DISTINCT FROM 
                    ROW(cr2.valid_start_date, cr2.valid_end_date, cr2.invalid_reason)
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.concept_synonym cs1
                FULL JOIN concept_synonym cs2 USING (
                        concept_id,
                        concept_synonym_name,
                        language_concept_id
                        )
                WHERE cs1.* IS DISTINCT FROM cs2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.relationship rel1
                FULL JOIN relationship rel2 USING (relationship_id)
                WHERE rel1.* IS DISTINCT FROM rel2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.vocabulary v1
                FULL JOIN vocabulary v2 USING (vocabulary_id)
                WHERE v1.* IS DISTINCT FROM v2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.concept_class cl1
                FULL JOIN concept_class cl2 USING (concept_class_id)
                WHERE cl1.* IS DISTINCT FROM cl2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.domain dm1
                FULL JOIN domain dm2 USING (domain_id)
                WHERE dm1.* IS DISTINCT FROM dm2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.drug_strength ds1
                FULL JOIN drug_strength ds2 USING (
                        drug_concept_id,
                        ingredient_concept_id
                        )
                WHERE ds1.* IS DISTINCT FROM ds2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.pack_content pc1
                FULL JOIN pack_content pc2 ON pc1.pack_concept_id = pc2.pack_concept_id
                    AND pc1.drug_concept_id = pc2.drug_concept_id
                    AND COALESCE(pc1.amount, -1) = COALESCE(pc2.amount, -1)
                WHERE pc1.* IS DISTINCT FROM pc2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.vocabulary_conversion vc1
                FULL JOIN vocabulary_conversion vc2 USING (vocabulary_id_v4)
                WHERE vc1.* IS DISTINCT FROM vc2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.concept_metadata cm1
                FULL JOIN concept_metadata cm2 USING (concept_id)
                WHERE cm1.* IS DISTINCT FROM cm2.*
                LIMIT 1
            )

            UNION ALL

            (
                SELECT 1
                FROM devv5.concept_relationship_metadata crm1
                FULL JOIN concept_relationship_metadata crm2 USING (
                        concept_id_1,
                        concept_id_2,
                        relationship_id)
                WHERE crm1.* IS DISTINCT FROM crm2.*
                LIMIT 1
            )
        ) s0
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION 'Basic tables are not the same! Please run devv5.FastRecreateSchema(include_deprecated_rels=>true,include_synonyms=>true)';
        END IF;
    END IF;

    RAISE NOTICE 'Disabling constraints...';
    SELECT * INTO pCreateDDLFK FROM vocabulary_pack.DropFKConstraints(pTables);

    RAISE NOTICE 'Dropping indexes...';
    SELECT * INTO pCreateDDLIdx FROM vocabulary_pack.DropIndexes (pTables, ARRAY['idx_concept_synonym_id','u_pack_content']/*not PK, but used as PK*/);

    RAISE NOTICE 'Restoring tables...';
    FOR r IN (SELECT * FROM audit.logged_actions WHERE log_id BETWEEN iLogID AND pCurrent_max_log_id AND table_name <> ALL(pExcludeTables) ORDER BY log_id DESC) LOOP
        IF r.tg_operation='I' THEN --insert
            IF r.table_name='concept' THEN
                DELETE FROM concept WHERE concept_id=(r.new_row->>'concept_id')::INT4;
            ELSIF r.table_name='concept_metadata' THEN
                DELETE FROM concept_metadata WHERE concept_id=(r.new_row->>'concept_id')::INT4;
            ELSIF r.table_name='concept_relationship' THEN
                DELETE FROM concept_relationship WHERE concept_id_1=(r.new_row->>'concept_id_1')::INT4 AND concept_id_2=(r.new_row->>'concept_id_2')::INT4 AND relationship_id=r.new_row->>'relationship_id';
            ELSIF r.table_name='concept_relationship_metadata' THEN
                DELETE FROM concept_relationship_metadata
                 WHERE concept_id_1 = (r.new_row->>'concept_id_1')::INT4 
                   AND concept_id_2 = (r.new_row->>'concept_id_2')::INT4 
                   AND relationship_id = r.new_row->>'relationship_id';
            ELSIF r.table_name='concept_synonym' THEN
                DELETE FROM concept_synonym WHERE concept_id=(r.new_row->>'concept_id')::INT4 AND concept_synonym_name=r.new_row->>'concept_synonym_name' AND language_concept_id=(r.new_row->>'language_concept_id')::INT4;
            ELSIF r.table_name='vocabulary' THEN
                DELETE FROM vocabulary WHERE vocabulary_id=(r.new_row->>'vocabulary_id');
            ELSIF r.table_name='relationship' THEN
                DELETE FROM relationship WHERE relationship_id=(r.new_row->>'relationship_id');
            ELSIF r.table_name='concept_class' THEN
                DELETE FROM concept_class WHERE concept_class_id=(r.new_row->>'concept_class_id');
            ELSIF r.table_name='domain' THEN
                DELETE FROM domain WHERE domain_id=(r.new_row->>'domain_id');
            ELSIF r.table_name='drug_strength' THEN
                DELETE FROM drug_strength WHERE drug_concept_id=(r.new_row->>'drug_concept_id')::INT4 AND ingredient_concept_id=(r.new_row->>'ingredient_concept_id')::INT4;
            ELSIF r.table_name='pack_content' THEN
                DELETE FROM pack_content WHERE pack_concept_id=(r.new_row->>'pack_concept_id')::INT4 AND drug_concept_id=(r.new_row->>'drug_concept_id')::INT4 AND amount IS NOT DISTINCT FROM (r.new_row->>'amount')::INT2;
            ELSIF r.table_name='vocabulary_conversion' THEN
                DELETE FROM vocabulary_conversion WHERE vocabulary_id_v4=(r.new_row->>'vocabulary_id_v4')::INT4;
            END IF;

        ELSIF r.tg_operation='U' THEN --update
            IF r.table_name='concept' THEN
                UPDATE concept c SET
                    (concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)=
                    (j.concept_id,j.concept_name,j.domain_id,j.vocabulary_id,j.concept_class_id,j.standard_concept,j.concept_code,j.valid_start_date,j.valid_end_date,j.invalid_reason)
                FROM JSONB_POPULATE_RECORD(NULL::concept, r.old_row) j
                WHERE c.concept_id=(r.new_row->>'concept_id')::INT4;

            ELSIF r.table_name='concept_metadata' THEN
                UPDATE concept_metadata cm SET
                    (concept_id, concept_category, reuse_status) = (j.concept_id, j.concept_category, j.reuse_status)
                FROM JSONB_POPULATE_RECORD(NULL::concept_metadata, r.old_row) j
                WHERE cm.concept_id=(r.new_row->>'concept_id')::INT4;
                
            ELSIF r.table_name='concept_relationship' THEN
                UPDATE concept_relationship cr SET
                    (concept_id_1,concept_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)=
                    (j.concept_id_1,j.concept_id_2,j.relationship_id,j.valid_start_date,j.valid_end_date,j.invalid_reason)
                FROM JSONB_POPULATE_RECORD(NULL::concept_relationship, r.old_row) j
                WHERE cr.concept_id_1=(r.new_row->>'concept_id_1')::INT4 AND cr.concept_id_2=(r.new_row->>'concept_id_2')::INT4
                AND cr.relationship_id=r.new_row->>'relationship_id';

            ELSIF r.table_name='concept_relationship_metadata' THEN
                UPDATE concept_relationship_metadata crm SET
                    (concept_id_1, concept_id_2, relationship_id,
                     relationship_predicate_id, relationship_group, mapping_source, 
                     confidence, mapping_tool, mapper, reviewer) =
                    (j.concept_id_1, j.concept_id_2, j.relationship_id,
                     j.relationship_predicate_id, j.relationship_group, j.mapping_source, 
                     j.confidence, j.mapping_tool, j.mapper, j.reviewer )
                FROM JSONB_POPULATE_RECORD(NULL::concept_relationship_metadata, r.old_row) j
                WHERE crm.concept_id_1 = r.new_row->>'concept_id_1')::INT4 
                  AND crm.concept_id_2 = (r.new_row->>'concept_id_2')::INT4
                  AND crm.relationship_id = r.new_row->>'relationship_id';
                
            ELSIF r.table_name='concept_synonym' THEN
                UPDATE concept_synonym cs SET
                    (concept_id,concept_synonym_name,language_concept_id)=
                    (j.concept_id,j.concept_synonym_name,j.language_concept_id)
                FROM JSONB_POPULATE_RECORD(NULL::concept_synonym, r.old_row) j
                WHERE cs.concept_id=(r.new_row->>'concept_id')::INT4
                AND cs.concept_synonym_name=r.new_row->>'concept_synonym_name'
                AND cs.language_concept_id=(r.new_row->>'language_concept_id')::INT4;

            ELSIF r.table_name='vocabulary' THEN
                UPDATE vocabulary v SET
                    (vocabulary_id,vocabulary_name,vocabulary_reference,vocabulary_version,vocabulary_concept_id, vocabulary_params)=
                    (j.vocabulary_id,j.vocabulary_name,j.vocabulary_reference,j.vocabulary_version,j.vocabulary_concept_id, j.vocabulary_params)
                FROM JSONB_POPULATE_RECORD(NULL::vocabulary, r.old_row) j
                WHERE v.vocabulary_id=(r.new_row->>'vocabulary_id')
                --skip changes from latest_update/dev_schema_name fields
                AND ROW(v.vocabulary_id,v.vocabulary_name,v.vocabulary_reference,v.vocabulary_version,v.vocabulary_concept_id, v.vocabulary_params)
                IS DISTINCT FROM
                ROW(j.vocabulary_id,j.vocabulary_name,j.vocabulary_reference,j.vocabulary_version,j.vocabulary_concept_id, j.vocabulary_params);

            ELSIF r.table_name='relationship' THEN
                UPDATE relationship rel SET
                    (relationship_id,relationship_name,is_hierarchical,defines_ancestry,reverse_relationship_id,relationship_concept_id)=
                    (j.relationship_id,j.relationship_name,j.is_hierarchical,j.defines_ancestry,j.reverse_relationship_id,j.relationship_concept_id)
                FROM JSONB_POPULATE_RECORD(NULL::relationship, r.old_row) j
                WHERE rel.relationship_id=r.new_row->>'relationship_id';

            ELSIF r.table_name='concept_class' THEN
                UPDATE concept_class cl SET
                    (concept_class_id,concept_class_name,concept_class_concept_id)=
                    (j.concept_class_id,j.concept_class_name,j.concept_class_concept_id)
                FROM JSONB_POPULATE_RECORD(NULL::concept_class, r.old_row) j
                WHERE cl.concept_class_id=r.new_row->>'concept_class_id';

            ELSIF r.table_name='domain' THEN
                UPDATE domain dm SET
                    (domain_id,domain_name,domain_concept_id)=
                    (j.domain_id,j.domain_name,j.domain_concept_id)
                FROM JSONB_POPULATE_RECORD(NULL::domain, r.old_row) j
                WHERE dm.domain_id=r.new_row->>'domain_id';

            ELSIF r.table_name='drug_strength' THEN
                UPDATE drug_strength ds SET
                    (drug_concept_id,ingredient_concept_id,amount_value,amount_unit_concept_id,numerator_value,numerator_unit_concept_id,denominator_value,denominator_unit_concept_id,box_size,valid_start_date,valid_end_date,invalid_reason)=
                    (j.drug_concept_id,j.ingredient_concept_id,j.amount_value,j.amount_unit_concept_id,j.numerator_value,j.numerator_unit_concept_id,j.denominator_value,j.denominator_unit_concept_id,j.box_size,j.valid_start_date,j.valid_end_date,j.invalid_reason)
                FROM JSONB_POPULATE_RECORD(NULL::drug_strength, r.old_row) j
                WHERE ds.drug_concept_id=(r.new_row->>'drug_concept_id')::INT4 AND ds.ingredient_concept_id=(r.new_row->>'ingredient_concept_id')::INT4;

            ELSIF r.table_name='pack_content' THEN
                UPDATE pack_content pc SET
                    (pack_concept_id,drug_concept_id,amount,box_size)=
                    (j.pack_concept_id,j.drug_concept_id,j.amount,j.box_size)
                FROM JSONB_POPULATE_RECORD(NULL::pack_content, r.old_row) j
                WHERE pc.pack_concept_id=(r.new_row->>'pack_concept_id')::INT4 AND pc.drug_concept_id=(r.new_row->>'drug_concept_id')::INT4 AND pc.amount IS NOT DISTINCT FROM (r.new_row->>'amount')::INT2;

            ELSIF r.table_name='vocabulary_conversion' THEN
                UPDATE vocabulary_conversion vc SET
                    (vocabulary_id_v4,vocabulary_id_v5,omop_req,click_default,available,url,click_disabled,latest_update)=
                    (j.vocabulary_id_v4,j.vocabulary_id_v5,j.omop_req,j.click_default,j.available,j.url,j.click_disabled,j.latest_update)
                FROM JSONB_POPULATE_RECORD(NULL::vocabulary_conversion, r.old_row) j
                WHERE vc.vocabulary_id_v4=(r.new_row->>'vocabulary_id_v4')::INT4;
            END IF;

        ELSIF r.tg_operation='D' THEN --delete
            EXECUTE FORMAT('INSERT INTO %I SELECT * FROM JSONB_POPULATE_RECORD (NULL::%I, $1)', r.table_name, r.table_name) USING r.old_row;
        END IF;

        --calculating the percentage of rows processed
        pCurrentPct:=100-((r.log_id-iLogID)::INT8*100)/(pCurrent_max_log_id-iLogID);
        IF pCurrentPct>=10 AND pCurrentPct<100 THEN
            IF LEFT(pCurrentPct::TEXT,1)>LEFT(pProcessedPct::TEXT,1) THEN
                pProcessedPct:=pCurrentPct;
                RAISE NOTICE '% of rows were processed',pProcessedPct::TEXT||'%';
            END IF;
        END IF;
    END LOOP;

    --special fix for the vocabulary_params field, because this field did not exist before log_id=44436537, then we always restore the current value from devv5
    IF iLogID < 44436537 THEN
        UPDATE vocabulary v
        SET vocabulary_params = v5.vocabulary_params
        FROM devv5.vocabulary v5
        WHERE v.vocabulary_id = v5.vocabulary_id
            AND v5.vocabulary_params IS NOT NULL;
    END IF;

    RAISE NOTICE '100%% of rows were processed';

    RAISE NOTICE 'Enabling constraints...';
    EXECUTE pCreateDDLFK;

    RAISE NOTICE 'Enabling indexes...';
    EXECUTE pCreateDDLIdx;


    RAISE NOTICE 'Collecting statistics...';
    FOREACH t IN ARRAY pTables LOOP
        EXECUTE FORMAT('ANALYZE %I',t);
    END LOOP;


    IF pDevv5 THEN
        FOREACH t IN ARRAY pTables LOOP
            EXECUTE FORMAT('ALTER TABLE %I ENABLE TRIGGER USER',t);
        END LOOP;
        
        RAISE NOTICE 'Deleting obsolete log records...';
        
        DELETE FROM audit.logged_actions WHERE log_id BETWEEN iLogID AND pCurrent_max_log_id AND table_name <> ALL(pExcludeTables);

        --update concept_id_1/2 in the base_concept_relationship_manual, if the concepts no longer exist in the base tables
        RAISE NOTICE 'Fixing base_concept_relationship_manual...';
        
        UPDATE base_concept_relationship_manual base_crm
        SET concept_id_1 = 0
        WHERE NOT EXISTS (
                SELECT 1
                FROM concept c_int
                WHERE c_int.concept_code = base_crm.concept_code_1
                    AND c_int.vocabulary_id = base_crm.vocabulary_id_1
                )
            AND base_crm.concept_id_1 <> 0;

        UPDATE base_concept_relationship_manual base_crm
        SET concept_id_2 = 0
        WHERE NOT EXISTS (
                SELECT 1
                FROM concept c_int
                WHERE c_int.concept_code = base_crm.concept_code_2
                    AND c_int.vocabulary_id = base_crm.vocabulary_id_2
                )
            AND base_crm.concept_id_2 <> 0;

        --same for base_concept_manual
        UPDATE base_concept_manual base_cm
        SET concept_id = 0
        WHERE NOT EXISTS (
                SELECT 1
                FROM concept c_int
                WHERE c_int.concept_code = base_cm.concept_code
                    AND c_int.vocabulary_id = base_cm.vocabulary_id
                )
            AND base_cm.concept_id <> 0;

        --same for base_concept_synonym_manual
        UPDATE base_concept_synonym_manual base_csm
        SET concept_id = 0
        WHERE NOT EXISTS (
                SELECT 1
                FROM concept c_int
                WHERE c_int.concept_code = base_csm.synonym_concept_code
                    AND c_int.vocabulary_id = base_csm.synonym_vocabulary_id
                )
            AND base_csm.concept_id <> 0;
    END IF;

    RAISE NOTICE 'Restoring complete';
END;
$BODY$
LANGUAGE 'plpgsql';
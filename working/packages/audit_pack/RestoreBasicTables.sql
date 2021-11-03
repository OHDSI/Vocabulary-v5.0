CREATE OR REPLACE FUNCTION audit.RestoreBasicTables(iLogID INT4)
RETURNS void AS
$BODY$
DECLARE
	r RECORD;
	pDevv5 BOOLEAN:=(CURRENT_SCHEMA='devv5');
	pCurrent_max_log_id INT4;
	pTruncate_id INT4;
	pCurrentPct INT2;
	pProcessedPct INT2:=0;
	pTables TEXT[]:=ARRAY['concept','concept_relationship','concept_synonym','drug_strength','pack_content','relationship','vocabulary','vocabulary_conversion','concept_class','domain'];
	t TEXT;
BEGIN
	IF iLogID IS NULL THEN
		RAISE EXCEPTION 'Please specify the LogID';
	END IF;

	SELECT MAX(log_id), MAX(log_id) FILTER (WHERE tg_operation='T') INTO pCurrent_max_log_id, pTruncate_id FROM audit.logged_actions WHERE log_id>=iLogID;
	
	IF pCurrent_max_log_id IS NULL THEN
		RAISE EXCEPTION 'Record with log_id=% not found in the LOG table',iLogID;
	END IF;

	IF pTruncate_id IS NOT NULL THEN
		RAISE EXCEPTION 'There was a TRUNCATE operation (log_id=%) after the specified LogID (%), can not restore. Please choose another LogID',pTruncate_id,iLogID;
	END IF;

	IF pDevv5 THEN
		--disable triggers to prevent log flooding
		FOR t IN (SELECT * FROM UNNEST(pTables)) LOOP
			EXECUTE FORMAT('ALTER TABLE %I DISABLE TRIGGER USER',t);
		END LOOP;

	ELSE
		--check current schema
		RAISE NOTICE 'Checking current schema...';
		IF (
			EXISTS (
				SELECT 1
				FROM devv5.concept c1
				FULL JOIN concept c2 ON c1.concept_id = c2.concept_id
					AND c1.concept_name = c2.concept_name
					AND c1.domain_id = c2.domain_id
					AND c1.vocabulary_id = c2.vocabulary_id
					AND c1.concept_class_id = c2.concept_class_id
					AND COALESCE(c1.standard_concept, 'X') = COALESCE(c2.standard_concept, 'X')
					AND c1.concept_code = c2.concept_code
					AND c1.valid_start_date = c2.valid_start_date
					AND c1.valid_end_date = c2.valid_end_date
					AND COALESCE(c1.invalid_reason, 'X') = COALESCE(c2.invalid_reason, 'X')
				WHERE c1.concept_id IS NULL
					OR c2.concept_id IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.concept_relationship cr1
				FULL JOIN concept_relationship cr2 ON cr1.concept_id_1 = cr2.concept_id_1
					AND cr1.concept_id_2 = cr2.concept_id_2
					AND cr1.relationship_id = cr2.relationship_id
					AND cr1.valid_start_date = cr2.valid_start_date
					AND cr1.valid_end_date = cr2.valid_end_date
					AND COALESCE(cr1.invalid_reason, 'X') = COALESCE(cr2.invalid_reason, 'X')
				WHERE cr1.concept_id_1 IS NULL
					OR cr2.concept_id_1 IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.concept_synonym cs1
				FULL JOIN concept_synonym cs2 USING (concept_id,concept_synonym_name,language_concept_id)
				WHERE cs1.concept_id IS NULL
					OR cs2.concept_id IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.relationship rel1
				FULL JOIN relationship rel2 USING (relationship_id,relationship_name,is_hierarchical,defines_ancestry,reverse_relationship_id,relationship_concept_id)
				WHERE rel1.relationship_id IS NULL
					OR rel2.relationship_id IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.vocabulary v1
				FULL JOIN vocabulary v2 ON v1.vocabulary_id = v2.vocabulary_id
					AND v1.vocabulary_name = v2.vocabulary_name
					AND v1.vocabulary_reference = v2.vocabulary_reference
					AND COALESCE(v1.vocabulary_version, 'X') = COALESCE(v2.vocabulary_version, 'X')
					AND v1.vocabulary_concept_id = v2.vocabulary_concept_id
				WHERE v1.vocabulary_id IS NULL
					OR v2.vocabulary_id IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.concept_class cl1
				FULL JOIN concept_class cl2 USING (concept_class_id,concept_class_name,concept_class_concept_id)
				WHERE cl1.concept_class_id IS NULL
					OR cl2.concept_class_id IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.domain dm1
				FULL JOIN domain dm2 USING (domain_id,domain_name,domain_concept_id)
				WHERE dm1.domain_id IS NULL
					OR dm2.domain_id IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.drug_strength ds1
				FULL JOIN drug_strength ds2 ON ds1.drug_concept_id = ds2.drug_concept_id
					AND ds1.ingredient_concept_id = ds2.ingredient_concept_id
					AND COALESCE(ds1.amount_value, -1) = COALESCE(ds2.amount_value, -1)
					AND COALESCE(ds1.amount_unit_concept_id, -1) = COALESCE(ds2.amount_unit_concept_id, -1)
					AND COALESCE(ds1.numerator_value, -1) = COALESCE(ds2.numerator_value, -1)
					AND COALESCE(ds1.numerator_unit_concept_id, -1) = COALESCE(ds2.numerator_unit_concept_id, -1)
					AND COALESCE(ds1.denominator_value, -1) = COALESCE(ds2.denominator_value, -1)
					AND COALESCE(ds1.denominator_unit_concept_id, -1) = COALESCE(ds2.denominator_unit_concept_id, -1)
					AND COALESCE(ds1.box_size, -1) = COALESCE(ds2.box_size, -1)
					AND ds1.valid_start_date = ds2.valid_start_date
					AND ds1.valid_end_date = ds2.valid_end_date
					AND COALESCE(ds1.invalid_reason, 'X') = COALESCE(ds2.invalid_reason, 'X')
				WHERE ds1.drug_concept_id IS NULL
					OR ds2.drug_concept_id IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.pack_content pc1
				FULL JOIN pack_content pc2 ON pc1.pack_concept_id = pc2.pack_concept_id
					AND pc1.drug_concept_id = pc2.drug_concept_id
					AND COALESCE(pc1.amount, -1) = COALESCE(pc2.amount, -1)
					AND COALESCE(pc1.box_size, -1) = COALESCE(pc2.box_size, -1)
				WHERE pc1.pack_concept_id IS NULL
					OR pc2.pack_concept_id IS NULL
				)
			OR EXISTS (
				SELECT 1
				FROM devv5.vocabulary_conversion vc1
				FULL JOIN vocabulary_conversion vc2 ON vc1.vocabulary_id_v4 = vc2.vocabulary_id_v4
					AND COALESCE(vc1.vocabulary_id_v5, 'X') = COALESCE(vc2.vocabulary_id_v5, 'X')
					AND COALESCE(vc1.omop_req, 'X') = COALESCE(vc2.omop_req, 'X')
					AND COALESCE(vc1.click_default, 'X') = COALESCE(vc2.click_default, 'X')
					AND COALESCE(vc1.available, 'X') = COALESCE(vc2.available, 'X')
					AND COALESCE(vc1.url, 'X') = COALESCE(vc2.url, 'X')
					AND COALESCE(vc1.click_disabled, 'X') = COALESCE(vc2.click_disabled, 'X')
					AND COALESCE(vc1.latest_update, CURRENT_DATE) = COALESCE(vc2.latest_update, CURRENT_DATE)
				WHERE vc1.vocabulary_id_v4 IS NULL
					OR vc2.vocabulary_id_v4 IS NULL
				)
			) THEN
		RAISE EXCEPTION 'Basic tables are not the same! Please run devv5.FastRecreateSchema(include_deprecated_rels=>true,include_synonyms=>true)';
		END IF;
	END IF;

	RAISE NOTICE 'Disabling constraints...';
	ALTER TABLE relationship DROP CONSTRAINT fpk_relationship_concept;
	ALTER TABLE vocabulary DROP CONSTRAINT fpk_vocabulary_concept;
	ALTER TABLE concept_class DROP CONSTRAINT fpk_concept_class_concept;
	ALTER TABLE domain DROP CONSTRAINT fpk_domain_concept;
	ALTER TABLE concept_relationship DROP CONSTRAINT fpk_concept_relationship_c_1;
	ALTER TABLE concept_relationship DROP CONSTRAINT fpk_concept_relationship_c_2;
	ALTER TABLE concept_relationship DROP CONSTRAINT fpk_concept_relationship_id;
	ALTER TABLE concept_synonym DROP CONSTRAINT fpk_concept_synonym_concept;
	ALTER TABLE concept_synonym DROP CONSTRAINT fpk_concept_synonym_language;
	ALTER TABLE concept_synonym DROP CONSTRAINT unique_synonyms;
	ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_concept_1;
	ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_concept_2;
	ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_unit_1;
	ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_unit_2;
	ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_unit_3;
	ALTER TABLE pack_content DROP CONSTRAINT fpk_pack_content_concept_1;
	ALTER TABLE pack_content DROP CONSTRAINT fpk_pack_content_concept_2;
	ALTER TABLE concept DROP CONSTRAINT fpk_concept_domain;
	ALTER TABLE concept DROP CONSTRAINT fpk_concept_class;
	ALTER TABLE concept DROP CONSTRAINT fpk_concept_vocabulary;

	RAISE NOTICE 'Restoring tables...';
	FOR r IN (SELECT * FROM audit.logged_actions WHERE log_id BETWEEN iLogID AND pCurrent_max_log_id ORDER BY log_id DESC) LOOP
		IF r.tg_operation='I' THEN --insert
			IF r.table_name='concept' THEN
				DELETE FROM concept WHERE concept_id=(r.new_row->>'concept_id')::INT4;
			ELSIF r.table_name='concept_relationship' THEN
				DELETE FROM concept_relationship WHERE concept_id_1=(r.new_row->>'concept_id_1')::INT4 AND concept_id_2=(r.new_row->>'concept_id_2')::INT4 AND relationship_id=r.new_row->>'relationship_id';
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

			ELSIF r.table_name='concept_relationship' THEN
				UPDATE concept_relationship cr SET
					(concept_id_1,concept_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)=
					(j.concept_id_1,j.concept_id_2,j.relationship_id,j.valid_start_date,j.valid_end_date,j.invalid_reason)
				FROM JSONB_POPULATE_RECORD(NULL::concept_relationship, r.old_row) j
				WHERE cr.concept_id_1=(r.new_row->>'concept_id_1')::INT4 AND cr.concept_id_2=(r.new_row->>'concept_id_2')::INT4
				AND cr.relationship_id=r.new_row->>'relationship_id';

			ELSIF r.table_name='concept_synonym' THEN
				UPDATE concept_synonym cs SET
					(concept_id,concept_synonym_name,language_concept_id)=
					(j.concept_id,j.concept_synonym_name,j.language_concept_id)
				FROM JSONB_POPULATE_RECORD(NULL::concept_synonym, r.old_row) j
				WHERE cs.concept_id=(r.new_row->>'concept_id')::INT4
				AND cs.concept_synonym_name=r.new_row->>'concept_synonym_name'
				AND cs.language_concept_id=(r.new_row->>'language_concept_id')::INT4;

			ELSIF r.table_name='vocabulary' THEN
				IF r.old_row ? 'dev_schema_name' OR r.new_row ? 'dev_schema_name' THEN
					CONTINUE; --skip ALTER TABLE from SetLatestUpdate
				END IF;
				
				UPDATE vocabulary v SET
					(vocabulary_id,vocabulary_name,vocabulary_reference,vocabulary_version,vocabulary_concept_id)=
					(j.vocabulary_id,j.vocabulary_name,j.vocabulary_reference,j.vocabulary_version,j.vocabulary_concept_id)
				FROM JSONB_POPULATE_RECORD(NULL::vocabulary, r.old_row) j
				WHERE v.vocabulary_id=(r.new_row->>'vocabulary_id');

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
		pCurrentPct:=100-((r.log_id-iLogID)*100)/(pCurrent_max_log_id-iLogID);
		IF pCurrentPct>=10 AND pCurrentPct<100 THEN
			IF LEFT(pCurrentPct::TEXT,1)>LEFT(pProcessedPct::TEXT,1) THEN
				pProcessedPct:=pCurrentPct;
				RAISE NOTICE '% of rows were processed',pProcessedPct::TEXT||'%';
			END IF;
		END IF;
	END LOOP;
	RAISE NOTICE '100%% of rows were processed';

	RAISE NOTICE 'Enabling constraints...';
	ALTER TABLE concept ADD CONSTRAINT fpk_concept_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id);
	ALTER TABLE concept ADD CONSTRAINT fpk_concept_class FOREIGN KEY (concept_class_id) REFERENCES concept_class (concept_class_id);
	ALTER TABLE concept ADD CONSTRAINT fpk_concept_vocabulary FOREIGN KEY (vocabulary_id) REFERENCES vocabulary (vocabulary_id);
	ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_concept FOREIGN KEY (relationship_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE vocabulary ADD CONSTRAINT fpk_vocabulary_concept FOREIGN KEY (vocabulary_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE concept_class ADD CONSTRAINT fpk_concept_class_concept FOREIGN KEY (concept_class_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE domain ADD CONSTRAINT fpk_domain_concept FOREIGN KEY (domain_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_1 FOREIGN KEY (concept_id_1) REFERENCES concept (concept_id);
	ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_2 FOREIGN KEY (concept_id_2) REFERENCES concept (concept_id);
	ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_id FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
	ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_concept FOREIGN KEY (concept_id) REFERENCES concept (concept_id);
	ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_language FOREIGN KEY (language_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE concept_synonym ADD CONSTRAINT unique_synonyms UNIQUE (concept_id,concept_synonym_name,language_concept_id);
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_1 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_2 FOREIGN KEY (ingredient_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_1 FOREIGN KEY (amount_unit_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_2 FOREIGN KEY (numerator_unit_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_3 FOREIGN KEY (denominator_unit_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_1 FOREIGN KEY (pack_concept_id) REFERENCES concept (concept_id);
	ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_2 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id);

	IF pDevv5 THEN
		FOR t IN (SELECT * FROM UNNEST(pTables)) LOOP
			EXECUTE FORMAT('ALTER TABLE %I ENABLE TRIGGER USER',t);
		END LOOP;
		RAISE NOTICE 'Deleting obsolete log records...';
		DELETE FROM audit.logged_actions WHERE log_id BETWEEN iLogID AND pCurrent_max_log_id;
	END IF;

	RAISE NOTICE 'Restoring complete';
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY INVOKER;
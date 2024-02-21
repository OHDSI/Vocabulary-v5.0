--Create a target (base) table for manual relationships in devv5
DROP TABLE IF EXISTS devv5.base_concept_relationship_manual CASCADE;
CREATE TABLE devv5.base_concept_relationship_manual (
	LIKE devv5.concept_relationship_manual,
	concept_id_1 INT4 NOT NULL,
	concept_id_2 INT4 NOT NULL,
	created TIMESTAMPTZ NOT NULL,
	created_by INT4 NOT NULL REFERENCES admin_pack.virtual_user(user_id),
	modified TIMESTAMPTZ,
	modified_by INT4 REFERENCES admin_pack.virtual_user(user_id),
	CONSTRAINT idx_pk_base_crm PRIMARY KEY (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id
		)
	);

--filling
INSERT INTO devv5.base_concept_relationship_manual
SELECT all_r.concept_code_1,
	all_r.concept_code_2,
	all_r.vocabulary_id_1,
	all_r.vocabulary_id_2,
	all_r.relationship_id,
	all_r.valid_start_date,
	all_r.valid_end_date,
	all_r.invalid_reason,
	COALESCE(c1.concept_id, 0),
	COALESCE(c2.concept_id, 0),
	TO_DATE('19700101', 'YYYYMMDD'),
	1,
	NULL,
	NULL
FROM dev_test.all_rels all_r
LEFT JOIN devv5.concept c1 ON c1.concept_code = all_r.concept_code_1
	AND c1.vocabulary_id = all_r.vocabulary_id_1
LEFT JOIN devv5.concept c2 ON c2.concept_code = all_r.concept_code_2
	AND c2.vocabulary_id = all_r.vocabulary_id_2;

CREATE INDEX idx_base_crm_cid1 ON devv5.base_concept_relationship_manual (concept_id_1) WHERE concept_id_1=0;
CREATE INDEX idx_base_crm_cid2 ON devv5.base_concept_relationship_manual (concept_id_2) WHERE concept_id_2=0;

ANALYZE devv5.base_concept_relationship_manual;

--Create a view for selecting crm with logins and names
CREATE OR REPLACE VIEW devv5.v_base_concept_relationship_manual AS
SELECT crm.*,
	vu_c.user_login AS created_by_login,
	vu_c.user_name AS created_by_name,
	vu_c.user_description AS created_by_description,
	vu_m.user_login AS modified_by_login,
	vu_m.user_name AS modified_by_name,
	vu_m.user_description AS modified_by_description
FROM devv5.base_concept_relationship_manual crm
JOIN admin_pack.virtual_user vu_c ON vu_c.user_id = crm.created_by
LEFT JOIN admin_pack.virtual_user vu_m ON vu_m.user_id = crm.modified_by;

--Create a target (base) table for manual concepts in devv5
DROP TABLE IF EXISTS devv5.base_concept_manual CASCADE;
CREATE TABLE devv5.base_concept_manual (
	LIKE devv5.concept_manual,
	concept_id INT4 NOT NULL,
	created TIMESTAMPTZ NOT NULL,
	created_by INT4 NOT NULL REFERENCES admin_pack.virtual_user(user_id),
	modified TIMESTAMPTZ,
	modified_by INT4 REFERENCES admin_pack.virtual_user(user_id),
	CONSTRAINT idx_pk_base_cm PRIMARY KEY (
		concept_code,
		vocabulary_id
		)
	);

--filling
INSERT INTO devv5.base_concept_manual
SELECT all_c.concept_name,
	all_c.domain_id,
	all_c.vocabulary_id,
	all_c.concept_class_id,
	all_c.standard_concept,
	all_c.concept_code,
	all_c.valid_start_date,
	all_c.valid_end_date,
	all_c.invalid_reason,
	COALESCE(c.concept_id, 0),
	TO_DATE('19700101', 'YYYYMMDD'),
	1,
	NULL,
	NULL
FROM dev_test.all_concepts all_c
LEFT JOIN devv5.concept c USING (concept_code, vocabulary_id);

CREATE INDEX idx_base_cm_cid ON devv5.base_concept_manual (concept_id) WHERE concept_id=0;

ANALYZE devv5.base_concept_manual;

--Create a view for selecting cm with logins and names
CREATE OR REPLACE VIEW devv5.v_base_concept_manual AS
SELECT cm.*,
	vu_c.user_login AS created_by_login,
	vu_c.user_name AS created_by_name,
	vu_c.user_description AS created_by_description,
	vu_m.user_login AS modified_by_login,
	vu_m.user_name AS modified_by_name,
	vu_m.user_description AS modified_by_description
FROM devv5.base_concept_manual cm
JOIN admin_pack.virtual_user vu_c ON vu_c.user_id = cm.created_by
LEFT JOIN admin_pack.virtual_user vu_m ON vu_m.user_id = cm.modified_by;

--Create a target (base) table for manual synonyms in devv5
DROP TABLE IF EXISTS devv5.base_concept_synonym_manual CASCADE;
CREATE TABLE devv5.base_concept_synonym_manual (
	LIKE devv5.concept_synonym_manual,
	concept_id INT4 NOT NULL,
	created TIMESTAMPTZ NOT NULL,
	created_by INT4 NOT NULL REFERENCES admin_pack.virtual_user(user_id),
	modified TIMESTAMPTZ,
	modified_by INT4 REFERENCES admin_pack.virtual_user(user_id),
	CONSTRAINT idx_pk_base_csm PRIMARY KEY (
		synonym_vocabulary_id,
		synonym_name,
		synonym_concept_code,
		language_concept_id
		)
	);

--filling
INSERT INTO devv5.base_concept_synonym_manual
SELECT all_s.synonym_name,
	all_s.synonym_concept_code,
	all_s.synonym_vocabulary_id,
	all_s.language_concept_id,
	COALESCE(c.concept_id, 0),
	TO_DATE('19700101', 'YYYYMMDD'),
	1,
	NULL,
	NULL
FROM dev_test.all_synonyms all_s
LEFT JOIN devv5.concept c ON c.concept_code = all_s.synonym_concept_code
	AND c.vocabulary_id = all_s.synonym_vocabulary_id;

CREATE INDEX idx_base_csm_cid ON devv5.base_concept_synonym_manual (concept_id) WHERE concept_id=0;

ANALYZE devv5.base_concept_synonym_manual;

--Create a view for selecting csm with logins and names
CREATE OR REPLACE VIEW devv5.v_base_concept_synonym_manual AS
SELECT csm.*,
	vu_c.user_login AS created_by_login,
	vu_c.user_name AS created_by_name,
	vu_c.user_description AS created_by_description,
	vu_m.user_login AS modified_by_login,
	vu_m.user_name AS modified_by_name,
	vu_m.user_description AS modified_by_description
FROM devv5.base_concept_synonym_manual csm
JOIN admin_pack.virtual_user vu_c ON vu_c.user_id = csm.created_by
LEFT JOIN admin_pack.virtual_user vu_m ON vu_m.user_id = csm.modified_by;

--Create a table for manual relationships in admin_pack (a tempopary place for storing logs before they're sent to devv5)
DROP TABLE IF EXISTS admin_pack.concept_relationship_manual;
CREATE TABLE admin_pack.concept_relationship_manual (
	LIKE devv5.base_concept_relationship_manual,
	dev_schema_name TEXT NOT NULL,
	CONSTRAINT idx_pk_crm PRIMARY KEY (
		dev_schema_name,
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id
		)
	);
ALTER TABLE admin_pack.concept_relationship_manual DROP COLUMN concept_id_1, DROP COLUMN concept_id_2;

--Same for concept_manual
DROP TABLE IF EXISTS admin_pack.concept_manual;
CREATE TABLE admin_pack.concept_manual (
	LIKE devv5.base_concept_manual,
	dev_schema_name TEXT NOT NULL,
	CONSTRAINT idx_pk_cm PRIMARY KEY (
		dev_schema_name,
		concept_code,
		vocabulary_id
		)
	);
ALTER TABLE admin_pack.concept_manual DROP COLUMN concept_id;

--Same for concept_synonym_manual
DROP TABLE IF EXISTS admin_pack.concept_synonym_manual;
CREATE TABLE admin_pack.concept_synonym_manual (
	LIKE devv5.base_concept_synonym_manual,
	dev_schema_name TEXT NOT NULL,
	CONSTRAINT idx_pk_csm PRIMARY KEY (
		dev_schema_name,
		synonym_name,
		synonym_concept_code,
		synonym_vocabulary_id,
		language_concept_id
		)
	);
ALTER TABLE admin_pack.concept_synonym_manual DROP COLUMN concept_id;

--Create triggers for all manual tables
DO $$
DECLARE
	iTables TEXT[]:=ARRAY['base_concept_manual','base_concept_relationship_manual','base_concept_synonym_manual'];
	t TEXT;
BEGIN
	FOREACH t IN ARRAY iTables LOOP
		EXECUTE FORMAT('
		CREATE TRIGGER tg_audit_u
		AFTER UPDATE ON %1$I
		FOR EACH ROW
		WHEN (OLD.* IS DISTINCT FROM NEW.*)
		EXECUTE PROCEDURE audit.f_tg_audit();

		CREATE TRIGGER tg_audit_id
		AFTER INSERT OR DELETE ON %1$I
		FOR EACH ROW
		EXECUTE PROCEDURE audit.f_tg_audit();

		CREATE TRIGGER tg_audit_t
		AFTER TRUNCATE ON %1$I
		FOR EACH STATEMENT
		EXECUTE PROCEDURE audit.f_tg_audit();',t);
	END LOOP;
END $$;
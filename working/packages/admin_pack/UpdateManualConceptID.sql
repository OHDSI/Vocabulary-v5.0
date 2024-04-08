CREATE OR REPLACE FUNCTION admin_pack.UpdateManualConceptID ()
RETURNS VOID AS
$BODY$
	/*
	Update concept_id fields in the "basic" manual tables for storing in audit
	Must run at the end of generic_update
	*/
BEGIN
	IF SESSION_USER='devv5' THEN
		--if we're under devv5
		UPDATE base_concept_relationship_manual base_crm
		SET concept_id_1 = c.concept_id
		FROM concept c
		WHERE base_crm.concept_code_1 = c.concept_code
			AND base_crm.vocabulary_id_1 = c.vocabulary_id
			AND base_crm.concept_id_1 = 0;

		UPDATE base_concept_relationship_manual base_crm
		SET concept_id_2 = c.concept_id
		FROM concept c
		WHERE base_crm.concept_code_2 = c.concept_code
			AND base_crm.vocabulary_id_2 = c.vocabulary_id
			AND base_crm.concept_id_2 = 0;

		UPDATE base_concept_manual base_cm
		SET concept_id = c.concept_id
		FROM concept c
		WHERE base_cm.concept_code = c.concept_code
			AND base_cm.vocabulary_id = c.vocabulary_id
			AND base_cm.concept_id = 0;

		UPDATE base_concept_synonym_manual base_csm
		SET concept_id = c.concept_id
		FROM concept c
		WHERE base_csm.synonym_concept_code = c.concept_code
			AND base_csm.synonym_vocabulary_id = c.vocabulary_id
			AND base_csm.concept_id = 0;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql';
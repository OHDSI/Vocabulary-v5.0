CREATE OR REPLACE FUNCTION admin_pack.DeleteManualRelationship (
	pConcept_code_1 TEXT,
	pVocabulary_id_1 TEXT,
	pConcept_code_2 TEXT,
	pVocabulary_id_2 TEXT,
	pRelationship_id TEXT
	)
RETURNS VOID AS
$BODY$
	/*
	Delete manual relationship from the base crm (devv5.base_concept_relationship_manual)

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.DeleteManualRelationship(
			pConcept_code_1  =>'A',
			pVocabulary_id_1 =>'SNOMED',
			pConcept_code_2  =>'B',
			pVocabulary_id_2 =>'SNOMED',
			pRelationship_id =>'Maps to'
		);
	END $_$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
BEGIN
	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.DELETE_MANUAL_RELATIONSHIP) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	DELETE
	FROM devv5.base_concept_relationship_manual base_crm
	WHERE base_crm.concept_code_1 = pConcept_code_1
		AND base_crm.vocabulary_id_1 = pVocabulary_id_1
		AND base_crm.concept_code_2 = pConcept_code_2
		AND base_crm.vocabulary_id_2 = pVocabulary_id_2
		AND base_crm.relationship_id = pRelationship_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Manual relationship with concept_code_1=%, vocabulary_id_1=%, concept_code_2=%, vocabulary_id_2=%, relationship_id=% not found', pConcept_code_1, pVocabulary_id_1, pConcept_code_2, pVocabulary_id_2, pRelationship_id;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;
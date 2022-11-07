--Fix vocabulary_name content [AVOF-3741]
--https://github.com/OHDSI/Vocabulary-v5.0/issues/712

DO $$
BEGIN
	--fix 'US Census'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Census regions of the United States (USCB)'
		WHERE vocabulary_id = 'US Census'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'VANDF'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Veterans Health Administration National Drug File (VA))'
		WHERE vocabulary_id = 'VANDF'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'UK Biobank'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'UK Biobank (UK Biobank)'
		WHERE vocabulary_id = 'UK Biobank'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'Sponsor'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'OMOP Sponsor'
		WHERE vocabulary_id = 'Sponsor'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'SNOMED Veterinary'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'SNOMED Veterinary Extension (VTSL)'
		WHERE vocabulary_id = 'SNOMED Veterinary'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'RxNorm Extension'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'OMOP RxNorm Extension'
		WHERE vocabulary_id = 'RxNorm Extension'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'Plan'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'OMOP Health Plan'
		WHERE vocabulary_id = 'Plan'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'Plan Stop Reason'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'OMOP Plan Stop Reason'
		WHERE vocabulary_id = 'Plan Stop Reason'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'OSM'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'OpenStreetMap (OSMF)'
		WHERE vocabulary_id = 'OSM'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'Nebraska Lexicon'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Nebraska Lexicon (UNMC)'
		WHERE vocabulary_id = 'Nebraska Lexicon'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'NCCD'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Normalized Chinese Clinical Drug knowledge base (UTHealth)'
		WHERE vocabulary_id = 'NCCD'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'Metadata'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'OMOP Metadata'
		WHERE vocabulary_id = 'Metadata'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'Language'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'OMOP Language'
		WHERE vocabulary_id = 'Language'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'Korean Revenue Code'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Korean Revenue Code (KNHIS)'
		WHERE vocabulary_id = 'Korean Revenue Code'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'KNHIS'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Korean Payer (KNHIS)'
		WHERE vocabulary_id = 'KNHIS'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'KCD7'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Korean Standard Classfication of Diseases and Causes of Death, 7th Revision (STATISTICS KOREA)'
		WHERE vocabulary_id = 'KCD7'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'ICD10CN'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'International Classification of Diseases, Tenth Revision, Chinese Edition (CAMS)'
		WHERE vocabulary_id = 'ICD10CN'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'ICD9ProcCN'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'International Classification of Diseases, Ninth Revision, Chinese Edition, Procedures (CAMS)'
		WHERE vocabulary_id = 'ICD9ProcCN'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'EDI'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Korean Electronic Data Interchange code system (HIRA)'
		WHERE vocabulary_id = 'EDI'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'CTD'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Comparative Toxicogenomic Database (NCSU)'
		WHERE vocabulary_id = 'CTD'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'CIM10'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'International Classification of Diseases, Tenth Revision, French Edition (ATIH)'
		WHERE vocabulary_id = 'CIM10'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;

	--fix 'CCAM'
	WITH v_upd
	AS (
		UPDATE vocabulary
		SET vocabulary_name = 'Common Classification of Medical Acts (ATIH)'
		WHERE vocabulary_id = 'CCAM'
		RETURNING *
		)
	UPDATE concept c
	SET concept_name = v.vocabulary_name
	FROM v_upd v
	WHERE c.concept_id = v.vocabulary_concept_id;
END $$;
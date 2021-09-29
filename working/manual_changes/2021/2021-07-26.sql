DO $_$
	--Create new vocabulary 'OMOP Genomic'
	BEGIN
		PERFORM VOCABULARY_PACK.AddNewVocabulary(
		pVocabulary_id			=> 'OMOP Genomic',
		pVocabulary_name		=> 'OMOP Genomic vocabulary',
		pVocabulary_reference	=> 'OMOP generated',
		pVocabulary_version		=> NULL,
		pOMOP_req				=> NULL,
		pClick_default			=> NULL, --NULL or 'Y'
		pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
		pURL					=> NULL,
		pClick_disabled			=> NULL --NULL or 'Y'
	);

	--Change hierarchy direction
	UPDATE relationship
	SET is_hierarchical = 1,
		defines_ancestry = 1
	WHERE relationship_concept_id IN (
			32919,
			32921
			);

	UPDATE relationship
	SET is_hierarchical = 0,
		defines_ancestry = 0
	WHERE relationship_concept_id IN (
			32920,
			32922
			);

	--Rename concept_class_ids and names
	ALTER TABLE concept DROP CONSTRAINT fpk_concept_class;

	-- update concept_classes
	UPDATE concept_class
	SET concept_class_id = 'DNA Variant',
		concept_class_name = 'DNA Variant'
	WHERE concept_class_concept_id = 32924;

	UPDATE concept
	SET concept_name = 'DNA Variant'
	WHERE concept_id = 32924;

	UPDATE concept
	SET concept_class_id = 'DNA Variant'
	WHERE concept_class_id = 'Genomic Variant';

	UPDATE concept_class
	SET concept_class_id = 'Genetic Variation',
		concept_class_name = 'Genetic Variation'
	WHERE concept_class_concept_id = 32925;

	UPDATE concept
	SET concept_name = 'Genetic Variation'
	WHERE concept_id = 32925;

	UPDATE concept
	SET concept_class_id = 'Genetic Variation'
	WHERE concept_class_id = 'Gene';

	UPDATE concept_class
	SET concept_class_id = 'RNA Variant',
		concept_class_name = 'RNA Variant'
	WHERE concept_class_concept_id = 32923;

	UPDATE concept
	SET concept_name = 'RNA Variant'
	WHERE concept_id = 32923;

	UPDATE concept
	SET concept_class_id = 'RNA Variant'
	WHERE concept_class_id = 'Transcript Variant';

	ALTER TABLE concept ADD CONSTRAINT fpk_concept_class FOREIGN KEY (concept_class_id) REFERENCES concept_class (concept_class_id);

	--Replace concept_code and vocabulary for genomic concepts
	UPDATE concept c
	SET concept_code = omop_can_code,
		vocabulary_id = 'OMOP Genomic'
	FROM dev_dkaduk.upd_concept_june a
	WHERE a.concept_id = c.concept_id;

	--Replace 'OMOP Extension' vocabulary to 'OMOP Genomic' for genomic concepts
	UPDATE concept c
	SET vocabulary_id = 'OMOP Genomic'
	WHERE vocabulary_id = 'OMOP Extension'
		AND concept_class_id LIKE '%Variant';

	--Replace 'HGNC' vocabulary to 'OMOP Genomic' for genomic concepts
	UPDATE concept c
	SET vocabulary_id = 'OMOP Genomic'
	WHERE vocabulary_id = 'HGNC';
END $_$;


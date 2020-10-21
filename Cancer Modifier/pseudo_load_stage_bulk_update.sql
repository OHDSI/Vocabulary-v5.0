DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=>'Cancer Modifier',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'Cancer Modifier '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'dev_test'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'NCIt',
	pVocabularyDate			=> to_date ('20180101', 'yyyyMMdd'),
	pVocabularyVersion		=> 'NCIt 2018-01-01',
	pVocabularyDevSchema	=> 'dev_test',
	pAppendVocabulary		=> TRUE
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CDM',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'CDM v6.0.2',
	pVocabularyDevSchema	=> 'dev_test',
	pAppendVocabulary		=> TRUE
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'Episode',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'Episode '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'dev_test',
	pAppendVocabulary		=> TRUE
);
END $_$;


-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;
--copy tables
insert into concept_stage select * from dev_christian.concept_stage
;
insert into concept_relationship_stage select * from dev_christian.concept_relationship_stage
;
--fixes
    update concept_stage set concept_name = trim (concept_name)
    ;
 update concept_stage set concept_name = replace (concept_name, '"','') where concept_name ~ '^".*"$'
 ;
 UPDATE concept_stage
   SET valid_start_date = DATE '1970-01-01'
WHERE vocabulary_id = 'Episode'
AND   concept_code = 'OMOP4997717'
;
-- avoid relationships deprecation, when we deal with delta
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT a.concept_code,
	b.concept_code,
	a.vocabulary_id,
	b.vocabulary_id,
	relationship_id,
	r.valid_start_date,
	r.valid_end_date,
	null
FROM concept a
JOIN concept_relationship r ON a.concept_id = concept_id_1
	AND r.invalid_reason IS NULL
JOIN concept b ON b.concept_id = concept_id_2
--deprecated concepts shouldn't have relationships
left join concept_stage s on a.concept_code = s.concept_code and a.vocabulary_id =s.vocabulary_id and s.invalid_reason is not null
WHERE 		a.vocabulary_id in (select vocabulary_id from concept_stage)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = a.concept_code
			AND crs_int.concept_code_2 = b.concept_code
			AND crs_int.vocabulary_id_1 = a.vocabulary_id
			AND crs_int.vocabulary_id_2 = b.vocabulary_id
			AND crs_int.relationship_id = r.relationship_id
		)
		and s.concept_code is null
		;

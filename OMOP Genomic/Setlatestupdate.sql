DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CIViC',
	pVocabularyDate			=> TO_DATE('20170425','YYYYMMDD'),
	pVocabularyVersion		=> 'CIViC v20170425',
	pVocabularyDevSchema	=> 'dev_genomic'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ClinVar',
	pVocabularyDate			=> TO_DATE('20200901','YYYYMMDD'),
	pVocabularyVersion		=> 'ClinVar v20200901',
	pVocabularyDevSchema	=> 'dev_genomic',
	pAppendVocabulary		=> TRUE
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'NCIt',
	pVocabularyDate			=> TO_DATE('20200820','YYYYMMDD'),
	pVocabularyVersion		=> 'NCIt 20200820',
	pVocabularyDevSchema	=> 'dev_genomic',
	pAppendVocabulary		=> TRUE
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CGI',
	pVocabularyDate			=> TO_DATE('20180117','YYYYMMDD'),
	pVocabularyVersion		=> 'CGI v20180117',
	pVocabularyDevSchema	=> 'dev_genomic',
	pAppendVocabulary		=> TRUE
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'JAX',
	pVocabularyDate			=> TO_DATE('20200824','YYYYMMDD'),
	pVocabularyVersion		=> 'JAX v20200824',
	pVocabularyDevSchema	=> 'dev_genomic',
	pAppendVocabulary		=> TRUE
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OMOP Genomic',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'OMOP Genomic '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'dev_genomic',
	pAppendVocabulary		=> TRUE
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OncoKB',
	pVocabularyDate			=> TO_DATE('20210502','YYYYMMDD'),
	pVocabularyVersion		=> 'OncoKB v20210502',
	pVocabularyDevSchema	=> 'dev_genomic',
	pAppendVocabulary		=> TRUE
);
END $_$;
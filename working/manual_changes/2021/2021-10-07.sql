--rename VA Product to VANDF [AVOF-3304]
do $$
declare
	cOldVocabulary constant varchar(100):='VA Product';
	cNewVocabulary constant varchar(100):='VANDF';
begin
	alter table vocabulary drop constraint fpk_vocabulary_concept;
	alter table concept drop constraint fpk_concept_vocabulary;
	update concept set vocabulary_id=cNewVocabulary where vocabulary_id=cOldVocabulary;
	update concept c set concept_name='Veterans Health Administration National Drug File' from vocabulary v where v.vocabulary_id=cOldVocabulary and c.concept_id=v.vocabulary_concept_id;
	update vocabulary set vocabulary_id=cNewVocabulary, vocabulary_name = 'Veterans Health Administration National Drug File' where vocabulary_id=cOldVocabulary;
	update vocabulary_conversion set vocabulary_id_v5=cNewVocabulary where vocabulary_id_v5=cOldVocabulary;
	alter table vocabulary add constraint fpk_vocabulary_concept foreign key (vocabulary_concept_id) references concept (concept_id);
	alter table concept add constraint fpk_concept_vocabulary foreign key (vocabulary_id) references vocabulary (vocabulary_id);
end $$;

--move NDFRT concepts from VANDF to NDFRT
UPDATE concept c
SET vocabulary_id = 'NDFRT'
FROM (
	SELECT c.concept_id
	FROM concept c
	LEFT JOIN sources.rxnconso rx ON rx.code = c.concept_code
		AND rx.sab = 'VANDF'
	WHERE c.vocabulary_id = 'VANDF'
		AND rx.code IS NULL
	) va
WHERE va.concept_id = c.concept_id;

--fix valid_start_date for all old concepts [Mik, Dmitry]
UPDATE concept
SET valid_start_date = TO_DATE('19700101', 'yyyymmdd')
WHERE vocabulary_id = 'VANDF';

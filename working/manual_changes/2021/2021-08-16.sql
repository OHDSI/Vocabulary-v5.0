--rename PHDSC vocabulary to SOPT [AVOF-3232]
do $$
declare
	cOldVocabulary constant varchar(100):='PHDSC';
	cNewVocabulary constant varchar(100):='SOPT';
begin
	alter table vocabulary drop constraint fpk_vocabulary_concept;
	alter table concept drop constraint fpk_concept_vocabulary;
	update concept set vocabulary_id=cNewVocabulary where vocabulary_id=cOldVocabulary;
	update concept c set concept_name='Source of Payment Typology (NAHDO)' where c.concept_id=(select v.vocabulary_concept_id from vocabulary v where v.vocabulary_id=cOldVocabulary);
	update vocabulary set vocabulary_id=cNewVocabulary, vocabulary_reference='https://www.nahdo.org/sopt', vocabulary_name='Source of Payment Typology (NAHDO)' where vocabulary_id=cOldVocabulary;
	update vocabulary_conversion set vocabulary_id_v5=cNewVocabulary where vocabulary_id_v5=cOldVocabulary;
	alter table vocabulary add constraint fpk_vocabulary_concept foreign key (vocabulary_concept_id) references concept (concept_id);
	alter table concept add constraint fpk_concept_vocabulary foreign key (vocabulary_id) references vocabulary (vocabulary_id);
end $$;
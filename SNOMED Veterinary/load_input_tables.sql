CREATE OR REPLACE FUNCTION sources_load_input_tables (
  pvocabularyid text,
  pvocabularydate date = NULL::date,
  pvocabularyversion text = NULL::text
)
RETURNS void AS
$body$
declare
/*****
pVocabularyPath varchar (1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='vocabulary_load_path');

 Hard coded path when testing. Where is devv5.config$, var_value and how to set devv5.config? I suspect is a 
session variable or from config. 
*****/
 pVocabularyPath varchar (1000) := 'E:/SNOMED_Veterinary_Edition_march_2026/';

  z varchar(100);
begin
  pVocabularyID=UPPER(pVocabularyID);
  pVocabularyPath=pVocabularyPath||pVocabularyID||'/';
  case pVocabularyID

  when 'SNOMED VETERINARY' then
     truncate table sources_vet_sct2_concept_full, sources_vet_sct2_desc_full, sources_vet_sct2_rela_full, sources_vet_der2_crefset_assreffull;
      execute 'COPY sources_vet_sct2_concept_full(id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources_vet_sct2_concept_full set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      execute 'COPY sources_vet_sct2_desc_full FROM '''||pVocabularyPath||'sct2_Description_Full_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources_vet_sct2_rela_full FROM '''||pVocabularyPath||'sct2_Relationship_Full_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources_vet_der2_crefset_assreffull FROM '''||pVocabularyPath||'der2_cRefset_AssociationFull_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    execute 'COPY sources_vet_der2_crefset_language(id,effectiveTime  ,active,moduleId,refsetId,referencedComponentId,acceptabilityId) 
    FROM '''||pVocabularyPath||'der2_cRefset_LanguageFull_en_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    execute 'COPY sources_vet_der2_crefset_attributevalue_full FROM '''||pVocabularyPath||'der2_cRefset_AttributeValueFull_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    execute 'COPY sources_vet_der2_ssRefset_ModuleDependency FROM '''||pVocabularyPath||'der2_ssRefset_ModuleDependencyfull_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources_vet_der2_crefset_language
      set source_file_id = 'VET' 
     where source_file_id is null;
      analyze sources_vet_sct2_concept_full;
      analyze sources_vet_sct2_desc_full;
      analyze sources_vet_sct2_rela_full;
    analyze sources_vet_der2_crefset_assreffull;
    analyze sources_vet_der2_crefset_language;
    analyze sources_vet_der2_crefset_attributevalue_full;
      PERFORM sources_archive.AddVocabularyToArchive('SNOMED Veterinary', 
    ARRAY['vet_sct2_concept_full','vet_sct2_desc_full','vet_sct2_rela_full','vet_der2_crefset_assreffull','vet_der2_crefset_language','vet_der2_crefset_attributevalue_full','vet_der2_ssRefset_ModuleDependency'], 
    COALESCE(pVocabularyDate,current_date), 'archive.snomedvet_version', 10);
  ELSE
      RAISE EXCEPTION 'Vocabulary with id=% not found', pVocabularyID;
  END CASE;
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100;
DO $$
BEGIN
	--column types changed from INT to TEXT [AVOC-4166]
	--fix main source tables
	ALTER TABLE sources.sct2_concept_full_merged ALTER COLUMN id SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_concept_full_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_concept_full_merged ALTER COLUMN statusid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_concept_full_merged ALTER COLUMN active SET DATA TYPE INT2;
	
	ALTER TABLE sources.sct2_desc_full_merged ALTER COLUMN conceptid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_desc_full_merged ALTER COLUMN typeid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_desc_full_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_desc_full_merged ALTER COLUMN id SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_desc_full_merged ALTER COLUMN casesignificanceid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_desc_full_merged ALTER COLUMN active SET DATA TYPE INT2;
	
	ALTER TABLE sources.sct2_rela_full_merged ALTER COLUMN typeid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_rela_full_merged ALTER COLUMN destinationid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_rela_full_merged ALTER COLUMN sourceid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_rela_full_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_rela_full_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources.sct2_rela_full_merged ALTER COLUMN id SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_rela_full_merged ALTER COLUMN characteristictypeid SET DATA TYPE TEXT;
	ALTER TABLE sources.sct2_rela_full_merged ALTER COLUMN modifierid SET DATA TYPE TEXT;
	
	ALTER TABLE sources.der2_crefset_assreffull_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_assreffull_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources.der2_crefset_assreffull_merged ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_assreffull_merged ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_assreffull_merged ALTER COLUMN targetcomponent SET DATA TYPE TEXT;
	
	ALTER TABLE sources.der2_srefset_simplemapfull_int ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_srefset_simplemapfull_int ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources.der2_srefset_simplemapfull_int ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_srefset_simplemapfull_int ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	
	ALTER TABLE sources.der2_crefset_language_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_language_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources.der2_crefset_language_merged ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_language_merged ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_language_merged ALTER COLUMN acceptabilityid SET DATA TYPE TEXT;
	
	ALTER TABLE sources.der2_ssrefset_moduledependency_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_ssrefset_moduledependency_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources.der2_ssrefset_moduledependency_merged ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_ssrefset_moduledependency_merged ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	
	ALTER TABLE sources.der2_iisssccrefset_extendedmapfull_us ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_iisssccrefset_extendedmapfull_us ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources.der2_iisssccrefset_extendedmapfull_us ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_iisssccrefset_extendedmapfull_us ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	
	ALTER TABLE sources.der2_crefset_attributevalue_full_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_attributevalue_full_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources.der2_crefset_attributevalue_full_merged ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_attributevalue_full_merged ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	ALTER TABLE sources.der2_crefset_attributevalue_full_merged ALTER COLUMN valueid SET DATA TYPE TEXT;

	--fix archive tables
	ALTER TABLE sources_archive.sct2_concept_full_merged ALTER COLUMN id SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_concept_full_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_concept_full_merged ALTER COLUMN statusid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_concept_full_merged ALTER COLUMN active SET DATA TYPE INT2;
	
	ALTER TABLE sources_archive.sct2_desc_full_merged ALTER COLUMN conceptid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_desc_full_merged ALTER COLUMN typeid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_desc_full_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_desc_full_merged ALTER COLUMN id SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_desc_full_merged ALTER COLUMN casesignificanceid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_desc_full_merged ALTER COLUMN active SET DATA TYPE INT2;
	
	ALTER TABLE sources_archive.sct2_rela_full_merged ALTER COLUMN typeid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_rela_full_merged ALTER COLUMN destinationid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_rela_full_merged ALTER COLUMN sourceid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_rela_full_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_rela_full_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources_archive.sct2_rela_full_merged ALTER COLUMN id SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_rela_full_merged ALTER COLUMN characteristictypeid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.sct2_rela_full_merged ALTER COLUMN modifierid SET DATA TYPE TEXT;
	
	ALTER TABLE sources_archive.der2_crefset_assreffull_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_assreffull_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources_archive.der2_crefset_assreffull_merged ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_assreffull_merged ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_assreffull_merged ALTER COLUMN targetcomponent SET DATA TYPE TEXT;
	
	ALTER TABLE sources_archive.der2_srefset_simplemapfull_int ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_srefset_simplemapfull_int ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources_archive.der2_srefset_simplemapfull_int ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_srefset_simplemapfull_int ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	
	ALTER TABLE sources_archive.der2_crefset_language_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_language_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources_archive.der2_crefset_language_merged ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_language_merged ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_language_merged ALTER COLUMN acceptabilityid SET DATA TYPE TEXT;
	
	ALTER TABLE sources_archive.der2_ssrefset_moduledependency_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_ssrefset_moduledependency_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources_archive.der2_ssrefset_moduledependency_merged ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_ssrefset_moduledependency_merged ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	
	ALTER TABLE sources_archive.der2_iisssccrefset_extendedmapfull_us ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_iisssccrefset_extendedmapfull_us ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources_archive.der2_iisssccrefset_extendedmapfull_us ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_iisssccrefset_extendedmapfull_us ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	
	ALTER TABLE sources_archive.der2_crefset_attributevalue_full_merged ALTER COLUMN moduleid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_attributevalue_full_merged ALTER COLUMN active SET DATA TYPE INT2;
	ALTER TABLE sources_archive.der2_crefset_attributevalue_full_merged ALTER COLUMN refsetid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_attributevalue_full_merged ALTER COLUMN referencedcomponentid SET DATA TYPE TEXT;
	ALTER TABLE sources_archive.der2_crefset_attributevalue_full_merged ALTER COLUMN valueid SET DATA TYPE TEXT;
END $$;

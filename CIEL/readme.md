# CIEL Vocabulary
Data dictionary avaliable here _data_dictionary_ciel.xlsx_


## Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- RxNorm, ICD10 (WHO), NDFRT, UCUM, LOINC and SNOMED must be loaded first.
- Schema SOURCES

## Source loading

1. Go to folder **_source_load_**
1. Run script _create_source_tables.sql_
2. Run script _additional_functions.sql_ for **API** and **JSON** work
3. Run scripts _load_ciel_concepts.sql_ **and** _load_ciel_mappings.sql_ **and** _load_ciel_source_versions.sql_ **and**  _get_ciel_concept_retired_version.sql_
4. Run script _load_ciel_all.sql_

### To load source us one of the following:

**Full load of latest version**
>SELECT * FROM sources.load_ciel_all \
>  ( \
>  p_token          := 'YOUR_TOKEN', \
>  p_source_version := NULL, \
>  p_clear          := true  \
> );

**Fixed version of CIEL _(now CIEL provides only 10000 concepts via this approach, can be used when they fix on their side)_**
> SELECT * FROM sources.load_ciel_all( \
> p_token          := 'YOUR_TOKEN', \
> p_source_version := 'v2025-10-19', \
> p_clear          := true \
> );

## IN DEVELOPMENT

1. Run create_source_tables.sql
2. Import source files into source tables
   (in DevV5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('CIEL',TO_DATE('20210312','YYYYMMDD'),'OpenMRS 2.11.0 20210312');
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();

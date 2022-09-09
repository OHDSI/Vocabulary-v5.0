1. Download all ClaML files from https://www.dimdi.de/dynamic/de/klassifikationen/downloads/?dir=ops/ for all years
2. Use Python processing script (OPS_convert.py) to extract source files and fill in the source tables. Append resulting tables to ops_src_agg and modifiers_append with version year as last field.
3. Run load_stage.sql; supply automated translations as needed in concept_manual.
4. Input manual tables to include manual translations and mappings to standard vocabularies. Examples for 2020 versions are included on Odysseus GDrive. If you update concept_manual and concept_relationship_manual, upload the latest versions
5. optionally use manual QA tests from specific_QA subdirectory to verify integrity of stage tables
6. Run genericupdate.sql

Manual tables directory permalink:
https://drive.google.com/drive/u/1/folders/1P2dJ9PDMDuu03K-EqzAR8QgmLj72kEB0

TODO:
Update scripts to depend on basic tables to extract dates, so that we need only ClaML files for current year.
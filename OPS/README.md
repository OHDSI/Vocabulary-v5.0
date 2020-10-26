1. Download all ClaML files from https://www.dimdi.de/dynamic/de/klassifikationen/downloads/?dir=ops/ for all years
2. Use Python processing script (OPS_convert.py) to extract source files and fill in the source tables
3. Run load_stage.sql; supply automated translations as needed
4. Input manual tables to include mnaual translations and mappings to standard vocabularies. Examples for 2020 versions are included on Odysseus GDrive. If you update concept_manual and concept_relationship_manual, upload the latest versions
5. optionally use manual QA tests from specific_QA subdirectory to verify integrity of stage tables
6. Run genericupdate.sql
OMOP Genomic Release February 2024

Modify_base_tables.sql
This scripts will modify the concept_class table and the vocabulary table. It also deletes synonyms and concepts we want to delete (rather than deprecate). For the synonyms, the question is whether synonyms should prevail for deprecated concepts or not, and the clause must be altered accordingly. Synonyms for refreshed concepts are deleted, only to be added back in (with modifications) through concept_synonym_stage (see below).

Create_source_tables.sql
There are two sets of tables: for small variants (ending in _small) and for large variants (ending in _large). The latter also contain changes to the gene list. The script loads them from files and does a bunch of further modifications and quality checks, which have to result in an empty table. Some checks are not pass/fail.

The cvs files for the tables are in https://drive.google.com/drive/folders/1IdzegeJoup4auVF4_5KDnK-Hy9jU4atD. The names of the files match the table names. The parameters are:
- Skip header row
- Delimiter = comma
- Quotation = "
- Ignore empty lines (there are quite a few)

Load_stage.sql
This scrip loads into the staging tables (except drug-related ones) from the small and the large source tables. It does further modifications. At the end, it renumbers the concept_codes.

## Manual content preparation

Before running the T1DX load pipeline [load_stage.sql](../load_stage.sql), prepare the manual layer. The load step depends on `concept_manual`, `concept_relationship_manual`, and `concept_synonym_manual`; if these tables do not contain the current T1DX manual content, newly added or corrected concepts, relationships, and synonyms may not be applied during the build.

The T1DX manual CSV files stored on the OHDSI Vocabulary Google Drive are the source of truth for T1DX manual content.

### Processing steps
1. **Update the source CSV files**:

   Apply all required manual changes directly to the T1DX CSV files stored on the OHDSI Vocabulary Google Drive. The CSV files should represent the complete current T1DX manual content, not only incremental changes or deltas.

2. **Import the CSV files into local manual staging tables**:

   Download the following sheets from the T1DX manual content Google Spreadsheet as [CSV files](https://docs.google.com/spreadsheets/d/11nPZuSN7rGScwNUCkE31ljj_HZYe6CxR07PMVm0Czpk/edit?usp=sharing). Then import the downloaded CSV files into the corresponding local manual staging tables:
   - `t1dx_concept_manual`
   - `t1dx_concept_relationship_manual`
   - `t1dx_concept_synonym_manual`

> **CSV format**:
>   - delimiter: ','
>   - encoding: 'UTF8'
>   -  header: ON
>   - decimal symbol: '.'
>   - quote escape: '"'
>   - quote always: TRUE
>   - NULL string: empty

   Use COPY, bulk import, DBeaver/pgAdmin import, or another preferred mechanism.

3. **Run QA on the imported manual content**:

   Execute [manual_tables_qa.sql](../vocab_specific_checks/manual_tables_qa.sql). Review and resolve all issues reported by the QA script before proceeding. This includes, but is not limited to:
   - duplicate concepts, relationships, or synonyms;
   - invalid domain_id, vocabulary_id, or concept_class_id;
   - invalid relationship_id;
   - nresolved relationship endpoints;
   - non-standard or inappropriate mapping targets;
   - invalid dates or invalid status fields.
If issues are found, correct the source CSV files on Google Drive, re-import them locally, and rerun QA.
4. **Populate the OHDSI manual tables**:

   After QA is clean, execute [manual_tables_inserts.sql](manual_tables_inserts.sql). This script replaces the T1DX subset in the destination manual tables with the current content from the staging tables. Non-T1DX base manual content is preserved.

5. **Run the load pipeline**:
   After the manual tables contain the current T1DX content, proceed with [load_stage.sql](../load_stage.sql)

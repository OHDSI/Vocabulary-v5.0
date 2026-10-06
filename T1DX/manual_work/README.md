## Manual content preparation

Before running the T1DX load pipeline [load_stage.sql](../load_stage.sql), prepare the manual layer. The load step depends on `concept_manual`, `concept_relationship_manual`, and `concept_synonym_manual`; if these tables do not contain the current T1DX manual content, newly added or corrected concepts, relationships, and synonyms may not be applied during the build.

The T1DX manual CSV files stored on the OHDSI Vocabulary Google Drive are the source of truth for T1DX manual content.

> **Important**
>
> [manual_tables_inserts.sql](manual_tables_inserts.sql) must be executed in two phases:
>
> 1. create the local staging tables;
> 2. after CSV import and QA, populate the OHDSI manual tables.
>
> Do not rerun the staging-table creation section after importing the CSV files because it drops and recreates the staging tables.

### Processing steps
1. **Update the source CSV files** _(for vocabulary refreshes only; skip this step for the initial build)_:

   Apply all required manual changes directly to the T1DX CSV files stored on the OHDSI Vocabulary Google Drive. The CSV files should represent the complete current T1DX manual content, not only incremental changes or deltas.

2. **Create the local manual staging tables**

   Execute only **Step 1: Create local staging tables** from [manual_tables_inserts.sql](manual_tables_inserts.sql).

   This section drops and recreates the following local staging tables:

   - `t1dx_concept_manual`
   - `t1dx_concept_relationship_manual`
   - `t1dx_concept_synonym_manual`

   Do not execute the destination-table replacement and insertion sections yet.
   
3. **Import the CSV files into the local staging tables**:

   Download the following sheets from the [T1DX manual content Google Spreadsheet](https://docs.google.com/spreadsheets/d/11nPZuSN7rGScwNUCkE31ljj_HZYe6CxR07PMVm0Czpk/edit?usp=sharing) as **CSV files**. Then execute **Step 2** of `manual_tables_inserts.sql` to import the downloaded CSV files into the corresponding tables:
   - `t1dx_concept_manual.csv` → `t1dx_concept_manual`
   - `t1dx_concept_relationship_manual.csv` → `t1dx_concept_relationship_manual`
   - `t1dx_concept_synonym_manual.csv` → `t1dx_concept_synonym_manual`
   
   Use COPY, bulk import, DBeaver/pgAdmin import, or another preferred mechanism.

> **CSV format**:
>   - delimiter: ','
>   - encoding: 'UTF8'
>   -  header: ON
>   - decimal symbol: '.'
>   - quote escape: '"'
>   - quote always: TRUE
>   - NULL string: empty

4. **Run QA on the imported manual content**:

   Execute [manual_tables_qa.sql](../vocab_specific_checks/manual_tables_qa.sql). Review and resolve all issues reported by the QA script before proceeding. This includes, but is not limited to:
   - duplicate concepts, relationships, or synonyms;
   - invalid domain_id, vocabulary_id, or concept_class_id;
   - invalid relationship_id;
   - nresolved relationship endpoints;
   - non-standard or inappropriate mapping targets;
   - invalid dates or invalid status fields.

   If issues are found:
   
   1. correct the source CSV files in Google Drive;
   2. re-import the corrected CSV files into the staging tables;
   3. rerun the QA script.

   Do not proceed until all errors have been resolved and all warnings have been reviewed.

5. **Populate the OHDSI manual tables**:

   After QA is complete, execute **Steps 3-7** of [manual_tables_inserts.sql](manual_tables_inserts.sql), beginning with:

   `Step 3. Replace existing T1DX rows in destination manual tables`

   Do not rerun Step 1 before this operation.

   The population section:

   - deletes the existing T1DX subset from the destination manual tables;
   - inserts the validated current T1DX content from the local staging tables;
   - preserves all non-T1DX content already present in the destination manual tables;
   - refreshes planner statistics for the affected tables.

   The populated destination tables are:

   - `concept_manual`
   - `concept_relationship_manual`
   - `concept_synonym_manual`

5. **Run the load pipeline**:
   After the manual tables contain the current T1DX content, proceed with [load_stage.sql](../load_stage.sql).

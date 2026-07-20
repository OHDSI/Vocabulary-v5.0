# SNOMED Veterinary Extension — Build Procedure

End-to-end procedure for building the SNOMED Veterinary Extension as an OHDSI
vocabulary: download and stage the source files, then run the psql build and QA
pipeline against the `devv5` / `dev_veterinary` schema.

> **Placeholders:** `YYYYMMDD` is the release date, `INT1000009` is the
> Veterinary Extension module identifier, and `VTSzzzzzzz` is the versioned
> release folder name. Replace each with the actual values from your downloads.

---

## Part 1 — Source File Preparation

### 1. Download

Download the **Veterinary Extension** and the **SNOMED International Edition**
on which the Veterinary Extension is based.

### 2. Unzip

Unzip both downloads, then move and rename the files as described below.

### 3. Veterinary Extension files

Copy the Veterinary Extension files from:

```
/path/to/SnomedCT_VETExtension_PRODUCTION_INT1000009_YYYYMMDDT120000Z/
```

into:

```
/path/to/SNOMED Veterinary/
```

and rename each file as follows.

#### From `Full/Terminology`

| Source file | Renamed to |
| --- | --- |
| `sct2_Concept_Full_INT1000009_YYYYMMDD.txt` | `sct2_Concept_Full_VTS.txt` |
| `sct2_Description_Full_en_INT1000009_YYYYMMDD.txt` | `sct2_Description_VTS.txt` |
| `sct2_Relationship_Full_INT1000009_YYYYMMDD.txt` | `sct2_Relationship_VTS.txt` |

#### From `Full/Refset/Language`

| Source file | Renamed to |
| --- | --- |
| `der2_cRefset_LanguageFull_en_INT1000009_YYYYMMDD.txt` | `der2_cRefset_LanguageFull_en_VTS.txt` |

#### From `SnomedCT_Release_VTSzzzzzzz/Full/Refset/Content`

| Source file | Renamed to |
| --- | --- |
| `der2_cRefset_AssociationReferenceFull_INT1000009_YYYYMMDD.txt` | `der2_cRefset_AssociationFull_VTS.txt` |
| `der2_cRefset_AttributeValueFull_INT1000009_YYYYMMDD.txt` | `der2_cRefset_AttributeValueFull_VTS.txt` |

#### From `SnomedCT_Release_VTSzzzzzzz/Full/Refset/Metadata`

| Source file | Renamed to |
| --- | --- |
| `der2_ssRefset_ModuleDependencyfull_INT1000009_YYYYMMDD.txt` | `der2_ssRefset_ModuleDependencyfull_VTS.txt` |

### 4. SNOMED International files

Copy the SNOMED International files from:

```
/path/to/SnomedCT_InternationalRF2_PRODUCTION_YYYYMMDDT120000Z/
```

into:

```
/path/to/SNOMED/
```

and rename each file as follows.

#### From `Full/Terminology`

| Source file | Renamed to |
| --- | --- |
| `sct2_Concept_Full_INT_YYYYMMDD.txt` | `sct2_Concept_Full_INT.txt` |
| `sct2_Description_Full-en_INT_YYYYMMDD.txt` | `sct2_Description_Full-en_INT.txt` |

#### From `Snapshot/Terminology`

| Source file | Renamed to |
| --- | --- |
| `sct2_Relationship_Full_INT_YYYYMMDD.txt` | `sct2_Relationship_Full_INT.txt` |

#### From `Full/Refset/Language`

| Source file | Renamed to |
| --- | --- |
| `der2_cRefset_LanguageFull-en_INT_YYYYMMDD.txt` | `der2_sRefset_LanguageFull_INT.txt` |

#### From `Full/Refset/Content`

| Source file | Renamed to |
| --- | --- |
| `der2_cRefset_AssociationFull_INT_YYYYMMDD.txt` | `der2_cRefset_AssociationFull_INT.txt` |
| `der2_cRefset_AttributeValueFull_INT_YYYYMMDD.txt` | `der2_cRefset_AttributeValueFull_INT.txt` |

#### From `Full/Refset/Metadata`

| Source file | Renamed to |
| --- | --- |
| `der2_ssRefset_ModuleDependencyFull_INT_YYYYMMDD.txt` | `der2_ssRefset_ModuleDependencyFull_INT.txt` |

> **Note on target names:** A few renamed targets are inconsistent with the
> usual convention and are reproduced exactly as given — verify them against
> what `load_stage_VETERINARY.sql` expects before running the build:
> - `der2_ssRefset_ModuleDependencyfull_VTS.txt` uses lowercase `full`,
>   whereas the International side uses `Full`.
> - `der2_sRefset_LanguageFull_INT.txt` uses the `sRefset` prefix rather than
>   `cRefset`.

---

## Part 2 — Build Pipeline

Run the following in `psql`, in order. The `\i` meta-command runs a SQL script
file; `\o` redirects query output to a file (and `\o` with no argument restores
output to the terminal).

### 5. Recreate the working schema

```sql
SELECT devv5.FastRecreateSchema(
    main_schema_name  => 'devv5',
    include_concept_ancestor => true,
    include_deprecated_rels  => true,
    include_synonyms         => true
);
```

### 6. Add the `AddPeaks` function

Add the `AddPeaks` function if it is not already available.

```sql
\i AddPeaks.sql
```

### 7. Create source tables

```sql
\i create_source_tables.sql
```

### 8. Load input tables

Loads the Veterinary Extension, then loads SNOMED International into the
`sources_*` tables.

```sql
\i sources_load_input_tables.sql
```

### 9. Update the vocabulary version

Updates the vocabulary version of SNOMED Veterinary.

```sql
\i update_vocabulary.sql
```

### 10. Load staging tables and run the generic update

```sql
\i load_stage_VETERINARY.sql      -- Load the staging tables
SELECT devv5.GenericUpdate();
```

### 11. Run the check suite

```sql
SELECT * FROM qa_tests.get_checks();
```

> Should return **0 rows**.

### 12. Run QA scripts, output to file, and interpret the results

```sql
\o get_summary_concept_devv5.txt
SELECT DISTINCT * FROM qa_tests.get_summary('concept', 'devv5');
\o

\o get_summary_concept_relationship_devv5.txt
SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship', 'devv5');
\o

\o qa_tests_get_domain_changes.txt
SELECT DISTINCT * FROM qa_tests.get_domain_changes('devv5');
\o

\o qa_tests_get_newly_concepts.txt
SELECT DISTINCT * FROM qa_tests.get_newly_concepts('devv5');
\o

\o qa_tests_get_standard_concept_changes.txt
SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes('devv5');
\o

\o qa_tests_get_newly_concepts_standard_concept_status.txt
SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status('devv5');
\o

\o qa_tests_get_changes_concept_mapping.txt
SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping('devv5');
\o

\o manual_checks_after_generic_update.txt
\i manual_checks_after_generic_update.sql
\o
```

### 13. Extract veterinary synonyms added to SNOMED core

```sql
\i Extract_vet_synonyms_to_SNOMED_core.sql
```

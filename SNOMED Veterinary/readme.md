# SNOMED Veterinary Extension — Build Procedure

End-to-end procedure for building the SNOMED Veterinary Extension as an OHDSI
vocabulary: download and stage the source files, then run the psql build and QA
pipeline against the `devv5` / `dev_veterinary` schema.

Prerequisites:
* Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
* Working directory SNOMED Veterinary.
* SNOMED must be updated in 'devv5' first.

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
### 6. Create SNOMED Veteriary Edition
Open each SNOMED Veterinary files and remove the header. 
```
Copy sct2_Concept_Full_INT_YYYYMMDD.txt  + sct2_Concept_Full_YYYYMMDD.txt  sct2_Concept_Full_VTS.txt 
```
Copy sct2_Description_Full-en_INT_20250201.txt + sct2_Description_Full_en_VTS_20250930.txt sct2_Description_Full_VTS.txt 

Copy sct2_Relationship_Full_INT_20250201.txt +  

sct2_Relationship_Full_VTS_20250930.txt sct2_Relationship_Full_VTS.txt 

Copy der2_cRefset_AssociationFull_INT_20250201.txt +  

der2_cRefset_AssociationReferenceFull_VTS_20250930.txt der2_cRefset_AssociationFull_VTS.txt 

Copy der2_cRefset_AttributeValueFull_INT_20250201.txt + 

 der2_cRefset_AttributeValueFull_VTS_20250930.txt  der2_cRefset_AttributeValueFull_VTS.txt 

Copy der2_cRefset_LanguageFull-en_INT_20250201.txt + der2_cRefset_LanguageFull_en_VTS_20250930.txt der2_sRefset_LanguageFull_en_VTS.txt 

Copy der2_ssRefset_ModuleDependencyFull_INT_20250201.txt +  

der2_ssRefset_ModuleDependencyfull_VTS_20250930.txt der2_ssRefset_ModuleDependencyfull_VTS.txt 
### 5. Create source tables
[create_source_tables.sql](create_source_tables.sql)

### 6. Load input tables
Loads the Veterinary Extension, then loads SNOMED International into the `sources_*` tables.
[sources_load_input_tables.sql](sources_load_input_tables.sql)

## Part 2 — Build Pipeline

### 7. Recreate the working schema

```sql
SELECT devv5.FastRecreateSchema(
    main_schema_name  => 'devv5',
    include_concept_ancestor => true,
    include_deprecated_rels  => true,
    include_synonyms         => true
);
```

### 8. Create or update the `AddPeaks` function if necessary
[AddPeaks.sql](../SNOMED/AddPeaks.sql)

### 9. Make any necessary changes to the manual tables

### 10. Load staging tables
[load_stage.sql](load_stage.sql)

### 11. Run GenericUpdate
   ```sql
   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
```

### 12. Run the check suite (should return null)
```sql
SELECT * FROM qa_tests.get_checks();
```

### 13. Run QA scripts and interpret the results
```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship');
    SELECT DISTINCT * FROM qa_tests.get_domain_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
   ```

### 14. Run checks for manual review:
[manual_checks_after_generic_update.sql](../working/manual_checks_after_generic_update.sql)

### 15. Extract veterinary synonyms added to SNOMED core
[Extract_vet_synonyms_to_SNOMED_core.sql](Extract_vet_synonyms_to_SNOMED_core.sql)

### STEP 1 of the ATC refresh/deployment: work with manual tables
* run *create_manual_tables.sql*
* extract the [respective сsv files](https://drive.google.com/drive/u/0/folders/1RwWqj3mgP9CdEt56dIA2aLI1EzCczrBP) into newly created tables.

* extract the [respective сsv file](https://docs.google.com/spreadsheets/d/1aUWrP4lQLFA27VAt86NsbzfhnQ9BkJN5CMsj2ra_LSo/edit?gid=1629777695#gid=1629777695) into the *new_atc_codes_ings_for_manual* table. The file was generated using the query:
```sql
SELECT
    source,
    class_code,
    class_name,
    relationship_id,
    ids,
    names
FROM new_atc_codes_ings_for_manual
```

* extract the [respective сsv file](https://docs.google.com/spreadsheets/d/1vnvT0dakOxcVseP2yj81dHhPHkklNCoLdcdvodQxwF0/edit?gid=795496822#gid=795496822) into the *bdpm_atc_codes* table. The file was generated using the query:
```sql
SELECT 
       id,
       atc_code
FROM bdpm_atc_codes;
```

* extract the [respective сsv file](https://drive.google.com/drive/u/0/folders/1RwWqj3mgP9CdEt56dIA2aLI1EzCczrBP) into the *norske_result* table. The file was generated using the query:
```sql
SELECT
    concept_id,
    concept_name,
    form,
    atc_code,
    atc_name,
    rx_ids,
    rx_names
FROM norske_result;
```

* extract the [respective сsv file](https://drive.google.com/file/d/1v0LIAdBCAIZrf81gtGfRQZEysakNE1Ja/view?usp=drive_link) into the *kdc_atc* table. The file was generated using the query:
```sql
SELECT
    concept_code,
    concept_code_2,
    vocabulary_id,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
FROM kdc_atc;
```

* extract the [respective сsv file](https://drive.google.com/file/d/1cLRKh3HpJJ917mcMaUUTJbHqh7B6t_Am/view?usp=drive_link) into the *atc_rxnorm_to_drop_in_sources* table. The file was generated using the query:
```sql
SELECT
    concept_id_atc,
    concept_code_atc,
    concept_name,
    drop,
    concept_id_rx,
    concept_name_rx
FROM atc_rxnorm_to_drop_in_sources;
```

* extract the [respective сsv file](https://drive.google.com/file/d/1BIlGZiFtr1W-tyj-cnLXq4f2s9DIZVfn/view?usp=drive_link) into the *existent_atc_rxnorm_to_drop* table. The file was generated using the query:
```sql
SELECT
    atc_code,
    atc_name,
    root,
    concept_id,
    to_drop,
    concept_name,
    to_check
FROM existent_atc_rxnorm_to_drop;
```
* extract the [respective сsv file](https://drive.google.com/drive/u/0/folders/1RwWqj3mgP9CdEt56dIA2aLI1EzCczrBP) into the *covid19_atc_rxnorm_manual* table. The file was generated using the query:
```sql
SELECT
    concept_code_atc,
    to_drop,
    concept_id,
    concept_name
FROM covid19_atc_rxnorm_manual;
```
* extract the [respective сsv file](https://drive.google.com/file/d/1AvzKNjcq_XUr40rH0FCHnuVrVJ0aS6RW/view?usp=drive_link) into the *gcs_manual_curated* table. The file was generated using the query:
```sql
SELECT
    concept_id,
    concept_name,
    vocabulary_id,
    ings,
    string_agg,
    atc_code
FROM gcs_manual_curated;
```
* extract the [respective сsv file](https://drive.google.com/file/d/1EJslT3HQMroaDj-aMeZ9Ksc3NOCBt5di/view?usp=drive_link) into the *ned_adm_r* table. The file was generated using the query:
```sql
SELECT 
    source_code_atc,
    source_code_rx
FROM drop_maps_to
```

#### csv format:
- delimiter: '\t'
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty
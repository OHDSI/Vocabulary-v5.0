### STEP 1 of the ATC refresh/deployment: work with manual tables
* run *create_manual_tables.sql*
* extract the [respective tsv files](https://drive.google.com/drive/u/0/folders/1RwWqj3mgP9CdEt56dIA2aLI1EzCczrBP) into newly created tables.

* extract the [respective tsv file](https://drive.google.com/file/d/1qZTvHquYpDg2FKpXF_Aoht8ne0ty7Cod/view?usp=drive_link) into the *ned_adm_r* table. The file was generated using the query:
```sql
SELECT class_code,
       class_name,
       old,
       new
FROM new_adm_r
```
* extract the [respective tsv file](https://drive.google.com/file/d/1D0P-Fd2DKam9Xs8nyUwzNrSBVWcJ7TwO/view?usp=drive_link) into the *new_atc_codes_ings_for_manual* table. The file was generated using the query:
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
* extract the [respective tsv file](https://drive.google.com/file/d/1HF944a-_jZdlPsSu8lF1C102bri7TANf/view?usp=drive_link) into the *existent_atc_rxnorm_to_drop* table. The file was generated using the query:
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

* extract the [respective tsv file](https://drive.google.com/file/d/1Jg66E71VUQlCF-jArg0ag3izrN2Tshsd/view?usp=drive_link) into the *bdpm_atc_codes* table. The file was generated using the query:
```sql
SELECT id,
       atc_code
FROM bdpm_atc_codes;
```

* extract the [respective tsv file](https://drive.google.com/file/d/1b9GpMVF6nVdqTaHRVqngL4oS9lrln3Py/view?usp=drive_link) into the *norske_result* table. The file was generated using the query:
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
* extract the [respective tsv file](https://drive.google.com/file/d/1_QOGi9foXuo6EWX3HWKDl_fwfSdQFzAF/view?usp=drive_link) into the *zindex_full* table. The file was generated using the query:
```sql
SELECT
    atc,
    targetid
FROM zindex_full;
```

* extract the [respective tsv file](https://drive.google.com/file/d/1TRjgoZ5bownwhsPajrmyxIm7DqOLjYkQ/view?usp=drive_link) into the *atc_rxnorm_to_drop_in_sources* table. The file was generated using the query:
```sql
SELECT
    concept_id_atc,
    concept_code_atc,
    concept_name,
    source,
    concept_id_rx,
    concept_name_rx
FROM atc_rxnorm_to_drop_in_sources;
```

#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty
Update of OncoTree

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory OncoTree.

1. Run create_source_tables.sql
2. Get concepts tree from http://oncotree.mskcc.org/api/tumorTypes/tree and load into sources.oncotree_tree.
We use this script:
```sql
with recursive jsondata(key, value, a_name, parent, d_name, lv) AS (
  SELECT
    je.key,
    je.value->'children' as value,
    null as a_name,
    je.value ->> 'parent' as parent,
    je.value ->> 'name' as d_name,
    1 as lv
  FROM (select http_content::json as data from vocabulary_download.py_http_get(url=>'http://oncotree.mskcc.org/api/tumorTypes/tree')) j
  cross join json_each(j.data) AS je

  UNION ALL

  SELECT
    je.key,
    je.value->'children' as value,
    j.d_name as a_name,
    je.value ->> 'parent' as parent,
    je.value ->> 'name' || case when j.lv<=1 then '' else ' ('||je.key||')' end as d_name,
    j.lv+1 as lv
  FROM jsondata j
  cross join json_each (j.value) as je
)
SELECT j.parent as ancestor_code, j.a_name as ancestor_name,
j.key as descendant_code,
j.d_name as descendant_name
FROM jsondata j;
```
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();

PS The manual files are available here: https://drive.google.com/drive/u/1/folders/1_-Hi-O1LNP1NehR560lZ9MUMBHdHpNko

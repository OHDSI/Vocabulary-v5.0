### DA France Refresh Process ###

#### Prerequisites ####
* Basic knowledge of the custom vocabulary refresh
* Schema devV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
* Working directory, e.g. *dev_da_france_2* (and there is no '_1', do not ask why)
* FULL fastRecreate
```sql
   SELECT devv5.FastRecreateSchema(include_concept_ancestor=>true,include_deprecated_rels=>true,include_synonyms=>true)
``` 
#### Sequence of actions:####
1. Download source files (e.g. da_france_source)
2. Run create_source_tables.sql
3. Prepare worktable
4. Assemble a table for manual mapping containing vaccines and insulins
5. Run load_input.sql
6. Run Build_RxE.sql and MapDrug.sql
7. Run post_processing
8. Run load_stage (to add!) -- Dima's TASK
9. Perform standard QA

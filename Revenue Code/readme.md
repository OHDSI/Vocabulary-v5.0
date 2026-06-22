Update of Revenue Code

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory Revenue Code.

1. Get new source from https://drive.google.com/drive/u/1/folders/13vk0EE-pUxKZCyaB0ZU19TP5UbWdMbMi
2. Run manual_work/preparing_the_source.sql
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();
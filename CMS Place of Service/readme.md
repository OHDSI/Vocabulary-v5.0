Update of CMS Place of Service

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory CMS Place of Service.

1. Get new source from https://drive.google.com/drive/u/1/folders/1MG_XoVCylyiUs0zV6IqtEpCiEdmT0wWc
2. Run manual_work/preparing_the_source.sql
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();
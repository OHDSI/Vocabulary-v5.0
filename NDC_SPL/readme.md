Update of NDC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- RxNorm must be loaded first
- Working directory NDC.

1. Run create_source_tables.sql
2. Download NDC code distrbution file
Open the site http://www.fda.gov/Drugs/InformationOnDrugs/ucm142438.htm
- Download the latest NDC Database File.
- Extract the product.txt file.

4. Load product.txt into PRODUCT using control file of the same name
5. Run load_stage.sql
6. Run generic_update.sql (from working directory)

 
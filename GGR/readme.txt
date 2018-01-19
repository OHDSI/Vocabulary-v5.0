GGR readme upload / update of GGR

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_ggr.

1.Upload source tables from http://www.bcfi.be/nl/download (CSV NL or SQL NL)
Extract exportNl.sql and run the queries inside

Source provides data as complete SQL querry in ZIP archive. Source Tables needed to be uploaded in the schema: IR, MP, MPP, SAM, GAL, INNM (STOF).

2. Run auto_init.sql. 
Note: BN, Ingredients: lowercase 'n' in mapped_name suggests using concept_name instead. Lowercase 'g' in mapped_name indicates that concept should not be mapped. Brand Names with in correct Suppliers must be deleted manually at this stage.

3. Give tables tomap_unit, tomap_form, tomap_supplier, tomap_bn, tomap_ingred to Medical Coder.
Reupload all tomap_* tables. 

4. Run after_mm.sql
Give table dsfix to Medical Coder.
Note: Place 'D' in Device field for products, that should be marked as Devices
Upload dsfix.csv and run fixes.sql

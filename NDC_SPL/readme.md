Update of NDC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- RxNorm must be loaded first
- Working directory NDC.
- Create package ApiGrabber using apigrabber.sql

1. Run create_source_tables.sql
2. Download NDC code distrbution file
Open the site http://www.fda.gov/Drugs/InformationOnDrugs/ucm142438.htm
- Download the latest NDC Database File.
- Extract the product.txt file.

4. Load product.txt into PRODUCT using control file of the same name
5. Download additional source for SPL concepts and relationships from http://dailymed.nlm.nih.gov/dailymed/spl-resources-all-drug-labels.cfm and http://dailymed.nlm.nih.gov/dailymed/spl-resources-all-mapping-files.cfm
- Full Releases of HUMAN PRESCRIPTION LABELS, HUMAN OTC LABELS, HOMEOPATHIC LABELS and REMAINDER LABELS (1st link)
- SPL-RXNORM MAPPINGS (2d link)
6. Extract LABELS using unzipxml.sh and load xml files using loadxml.ctl
7. Extract rxnorm_mappings.zip and load rxnorm_mappings.txt using rxnorm_mappings.ctl
8. Run parse_XML.sql
9. Run load_stage.sql
10. Run generic_update.sql (from working directory)
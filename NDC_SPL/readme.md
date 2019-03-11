Update of NDC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- RxNorm must be loaded first
- Working directory NDC.
- Created schema ApiGrabber (\working\packages\APIgrabber). You must execute all functions in ApiGrabber at least once

1. Run create_source_tables.sql
2. Download NDC code distrbution file
Open the site http://www.fda.gov/Drugs/InformationOnDrugs/ucm142438.htm
- Download the latest NDC Database File
- Extract product.txt and package.txt files
3. Download additional source for SPL concepts and relationships from https://dailymed.nlm.nih.gov/dailymed/spl-resources-all-drug-labels.cfm and https://dailymed.nlm.nih.gov/dailymed/spl-resources-all-mapping-files.cfm
- Full Releases of HUMAN PRESCRIPTION LABELS, HUMAN OTC LABELS, HOMEOPATHIC LABELS and REMAINDER LABELS (1st link)
- SPL-RXNORM MAPPINGS (2d link)
4. Extract LABELS using unzipxml.sh
5. Extract rxnorm_mappings.txt from rxnorm_mappings.zip
6. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('NDC_SPL',TO_DATE('20180420','YYYYMMDD'),'NDC 20180420');
7. Run load_stage.sql
8. Run generic_update: devv5.GenericUpdate();
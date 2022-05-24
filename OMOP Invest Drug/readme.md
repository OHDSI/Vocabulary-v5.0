## Update of OMOP Investigational Drugs

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed
- UMLS, RxNorm/E, ATC must be loaded first
- Working directory OMOP Invest drug

1. Run create_source_tables.sql
2. Download Antineoplastic_Agent.txt from https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Drug_or_Substance/Antineoplastic_Agent.txt and rename to antineoplastic_agent.txt
3. Download the latest NCIT_PharmSub_XX.YYe_YYYYMMDD.xlsx from https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Branches/ and rename to ncit_pharmsub.xlsx
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('OMOP Invest drug',TO_DATE('20220131','YYYYMMDD'),'22.01e');
5. Run load_stage.sql
6. Run generic_update: devv5.GenericUpdate();

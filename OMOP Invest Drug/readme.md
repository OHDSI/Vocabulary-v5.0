## Update of OMOP Investigational Drugs

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed
- UMLS, RxNorm/E, ATC must be loaded first
- Working directory OMOP Invest Drug

1. Run create_source_tables.sql
2. Download Antineoplastic_Agent.txt from https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Drug_or_Substance/Antineoplastic_Agent.txt and rename to antineoplastic_agent.txt
3. Download the latest NCIT_PharmSub_XX.YYe_YYYYMMDD.xlsx from https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Branches/ and rename to ncit_pharmsub.xlsx
4. Download dump-public-YYYY-MM-DD.gsrs from https://gsrs.ncats.nih.gov/#/release and rename to dump-public.gsrs
5. Run in devv5 (with fresh vocabulary date from dump-public.gsrs): SELECT sources.load_input_tables('OMOP Invest Drug',TO_DATE('20220512','YYYYMMDD'),'OMOP Invest Drug version 2022-05-12');
6. Run load_stage.sql
7. Run generic_update: devv5.GenericUpdate();
CREATE TABLE RXXXREF
(
   external_source           VARCHAR2 (10),
   external_source_code      VARCHAR2 (30),
   concept_type_id           NUMBER,
   concept_value             VARCHAR2 (20),
   transaction_cd            VARCHAR2 (1),
   match_type                VARCHAR2 (2),
   umls_concept_identifier   VARCHAR2 (12),
   rxnorm_code               VARCHAR2 (10),
   reserve                   VARCHAR2 (22)
);

CREATE TABLE GPI_NAME
(
  GPI_CODE     VARCHAR2(100 BYTE),
  DRUG_STRING  VARCHAR2(100 BYTE)
);
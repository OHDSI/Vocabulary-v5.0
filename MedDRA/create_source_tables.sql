CREATE TABLE hlgt_pref_term
(
   hlgt_code          NUMBER,
   hlgt_name          VARCHAR2 (100),
   hlgt_whoart_code   VARCHAR2 (100),
   hlgt_harts_code    NUMBER,
   hlgt_costart_sym   VARCHAR2 (100),
   hlgt_icd9_code     VARCHAR2 (100),
   hlgt_icd9cm_code   VARCHAR2 (100),
   hlgt_icd10_code    VARCHAR2 (100),
   hlgt_jart_code     VARCHAR2 (100)
);

CREATE TABLE hlgt_hlt_comp
(
   hlgt_code   NUMBER,
   hlt_code    NUMBER
);

CREATE TABLE hlt_pref_term
(
   hlt_code          NUMBER,
   hlt_name          VARCHAR2 (100),
   hlt_whoart_code   VARCHAR2 (100),
   hlt_harts_code    NUMBER,
   hlt_costart_sym   VARCHAR2 (100),
   hlt_icd9_code     VARCHAR2 (100),
   hlt_icd9cm_code   VARCHAR2 (100),
   hlt_icd10_code    VARCHAR2 (100),
   hlt_jart_code     VARCHAR2 (100)
);

CREATE TABLE hlt_pref_comp
(
   hlt_code   NUMBER,
   pt_code    NUMBER
);

CREATE TABLE soc_intl_order
(
   intl_ord_code   NUMBER,
   soc_code        NUMBER
);

CREATE TABLE low_level_term
(
   llt_code          NUMBER,
   llt_name          VARCHAR2 (100),
   pt_code           NUMBER,
   llt_whoart_code   VARCHAR2 (100),
   llt_harts_code    NUMBER,
   llt_costart_sym   VARCHAR2 (100),
   llt_icd9_code     VARCHAR2 (100),
   llt_icd9cm_code   VARCHAR2 (100),
   llt_icd10_code    VARCHAR2 (100),
   llt_currency      VARCHAR2 (100),
   llt_jart_code     VARCHAR2 (100)
);

CREATE TABLE md_hierarchy
(
   pt_code          NUMBER,
   hlt_code         NUMBER,
   hlgt_code        NUMBER,
   soc_code         NUMBER,
   pt_name          VARCHAR2 (100),
   hlt_name         VARCHAR2 (100),
   hlgt_name        VARCHAR2 (100),
   soc_name         VARCHAR2 (100),
   soc_abbrev       VARCHAR2 (100),
   null_field       VARCHAR2 (100),
   pt_soc_code      NUMBER,
   primary_soc_fg   VARCHAR2 (100)
);

CREATE TABLE pref_term
(
   pt_code          NUMBER,
   pt_name          VARCHAR2 (100),
   null_field       VARCHAR2 (100),
   pt_soc_code      NUMBER,
   pt_whoart_code   VARCHAR2 (100),
   pt_harts_code    NUMBER,
   pt_costart_sym   VARCHAR2 (100),
   pt_icd9_code     VARCHAR2 (100),
   pt_icd9cm_code   VARCHAR2 (100),
   pt_icd10_code    VARCHAR2 (100),
   pt_jart_code     VARCHAR2 (100)
);

CREATE TABLE smq_content
(
   SMQ_code                     NUMBER,
   Term_code                    NUMBER,
   Term_level                   NUMBER,
   Term_scope                   NUMBER,
   Term_category                VARCHAR2 (100),
   Term_weight                  NUMBER,
   Term_status                  VARCHAR2 (100),
   Term_addition_version        VARCHAR2 (100),
   Term_last_modified_version   VARCHAR2 (100)
);

CREATE TABLE smq_list
(
   SMQ_code          NUMBER,
   SMQ_name          VARCHAR2 (100),
   SMQ_level         NUMBER,
   SMQ_description   VARCHAR2 (2000),
   SMQ_source        VARCHAR2 (2000),
   SMQ_note          VARCHAR2 (2000),
   MedDRA_version    VARCHAR2 (100),
   Status            VARCHAR2 (100),
   SMQ_Algorithm     VARCHAR2 (100)
);

CREATE TABLE soc_term
(
   soc_code          NUMBER,
   soc_name          VARCHAR2 (100),
   soc_abbrev        VARCHAR2 (100),
   soc_whoart_code   VARCHAR2 (100),
   soc_harts_code    NUMBER,
   soc_costart_sym   VARCHAR2 (100),
   soc_icd9_code     VARCHAR2 (100),
   soc_icd9cm_code   VARCHAR2 (100),
   soc_icd10_code    VARCHAR2 (100),
   soc_jart_code     VARCHAR2 (100)
);

CREATE TABLE soc_hlgt_comp
(
   soc_code    NUMBER,
   hlgt_code   NUMBER
);
/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.GPI_NAME;
CREATE TABLE SOURCES.GPI_NAME
(
  gpi_code           VARCHAR (100),
  drug_string        VARCHAR (100),
  vocabulary_date    DATE,
  vocabulary_version VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.NDW_V_PRODUCT;
CREATE TABLE SOURCES.NDW_V_PRODUCT
(
  product_id                    INT4,
  ndc                           VARCHAR (500),
  cmf_ppk_nbr                   VARCHAR (1000),
  cmf_prod_nbr                  VARCHAR (1000),
  cmf_pack_nbr                  VARCHAR (1000),
  mkted_prod_formltn_nm         VARCHAR (500),
  mkted_prod_formltn_short_nm   VARCHAR (1000),
  mkted_prod_detl_nm            VARCHAR (500),
  mkted_prod_typ_cd             VARCHAR (1000),
  mkted_prod_nm                 VARCHAR (1000),
  pack_label_nm                 VARCHAR (1000),
  unifm_prod_nm                 VARCHAR (1000),
  dosage_form_cd                VARCHAR (1000),
  dosage_form_nm                VARCHAR (1000),
  strnt_desc                    VARCHAR (1000),
  strnt_value_nbr               VARCHAR (1000),
  strnt_uom_cd                  VARCHAR (1000),
  pack_qty                      VARCHAR (1000),
  pack_qty_uom_cd               VARCHAR (1000),
  pack_size_nbr                 VARCHAR (1000),
  pack_size_uom_cd              VARCHAR (1000),
  total_pack_qty                VARCHAR (1000),
  route_adm_cd                  VARCHAR (1000),
  route_adm_nm                  VARCHAR (1000),
  glbl_route_form_cd            VARCHAR (1000),
  upc                           VARCHAR (1000),
  hcpcs_cd                      VARCHAR (1000),
  hcpcs_desc                    VARCHAR (1000),
  dea_clas_cd                   VARCHAR (1000),
  dea_clas_desc                 VARCHAR (1000),
  otc_ind                       VARCHAR (1000),
  spcl_prod_ind                 VARCHAR (1000),
  cmbn_drug_ind                 VARCHAR (1000),
  origintr_prod_ind             VARCHAR (1000),
  repack_ind                    VARCHAR (1000),
  patn_status_ind               VARCHAR (1000),
  unit_typ_id                   VARCHAR (1000),
  multi_src_cd                  VARCHAR (1000),
  multi_src_nm                  VARCHAR (1000),
  lbler_nm                      VARCHAR (1000),
  lbler_typ_cd                  VARCHAR (1000),
  lbler_corp_nm                 VARCHAR (1000),
  mkted_prod_formltn_lnch_dt    DATE,
  tpty_recv_add_dt              DATE,
  obsolete_dt                   DATE,
  act_ind                       VARCHAR (1000),
  usc_cd                        VARCHAR (1000),
  usc_desc                      VARCHAR (1000),
  usc_lvl4_cd                   VARCHAR (1000),
  usc_lvl4_desc                 VARCHAR (1000),
  usc_lvl3_cd                   VARCHAR (1000),
  usc_lvl3_desc                 VARCHAR (1000),
  usc_lvl2_cd                   VARCHAR (1000),
  usc_lvl2_desc                 VARCHAR (1000),
  gpi                           VARCHAR (500),
  gpi_desc                      VARCHAR (500),
  gpi10_cd                      VARCHAR (1000),
  gpi10_desc                    VARCHAR (1000),
  gpi6_cd                       VARCHAR (1000),
  gpi6_desc                     VARCHAR (1000),
  gpi4_cd                       VARCHAR (1000),
  gpi4_desc                     VARCHAR (1000),
  gpi2_cd                       VARCHAR (1000),
  gpi2_desc                     VARCHAR (1000),
  gpi_thptc_clas_id             VARCHAR (1000),
  gpi_thptc_clas_desc           VARCHAR (1000),
  generic_thptc_clas_id         VARCHAR (1000),
  generic_thptc_clas_desc       VARCHAR (1000),
  ahfs_cd                       VARCHAR (1000),
  ahfs_desc                     VARCHAR (1000),
  thptc_clas_id                 VARCHAR (1000),
  thptc_clas_desc               VARCHAR (1000),
  cmf_mkted_prod_nm             VARCHAR (1000),
  cmf_usc_cd                    VARCHAR (1000)
);
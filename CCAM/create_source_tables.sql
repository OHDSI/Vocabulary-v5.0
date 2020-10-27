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
* Authors: Authors: Dmitry Dymshyts, Timur Vakhitov
* Date: 2020
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.CCAM_R_ACTE;
CREATE TABLE SOURCES.CCAM_R_ACTE (
  COD_ACTE    VARCHAR(13),
  DT_MODIF    DATE,
  MENU_COD    INT2,
  FRAIDP_COD  VARCHAR(1),
  REMBOU_COD  INT2,
  TYPE_COD    INT2,
  COD_STRUCT  VARCHAR(13),
  NOM_COURT   VARCHAR(4000),
  NOM_LONG    VARCHAR(4000),
  NOM_LONG0   VARCHAR(4000),
  NOM_LONG1   VARCHAR(4000),
  NOM_LONG2   VARCHAR(4000),
  NOM_LONG3   VARCHAR(4000),
  NOM_LONG4   VARCHAR(4000),
  NOM_LONG5   VARCHAR(4000),
  NOM_LONG6   VARCHAR(4000),
  NOM_LONG7   VARCHAR(4000),
  NOM_LONG8   VARCHAR(4000),
  NOM_LONG9   VARCHAR(4000),
  NOM_LONGA   VARCHAR(4000),
  NOM_LONGB   VARCHAR(4000),
  NOM_LONGC   VARCHAR(4000),
  NOM_LONGD   VARCHAR(4000),
  NOM_LONGE   VARCHAR(4000),
  SEXE        INT2,
  DT_CREATIO  DATE,
  DT_FIN      DATE,
  ENTENTE     VARCHAR(1),
  DT_EFFET    DATE,
  DT_ARRETE   DATE,
  DT_JO       DATE,
  MFIC_PLACE  INT2,
  PRECEDENT   VARCHAR(13),
  SUIVANT     VARCHAR(13)
);

DROP TABLE IF EXISTS SOURCES.CCAM_R_MENU;
CREATE TABLE SOURCES.CCAM_R_MENU (
  COD_MENU            INT2,
  RANG                INT2,
  LIBELLE             VARCHAR(254),
  COD_PERE            INT2,
  VOCABULARY_DATE     DATE,
  VOCABULARY_VERSION  VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.CCAM_R_ACTE_IVITE;
CREATE TABLE SOURCES.CCAM_R_ACTE_IVITE (
  COD_AA      VARCHAR(14),
  DT_MODIF    DATE,
  ACTE_COD    VARCHAR(13),
  ACDT_MODIF  DATE,
  ACTIV_COD   INT2,
  REGROU_COD  VARCHAR(3),
  CATMED_COD  VARCHAR(2)
);

DROP TABLE IF EXISTS SOURCES.CCAM_R_REGROUPEMENT;
CREATE TABLE SOURCES.CCAM_R_REGROUPEMENT (
  COD_REGROU  VARCHAR(3),
  LIBELLE     VARCHAR(100)
);

CREATE INDEX idx_ccam_r_acte ON sources.ccam_r_acte(menu_cod);
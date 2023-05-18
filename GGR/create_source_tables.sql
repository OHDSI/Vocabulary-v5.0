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
* Authors: Eduard Korchmar, Timur Vakhitov
* Date: 2017
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.GGR_GAL;
CREATE TABLE SOURCES.GGR_GAL
(
    galcv    VARCHAR (255) NOT NULL,
    ngalnm   VARCHAR (255),
    fgalnm   VARCHAR (255),
    amb      bool,
    hosp     bool
);

DROP TABLE IF EXISTS SOURCES.GGR_INNM;
CREATE TABLE SOURCES.GGR_INNM
(
    stofcv      VARCHAR (255) NOT NULL,
    ninnm       VARCHAR (255),
    finnm       VARCHAR (255),
    nbase       VARCHAR (255),
    ninnmx      VARCHAR (255),
    nsaltestr   VARCHAR (255),
    fbase       VARCHAR (255),
    finnmx      VARCHAR (255),
    fsaltestr   VARCHAR (255),
    amb         bool,
    hosp        bool
);

DROP TABLE IF EXISTS SOURCES.GGR_IR;
CREATE TABLE SOURCES.GGR_IR
(
    ircv               VARCHAR (255) NOT NULL,
    nirnm              VARCHAR (255) NOT NULL,
    firnm              VARCHAR (255) NOT NULL,
    pip                bool,
    amb                bool,
    hosp               bool,
    vocabulary_date    DATE,
    vocabulary_version VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.GGR_MP;
CREATE TABLE SOURCES.GGR_MP
(
    mpcv        VARCHAR (255) NOT NULL,
    hyrcv       VARCHAR (255) NOT NULL,
    hyr_        VARCHAR (255),
    mpnm        VARCHAR (255),
    ircv        VARCHAR (255) NOT NULL,
    bt          bool,
    note        text,
    pos         text,
    wadan       VARCHAR (255),
    wadaf       VARCHAR (255),
    "rank"      int4,
    nmcv        VARCHAR (255),
    orphan      bool NOT NULL,
    specrules   bool NOT NULL,
    narcotic    bool NOT NULL,
    amb         bool,
    hosp        bool
);

DROP TABLE IF EXISTS SOURCES.GGR_MPP;
CREATE TABLE SOURCES.GGR_MPP
(
    mppcv       VARCHAR (255) NOT NULL,
    hyr_        VARCHAR (255),
    hyrcv       VARCHAR (255) NOT NULL,
    ogc         VARCHAR (255),
    mpcv        VARCHAR (255) NOT NULL,
    ouc         CHAR (1) NOT NULL,
    mppnm       VARCHAR (255) NOT NULL,
    volgnr      int4,
    galcv       VARCHAR (255) NOT NULL,
    spef        VARCHAR (255),
    cq          int4,
    cu          CHAR (1),
    cfq         NUMERIC (12, 4),
    cfu         VARCHAR (255),
    aq          int4,
    au          VARCHAR (255),
    afq         NUMERIC (12, 4) NOT NULL,
    afu         VARCHAR (255),
    atype       VARCHAR (255),
    cmucomb     VARCHAR (255),
    law         CHAR (1),
    ssecr       VARCHAR (255),
    pupr        NUMERIC (12, 4) NOT NULL,
    use         CHAR (1),
    note        VARCHAR (255),
    pos         VARCHAR (255),
    content_    VARCHAR (255),
    galnm_      VARCHAR (255),
    "index"     NUMERIC (12, 4) NOT NULL,
    rema        NUMERIC (12, 4) NOT NULL,
    remw        NUMERIC (12, 4) NOT NULL,
    inncnk      VARCHAR (255) NOT NULL,
    vosnm_      VARCHAR (255),
    bt          bool,
    gdkp        bool NOT NULL,
    excip       VARCHAR (255),
    cheapest    bool,
    specrules   bool NOT NULL,
    narcotic    bool NOT NULL,
    amb         bool,
    hosp        bool
);

DROP TABLE IF EXISTS SOURCES.GGR_SAM;
CREATE TABLE SOURCES.GGR_SAM
(
    mppcv     VARCHAR (255) NOT NULL,
    stofcv    VARCHAR (255) NOT NULL,
    ppid      VARCHAR (255) NOT NULL,
    hyr_      VARCHAR (255) NOT NULL,
    hyrcv_    VARCHAR (255) NOT NULL,
    mpcv_     VARCHAR (255) NOT NULL,
    mppnm_    VARCHAR (255),
    ppq       int4,
    ppgal     VARCHAR (255),
    inrank    int4 NOT NULL,
    stofnm_   VARCHAR (255),
    dim       VARCHAR (255),
    inx       VARCHAR (255),
    inq       NUMERIC (12, 4) NOT NULL,
    inu       VARCHAR (255),
    "add"     CHAR (1),
    inbasq    NUMERIC (12, 4) NOT NULL,
    inbasu    VARCHAR (255),
    inq2      NUMERIC (12, 4) NOT NULL,
    inu2      VARCHAR (255),
    amb       bool,
    hosp      bool
);
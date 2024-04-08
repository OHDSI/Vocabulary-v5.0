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

DROP TABLE IF EXISTS SOURCES.CVX;
CREATE TABLE SOURCES.CVX
(
   cvx_code            VARCHAR (100),
   short_description   VARCHAR (4000),
   full_vaccine_name   VARCHAR (4000),
   vaccinestatus       TEXT,
   last_updated_date   DATE,
   vocabulary_date     DATE,
   vocabulary_version  VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.CVX_DATES;
CREATE TABLE SOURCES.CVX_DATES
(
   cvx_code            VARCHAR (100) UNIQUE NOT NULL,
   concept_date        DATE NOT NULL
);

DROP TABLE IF EXISTS SOURCES.CVX_CPT;
CREATE TABLE SOURCES.CVX_CPT
(
   cpt_code               VARCHAR (100),
   cpt_description        VARCHAR (4000),
   cvx_short_description  VARCHAR (4000),
   cvx_code               VARCHAR (100),
   map_comment            VARCHAR (4000),
   last_updated_date      DATE,
   cpt_code_id            VARCHAR (100)
);

DROP TABLE IF EXISTS SOURCES.CVX_VACCINE;
CREATE TABLE SOURCES.CVX_VACCINE
(
   cvx_short_description  VARCHAR (4000),
   cvx_code               VARCHAR (100),
   vaccine_status         VARCHAR (100),
   vg_name                VARCHAR (4000),
   cvx_vaccine_group      VARCHAR (100)
);

CREATE OR REPLACE FUNCTION sources.py_xlsparse_cvx_codes(xls_path varchar)
RETURNS
TABLE (
    CVX_CODE varchar,
    SHORT_DESCRIPTION varchar,
    FULL_VACCINE_NAME varchar,
    VACCINESTATUS text,
    LAST_UPDATED_DATE date
)
AS
$BODY$
from openpyxl import load_workbook
res = []
wb = load_workbook(xls_path)
sheet = wb.worksheets[0]
for row in sheet.iter_rows(min_row=2):
  CVX_CODE=row[0].value if row[0].value else None
  SHORT_DESCRIPTION=row[1].value if row[1].value else None
  FULL_VACCINE_NAME=row[2].value if row[2].value else None
  VACCINESTATUS=row[4].value if row[4].value else None
  LAST_UPDATED_DATE=row[7].value if row[7].value else None
  res.append((CVX_CODE,SHORT_DESCRIPTION,FULL_VACCINE_NAME,VACCINESTATUS,LAST_UPDATED_DATE))
return res
$BODY$
LANGUAGE 'plpython3u' STRICT;

CREATE OR REPLACE FUNCTION sources.py_xlsparse_cvx_dates(xls_path varchar)
RETURNS
TABLE (
    CVX_CODE varchar
)
AS
$BODY$
import xlrd
res = []
wb = xlrd.open_workbook(xls_path)
sheet = wb.sheet_by_index(1)
for rowid in range(1,sheet.nrows):
  row = sheet.row_values(rowid)
  CVX_CODE=row[0] if row[0] else None
  res.append((CVX_CODE))
return res
$BODY$
LANGUAGE 'plpython3u' STRICT;

CREATE OR REPLACE FUNCTION sources.py_xlsparse_cvx_cpt(xls_path varchar)
RETURNS
TABLE (
    CPT_CODE varchar,
    CPT_DESCRIPTION varchar,
    CVX_SHORT_DESCRIPTION varchar,
    CVX_CODE varchar,
    MAP_COMMENT varchar,
    LAST_UPDATED_DATE date,
    CPT_CODE_ID varchar
)
AS
$BODY$
from openpyxl import load_workbook
res = []
wb = load_workbook(xls_path)
sheet = wb.worksheets[0]
for row in sheet.iter_rows(min_row=2):
  CPT_CODE=row[0].value if row[0].value else None
  CPT_DESCRIPTION=row[1].value if row[1].value else None
  CVX_SHORT_DESCRIPTION=row[2].value if row[2].value else None
  CVX_CODE=row[3].value if row[3].value else None
  MAP_COMMENT=row[4].value if row[4].value else None
  LAST_UPDATED_DATE=row[5].value if row[5].value else None
  CPT_CODE_ID=row[6].value if row[6].value else None
  res.append((CPT_CODE,CPT_DESCRIPTION,CVX_SHORT_DESCRIPTION,CVX_CODE,MAP_COMMENT,LAST_UPDATED_DATE,CPT_CODE_ID))
return res
$BODY$
LANGUAGE 'plpython3u' STRICT;

CREATE OR REPLACE FUNCTION sources.py_xlsparse_cvx_vaccine(xls_path varchar)
RETURNS
TABLE (
    CVX_SHORT_DESCRIPTION varchar,
    CVX_CODE varchar,
    VACCINE_STATUS varchar,
    VG_NAME varchar,
    CVX_VACCINE_GROUP varchar
)
AS
$BODY$
from openpyxl import load_workbook
res = []
wb = load_workbook(xls_path)
sheet = wb.worksheets[0]
for row in sheet.iter_rows(min_row=2):
  CVX_SHORT_DESCRIPTION=row[0].value if row[0].value else None
  CVX_CODE=row[1].value if row[1].value else None
  VACCINE_STATUS=row[2].value if row[2].value else None
  VG_NAME=row[3].value if row[3].value else None
  CVX_VACCINE_GROUP=row[4].value if row[4].value else None
  res.append((CVX_SHORT_DESCRIPTION,CVX_CODE,VACCINE_STATUS,VG_NAME,CVX_VACCINE_GROUP))
return res
$BODY$
LANGUAGE 'plpython3u' STRICT;
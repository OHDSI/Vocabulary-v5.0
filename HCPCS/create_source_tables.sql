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

DROP TABLE IF EXISTS SOURCES.ANWEB_V2;
CREATE TABLE SOURCES.ANWEB_V2
(
   HCPC                VARCHAR (1000),
   LONG_DESCRIPTION    VARCHAR (4000),
   SHORT_DESCRIPTION   VARCHAR (1000),
   XREF1               VARCHAR (1000),
   XREF2               VARCHAR (1000),
   XREF3               VARCHAR (1000),
   XREF4               VARCHAR (1000),
   XREF5               VARCHAR (1000),
   BETOS               VARCHAR (1000),
   ADD_DATE            DATE,
   ACT_EFF_DT          DATE,
   TERM_DT             DATE,
   VOCABULARY_DATE     DATE,
   VOCABULARY_VERSION  VARCHAR (200)
);

CREATE OR REPLACE FUNCTION sources.py_xlsparse_hcpcs(xls_path varchar)
RETURNS
TABLE (
    HCPC varchar,
    LONG_DESCRIPTION varchar,
    SHORT_DESCRIPTION varchar,
    XREF1 varchar,
    XREF2 varchar,
    XREF3 varchar,
    XREF4 varchar,
    XREF5 varchar,
    BETOS varchar,
    ADD_DATE varchar,
    ACT_EFF_DT varchar,
    TERM_DT varchar
)
AS
$BODY$
import xlrd
res = []
wb = xlrd.open_workbook(xls_path)
sheet = wb.sheet_by_index(0)
for rowid in range(1,sheet.nrows):
  row = sheet.row_values(rowid)
  HCPC=row[0] if row[0] else None
  LONG_DESCRIPTION=row[3] if row[3] else None
  SHORT_DESCRIPTION=row[4] if row[4] else None
  XREF1=row[25] if row[25] else None
  XREF2=row[26] if row[26] else None
  XREF3=row[27] if row[27] else None
  XREF4=row[28] if row[28] else None
  XREF5=row[29] if row[29] else None
  BETOS=row[37] if row[37] else None
  ADD_DATE=row[44] if row[44] else None
  ACT_EFF_DT=row[45] if row[45] else None
  TERM_DT=row[46] if row[46] else None
  res.append((HCPC,LONG_DESCRIPTION,SHORT_DESCRIPTION,XREF1,XREF2,XREF3,XREF4,XREF5,BETOS,ADD_DATE,ACT_EFF_DT,TERM_DT))
return res
$BODY$
LANGUAGE 'plpythonu'
SECURITY DEFINER;
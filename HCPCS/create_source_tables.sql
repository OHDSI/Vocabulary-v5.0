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
from openpyxl import load_workbook
res = []
wb = load_workbook(xls_path)
sheet = wb.worksheets[0]
for row in sheet.iter_rows(min_row=2):
  HCPC=row[0].value if row[0].value else None
  LONG_DESCRIPTION=row[3].value if row[3].value else None
  SHORT_DESCRIPTION=row[4].value if row[4].value else None
  XREF1=row[25].value if row[25].value else None
  XREF2=row[26].value if row[26].value else None
  XREF3=row[27].value if row[27].value else None
  XREF4=row[28].value if row[28].value else None
  XREF5=row[29].value if row[29].value else None
  BETOS=row[37].value if row[37].value else None
  ADD_DATE=row[44].value if row[44].value else None
  ACT_EFF_DT=row[45].value if row[45].value else None
  TERM_DT=row[46].value if row[46].value else None
  res.append((HCPC,LONG_DESCRIPTION,SHORT_DESCRIPTION,XREF1,XREF2,XREF3,XREF4,XREF5,BETOS,ADD_DATE,ACT_EFF_DT,TERM_DT))
return res
$BODY$
LANGUAGE 'plpython3u' STRICT;
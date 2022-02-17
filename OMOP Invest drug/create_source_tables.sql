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
* Date: 2022
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.NCIT_ANTINEOPL;
CREATE TABLE SOURCES.NCIT_ANTINEOPL
(
   CODE                TEXT,
   NCIT_PREFERRED_NAME TEXT,
   SYNONYMS            TEXT,
   DEFINITION          TEXT,
   SEMANTIC_TYPE       TEXT
);

DROP TABLE IF EXISTS SOURCES.NCIT_PHARMSUB;
CREATE TABLE SOURCES.NCIT_PHARMSUB
(
   CONCEPT_ID         TEXT,
   PT                 TEXT,
   SY                 TEXT,
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR (200)
);

CREATE OR REPLACE FUNCTION sources.py_xlsparse_ncit(xls_path varchar)
RETURNS
TABLE (
    concept_id text,
    pt text,
    sy text
)
AS
$BODY$
import xlrd
res = []
wb = xlrd.open_workbook(xls_path)
sheet = wb.sheet_by_index(0)
for rowid in range(1,sheet.nrows):
  row = sheet.row_values(rowid)
  concept_id=row[1] if row[1] else None
  pt=row[2] if row[2] else None
  sy=row[3] if row[3] else None
  res.append((concept_id,pt,sy))
return res
$BODY$
LANGUAGE 'plpythonu'
SECURITY DEFINER;
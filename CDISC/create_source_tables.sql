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
* Authors: Aliaksei Katyshou
* Date: 2024
**************************************************************************/
DROP TABLE IF EXISTS sources.meta_mrsab;
CREATE TABLE sources.meta_mrsab (
	vcui text NULL,
	rcui text NULL,
	vsab text NULL,
	rsab text NULL,
	son text NULL,
	sf text NULL,
	sver text NULL,
	vstart text NULL,
	vend text NULL,
	imeta text NULL,
	rmeta text NULL,
	slc text NULL,
	scc text NULL,
	srl int4 NULL,
	tfr int4 NULL,
	cfr int4 NULL,
	cxty text NULL,
	ttyl text NULL,
	atnl text NULL,
	lat text NULL,
	cenc text NULL,
	curver text NULL,
	sabin text NULL,
	ssn text NULL,
	scit text NULL,
	vocabulary_date date NULL,
	vocabulary_version text NULL
);

DROP TABLE IF EXISTS sources.meta_mrconso;
CREATE TABLE sources.meta_mrconso (
	cui text NULL,
	lat text NULL,
	ts text NULL,
	lui text NULL,
	stt text NULL,
	sui text NULL,
	ispref text NULL,
	aui text NULL,
	saui text NULL,
	scui text NULL,
	sdui text NULL,
	sab text NULL,
	tty text NULL,
	code text NULL,
	str text NULL,
	srl int4 NULL,
	suppress text NULL,
	cvf int4 NULL,
	filler_column int4 NULL
);
CREATE INDEX idx_meta_mrconso_aui ON sources.meta_mrconso USING btree (aui);
CREATE INDEX idx_meta_mrconso_code ON sources.meta_mrconso USING btree (code);
CREATE INDEX idx_meta_mrconso_cui ON sources.meta_mrconso USING btree (cui);
CREATE INDEX idx_meta_mrconso_sab_tty ON sources.meta_mrconso USING btree (sab, tty);
CREATE INDEX idx_meta_mrconso_scui ON sources.meta_mrconso USING btree (scui);

DROP TABLE IF EXISTS sources.meta_mrsty;
CREATE TABLE sources.meta_mrsty (
	cui text NULL,
	tui text NULL,
	stn text NULL,
	sty text NULL,
	atui text NULL,
	cvf text NULL,
	filler_column int4 NULL
);
CREATE INDEX idx_meta_mrsty_cui ON sources.meta_mrsty USING btree (cui);

DROP TABLE IF EXISTS sources.meta_mrdef;
CREATE TABLE sources.meta_mrdef (
	cui text NULL,
	aui text NULL,
	atui text NULL,
	satui text NULL,
	sab text NULL,
	def text NULL,
	suppress text NULL,
	cvf int4 NULL,
	filler_column int4 NULL
);
CREATE INDEX idx_meta_mrdef_sab_cui ON sources.meta_mrdef USING btree (sab, cui);

/**************************************************************************
* Copyright 2017 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Timur Vakhitov
* Date: 2017
**************************************************************************/
/*
	Procedures gets data from the sources and parse into our tables
	
	Target tables:
	ndc_history - target table with parsed NDC-data (job GetAllNDC)
	rxnorm2ndc_mappings - target table with parsed mappings from RxNorm to NDC (job RxNorm2NDC_Mappings)
	rxnorm2spl_mappings - target table with parsed mappings from RxNorm to SPL (job RxNorm2SPL_Mappings)
	TEMP tables:
	api_codes_failed - table for failed concepts
	ndc_history_tmp - temporary table for ndc_history
	ndc_all_codes - temporary table for job GetAllNDC
	rxnorm2ndc_mappings_tmp - temporary table for rxnorm2ndc_mappings
	rxnorm2spl_mappings_tmp - temporary table for rxnorm2spl_mappings
	
	DDL:
	CREATE TABLE apigrabber.api_codes_failed (concept_code VARCHAR(50));
	CREATE TABLE apigrabber.ndc_all_codes (concept_code VARCHAR(50));
	CREATE TABLE apigrabber.ndc_history
	(
		CONCEPT_CODE  VARCHAR(50),
		STATUS        VARCHAR(4000),
		ACTIVERXCUI   VARCHAR(4000),
		STARTDATE     DATE,
		ENDDATE       DATE
	);
	CREATE TABLE apigrabber.rxnorm2ndc_mappings
	(
		CONCEPT_CODE  VARCHAR(50),
		NDC_CODE      VARCHAR(4000),
		STARTDATE     DATE,
		ENDDATE       DATE
	);
	CREATE TABLE apigrabber.rxnorm2spl_mappings
	(
		CONCEPT_CODE  VARCHAR(50),
		SPL_CODE      VARCHAR(4000)
	);
	CREATE TABLE apigrabber.rxnorm2spl_mappings_tmp (LIKE apigrabber.rxnorm2spl_mappings);
	CREATE TABLE apigrabber.rxnorm2ndc_mappings_tmp (LIKE apigrabber.rxnorm2ndc_mappings);
	CREATE TABLE apigrabber.ndc_history_tmp (LIKE apigrabber.ndc_history);
	CREATE INDEX idx_ndc_hist_cc ON apigrabber.ndc_history (concept_code);
	
	Start sequence:
	DO $_$
	BEGIN
		PERFORM apigrabber.GetRxNorm2NDC_Mappings();
		PERFORM apigrabber.GetRxNorm2SPL_Mappings();
		PERFORM apigrabber.GetAllNDC();
	END $_$;
*/
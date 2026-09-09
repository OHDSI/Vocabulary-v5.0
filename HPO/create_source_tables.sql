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
* Authors: HPO
* Date: 2025
**************************************************************************/

-- ============================================================================
-- TABLE: dev_hpo.hpo_json
-- Description: Stores HPO JSON source data with version tracking
-- ============================================================================

DROP TABLE IF EXISTS dev_hpo.hpo_json;
CREATE TABLE dev_hpo.hpo_json (
    id SERIAL PRIMARY KEY,
    version DATE,
    source_json JSONB NOT NULL,
    ts DATE DEFAULT CURRENT_DATE,
    download_url TEXT DEFAULT 'https://purl.obolibrary.org/obo/hp.json'  -- Corrected typo: 'download_ulr' to 'download_url'
);


-- ============================================================================
-- TABLE: genes_to_phenotype
-- Description: Stores associations between genes and phenotypes from HPO
-- ============================================================================

DROP TABLE IF EXISTS dev_hpo.genes_to_hpo_phenotype;
CREATE TABLE dev_hpo.genes_to_hpo_phenotype (
    ncbi_gene_id INTEGER,
    gene_symbol VARCHAR(50),
    hpo_id VARCHAR(20),
    hpo_name TEXT,
    frequency VARCHAR(50),
    disease_id VARCHAR(100)
);




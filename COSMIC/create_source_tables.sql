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
* Authors: Medical Team
* Date: 2022
**************************************************************************/
DROP TABLE cosmicmutantexportcensus;
CREATE TABLE cosmicmutantexportcensus
(
    gene_name                VARCHAR(100),
    accession_number         VARCHAR(200),
    gene_cds_length          INT,
    hgnc_id                  INT,
    sample_name              VARCHAR(200),
    id_sample                INT,
    id_tumour                INT,
    primary_site             VARCHAR(200),
    site_subtype_1           VARCHAR(100),
    site_subtype_2           VARCHAR(100),
    site_subtype_3           VARCHAR(100),
    primary_histology        VARCHAR(200),
    histology_subtype_1      VARCHAR(100),
    histology_subtype_2      VARCHAR(100),
    histology_subtype_3      VARCHAR(100),
    genome_wide_screen       VARCHAR(50),
    genomic_mutation_id      VARCHAR(100),
    legacy_mutation_id       VARCHAR(100),
    mutation_id              INT,
    mutation_cds             TEXT,
    mutation_aa              TEXT,
    mutation_description     TEXT,
    mutation_zygosity        VARCHAR(50),
    loh                      VARCHAR(20),
    grch                     VARCHAR(20),
    mutation_genome_position VARCHAR(200),
    mutation_strand          VARCHAR(5),
    resistance_mutation      VARCHAR(5),
    mutation_somatic_status  TEXT,
    pubmed_pmid              VARCHAR(100),
    id_study                 VARCHAR(100),
    sample_type              VARCHAR(200),
    tumour_origin            VARCHAR(100),
    age                      VARCHAR(100),
    tier                     INT,
    hgvsp                    TEXT,
    hgvsc                    TEXT,
    hgvsg                    TEXT
);
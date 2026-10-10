######################################
## PhenotypeChangesInVocabUpdate code to run ##
######################################

# install libraries, if not installed

#remotes::install_github("OHDSI/Alathea")

library(dplyr)
library(openxlsx)
library(readr)
library(tibble)
library(DatabaseConnector)
library(Alathea)

source("R/config.R")

# Report name derived from schema versions: e.g. v20250827_vs_v20260227_omop
projName <- paste0(sub("^.*\\.", "", oldVocSchema), "_vs_", sub("^.*\\.", "", newVocSchema))

# specify cohorts you want to run the comparison for
# maybe Azza can suggest how to extract these automatically
Cohorts <- read_delim("Cohorts2026.csv", delim = ",",
                      escape_double = FALSE, trim_ws = TRUE)
cohorts <-c( Cohorts$cohortId)

#excluded nodes is a text string with nodes you want to exclude from the analysis, it's set to 0 by default
# for example now some CPT4 and HCPCS are mapped to Visit concepts and we didn't implement this in the ETL,
#so we don't want these in the analysis (note, the tool doesn't look at the actual CDM, but on the mappings in the vocabulary)
#this way, the excludedNodes are defined in this way:
excludedVisitNodes <- "9202, 2514435,9203,2514436,2514437,2514434,2514433,9201"

#you can restrict the output by using specific source vocabularies (only those that exist in your data as source concepts)
includedSourceVocabs <- "'ICD10', 'ICD10CM', 'CPT4', 'HCPCS', 'NDC', 'ICD9CM', 'ICD9Proc', 'ICD10PCS', 'ICDO3', 'JMDC', 'LOINC'"

#specify schemas — set in config.R


#get the concept count table
#see to generate here
# https://github.com/OHDSI/WebAPI/blob/master/src/main/resources/ddl/achilles/achilles_result_concept_count.sql
# and store it in the same database as the Vocabulary tables, please specify schema as result schema
# set to NULL to run without usage counts
# resultSchema is set in config.R

# (optional) CDM schema for the stats tab — set in config.R (NULL to skip)

#create the dataframe with concept set expressions using the getNodeConcepts function
Concepts_in_cohortSet<-getNodeConcepts(cohorts, baseUrl)

#resolve concept sets, compare the outputs on different vocabulary versions, write results to the Excel file
#for Redshift ask your administrator for a key for bulk load, since the function uploads the data to the database
resultToExcel(connectionDetailsVocab = connectionDetails,
              Concepts_in_cohortSet = Concepts_in_cohortSet,
              newVocabSchema = newVocSchema,
              oldVocabSchema = oldVocSchema,
              excludedNodes = excludedVisitNodes,
              resultSchema = resultSchema,
              scratchSchema= scratchSchema,
              includedSourceVocabs = includedSourceVocabs,
              projName = projName,
              cdmSchema = cdmSchema
)

#open the excel file
#Windows
phenFile <- paste0(projName, "PhenChange.xlsx")
dir.create(outputDir, recursive = TRUE, showWarnings = FALSE)
if (file.exists(phenFile)) file.rename(phenFile, file.path(outputDir, phenFile))
outPath <- normalizePath(file.path(outputDir, phenFile), mustWork = FALSE)
if (file.exists(outPath)) shell.exec(outPath) else warning("Output file not found: ", outPath)

#MacOS
#system(paste("open", file.path(outputDir, phenFile)))

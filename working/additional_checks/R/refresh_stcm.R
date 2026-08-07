#update STCM automatically, for rows where it's not possible, run it automatically
#if not possibly to map automatically, get the mapping manualy

#set connectionDetailsVocab

library(dplyr)
library(readr)
library(tibble)
library(openxlsx)
library(DatabaseConnector)

source("R/config.R")

#set path to SQL
stcm_refresh_part_1 <- read_file(file.path(sqlDir, "stcm_refresh_part_1.sql"))
stcm_refresh_part_2 <- read_file(file.path(sqlDir, "stcm_refresh_part_2.sql"))
stcm_refresh_part_3 <- read_file(file.path(sqlDir, "stcm_refresh_part_3.sql"))

# check queries
stcm_check_non_standard_sql      <- read_file(file.path(sqlDir, "stcm_check_non_standard.sql"))
stcm_check_duplicates_sql        <- read_file(file.path(sqlDir, "stcm_check_duplicates.sql"))
stcm_check_changed_mapping_sql   <- read_file(file.path(sqlDir, "stcm_check_changed_mapping.sql"))
stcm_check_new_source_sql        <- read_file(file.path(sqlDir, "stcm_check_new_source_concepts.sql"))
stcm_check_lost_mapping_sql      <- read_file(file.path(sqlDir, "stcm_check_lost_mapping.sql"))

conn <- DatabaseConnector::connect(connectionDetailsVocab)

#run automated updates on STCM
sql1 <-SqlRender::render(stcm_refresh_part_1,
                         newVocSchema  = newVocSchema,
                         oldVocSchema  = oldVocSchema,
                         scratchSchema = scratchSchema)

 #run it
 DatabaseConnector::executeSql(connection = conn,
                               sql1)


#get table for manual mapping
 STCM_to_map <- DatabaseConnector::renderTranslateQuerySql(
   connection    = conn,
   stcm_refresh_part_2,
   scratchSchema = scratchSchema,
   resultSchema  = resultSchema
 )


#save as file
write.csv(STCM_to_map, file = file.path(outputDir, "STCM_to_map.csv"))

#open in excel as 'data' tab above ->from text-> chose the file and set the data types, so it will not corrupt the concept codes

#open in system viewer
shell.exec(normalizePath(file.path(outputDir, "STCM_to_map.csv")))

#fill the mappings, if mapping is not available set target_concept_id = 0, target_vocabulary_id= 'None'
# save file as STCM_manual.csv with the following columns:
#source_code, source_concept_id, source_vocabulary_id, source_code_description, target_concept_id, target_vocabulary_id

#save csv to dataframe
STCM_manual <- read_csv(file.path(outputDir, 'STCM_manual.csv'))

#upload table to the server
DatabaseConnector::insertTable(connection = conn,
                               tableName = paste0(scratchSchema, ".STCM_manual"),
                               data = STCM_manual,
                               dropTableIfExists = TRUE,
                               createTable = TRUE,
                               tempTable = F,
                               bulkLoad = F)

#merge STCM_manual with source_to_concept_map
DatabaseConnector::renderTranslateExecuteSql(connection = conn,
                                             stcm_refresh_part_3,
                                             newVocSchema  = newVocSchema,
                                             oldVocSchema  = oldVocSchema,
                                             scratchSchema = scratchSchema)

########################################
#checks and statistics
########################################

#check if mapped to non-standard
non_st_map <- DatabaseConnector::renderTranslateQuerySql(
  connection = conn,
  stcm_check_non_standard_sql,
  scratchSchema = scratchSchema
)

#are there duplicates
duplicates <- DatabaseConnector::renderTranslateQuerySql(
  connection = conn,
  stcm_check_duplicates_sql,
  scratchSchema = scratchSchema
)

#calculate delta, concepts changed mapping
cnc_changed_mapping <- DatabaseConnector::renderTranslateQuerySql(
  connection = conn,
  stcm_check_changed_mapping_sql,
  scratchSchema = scratchSchema,
  newVocSchema  = newVocSchema,
  oldVocSchema  = oldVocSchema
)

#calculate delta, new source concepts
new_source_concepts <- DatabaseConnector::renderTranslateQuerySql(
  connection = conn,
  stcm_check_new_source_sql,
  scratchSchema = scratchSchema,
  newVocSchema  = newVocSchema,
  oldVocSchema  = oldVocSchema
)

#concepts lost their mapping (even mapping to 0) with this refresh
lost_mapping <- DatabaseConnector::renderTranslateQuerySql(
  connection = conn,
  stcm_check_lost_mapping_sql,
  scratchSchema = scratchSchema,
  newVocSchema  = newVocSchema,
  oldVocSchema  = oldVocSchema
)

#disconnect
DatabaseConnector::disconnect(conn)

# put the results in excel, each dataframe goes to a separate tab
wb <- createWorkbook()

addWorksheet(wb, "non_st_map")
writeData(wb, "non_st_map", non_st_map)

addWorksheet(wb, "duplicates")
writeData(wb, "duplicates", duplicates)

addWorksheet(wb, "cnc_changed_mapping")
writeData(wb, "cnc_changed_mapping", cnc_changed_mapping)

addWorksheet(wb, "new_source_concepts")
writeData(wb, "new_source_concepts", new_source_concepts)

addWorksheet(wb, "lost_mapping")
writeData(wb, "lost_mapping", lost_mapping)

saveWorkbook(wb, file.path(outputDir, "statistics.xlsx"), overwrite = TRUE)

#open the excel file
#Windows
shell.exec(normalizePath(file.path(outputDir, "statistics.xlsx")))

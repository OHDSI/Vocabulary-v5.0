library(readr)
library(dplyr)
library(stringr)
library(ellmer)
#install.packages("ellmer")

source("R/config.R")
conn <- DatabaseConnector::connect(connectionDetails)

# read SQL from file
map_difSql <- read_file(file.path(sqlDir, "mapping_changed.sql"))

#run the SQL creating all tables needed for the output
mappings <- DatabaseConnector::renderTranslateQuerySql(
  connection    = conn,
  map_difSql,
  newVocSchema  = newVocSchema,
  oldVocSchema  = oldVocSchema,
  resultSchema  = resultSchema
)
DatabaseConnector::disconnect(conn)

systemPrompt <- "
You are an expert in clinical ontologies, evaluating mappings from a source
terminology system to standard concepts in the OHDSI vocabulary. Your task is to
determine which of two target concepts is the best mapping. Because we map
in one direction only, it is ok if the target is slightly broader in scope,
but the best mapping would be a target concept that is clinically equivalent to
the source term.
"
promptTemplate <- "
Source concept: %s
Old target concept: %s
New target concept: %s
Provide reasons why a mapping might be better, followed by your final
assessment of which mapping is best.
Output format:
- Reasons why the old mapping might be better:
- Reasons why the new mapping might be better:
- Final answer: 'old' or 'new'
"

# Create one independent chat per mapping pair (stateless — no shared context)
chats <- lapply(seq_len(nrow(mappings)), function(i) {
  chat_azure_openai(
    endpoint      = gsub("/openai/deployments.*", "", keyring::key_get("genai_o3_endpoint")),
    api_version   = "2024-12-01-preview",
    model         = model,
    credentials   = function() keyring::key_get("genai_api_gpt4_key"),
    system_prompt = systemPrompt
  )
})

prompts <- lapply(seq_len(nrow(mappings)), function(i) {
  sprintf(promptTemplate,
          mappings$SOURCE_CONCEPT_NAME[i],
          mappings$OLD_MAPPED_CONCEPT_NAME[i],
          mappings$NEW_MAPPED_CONCEPT_NAME[i])
})

message(sprintf("Evaluating %d mapping pairs in parallel...", nrow(mappings)))
responses <- parallel_chat_text(chats, prompts)

mappings$bestMapping <- str_match(responses, "Final answer.*: ['\"]?(old|new)['\"]?")[, 2]

token_usage()

#store as csv
write.csv(mappings, file.path(outputDir, "mapping_output.csv"), row.names = FALSE)

#open the file
shell.exec(normalizePath(file.path(outputDir, "mapping_output.csv")))

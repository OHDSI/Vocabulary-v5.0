library(openxlsx)
library(DatabaseConnector)
library(readr)

source("R/config.R")

conn <- DatabaseConnector::connect(connectionDetails)

DatabaseConnector::renderTranslateExecuteSql(connection = conn,
                                             "use @newVocSchema",
                                             newVocSchema = newVocSchema
)

################################
#check release
################################

#missing gemcitabine intravesical [Inlexzo]
missingInlexzo <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
                                                            "select vocabulary_id,vocabulary_version , 'check this vocabulary if we miss inlexzo in it' as info_message from vocabulary where vocabulary_id in ('HCPCS', 'NDC', 'RxNorm', 'CPT4', 'ICD10PCS') -- possible drug vocabularies
                                                            and vocabulary_id not in (
                                                              select vocabulary_id from concept where lower (concept_name) like '%inlexzo%' or lower (concept_name) like '%gemcitabine%intravesical%'
                                                            )
                                                            union all
                                                            --if RxNorm concept is available check mappings
                                                            select vocabulary_id,vocabulary_version , 'check this vocabulary if we miss mapping from it, if RxNorm concept is available' from vocabulary where vocabulary_id in ('HCPCS', 'NDC', 'RxNorm', 'CPT4', 'ICD10PCS') -- possible drug vocabularies
                                                            and vocabulary_id not in (
                                                              select distinct c2.vocabulary_id   from concept c
                                                              join concept_relationship r on r.concept_id_2= c.concept_id and r.relationship_id = 'Maps to'
                                                              join concept c2 on c2.concept_id = r.concept_id_1
                                                              where lower (c.concept_name) like '%inlexzo%' or lower (c.concept_name) like '%gemcitabine%intravesical%'
                                                              and c.vocabulary_id = 'RxNorm'
                                                            ) "
)


#ICD conditions missing mapping
#ICD in JnJ
ICD_jnj_mis_map <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
"select c.* from concept c
left join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id = 'Maps to'
where (c.vocabulary_id in ('ICD9CM', 'ICD10')
       or c.vocabulary_id ='ICD10CM' and c.valid_end_date >'2015-10-01') -- ICD10CM effective since Oct-2015
and c.concept_name NOT LIKE '%Emergency use%' AND c.concept_name NOT LIKE '%Invalid ICD10%'
and LOWER(c.concept_class_id) NOT LIKE '%chapter%'
and cr.concept_id_1 is null"
)


#all ICDs
ICD_all_mis_map <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
                                                              "select c.* from concept c
left join concept_relationship cr on cr.concept_id_1= c.concept_id and relationship_id = 'Maps to'
where (c.vocabulary_id in ('ICD9CM', 'ICD10', 'ICD10GM', 'CIM10', 'ICD10CN', 'KCD7')
       or c.vocabulary_id ='ICD10CM' and c.valid_end_date >'2015-10-01'  -- ICD10CM effective since Oct-2015
       or c.vocabulary_id = 'ICDO3' and c.concept_class_id='ICDO Condition' -- only precoordinated concepts should be mapped
       )
and c.concept_name NOT LIKE '%Emergency use%' AND c.concept_name NOT LIKE '%Invalid ICD10%'
and LOWER(c.concept_class_id) NOT LIKE '%chapter%'
and cr.concept_id_1 is null
order by c.vocabulary_id , c.concept_code"
)

#source procedure concepts missing mapping
#used in JnJ
Prc_jnj_mis_map <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
"select c.* from concept c
left join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id = 'Maps to'
where c.vocabulary_id in ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
and concept_class_id not in ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy' )
and LOWER(c.concept_name) NOT LIKE '% not %'
and cr.concept_id_1 is null
order by c.vocabulary_id , c.concept_code"
)

#source procedure concepts missing mapping
#used overall in OMOP vocab, 'OPS', 'CCAM', 'OPCS4' added
Prc_all_mis_map <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
                                                             "select c.* from concept c
left join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id = 'Maps to'
where c.vocabulary_id in ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4', 'OPS', 'CCAM', 'OPCS4')
and concept_class_id not in ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy' )
and LOWER(c.concept_name) NOT LIKE '% not %'
and cr.concept_id_1 is null
order by c.vocabulary_id , c.concept_code"
)


# missing mapping from source procedure vocabs to drug
# identyfying potential drug concepts using word match pattern - presence of dose units, administration
# to many things to review anyway, so better to use it on delta or JnJ specific drugs
# JnJ specific drugs: Brand names or ingredients

# Upload bnui reference table (JnJ brand names & ingredients) from data/ to scratch schema
bnui_data <- readr::read_csv(file.path("data", "bnui.csv"), show_col_types = FALSE)
DatabaseConnector::insertTable(
  connection        = conn,
  databaseSchema    = scratchSchema,
  tableName         = "bnui",
  data              = bnui_data,
  dropTableIfExists = TRUE,
  createTable       = TRUE
)

Prc_JnJDrug_no_map <- DatabaseConnector::renderTranslateQuerySql(
  connection    = conn,
  read_file(file.path(sqlDir, "collect_check_JnJDrug_no_map.sql")),
  scratchSchema = scratchSchema
)


#procedures that are potential drugs and don't have mapping to drug
Prc_Drug_no_map <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
"select c.* from concept c
join concept c2 on CHARINDEX(LOWER(c2.concept_name), LOWER(c.concept_name)) > 0
and (c2.standard_concept ='S' and c2.concept_class_id ='Ingredient' and c2.vocabulary_id ='RxNorm' and LEN(c2.concept_name)>4
     or c2.invalid_reason is null and c2.concept_class_id ='Brand Name' and c2.vocabulary_id ='RxNorm' and LEN(c2.concept_name)>4)
where c.concept_id not in (
  select c.concept_id  from concept c
  join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id = 'Maps to'
  join concept c2 on c2.concept_id = cr.concept_id_2 and c2.domain_id ='Drug'
  where c.vocabulary_id in ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
  and c.concept_class_id not in ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy' )
  and (    LOWER(c.concept_name) LIKE '%administration%'
        OR LOWER(c.concept_name) LIKE '%administered through%'
        OR c.concept_name LIKE '% mg %'    OR c.concept_name LIKE '% mg)%'   OR c.concept_name LIKE '% mg,%'
        OR c.concept_name LIKE '% units %' OR c.concept_name LIKE '% units)%' OR c.concept_name LIKE '% units,%'
        OR c.concept_name LIKE '% ml %'    OR c.concept_name LIKE '% ml)%'   OR c.concept_name LIKE '% ml,%'
        OR c.concept_name LIKE '% meg %'   OR c.concept_name LIKE '% mcg %'
        OR c.concept_name LIKE '% millicurie%'
        OR c.concept_name LIKE '% gram %'  OR c.concept_name LIKE '% grams %'
        OR c.concept_name LIKE '% million %'
        OR c.concept_name LIKE '% cc %'    OR c.concept_name LIKE '% cc)%'
        OR LOWER(c.concept_name) LIKE '%introduction of %'
        OR LOWER(c.concept_name) LIKE '%per millicurie%'
        OR LOWER(c.concept_name) LIKE '%vaccine%'
        OR LOWER(c.concept_name) LIKE '%injection%'
        OR LOWER(c.concept_name) LIKE '%for intravenous use%'
        OR LOWER(c.concept_name) LIKE '%releasing intrauterine system%'
        OR c.concept_name LIKE '%patches, %' )
)
and c.vocabulary_id in ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
and c.concept_class_id not in ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy' )
and (    LOWER(c.concept_name) LIKE 'administration%'
      OR LOWER(c.concept_name) LIKE '%administered through%'
      OR LOWER(c.concept_name) LIKE 'introduction of %'
      OR LOWER(c.concept_name) LIKE '%per millicurie%'
      OR LOWER(c.concept_name) LIKE '%vaccine%'
      OR LOWER(c.concept_name) LIKE '%for intravenous use%'
      OR LOWER(c.concept_name) LIKE '%releasing intrauterine system%'
      OR LOWER(c.concept_name) LIKE '%patches%'
      OR c.concept_name LIKE '% mg %'    OR c.concept_name LIKE '% mg)%'   OR c.concept_name LIKE '% mg,%'
      OR c.concept_name LIKE '% units %' OR c.concept_name LIKE '% units)%' OR c.concept_name LIKE '% units,%'
      OR c.concept_name LIKE '% ml %'    OR c.concept_name LIKE '% ml)%'   OR c.concept_name LIKE '% ml,%'
      OR c.concept_name LIKE '% meg %'   OR c.concept_name LIKE '% mcg %'
      OR c.concept_name LIKE '% millicurie%'
      OR c.concept_name LIKE '% gram %'  OR c.concept_name LIKE '% grams %'
      OR c.concept_name LIKE '% million %' )
order by c.vocabulary_id , c.concept_code"
)

################################
#check delta
################################

Prc_Delta_Drug_no_map <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
"--delta
select c.* from concept c
--look only at the delta
left join @oldVocSchema.concept c3 on c.concept_id = c3.concept_id
join concept c2 on CHARINDEX(LOWER(c2.concept_name), LOWER(c.concept_name)) > 0
and (c2.standard_concept ='S' and c2.concept_class_id ='Ingredient' and c2.vocabulary_id ='RxNorm' and LEN(c2.concept_name)>4
     or c2.invalid_reason is null and c2.concept_class_id ='Brand Name' and c2.vocabulary_id ='RxNorm' and LEN(c2.concept_name)>4)
where c.concept_id not in (
  select c.concept_id  from concept c
  join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id = 'Maps to'
  join concept c2 on c2.concept_id = cr.concept_id_2 and c2.domain_id ='Drug'
  where c.vocabulary_id in ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
  and c.concept_class_id not in ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy' )
  and (    LOWER(c.concept_name) LIKE '%administration%'
        OR LOWER(c.concept_name) LIKE '%administered through%'
        OR c.concept_name LIKE '% mg %'    OR c.concept_name LIKE '% mg)%'   OR c.concept_name LIKE '% mg,%'
        OR c.concept_name LIKE '% units %' OR c.concept_name LIKE '% units)%' OR c.concept_name LIKE '% units,%'
        OR c.concept_name LIKE '% ml %'    OR c.concept_name LIKE '% ml)%'   OR c.concept_name LIKE '% ml,%'
        OR c.concept_name LIKE '% meg %'   OR c.concept_name LIKE '% mcg %'
        OR c.concept_name LIKE '% millicurie%'
        OR c.concept_name LIKE '% gram %'  OR c.concept_name LIKE '% grams %'
        OR c.concept_name LIKE '% million %'
        OR c.concept_name LIKE '% cc %'    OR c.concept_name LIKE '% cc)%'
        OR LOWER(c.concept_name) LIKE '%introduction of %'
        OR LOWER(c.concept_name) LIKE '%per millicurie%'
        OR LOWER(c.concept_name) LIKE '%vaccine%'
        OR LOWER(c.concept_name) LIKE '%injection%'
        OR LOWER(c.concept_name) LIKE '%for intravenous use%'
        OR LOWER(c.concept_name) LIKE '%releasing intrauterine system%'
        OR c.concept_name LIKE '%patches, %' )
)
and c3.concept_id is null -- part of negative join with @oldVocSchema.concept c3
and c.vocabulary_id in ('ICD10PCS', 'ICD9Proc', 'HCPCS', 'CPT4')
and c.concept_class_id not in ('HCPCS class', 'CPT4 Hierarchy', 'HCPCS Class', 'ICD10PCS Hierarchy' )
and (    LOWER(c.concept_name) LIKE 'administration%'
      OR LOWER(c.concept_name) LIKE '%administered through%'
      OR LOWER(c.concept_name) LIKE 'introduction of %'
      OR LOWER(c.concept_name) LIKE '%per millicurie%'
      OR LOWER(c.concept_name) LIKE '%vaccine%'
      OR LOWER(c.concept_name) LIKE '%for intravenous use%'
      OR LOWER(c.concept_name) LIKE '%releasing intrauterine system%'
      OR LOWER(c.concept_name) LIKE '%patches%'
      OR c.concept_name LIKE '% mg %'    OR c.concept_name LIKE '% mg)%'   OR c.concept_name LIKE '% mg,%'
      OR c.concept_name LIKE '% units %' OR c.concept_name LIKE '% units)%' OR c.concept_name LIKE '% units,%'
      OR c.concept_name LIKE '% ml %'    OR c.concept_name LIKE '% ml)%'   OR c.concept_name LIKE '% ml,%'
      OR c.concept_name LIKE '% meg %'   OR c.concept_name LIKE '% mcg %'
      OR c.concept_name LIKE '% millicurie%'
      OR c.concept_name LIKE '% gram %'  OR c.concept_name LIKE '% grams %'
      OR c.concept_name LIKE '% million %' )
order by c.vocabulary_id , c.concept_code",
oldVocSchema = oldVocSchema
)

DrMapChangSQL <- read_file(file.path(sqlDir, "drug_map_dif.sql"))

#there are too many drugs, and they were carefully reviewed by the Sciforce once, so we'll look at the delta only
JnJDrug_map_change <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
                                                                DrMapChangSQL,
oldVocSchema  = oldVocSchema,
scratchSchema = scratchSchema,
resultSchema  = resultSchema
)

#mapping chains that lost an intermediate step between old and new vocabulary
lost_leg_sql <- read_file(file.path(sqlDir, "lost_leg_of_mapping.sql"))
lost_leg_of_mapping <- DatabaseConnector::renderTranslateQuerySql(
  connection   = conn,
  lost_leg_sql,
  oldVocSchema = oldVocSchema,
  newVocSchema = newVocSchema
)

#ATC/RxNorm hierarchy edges lost in the new vocabulary
atc_rxnorm_lost_sql <- read_file(file.path(sqlDir, "compare_Atc_Rxnorm_hierarchy.sql"))
atc_rxnorm_hierarchy_lost <- DatabaseConnector::renderTranslateQuerySql(
  connection   = conn,
  atc_rxnorm_lost_sql,
  oldVocSchema = oldVocSchema,
  newVocSchema = newVocSchema
)

#ATC/RxNorm hierarchy edges added in the new vocabulary
atc_rxnorm_added_sql <- read_file(file.path(sqlDir, "compare_Atc_Rxnorm_hierarchy_added.sql"))
atc_rxnorm_hierarchy_added <- DatabaseConnector::renderTranslateQuerySql(
  connection   = conn,
  atc_rxnorm_added_sql,
  oldVocSchema = oldVocSchema,
  newVocSchema = newVocSchema
)

VocabReport <-DatabaseConnector::renderTranslateQuerySql(connection = conn,
"with new_vocab as (
  select
  'Name_duplicate' as issue_type,
  count(distinct c.concept_id) as number_of_cases from concept c
  join concept c2 on c.domain_id = c2.domain_id and c.standard_concept='S' and c2.standard_concept ='S' and lower (c.concept_name) = lower (c2.concept_name) and c.concept_id != c2.concept_id
  union all
  select 'no children and no parent codes', count(1) from concept c
  --do not have children
  left join concept_ancestor ca on c.concept_id = ca.ancestor_concept_id and ca.ancestor_concept_id != ca.descendant_concept_id
  --do not have parents
  left join concept_ancestor ca2 on c.concept_id = ca2.descendant_concept_id and ca2.ancestor_concept_id != ca2.descendant_concept_id
  where ca.ancestor_concept_id is null and ca2.ancestor_concept_id is null and c.standard_concept in ('S', 'C')
  union all
  --Check if a code has no Ingredient as a parent
  select 'concept has no Ingredient as a parent' ,count(1) from concept c
  left join (select descendant_concept_Id from concept_ancestor ca
             join concept c2 on c2.concept_id = ca.ancestor_concept_id and c2.concept_class_id ='Ingredient'
  ) b on c.concept_id = b.descendant_concept_Id
  where c.domain_id ='Drug' and c.standard_concept ='S' and b.descendant_concept_Id is null
),
old_vocab as (
  select
  'Name_duplicate' as issue_type,
  count(distinct c.concept_id) as number_of_cases from @oldVocSchema.concept c
  join @oldVocSchema.concept c2 on c.domain_id = c2.domain_id and c.standard_concept='S' and c2.standard_concept ='S' and lower (c.concept_name) = lower (c2.concept_name) and c.concept_id != c2.concept_id
  union all
  select 'no children and no parent codes', count(1) from @oldVocSchema.concept c
  --do not have children
  left join @oldVocSchema.concept_ancestor ca on c.concept_id = ca.ancestor_concept_id and ca.ancestor_concept_id != ca.descendant_concept_id
  --do not have parents
  left join @oldVocSchema.concept_ancestor ca2 on c.concept_id = ca2.descendant_concept_id and ca2.ancestor_concept_id != ca2.descendant_concept_id
  where ca.ancestor_concept_id is null and ca2.ancestor_concept_id is null and c.standard_concept in ('S', 'C')
  union all
  --Check if a code has no Ingredient as a parent
  select 'concept has no Ingredient as a parent' ,count(1) from @oldVocSchema.concept c
  left join (select descendant_concept_Id from @oldVocSchema.concept_ancestor ca
             join @oldVocSchema.concept c2 on c2.concept_id = ca.ancestor_concept_id and c2.concept_class_id ='Ingredient'
  ) b on c.concept_id = b.descendant_concept_Id
  where c.domain_id ='Drug' and c.standard_concept ='S' and b.descendant_concept_Id is null
)
select issue_type, old_vocab.number_of_cases as old_Voc_Count, new_vocab.number_of_cases as new_Voc_Count from old_vocab
join new_vocab using (issue_type)",
oldVocSchema = oldVocSchema
)

#disconnect
DatabaseConnector::disconnect(conn)

# put the results in excel, each dataframe goes to a separate tab
wb <- createWorkbook()

addWorksheet(wb, "missingInlexzo")
writeData(wb, "missingInlexzo", missingInlexzo)

addWorksheet(wb, "ICD_jnj_mis_map")
writeData(wb, "ICD_jnj_mis_map", ICD_jnj_mis_map)

addWorksheet(wb, "ICD_all_mis_map")
writeData(wb, "ICD_all_mis_map", ICD_all_mis_map)

addWorksheet(wb, "Prc_jnj_mis_map")
writeData(wb, "Prc_jnj_mis_map", Prc_jnj_mis_map)

addWorksheet(wb, "Prc_all_mis_map")
writeData(wb, "Prc_all_mis_map", Prc_all_mis_map)

addWorksheet(wb, "Prc_JnJDrug_no_map")
writeData(wb, "Prc_JnJDrug_no_map", Prc_JnJDrug_no_map)

addWorksheet(wb, "Prc_Drug_no_map")
writeData(wb, "Prc_Drug_no_map", Prc_Drug_no_map)

addWorksheet(wb, "Prc_Delta_Drug_no_map")
writeData(wb, "Prc_Delta_Drug_no_map", Prc_Delta_Drug_no_map)

addWorksheet(wb, "JnJDrug_map_change")
writeData(wb, "JnJDrug_map_change", JnJDrug_map_change)

addWorksheet(wb, "lost_leg_of_mapping")
writeData(wb, "lost_leg_of_mapping", lost_leg_of_mapping)

addWorksheet(wb, "atc_rxnorm_lost")
writeData(wb, "atc_rxnorm_lost", atc_rxnorm_hierarchy_lost)

addWorksheet(wb, "atc_rxnorm_added")
writeData(wb, "atc_rxnorm_added", atc_rxnorm_hierarchy_added)

addWorksheet(wb, "VocabReport")
writeData(wb, "VocabReport", VocabReport)

saveWorkbook(wb, file.path(outputDir, "vocab_checks.xlsx"), overwrite = TRUE)

#open the excel file
#Windows
shell.exec(normalizePath(file.path(outputDir, "vocab_checks.xlsx")))

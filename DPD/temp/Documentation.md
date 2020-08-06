#DPD vocabulary
###Step 0: Preparation
a) Clean stage tables required.

b) Modification of source field DRUG_IDENTIFICATION_NUMBER has been chosen as a source_code, even though it results in duplicates of some drugs, because 
DRUG_IDENTIFICATION_NUMBERs are in use in ETL data and Health Canada use DRUG_IDENTIFICATION_NUMBER as unique drug identifier on it's official website.

c) There is a priority for valid non-veterinary drugs during deduplication process. However, some drugs are lost during this process. They are mostly the same substances intended for different purposes (veterinary and human drugs; drugs for cats and for dogs, etc.)

###Step 1: Separation drugs from devices
Separation performed according to the community guidelines.

As a result of this step:

**non_drug** - table for devices with relevant *valid_start_date* and *valid_end_date*

**drug_product** - table for drugs with relevant *valid_start_date* and *valid_end_date*

###Step 2: Create service tables
As a result of this step:

**active_ingredients** - service table with links between drugs and ingredients

**route** - service table with links between routes of administration and drugs

**packaging** - the only available in source packaging info for drugs

**companies** - service table with links between drugs and manufacturers; the only available info for companies (*company_code has not been used to identify the company because of possible duplication of concept_code among the DPD vocabulary later*) 

**therapeutic_class** - service table with links between ATC class and drugs

**unit** - service table with all DPD units + units, not mentioned in source table active_ingredients

**ingr** - main table with all the info regarding ingredients (*active_ingredient_code, initial_name, modified_name (used in OMOP), precise_ingredient_name*) and their links to drugs

**forms** - all the possible drug forms, figured out from route_of_administration and pharmaceutical form 

**brand_name** - all the brand names, figured out from the drug_name + links to drugs

###Step 3: Populating stage tables
**list_temp** - the only service table during this step. Includes concepts requiring OMOP-codes.

**drug_concept_stage** and **internal_relationship_stage** are populated 

During this step there are also updates of brand_names, ingredients, suppliers and forms, coming from manual mapping, and creation of drug_concept_stage_backup table (with not-updated concept_names)

###Step 4: ds_stage population
**ds_stage** - main table on this step. It store all the information regarding drug strength, ingredients and box size.
All updates performed on this table

1) Creation of ds_stage table from **drug_product**, **ingr**, **active_ingredients**, **drug_concept_stage**
2) Populate amount, numerator, denominator fields from **active_ingredients**
3) Add 1 as denominator value and set unnescessary fields to null for drugs with amounts and isolated denominators units
4) Delete homeopathy drugs
5) Get rid of drugs with %, turning them into weight per weight, volume per volume or weight per volume with help of **forms**
6) Use package_size to get box_size
7) Get box size from parsing product_information from **packaging**

###Step 5: pack_content population

###Step 6: relationship to concept population
**relationship_to_concept** - table for integration of new vocabulary to existing concepts. 

During this step *Maps to* to existing concepts are created with both automated mapping and manual mapping 

###Step 7: QA


=========================================================
1) Run fast_recreate_schema
2) Run load_stage (for the first time)
3) Run rtc + perform manual_mapping
4) Run load_stage (integration of manual changes)
5) Run input_tables_QA
6) Run BuildRxE (+ set extrafloatdigits to 0)
7) Run stage_tables_QA
8) Run genericupdate
# Load Stage Logic

This document details the standardized procedure for the load stage of the dm+d (dictionary of medicines and devices) vocabulary refresh process within the OMOP CDM and OHDSI Standardized Vocabularies framework. Strict adherence to these steps is mandatory to ensure data integrity and consistency within the vocabulary. 

To delve deeper into the technical aspects of the logic described here, refer to the `load_stage.sql` `add link here`.

For easy navigation, the **steps in this documentation are numbered to match the sections within the load_stage.sql `add link here`**.
You can quickly locate each step by searching for the pattern `--! Step [x]`.

## Workflow

### Schema Preparation and Initial Data Retrieval:

* Prepare schema by creating all necessary required for the dm+d refresh process using the [additional_DDL](https://github.com/OHDSI/Vocabulary-v5.0/blob/4e371227ce73f35c8b6a5d554461a2f10b843ad3/dmd/additional_DDL.sql)

* Perform [latest_update()](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/SetLatestUpdate.sql) for the affected vocabulary (`dm+d`, `RxNorm Extension`) to reflect the commencement of the refresh process.

* Retrieve ancestor data from non-standard SNOMED concept relations using ready-to-use SQL query. This step is necessary due to the presence of non-standard Substances within the SNOMED vocabulary.

### Step 1. Data Extraction and Initial Correction

Creating working tables and populating them with necessary data extracted from the source XML files. Below is a brief overview of the tables created from these source files:

|Source Table||Derived Table|Description|
|---|---|---|---|
|f_history| → |history_codes|Contains historical codes|
|f_vtm2| → |vtms|Represents Virtual Therapeutic Moieties (VTMs)|
|f_vmp2| → |vmps, virtual_product_ingredient, ont_drug_form, drug_form|Details Virtual Medicinal Products (VMPs), their Ingredients, Ontological Dose Forms, and General Dose Forms|
|f_vmpp2| → |vmpps, comb_content_v|Provides information on Virtual Medicinal Product Packs (VMPPs) and their combination content|
|f_amp2| → |amps, licensed_route|Covers Actual Medicinal Products (AMPs) and their licensed routes of administration|
|f_ampp2| → |ampps, comb_content_a|Defines Actual Medicinal Product Packs (AMPPs) and their combination content|
|f_ingredient2| → |ingredient_substances|Lists individual ingredient substances|
|f_lookup2| → |combination_pack_ind, combination_prod_ind, unit_of_measure, forms, supplier, df_indicator|Includes dm+d lookup values for Combination Pack and Product Indicators, Units of Measure, Dose Forms, Suppliers, and Dose Form indicators.|
|*supplier| → |fake_supp|Contains fabricated supplier data for testing or anonymization purposes|

During this step, known systematic errors originating directly from the source data was addressed. These corrections, which involve update and delete queries after table creation, are necessary for two main reasons:

* The errors consistently occur during the data extraction process.
* These adjustments streamline the process of populating drug tables in subsequent steps.
  
A detailed explanation of each specific discrepancy and its resolution is provided in the comments directly preceding the relevant SQL queries within the `load_stage.sql``add link here`. These queries are specifically designed to rectify these consistent issues.

### Step 2. Device Segregation

This step involves filtering out the devices from drugs.
To store devices `devices` table is created.

The primary method involves using known issues and patterns identified from previous iterations of the dm+d vocabulary. This means that certain naming conventions or data characteristics, which historically indicated a product as a device rather than a medicinal product, are applied. These established "name patterns" act as initial classifiers.

The process also incorporates a list of pre-identified codes that are known to represent devices or are directly associated with devices. These codes serve as a robust filter to ensure correct categorization.

All patterns are described and commented via `load_stage.sql``add link here`.

### Step 3. Ingredients Processing

This section works with the `virtual_product_ingredient`, `ingredient_substances`, and `new_ingr` (a temporary table for potential automated ingredient mappings) tables. The following changes are applied:

* Units are converted to standard `UCUM` (Unified Code for Units of Measure) units, with corresponding adjustments to dosages.
* Missing amounts, numerators, and denominators are added for drugs where this information is expected but was lost.
* Any missed ingredients are added to ensure completeness.

### Step 4. Prepare for drug_concept_stage Population

This step systematically addresses ingredient accuracy and the proper representation of multi-ingredient drugs:

* An`ingred_replacement` table is created to store mappings of incorrect ingredient entries to their correct counterparts. This table serves as a reference for all subsequent replacement operations.
* Drugs containing multiple ingredients (using `+` in naming) are meticulously parsed. 
* For each parsed ingredient, an attempt is made to connect it to an existing, standard identifier. If no such identifier is found, a new OMOP concept code is assigned to the ingredient.
* Based on the mappings established in the ingredient replacement table, any identified incorrect ingredients are replaced with their accurate versions.

### Step 5. Populate drug_concept_stage

* The `drug_concept_stage` table is populated using prepared data from the following source tables:
  
|Entity|Source Table Name|
|---|---|
|Dose Form|forms, drug_form|
|Ingredient|ingredient_substances|
|Unit|unit_of_measure|
|Supplier|supplier, amps|
|Device|amps, ampps, vmps, vmpps|
|Drug Product|amps, ampps, vmps, vmpps|
|Brand Names|ampps|

* The `ingred_replacement` table is filled with Ingredient-VTM (Virtual Therapeutic Moiety) pairs, where such relationships exist in the source data.

### Step 6. Populate pc_stage (pack content)

* The `pc_stage` table is populated with product packaging attributes, such as pack size and units per pack, using data from the `comb_content_v` (Virtual Medicinal Product Packs combination content) and `comb_content_a` (Actual Medicinal Product Packs combination content) tables.
* Any modifiers that might have been lost during previous processing are restored to `pc_stage via` the creation of the `pc_modifier` table.
* Lost branded pack and clinical pack headers are added.

### Step 7. Populate internal_relationship_stage

The `internal_relationship_stage` table is populated with crucial links establishing relationships between various drug entities. This includes:

||||
|---|---|---|
|VMP|⇄|Ingredient|
|VMP|⇄|Dose Form|
|AMP|⇄|Dose Form|
|AMP|⇄|Supplier|
|VMPP|⇄|Ingredient|
|VMPP|⇄|Dose Form|
|AMPP|⇄|Dose Form|
|AMPP|⇄|Supplier|
|Monopacks|||


During the population of relationships, a dedicated process is executed to fix Dose Forms.

### Step 8. Prepare for ds_stage (drug strength) Population

#### 8.1. Initialize `ds_prototype` and Correct Dosages
* A temporary table named `ds_prototype` is created, specifically designed to store only VMP entities.
* Missing dosages for VMPs are identified and added to `ds_prototype`.
* Existing dosages within `ds_prototype` are reviewed and corrected where possible.
* Any incorrect or erroneous entities are either removed or updated within the `ds_prototype`.

#### 8.2. Populate with Attributes and Convert Units
* The `ds_prototype` table is populated with accurate Ingredients and Dose Form attributes.
* Unit and dosage conversions performed.

#### 8.3. Prepare for Manual Mapping and Integrate Results
* `tomap_vmps_ds` is prepared. This table is dedicated to facilitating the manual mapping of VMP drug strengths.
* Once the manual mapping process is completed, the ds_prototype table is updated, using data from `tomap_vmps_ds`.
* The `ds_parsed` table is refined and cleaned using the updated data from `tomap_vmps_ds`.

#### 8.4. Final Corrections for Dosages
* The `ds_prototype` updated, leveraging data from the `unit_of_measure` table.
* Finally, amount values are corrected within `ds_prototype` based on their respective drug units.

### Step 9. Populate ds_stage

`ds_stage` table is populated using data from the ds_prototype table. This involves transferring key drug strength and ingredient information, including:

* Drug and Ingredient Codes
* Amount Value and Unit
* Numerator Value and Unit
* Denominator Value and Unit
* Box Sizes

During this population process, any lost information or inconsistencies were identified and adjusted. 
Additionally, redundant or incorrect entries were identified and removed.

### Step 10. Prepare Entities for Manual Mapping

#### 10.1. Ingredients
* Pinpoint Ingredients that require manual mapping.
* Perform Manual Mapping.
* Upload the newly created Ingredient mappings to the `relationship_to_concept` table.

#### 10.2. Units
* Pinpoint Units that require manual mapping.
* Perform Manual Mapping.
* Upload the newly created Units mappings to the `relationship_to_concept` table.

#### 10.3. Dose Forms
* Pinpoint Dose Forms that require manual mapping.
* Perform Manual Mapping.
* Upload the newly created Dose Forms mappings to the `relationship_to_concept` table.

#### 10.4. `ds_stage` table is updated with all new mappings from the previous steps.

### Step 11. Brand Name and Supplier Mapping

#### 11.1. Brand Names

* Create the `amps_to_brands` table as a main storage for brand names.
* Create the `tofind_brands` table as a working one, used to generate a pool of brand names, performing pattern-matching and conversions.
* Insert identified brands into `amps_to_brands`.
* Identify brand names that require manual search and store it in `tofind_brands_man`.
* Assign OMOP concept codes to newly found brands and upload them to `amps_to_brands`.
* Identify and add brands missing from `drug_concept_stage`.
* Identify and perform brand name replacements where one brand name has different codes and remove extra ones from `drug_concept_stage`.
* Add links from AMPs and AMPPs to `internal_relationship_stage`.
* Create the `tomap_brands_man` table for manual brand name mappings.
* Insert manually mapped brands into `relationship_to_concept`.

#### 11.2. Suppliers

* Create the `tomap_supplier_man` table containing suppliers that require manual mapping, and modify it to facilitate the mapping process.
* Insert mapped suppliers into `relationship_to_concept`.
* Remove duplicate ingredients per supplier from `relationship_to_concept`.
* Generate OMOP concept codes for suppliers and update `drug_concept_stage`, `relationship_to_concept`, `ds_stage`, and `pc_stage` to replace old codes with new ones if they exist.
  
#### 11.3 General Data Integrity and Relationship Management
* Inherit AMP, VMPP, and AMPP Ingredient and Dose Form relations for empty `ds_stage` entries.
* Clean up incorrect and add correct monopacks to `internal_relationship_stage`.
* Perform deduplication of `internal_relationship_stage`, `relationship_to_concept`, and `drug_concept_stage`.
* Remove unused concepts from `drug_concept_stage`.
* Add supplier relations for packs into `internal_relationship_stage`.
* Remove entities from `internal_relationship_stage` that affect clear logic or cause errors, specifically:
    a. Marketed products that do not have either a pc_stage or ds_stage entry.
    b. Replace "powder" with a more precise Dose Form if such exists.
    c. AMPs and VMPs with an incorrect route when a licensed one is defined.
Remove codes from `pc_stage` that cause errors.

### Step 12. Manual Fixes

* Remove wrong entities from `drug_concept_stage`, `relationship_to_concept`, `internal_relationship_stage`, `ds_stage`.
* Add missed entities to `internal_relationship_stage`, `ds_stage`.
* Remove relationships to attributes for concepts, processed manually.
* Change column types AS they should be for BuildRxE

### At this point, everything should be prepared for [`BuildRxE()`](https://github.com/OHDSI/Vocabulary-v5.0/blob/4e371227ce73f35c8b6a5d554461a2f10b843ad3/working/packages/vocabulary_pack/BuildRxE.sql) run
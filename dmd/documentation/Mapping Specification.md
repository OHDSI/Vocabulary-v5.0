# Mapping Specification

## Objective

To ensure accurate, consistent, and clinically meaningful mappings from source drug entities to OMOP target concepts, prioritizing precision and semantic correctness. This process focuses strictly on the Drug domain, utilizing ingredients primarily from RxNorm and, only when absolutely necessary, from RxNorm Extension.

## General Mapping Principles

|Entity||Domain ID|Concept Class ID|Vocabulary ID|
|---|---|---|---|---|
|Drug|→|Drug|Brand Name, Branded Drug, Branded Drug Comp, Branded Drug Form, Branded Pack, Clinical Drug, Clinical Drug, Clinical Drug Form, Clinical Pack, Dose Form, Ingredient, Quant Branded Drug, Quant Clinical Drug|RxNorm, RxNorm Extension (ordered by priority)|
|Insulins|→|Drug|Brand Name, Branded Drug, Branded Drug Comp, Branded Drug Form, Branded Pack, Clinical Drug, Clinical Drug, Clinical Drug Form, Clinical Pack, Dose Form, Ingredient, Quant Branded Drug, Quant Clinical Drug|RxNorm, RxNorm Extension (ordered by priority)|
|Vaccines|→|Drug|CVX, Vaccine Group|CVX|
|Device|→|Device|Pharma/Biol Product, Physical Object, Substance|SNOMED|

1. When equivalent entities exist in both the dm+d source and the target vocabularies (RxNorm, RxNorm Extension, and SNOMED for devices), a one-to-one mapping must be established. Each of these mappings should accurately reflect the closest semantic equivalence to the original source concept.

2. When direct equivalence is not found, an attributive mapping approach must be used. This means mapping by component parts, such as ingredients, dose forms, or brand names, to populate drug tables. This process is crucial for enabling [`build_RxE()`](https://github.com/OHDSI/Vocabulary-v5.0/blob/4e371227ce73f35c8b6a5d554461a2f10b843ad3/working/packages/vocabulary_pack/BuildRxE.sql) to create accurate drug concepts.

3. Any unmapped rows or mappings that appear inaccurate under these strict criteria must be explicitly identified, flagged, and revisited for detailed manual reassessment.

4. The following entities must be filtered out due to potential execution issues, marked and highlighted for subsequent reassessment:
* Vaccines
* Insulins
* Devices

### Ingredients

1. For combo-drugs, if no single concept fully captures the source’s semantics, consider the mapping into multiple closely related target concepts. This is particularly applicable for herbal or plant-based substances, which can vary significantly (e.g., root, leaf, flower, bark, oil, seed, pollen, preparation, dry or liquid extracts).

Maps to multiple entities is preferable to choosing a single incorrect or overly broad concept. For example:
	
`Catechu` could be mapped to:

||||||
|---|---|---|---|---|
|Catechu|→|Acacia catechu whole extract|RxNorm|Ingredient|
||→|Acacia catechu bark extract|RxNorm|Ingredient|
||→|Acacia catechu wood extract|RxNorm|Ingredient|
||→|Areca Catechu|RxNorm Extension|Ingredient|
||→|black catechu extract|RxNorm|Ingredient|

2. Handling Ambiguous or Compound Ingredients:

* If the ingredient explicitly refers to a specific part or preparation type (e.g., "dry extract," "oil," "pollen," "root," "leaves," "flowers," "powder"), the mapping must respect this specificity.

* When faced with ambiguity (e.g., “preparation” vs. “extract”), the source concept should be mapped to multiple specific OMOP concepts, clearly documented with reasoning and precedence.

## Precedence
To ensure the accuracy and relevance of our mapped concepts, we assign a numerical precedence score (1-5) to each. This score reflects the semantic closeness between the source and target concepts, with 1 indicating an ideal match and 5 representing a poor, generally avoidable, match. Brief overview of possible precedence listed below:

|Precedence|Meaning|
|---|---|
|**1**|Ideal semantic match (direct, exact semantic equivalence)|
|**2**|Good semantic match, minor nuances differ (e.g., "powder" vs. "dry extract")|
|**3**|Acceptable semantic match, but involves broader generalization (e.g., "fruit extract" when source specifies “fruit powder”)|
|**4**|Weak semantic match; involves significant compromise (e.g., broader plant family instead of exact species)|
|**5**|Poor semantic match; very distant or only vaguely related concepts (should be avoided unless there are no alternatives)|

# Mapping: Staging Tables

To run the [`build_RxE()`](https://github.com/OHDSI/Vocabulary-v5.0/blob/4e371227ce73f35c8b6a5d554461a2f10b843ad3/working/packages/vocabulary_pack/BuildRxE.sql), the following staging tables must first be populated: 
* `drug_concept_stage`
* `internal_relationship_stage`
* `ds_stage`
* `pc_stage`

### drug_concept_stage

The `drug_concept_stage` table temporarily stores preliminary concept information, transforming data extracted from dm+d source files.

Here is an example of how the AMPP `Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet` is populated in this table:

|Column Name|Value|Value Source|Rule|
|---|---|---|---|
|concept_name|Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet|`ampps.nm`|-|
|vocabulary_id|dm+d|Autoassigned|`dm+d` set for all cases|
|concept_class_id|Drug Product|Autoassigned|Set based on source data within xml|
|source_concept_class_id|AMPP|Autoassigned|Set based on source data within xml|
|standard_concept|NULL|Autoassigned|Set based on presence of mappings|
|concept_code|7123911000001109|`amps.appid`|-|
|possible_excipient|NULL|Autoassigned|Set based on source data within xml|
|domain_id|Drug|Autoassigned|`Drug` set for all cases, that after filtering out the Devices|
|valid_start_date|1970-01-01|Autoassigned|Get from `ampps.dicsdt` OR set based on presence/absence of entities in Athena| 
|valid_end_date|2099-12-31|Autoassigned|Set based on presence/absence of entities in Athena, mapping change|
|invalid_reason|NULL|Autoassigned|Get from `ampps.invalid` OR set based on presence/absence of entities in Athena, mapping change|

## pc_stage

The `pc_stage` table acts as a staging area for information related to medicinal product packs.

Here is an example of how the AMPP `Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet` is populated in this table:

|Column Name|Value|Value Name|Value Source|Rule|
|---|---|---|---|---|
|pack_concept_code|5487511000001102|Trisequens tablets|`comb_content_a.prntappid`|-|
|drug_concept_code|7123911000001109|Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet|`ampps.appid`|-|
|amount|18|18|`vmpps.qtyval`|Get from respective to `ampps` `vmpps` table|
|box_size|NULL|NULL|`ampps.nm`|-|

## internal_relationship_stage

The `internal_relationship_stage` table is a crucial staging area for defining and managing the internal relationships between drug and device concepts and their associated attributes within the dm+d vocabulary. This table allows for a flexible representation of how drugs relate to their components (i.e. Ingredients, Dose Forms, Suppliers).

Here is an example of how the AMPP `Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet` generates entries in this table. For this product, three entries exist:

|Entry Number|Column Name|Value|Value Name|Value Source|
|---|---|---|---|---|
|Entry 1|Concept Code 1|7123911000001109|Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet|`amps.appid`|
||Concept Code 2|126172005|Estradiol|`virtual_product_ingredient.isid`|
|Entry 2|Concept Code 1|7123911000001109|Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet|`amps.appid`|
||Concept Code 2|2091401000001103|Waymade Healthcare Plc|`amps.suppcd`|
|Entry 3|Concept Code 1|7123911000001109|Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet|`amps.appid`|
||Concept Code 2|421026006|Oral tablet|`drug_form.formcd`|

## ds_stage

The `ds_stage` table serves as a staging area for capturing detailed strength and dosage information for drug concepts.

Here is an example of how the AMPP `Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet` is populated in this table:

|Column Name|Value|Value Name|Value Source|
|---|---|---|---|
|drug_concept_code|7123911000001109|Estradiol 1mg tablets (Waymade Healthcare Plc) 18 tablet|`amps.appid`|
|ingredient_concept_code|126172005|Estradiol|`virtual_product_ingredient.isid`|
|amount_value|1|1|`virtual_product_ingredient.strnt_nmrtr_val`|
|amount_unit|mg|mg|`vmpps.qty_uomcd`|
|numerator_value|NULL|NULL||
|numerator_unit|NULL|NULL||
|denominator_value|NULL|NULL||
|denominator_unit|NULL|NULL||
|box_size|18|18|`vmpps.qtyval`|

## Gaps and Limitations

While comprehensive, the dm+d vocabulary has potential gaps and limitations that could affect its integration and use:

* **Device Coverage**: Primarily focused on medicinal products, device coverage (VAP and AAP) is not as extensive, potentially leading to challenges in representing certain medical devices.
* **Granularity**: The level of detail might not always suffice for specific use cases (e.g., detailed device models or material compositions).
* **Mapping Completeness**: Direct, exhaustive mappings to external terminologies (like SNOMED CT or RxNorm) might be absent, requiring careful mapping strategies or local extensions.
* **Data Quality**: Despite efforts, some inconsistencies, errors, or omissions might persist.
* **Timeliness of Updates**: Update frequencies might not align with other systems, leading to temporary discrepancies.
* **Complexity of Relationships**: Navigating complex relationships between dm+d entities (e.g., VTM to AMPP hierarchy) requires thorough understanding.
* **Lack of Standard External Codes**: Direct mappings to widely adopted international standard codes are often absent in the source data, necessitating external mapping.
* **Combination Products**: Representing combination medicinal products and devices can be challenging due to varied descriptions and coding.
* **Supplier Information**: Detail and consistency of supplier information can vary, limiting its use for certain applications.

Implementers must be aware of these limitations and plan integration strategies accordingly, including processes for addressing unmapped concepts or data quality issues.

## Recommendations and Next Steps

For effective dm+d integration and utilization, consider these **recommendations**:

* **Establish a Robust ETL Pipeline**: Implement an automated ETL pipeline for consistent and reliable data processing.
* **Prioritize Data Quality**: Integrate rigorous validation and cleaning steps into the ETL process.
* **Develop Comprehensive Mapping Strategies**: Invest in accurate mappings between dm+d concepts and external standard terminologies (e.g., SNOMED CT, RxNorm).
* **Address Device Coverage**: Assess device coverage for systems with significant requirements and supplement with other vocabularies or local codes if needed.
* **Granularity Assessment**: Evaluate if dm+d's detail meets target system needs; extend the data model or incorporate additional sources if not.
* **Implement Version Management**: Establish clear processes for managing different dm+d versions and ensuring system alignment.
* **Foster Collaboration**: Encourage collaboration among data engineers, clinical informaticists, and domain experts.
* **Continuous Monitoring and Improvement**: Track ETL pipeline performance and data quality, refining processes based on feedback.
* **Contribute to Community Efforts**: Consider contributing to dm+d mapping and standardization initiatives.
* **Stay Informed About Updates**: Keep abreast of dm+d changes and adjust processes accordingly.

**Next Steps**:

* **Detailed System Analysis**: Understand target system requirements and data models.
* **Proof of Concept (POC)**: Pilot proposed ETL and mapping strategies.
* **Tool and Technology Selection**: Choose appropriate tools for ETL and mapping.
* **Team Training**: Train team members on dm+d, ETL, and mapping.
* **Documentation**: Maintain comprehensive documentation of the integration process.
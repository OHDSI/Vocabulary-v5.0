Update of ISBT

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory ISBT

1. Open ISBT-128-Product-Description-Code-Database.accdb and load
"Product Description Codes" into ISBT_PRODUCT_DESC
"Classes" into ISBT_CLASSES
"Modifiers" into ISBT_MODIFIERS
"Attribute values" into ISBT_ATTRIBUTE_VALUES
"Attribute groups" into ISBT_ATTRIBUTE_GROUPS
"Categories" into ISBT_CATEGORIES
"Modifier Category Map" into ISBT_MODIFIER_CATEGORY_MAP

2. Run load_stage.sql (with updated pVocabularyDate = Version)
3. Run generic_update.sql (from working directory)

 
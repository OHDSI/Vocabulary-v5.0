CREATE OR REPLACE PACKAGE DEVV5.VOCABULARY_PACK
   AUTHID CURRENT_USER
IS
   /*
    Adds (if not exists) column 'latest_update' to 'vocabulary' table and sets it to pVocabularyDate value
    Also adds 'dev_schema_name' column what needs for 'CreateSynForManualTable' procedure
    If pAppendVocabulary is set to TRUE, then procedure DOES NOT drops any columns, just updates the 'latest_update' and 'dev_schema_name'
   */
   PROCEDURE SetLatestUpdate (pVocabularyName        IN VARCHAR2,
                              pVocabularyDate        IN DATE,
                              pVocabularyVersion     IN vocabulary.vocabulary_version%TYPE,
                              pVocabularyDevSchema   IN VARCHAR2,
                              pAppendVocabulary      IN BOOLEAN DEFAULT FALSE);

   /*
    Inserts manual relationships from concept_relationship_manual in concept_relationship_stage
   */
   PROCEDURE ProcessManualRelationships;

   /*
    Working with 'Concept replaced by', 'Concept same_as to', etc mappings:
    1. Delete duplicate replacement mappings (one concept has multiply target concepts)
    2. Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
    3. Deprecate concepts if we have no active replacement record in the concept_relationship_stage
    4. Deprecate replacement records if target concept was depreceted
    5. Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
   */
   PROCEDURE CheckReplacementMappings;


   /*
    Deprecates 'Maps to' mappings to deprecated ('D') and upgraded ('U') concepts
   */
   PROCEDURE DeprecateWrongMAPSTO;

   /*
    Adds mapping from deprecated to fresh concepts
   */
   PROCEDURE AddFreshMAPSTO;

   /*
    Deletes ambiguous 'Maps to' mappings following by rules:
    1. if we have 'true' mappings to Ingredient or Clinical Drug Comp, then delete all others mappings
    2. if we don't have 'true' mappings, then leave only one fresh mapping
    3. if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then delete mappings to Ingredients, which have mappings to Clinical Drug Comp
   */
   PROCEDURE DeleteAmbiguousMAPSTO;
END VOCABULARY_PACK;
/
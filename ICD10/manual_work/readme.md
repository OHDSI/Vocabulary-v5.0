### A manual mapping check for mechanical and semantic errors

* This script should be run BEFORE insert of refeshed or newly added mappings into concept_relationship_manual. 
* During mapping of ICD codes we recommend to use the following relationship_ids:
  * **"Maps to"** is used for 1-to-1 FULL equivalent mapping only
  * **"Maps to" + "Maps to value"** is used for for Observations and Measurements with results
  * **"Is a"** is a temporary relationship used for this check only and applicable for 1-to-1 PARTIAL equivalent AND 1-to-many mappings.
* Preserve a manual table with 'Is a' relationships, but change 'Is a' to 'Maps to' during the insertion into the concept_relatioship_manual (e.g. using CASE WHEN).

**Required fields in a manual table** 
  * icd_id INT, 
  * icd_code VARHCAR, 
  * icd_name VARHCAR, 
  * relationship_id VARCHAR, 
  * concept_id INT, 
  * concept_code VARCHAR, 
  * concept_name VARCHAR

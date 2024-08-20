--TODO: Fill the readme with the information derived from:
https://docs.google.com/document/d/1tjkAvIlVXwSw_H83hV7F4hXw6YuVXng7fkwit7Yfaoo/edit#heading=h.sqj179hres8c

### Recomanditions for relationship_ids
  * **"Maps to"** is used for 1-to-1 FULL equivalent mapping only
  * **"Maps to" + "Maps to value"** is used for for Observations and Measurements with results
  * **"Is a"** is a temporary relationship used for this check only and applicable for 1-to-1 PARTIAL equivalent AND 1-to-many mappings.
Preserve a manual table with 'Is a' relationships, but change 'Is a' to 'Maps to' during the insertion into the concept_relatioship_manual (e.g. using CASE WHEN).

#### Required fields in a manual table 
- icd_code VARHCAR, 
- icd_name VARHCAR, 
- repl_by_relationship VARCHAR, 
- repl_by_id INT, 
- repl_by_code VARCHAR, 
- repl_by_name VARCHAR,
- repl_by_domain VARCHAR,
- repl_by_vocabulary VARCHAR

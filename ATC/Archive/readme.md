This is the first integration of ATC into the OMOP Vocabularies. 

The code is outdated, left here for the backward compatibility

Update of ATC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED and RxNorm must be loaded first with the full release cycle.
- Working directory ATC.

1. Run load_stage.sql
2. Run generic_update: devv5.GenericUpdate();

 
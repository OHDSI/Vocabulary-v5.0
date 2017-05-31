# BDPM source conversion

source:
http://base-donnees-publique.medicaments.gouv.fr/telechargement.php
current version of BDPM vocabulary itself is 29/05/2017
"Fichier des présentations (date de mise à jour : 29/05/2017, 3931 Ko)"
hm. did they update this thing everyday?

plan of work:
1. Anna - formalize manual tables and post them on github
2. Upload tables (source and Anna's) 
with source - check if there is no format changes compare to last year release.
Anna's - check if they still can be usable (for example manual table has relationship to a very termporary entity (OMOP123).
3. run fast recreate and load_stage
--easiest way of old concepts support - they did this on Canada DPD, looks like it'll work well here too:
if concept has it's own code - it's not even a question
if concept has OMOP code - merge it with an old concept using (concept_name)
so if name is not equal just give a new concept_code, no reminiscences:)
use temporary query, otherwise you'll get a holes in sequence.
apply checks anywhere you have a manual table
 - does it covers all the data required on this step?
 - does it meets the changed rules (we got rid from precedence, we map to RxNorm-existing units in relationship_to_concept, etc.)
 - Check the Quality of manual table - can give it to OLena or Polina to make manual review.
4. run generic_update with checks
5. release
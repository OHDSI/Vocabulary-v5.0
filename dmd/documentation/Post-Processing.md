## Post-Processing

Post-processing is a crucial step after executing [`build_RxE.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/4e371227ce73f35c8b6a5d554461a2f10b843ad3/working/packages/vocabulary_pack/BuildRxE.sql). It ensures that the integrated dm+d content aligns with OHDSI Standardized Vocabularies and maintains semantic integrity across relationships. While [`build_RxE.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/4e371227ce73f35c8b6a5d554461a2f10b843ad3/working/packages/vocabulary_pack/BuildRxE.sql) handles the core construction of RxNorm Extension mappings, it does not fully address conflicts, priority rules, deprecated relationships, or the integration of manual curation. Therefore, post-processing is essential for applying logical refinements, enforcing vocabulary governance rules, and preparing the data for final integration into the OMOP Standardized Vocabularies framework.

This post-processing primarily affects the `concept_stage` and `concept_relationship_stage` tables.

To delve deeper into these steps, refer to postprocessing.sql`add link here`.

---

#### `concept_relationship_stage` post-processing:

* Replace mapping for concepts which are already exist, but change attributes.
* Add mappings from dm+d to SNOMED Devices that already exist in Athena. These might have been lost during a vocabulary refresh.
* When multiple mappings exist for a single dm+d entity, SNOMED mappings are given the highest priority.
* Delete relationships that are marked as `Deprecated` and do not exist in Athena.
* Retrieve replacement mappings for deprecated VMPs (Virtual Medicinal Products) if they exist in the sources but were missed during initial processing.
* Deprecate old mappings from previous vocabulary refreshes, except for internal dm+d relationships.
* Delete mappings if a mapping for the same entity already exists in `concept_relationship_manual`.
* Perform deduplication of entries.
* Run relevant [`Vocabulary Pack`](https://github.com/OHDSI/Vocabulary-v5.0/tree/4e371227ce73f35c8b6a5d554461a2f10b843ad3/working/packages/vocabulary_pack) functions to apply additional rules and transformations.
* Deprecate outdated ingredient mappings.

---

#### `concept_stage` post-processing:

* Delete unnecessary concepts.
* Manually destandardize Devices within dm+d if they have new mappings to SNOMED.
* Add VMPs that already exist in Athena (meaning they were applied and proven in previous releases) but may have been lost from the sources.
* Perform deduplication of entries.
* Run relevant [`Vocabulary Pack`](https://github.com/OHDSI/Vocabulary-v5.0/tree/4e371227ce73f35c8b6a5d554461a2f10b843ad3/working/packages/vocabulary_pack) functions to apply additional rules and transformations.
* Trim names to remove leading or trailing spaces.
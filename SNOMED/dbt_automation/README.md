# dbt_automation

This folder contains code for [data build tool](https://github.com/dbt-labs/dbt-core)(dbt) automation of the process of updating a vocabulary. 

# status
in-development

# purpose
dbt allows for the atomic representation of select statements into "models" which relationships can be visualized and tests preformed.

The following are guiding ideas when implementing this framework:

1. It should be possible to update a vocabulary with a single command as long as all configurations are set
   1.1. Furthering automated processes and testing similar to that used in software development reduces human error and improves the reliability of the vocabulary 
2. Names should have meaning that is apperant. If the meaning is not readily apperant it should at least be readily referencable. 
3. Atomicity should be practiced to prevent partial updates and conceptual coherence
4. Processes should be accessible to the public and understandable by non-technical readers


# TODO

- [x] Implement basic structure of a dbt project
- [x] Translate create_source_tables.sql to dbt models
- [x] Translate load_stage.sql to dbt models
- [ ] Translate snomed_refresh.sql to dbt models
- [ ] Translate load_stage_checks.sql to dbt tests
- [ ] Translate manual_checks_after_generic.sql to dbt tests
- [ ] Develop process for gathering vocabularies through WebAPIs
- [ ] Integrate hash validation to check downloaded vocabularies
- [ ] Translate process for organizing and renaming downloaded vocabularies
- [ ] Develop process for ingesting vocabularies
- [ ] Implement standard dbt visualizations and reports
- [ ] Perform initial run and report out results
- [ ] Develop proposal for scheduling tooling
- [ ] Planning for prioritizing other vocabularies
### Manual content processing:
It is essential to follow the steps outlined below in order to modify the canonical loadstage, as certain content may be overlooked at both the concept and relationship levels. Prior to commencing the loadstage, ensure that the manual tables provided in the list below are populated.

1.In order to prevent the disappearance of synonyms caused by changes in the source content, the concept_synonym_manual table is necessary. 
Extract the following csv file into the concept_synonym_manual table:
https://docs.google.com/spreadsheets/d/17C887UjOZxPPJ0_H58AUU7mFuEq2wVD_EHQLpW2vth8/edit#gid=0
;

2. To enable the maintenance or creation of new links between source elements and OMOP targets, the concept_relationship_manual table is required
Extract the following csv file into the concept_relationship_manual table: https://docs.google.com/spreadsheets/d/1THz5xZAkmdqUSAGct9z8Jh6f00_FSt49J89p55rRhDo/edit#gid=0
;

The DDL for manual tables are stored here -  https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/DevV5_DDL.sql

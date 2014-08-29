Vocabulary_ID=17 Read Codes

The following describes the procedure to update the READ vocabulary  with the latest release of the source.

Only a source_to_concept_map is updated


1.1 Scripts

Script Name Description
- 17_create_schema.sql  Create prestage-stage schema with tables and indexes
- 17_rcsctmap2_uk.ctl  Control file for loading rcsctmap2_uk_YYYYMMDD000001.txt
- 17_keyv2.ctl	Control file for loading keyv2.all
- 17_transform_row_maps.sql Convert and store in stage table SOURCE_TO_CONCEPT_MAP_STAGE
- 17_load_maps.sql  Load only new maps into SOURCE_TO_CONCEPT_MAP table, add invalid code information


1.2 Download data from source

Download latest release files from the Health and Social Care Information Centre TRUD 
(login under https://isd.hscic.gov.uk/trud3/user/guest/group/0/login/form) 
section "UK Read".

1.2.1	Read code distrbution file
	
nhs_readv2_VV.0.0_YYYYMMDD000001.zip from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/9/subpack/21/releases
(Subscription "NHS UK Read Codes Version 2"). "VV" stands for the current version number, "YYYYMMDD" for the release date.
The latest file size was ~8.6 MB.

1.2.2 Read code to SNOMED CT mapping file

nhs_datamigration_VV.0.0_YYYYMMDD000001.zip from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/9/subpack/9/releases 
(Subscription "NHS Data Migration"). "VV" stands for the current version number, "YYYYMMDD" for the release date.
The latest zip file size was ~140 MB.


1.3 Build Database Schema

All tables will be located in the schema READ_<DateOfSourceFile> as following: READ_20140131
The following steps will create a schema and will grant to a schema owner appropriate permissions. 

In addition to the schema, it will create table to load raw data RCTSCTMAP_UK and KEYV2 as well as staging tables: 

CONCEPT_STAGE, CONCEPT_ANCESTOR_STAGE, 
CONCEPT_RELATIONSHIP_STAGE, 
SOURCE_TO_CONCEPT_MAP_STAGE

	$ sqlplus System/<SystemPass>@DEV @17_create_schema.sql <READ_Schema> <Pass_READ_Schema>

The Format of the READ schema should be READ_YYYYMMDD (e.g. READ_20140131)

The staging tables match Vocabulary schema version 4.0 with slight modification. Modifications made to the tables are:

- CONCEPT_STAGE.CONCEPT_ID is nullable
- SOURCE_TO_CONCEPT_MAP_STAGE.SOURCE_TO_CONCEPT_MAP_ID is nullable
- CONCEPT_RELATIONSHIP_STAGE.REL_ID is nullable


1.4 Raw data load into Oracle tables

1.4.1 Extract files from the zip archive into the current directory

	$ unzip -u nhs_readv2_17.0.0_YYYYMMDD000001.zip
	$ unzip -u nhs_datamigration_17.0.0_YYYYMMDD000001.zip

1.4.2 Verify that the following files have been created:

	nhs_readv2_17.0.0_20140401000001\V2\Unified\Keyv2.all (Latest file size ~15.2MB)
	nhs_datamigration_17.0.0_20140401000001\Mapping Tables\Updated\Clinically Assured\rcsctmap2_uk_20140401000001.txt
	(latest file size ~8.6 MB)
	
Copy these files into the current directory.

1.4.3    Load FDA raw data into Oracle. 

  $ sqlldr READ_YYYYMMDD/myPass@DEV control=17_keyv2.ctl
  $ sqlldr READ_YYYYMMDD/myPass@DEV control=17_rcsctmap2_uk.ctl

1.4.4 Verify that files with extension .bad are empty, no records have been rejected.

1.4.5 Copy data and intermediate files to backup area. In this step, downloaded files will be archived to preserve source of the data. Discuss a location of backup area with your system administrator.         

  $ cp -Ru /data/READ/*.zip /data/backup_area ; cp -Ru /data/READ/*.log /data/backup_area

1.4.6  Verify that number of records loaded is equivalent to prior production load

 $ sqlplus READ_20140131/myPass@DEV_VOCAB

Execute commands:

    SELECT count(*) FROM KEYV2; (expect something around 140,000 records)
    SELECT count(*) FROM RCSCTMAP2_UK; (expect something around 130,000 records)


1.5 Loading to staging tables from raw

1.5.1 Convert and store in staging table maps

  $  sqlplus READ_YYYMMDD/myPass@DEV @17_transform_row_maps.sql

1.5.2  Verify that number of records loaded is equivalent to prior production load

In this step we will verify that number of active records in staging tables is valid prior to transfer data to historical DEV schema. 

  a. Number of Records in stage table
  b. Number of records in DEV schema not deleted (active, prior load production)
  c. How many records would be added to DEV schema table
	d. How many active DEV records will be marked for deletion

In most cases  number of records in stage (a) should be greater than number of active records in production (b) 
In rare occasion that might not be the case. It is responsibility of the developer running the scripts to verify that that is the the valid.

 $ sqlplus READ_YYYYMMDD/myPass@DEV_VOCAB

Execute the following SQL commands (also in 17_check.sql)

-- Run this after 17_transform_row_maps.sql and before 17_load_maps.sql
select '1. Num Rec in stage' as scr, count(8) as cnt
from source_to_concept_map_stage c
where c.source_vocabulary_id in (17)
union all
select '2. Num Rec in DEV not deleted' as scr, count(8) as cnt
from dev.source_to_concept_map d
where d.source_vocabulary_id in (17)
  and d.target_vocabulary_id in (1)
  and nvl (d.invalid_reason, 'X') <> 'D'
union all
select '3. How many records would be new in DEV added' as scr, count(8) as cnt
from source_to_concept_map_stage c
where c.source_vocabulary_id in (17) and c.target_vocabulary_id in (1)
  and not exists (
    select 1
    from dev.source_to_concept_map d
    where d.source_vocabulary_id in (17)
      and c.source_code = d.source_code
      and d.source_vocabulary_id = c.source_vocabulary_id
      and d.mapping_type = c.mapping_type
      and d.target_concept_id = c.target_concept_id
      and d.target_vocabulary_id = c.target_vocabulary_id
  )
union all
select '4. How many DEV active will be marked for deletion' as scr, count(8) as cnt
from dev.source_to_concept_map d
where d.source_vocabulary_id in (17)
  and d.target_vocabulary_id in (1)
  and nvl (d.invalid_reason, 'X') <> 'D'
  and d.valid_start_date < to_date (substr (user, regexp_instr (user, '_[[:digit:]]') + 1, 256), 'yyyymmdd')
  and not exists (
    select 1
    from source_to_concept_map_stage c
    where c.source_vocabulary_id in (17)
    and c.source_code = d.source_code
    and d.source_vocabulary_id = c.source_vocabulary_id
    and d.mapping_type = c.mapping_type
    and d.target_concept_id = c.target_concept_id
    and d.target_vocabulary_id = c.target_vocabulary_id
  )
  and exists (
    select 1
    from source_to_concept_map_stage c
    where d.source_code = c.source_code
    and d.source_vocabulary_id = c.source_vocabulary_id
    and d.mapping_type = c.mapping_type
    and d.target_vocabulary_id = c.target_vocabulary_id
  )
;


Current Result:
1. Num Rec in stage	99676
2. Num Rec in DEV not deleted	51667
3. How many records would be new in DEV added	99650
4. How many DEV active will be marked for deletion	0

1.5.3    Load new maps into DEV schema concept table

Mark deprecated concepts as deleted. Transfer records from SOURCE_TO_CONCEPT_MAP_STAGE to DEV.SOURCE_TO_CONCEPT_MAP table

  $  sqlplus READ_20140131/myPass@DEV_VOCAB @17_load_maps.sql 

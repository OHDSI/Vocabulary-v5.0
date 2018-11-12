/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2018
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CDM',
	pVocabularyDate			=> (SELECT MAX(vocabulary_date) FROM sources.cdm_tables), --always use maximum date and version
	pVocabularyVersion		=> (SELECT MAX(vocabulary_version) FROM sources.cdm_tables),
	pVocabularyDevSchema	=> 'DEV_CDM'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Loop all unparsed versions
DO $_$
DECLARE
cdm record;
z int4;
BEGIN
	--create sequence for concept codes
	select coalesce(max(replace(c.concept_code, 'CDM','')::int4),0)+1 into z from concept c where c.vocabulary_id='CDM' and c.concept_code like 'CDM%' and c.concept_class_id<>'CDM';
	drop sequence if exists cdm_seq;
	execute 'create sequence cdm_seq increment by 1 start with ' || z || ' no cycle cache 20';
	
	for cdm in (
		select s0.ddl_release_id, s0.ddl_date, s0.vocabulary_version, l.prev_vocabulary_version, l.prev_ddl_release_id from (
			select distinct cd.ddl_release_id, cd.ddl_date, cd.vocabulary_version from sources.cdm_tables cd 
			where not exists (select 1 from concept c where c.vocabulary_id='CDM' and c.concept_code=cd.vocabulary_version)
		) s0
		left join lateral
		(
			--determine the affected version, because after 5.0.1 comes 4.0.0 for historical reasons, or after 5.3.1 comes 5.2.2 for support reason
			select ct.vocabulary_version as prev_vocabulary_version, ct.vocabulary_date, ct.ddl_release_id as prev_ddl_release_id from sources.cdm_tables ct
			where ct.ddl_date<s0.ddl_date and upper(ct.vocabulary_version)<upper(s0.vocabulary_version)
			order by upper(ct.vocabulary_version) desc, ct.ddl_date desc limit 1
		) l on true
		order by ddl_date
	) loop
		--insert the 'release concept'
		insert into concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
		values ('OMOP '||replace(cdm.vocabulary_version,'v','Version '), 'Metadata', 'CDM','CDM','S',cdm.vocabulary_version,cdm.ddl_date::date,to_date ('20991231', 'yyyymmdd'),null);
		
		--add whole release
		if cdm.prev_ddl_release_id is null then
			--insert the 'Fields'
			insert into concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
			select cd.table_name||'.'||cd.column_name as concept_name,
				null as domain_id, --temporary use null instead of 'Metadata'
				'CDM' as vocabulary_id,
				'Field' as concept_class_id,
				'S' as standard_concept,
				'CDM'||nextval('cdm_seq') as concept_code,
				cd.vocabulary_date as valid_start_date,
				to_date ('20991231', 'yyyymmdd') as valid_end_date,
				null as invalid_reason
			from sources.cdm_tables cd
			where cd.ddl_release_id=cdm.ddl_release_id;
			
			--insert the 'Tables'
			insert into concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
			select s0.concept_name,
				s0.domain_id,
				s0.vocabulary_id,
				s0.concept_class_id,
				s0.standard_concept,
				'CDM'||nextval('cdm_seq') as concept_code,
				s0.valid_start_date,
				s0.valid_end_date,
				s0.invalid_reason
			from (
				select distinct cd.table_name as concept_name,
					null as domain_id, --temporary use null instead of 'Metadata'
					'CDM' as vocabulary_id,
					'Table' as concept_class_id,
					'S' as standard_concept,
					cd.vocabulary_date as valid_start_date,
					to_date ('20991231', 'yyyymmdd') as valid_end_date,
					null as invalid_reason
				from sources.cdm_tables cd
				where cd.ddl_release_id=cdm.ddl_release_id
			) as s0;
		else --add only diff
			--create 'Subsumes' between the new version and the old
			insert into concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
			values (cdm.vocabulary_version,cdm.prev_vocabulary_version,'CDM','CDM','Subsumes',cdm.ddl_date::date,to_date('20991231', 'yyyymmdd'),null);
			
			--add mappings for same concepts (table_name.column_name or table_name)
			insert into concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
			select cdm.vocabulary_version as concept_code_1,
				cur.concept_code as concept_code_2,
				'CDM' as vocabulary_id_1,
				'CDM' as vocabulary_id_2,
				cur.relationship_id as relationship_id,
				cdm.ddl_date::date as valid_start_date,
				to_date('20991231', 'yyyymmdd') as valid_end_date,
				null as invalid_reason
			from (--get concept codes from previous release
				select c2.concept_code, c2.concept_name, cr.relationship_id from concept_relationship cr
				join concept c1 on c1.concept_id=cr.concept_id_1 and c1.vocabulary_id='CDM' and c1.concept_code=cdm.prev_vocabulary_version
				join concept c2 on c2.concept_id=cr.concept_id_2 and c2.vocabulary_id='CDM'
				where cr.relationship_id='Version contains' and cr.invalid_reason is null
				union all
				--but for now they may not be in the base tables
				select cs2.concept_code, cs2.concept_name, crs.relationship_id from concept_relationship_stage crs
				join concept_stage cs1 on cs1.concept_code=crs.concept_code_1 and cs1.concept_code=cdm.prev_vocabulary_version
				join concept_stage cs2 on cs2.concept_code=crs.concept_code_2
				where crs.relationship_id='Version contains' and crs.invalid_reason is null
			) cur
			where exists (
				select 1 from sources.cdm_tables cd1
				join sources.cdm_tables cd2 on cd2.table_name=cd1.table_name and cd2.column_name=cd1.column_name and cd2.ordinal_position=cd1.ordinal_position
				and (cd2.column_default=cd1.column_default or (cd2.column_default is null and cd1.column_default is null))
				and cd2.is_nullable=cd1.is_nullable and cd2.column_type=cd1.column_type 
				and (cd2.character_maximum_length=cd1.character_maximum_length or (cd2.character_maximum_length is null and cd1.character_maximum_length is null))
				and cd2.ddl_release_id=cdm.prev_ddl_release_id
				where cd1.ddl_release_id=cdm.ddl_release_id
				and cur.concept_name=cd1.table_name||'.'||cd1.column_name --for fields
			)
			or exists (
				select 1 from sources.cdm_tables cd1
				join sources.cdm_tables cd2 on cd2.table_name=cd1.table_name
				and cd2.ddl_release_id=cdm.prev_ddl_release_id
				where cd1.ddl_release_id=cdm.ddl_release_id
				and cur.concept_name=cd1.table_name --for tables
			);
			
			--add new concept codes
			--insert the new 'Fields' (if any)
			insert into concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
			select cd.table_name||'.'||cd.column_name as concept_name,
				null as domain_id, --temporary use null instead of 'Metadata'
				'CDM' as vocabulary_id,
				'Field' as concept_class_id,
				'S' as standard_concept,
				'CDM'||nextval('cdm_seq') as concept_code,
				cd.vocabulary_date as valid_start_date,
				to_date ('20991231', 'yyyymmdd') as valid_end_date,
				null as invalid_reason
			from sources.cdm_tables cd
			where cd.ddl_release_id=cdm.ddl_release_id
			and not exists (
				select 1 from sources.cdm_tables cd_int
				where cd_int.table_name=cd.table_name and cd_int.column_name=cd.column_name and cd_int.ordinal_position=cd.ordinal_position
				and (cd_int.column_default=cd.column_default or (cd_int.column_default is null and cd.column_default is null))
				and cd_int.is_nullable=cd.is_nullable and cd_int.column_type=cd.column_type 
				and (cd_int.character_maximum_length=cd.character_maximum_length or (cd_int.character_maximum_length is null and cd.character_maximum_length is null))
				and cd_int.ddl_release_id=cdm.prev_ddl_release_id
			);
			
			--insert the new 'Tables' (if any)
			insert into concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
			select s0.concept_name,
				s0.domain_id,
				s0.vocabulary_id,
				s0.concept_class_id,
				s0.standard_concept,
				'CDM'||nextval('cdm_seq') as concept_code,
				s0.valid_start_date,
				s0.valid_end_date,
				s0.invalid_reason
			from (
				select distinct cd.table_name as concept_name,
					null as domain_id, --temporary use null instead of 'Metadata'
					'CDM' as vocabulary_id,
					'Table' as concept_class_id,
					'S' as standard_concept,
					cd.vocabulary_date as valid_start_date,
					to_date ('20991231', 'yyyymmdd') as valid_end_date,
					null as invalid_reason
				from sources.cdm_tables cd
				where cd.ddl_release_id=cdm.ddl_release_id
				and not exists (
					select 1 from sources.cdm_tables cd_int
					where cd_int.table_name=cd.table_name
					and cd_int.ddl_release_id=cdm.prev_ddl_release_id
				)
			) as s0;
		end if;
		
		--create new relationships between the 'Table' and the 'Field' (domain 'Subsumes' domain.domain_id)
		insert into concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
		select cs1.concept_code as concept_code_1,
			cs2.concept_code as concept_code_2,
			'CDM' as vocabulary_id_1,
			'CDM' as vocabulary_id_2,
			'Subsumes' as relationship_id,
			cdm.ddl_date::date as valid_start_date,
			to_date('20991231', 'yyyymmdd') as valid_end_date,
			null as invalid_reason
		from concept_stage cs1
		join concept_stage cs2 on cs2.concept_name like cs1.concept_name || '.%'
		and cs2.concept_class_id='Field' and cs2.domain_id is null
		where cs1.concept_class_id='Table' and cs1.domain_id is null;
		
		--create mappings from the 'release concept' to affected version
		insert into concept_relationship_stage (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
		select cdm.vocabulary_version as concept_code_1,
			cs.concept_code as concept_code_2,
			'CDM' as vocabulary_id_1,
			'CDM' as vocabulary_id_2,
			'Version contains' as relationship_id,
			cdm.ddl_date::date as valid_start_date,
			to_date('20991231', 'yyyymmdd') as valid_end_date,
			null as invalid_reason
		from concept_stage cs where cs.domain_id is null;
		
		--fill domain_id. it means that we are done with parsing
		update concept_stage set domain_id='Metadata' where domain_id is null;
	end loop;
	
	--clearing
	drop sequence cdm_seq;
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
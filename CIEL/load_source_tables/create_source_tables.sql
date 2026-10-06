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
* Authors: Denys Kaduk, Polina Talapova
* Date: 2025
**************************************************************************/

-- extact list of versions
DROP TABLE IF EXISTS SOURCES.ciel_source_versions;
CREATE TABLE IF NOT EXISTS sources.ciel_source_versions (
  version                text PRIMARY KEY,     -- e.g., "v2025-10-19"
  id                     text,
  uuid                   text,
  url                    text,
  version_url            text,
  is_latest_version      boolean,
  update_comment         text,
  type                   text,
  source                 text,
  owner                  text,
  owner_type             text,
  owner_url              text,
  description            text,
  released_on            timestamptz,          -- if provided by OCL
  created_on             timestamptz,
  created_by             text,
  updated_on             timestamptz,
  updated_by             text,
  public_can_view        boolean,
  latest_source_version  text,                 -- if present
  checksums              jsonb,                -- {"smart": "...", "standard": "..."} if present
  attributes             jsonb,
  extras                 jsonb,
  raw                    jsonb,                -- full JSON from OCL
  pulled_at              timestamptz DEFAULT now()
);

-- Concepts
DROP TABLE IF EXISTS SOURCES.ciel_concepts;
CREATE TABLE IF NOT EXISTS sources.ciel_concepts (
  id                   text PRIMARY KEY,          -- "id" as source_code
  uuid                 text,
  external_id          text,
  concept_class        text,
  datatype             text,
  retired              boolean,
  source               text,
  owner                text,
  owner_type           text,
  owner_url            text,
  url                  text,
  display_name         text,
  display_locale       text,
  version              text,
  version_url          text,
  versions_url         text,
  versioned_object_id  bigint,
  versioned_object_url text,
  is_latest_version    boolean,
  update_comment       text,
  type                 text,
  created_on           timestamptz,
  created_by           text,
  updated_on           timestamptz,
  updated_by           text,
  public_can_view      boolean,
  latest_source_version text,
  checksums            jsonb,       -- {"smart":"...","standard":"..."}
  attributes           jsonb,
  extras               jsonb,
  names                jsonb,       -- all names
  descriptions         jsonb,       -- all descriptions
  property             jsonb,       -- all properies
  raw                  jsonb,       -- full JSON for debug
  pulled_at            timestamptz DEFAULT now()
);

-- Normalized Names with all locales
DROP TABLE IF EXISTS SOURCES.ciel_concept_names;
CREATE TABLE IF NOT EXISTS sources.ciel_concept_names (
  concept_id         text NOT NULL,
  uuid               text,
  name               text,
  external_id        text,
  type               text,              -- "ConceptName"
  locale             text,
  locale_preferred   boolean,
  name_type          text,
  case_sensitive     boolean,
  checksum           text,
  raw                jsonb,
  pulled_at          timestamptz DEFAULT now(),
  CONSTRAINT ciel_concept_names_v3_pk PRIMARY KEY (concept_id, locale, name)
);

-- Mappings
DROP TABLE IF EXISTS SOURCES.ciel_mappings;
CREATE TABLE IF NOT EXISTS sources.ciel_mappings (
  url                   text PRIMARY KEY,          -- canonical URL
  id                    text,
  uuid                  text,
  external_id           text,
  version               text,
  version_url           text,
  versioned_object_id   bigint,
  versioned_object_url  text,
  is_latest_version     boolean,
  update_comment        text,
  type                  text,
  sort_weight           numeric,
  map_type              text,
  retired               boolean,
  source                text,
  owner                 text,
  owner_type            text,
  from_concept_code     text,
  from_concept_name     text,
  from_concept_name_resolved text,
  from_concept_url      text,
  to_concept_code       text,
  to_concept_name       text,
  to_concept_url        text,
  from_source_owner     text,
  from_source_owner_type text,
  from_source_url       text,
  from_source_name      text,
  from_source_version   text,
  to_source_owner       text,
  to_source_owner_type  text,
  to_source_url         text,
  to_source_name        text,
  to_source_version     text,
  latest_source_version text,
  created_on            timestamptz,
  created_by            text,
  updated_on            timestamptz,
  updated_by            text,
  version_created_on    timestamptz,
  version_updated_on    timestamptz,
  version_updated_by    text,
  public_can_view       boolean,
  checksums             jsonb,       -- {"smart":"...","standard":"..."}
  attributes            jsonb,
  extras                jsonb,
  raw                   jsonb,
  pulled_at             timestamptz DEFAULT now()
);

-- retired concepts version and deate extraction
DROP TABLE IF EXISTS SOURCES.ciel_concept_retired_history;
CREATE TABLE IF NOT EXISTS sources.ciel_concept_retired_history (
	concept_id text NOT NULL,
	retired_since_version text NULL,
	retired_since_on timestamptz NULL,
	raw jsonb NULL,
	pulled_at timestamptz NULL DEFAULT now(),
	CONSTRAINT ciel_concept_retired_history_pkey PRIMARY KEY (concept_id)
);
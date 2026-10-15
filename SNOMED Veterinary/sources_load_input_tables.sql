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
* Authors: Medical team
* Date: 2026
**************************************************************************/

-- ===========================================================================
-- sources.load_input_tables.sql
--
-- Client-side replacement for the sources.load_input_tables() PL/pgSQL
-- function, using psql's \copy meta-command instead of server-side COPY.
--
-- Both the SNOMED Veterinary release files AND the SNOMED International
-- release files load into the SAME sources.vet_* tables, since
-- load_stage_test.sql step 3 expects a single unified set of source tables
-- filtered by moduleId.
--
-- IMPORTANT: File paths below are hardcoded (no \set/:variable
-- substitution). psql's \set/:'variable' substitution was found to
-- mishandle paths containing spaces in this environment - either including
-- literal quote characters in the substituted value, or stripping spaces
-- entirely. To edit the release date or file locations, search/replace the
-- literal path strings below directly.
--
-- USAGE:
--   Edit the hardcoded paths and dates below for the current release, then
--   run from within an existing psql session:
--     \i sources.load_input_tables.sql
-- ===========================================================================


-- ===========================================================================
-- SECTION 1: SNOMED VETERINARY
-- ===========================================================================

\echo 'Loading SNOMED Veterinary Edition source tables...'
SET client_encoding = 'UTF8';

TRUNCATE TABLE
    sources.vet_sct2_concept_full,
    sources.vet_sct2_desc_full,
    sources.vet_sct2_rela_full,
    sources.vet_der2_crefset_assreffull;

\copy sources.vet_sct2_concept_full(id,effectivetime,active,moduleid,statusid) FROM 'E:/SNOMED Files/SNOMED Veterinary/sct2_Concept_Full_VTS.txt' DELIMITER E'\t' CSV QUOTE E'\b' HEADER

UPDATE sources.vet_sct2_concept_full
SET vocabulary_date = '2026-03-31'::date,
    vocabulary_version = 'SNOMED Veterinary 2026-03-31'
WHERE vocabulary_date IS NULL;

\copy sources.vet_sct2_desc_full FROM 'E:/SNOMED Files/SNOMED Veterinary/sct2_Description_VTS.txt' DELIMITER E'\t' CSV QUOTE E'\b' HEADER

\copy sources.vet_sct2_rela_full FROM 'E:/SNOMED Files/SNOMED Veterinary/sct2_Relationship_VTS.txt' DELIMITER E'\t' CSV QUOTE E'\b' HEADER

\copy sources.vet_der2_crefset_assreffull FROM 'E:/SNOMED Files/SNOMED Veterinary/der2_cRefset_AssociationFull_VTS.txt' DELIMITER E'\t' CSV QUOTE E'\b' HEADER

\copy sources.vet_der2_crefset_language(id,effectiveTime,active,moduleId,refsetId,referencedComponentId,acceptabilityId) FROM 'E:/SNOMED Files/SNOMED Veterinary/der2_cRefset_LanguageFull_en_VTS.txt' DELIMITER E'\t' CSV QUOTE E'\b' HEADER

\copy sources.vet_der2_crefset_attributevalue_full FROM 'E:/SNOMED Files/SNOMED Veterinary/der2_cRefset_AttributeValueFull_VTS.txt' DELIMITER E'\t' CSV QUOTE E'\b' HEADER

\copy sources.vet_der2_ssRefset_ModuleDependency FROM 'E:/SNOMED Files/SNOMED Veterinary/der2_ssRefset_ModuleDependencyfull_VTS.txt' DELIMITER E'\t' CSV QUOTE E'\b' HEADER

UPDATE sources.vet_der2_crefset_language
SET source_file_id = 'VET'
WHERE mooduleId = '332351000009108';

UPDATE sources.vet_der2_crefset_language
SET source_file_id = 'INT'
WHERE mooduleId != '332351000009108';

\echo 'SNOMED Veterinary Edition file load complete.'


-- ===========================================================================
-- SECTION 2: Post-load indexing, analysis, and archiving
-- ===========================================================================

\echo 'Indexing and analyzing combined source tables...'

CREATE INDEX IF NOT EXISTS idx_vet_desc_conceptid ON sources.vet_sct2_desc_full (conceptid);
CREATE INDEX IF NOT EXISTS idx_vet_rela_id ON sources.vet_sct2_rela_full (id);

ANALYZE sources.vet_sct2_concept_full;
ANALYZE sources.vet_sct2_desc_full;
ANALYZE sources.vet_sct2_rela_full;
ANALYZE sources.vet_der2_crefset_assreffull;
ANALYZE sources.vet_der2_crefset_language;
ANALYZE sources.vet_der2_crefset_attributevalue_full;

-- NOTE: AddVocabularyToArchive requires INSERT permission on
-- sources.archive.archive_conversion, which this account does not have.
-- Skipped here; ask a DBA/admin to run archiving separately if needed.
-- SELECT sources.archive.AddVocabularyToArchive(
--     'SNOMED Veterinary',
--     ARRAY['vet_sct2_concept_full','vet_sct2_desc_full','vet_sct2_rela_full',
--           'vet_der2_crefset_assreffull','vet_der2_crefset_language',
--           'vet_der2_crefset_attributevalue_full','vet_der2_ssRefset_ModuleDependency'],
--     '2026-03-31'::date,
--     'archive.snomedvet_version', 10);

\echo 'Load complete.'

CREATE OR REPLACE FUNCTION vocabulary_pack.ClearBasicTables ()
RETURNS void AS
$BODY$
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
  * Authors: Timur Vakhitov
  * Date: 2021
  **************************************************************************/

  /*
    Use this script to clear basic/stage tables in your current dev-schema, just run SELECT vocabulary_pack.ClearBasicTables();
  */
  BEGIN
    IF CURRENT_SCHEMA = 'devv5' THEN RAISE EXCEPTION 'You cannot use this script in the ''devv5''!'; END IF;
    
    TRUNCATE concept_ancestor, concept CASCADE; --concept_class, domain, concept_relationship, concept_synonym, vocabulary, relationship, drug_strength, pack_content will also be cleared
    TRUNCATE TABLE concept_stage, concept_relationship_stage, concept_synonym_stage, drug_strength_stage, pack_content_stage;
  END;
$BODY$
LANGUAGE 'plpgsql' SECURITY INVOKER
SET client_min_messages = error;
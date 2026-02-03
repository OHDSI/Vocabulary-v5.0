/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the License);
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an AS IS BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Aliaksei Katyshou
* Date: 2024
**************************************************************************/

-- concept_metadata audit trigger
CREATE TRIGGER tg_audit_u AFTER
UPDATE 
ON devv5.concept_metadata 
    FOR EACH ROW
    WHEN ((old.* IS DISTINCT FROM new.*)) 
    EXECUTE FUNCTION audit.f_tg_audit();

CREATE TRIGGER tg_audit_id AFTER
INSERT OR DELETE
ON devv5.concept_metadata 
    FOR EACH 
    ROW EXECUTE FUNCTION audit.f_tg_audit();

CREATE TRIGGER tg_audit_t AFTER
TRUNCATE
ON devv5.concept_metadata 
    FOR EACH STATEMENT 
    EXECUTE FUNCTION audit.f_tg_audit();

-- concept_relationship_metadata audit triggers
CREATE TRIGGER tg_audit_id AFTER
INSERT OR DELETE
ON devv5.concept_relationship_metadata 
    FOR EACH ROW 
    EXECUTE FUNCTION audit.f_tg_audit();

CREATE TRIGGER tg_audit_t AFTER
TRUNCATE
ON devv5.concept_relationship_metadata 
    FOR EACH 
    STATEMENT EXECUTE FUNCTION audit.f_tg_audit();

CREATE TRIGGER tg_audit_u AFTER
UPDATE
ON devv5.concept_relationship_metadata 
    FOR EACH ROW
    WHEN ((old.* IS DISTINCT FROM new.*)) 
    EXECUTE FUNCTION audit.f_tg_audit();
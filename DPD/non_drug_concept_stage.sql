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
* Authors: Anna Ostropolets, Dmitry Dimschitz, Christian Reich
* Date: April 2016
**************************************************************************/
create table NON_DRUG as (select drug_Code as concept_code,old_code,brand_name as concept_name, class as domain_id, 'DPD' as vocabulary_id, 'Branded Drug' as concept_class_id,TO_DATE('2015/12/12', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, 'D' as invalid_reason  from drug_product where upper(CLASS) in ('DISINFECTANT','VETERINARY','RADIOPHARMACEUTICAL'));

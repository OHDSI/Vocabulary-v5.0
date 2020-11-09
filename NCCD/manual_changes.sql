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
* Authors: Polina Talapova, Daryna Ivakhnenko, Dmitry Dymshyts
* Date: 2020
**************************************************************************/
-- Add a new vocabulary
DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.AddNewVocabulary(
    pVocabulary_id          => 'NCCD',
    pVocabulary_name        => 'Normalized Chinese Clinical Drug',
    pVocabulary_reference   => 'https://www.ohdsi.org/wp-content/uploads/2020/07/NCCD_RxNorm_Mapping_0728.pdf',
    pVocabulary_version     => NULL,
    pOMOP_req               => NULL, 
    pClick_default          => NULL, 
    pAvailable              => NULL, -- unrestricted license
    pURL                    => NULL,
    pClick_disabled         => NULL 
);
END $_$;

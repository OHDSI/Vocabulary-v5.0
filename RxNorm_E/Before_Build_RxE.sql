/*****************************************************************************
* Copyright 2016-17 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES or CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Christian Reich, Anna Ostropolets, Dmitri Dimschits
***************************************************************************/

/***************************************************************************
* This script pre-processes before Build_RxE.sql can be run against RxNorm *
* Extension (instead of a real drug database). It needs to be run after    *
* fast_create and before create_input.                               *
***************************************************************************/

insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_concept_id)
     values ('RxO', 'RxO', 0);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_concept_id)
     values ('Rxfix', 'Rxfix', 10000);

update concept
set vocabulary_id = 'RxO' 
where vocabulary_id = 'RxNorm Extension';

update concept_relationship
set invalid_reason = 'D'
where concept_id_1 in (select concept_id_1 from concept_relationship JOIN concept on concept_id_1 = concept_id and vocabulary_id = 'RxO')
  or concept_id_2 in (select concept_id_2 from concept_relationship JOIN concept on concept_id_2 = concept_id and vocabulary_id = 'RxO');     

begin
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'Rxfix',
                                          pVocabularyDate        => TRUNC(sysdate),
                                          pVocabularyVersion     => 'Rxfix '||sysdate,
                                          pVocabularyDevSchema   => 'DEV_RXE');           
end;
commit;

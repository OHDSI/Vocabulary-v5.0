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
* Authors: Eldar Allakhverdiiev, Dmitry Dymshyts, Christian Reich
* Date: 2017
**************************************************************************/

--delete duplicates
delete from france where PFC IN (SELECT PFC FROM FRANCE GROUP BY PFC HAVING COUNT (1) >1) and
rowid not in (
select distinct min(rowid) over (partition by pfc) from  FRANCE); 



create table non_drugs as (
select PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS,  cast('' as varchar (250)) as concept_type from france where 
   regexp_like(upper(molecule),'BANDAGES|DEVICES|CARE PRODUCTS|DRESSING|CATHETERS|EYE OCCLUSION PATCH|INCONTINENCE COLLECTION APPLIANCES|SOAP|CREAM|HAIR|SHAMPOO|LOTION|FACIAL CLEANSER|LIP PROTECTANTS|CLEANSING AGENTS|SKIN|TONICS|TOOTHPASTES|MOUTH|SCALP LOTIONS|UREA 13|BARIUM|CRYSTAL VIOLET')
or regexp_like(upper(molecule),'LENS SOLUTIONS|INFANT |DISINFECTANT|ANTISEPTIC|CONDOMS|COTTON WOOL|GENERAL NUTRIENTS|LUBRICANTS|INSECT REPELLENTS|FOOD|SLIMMING PREPARATIONS|SPECIAL DIET|SWAB|WOUND|GADOBUTROL|GADODIAMIDE|GADOBENIC ACID|GADOTERIC ACID|GLUCOSE 1-PHOSPHATE|BRAN|PADS$|IUD')
or regexp_like(upper(molecule),'AFTER SUN PROTECTANTS|BABY MILKS|INCONTINENCE PADS|INSECT REPELLENTS|WIRE|CORN REMOVER|DDT|DECONGESTANT RUBS|EYE MAKE-UP REMOVERS|FIXATIVES|FOOT POWDERS|FIORAVANTI BALSAM|LOW CALORIE FOOD|NUTRITION|TETRAMETHRIN|OTHERS|NON MEDICATED|NON PHARMACEUTICAL|TRYPAN BLUE')
or (MOLECULE like '% TEST%' and MOLECULE not like 'TUBERCULIN%')
or DESCR_PCK like '%KCAL%'
or english = 'Non Human Usage Products'
or LB_NFC_3 like '%NON US.HUMAIN%'
)
;

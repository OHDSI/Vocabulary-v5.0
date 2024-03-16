--france_names_translation
----https://docs.google.com/spreadsheets/d/1HaaBxHlJZoe69IviZRCz3uNyjRktrHgf_ZWPOpV2I9E/edit#gid=0
CREATE TABLE     france_names_translation
(
    dose_form varchar(255),
    dose_form_name varchar(255)
)
;

--Table needed to perform manual work
--DROP TABLE FRANCE_manual;
CREATE TABLE FRANCE_manual as
SELECT *
FROM FRANCE;

--Update of fields
--After population of VOLUME rebuild the DOSAGE according to https://docs.google.com/document/d/1Fp4Ru2ONqlb9x4ch_IRifXrV810BGznfpKbc_a96P2M/edit
--Needed in case when we decide to rerun the Script
UPDATE FRANCE_manual
SET DOSAGE = CONCAT(STRG_UNIT,' ',STRG_MEAS )
;
-- Based on substring(volume, '(\d+(\.\d+)*)')::FLOAT,)
UPDATE FRANCE_manual
SET VOLUME = CONCAT(DOSAGE,' ',VOLUME )
;

UPDATE FRANCE_manual f
SET LB_NFC_3 = r.LB_NFC_3
FROM Data_NFC_Reference r
where r.CD_NFC_3=f.CD_NFC_3;

UPDATE FRANCE_manual f
SET english = r.English
FROM Data_NFC_Dictionary r
where r.CD_NFC_1= left(f.CD_NFC_3,1);

----list of non_drugs
DROP TABLE IF EXISTS non_drugs;
CREATE TABLE non_drugs AS
	SELECT product_desc,
		form_desc,
		dosage,
		dosage_add,
		volume,
		packsize,
		claatc,
		pfc,
		molecule,
		cd_nfc_3,
		english,
		lb_nfc_3,
		descr_pck,
		strg_unit,
		strg_meas,
		NULL::VARCHAR(250) AS concept_type
	FROM france
	WHERE molecule ~* 'BANDAGES|DEVICES|CARE PRODUCTS|DRESSING|CATHETERS|EYE OCCLUSION PATCH|INCONTINENCE COLLECTION APPLIANCES|SOAP|CREAM|HAIR|SHAMPOO|LOTION|FACIAL CLEANSER|LIP PROTECTANTS|CLEANSING AGENTS|SKIN|TONICS|TOOTHPASTES|MOUTH|SCALP LOTIONS|UREA 13|BARIUM|CRYSTAL VIOLET'
		OR molecule ~* 'LENS SOLUTIONS|INFANT |DISINFECTANT|ANTISEPTIC|CONDOMS|COTTON WOOL|GENERAL NUTRIENTS|LUBRICANTS|INSECT REPELLENTS|FOOD|SLIMMING PREPARATIONS|SPECIAL DIET|SWAB|WOUND|GADOBUTROL|GADODIAMIDE|GADOBENIC ACID|GADOTERIC ACID|GLUCOSE 1-PHOSPHATE|BRAN|PADS$|IUD'
		OR molecule ~* 'AFTER SUN PROTECTANTS|BABY MILKS|INCONTINENCE PADS|INSECT REPELLENTS|WIRE|CORN REMOVER|DDT|DECONGESTANT RUBS|EYE MAKE-UP REMOVERS|FIXATIVES|FOOT POWDERS|FIORAVANTI BALSAM|LOW CALORIE FOOD|NUTRITION|TETRAMETHRIN|OTHERS|NON MEDICATED|NON PHARMACEUTICAL|TRYPAN BLUE'
		OR (
			molecule LIKE '% TEST%'
			AND molecule NOT LIKE 'TUBERCULIN%'
			)
		OR descr_pck LIKE '%KCAL%'
		OR english = 'Non Human Usage Products'
		OR lb_nfc_3 LIKE '%NON US.HUMAIN%';

--Concept_manual population
with tab as (
    SELECT DISTINCT cc.concept_name as ingested_name,
                   INITCAP(trim(regexp_replace(replace(CONCAT(
                                                                     a.volume,
                                                                     ' ',
                                                                     substr((replace(a.molecule, '+', ' / ')), 1, 175) --To avoid names length more than 255
                                                                 ,
                                                                     '  ',
                                                                     a.dosage,' ',a.form_desc, ' ',
                                                                     ' [' || a.product_desc || ']',
                                                                     ' Box of ',
                                                                     a.packsize
                                                                 ), 'NULL', ''), '\s+', ' ', 'g')))
                           AS concept_name,
                    CASE WHEN nd.pfc is not null then 'Device' else 'Drug Product'::VARCHAR end AS concept_class_id,
                    a.pfc                                                                       AS concept_code
    FROM FRANCE_manual a
             LEFT JOIN non_drugs nd
                       on a.pfc = nd.pfc
             JOIN concept cc
                  on cc.concept_code = a.pfc
                      and cc.vocabulary_id = 'DA_France'
    WHERE a.molecule is not NULL
)
/*,
     --To prove that naming is done properly fro at least 75%
tab2 as (
SELECT devv5.similarity (ingested_name,concept_name) as similarity,ingested_name, concept_name, concept_class_id, concept_code
FROM tab)
select CASE WHEN similarity=1 then '1' else 'non1' end as similarity,concept_class_id,(100*count(*)::int)/(4488+22499) from tab2
group by 1,2*/

SELECT
       concept_name,
       concept_code,
       concept_class_id,
       CASE WHEN concept_class_id ='Device'
       then 'Device'
       else 'Drug'    end as domain_id  ,
CASE WHEN concept_class_id ='Device' then 'S'
else NULL    end as standard_cocnept,
       null as invalid_reason,
       current_date as valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM tab a
where  not exists(
            SELECT 1
            from FRANCE_manual m
                     JOIN devv5.concept c
                          on m.pfc = c.concept_code
                              and c.vocabulary_id = 'DA_France'
            where c.concept_code = a.concept_code
        )
;



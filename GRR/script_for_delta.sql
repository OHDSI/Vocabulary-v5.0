--update source table while upload was mistake with empty cells
UPDATE source_grr_q1_19
   SET product_launch_date = NULL::VARCHAR
WHERE product_launch_date = '';

--create from source working table 
DROP TABLE IF EXISTS source_data_1;

CREATE TABLE source_data_1 
AS
SELECT CASE
         WHEN product_launch_date IS NULL THEN CAST(input_fcc AS VARCHAR)
         ELSE input_fcc || '_' || TO_CHAR(TO_DATE(product_launch_date,'dd.mm.yyyy'),'mmddyyyy')
       END AS fcc,
       LTRIM(CAST(pzn AS VARCHAR),'0') AS pzn,
       Therapy_Name AS therapy_name_code,
       Therapy_Name_Therapy_Name AS therapy_name,
       product_no,
       product_launch_date,
       product_form,
       product_form_name,
       strength,
       Strength_Unit_Strength_Unit AS strength_unit,
       volume,
       Volume_Unit_Volume_Unit AS volume_unit,
       packsize,
       form_launch_date,
       out_of_trade_date,
       manufacturer,
       manufacturer_name,
       manufacturer_short_name,
       who_atc5_code,
       who_atc5_text,
       who_atc4_code,
       who_atc4_text,
       who_atc3_code,
       who_atc3_text,
       who_atc2_code,
       who_atc2_text,
       who_atc1_code,
       who_atc1_text,
       substance,
       no_of_substances,
       nfc_no,
       nfc,
       nfc_description
FROM source_grr_q1_19
;

--use data that we haven't in devv5 and those concepts which haven't 'live' mapping
DELETE
FROM source_data_1
WHERE fcc IN (SELECT DISTINCT fcc
              FROM source_data_1
                JOIN devv5.concept c1
                  ON c1.concept_code = fcc
                 AND c1.vocabulary_id = 'GRR'
                JOIN devv5.concept_relationship cr
                  ON cr.concept_id_1 = c1.concept_id
                 AND cr.relationship_id = 'Maps to'
                 AND cr.invalid_reason IS NULL
                JOIN devv5.concept c2
                  ON c2.concept_id = cr.concept_id_2
                 AND c2.invalid_reason IS NULL);

-- manual mapping!!!!vaccines\insulins,  after manual work put it to concept_relationship_manual 
DROP TABLE if exists vacc_ins_manual;

CREATE TABLE vacc_ins_manual 
AS
SELECT *
FROM source_data_1
WHERE UPPER(substance) ~ 'VACCINE|INSULIN';
 
--filling non-drug table
DROP TABLE IF EXISTS grr_non_drug;

CREATE TABLE grr_non_drug 
AS
SELECT fcc,
       therapy_name AS brand_name
FROM source_data_1
WHERE substance ~ 'AMINOACIDS|TAMPON|HAIR |ELECTROLYTE SOLUTION|ANTACIDS|ANTI-PSORIASIS|TOPICAL ANALGESICS|NASAL DECONGESTANTS|EMOLLIENT|MEDICAL|MEDICINE|SHAMPOOS|INFANT|INCONTINENCE|REPELLENT|^NON |MULTIVITAMINS AND MINERALS|DRESSING|WIRE|BRANDY|PROTECTAN|PROMOTIONAL|MOUTH|OTHER|CONDOM|LUBRICANTS|CARE |PARASITIC|COMBINATION'
OR    substance ~ 'GLUCOMANNAN|SELENIC ACID|SOAP|UNSPECIFIED|HYLAN|DEVICE|CLEANS|DISINFECTANT|TEST| LENS|URINARY PREPARATION|DEODORANT|CREAM|BANDAGE|MOUTH |KATHETER|NUTRI|LOZENGE|WOUND|LOTION|PROTECT|ARTIFICIAL|MULTI SUBSTANZ|DENTAL| FOOT|^FOOT|^BLOOD| FOOD| DIET|BLOOD|PREPARATION|DIABETIC|UNDECYLENAMIDOPROPYL|DIALYSIS|DISPOSABLE|DRUG'
OR    substance IN ('ENDOLYSIN','EYE','ANTIDIARRHOEALS','BATH OIL','TONICS','ENZYME (UNSPECIFIED)','GADOBENIC ACID','SWABS','EYE BATHS','POLYHEXAMETHYLBIGUANIDE','AMBAZONE','TOOTHPASTES','GADOPENTETIC ACID','GADOTERIC ACID','KEINE ZUORDNUNG')
OR    product_form_name ~ 'WUNDGAZE|WUNDKOMPRESS|WUNDV.'
OR    (therapy_name ~ '\d+(\.)?(\d+)?(CM|MM)(\s)?(\d+)?(CM|MM)?|DALLMANN|KNOBIVITAL' AND strength = '0.0' AND volume = '0.0')
OR    WHO_ATC4_CODE = 'V07A0'
OR    WHO_ATC5_CODE LIKE 'B05AX03%'
OR    WHO_ATC5_CODE LIKE 'B05AX02%'
OR    WHO_ATC5_CODE LIKE 'B05AX01%'
OR    WHO_ATC5_CODE LIKE 'V09%'
OR    WHO_ATC5_CODE LIKE 'V08%'
OR    WHO_ATC5_CODE LIKE 'V04%'
OR    WHO_ATC5_CODE LIKE 'B05AX04%'
OR    WHO_ATC5_CODE LIKE 'B05ZB%'
OR    WHO_ATC5_CODE LIKE '%B05AX %'
OR    WHO_ATC5_CODE LIKE '%D03AX32%'
OR    WHO_ATC5_CODE LIKE '%V03AX%'
OR    WHO_ATC5_CODE LIKE 'V10%'
OR    WHO_ATC5_CODE LIKE 'V %'
OR    WHO_ATC4_CODE LIKE 'X10%'
OR    WHO_ATC2_TEXT LIKE '%DIAGNOSTIC%'
OR    WHO_ATC1_TEXT LIKE '%DIAGNOSTIC%'
OR    NFC IN ('MQS','DYH')
OR    NFC LIKE 'V%'
OR    nfc_description ~ 'TAMPONS '
OR    therapy_name ~ 'OP\sSEPT|CASEIN|NOBAGEL|KNOBIVITAL|JUICE|KOMBIP\+TEST|WIPES';

--filling non-drug table
INSERT INTO grr_non_drug
SELECT fcc,
       therapy_name
FROM source_data_1
WHERE INITCAP(substance) IN ('Anti-Dandruff Shampoo','Kidney Stones','Acrylic Resin','Anti-Acne Soap','Antifungal','Antioxidants','Arachnoidae','Articulation','Bath Oil','Breath Freshners','Catheters','Clay','Combination Products','Corn Remover','Creams (Basis)','Cresol Sulfonic Acid Phenolsulfonic Acid Urea-Formaldehyde Complex','Decongestant Rubs','Electrolytes/Replacers','Eye Make-Up Removers','Fish','Formaldehyde And Phenol Condensation Product','Formosulfathiazole,Herbal','Hydrocolloid','Infant Food Modified','Iocarmic Acid','Ioglicic Acid','Iopronic Acid','Iopydol','Iosarcol','Ioxitalamic Acid','Iud-Cu Wire & Au Core','Lipides','Lipids','Low Calorie Food','Massage Oil','Medicinal Mud','Minerals','Misc.Allergens (Patient Requirement)','Mumio','Musculi','Nasal Decongestants','Non-Allergenic Soaps','Nutritional Supplements','Oligo Elements','Other Oral Hygiene Preparations','Paraformaldehyde-Sucrose Complex','Polymethyl Methacrylate','Polypeptides','Purgative/Laxative','Quaternary Ammonium Compounds','Rock','Saponine','Shower Gel','Skin Lotion','Sleep Aid','Slug','Suxibuzone','Systemic Analgesics','Tonics','Varroa Destructor','Vasa','Vegetables Extracts')
AND   fcc NOT IN (SELECT fcc FROM grr_non_drug);

--deleting non-drugs from working tables
DELETE
FROM source_data_1
WHERE fcc IN (SELECT fcc FROM grr_non_drug);

--create brand names table
DROP TABLE IF EXISTS grr_bn;

CREATE TABLE grr_bn 
AS
SELECT fcc,
       CASE
         WHEN therapy_name LIKE '%  %' THEN REGEXP_REPLACE(therapy_name,'\s\s.*','','g')
         ELSE REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(therapy_name,'\d+\.?\d+(%|C|CM|D|G|GR|IM|VIP|TABL|IU|K|K.|KG|L|LM|M|MG|ML|MO|NR|O|TU|Y|Y/H)+','','g'),'\d+\.?\d?(%|C|CM|D|G|GR|IU|K|K.|KG|L|LM|M|MG|ML|MO|NR|O|TU|Y|Y/H)+','','g'),'\(.*\)','','g'),REGEXP_REPLACE(PRODUCT_FORM_NAME || '.*','\s\s','\s','g'),'','g')
       END AS bn,
       therapy_name AS old_name
FROM source_data_1;

--start from source data patterns and normalize 
UPDATE grr_bn
   SET bn = REGEXP_REPLACE(REGEXP_REPLACE(TRIM(REGEXP_REPLACE(bn,'(\S)+(\.)+(\S)*(\s\S)*(\s\S)*','','g')),'(TABL|>>|ALPHA|--)*','','g'),'(\d)*(\s)*(\.)+(\S)*(\s\S)*(\s)*(\d)*','','g')
WHERE bn LIKE '%.%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(TRIM(REGEXP_REPLACE(bn,'(\S)*\+(\S|\d)*','','g')),'(\d|D3|B12|IM|FT|AMP|INF| INJ|ALT$)*','','g')
WHERE bn LIKE '%+%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'\s\s.*','','g')
WHERE bn LIKE '%  %';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'(\S)+(>>).*','','g')
WHERE bn LIKE '%>>%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'(\S)+(/).*','','g')
WHERE bn LIKE '%/%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'\(.*','','g')
WHERE bn LIKE '%(%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'(INJ).*','','g')
WHERE bn LIKE '% INJ %'
OR    bn ~ '^INJ';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(RTRIM(REGEXP_REPLACE(bn,'(\s)+(\S-\S)+','','g'),'-'),'(TABL|ALT|AAA|ACC |CAPS|LOTION| SUPP)','','g')
WHERE bn NOT LIKE 'ALT%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'RATIOPH\.|RAT\.|RATIO\.|RATIO |\sRAT$','RATIOPHARM','g');

UPDATE grr_bn
   SET bn = TRIM(REGEXP_REPLACE(bn,'SUBLINGU\.|SUPPOSITOR\.|INJ\.','','g'));

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'HEUM\.|HEU\.','HEUMANN','g');

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'SAND\.','SANDOZ','g');

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'NEURAXPH\.','NEURAXPHARM','g');

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'RATIOP$|RATIOP\s','RATIOPHARM','g');

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'WINTHR\.','WINTHROP','g');

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'1A PH\.','1A PHARMA','g');

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'INJEKTOP\.','INJEKTOPAS','g');

UPDATE grr_bn
   SET BN = REGEXP_REPLACE(bn,'(HEUMANN HEU)|(HEUMAN HEU)| HEU$','HEUMANN','g');

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'KHP$','KOHLPHARMA','g')
WHERE bn LIKE '%KHP';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'E-M$','EURIM-PHARM','g')
WHERE bn LIKE '%E-M';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'MSD$','MERCK','g')
WHERE bn LIKE '%MSD';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'ZEN$','ZENTIVA','g')
WHERE bn LIKE '%ZEN';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'WTH$','WESTEN PHARMA','g')
WHERE bn LIKE '%WTH';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'ORI$','ORIFARM','g')
WHERE bn LIKE '%ORI';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'RDX$','REMEDIX','g')
WHERE bn LIKE '%RDX';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'PBA$','PB PHARMA','g')
WHERE bn LIKE '%PBA';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'ACCORD\s.*','','g')
WHERE bn LIKE '% ACCORD%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'ROTEXM','ROTEXMEDICA','g')
WHERE bn LIKE '%ROTEXM%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'LICH','LICHTENSTEIN','g')
WHERE bn LIKE '% LICH'
OR    bn LIKE '% LICH %';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'WINTHR','WINTHROP','g')
WHERE bn LIKE '%WINTHR'
OR    bn LIKE '%WINTHR %';

UPDATE grr_bn
   SET bn = 'ABILIFY MAINTENA'
WHERE bn LIKE '%ABILIFY MAIN%';

UPDATE grr_bn
   SET bn = 'INFANRIX'
WHERE bn ~ '^INFA';

UPDATE grr_bn
   SET bn = 'MYDOCALM'
WHERE bn LIKE '%MYDOCALM%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'SPIRONOL.','SPIRONOLACTONE ','g')
WHERE bn LIKE '%SPIRONOL.%';

UPDATE grr_bn
   SET bn = 'OVYSMEN'
WHERE bn LIKE '%OVYSM%';

UPDATE grr_bn
   SET bn = 'ORTHO-NOVUM'
WHERE bn LIKE '%ORTHO-N%';

UPDATE grr_bn
   SET bn = 'CYKLOKAPRON'
WHERE bn ~ '^CYKLOK';

UPDATE grr_bn
   SET bn = 'ZADITEN'
WHERE bn LIKE '%ZADITEN%';

UPDATE grr_bn
   SET bn = 'VOLTAREN'
WHERE bn ~ '%VOLTAREN%';

UPDATE grr_bn
   SET bn = 'ALLEVYN'
WHERE bn LIKE '%ALLEVY%';

UPDATE grr_bn
   SET bn = 'OTRIVEN'
WHERE bn LIKE '%OTRIVEN%'
AND   bn != 'OTRIVEN DUO';

UPDATE grr_bn
   SET bn = 'SEEBRI'
WHERE bn LIKE '%SEEBRI%';

UPDATE grr_bn
   SET bn = 'DIDRONEL'
WHERE bn LIKE '%DIDRONEL%';

UPDATE grr_bn
   SET bn = 'ISCADOR'
WHERE bn LIKE '%ISCADOR%';

UPDATE grr_bn
   SET bn = 'NOVIRELL'
WHERE bn LIKE '%NOVIRELL%';

UPDATE grr_bn
   SET bn = 'QUINALICH'
WHERE bn LIKE '%QUINALICH%';

UPDATE grr_bn
   SET bn = 'TENSOBON'
WHERE bn LIKE '%TENSOBON%';

UPDATE grr_bn
   SET bn = 'PRESOMEN'
WHERE bn LIKE '%PRESOMEN%';

UPDATE grr_bn
   SET bn = 'BLOPRESID'
WHERE bn LIKE '%BLOPRESID%';

UPDATE grr_bn
   SET bn = 'NEO STEDIRIL'
WHERE bn LIKE '%NEO STEDIRIL%';

UPDATE grr_bn
   SET bn = 'TETESEPT'
WHERE bn LIKE '%TETESEPT%';

UPDATE grr_bn
   SET bn = 'ALKA SELTZER'
WHERE bn LIKE '%ALKA SELTZER%';

UPDATE grr_bn
   SET bn = 'BISOPROLOL VITABALANS'
WHERE bn LIKE '%BISOPROLOL VITABALANS%';

UPDATE grr_bn
   SET bn = 'NEURAXPHARM'
WHERE bn LIKE '%NEURAXPH%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'(\.)?\sCOMP\.',' ','g')
WHERE bn ~ '(\sCOMP$)|(\.COMP$)|COMP\.|RATIOPHARMCOMP';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,' COMP','','g')
WHERE bn LIKE '% COMP'
OR    bn LIKE '% COMP %';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'ML/$|CB/$|KL/$|\(SA/|\(OR/|\.IV|INHALAT|INHAL| INH|VAGINALE|SAFT|TONIKUM|TROPF| SALB| NO&| (NO$)','','g');

UPDATE grr_bn
   SET bn = TRIM(REGEXP_REPLACE(bn,'TABL$|SCHMERZTABL| KAPS|SCHM.TABL.| SCHM.$|TABLETTEN|BET\.M|RETARDTABL|\sTABL.','','g'));

UPDATE grr_bn
   SET bn = TRIM(REGEXP_REPLACE(bn,'\(.*','','g'));

UPDATE grr_bn
   SET bn = TRIM(REGEXP_REPLACE(bn,'(\d+\.)?\d+\%.*','','g'))
WHERE bn ~ '\d+\%';

UPDATE grr_bn
   SET bn = REGEXP_REPLACE(bn,'SUP|(\d$)| PW|( DRAG.*)|( ORAL.*)','','g')
WHERE bn NOT LIKE 'SUP%';

UPDATE GRR_BN
   SET BN = 'DEXAMONOZON'
WHERE BN = 'DEXAMONOZON SUPP.';

UPDATE grr_bn
   SET BN = REGEXP_REPLACE(bn,'-',' ','g');

UPDATE grr_bn
   SET bn = TRIM(REGEXP_REPLACE(bn,'  ',' ','g'));

DROP TABLE IF EXISTS grr_bn_2_1;

CREATE TABLE grr_bn_2_1 
AS
WITH lng
AS
(SELECT fcc,
       MAX(LENGTH(bn)) AS lng
FROM grr_bn
GROUP BY fcc)
SELECT DISTINCT b.*
FROM grr_bn b
  JOIN lng
    ON b.fcc = lng.fcc
   AND lng.lng = (LENGTH (b.bn));

--clean Brand Name
DELETE
FROM grr_bn_2_1
WHERE bn ~ 'BLAEHUNGSTABLETTEN|KOMPLEX|GALGANTTABL|PREDNISOL\.|LOESG|ALBUMIN|BABY|ANDERE|--|/|ACID.*\.|SCHLAFTABL\.|VIT.B12\+|RINGER|M8V|F4T|\. DHU|TABACUM|A8X|CA2|GALLE|BT5|KOCHSALZ|V3P|D4F|AC9|B9G|BC4|GALLE-DR\.|\+|SCHUESSL BIOCHEMIE|^BIO\.|BLAS\.|SILIC\.|KPK|CHAMOMILLA|ELEKTROLYT|AQUA|KNOBLAUCH|VITAMINE|/|AQUA A|LOESUNG'
AND   NOT bn ~ 'PHARM|ABTEI|HEEL|INJEE|HEUMANN|MERCK|BLUESFISH|WESTERN|PHARMA|ZENTIVA|PFIZER|PHARMA|MEDE|MEDAC|FAIR|HAMELN|ACCORD|RATIO|AXCOUNT|STADA|SANDOZ|SOLVAY|GLENMARK|APOTHEKE|HEXAL|TEVA|AUROBINDO|ORION|SYXYL|NEURAX|KOHNE|ACTAVIS|CLARIS|NOVUM|ABZ|AXCOUNT|MYLAN|ARISTO|KABI|BENE|HORMOSAN|ZENTIVA|PUREN|BIOMO|ACIS|RATIOPH|SYNOMED|ALPHA|ROTEXMEDICA|BERCO|DURA|DAGO|GASTREU|FORTE|VITAL|VERLA|ONKOVIS|ONCOTRADE|NEOCORP';

DELETE
FROM grr_bn_2_1
WHERE bn ~ 'TROPFEN|TETANUS|FAKTOR| KAPSELN|RNV|COMPOSITUM| SC | CARBON|COMPLEX|SLR|OLEUM|FERRUM|ROSMARIN|SYND|NATRIUM|BIOCHEMIE|URTICA|VALERIANA|DULCAMARA|SALZ| LH| DHU|HERBA|SULFUR|TINKTUR|PRUNUS|ZEMENT|KALIUM|ALUMIN|SOLUM| AKH| A1X| SAL| DHU|B\d|FLOR| ANTIDOT|ARNICA|KAMILLEN'
AND   NOT bn ~ 'PHARM|ABTEI|HEEL|INJEE|HEUMANN|MERCK|BLUESFISH|WESTERN|PHARMA|ZENTIVA|PFIZER|PHARMA|MEDE|MEDAC|FAIR|HAMELN|ACCORD|RATIO|AXCOUNT|STADA|SANDOZ|SOLVAY|GLENMARK|APOTHEKE|HEXAL|TEVA|AUROBINDO|ORION|SYXYL|NEURAX|KOHNE|ACTAVIS|CLARIS|NOVUM|ABZ|AXCOUNT|MYLAN|ARISTO|KABI|BENE|HORMOSAN|ZENTIVA|PUREN|BIOMO|ACIS|RATIOPH|SYNOMED|ALPHA|ROTEXMEDICA|BERCO|DURA|DAGO|GASTREU|FORTE|VITAL|VERLA|ONKOVIS|ONCOTRADE|NEOCORP|( AWD$)';

DELETE
FROM grr_bn_2_1
WHERE BN ~ 'SILICEA|STANNUM|SAURE|CAUSTICUM|CASCARA|FOLINATE|FOLATE|COLOCYNTHIS|CUPRUM|CALCIUM|SODIUM|BLUETEN|ACETYL|CHLORID|ACIDIDUM|ACIDUM|LIDOCAIN|ESTRADIOL|NACHTKERZENOE|NEOSTIGMIN|METALLICUM|SPAGYRISCHE|ARCANA|SULFURICUM|BERBERIS|BALDRIAN|TILIDIN| VIT '
AND   NOT bn ~ 'PHARM|ABTEI|HEEL|INJEE|HEUMANN|MERCK|BLUESFISH|WESTERN|PHARMA|ZENTIVA|PFIZER|PHARMA|MEDE|MEDAC|FAIR|HAMELN|ACCORD|RATIO|AXCOUNT|STADA|SANDOZ|SOLVAY|GLENMARK|APOTHEKE|HEXAL|TEVA|AUROBINDO|ORION|SYXYL|NEURAX|KOHNE|ACTAVIS|CLARIS|NOVUM|ABZ|AXCOUNT|MYLAN|ARISTO|KABI|BENE|HORMOSAN|ZENTIVA|PUREN|BIOMO|ACIS|RATIOPH|SYNOMED|ALPHA|ROTEXMEDICA|BERCO|DURA|DAGO|GASTREU|FORTE|VITAL|VERLA|ONKOVIS|ONCOTRADE|NEOCORP';

--delete Brand Name with length less than 2 letter 
DELETE
FROM grr_bn_2_1
WHERE LENGTH(bn) <= 2
OR    bn IS NULL;

DELETE
FROM grr_bn_2_1
WHERE LENGTH(bn) = 4
AND   SUBSTRING(bn,'\w') != SUBSTRING(old_name,'\w');

DELETE
FROM grr_bn_2_1
WHERE LENGTH(bn) < 6
AND   bn LIKE '% %'
AND   bn NOT IN ('OME Q','O PUR','IUP T','GO ON','AZA Q');

--deleting all sorts of ingredients
DELETE
FROM grr_bn_2_1
WHERE UPPER(bn) IN (SELECT UPPER(SUBSTANCE) FROM source_data_1);

--normalize Brand Name to RxNorm standard to better filling r_t_c
DROP TABLE if exists grr_bn_2;

CREATE TABLE grr_bn_2 
AS
SELECT DISTINCT a.*
FROM grr_bn_2_1 a
  JOIN sourcE_data_1 USING (fcc)
  JOIN (SELECT *,
               SUBSTRING(concept_name,'\w+') AS bn_short
        FROM concept
        WHERE vocabulary_id LIKE 'RxNorm%'
        AND   concept_class_id = 'Brand Name'
        AND   concept_name ~ '\w+\s\w+\s?\w+?'
        AND   invalid_reason IS NULL) b ON UPPER (bn) = UPPER (concept_name);

--using pattern for Brand Name that looks like 'AMLODIPINE SANDOZ'
INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER(SUBSTRING(bn,'\w+') || ' ' ||manufacturer_name) AS bn,
       old_name
FROM grr_bn_2_1 a
  JOIN sourcE_data_1 USING (fcc)
  JOIN (SELECT *,
               SUBSTRING(concept_name,'\w+') AS bn_short
        FROM concept
        WHERE vocabulary_id LIKE 'RxNorm%'
        AND   concept_class_id = 'Brand Name'
        AND   concept_name ~ '\w+\s\w+\s?\w+?'
        AND   invalid_reason IS NULL) b
    ON UPPER (SUBSTRING (bn,'\w+') || ' ' ||manufacturer_name) = UPPER (concept_name)
   AND fcc NOT IN (SELECT fcc FROM grr_bn_2);

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER(SUBSTRING(bn,'\w+') || ' ' ||substring (manufacturer_name,'\w+')) AS bn,
       old_name
FROM grr_bn_2_1 a
  JOIN sourcE_data_1 USING (fcc)
  JOIN (SELECT *,
               SUBSTRING(concept_name,'\w+') AS bn_short
        FROM concept
        WHERE vocabulary_id LIKE 'RxNorm%'
        AND   concept_class_id = 'Brand Name'
        AND   concept_name ~ '\w+\s\w+\s?\w+?'
        AND   invalid_reason IS NULL) b
    ON UPPER (SUBSTRING (bn,'\w+') || ' ' ||substring (manufacturer_name,'\w+')) = UPPER (concept_name)
   AND fcc NOT IN (SELECT fcc FROM grr_bn_2);

--put some Brand Name manually
INSERT INTO grr_bn_2
SELECT DISTINCT a.*
FROM grr_bn_2_1 a
  JOIN concept
    ON UPPER (bn) = UPPER (concept_name)
   AND concept_class_id = 'Brand Name'
   AND vocabulary_id LIKE 'RxNorm%'
   AND invalid_reason IS NULL
WHERE fcc NOT IN (SELECT fcc FROM grr_bn_2);

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER('Travoprost - 1 A Pharma') AS bn,
       old_name
FROM grr_bn_2_1
WHERE fcc = '1021878_01012018';

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER('COSOPT-S'),
       old_name
FROM grr_bn_2_1
WHERE old_name ~ 'COSOPT\-S';

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER('EZESIMVA'),
       old_name
FROM grr_bn_2_1
WHERE old_name ~ 'EZESIMVA';

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER('Amilorid Hct'),
       old_name
FROM grr_bn_2_1
WHERE old_name ~ 'AMILORID HCT';

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER('Flupentixol-Neuraxpharm'),
       old_name
FROM grr_bn_2_1
WHERE old_name ~ 'FLUPENTIXOL\-NEURAX';

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER('Q10 Coenzym'),
       old_name
FROM grr_bn_2_1
WHERE old_name ~ 'COENZYM Q10';

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER('Promethazin-Neuraxpharm'),
       old_name
FROM grr_bn_2_1
WHERE old_name ~ 'PROMETHAZIN-NEURAX';

--filter Brand Names with existing 
INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER(SUBSTRING(bn,'\w+')),
       old_name
FROM grr_bn_2_1 a
  JOIN sourcE_data_1 USING (fcc)
  JOIN concept
    ON UPPER (SUBSTRING (bn,'\w+')) = UPPER (concept_name)
   AND concept_class_id = 'Brand Name'
   AND vocabulary_id LIKE 'RxNorm%'
   AND invalid_reason IS NULL
WHERE a.fcc NOT IN (SELECT fcc FROM grr_bn_2)
AND   bn !~ 'PUREN|MYLAN|ALKEM';

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER(concept_name),
       old_name
FROM grr_bn_2_1
  JOIN concept
    ON UPPER (REPLACE (bn,'PREGABALIN','PREGABALINE')) = UPPER (concept_name)
   AND concept_class_id = 'Brand Name'
   AND vocabulary_id LIKE 'RxNorm%'
   AND invalid_reason IS NULL
WHERE fcc NOT IN (SELECT fcc FROM grr_bn_2);

INSERT INTO grr_bn_2
SELECT DISTINCT fcc,
       UPPER('LEVETIRACETAM PUREN'),
       old_name
FROM grr_bn_2_1
WHERE bn ~ 'LEVETIRACETAM PURE';

INSERT INTO grr_bn_2
SELECT DISTINCT *
FROM grr_bn_2_1
WHERE fcc NOT IN (SELECT fcc FROM grr_bn_2);

--avoid names of Brand Name that equal to non Brand Name
DELETE
FROM grr_bn_2
WHERE fcc IN (SELECT fcc
              FROM grr_bn_2
                JOIN concept ON UPPER (bn) = UPPER (concept_name)
              WHERE concept_class_id != 'Brand Name'
              AND   vocabulary_id IN ('RxNorm','RxNorm Extension'));

--create table of Suppliers
DROP TABLE IF EXISTS grr_manuf_0;

CREATE TABLE grr_manuf_0 
(
  fcc              VARCHAR(255),
  EFF_FR_DT        VARCHAR(255),
  EFF_TO_DT        VARCHAR(255),
  PRI_ORG_CD       INTEGER,
  PRI_ORG_LNG_NM   VARCHAR(255),
  CUR_REC_IND      VARCHAR(255)
);

--inserting suppliers from source data
INSERT INTO grr_manuf_0
(
  fcc,
  PRI_ORG_LNG_NM
)
SELECT DISTINCT fcc,
       manufacturer_name
FROM source_data_1;

DROP TABLE IF EXISTS grr_manuf;

CREATE TABLE grr_manuf 
AS
SELECT DISTINCT fcc,
       REGEXP_REPLACE(PRI_ORG_LNG_NM,'\s\s+>>','','g') AS PRI_ORG_LNG_NM
FROM grr_manuf_0;

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'TAKEDA'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%TAKEDA%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'BAYER'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%BAYER%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'ABBOTT'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%ABBOTT%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'PFIZER'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%PFIZER%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'BOEHRINGER'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%BEHR%'
              OR    PRI_ORG_LNG_NM LIKE '%BOEH%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'MERCK DURA'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%MERCK%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'RATIOPHARM'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%RATIO%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'MERCK DURA'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%MERCK%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'GEDEON RICHTER'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%RICHT%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'SANOFI'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%SANOFI%'
              OR    PRI_ORG_LNG_NM LIKE '%SYNTHELABO%'
              OR    PRI_ORG_LNG_NM LIKE '%AVENTIS%'
              OR    PRI_ORG_LNG_NM LIKE '%ZENTIVA%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'NOVARTIS'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%NOVART%'
              OR    PRI_ORG_LNG_NM LIKE '%SANDOZ%'
              OR    PRI_ORG_LNG_NM LIKE '%HEXAL%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'ACTAVIS'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%ACTAVIS%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'ASTRA ZENECA'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%ASTRA%'
              OR    PRI_ORG_LNG_NM LIKE '%ZENECA%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'GLAXOSMITHKLINE'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%SMITHKL%'
              OR    PRI_ORG_LNG_NM LIKE '%GLAXO%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'WESTEN PHARMA'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%WESTEN%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'ASTELLAS'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%ASTELLAS%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'ASTA PHARMA'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%ASTA%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'ABZ PHARMA'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%ABZ%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'HORMOSAN PHARMA'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%HORMOSAN%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'LUNDBECK'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%LUNDBECK%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'EU RHO ARZNEI'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%EU RHO%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'B.BRAUN'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%.BRAUN%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'BIOGLAN'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%BIOGLAN%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'MEPHA-PHARMA'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%MEPHA%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'PIERRE FABRE'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%PIERRE%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'FOURNIER PHARMA'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%FOURNIER%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'JOHNSON&JOHNSON'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%JOHNSON%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'AASTON HEALTH'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '%AASTON%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'HAEMATO PHARM'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%HAEMATO PHARM%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'STRATHMANN'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%STRATHMANN%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'ACA MUELLER'
WHERE fcc IN (SELECT fcc
              FROM grr_manuf
              WHERE PRI_ORG_LNG_NM LIKE '%MUELLER%');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = 'KRKA'
WHERE fcc IN (SELECT fcc FROM grr_manuf WHERE PRI_ORG_LNG_NM LIKE '^TAD$');

UPDATE grr_manuf
   SET PRI_ORG_LNG_NM = REPLACE(PRI_ORG_LNG_NM,'>','');

DELETE
FROM grr_manuf
WHERE PRI_ORG_LNG_NM IN ('OLIBANUM','EIGENHERSTELLUNG');

--delete from manufacturer ingredients
DELETE
FROM grr_manuf
WHERE LOWER(PRI_ORG_LNG_NM) IN (SELECT LOWER(concept_name)
                                FROM concept
                                WHERE concept_class_id = 'Ingredient');

--delete strange manufacturers
DELETE
FROM grr_manuf
WHERE PRI_ORG_LNG_NM LIKE '%/%'
OR    PRI_ORG_LNG_NM LIKE '%.%'
OR    PRI_ORG_LNG_NM LIKE '%APOTHEKE%'
OR    PRI_ORG_LNG_NM LIKE '%IMPORTE AUS%';

DELETE
FROM grr_manuf
WHERE LENGTH(PRI_ORG_LNG_NM) < 4;

--deleting BNs that looks like suppliers
DELETE
FROM grr_bn_2
WHERE UPPER(bn) IN (SELECT UPPER(PRI_ORG_LNG_NM) FROM grr_manuf);

--create table with dose form
DROP TABLE IF EXISTS grr_form;

CREATE TABLE grr_form 
AS
SELECT fcc,
       PRODUCT_FORM_NAME AS INTL_PACK_FORM_DESC,
       CASE
         WHEN NFC = 'ZZZ' THEN NULL
         ELSE nfc
       END AS NFC_123_CD
FROM source_data_1;

--update forms if concepts didn't have NFC
DO $_$ BEGIN UPDATE grr_form
   SET NFC_123_CD = 'BAA'
WHERE INTL_PACK_FORM_DESC ~ '(CT TAB)|(EC TAB)|(FC TAB)|(RT TAB)';

UPDATE grr_form
   SET NFC_123_CD = 'BCA'
WHERE INTL_PACK_FORM_DESC ~ '(RT CAP)|(EC CAP)';

UPDATE grr_form
   SET NFC_123_CD = 'ACA'
WHERE INTL_PACK_FORM_DESC = 'CAP';

UPDATE grr_form
   SET NFC_123_CD = 'AAA'
WHERE INTL_PACK_FORM_DESC = '%LOZ';

UPDATE grr_form
   SET NFC_123_CD = 'DEP'
WHERE INTL_PACK_FORM_DESC IN (' ORL UD PWD',' ORL SLB PWD',' ORL PWD');

UPDATE grr_form
   SET NFC_123_CD = 'DGB'
WHERE INTL_PACK_FORM_DESC IN (' ORL DRP',' ORAL LIQ',' ORL MD LIQ',' ORL RT LIQ',' ORL UD LIQ',' ORL SYR',' ORL SUSP',' ORL SPIRIT');

UPDATE grr_form
   SET NFC_123_CD = 'TAA'
WHERE INTL_PACK_FORM_DESC IN ('VAG COMB TAB','VAG TAB');

UPDATE grr_form
   SET NFC_123_CD = 'TGA'
WHERE INTL_PACK_FORM_DESC IN ('VAG UD LIQ','VAG LIQ','VAG IUD');

UPDATE grr_form
   SET NFC_123_CD = 'MSA'
WHERE INTL_PACK_FORM_DESC IN ('TOP OINT','TOP OIL');

UPDATE grr_form
   SET NFC_123_CD = 'MGW'
WHERE INTL_PACK_FORM_DESC = 'TOP LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'FMA'
WHERE INTL_PACK_FORM_DESC LIKE '%AMP%';

UPDATE grr_form
   SET NFC_123_CD = 'MWA'
WHERE INTL_PACK_FORM_DESC LIKE '%PLAST%';

UPDATE grr_form
   SET NFC_123_CD = 'FNA'
WHERE INTL_PACK_FORM_DESC LIKE '%PF %SG%'
OR    INTL_PACK_FORM_DESC LIKE '%PF %PEN%';

UPDATE grr_form
   SET NFC_123_CD = 'FPA'
WHERE INTL_PACK_FORM_DESC LIKE '%VIAL%';

UPDATE grr_form
   SET NFC_123_CD = 'FQE'
WHERE INTL_PACK_FORM_DESC LIKE '%INF BAG%';

UPDATE grr_form
   SET NFC_123_CD = 'RHP'
WHERE INTL_PACK_FORM_DESC LIKE '%LUNG%';

UPDATE grr_form
   SET NFC_123_CD = 'MHA'
WHERE INTL_PACK_FORM_DESC LIKE '%SPRAY%';

UPDATE grr_form
   SET NFC_123_CD = 'MJY'
WHERE INTL_PACK_FORM_DESC = 'BAD';

UPDATE grr_form
   SET NFC_123_CD = 'MJH'
WHERE INTL_PACK_FORM_DESC = 'BAD OEL';

UPDATE grr_form
   SET NFC_123_CD = 'MJY'
WHERE INTL_PACK_FORM_DESC = 'BATH';

UPDATE grr_form
   SET NFC_123_CD = 'MJL'
WHERE INTL_PACK_FORM_DESC = 'BATH EMUL';

UPDATE grr_form
   SET NFC_123_CD = 'MJT'
WHERE INTL_PACK_FORM_DESC = 'BATH FOAM';

UPDATE grr_form
   SET NFC_123_CD = 'MJH'
WHERE INTL_PACK_FORM_DESC = 'BATH OIL';

UPDATE grr_form
   SET NFC_123_CD = 'MJY'
WHERE INTL_PACK_FORM_DESC = 'BATH OTH';

UPDATE grr_form
   SET NFC_123_CD = 'MJB'
WHERE INTL_PACK_FORM_DESC = 'BATH SOLID';

UPDATE grr_form
   SET NFC_123_CD = 'ADQ'
WHERE INTL_PACK_FORM_DESC = 'BISCUIT';

UPDATE grr_form
   SET NFC_123_CD = 'ACF'
WHERE INTL_PACK_FORM_DESC = 'BITE CAP';

UPDATE grr_form
   SET NFC_123_CD = 'MYP'
WHERE INTL_PACK_FORM_DESC = 'BONE CMT W SUB';

UPDATE grr_form
   SET NFC_123_CD = 'AAE'
WHERE INTL_PACK_FORM_DESC = 'BUC TAB';

UPDATE grr_form
   SET NFC_123_CD = 'FRA'
WHERE INTL_PACK_FORM_DESC = 'CART';

UPDATE grr_form
   SET NFC_123_CD = 'ACG'
WHERE INTL_PACK_FORM_DESC = 'CHEW CAP';

UPDATE grr_form
   SET NFC_123_CD = 'AAG'
WHERE INTL_PACK_FORM_DESC = 'CHEW TAB';

UPDATE grr_form
   SET NFC_123_CD = 'ACZ'
WHERE INTL_PACK_FORM_DESC = 'COMB CAP';

UPDATE grr_form
   SET NFC_123_CD = 'ADZ'
WHERE INTL_PACK_FORM_DESC = 'COMB SPC SLD';

UPDATE grr_form
   SET NFC_123_CD = 'AAZ'
WHERE INTL_PACK_FORM_DESC = 'COMB TAB';

UPDATE grr_form
   SET NFC_123_CD = 'FQD'
WHERE INTL_PACK_FORM_DESC = 'DRY INF BTL';

UPDATE grr_form
   SET NFC_123_CD = 'MEC'
WHERE INTL_PACK_FORM_DESC = 'DUST PWD';

UPDATE grr_form
   SET NFC_123_CD = 'AAH'
WHERE INTL_PACK_FORM_DESC = 'EFF TAB';

UPDATE grr_form
   SET NFC_123_CD = 'DGA'
WHERE INTL_PACK_FORM_DESC = 'FLUESSIG';

UPDATE grr_form
   SET NFC_123_CD = 'MYT'
WHERE INTL_PACK_FORM_DESC = 'FOAM';

UPDATE grr_form
   SET NFC_123_CD = 'DGR'
WHERE INTL_PACK_FORM_DESC = 'FRANZBR.WEIN';

UPDATE grr_form
   SET NFC_123_CD = 'MWB'
WHERE INTL_PACK_FORM_DESC = 'GAUZE W SUB';

UPDATE grr_form
   SET NFC_123_CD = 'MZK'
WHERE INTL_PACK_FORM_DESC = 'GEL DRESS';

UPDATE grr_form
   SET NFC_123_CD = 'ADR'
WHERE INTL_PACK_FORM_DESC = 'GLOBULE';

UPDATE grr_form
   SET NFC_123_CD = 'AEB'
WHERE INTL_PACK_FORM_DESC = 'GRAN';

UPDATE grr_form
   SET NFC_123_CD = 'KDF'
WHERE INTL_PACK_FORM_DESC = 'GUM';

UPDATE grr_form
   SET NFC_123_CD = 'GYV'
WHERE INTL_PACK_FORM_DESC = 'IMPLANT';

UPDATE grr_form
   SET NFC_123_CD = 'FQC'
WHERE INTL_PACK_FORM_DESC = 'INF BTL';

UPDATE grr_form
   SET NFC_123_CD = 'FQF'
WHERE INTL_PACK_FORM_DESC = 'INF CART';

UPDATE grr_form
   SET NFC_123_CD = 'RCT'
WHERE INTL_PACK_FORM_DESC = 'INH CAP';

UPDATE grr_form
   SET NFC_123_CD = 'FNH'
WHERE INTL_PACK_FORM_DESC = 'INJEKTOR NA';

UPDATE grr_form
   SET NFC_123_CD = 'DKJ'
WHERE INTL_PACK_FORM_DESC = 'INSTANT TEA';

UPDATE grr_form
   SET NFC_123_CD = 'MQS'
WHERE INTL_PACK_FORM_DESC = 'IRRIGAT FLUID';

UPDATE grr_form
   SET NFC_123_CD = 'ACA'
WHERE INTL_PACK_FORM_DESC = 'KAPS';

UPDATE grr_form
   SET NFC_123_CD = 'AAJ'
WHERE INTL_PACK_FORM_DESC = 'LAYER TAB';

UPDATE grr_form
   SET NFC_123_CD = 'MGW'
WHERE INTL_PACK_FORM_DESC = 'LIQ SOAP';

UPDATE grr_form
   SET NFC_123_CD = 'DGA'
WHERE INTL_PACK_FORM_DESC = 'LIQU';

UPDATE grr_form
   SET NFC_123_CD = 'DGA'
WHERE INTL_PACK_FORM_DESC = 'LOESG N';

UPDATE grr_form
   SET NFC_123_CD = 'DGA'
WHERE INTL_PACK_FORM_DESC = 'LOESUNG';

UPDATE grr_form
   SET NFC_123_CD = 'ADE'
WHERE INTL_PACK_FORM_DESC = 'LOZ';

UPDATE grr_form
   SET NFC_123_CD = 'TYQ'
WHERE INTL_PACK_FORM_DESC = 'MCH PES W SUB';

UPDATE grr_form
   SET NFC_123_CD = 'DKA'
WHERE INTL_PACK_FORM_DESC = 'MED TEA';

UPDATE grr_form
   SET NFC_123_CD = 'QGC'
WHERE INTL_PACK_FORM_DESC = 'NH AERO';

UPDATE grr_form
   SET NFC_123_CD = 'DGA'
WHERE INTL_PACK_FORM_DESC = 'NH LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'DEK'
WHERE INTL_PACK_FORM_DESC = 'NH SLB PWD';

UPDATE grr_form
   SET NFC_123_CD = 'AAH'
WHERE INTL_PACK_FORM_DESC = 'NH SLB TAB';

UPDATE grr_form
   SET NFC_123_CD = 'DEK'
WHERE INTL_PACK_FORM_DESC = 'NH SLD SUB';

UPDATE grr_form
   SET NFC_123_CD = 'FPA'
WHERE INTL_PACK_FORM_DESC = 'NH TST X STK';

UPDATE grr_form
   SET NFC_123_CD = 'MGN'
WHERE INTL_PACK_FORM_DESC = 'NH UD LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'RHQ'
WHERE INTL_PACK_FORM_DESC = 'NON CFC MDI';

UPDATE grr_form
   SET NFC_123_CD = 'IGP'
WHERE INTL_PACK_FORM_DESC = 'NS MD LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'IGN'
WHERE INTL_PACK_FORM_DESC = 'NS UD LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'QTA'
WHERE INTL_PACK_FORM_DESC = 'NT CRM';

UPDATE grr_form
   SET NFC_123_CD = 'QGB'
WHERE INTL_PACK_FORM_DESC = 'NT DRP';

UPDATE grr_form
   SET NFC_123_CD = 'QGP'
WHERE INTL_PACK_FORM_DESC = 'NT MD LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'QGH'
WHERE INTL_PACK_FORM_DESC = 'NT OIL';

UPDATE grr_form
   SET NFC_123_CD = 'QYM'
WHERE INTL_PACK_FORM_DESC = 'NT STICK';

UPDATE grr_form
   SET NFC_123_CD = 'QGN'
WHERE INTL_PACK_FORM_DESC = 'NT UD LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'NDN'
WHERE INTL_PACK_FORM_DESC = 'OCULAR SYS';

UPDATE grr_form
   SET NFC_123_CD = 'MGH'
WHERE INTL_PACK_FORM_DESC = 'OEL';

UPDATE grr_form
   SET NFC_123_CD = 'PGB'
WHERE INTL_PACK_FORM_DESC = 'OHRENTROPFEN';

UPDATE grr_form
   SET NFC_123_CD = 'NGZ'
WHERE INTL_PACK_FORM_DESC = 'OPH COMB LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'NTA'
WHERE INTL_PACK_FORM_DESC = 'OPH CRM';

UPDATE grr_form
   SET NFC_123_CD = 'NGB'
WHERE INTL_PACK_FORM_DESC = 'OPH DRP';

UPDATE grr_form
   SET NFC_123_CD = 'NVB'
WHERE INTL_PACK_FORM_DESC = 'OPH GEL DRP';

UPDATE grr_form
   SET NFC_123_CD = 'NSA'
WHERE INTL_PACK_FORM_DESC = 'OPH OINT';

UPDATE grr_form
   SET NFC_123_CD = 'MZY'
WHERE INTL_PACK_FORM_DESC = 'OPH OTH M.AID';

UPDATE grr_form
   SET NFC_123_CD = 'NGQ'
WHERE INTL_PACK_FORM_DESC = 'OPH PRSV-F MU-D LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'NGA'
WHERE INTL_PACK_FORM_DESC = 'OPH SOL';

UPDATE grr_form
   SET NFC_123_CD = 'NGK'
WHERE INTL_PACK_FORM_DESC = 'OPH SUSP';

UPDATE grr_form
   SET NFC_123_CD = 'NGN'
WHERE INTL_PACK_FORM_DESC = 'OPH UD LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'AAB'
WHERE INTL_PACK_FORM_DESC = ' ORAL SLD ODT';

UPDATE grr_form
   SET NFC_123_CD = 'DGZ'
WHERE INTL_PACK_FORM_DESC = ' ORL COMB LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'DGJ'
WHERE INTL_PACK_FORM_DESC = ' ORL DRY SUSP';

UPDATE grr_form
   SET NFC_123_CD = 'DGJ'
WHERE INTL_PACK_FORM_DESC = ' ORL DRY SYR';

UPDATE grr_form
   SET NFC_123_CD = 'DGL'
WHERE INTL_PACK_FORM_DESC = ' ORL EMUL';

UPDATE grr_form
   SET NFC_123_CD = 'AEB'
WHERE INTL_PACK_FORM_DESC = ' ORL GRAN';

UPDATE grr_form
   SET NFC_123_CD = 'KSA'
WHERE INTL_PACK_FORM_DESC = ' ORL OIL';

UPDATE grr_form
   SET NFC_123_CD = 'DDY'
WHERE INTL_PACK_FORM_DESC = ' ORL SPC FORM';

UPDATE grr_form
   SET NFC_123_CD = 'AEB'
WHERE INTL_PACK_FORM_DESC = ' ORL UD GRAN';

UPDATE grr_form
   SET NFC_123_CD = 'JGB'
WHERE INTL_PACK_FORM_DESC = 'OS DRP';

UPDATE grr_form
   SET NFC_123_CD = 'JVA'
WHERE INTL_PACK_FORM_DESC = 'OS GEL';

UPDATE grr_form
   SET NFC_123_CD = 'JFA'
WHERE INTL_PACK_FORM_DESC = 'OS INH GAS';

UPDATE grr_form
   SET NFC_123_CD = 'JGE'
WHERE INTL_PACK_FORM_DESC = 'OS INH LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'JSA'
WHERE INTL_PACK_FORM_DESC = 'OS OINT';

UPDATE grr_form
   SET NFC_123_CD = 'JEY'
WHERE INTL_PACK_FORM_DESC = 'OS OTH PWD';

UPDATE grr_form
   SET NFC_123_CD = 'JWN'
WHERE INTL_PACK_FORM_DESC = 'OS TD SYS';

UPDATE grr_form
   SET NFC_123_CD = 'JCV'
WHERE INTL_PACK_FORM_DESC = 'OS TOP CAP';

UPDATE grr_form
   SET NFC_123_CD = 'JVN'
WHERE INTL_PACK_FORM_DESC = 'OS UD GEL';

UPDATE grr_form
   SET NFC_123_CD = 'KAE'
WHERE INTL_PACK_FORM_DESC = 'OT BUC TAB';

UPDATE grr_form
   SET NFC_123_CD = 'KGD'
WHERE INTL_PACK_FORM_DESC = 'OT COLLODION';

UPDATE grr_form
   SET NFC_123_CD = 'KGB'
WHERE INTL_PACK_FORM_DESC = 'OT DRP';

UPDATE grr_form
   SET NFC_123_CD = 'KVA'
WHERE INTL_PACK_FORM_DESC = 'OT GEL';

UPDATE grr_form
   SET NFC_123_CD = 'KGD'
WHERE INTL_PACK_FORM_DESC = 'OT LACQUER';

UPDATE grr_form
   SET NFC_123_CD = 'KGA'
WHERE INTL_PACK_FORM_DESC = 'OT LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'KDE'
WHERE INTL_PACK_FORM_DESC = 'OT LOZ';

UPDATE grr_form
   SET NFC_123_CD = 'KSA'
WHERE INTL_PACK_FORM_DESC = 'OT OINT';

UPDATE grr_form
   SET NFC_123_CD = 'KHA'
WHERE INTL_PACK_FORM_DESC = 'OT P.AERO';

UPDATE grr_form
   SET NFC_123_CD = 'KSB'
WHERE INTL_PACK_FORM_DESC = 'OT PASTE';

UPDATE grr_form
   SET NFC_123_CD = 'KEK'
WHERE INTL_PACK_FORM_DESC = 'OT SLB PWD';

UPDATE grr_form
   SET NFC_123_CD = 'ACA'
WHERE INTL_PACK_FORM_DESC = 'OT SPC FORM';

UPDATE grr_form
   SET NFC_123_CD = 'KYK'
WHERE INTL_PACK_FORM_DESC = 'OT STYLI';

UPDATE grr_form
   SET NFC_123_CD = 'KDG'
WHERE INTL_PACK_FORM_DESC = 'OT SWEET';

UPDATE grr_form
   SET NFC_123_CD = 'KVN'
WHERE INTL_PACK_FORM_DESC = 'OT UD GEL';

UPDATE grr_form
   SET NFC_123_CD = 'KGN'
WHERE INTL_PACK_FORM_DESC = 'OT UD LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'ACA'
WHERE INTL_PACK_FORM_DESC = 'OTH CAP';

UPDATE grr_form
   SET NFC_123_CD = 'PGB'
WHERE INTL_PACK_FORM_DESC = 'OTIC DRP';

UPDATE grr_form
   SET NFC_123_CD = 'PSA'
WHERE INTL_PACK_FORM_DESC = 'OTIC OINT';

UPDATE grr_form
   SET NFC_123_CD = 'MWD'
WHERE INTL_PACK_FORM_DESC = 'PAD W SUB';

UPDATE grr_form
   SET NFC_123_CD = 'FNH'
WHERE INTL_PACK_FORM_DESC = 'PARENT ORD PF AUTINJ';

UPDATE grr_form
   SET NFC_123_CD = 'ADD'
WHERE INTL_PACK_FORM_DESC = 'PELLET';

UPDATE grr_form
   SET NFC_123_CD = 'AAA'
WHERE INTL_PACK_FORM_DESC = 'PILLEN N';

UPDATE grr_form
   SET NFC_123_CD = 'MWS'
WHERE INTL_PACK_FORM_DESC = 'POULTICE';

UPDATE grr_form
   SET NFC_123_CD = 'AEA'
WHERE INTL_PACK_FORM_DESC = 'PULVER';

UPDATE grr_form
   SET NFC_123_CD = 'MEA'
WHERE INTL_PACK_FORM_DESC = 'PULVER T';

UPDATE grr_form
   SET NFC_123_CD = 'HCA'
WHERE INTL_PACK_FORM_DESC = 'RS CAP';

UPDATE grr_form
   SET NFC_123_CD = 'HGX'
WHERE INTL_PACK_FORM_DESC = 'RS ENEMA LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'HHP'
WHERE INTL_PACK_FORM_DESC = 'RS MD AERO';

UPDATE grr_form
   SET NFC_123_CD = 'HLX'
WHERE INTL_PACK_FORM_DESC = 'RS MICRO ENEMA';

UPDATE grr_form
   SET NFC_123_CD = 'HLA'
WHERE INTL_PACK_FORM_DESC = 'RS SUP';

UPDATE grr_form
   SET NFC_123_CD = 'HLA'
WHERE INTL_PACK_FORM_DESC = 'RS SUP ADLT';

UPDATE grr_form
   SET NFC_123_CD = 'HLA'
WHERE INTL_PACK_FORM_DESC = 'RS SUP PAED';

UPDATE grr_form
   SET NFC_123_CD = 'FRA'
WHERE INTL_PACK_FORM_DESC = 'RT CART';

UPDATE grr_form
   SET NFC_123_CD = 'ACD'
WHERE INTL_PACK_FORM_DESC = 'RT UD PWD';

UPDATE grr_form
   SET NFC_123_CD = 'MSA'
WHERE INTL_PACK_FORM_DESC = 'SALBE WEISS';

UPDATE grr_form
   SET NFC_123_CD = 'MYT'
WHERE INTL_PACK_FORM_DESC = 'SCHAUM';

UPDATE grr_form
   SET NFC_123_CD = 'MGT'
WHERE INTL_PACK_FORM_DESC = 'SHAKING MIX';

UPDATE grr_form
   SET NFC_123_CD = 'AAK'
WHERE INTL_PACK_FORM_DESC = 'SLB TAB';

UPDATE grr_form
   SET NFC_123_CD = 'DGF'
WHERE INTL_PACK_FORM_DESC = 'SUBL LIQ';

UPDATE grr_form
   SET NFC_123_CD = 'AAF'
WHERE INTL_PACK_FORM_DESC = 'SUBL TAB';

UPDATE grr_form
   SET NFC_123_CD = 'MSA'
WHERE INTL_PACK_FORM_DESC = 'SUBSTANZ';

UPDATE grr_form
   SET NFC_123_CD = 'DGK'
WHERE INTL_PACK_FORM_DESC = 'SUSP';

UPDATE grr_form
   SET NFC_123_CD = 'DGK'
WHERE INTL_PACK_FORM_DESC = 'SUSP PALMIT.';

UPDATE grr_form
   SET NFC_123_CD = 'ADG'
WHERE INTL_PACK_FORM_DESC = 'SWEET';

UPDATE grr_form
   SET NFC_123_CD = 'AAA'
WHERE INTL_PACK_FORM_DESC = 'TAB';

UPDATE grr_form
   SET NFC_123_CD = 'AAA'
WHERE INTL_PACK_FORM_DESC = 'TABL';

UPDATE grr_form
   SET NFC_123_CD = 'AAA'
WHERE INTL_PACK_FORM_DESC = 'TABL VIT+MIN';

UPDATE grr_form
   SET NFC_123_CD = 'JWN'
WHERE INTL_PACK_FORM_DESC = 'TD PATCH';

UPDATE grr_form
   SET NFC_123_CD = 'DKP'
WHERE INTL_PACK_FORM_DESC = 'TEA BAG';

UPDATE grr_form
   SET NFC_123_CD = 'DGK'
WHERE INTL_PACK_FORM_DESC = 'TINKT';

UPDATE grr_form
   SET NFC_123_CD = 'HLA'
WHERE INTL_PACK_FORM_DESC = 'TMP W SUB';

UPDATE grr_form
   SET NFC_123_CD = 'DGA'
WHERE INTL_PACK_FORM_DESC = 'TONIKUM';

UPDATE grr_form
   SET NFC_123_CD = 'MSZ'
WHERE INTL_PACK_FORM_DESC = 'TOP COMB OINT';

UPDATE grr_form
   SET NFC_123_CD = 'MHZ'
WHERE INTL_PACK_FORM_DESC = 'TOP COMB P.AERO';

UPDATE grr_form
   SET NFC_123_CD = 'MTA'
WHERE INTL_PACK_FORM_DESC = 'TOP CRM';

UPDATE grr_form
   SET NFC_123_CD = 'MGB'
WHERE INTL_PACK_FORM_DESC = 'TOP DRP';

UPDATE grr_form
   SET NFC_123_CD = 'MGJ'
WHERE INTL_PACK_FORM_DESC = 'TOP DRY SUSP';

UPDATE grr_form
   SET NFC_123_CD = 'MGL'
WHERE INTL_PACK_FORM_DESC = 'TOP EMUL';

UPDATE grr_form
   SET NFC_123_CD = 'MVL'
WHERE INTL_PACK_FORM_DESC = 'TOP EMUL GEL';

UPDATE grr_form
   SET NFC_123_CD = 'MVA'
WHERE INTL_PACK_FORM_DESC = 'TOP GEL';

UPDATE grr_form
   SET NFC_123_CD = 'MGS'
WHERE INTL_PACK_FORM_DESC = 'TOP LOT';

UPDATE grr_form
   SET NFC_123_CD = 'MHP'
WHERE INTL_PACK_FORM_DESC = 'TOP MD AERO';

UPDATE grr_form
   SET NFC_123_CD = 'MLX'
WHERE INTL_PACK_FORM_DESC = 'TOP MICRO ENEMA';

UPDATE grr_form
   SET NFC_123_CD = 'MTY'
WHERE INTL_PACK_FORM_DESC = 'TOP OTH CRM';

UPDATE grr_form
   SET NFC_123_CD = 'MVY'
WHERE INTL_PACK_FORM_DESC = 'TOP OTH GEL';

UPDATE grr_form
   SET NFC_123_CD = 'MHA'
WHERE INTL_PACK_FORM_DESC = 'TOP P.AERO';

UPDATE grr_form
   SET NFC_123_CD = 'MHT'
WHERE INTL_PACK_FORM_DESC = 'TOP P.FOAM';

UPDATE grr_form
   SET NFC_123_CD = 'MHS'
WHERE INTL_PACK_FORM_DESC = 'TOP P.OINT';

UPDATE grr_form
   SET NFC_123_CD = 'MHC'
WHERE INTL_PACK_FORM_DESC = 'TOP P.PWD';

UPDATE grr_form
   SET NFC_123_CD = 'MSB'
WHERE INTL_PACK_FORM_DESC = 'TOP PASTE';

UPDATE grr_form
   SET NFC_123_CD = 'MEA'
WHERE INTL_PACK_FORM_DESC = 'TOP PWD';

UPDATE grr_form
   SET NFC_123_CD = 'MEK'
WHERE INTL_PACK_FORM_DESC = 'TOP SLB PWD';

UPDATE grr_form
   SET NFC_123_CD = 'MYK'
WHERE INTL_PACK_FORM_DESC = 'TOP STK';

UPDATE grr_form
   SET NFC_123_CD = 'MYK'
WHERE INTL_PACK_FORM_DESC = 'TOP STYLI';

UPDATE grr_form
   SET NFC_123_CD = 'MLA'
WHERE INTL_PACK_FORM_DESC = 'TOP SUP ADULT';

UPDATE grr_form
   SET NFC_123_CD = 'MGK'
WHERE INTL_PACK_FORM_DESC = 'TOP SUSP';

UPDATE grr_form
   SET NFC_123_CD = 'DGB'
WHERE INTL_PACK_FORM_DESC = 'TROPF';

UPDATE grr_form
   SET NFC_123_CD = 'JRP'
WHERE INTL_PACK_FORM_DESC = 'UD CART';

UPDATE grr_form
   SET NFC_123_CD = 'AEB'
WHERE INTL_PACK_FORM_DESC = 'UD GRAN';

UPDATE grr_form
   SET NFC_123_CD = 'DEP'
WHERE INTL_PACK_FORM_DESC = 'UD PWD';

UPDATE grr_form
   SET NFC_123_CD = 'TCA'
WHERE INTL_PACK_FORM_DESC = 'VAG CAP';

UPDATE grr_form
   SET NFC_123_CD = 'TTZ'
WHERE INTL_PACK_FORM_DESC = 'VAG COMB CRM';

UPDATE grr_form
   SET NFC_123_CD = 'TLZ'
WHERE INTL_PACK_FORM_DESC = 'VAG COMB SUP';

UPDATE grr_form
   SET NFC_123_CD = 'TTA'
WHERE INTL_PACK_FORM_DESC = 'VAG CRM';

UPDATE grr_form
   SET NFC_123_CD = 'TVA'
WHERE INTL_PACK_FORM_DESC = 'VAG FOAM';

UPDATE grr_form
   SET NFC_123_CD = 'TVA'
WHERE INTL_PACK_FORM_DESC = 'VAG GEL';

UPDATE grr_form
   SET NFC_123_CD = 'TVA'
WHERE INTL_PACK_FORM_DESC = 'VAG P.FOAM';

UPDATE grr_form
   SET NFC_123_CD = 'TLS'
WHERE INTL_PACK_FORM_DESC = 'VAG SUP';

UPDATE grr_form
   SET NFC_123_CD = 'TWE'
WHERE INTL_PACK_FORM_DESC = 'VAG TMP W SUB';

UPDATE grr_form
   SET NFC_123_CD = 'TTN'
WHERE INTL_PACK_FORM_DESC = 'VAG UD CRM';

UPDATE grr_form
   SET NFC_123_CD = 'TVN'
WHERE INTL_PACK_FORM_DESC = 'VAG UD GEL';

UPDATE grr_form
   SET NFC_123_CD = 'MTA'
WHERE INTL_PACK_FORM_DESC = 'VASELINE';

END $_$;

--give to dose form correct name
DROP TABLE IF EXISTS grr_form_2;

CREATE TABLE grr_form_2 
AS
SELECT DISTINCT fcc,
       concept_code,
       concept_name,
       intl_pack_form_desc
FROM grr_form a
  JOIN concept b ON nfc_123_cd = concept_code
WHERE vocabulary_id = 'NFC';

--create  table with ingredients
DROP TABLE IF EXISTS grr_ing_2;

CREATE TABLE grr_ing_2 
AS
SELECT ingredient,
       fcc
FROM (SELECT DISTINCT TRIM(UNNEST(REGEXP_MATCHES(t.substance,'[^\+]+','g'))) AS ingredient,
             fcc
      FROM source_data_1 t) AS s
WHERE ingredient NOT IN ('MULTI SUBSTANZ','ENZYME (UNSPECIFIED)','NASAL DECONGESTANTS','ANTACIDS','ELECTROLYTE SOLUTIONS','ANTI-PSORIASIS','TOPICAL ANALGESICS');

--find OMOP codes that aren't used
DO $$ DECLARE ex INTEGER;

BEGIN
SELECT MAX(REPLACE(concept_code,'OMOP','')::INT4) +1 INTO ex
FROM devv5.concept
WHERE concept_code LIKE 'OMOP%'
AND   concept_code NOT LIKE '% %';

DROP SEQUENCE IF EXISTS new_vocab;

EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';

END $$;

--creating table with all concepts that need to have OMOP code
DROP TABLE IF EXISTS list;

CREATE TABLE list 
AS
SELECT DISTINCT bn AS concept_name,
       'Brand Name' AS concept_class_id,
       NULL::VARCHAR(255) AS concept_code
FROM grr_bn_2
UNION
SELECT DISTINCT PRI_ORG_LNG_NM,
       'Supplier',
       NULL::VARCHAR(255)
FROM grr_manuf
UNION
SELECT DISTINCT ingredient,
       'Ingredient',
       NULL::VARCHAR(255)
FROM grr_ing_2
WHERE ingredient IS NOT NULL;

UPDATE list
   SET concept_code = 'OMOP' || nextval('new_vocab');

--create source name for drugs
DROP TABLE IF EXISTS dcs_drugs;

CREATE TABLE dcs_drugs 
AS
SELECT INITCAP(therapy_name) AS concept_name,
       fcc
FROM source_data_1;

--create table with units
DROP TABLE IF EXISTS dcs_unit;

CREATE TABLE dcs_unit 
AS
SELECT DISTINCT REPLACE(WGT_UOM_CD,'.','') AS concept_code,
       'Unit' AS concept_class_id,
       REPLACE(WGT_UOM_CD,'.','') AS concept_name
FROM (SELECT STRENGTH_UNIT AS WGT_UOM_CD
      FROM source_data_1
      UNION ALL
      SELECT VOLUME_UNIT
      FROM source_data_1
      UNION ALL
      SELECT 'ACTUAT' UNION ALL SELECT 'HOUR') AS s0
WHERE WGT_UOM_CD IS NOT NULL
AND   WGT_UOM_CD NOT IN ('','--','Y/H');

--erease drug_concept_stage and fill it with actual concepts
TRUNCATE TABLE drug_concept_stage;

--fill drug_concept_stage with Drug Products from dcs_drugs, source attributes from list, grr_from_2, dcs_units
INSERT INTO drug_concept_stage
(
  CONCEPT_NAME,
  VOCABULARY_ID,
  CONCEPT_CLASS_ID,
  STANDARD_CONCEPT,
  CONCEPT_CODE,
  POSSIBLE_EXCIPIENT,
  DOMAIN_ID,
  VALID_START_DATE,
  VALID_END_DATE,
  INVALID_REASON,
  SOURCE_CONCEPT_CLASS_ID
)
SELECT DISTINCT CONCEPT_NAME,
       'GRR',
       CONCEPT_CLASS_ID,
       NULL,
       CONCEPT_CODE,
       NULL,
       'Drug',
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       NULL
FROM (SELECT concept_name,
             concept_class_id,
             concept_code
      FROM dcs_unit
      UNION ALL
      SELECT INITCAP(concept_name),
             concept_class_id,
             concept_code
      FROM list
      UNION ALL
      SELECT concept_name,
             'Drug Product',
             fcc
      FROM dcs_drugs
      UNION ALL
      SELECT concept_name,
             'Dose Form',
             concept_code
      FROM grr_form_2) AS s0;

--put non-drug in drug_concept_stage
INSERT INTO drug_concept_stage
(
  CONCEPT_NAME,
  VOCABULARY_ID,
  CONCEPT_CLASS_ID,
  STANDARD_CONCEPT,
  CONCEPT_CODE,
  POSSIBLE_EXCIPIENT,
  domain_id,
  VALID_START_DATE,
  VALID_END_DATE,
  INVALID_REASON,
  SOURCE_CONCEPT_CLASS_ID
)
SELECT DISTINCT brand_name,
       'GRR',
       'Device',
       'S',
       a.fcc,
       NULL,
       'Device',
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       NULL
FROM grr_non_drug a;

-- insert missing unit to drug_concept_stage
INSERT INTO drug_concept_stage
(
  concept_name,
  vocabulary_id,
  concept_class_id,
  concept_code,
  domain_id,
  valid_start_date,
  valid_end_date
)
VALUES
(
  'MCG',
  'GRR',
  'Unit',
  'MCG',
  'Drug',
  CURRENT_DATE,
  TO_DATE('20991231','yyyymmdd')
);

--filling relation between source attributes and standard attributes
TRUNCATE TABLE relationship_to_concept;

--insert mapping for attributes from previous iteration
INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence,
  conversion_factor
)
SELECT DISTINCT d.concept_code,
       'GRR',
       CONCEPT_id,
       precedence,
       conversion_factor
FROM r_t_c_all r
  JOIN drug_concept_stage d ON UPPER (d.concept_name) = UPPER (r.concept_name)
  JOIN concept c USING (concept_id)
WHERE c.invalid_reason IS NULL or c.invalid_reason = 'U';

--automated mapping for attribute
INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence
)
SELECT DISTINCT dcs.concept_code,
       'GRR',
       cc.concept_id,
       1
FROM drug_concept_stage dcs
  LEFT JOIN relationship_to_concept cr ON dcs.concept_code = cr.concept_code_1
  JOIN concept cc
    ON LOWER (cc.concept_name) = LOWER (dcs.concept_name)
   AND cc.concept_class_id = dcs.concept_class_id
   AND cc.vocabulary_id LIKE 'RxNorm%'
WHERE concept_code_1 IS NULL
AND   dcs.concept_class_id IN ('Ingredient','Brand Name','Dose Form','Supplier')
AND   cc.invalid_reason IS NULL or cc.invalid_reason = 'U';

--update relationship_to_concept if targeted concept has U
UPDATE relationship_to_concept r1
   SET concept_id_2 = cr.concept_id_2
FROM relationship_to_concept rtc
  JOIN concept c1 ON concept_id = concept_id_2
  JOIN concept_relationship cr
    ON concept_id_1 = concept_id
   AND relationship_id = 'Concept replaced by'
WHERE r1.concept_code_1 = rtc.concept_code_1
AND   c1.invalid_reason IS NOT NULL;

--create table that need to map manually by medical coder
drop table if exists relationship_to_concept_to_map;
create table relationship_to_concept_to_map
(
 source_attr_name varchar(255),
 source_attr_concept_class varchar(50),
 target_concept_id integer,
 target_concept_code varchar(50),
 target_concept_name varchar(255),
 precedence integer,
 conversion_factor float,
 indicator_rxe varchar(10)
);

--extract source attributes that aren't mapped and do it manually
insert into relationship_to_concept_to_map
(
  source_attr_name,
  source_attr_concept_class
)
select concept_name as source_attr_name, concept_class_id as source_attr_concept_class
from drug_concept_stage 
left join relationship_to_concept on concept_code_1 = concept_code 
where concept_code_1 is null 
and concept_class_id not in ('Drug Product','Device');

--erase relationship_to_concept_manual table 
truncate relationship_to_concept_manual;

--fill manual table
insert into relationship_to_concept_manual
;

--insert all manual work into r_t_c
insert into relationship_to_concept
(
concept_code_1,
vocabulary_id_1,
concept_id_2,
precedence,
conversion_factor
)
select dcs.concept_code, dcs.vocabulary_id, mt.target_concept_id, mt.precedence, mt.conversion_factor
from drug_concept_stage dcs
join relationship_to_concept_manual mt on upper(mt.source_attr_name) = upper(dcs.concept_name)
;

--delete attributes they aren't mapped to RxNorm% and which we don't want to create
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1,concept_code_2) IN (SELECT irs.*
                                          FROM internal_relationship_stage irs 
                                            JOIN drug_concept_stage dcs ON dcs.concept_code = irs.concept_code_2
                                            JOIN relationship_to_concept_manual rtc ON upper(rtc.source_attr_name) = upper(dcs.concept_name)
                                          WHERE rtc.indicator_rxe IS NULL and rtc.target_concept_id IS NULL);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (SELECT concept_code
                       FROM drug_concept_stage dcs
                        JOIN relationship_to_concept_manual rtc ON upper(rtc.source_attr_name) = upper(dcs.concept_name)
                       WHERE rtc.indicator_rxe IS NULL and rtc.target_concept_id IS NULL);


--filling internal relationship between source drugs and their attributes
TRUNCATE TABLE internal_relationship_stage;

INSERT INTO internal_relationship_stage
SELECT fcc,
       concept_code
FROM grr_form_2
UNION
--drug to bn
SELECT fcc,
       concept_code
FROM grr_bn_2
  JOIN drug_concept_stage ON UPPER (bn) = UPPER (concept_name)
WHERE concept_class_id = 'Brand Name'
UNION
--drug to supp
SELECT fcc,
       concept_code
FROM grr_manuf
  JOIN drug_concept_stage ON UPPER (PRI_ORG_LNG_NM) = UPPER (concept_name)
WHERE concept_class_id = 'Supplier'
UNION
--drug to ingr
SELECT fcc,
       concept_code
FROM grr_ing_2
  JOIN drug_concept_stage b
    ON UPPER (ingredient) = UPPER (concept_name)
   AND concept_class_id = 'Ingredient';

--extract dosage from source_data
DROP TABLE IF EXISTS ds_0_sd_2;

CREATE TABLE ds_0_sd_2 
AS
SELECT DISTINCT a.fcc,
       substance,
       CASE
         WHEN STRENGTH = '0.0' THEN NULL
         ELSE STRENGTH
       END AS STRENGTH,
       CASE
         WHEN STRENGTH_UNIT = 'Y/H' THEN 'MCG'
         WHEN STRENGTH_UNIT = 'K.' THEN 'K'
         ELSE STRENGTH_UNIT
       END AS STRENGTH_UNIT,
       CASE
         WHEN VOLUME = '0.0' THEN NULL
         ELSE VOLUME
       END AS VOLUME,
       CASE
         WHEN STRENGTH_UNIT = 'Y/H' THEN 'HOUR'
         WHEN VOLUME_UNIT = 'K.' THEN 'K'
         ELSE VOLUME_UNIT
       END AS VOLUME_UNIT,
       b.concept_code,
       b.concept_name,
       SUBSTRING(CAST(PACKSIZE AS VARCHAR),'(\d+)\.\d+')::INT4 AS box_size,
       PRODUCT_FORM_NAME,
       therapy_name
FROM source_data_1 a
  LEFT JOIN grr_form_2 b ON a.fcc = b.fcc
WHERE NO_OF_SUBSTANCES = '1'
OR    (NO_OF_SUBSTANCES != '1' AND STRENGTH != '0')
AND   substance NOT LIKE '%+%';

UPDATE ds_0_sd_2
   SET volume_unit = NULL
WHERE volume_unit = '';

UPDATE ds_0_sd_2
   SET STRENGTH_UNIT = NULL
WHERE STRENGTH_UNIT = '';

--convert percent to normal units
DROP TABLE if exists ds_0_sd_1;

CREATE TABLE ds_0_sd_1 
AS
SELECT fcc,
       therapy_name,
       concept_name,
       box_size,
       substance,
       strength AS amount,
       strength_unit AS amount_unit,
       CASE
         WHEN strength_unit = '%' THEN CAST(strength AS FLOAT)*10
         ELSE CAST(strength AS FLOAT)
       END AS numerator,
       strength_unit AS numerator_unit,
       CAST(volume AS FLOAT) AS denominator,
       volume_unit AS denominator_unit
FROM ds_0_sd_2;

UPDATE ds_0_sd_1
   SET amount_unit = NULL
WHERE amount IS NULL;

UPDATE ds_0_sd_1
   SET denominator_unit = 'ML'
WHERE numerator_unit = '%'
AND   denominator_unit IS NULL;

UPDATE ds_0_sd_1
   SET numerator_unit = 'MG'
WHERE numerator_unit = '%';

UPDATE ds_0_sd_1
   SET numerator = NULL,
       numerator_unit = NULL
WHERE amount is not  null
AND   amount_unit is not  null
AND   denominator IS NULL
AND   denominator_unit IS NULL;

UPDATE ds_0_sd_1
   SET amount = NULL,
       amount_unit = NULL
WHERE amount IS NOT NULL
AND   amount_unit IS NOT NULL
AND   numerator IS NOT NULL
AND   numerator_unit IS NOT NULL
AND   denominator_unit IS NOT NULL;

--extract dosage from therapy_name
DROP TABLE if exists ds_0_sd;

CREATE TABLE ds_0_sd 
AS
SELECT fcc,
       therapy_name,
       concept_name,
       box_size,
       amount,
       amount_unit,
       substance,
       CASE
         WHEN therapy_name ~ '\d+(IU|MG|MCG|D|Y|C)(\s)?\/\d+ML' AND denominator IS NOT NULL THEN (numerator / 5)*denominator
         WHEN therapy_name ~ '\d+(IU|MG|MCG|D|Y|C)\s?\/(ML|G)|\%' AND denominator IS NOT NULL THEN numerator*denominator
         ELSE numerator
       END numerator,
       numerator_unit,
       denominator,
       denominator_unit
FROM ds_0_sd_1;

--delete drugs with wrong units
DELETE
FROM ds_0_sd
WHERE fcc IN (SELECT fcc
              FROM ds_0_sd
              WHERE amount_unit IN ('--','LM','NR')
              OR    numerator_unit IN ('--','LM','NR')
              OR    denominator_unit IN ('--','LM','NR'));

DELETE
FROM ds_0_sd
WHERE amount IS NULL
AND   amount_unit IS NULL
AND   numerator IS NULL
AND   numerator_unit IS NULL
AND   denominator IS NOT NULL
AND   denominator_unit IS NOT NULL;

--fill ds_stage
TRUNCATE TABLE ds_stage;

INSERT INTO ds_stage
(
  DRUG_CONCEPT_CODE,
  INGREDIENT_CONCEPT_CODE,
  BOX_SIZE,
  AMOUNT_VALUE,
  AMOUNT_UNIT,
  NUMERATOR_VALUE,
  NUMERATOR_UNIT,
  DENOMINATOR_VALUE,
  DENOMINATOR_UNIT
)
SELECT fcc,
       b.concept_code,
       box_size,
       amount,
       AMOUNT_UNIT,
       NUMERATOR,
       NUMERATOR_UNIT,
       DENOMINATOR,
       DENOMINATOR_UNIT
FROM ds_0_sd a
  JOIN drug_concept_stage b
    ON UPPER (b.concept_name) = UPPER (substance)
   AND b.concept_class_id = 'Ingredient';

DELETE
FROM ds_stage
WHERE numerator_unit = 'O'
OR    amount_unit = 'O';

DELETE
FROM ds_stage
WHERE numerator_value = 0.0
OR    amount_value = 0.0;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE amount_unit IS NULL
                            AND   numerator_unit IS NULL);

UPDATE ds_stage
   SET denominator_value = NULL,
       denominator_unit = NULL
WHERE denominator_value = 0.0;

UPDATE ds_stage
   SET numerator_value = NULL,
       numerator_unit = NULL
WHERE amount_value = numerator_value
AND   amount_unit = numerator_unit;

--find dosage for multiple drugs
DROP TABLE if exists grr_mult;

CREATE TABLE grr_mult 
AS
WITH r_ds AS
(
  SELECT DISTINCT drug_concept_id,
         STRING_AGG(ingredient_concept_id::VARCHAR,'-' ORDER BY ingredient_concept_id) AS r_i_combo,
         STRING_AGG(amount_value::VARCHAR,'-' ORDER BY ingredient_concept_id) AS r_d_combo
  FROM drug_strength
    JOIN concept
      ON concept_id = drug_concept_id
     AND concept_class_id = 'Clinical Drug'
  GROUP BY drug_concept_id,
           vocabulary_id
  HAVING COUNT(1) = 2
),

q_ds
AS
(
SELECT fcc AS q_code,
       STRING_AGG(rtc.concept_Id_2::VARCHAR,'-' ORDER BY concept_Id_2) AS q_ing_combo,
       SUBSTRING(therapy_name,'(\d+\.?\d?)(/|-- )') || '-' ||regexp_replace(SUBSTRING(therapy_name,'((/|-- )\d+\.?\d?)'),'(/|-- )','') AS q_d_combo
FROM source_data_1
  JOIN internal_relationship_stage irs ON fcc = irs.concept_code_1
  JOIN relationship_to_concept rtc
    ON irs.concept_code_2 = rtc.concept_code_1
   AND precedence = 1
  JOIN concept
    ON concept_id = concept_id_2
   AND concept_class_id = 'Ingredient'
WHERE substance LIKE '%+%'
GROUP BY fcc,
         therapy_name
UNION
SELECT fcc AS q_code,
       STRING_AGG(rtc.concept_Id_2::VARCHAR,'-' ORDER BY concept_Id_2) AS q_ing_combo,
       REGEXP_REPLACE(SUBSTRING(therapy_name,'((/|-- )\d+\.?\d?)'),'(/|-- )','') || '-' ||SUBSTRING(therapy_name,'(\d+\.?\d?)(/|-- )') AS q_d_combo
FROM source_data_1
  JOIN internal_relationship_stage irs ON fcc = irs.concept_code_1
  JOIN relationship_to_concept rtc
    ON irs.concept_code_2 = rtc.concept_code_1
   AND precedence = 1
  JOIN concept
    ON concept_id = concept_id_2
   AND concept_class_id = 'Ingredient'
WHERE substance LIKE '%+%'
GROUP BY fcc,
         therapy_name
),

c_m
AS
(
SELECT DISTINCT q_code,
       SUBSTRING(q_ing_combo,'(\d+)\-') AS ing,
       SUBSTRING(q_d_combo,'(\d+(\.?)(\d+)?)') AS d1
FROM q_ds
  JOIN r_ds
    ON q_ing_combo = r_i_combo
   AND q_d_combo = r_d_combo
UNION
SELECT DISTINCT q_code,
       SUBSTRING(q_ing_combo,'\d+\-(\d+)') AS ing,
       REGEXP_REPLACE(SUBSTRING(q_d_combo,'(\-\d+(\.)?(\d+)?)'),'-','') AS d1
FROM q_ds
  JOIN r_ds
    ON q_ing_combo = r_i_combo
   AND q_d_combo = r_d_combo
)
   
SELECT q_code,
       rtc.concept_code_1,
       d1
FROM c_m
  JOIN relationship_to_concept rtc ON CAST (c_m.ing AS INTEGER) = rtc.concept_id_2;
DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT q_code FROM grr_mult);

INSERT INTO ds_stage
(
  DRUG_CONCEPT_CODE,
  INGREDIENT_CONCEPT_CODE,
  BOX_SIZE,
  AMOUNT_VALUE,
  AMOUNT_UNIT
)
SELECT q_code,
       concept_code_1,
       CAST(SUBSTRING(CAST(packsize AS VARCHAR),'\d+') AS INTEGER),
       CAST(d1 AS FLOAT),
       'MG'
FROM grr_mult
  JOIN source_data_1 ON fcc = q_code;

--delete homeopathy liquids
DELETE
FROM drug_concept_stage
WHERE concept_code IN (SELECT drug_concept_code
                       FROM ds_stage
                       WHERE numerator_unit IN ('DH','C','CH','D','TM','X','XMK')
                       AND   denominator_value IS NOT NULL);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (SELECT drug_concept_code
                         FROM ds_stage
                         WHERE numerator_unit IN ('DH','C','CH','D','TM','X','XMK')
                         AND   denominator_value IS NOT NULL);

DELETE
FROM ds_stage
WHERE numerator_unit IN ('DH','C','CH','D','TM','X','XMK')
AND   denominator_value IS NOT NULL;

--delete units that aren't used
DELETE
FROM drug_concept_stage
WHERE concept_code IN (SELECT CONCEPT_CODE
                       FROM drug_concept_Stage a
                         LEFT JOIN relationship_to_concept b ON a.concept_code = b.concept_code_1
                       WHERE concept_class_id IN ('Unit')
                       AND   b.concept_code_1 IS NULL);

--delete suppliers  from drugs without dosage
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1,concept_code_2) IN (SELECT concept_code_1,
                                                 concept_code_2
                                          FROM internal_relationship_stage
                                            JOIN drug_concept_stage
                                              ON concept_code_2 = concept_code
                                             AND concept_class_id = 'Supplier'
                                            LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
                                          WHERE drug_concept_code IS NULL);

-- update concept code for concept that already exist in devv5
DROP TABLE if exists code_replace;

CREATE TABLE code_replace 
AS
SELECT DISTINCT d.concept_code AS old_code,
       d.concept_name AS name,
       MIN(c.concept_code) OVER (PARTITION BY c.concept_name,c.vocabulary_id = 'GRR') AS new_code
FROM drug_concept_stage d
  JOIN devv5.concept c
    ON UPPER (c.concept_name) = TRIM (UPPER (d.concept_name))
   AND c.vocabulary_id = 'GRR'
   AND c.concept_class_id NOT IN ('Device', 'Drug Product')
WHERE d.concept_code LIKE 'OMOP%';

UPDATE drug_concept_stage a
   SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;

UPDATE relationship_to_concept a
   SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE ds_stage a
   SET ingredient_concept_code = b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code;

UPDATE ds_stage a
   SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE internal_relationship_stage a
   SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE internal_relationship_stage a
   SET concept_code_2 = b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code;

UPDATE pc_stage a
   SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;


--create name for source concept
DROP TABLE IF EXISTS ds_stage_cnc;

CREATE TABLE ds_stage_cnc 
AS
SELECT CONCAT(denominator_value,' ',denominator_unit) AS quant,
       drug_concept_code,
       CASE
         WHEN therapy_name ~ '\d+\.?\d+?(MG|G|Y|K)\s\/(\d+)?(ML|G)' THEN CONCAT (i.concept_name,' ',COALESCE(amount_value,numerator_value),' ',COALESCE(amount_unit,numerator_unit),COALESCE('/' ||denominator_unit))
         ELSE CONCAT (i.concept_name,' ',ROUND((COALESCE(amount_value,numerator_value /COALESCE(denominator_value,1)))::NUMERIC,(3 - FLOOR(LOG(COALESCE(amount_value,numerator_value /COALESCE(denominator_value,1)))) -1)::INT),' ',COALESCE(amount_unit,numerator_unit))
       END AS dosage_name
FROM ds_stage
  JOIN source_data_1 ON fcc = drug_concept_code
  JOIN drug_concept_stage i ON i.concept_code = ingredient_concept_code;

DROP TABLE IF EXISTS ds_stage_cnc2;

CREATE TABLE ds_stage_cnc2 
AS
SELECT quant,
       drug_concept_code,
       STRING_AGG(dosage_name,' / ' ORDER BY DOSAGE_NAME ASC) AS dos_name_cnc
FROM ds_stage_cnc
GROUP BY quant,
         drug_concept_code;

DROP TABLE IF EXISTS ds_stage_cnc3;

CREATE TABLE ds_stage_cnc3 
AS
SELECT quant,
       drug_concept_code,
       CASE
         WHEN quant ~ '^\d.*' THEN CONCAT (quant,' ',dos_name_cnc)
         ELSE dos_name_cnc
       END AS strength_name
FROM ds_stage_cnc2;

DROP TABLE IF EXISTS rel_to_name;

CREATE TABLE rel_to_name 
AS
SELECT ri.*,
       d.concept_name,
       d.concept_class_id
FROM internal_relationship_stage ri
  JOIN drug_concept_stage d ON concept_code = concept_code_2;

DROP TABLE IF EXISTS new_name;

CREATE TABLE new_name 
AS
SELECT DISTINCT c.drug_concept_code,
       CONCAT(strength_name,CASE WHEN f.concept_name IS NOT NULL THEN CONCAT (' ',f.concept_name) ELSE NULL END,CASE WHEN b.concept_name IS NOT NULL THEN CONCAT (' [',b.concept_name,']') ELSE NULL END,CASE WHEN ds.box_size IS NOT NULL THEN CONCAT (' Box of ',ds.box_size) ELSE NULL END,CASE WHEN s.concept_name IS NOT NULL THEN CONCAT (' by ',s.concept_name) ELSE NULL END) AS concept_name
FROM ds_stage_cnc3 c
  LEFT JOIN rel_to_name f
         ON c.drug_concept_code = f.concept_code_1
        AND f.concept_class_id = 'Dose Form'
  LEFT JOIN rel_to_name b
         ON c.drug_concept_code = b.concept_code_1
        AND b.concept_class_id = 'Brand Name'
  LEFT JOIN rel_to_name s
         ON c.drug_concept_code = s.concept_code_1
        AND s.concept_class_id = 'Supplier'
  LEFT JOIN ds_stage ds ON c.drug_concept_code = ds.drug_concept_code;

INSERT INTO new_name
SELECT DISTINCT a.concept_code,
       CONCAT(a.ingred_name,CASE WHEN f.concept_name IS NOT NULL THEN CONCAT (' ',f.concept_name) ELSE NULL END,CASE WHEN b.concept_name IS NOT NULL THEN CONCAT (' [',b.concept_name,']') ELSE NULL END,CASE WHEN ds.box_size IS NOT NULL THEN CONCAT (' Box of ',ds.box_size) ELSE NULL END,CASE WHEN s.concept_name IS NOT NULL THEN CONCAT (' by ',s.concept_name) ELSE NULL END) AS concept_name
FROM (SELECT DISTINCT ca.concept_code,
             STRING_AGG(i.concept_name,'/') OVER (PARTITION BY ca.concept_code) AS ingred_name
      FROM (SELECT DISTINCT *
            FROM drug_concept_stage
            WHERE UPPER(concept_name) IN (SELECT therapy_name FROM source_data_1)) ca
        JOIN rel_to_name i
          ON ca.concept_code = i.concept_code_1
         AND i.concept_class_id = 'Ingredient') a
  LEFT JOIN rel_to_name f
         ON a.concept_code = f.concept_code_1
        AND f.concept_class_id = 'Dose Form'
  LEFT JOIN rel_to_name b
         ON a.concept_code = b.concept_code_1
        AND b.concept_class_id = 'Brand Name'
  LEFT JOIN rel_to_name s
         ON a.concept_code = s.concept_code_1
        AND s.concept_class_id = 'Supplier'
  LEFT JOIN ds_stage ds ON a.concept_code = ds.drug_concept_code
WHERE a.concept_code NOT IN (SELECT drug_concept_code FROM new_name);

UPDATE drug_concept_stage a
   SET concept_name = SUBSTR(n.concept_name,1,255)
FROM new_name n
WHERE n.drug_concept_code = a.concept_code;

--insert into r_t_c_all from current rtc for future use
INSERT INTO r_t_c_all 
(
concept_name,
concept_id,
precedence,
conversion_factor
)
SELECT concept_name,
       concept_id_2,
       precedence,
       conversion_factor
FROM drug_concept_stage
  JOIN relationship_to_concept ON concept_code = concept_code_1
WHERE UPPER(concept_name) NOT IN (SELECT UPPER(concept_name) FROM r_t_c_all);
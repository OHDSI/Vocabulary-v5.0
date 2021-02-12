-- look at the difference between dev_icd10.crm and dev_icd10cm.crm

with icd10_map as (
select distinct a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
       
from dev_icd10.concept a
join dev_icd10.concept_relationship_manual r on a.concept_code = r.concept_code_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null and a.vocabulary_id = 'ICD10'
join dev_icd10.concept b on b.concept_code = r.concept_code_2 and b.vocabulary_id in ('SNOMED','Cancer Modifier')
where a.vocabulary_id = 'ICD10' and a.invalid_reason is null
group by a.concept_code, a.concept_name
),
icd10cm_map as (
select distinct a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
       
from dev_icd10cm.concept a
join dev_icd10cm.concept_relationship_manual r on a.concept_code = r.concept_code_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null and a.vocabulary_id = 'ICD10CM'
join dev_icd10cm.concept b on b.concept_code = r.concept_code_2 and b.vocabulary_id in ('SNOMED','Cancer Modifier')
where a.vocabulary_id = 'ICD10CM' and a.invalid_reason is null
group by a.concept_code, a.concept_name
)
select distinct
a.concept_code as icd10_code,
a.concept_name as icd10_name,
c1.concept_code as icd10_map_code,
c1.concept_name as icd10_map_name,
b.concept_code as icd10cm_code,
b.concept_name as icd10cm_name,
c2.concept_code as icd10cm_map_code,
c2.concept_name as icd10cm_map_name
from icd10_map  a
join icd10cm_map b
on a.concept_code = b.concept_code and (a.code_agg != b.code_agg or a.relationship_agg != b.relationship_agg)
join dev_icd10.concept_relationship_manual crm on a.concept_code = crm.concept_code_1
join dev_icd10cm.concept_relationship_manual crm1 on b.concept_code = crm1.concept_code_1 
join dev_icd10.concept c1 on crm.concept_code_2 = c1.concept_code and c1.vocabulary_id in ('SNOMED','Cancer Modifier')
join dev_icd10cm.concept c2 on crm1.concept_code_2 = c2.concept_code and c2.vocabulary_id in ('SNOMED','Cancer Modifier')
order by a.concept_code
;

-- crm table update

CREATE TABLE concept_relationship_manual_290121 
AS
SELECT *
FROM concept_relationship_manual;

UPDATE concept_relationship_manual
   SET concept_code_2 = '1087001000119105',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'A54.6';

UPDATE concept_relationship_manual
   SET concept_code_2 = '786878009',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'K60.3';

UPDATE concept_relationship_manual
   SET concept_code_2 = '394726009',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'L82';

UPDATE concept_relationship_manual
   SET concept_code_2 = '201219009',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'L70.4';

UPDATE concept_relationship_manual
   SET concept_code_2 = '367338000',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'L30.3';

UPDATE concept_relationship_manual
   SET concept_code_2 = '829821000000102',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'M31.7';

DELETE
FROM concept_relationship_manual
WHERE concept_code_1 = 'M85.2'
AND   concept_code_2 = '118945008';

UPDATE concept_relationship_manual
   SET concept_code_2 = '788954009',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'M85.2';

UPDATE concept_relationship_manual
   SET concept_code_2 = '156035004',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'N91.0';

UPDATE concept_relationship_manual
   SET concept_code_2 = '156036003',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'N91.1';

-- afre SNOMED update better mapping could be found. For these cases additional table can be created

CREATE TABLE concepts_for_refresh 
(
  icd10_code        VARCHAR,
  icd10_name        VARCHAR,
  relationship_id   VARCHAR,
  icd10map_code     VARCHAR,
  icd10map_name     VARCHAR
);

WbImport -file="C:/Users/nicol/Downloads/ICD10 mapping refresh - january 2021 - Лист2 (2).csv"
         -type=text
         -table=concepts_for_refresh
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter=','
         -quotechar='"'
         -decimal=.
         -fileColumns=icd10_code,icd10_name,relationship_id,icd10map_code,icd10map_name
         -quoteCharEscaping=NONE
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000; -- https://docs.google.com/spreadsheets/d/1AXSe6MR8gM0uzQ5q9bNOMv44Lcb4p8si39dmusegsM0/edit?usp=sharing

DELETE
FROM concept_relationship_manual
WHERE concept_code_1 IN (SELECT icd10_code FROM concepts_for_refresh);--201
INSERT INTO concept_relationship_manual
SELECT icd10_code,
       icd10map_code,
       'ICD10',
       'SNOMED',
       relationship_id,
       CURRENT_DATE -1,
       TO_DATE('20991231','yyyymmdd'),
       NULL
FROM concepts_for_refresh;--207

-- check boobos for necessary updates
UPDATE concept_relationship_manual
   SET concept_code_2 = '80659006',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'L02';

INSERT INTO concept_relationship_manual
VALUES
(
  'L02',
  '128139000',
  'ICD10',
  'SNOMED',
  'Maps to',
  CURRENT_DATE -1,
  TO_DATE('20991231','yyyymmdd'),
  NULL
);

INSERT INTO concept_relationship_manual
VALUES
(
  'C11.9',
  '226521000119108',
  'ICD10',
  'SNOMED',
  'Maps to',
  CURRENT_DATE -1,
  TO_DATE('20991231','yyyymmdd'),
  NULL
);

UPDATE concept_relationship_manual
   SET concept_code_2 = '69896004',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'M05.20'
AND   concept_code_2 = '287006005';

UPDATE concept_relationship_manual
   SET concept_code_2 = '722869007',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'K80.2';

UPDATE concept_relationship_manual
   SET concept_code_2 = '85005007',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'F12.9';

UPDATE concept_relationship_manual
   SET concept_code_2 = '120639003',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'B33.4';

UPDATE concept_relationship_manual
   SET concept_code_2 = '70209001',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'Y83';

UPDATE concept_relationship_manual
   SET concept_code_2 = '70209001',
       valid_start_date = CURRENT_DATE -1
WHERE concept_code_1 = 'Y84';

-- cancer modifier mapping
INSERT INTO concept_relationship_manual
SELECT b.concept_code_1,
       a.concept_code_2,
       'ICD10',
       'Cancer Modifier',
       'Maps to',
       CURRENT_DATE- 1,
       TO_DATE('20991231','yyyymmdd'),
       NULL
FROM dev_icd10cm.concept_relationship_manual a
  JOIN concept_relationship_manual b ON b.concept_code_1 = a.concept_code_1
WHERE a.vocabulary_id_2 = 'Cancer Modifier';

-- check for valid mapping
SELECT *
FROM concept_relationship_manual a
  JOIN dev_snomed.concept b
    ON b.concept_code = a.concept_code_2
   AND b.vocabulary_id = 'SNOMED'
   AND b.invalid_reason IS NOT NULL;

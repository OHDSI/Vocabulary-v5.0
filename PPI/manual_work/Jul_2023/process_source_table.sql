-- BHP (Behavioral Health and Personality) source table
TRUNCATE TABLE bhp;
CREATE TABLE bhp
(Variable_Field_Name	varchar,
Form_Name	varchar,
Section_Header	varchar,
Field_Type	varchar,
Field_Label	varchar,
Choices_Calculations_OR_Slider_Labels varchar,
Field_Note	varchar,
Text_Validation_Type_OR_Show_Slider_Number	varchar,
Text_Validation_Min	varchar,
Text_Validation_Max	varchar,
Identifier	varchar,
Branching_Logic varchar,
Required_Field	varchar,
Custom_Alignment	varchar,
Question_Number	varchar,
Matrix_Group_Name	varchar,
Matrix_Ranking	varchar,
Field_Annotation	varchar);

SELECT * FROM bhp; -- 69
CREATE TABLE bhp_pr_back as SELECT * FROM bhp_pr;

--Process answers
DROP TABLE answers;
CREATE TABLE answers as
    SELECT DISTINCT
           SPLIT_PART (TRIM(REGEXP_SPLIT_TO_TABLE(choices_calculations_or_slider_labels, '\|')), ', ', 1)  AS answer_code,
           SPLIT_PART (TRIM(REGEXP_SPLIT_TO_TABLE(choices_calculations_or_slider_labels, '\|')), ', ', 2)  AS answer_name
    FROM bhp;

SELECT * FROM answers;

--Processed BHP source table
DROP TABLE bhp_pr;
TRUNCATE TABLE bhp_pr;
CREATE TABLE bhp_pr (
    concept_code varchar,
    concept_name varchar,
    field_type varchar,
    flag varchar);

--Question insertion
INSERT INTO bhp_pr (concept_code,
                    concept_name,
                    field_type,
                    flag)
SELECT DISTINCT variable_field_name,
                CASE WHEN variable_field_name in ('asrs_1', 'asrs_2', 'asrs_3', 'asrs_4', 'asrs_5', 'asrs_6')
                THEN concat ('During the past 6 months' ||' '|| field_label)
                ELSE field_label
                END as concept_name,
                field_type,
                'q' as flag
FROM bhp
WHERE variable_field_name not in ('bhp', 'bhp_intro', 'mood_energy', 'panic_anxiety', 'recurring_thoughts', 'social_anxiety', 'personality', 'attention_focus', 'unusual_experiences');

SELECT DISTINCT concept_code, concept_name FROM dev_ppi.bhp_pr where length (concept_name) > 255;
-- Cut concept names longer than 255
UPDATE bhp_pr SET concept_name = 'Some people have a lot of fear about things like going out of the house alone, being in a crowd, going over bridges, or traveling by bus. Were you ever in your life frightened by any of these situations?'
WHERE concept_code = 'cidi5_30';
UPDATE bhp_pr SET concept_name = 'Have you ever been bothered with thoughts, images, or urges that kept coming back over and over, like concerns with germs, order, or experiencing horrific images or intrusive sexual thoughts, or urges to knock objects, or harming a loved one?'
WHERE concept_code = 'pmi_1';
UPDATE bhp_pr SET concept_name = 'Did you ever talk to a health professional about any of these experiences (such as seeing a vision, hearing a voice, believing that something strange was trying to communicate with you)?'
WHERE concept_code = 'mhqukb_55';

--Answers insertion
INSERT INTO bhp_pr (concept_code,
                    concept_name,
                    field_type,
                    flag)
SELECT DISTINCT answer_code,
                answer_name,
                NULL as field_type,
                'a' as flag
FROM answers;

DELETE FROM bhp_pr WHERE concept_code = 'bhp_44' and concept_name = 'Enter number'; -- to preserve only one variant for bhp_44
SELECT * FROM bhp_pr; --100

-- q-a pairs
DROP TABLE bhp_qa;
CREATE TABLE bhp_qa as (
WITH a
AS
(SELECT *,
  TRIM(REGEXP_SPLIT_TO_TABLE(choices_calculations_or_slider_labels, '\|')) AS answer
 FROM bhp)
     SELECT
     variable_field_name as question_code,
     field_label as question_name,
     SPLIT_PART(answer, ',', 1) AS answer_code,
     trim(SPLIT_PART(answer, ',', 2)) AS answer_name
     FROM a);

SELECT * FROM bhp_qa;
UPDATE bhp_qa SET answer_code = 'PMI_DontKnow' WHERE answer_code = 'pmi_dontknow';
UPDATE bhp_qa SET answer_code = 'PMI_PreferNotToAnswer' WHERE answer_code = 'pmi_prefernottoanswer';
UPDATE bhp_qa SET answer_code = 'PMI_None' WHERE answer_code = 'pmi_none';

SELECT * FROM bhp_qa;


-- EHH (Emotional Health history and Wellbeing) source table
TRUNCATE TABLE ehh;
CREATE TABLE ehh
(Variable_Field_Name	varchar,
Form_Name	varchar,
Section_Header	varchar,
Field_Type	varchar,
Field_Label	varchar,
Choices_Calculations_OR_Slider_Labels varchar,
Field_Note	varchar,
Text_Validation_Type_OR_Show_Slider_Number	varchar,
Text_Validation_Min	varchar,
Text_Validation_Max	varchar,
Identifier	varchar,
Branching_Logic varchar,
Required_Field	varchar,
Custom_Alignment	varchar,
Question_Number	varchar,
Matrix_Group_Name	varchar,
Matrix_Ranking	varchar,
Field_Annotation	varchar) ;

SELECT * FROM ehh; --122
CREATE TABLE ehh_pr_back as SELECT * FROM ehh_pr;

--Process answers
DROP TABLE ehh_answers;
CREATE TABLE ehh_answers as
    SELECT DISTINCT
           SPLIT_PART (TRIM(REGEXP_SPLIT_TO_TABLE(choices_calculations_or_slider_labels, '\|')), ', ', 1)  AS answer_code,
           SPLIT_PART (TRIM(REGEXP_SPLIT_TO_TABLE(choices_calculations_or_slider_labels, '\|')), ', ', 2)  AS answer_name
    FROM ehh;

SELECT * FROM ehh_answers;
DELETE FROM ehh_answers WHERE answer_code = 'ehhwb_10' and answer_name = 'More than half of the days'; -- to preserve only one variant
DELETE FROM ehh_answers WHERE answer_code = 'pmi_dontknow' and answer_name = 'Don''t know/Not sure';-- to preserve only one variant

--Processed BHP source table
DROP TABLE ehh_pr;
TRUNCATE TABLE ehh_pr;
CREATE TABLE ehh_pr (
    concept_code varchar,
    concept_name varchar,
    field_type varchar,
    flag varchar);

--Question insertion
INSERT INTO ehh_pr (concept_code,
                    concept_name,
                    field_type,
                    flag)
SELECT DISTINCT variable_field_name,
                CASE WHEN variable_field_name in ('gad7_1', 'gad7_2', 'gad7_3', 'gad7_4', 'gad7_5', 'gad7_6', 'gad7_7',
                                                 'phq9_1', 'phq9_2', 'phq9_3', 'phq9_4', 'phq9_5', 'phq9_6', 'phq9_7', 'phq9_8', 'phq9_9')
                THEN concat ('Over the last 2 weeks, how often have you been bothered by' ||' '|| lower (field_label))
                WHEN variable_field_name in ('mhqukb_29', 'mhqukb_30', 'mhqukb_31')
                THEN concat ('During feelings of depression or loss of interest' ||' '|| field_label)
                WHEN variable_field_name in ('cidi5_6', 'cidi5_7', 'cidi5_8', 'cidi5_9', 'cidi5_10', 'cidi5_11', 'cidi5_12', 'cidi5_13', 'cidi5_14', 'cidi5_15')
                THEN concat ('During those 6 months, how often did you' ||' '|| lower (field_label))
                ELSE field_label
                END as concept_name,
                field_type,
                'q' as flag
FROM ehh
WHERE variable_field_name not in ('ehhwb', 'ehhwb_intro', 'anxiety_worry', 'mood_sadness', 'depression_popup1', 'lifetime_symptoms',
                                  'twoweekperiod_depression', 'depression_popup2', 'depression_help', 'self_harm', 'suicide_popup', 'trauma',
                                  'trauma_popup1', 'trauma_popup2', 'ptsd', 'well_being', 'depression', 'worryanxiety_yes', 'worryanxiety_yes_2');


--Answers insertion
INSERT INTO ehh_pr (concept_code,
                    concept_name,
                    field_type,
                    flag)
SELECT DISTINCT answer_code,
                answer_name,
                NULL as field_type,
                'a' as flag
FROM ehh_answers;

SELECT * FROM ehh_pr; --185

SELECT DISTINCT concept_code, concept_name FROM dev_ppi.ehh_pr where length (concept_name) > 255;

--q-a pairs
DROP TABLE ehh_qa;
CREATE TABLE ehh_qa as (
WITH a
AS
(SELECT *,
  TRIM(REGEXP_SPLIT_TO_TABLE(choices_calculations_or_slider_labels, '\|')) AS answer
 FROM ehh)
     SELECT
     variable_field_name as question_code,
     field_label as question_name,
     SPLIT_PART(answer, ',', 1) AS answer_code,
     trim(SPLIT_PART(answer, ',', 2)) AS answer_name
     FROM a) ;
SELECT * FROM ehh_qa;

UPDATE ehh_qa SET answer_code = 'PMI_DontKnow' WHERE answer_code = 'pmi_dontknow';
UPDATE ehh_qa SET answer_code = 'PMI_PreferNotToAnswer' WHERE answer_code = 'pmi_prefernottoanswer';
UPDATE ehh_qa SET answer_code = 'PMI_None' WHERE answer_code = 'pmi_none';



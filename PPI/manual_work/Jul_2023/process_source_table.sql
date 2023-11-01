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
TRUNCATE TABLE ABLE bhp_pr;
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
                field_label,
                field_type,
                'q' as flag
FROM bhp;

-- Cut concept names longer than 255
UPDATE bhp_pr SET concept_name = 'Some people have a lot of fear about things like going out of the house alone, being in a crowd, going over bridges, or traveling by bus. Were you ever in your life frightened by any of these situations?'
WHERE concept_code = 'cidi5_30';
UPDATE bhp_pr SET concept_name = 'Have you ever been bothered with thoughts, images, or urges that kept coming back over and over, like concerns with germs, order, or experiencing horrific images or intrusive sexual thoughts, or urges to knock objects, or harming a loved one?'
WHERE concept_code = 'pmi_1';
UPDATE bhp_pr SET concept_name = 'Did you ever talk to a health professional about any of these experiences (such as seeing a vision, hearing a voice, believing that something strange was trying to communicate with you)?'
WHERE concept_code = 'mhqukb_55';
UPDATE bhp_pr SET concept_name = 'Attention and Focus Everyone has different abilities to pay attention and get things done. Answering these next questions may help researchers learn more about the brain and attention. During the past 6 months,'
WHERE concept_code = 'attention_focus';
UPDATE bhp_pr SET concept_name = 'Experiences of Panic and Anxiety The next section asks about panic attacks. Your answers to these next questions may help researchers understand how to better prevent and treat these attacks.'
WHERE concept_code = 'panic_anxiety';
UPDATE bhp_pr SET concept_name = 'Shifts in Mood, Energy, and Activity People often experience changes in their mood or energy levels. The next questions ask about unusual moods you may have had. '
WHERE concept_code = 'mood_energy';
UPDATE bhp_pr SET concept_name = 'Feelings of Fear in Certain Situations For some people, being in social settings can make them feel a lot of fear and anxiety. Your answers may help researchers better identify and help people with social anxiety disorder or agoraphobia. '
WHERE concept_code = 'social_anxiety';
UPDATE bhp_pr SET concept_name = 'Unusual Experiences and Perceptions. Your answers could help researchers better understand why these experiences happen and how to help people who have them. With that in mind, did you ever in your life have any of the following experiences?'
WHERE concept_code = 'unusual_experiences';
UPDATE bhp_pr SET concept_name = 'Recurring Thoughts and Behaviors Everyone double-checks things. In the next section, we ask about thoughts and behaviors that may be hard to control and can cause anxiety.'
WHERE concept_code = 'recurring_thoughts';
UPDATE bhp_pr SET concept_name = 'The following questions ask about your behavioral health and personality. Some of the questions may be sensitive. You can choose not to answer any question.'
WHERE concept_code = 'bhp_intro';

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

SELECT * FROM bhp_pr; --110
DELETE FROM bhp_pr WHERE concept_code = 'bhp_44' and concept_name = 'Enter number'; -- to preserve only one variant for bhp_44

-- table with q-a pairs
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


SELECT DISTINCT concept_code, concept_name FROM dev_ppi.bhp_pr where length (concept_name) > 255;

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
                field_label,
                field_type,
                'q' as flag
FROM ehh;

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

SELECT * FROM ehh_pr; --206

SELECT DISTINCT concept_code, concept_name FROM dev_ppi.ehh_pr where length (concept_name) > 255;
SELECT * FROM dev_ppi.ehh where length (field_label) > 255;

UPDATE ehh_pr SET concept_name = 'Self-Harm Suicide is often preventable. Your answers may help researchers find better ways to help those with thoughts of harming themselves. '
WHERE concept_code = 'self_harm';
UPDATE ehh_pr SET concept_name = 'The following questions ask about your emotional health and well-being. If you aren''t sure how to answer a question, choose the best answer from the options given. '
WHERE concept_code = 'ehhwb_intro';
UPDATE ehh_pr SET concept_name = 'Feelings of General Anxiety and Worry Everyone worries from time to time. Over the last 2 weeks, how often have you been bothered by the following problems?'
WHERE concept_code = 'anxiety_worry';
UPDATE ehh_pr SET concept_name = 'Mood and Sadness Everyone experiences sadness every now and then. Over the last 2 weeks, how often have you been bothered by any of the following problems?'
WHERE concept_code = 'mood_sadness';
UPDATE ehh_pr SET concept_name = 'Experiences with Trauma Some people go through stressful and upsetting events during their life. In this section we will be asking you about your experiences with trauma in childhood (before you were 18 years old).'
WHERE concept_code = 'trauma';

--table with q-a pairs
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



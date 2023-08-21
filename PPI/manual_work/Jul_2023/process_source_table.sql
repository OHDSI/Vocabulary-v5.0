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

--Process BHP source table
DROP TABLE bhp_pr;
CREATE TABLE bhp_pr as (
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
     FROM a) ;

--Precoordinated answer concepts
--SELECT DISTINCT concat (question_code, '-', answer_code), concat (question_name, '-', answer_name) FROM bhp_pr;
UPDATE bhp_pr SET answer_name = concat (question_name, '-', answer_name);
UPDATE bhp_pr SET answer_code = concat (question_code, '-', answer_code);

UPDATE bhp_pr SET answer_code = trim(answer_code) ;
UPDATE bhp_pr SET question_code = trim(question_code) ;
UPDATE bhp_pr SET answer_name = trim(answer_name) ;
UPDATE bhp_pr SET question_name = trim(question_name) ;

SELECT * FROM bhp_pr; --209

SELECT DISTINCT question_code, question_name FROM dev_ppi.bhp_pr where length (question_name) > 255;

UPDATE bhp_pr SET question_name = 'Some people have a lot of fear about things like going out of the house alone, being in a crowd, going over bridges, or traveling by bus. Were you ever in your life frightened by any of these situations?'
WHERE question_code = 'cidi5_30';
UPDATE bhp_pr SET question_name = 'Have you ever been bothered with thoughts, images, or urges that kept coming back over and over, like concerns with germs, order, or experiencing horrific images or intrusive sexual thoughts, or urges to knock objects, or harming a loved one?'
WHERE question_code = 'pmi_1';
UPDATE bhp_pr SET question_name = 'Did you ever talk to a health professional about any of these experiences (such as seeing a vision, hearing a voice, believing that something strange was trying to communicate with you)?'
WHERE question_code = 'mhqukb_55';

SELECT DISTINCT answer_code, answer_name FROM bhp_pr where length (answer_name) > 255;

UPDATE bhp_pr SET answer_name = 'Some people have a lot of fear about things like going out of the house alone, being in a crowd, going over bridges, or traveling by bus. Were you ever in your life frightened by any of these situations?-Yes'
WHERE answer_code = 'cidi5_30-bhp_6';
UPDATE bhp_pr SET answer_name = 'Some people have a lot of fear about things like going out of the house alone, being in a crowd, going over bridges, or traveling by bus. Were you ever in your life frightened by any of these situations?-No'
WHERE answer_code = 'cidi5_30-bhp_7';
UPDATE bhp_pr SET answer_name = 'How distressing did you find having any of these experiences (such as seeing a vision, hearing a voice)?-Not distressing at all. It was a positive experience'
WHERE answer_code = 'mhqukb_54-bhp_96';
UPDATE bhp_pr SET answer_name = 'Did you ever talk to a health professional about any of these experiences (such as seeing a vision, hearing a voice, believing that something strange was trying to communicate with you)?-Yes'
WHERE answer_code = 'mhqukb_55-bhp_6';
UPDATE bhp_pr SET answer_name = 'Did you ever talk to a health professional about any of these experiences (such as seeing a vision, hearing a voice, believing that something strange was trying to communicate with you)?-No'
WHERE answer_code = 'mhqukb_55-bhp_7';
UPDATE bhp_pr SET answer_name = 'Did you ever talk to a health professional about any of these experiences (such as seeing a vision, hearing a voice, believing that something strange was trying to communicate with you)?-Don''t know'
WHERE answer_code = 'mhqukb_55-pmi_dontknow';
UPDATE bhp_pr SET answer_name = 'Did you ever talk to a health professional about any of these experiences (such as seeing a vision, hearing a voice, believing that something strange was trying to communicate with you)?-Prefer not to answer'
WHERE answer_code = 'mhqukb_55-pmi_prefernottoanswer';
UPDATE bhp_pr SET answer_name = 'Were you ever prescribed a medication by a health professional for any of these experiences (such as seeing a vision, hearing a voice)? -Prefer not to answer'
WHERE answer_code = 'mhqukb_56-pmi_prefernottoanswer';
UPDATE bhp_pr SET answer_name = 'Have you ever been bothered with thoughts, images, or urges that kept coming back over and over, like concerns with germs, order, or experiencing horrific images or intrusive sexual thoughts, or urges to knock objects, or harming a loved one?-Yes'
WHERE answer_code = 'pmi_1-bhp_6';
UPDATE bhp_pr SET answer_name = 'Have you ever been bothered with thoughts, images, or urges that kept coming back over and over, like concerns with germs, order, or experiencing horrific images or intrusive sexual thoughts, or urges to knock objects, or harming a loved one?-No'
WHERE answer_code = 'pmi_1-bhp_7';


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

--Process EHH source table
DROP TABLE ehh_pr;
CREATE TABLE ehh_pr as (
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

--Precoordinated answer concepts
--SELECT DISTINCT answer_code, answer_name FROM ehh_pr;
UPDATE ehh_pr SET answer_name = concat (question_name, '-', answer_name);
UPDATE ehh_pr SET answer_code = concat (question_code, '-', answer_code);

update ehh_pr set answer_code = trim(answer_code) ;
update ehh_pr set question_code = trim(question_code) ;
update ehh_pr set answer_name = trim(answer_name) ;
update ehh_pr set question_name = trim(question_name) ;

SELECT * FROM ehh_pr; --408

SELECT DISTINCT question_code, question_name FROM ehh_pr where length (question_name) > 255;
SELECT DISTINCT answer_code, answer_name FROM ehh_pr where length (answer_name) > 255;

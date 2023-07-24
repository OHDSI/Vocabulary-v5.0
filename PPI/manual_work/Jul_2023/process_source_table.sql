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
Field_Annotation	varchar) ;

SELECT * FROM bhp;

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

SELECT * FROM ehh;


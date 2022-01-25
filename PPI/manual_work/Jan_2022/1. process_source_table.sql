--WMS source table
CREATE TABLE ppi_wms_1121
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

WbImport -file="F:/Downloads/ppi - wms.tsv"
         -type=text
         -table=ppi_wms_1121
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=variable_field_name,form_name,section_header,field_type,field_label,choices_calculations_or_slider_labels,field_note,text_validation_type_or_show_slider_number,text_validation_min,text_validation_max,identifier,branching_logic,required_field,custom_alignment,question_number,matrix_group_name,matrix_ranking,field_annotation
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100;
         
--Process WMS source table
CREATE TABLE wms as (
WITH a
AS
(SELECT *,
  TRIM(REGEXP_SPLIT_TO_TABLE(choices_calculations_or_slider_labels, '\|')) AS answer_reg
 FROM ppi_wms_1121) 
     SELECT 
     variable_field_name as question_code, 
     field_label as question_name, 
     SPLIT_PART(answer_reg, ',', 1) AS answer_code,
     trim(SPLIT_PART(answer_reg, ',', 2)) AS answer_name 
     FROM a) ;
     
--routine update
UPDATE wms 
SET answer_code = NULL, 
    answer_name = NULL
WHERE concept_id = '' ;
         
--PFH source table
CREATE TABLE ppi_pfh_1121
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

WbImport -file="F:/Downloads/ppi - pfh.tsv"
         -type=text
         -table=ppi_pfh_1121
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=variable_field_name,form_name,section_header,field_type,field_label,choices_calculations_or_slider_labels,field_note,text_validation_type_or_show_slider_number,text_validation_min,text_validation_max,identifier,branching_logic,required_field,custom_alignment,question_number,matrix_group_name,matrix_ranking,field_annotation
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100;
         
--Process PFH source table
CREATE TABLE ppi_pfh_c as (
WITH a
AS
(SELECT *,
  TRIM(REGEXP_SPLIT_TO_TABLE(choices_calculations_or_slider_labels, '\|')) AS answer_reg
 FROM ppi_pfh_1121) 
     SELECT 
     variable_field_name as question_code, 
     field_label as question_name, 
     SPLIT_PART(answer_reg, ',', 1) AS answer_code,
     trim(SPLIT_PART(answer_reg, ',', 2)) AS answer_name 
     FROM a) ;

--routine updates
UPDATE ppi_pfh_c 
SET answer_code = NULL, 
    answer_name = NULL
WHERE concept_id = '' ;

update ppi_pfh_c a set answer_code = (select short_code from ppi_long_short_code b
where lower(a.answer_code) = lower(b.source_code))
where lower(a.answer_code) in (select lower(source_code) from ppi_long_short_code) ;

update ppi_pfh_c set answer_name = 'Adolescent (12-17)' where answer_name = 'Adolescent(12-17)'  ;
update ppi_pfh_c set answer_name = 'Older adult (65-74)' where answer_name ~* '(65-64)'  ;
update ppi_pfh_c set answer_name = 'Head and neck (This includes cancers of the mouth, sinuses, nose, or throat.)' where answer_code = 'CancerCondition_HeadNeckCancer' ;
update ppi_pfh_c set answer_name = 'Dementia (includes Alzheimer'||''''||'s, vascular, etc.)' where answer_code = 'NervousCondition_Dementia' ;
update ppi_pfh_c set answer_name = 'Skin condition (e.g., eczema, psoriasis)' where answer_code = 'DiagnosedHealthCondition_SkinCondition' ;
update ppi_pfh_c set answer_name = 'Liver condition (e.g., cirrhosis)' where answer_code = 'DigestiveCondition_LiverCondition' ;
update ppi_pfh_c set answer_name = 'Chronic lung disease (COPD, emphysema or bronchitis)' where answer_code = 'RespiratoryCondition_ChronicLungDisease' ; 
update ppi_pfh_c set answer_name = 'Sexually transmitted infections (Gonorrhea, Syphilis, Chlamydia)' where answer_name ~* 'Sexually' ;

update ppi_pfh_c set question_name = trim(question_name)
where question_name ~* ' $'; 

update ppi_pfh_c set answer_code = trim(answer_code)
where answer_code ~* 'CancerConditions_ProstateCancer' ;

update ppi_pfh_c set answer_code = trim(answer_code) ;
update ppi_pfh_c set question_code = trim(question_code) ;
update ppi_pfh_c set answer_code = null where answer_code = '' ;
update ppi_pfh_c set answer_name = null where answer_name = '' ;

--manual tables
create table ppi_pfh_all_answ (
source_code varchar,
source_name varchar,
relationship_id varchar,
concept_code varchar,
concept_name varchar ) ;

WbImport -file="F:/Downloads/ppi - ppi_pfh_all_answ.tsv"
         -type=text
         -table=ppi_pfh_all_answ
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=source_code,source_name,relationship_id,concept_code,concept_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100;
         
update ppi_pfh_all_answ set source_code = trim(source_code) ;
update ppi_pfh_all_answ set concept_code = trim(concept_code) ;

update ppi_pfh_all_answ a set source_code = (select concept_code from concept c where vocabulary_id = 'PPI'
and lower(a.source_code) = lower(c.concept_code))
where lower(a.source_code) in (select lower(concept_code) from concept c where vocabulary_id = 'PPI') ;

update ppi_pfh_all_answ a set concept_code = (select concept_code from concept c where vocabulary_id = 'PPI'
and lower(a.concept_code) = lower(c.concept_code))
where lower(a.concept_code) in (select lower(concept_code) from concept c where vocabulary_id = 'PPI') ;

update ppi_pfh_all_answ a set source_code = (select short_code from ppi_long_short_code b
where lower(a.source_code) = lower(b.source_code))
where lower(a.source_code) in (select lower(source_code) from ppi_long_short_code) ;

update ppi_pfh_all_answ a set concept_code = (select short_code from ppi_long_short_code b
where lower(a.concept_code) = lower(b.source_code))
where lower(a.concept_code) in (select lower(source_code) from ppi_long_short_code) ;

update ppi_pfh_all_answ set source_name = 'Have you ever been diagnosed with the following conditions? - Sexually transmitted infections (gonorrhea, syphilis, chlamydia)' 
where source_code = 'InfectiousDiseaseConditions_SexuallyTransmitted' ;

update ppi_pfh_all_answ set source_code = 'SkeletalMuscularConditions_Rheumatoidarthritis'
where source_code = 'SkeletalMuscularConditions_RheumatoidArthritis' ;

create table ppi_wms_1121_mapped (
source_code varchar,
source_name varchar,
concept_id int,
concept_code varchar,
concept_name varchar,
domain_id varchar,
concept_class_id varchar,
vocabulary_id varchar,
standard_concept varchar,
mark varchar,
valid_start_date varchar,
valid_end_date varchar,
invalid_reason varchar) ;

WbImport -file="F:/Downloads/ppi - wms_mapped.tsv"
         -type=text
         -table=ppi_wms_1121_mapped
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=source_code,source_name,concept_id,concept_code,concept_name,domain_id,concept_class_id,vocabulary_id,standard_concept,mark,valid_start_date,valid_end_date,invalid_reason
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100;
         
create table ppi_long_short_code
(concept_class_id varchar,
source_code varchar,
concept_name varchar,
short_code varchar ) ;

WbImport -file="F:/Downloads/ppi - long_short_code.tsv"
         -type=text
         -table=ppi_long_short_code
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=concept_class_id,source_code,concept_name,short_code
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=100;

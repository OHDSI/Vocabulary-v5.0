issues:
--1. still wrong domain_id definition, for example:
/*update concept_stage 
set domain_id ='Drug'
where concept_code  in (
'82867998',
'91097998',
'97563998',
'97482998',
'97482997',
'91389998',
'94472997'
)
;
*/

--2. Suppliers and Brand Names can be mapped better
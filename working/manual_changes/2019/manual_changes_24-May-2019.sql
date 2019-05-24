--Rename IMS to IQVIA
--AVOF-1704

update vocabulary set vocabulary_reference='IQVIA proprietary; http://sigtap.datasus.gov.br/' where vocabulary_id='SUS';
update vocabulary set vocabulary_name='Longitudinal Patient Data Belgium (IQVIA)', vocabulary_reference='IQVIA proprietary' where vocabulary_id='LPD_Belgium';
update vocabulary set vocabulary_name=replace(vocabulary_name,'IMS','IQVIA'), vocabulary_reference=replace(vocabulary_reference,'IMS','IQVIA') where vocabulary_id in ('GRR','DA_France','LPD_Australia');
update vocabulary_conversion set available='License required', url='mailto:contact@ohdsi.org?subject=License%20required%20for%20LPD_Belgium&body=Describe%20your%20situation%20and%20your%20need%20for%20this%20vocabulary.' where vocabulary_id_v5='LPD_Belgium';
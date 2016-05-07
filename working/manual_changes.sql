/*
-- start new sequence
drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id>=200 and concept_id<1000; -- Last valid value in the 500-1000 slot
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

-- Add EphMRA ATC
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Anatomical Classification of Pharmaceutical Products (EphMRA)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('EphMRA ATC', 'Anatomical Classification of Pharmaceutical Products (EphMRA)', 'http://www.ephmra.org/Anatomical-Classification', 'V2016', (select concept_id from concept where concept_name='Anatomical Classification of Pharmaceutical Products (EphMRA)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url) values (80, 'EphMRA ATC', null, null, null, null);

-- Add Concept Class Supplier
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Supplier', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Supplier', 'Supplier: Manufacturer, Wholesaler', (select concept_id from concept where concept_name = 'Supplier'));

commit;

-- Add old NDC from GPI
select distinct n.gpi, n.gpi_desc, n.ndc, n.mkted_prod_formltn_nm as ndw_name, ndc.concept_name as ndc_name, rx.concept_id as rx_id, rx.concept_name as rx_name, rx.concept_class_id as rx_class, cd.concept_id as cd_id, cd.concept_name as cd_name, cd.concept_class_id as cd_class
from ndw_v_product n
join concept ndc on ndc.concept_code=n.ndc and ndc.vocabulary_id='NDC' 
join concept_relationship r on r.invalid_reason is null and r.concept_id_1=ndc.concept_id and r.relationship_id='Maps to'
join concept rx on rx.concept_id=r.concept_id_2
left join concept_relationship r2 on r2.concept_id_1=rx.concept_id and r2.invalid_reason is null and r2.relationship_id='Tradename of'
left join concept cd on cd.concept_id=r2.concept_id_2 
where n.gpi='83100020302005'
  ;

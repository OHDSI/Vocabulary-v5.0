--undeprecate concept_id=40798976 [AVOF-2710]
update concept set invalid_reason=null,valid_end_date=to_date('20991231','yyyymmdd'),standard_concept='S' where concept_id=40798976;
update concept_relationship set invalid_reason=null,valid_end_date=to_date('20991231','yyyymmdd') where concept_id_1=40798976 and concept_id_2=40798976;
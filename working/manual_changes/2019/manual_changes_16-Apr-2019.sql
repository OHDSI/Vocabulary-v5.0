--AVOF-1610

--UB04 Point of Origin
--set non-standard for some UB04 Point of Origin codes
update concept set standard_concept=null where concept_id between 32193 and 32202;
--deprecate self 'Maps to'
update concept_relationship set invalid_reason='D', valid_end_date=current_date where concept_id_1 between 32193 and 32202 and concept_id_1=concept_id_2;

--add new 'Maps to' for some existing UB04
insert into concept_relationship values 
(32193,581476, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(581476,32193, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32194,38004207, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004207,32194, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32195,8717, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8717,32195, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32196,8863, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8863,32196, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32198,38003619, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38003619,32198, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32200,8717, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8717,32200, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32201,38004207, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004207,32201, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32202,8546, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8546,32202, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null);

--add new UB04 Point of Origin codes
insert into concept values 
(32582,'HMO Referral','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'3',current_date,to_date('20991231', 'yyyymmdd'),null),
(32583,'Emergency Room','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'7',current_date,to_date('20991231', 'yyyymmdd'),null),
(32584,'Transfer from critial access hospital','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'A',current_date,to_date('20991231', 'yyyymmdd'),null),
(32585,'Transfer From Another Home Health Agency','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'B',current_date,to_date('20991231', 'yyyymmdd'),null),
(32586,'Readmission to Same Home Health Agency','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'C',current_date,to_date('20991231', 'yyyymmdd'),null),
(32587,'Normal Delivery','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'N',current_date,to_date('20991231', 'yyyymmdd'),null),
(32588,'Premature Delivery','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'O',current_date,to_date('20991231', 'yyyymmdd'),null),
(32589,'Sick Baby','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'P',current_date,to_date('20991231', 'yyyymmdd'),null),
(32590,'Extramural Birth','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'Q',current_date,to_date('20991231', 'yyyymmdd'),null),
(32591,'Not Available','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'R',current_date,to_date('20991231', 'yyyymmdd'),null),
(32592,'Born inside this hospital','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'S',current_date,to_date('20991231', 'yyyymmdd'),null),
(32593,'Born outside this hospital','Visit','UB04 Point of Origin','UB04 Point of Origin',null,'T',current_date,to_date('20991231', 'yyyymmdd'),null);

--add new relationships for new codes
insert into concept_relationship values 
(32583,9203, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(9203,32583, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32584,32276, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(32276,32584, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32585,38004519, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004519,32585, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32586,38004519, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004519,32586, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null);

--UB04 Pt dis status
update concept set standard_concept=null where concept_id between 32209 and 32249;
--deprecate self 'Maps to'
update concept_relationship set invalid_reason='D', valid_end_date=current_date where concept_id_1 between 32209 and 32249 and concept_id_1=concept_id_2;

--add new 'Maps to' for some existing UB04
insert into concept_relationship values 
(32210,581476, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(581476,32210, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32211,8717, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8717,32211, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32212,8863, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8863,32212, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32213,8951, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8951,32213, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32214,8717, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8717,32214, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32215,38004519, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004519,32215, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32219,38003619, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38003619,32219, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32224,8717, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8717,32224, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32225,8546, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8546,32225, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32226,8546, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8546,32226, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32227,32254, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(32254,32227, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32228,38004285, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004285,32228, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32229,38004277, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004277,32229, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32230,8676, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8676,32230, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32231,38004284, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004284,32231, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32232,32276, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(32276,32232, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32235,581476, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(581476,32235, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32236,8717, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8717,32236, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32237,8863, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8863,32237, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32238,42898160, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(42898160,32238, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32239,8717, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8717,32239, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32240,38004519, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004519,32240, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32241,38003619, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38003619,32241, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32242,8966, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8966,32242, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32243,32254, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(32254,32243, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32244,8920, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8920,32244, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32245,38004277, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004277,32245, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32246,8676, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8676,32246, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32247,38004284, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38004284,32247, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32248,32276, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(32276,32248, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null);

--add new UB04 Pt dis status codes
insert into concept values 
(32594,'Discharged/transferred to home under care of Home IV provider','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'8',current_date,to_date('20991231', 'yyyymmdd'),null),
(32595,'Neonate discharged to another hospital for neonatal aftercare','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'10',current_date,to_date('20991231', 'yyyymmdd'),null),
(32596,'Discharged/transferred/referred another institution for outpatient services','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'71',current_date,to_date('20991231', 'yyyymmdd'),null),
(32597,'Discharged/transferred/referred to this institution for outpatient services','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'72',current_date,to_date('20991231', 'yyyymmdd'),null),
(32598,'Discharged for Other Reasons','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'100',current_date,to_date('20991231', 'yyyymmdd'),null),
(32599,'Discharged to Care of Family/Friend(s)','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'101',current_date,to_date('20991231', 'yyyymmdd'),null),
(32600,'Discharged to Care of Paid Caregiver','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'102',current_date,to_date('20991231', 'yyyymmdd'),null),
(32601,'Discharged to Court/ Law Enforcement/Jail','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'103',current_date,to_date('20991231', 'yyyymmdd'),null),
(32602,'Discharged to Other Facility per Legal Guidelines','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'104',current_date,to_date('20991231', 'yyyymmdd'),null),
(32603,'Disharge required by Carrier Change','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'105',current_date,to_date('20991231', 'yyyymmdd'),null),
(32604,'Internal Transfer per Legal Guidelines','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'106',current_date,to_date('20991231', 'yyyymmdd'),null),
(32605,'Other Home Care','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'107',current_date,to_date('20991231', 'yyyymmdd'),null),
(32606,'Regular Discharge with Follow-up','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'108',current_date,to_date('20991231', 'yyyymmdd'),null),
(32607,'Return Transfer','Visit','UB04 Pt dis status','UB04 Pt dis status',null,'109',current_date,to_date('20991231', 'yyyymmdd'),null);

--add new relationships for new codes
insert into concept_relationship values 
(32594,581476, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(581476,32594, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32595,8717, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(8717,32595, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32596,9202, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(9202,32596, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32597,9202, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(9202,32597, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32599,581476, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(581476,32599, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32600,581476, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(581476,32600, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32601,38003619, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(38003619,32601, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32602,42898160, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(42898160,32602, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32605,581476, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(581476,32605, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null),
(32606,581476, 'Maps to', current_date, to_date('20991231','yyyymmdd'),null),
(581476,32606, 'Mapped from', current_date, to_date('20991231','yyyymmdd'),null);

--add all missing synonyms for new concepts
insert into concept_synonym
select concept_id, concept_name, 4180186 from concept where concept_id between 32582 and 32607;
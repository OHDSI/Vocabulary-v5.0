--bugfix with valid_start_date (PPI)
update concept set valid_start_date=valid_start_date+interval '2000 year' where extract (year from valid_start_date)=17;
update concept set valid_start_date=to_date ('20170424', 'yyyymmdd') where concept_id in (1585865,1585866);
update concept set valid_start_date=to_date ('20180925', 'yyyymmdd') where concept_id in (43529091,43529094);
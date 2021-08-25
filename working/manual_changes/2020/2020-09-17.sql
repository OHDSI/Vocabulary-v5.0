--bugfix with U concepts without active replacement [AVOF-2811]
update concept set invalid_reason='D' where concept_id in (9439,38003632,38003811,38004031,38004292,38004313) and invalid_reason='U';
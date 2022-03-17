--PPI new concept

-- 'aian_tribe' concept insert into cm
INSERT INTO concept_manual
VALUES ('AIAN: tribe', 'Observation', 'PPI', 'Answer', null, 'aian_tribe', '2022-03-17', '2099-12-31');

-- 'aian_tribe' relationships insert into crm
INSERT INTO concept_relationship_manual
VALUES ('aian_tribe', 'AIAN_AIANSpecific', 'PPI', 'PPI', 'Answer of (PPI)', '2022-03-17', '2099-12-31', NULL),
       ('aian_tribe', 'AIAN_AIANSpecific', 'PPI', 'PPI', 'Has PPI parent code', '2022-03-17', '2099-12-31', NULL),
       ('aian_tribe', 'AIAN_AIANSpecific', 'PPI', 'PPI', 'Maps to', '2022-03-17', '2099-12-31', NULL);
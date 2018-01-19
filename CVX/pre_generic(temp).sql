insert into concept (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE)
values (1000000000,'CVX','Metadata','Vocabulary','Vocabulary','OMOP generated',TO_DATE ('20170728', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd') );

INSERT INTO VOCABULARY (  VOCABULARY_ID, VOCABULARY_NAME,  VOCABULARY_REFERENCE,  VOCABULARY_VERSION,  VOCABULARY_CONCEPT_ID)
VALUES ( 'CVX',  'CVX',  'CVX',  NULL,  1000000000);

insert into concept (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE)
values (6000000120,'CVX to RxNorm','Metadata','Relationship','Relationship','OMOP generated',TO_DATE ('20170728', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd') );

insert into concept (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE)
values (6000000121,'RxNorm to CVX','Metadata','Relationship','Relationship','OMOP generated',TO_DATE ('20170728', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd') );



alter table relationship drop CONSTRAINT FPK_RELATIONSHIP_REVERSE;
insert into relationship values ('CVX to RxNorm','CVX to Rx',0,1,'RxNorm to CVX', 6000000120) ;
insert into relationship values ('RxNorm to CVX','CVX to Rx',0,0,'CVX to RxNorm', 6000000121);



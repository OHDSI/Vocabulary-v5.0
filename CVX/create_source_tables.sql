CREATE TABLE CVX
(
   cvx_code            VARCHAR2 (100),
   short_description   VARCHAR2 (4000),
   full_vaccine_name   VARCHAR2 (4000),
   vaccine_status      VARCHAR2 (100),
   nonvaccine          VARCHAR2 (100),
   last_updated_date   DATE
);

CREATE TABLE CVX_DATES
(
   cvx_code                 VARCHAR2 (100),
   concept_date             DATE
);
--READ DRUG AND APPLIANCE DICTIONARY

--PROCESSING OF SOURCES

--UKB 2020

--Combination of read_drug code + atc_code is unique
--DROP TABLE sources_ukb_readdrug_atc;
CREATE TABLE sources_ukb_readdrug_atc
(
    read_code_drug varchar(5),
    atc_code varchar(20)
);

UPDATE sources_ukb_readdrug_atc
SET atc_code = regexp_replace(atc_code, ' ', '', 'g');

--Combination of read_drug code + bnf_code is unique
--DROP TABLE sources_ukb_readdrug_bnf;
CREATE TABLE sources_ukb_readdrug_bnf
(
    read_code_drug varchar(5),
    bnf_code varchar(20)
);

UPDATE sources_ukb_readdrug_bnf
SET bnf_code = regexp_replace(bnf_code, ' ', '', 'g');


--Drug strength for Read Drug
--DROP TABLE sources_ukb_readdrug_nsf;
CREATE TABLE sources_ukb_readdrug_nsf
(
    read_code_drug varchar(5),
    name_drug varchar(50),
    strength_drug varchar(30),
    form_drug varchar(20)
);

UPDATE sources_ukb_readdrug_nsf
SET name_drug = trim(name_drug),
    strength_drug = trim(strength_drug),
    form_drug = trim(form_drug);

SELECT * FROM sources_ukb_readdrug_nsf;


--Unidrug.key - the main file
--DROP TABLE sources_ukb_readdrug_unidrug;
CREATE TABLE sources_ukb_readdrug_unidrug
(
    termkey varchar(15),
    uniquifier varchar(10),
    term_30 varchar(40),
    term_60 varchar(70),
    term_198 varchar(255),
    term_code varchar(10),
    language_code varchar(10),
    read_code_drug varchar(10),
    status_flag varchar(10)
);

UPDATE sources_ukb_readdrug_unidrug
SET uniquifier = trim(uniquifier),
    term_30 = trim(term_30),
    term_60 = trim(term_60),
    term_198 = trim(term_198),
    term_code = trim(term_code),
    language_code = trim(language_code),
    read_code_drug = trim(read_code_drug),
    status_flag = trim(status_flag)
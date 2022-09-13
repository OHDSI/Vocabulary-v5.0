--DDL (predicted data type)
CREATE TABLE genomic_cgi
(
    alteration varchar(255),
    alteration_type varchar(255),
    assay_type varchar(255),
    association varchar(255),
    biomarker varchar(255),
    comments TEXT,
    curation_date varchar(255),
    curator varchar(255),
    drug TEXT,
    drug_family varchar(255),
    drug_full_name TEXT,
    drug_status varchar(255),
    evidence_level varchar(255),
    gene varchar(255),
    metastatic_tumor_type varchar(255),
    primary_tumor_acronym varchar(255),
    primary_tumor_type_full_name varchar(255),
    source varchar(255),
    tcgi_included varchar(255),
    targeting varchar(255),
    cdna varchar(255),
    gdna varchar(255),
    individual_mutation varchar(255),
    info TEXT,
    region varchar(255),
    strand varchar(255),
    transcript varchar(255),
    primary_tumor_type varchar(255)
    )
;

--Table is created
DROP TABLE IF EXISTS dev_cgi.genomic_cgi;
CREATE TABLE dev_cgi.genomic_cgi
as (select * from sources.genomic_cgi);


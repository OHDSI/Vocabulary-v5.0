--source upload based on 2022 files structure
drop table dev_cgi.genomic_cgi_source;
create table dev_cgi.genomic_cgi_source (
    gene varchar(255),
    gdna varchar(255),
    protein varchar(255),
    transcript varchar(255),
    info text,
    context varchar(255),
    cancer_acronym varchar(255),
    source varchar(255),
    reference text
);


-- with existing sources
DROP TABLE IF EXISTS dev_cgi.genomic_cgi_backup210727;
CREATE TABLE dev_cgi.genomic_cgi_backup210727
as (select * from sources.genomic_cgi);

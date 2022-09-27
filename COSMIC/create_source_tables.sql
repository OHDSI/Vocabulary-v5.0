drop table dev_genomic.cosmicmutantexportcensus;
create table dev_genomic.cosmicmutantexportcensus (
    gene_name varchar(100),
    accession_number varchar(200),
    gene_cds_length int,
    hgnc_id int,
    sample_name varchar(200),
    id_sample int,
    id_tumour int,
    primary_site varchar(200),
    site_subtype_1 varchar(100),
    site_subtype_2 varchar(100),
    site_subtype_3 varchar(100),
    primary_histology varchar(200),
    histology_subtype_1 varchar(100),
    histology_subtype_2 varchar(100),
    histology_subtype_3 varchar(100),
    genome_wide_screen varchar(50),
    genomic_mutation_id varchar(100),
    legacy_mutation_id varchar(100),
    mutation_id int,
    mutation_cds text,
    mutation_aa text,
    mutation_description text,
    mutation_zygosity varchar(50),
    loh varchar(20),
    grch varchar(20),
    mutation_genome_position varchar(200),
    mutation_strand varchar(5),
    resistance_mutation varchar(5),
    mutation_somatic_status text,
    pubmed_pmid varchar(100),
    id_study varchar(100),
    sample_type varchar(200),
    tumour_origin varchar(100),
    age varchar(100),
    tier int,
    hgvsp text,
    hgvsc text,
    hgvsg text
);

select *
from cosmicmutantexportcensus;


select *
from cosmicmutantexportcensus
where length(genomic_mutation_id) = 0;

select count(distinct genomic_mutation_id)
from cosmicmutantexportcensus;

select count(distinct legacy_mutation_id)
from cosmicmutantexportcensus;



select *
from cosmicmutantexportcensus
where length(genomic_mutation_id) = 0
and mutation_cds != 'c.?';


select gene_name, mutation_cds, mutation_aa, genomic_mutation_id, legacy_mutation_id
from cosmicmutantexportcensus
where mutation_aa in (
    select mutation_aa
from cosmicmutantexportcensus
where length(genomic_mutation_id) = 0
    )
and mutation_aa != 'p.?'
group by gene_name, mutation_cds, mutation_aa, genomic_mutation_id, legacy_mutation_id
having count(mutation_aa) > 1;


select distinct mutation_aa
from cosmicmutantexportcensus
where mutation_aa in (
    select mutation_aa
from cosmicmutantexportcensus
where length(genomic_mutation_id) = 0
    )
and mutation_aa != 'p.?'
group by mutation_aa
having count(mutation_aa) > 1;
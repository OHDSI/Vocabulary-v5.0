drop table cosmicmutantexportcensus;
create table cosmicmutantexportcensus (
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
from cosmicmutantexportcensus
where legacy_mutation_id = 'COSM7170946';


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



select distinct gene_name, accession_number, gene_cds_length, hgnc_id, sample_name, id_sample, id_tumour, primary_site, site_subtype_1, site_subtype_2, site_subtype_3, primary_histology, histology_subtype_1, histology_subtype_2, histology_subtype_3, genome_wide_screen, legacy_mutation_id, mutation_id, mutation_cds, mutation_aa, mutation_description, mutation_zygosity, loh, grch, mutation_genome_position, mutation_strand, resistance_mutation, mutation_somatic_status, pubmed_pmid, id_study, sample_type, tumour_origin, age, tier, hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus;

select distinct * from cosmicmutantexportcensus
where legacy_mutation_id in (
    select legacy_mutation_id from (
    select distinct gene_name, accession_number, gene_cds_length, hgnc_id, sample_name, id_sample, id_tumour, primary_site, site_subtype_1, site_subtype_2, site_subtype_3, primary_histology, histology_subtype_1, histology_subtype_2, histology_subtype_3, genome_wide_screen, legacy_mutation_id, mutation_id, mutation_cds, mutation_aa, mutation_description, mutation_zygosity, loh, grch, mutation_genome_position, mutation_strand, resistance_mutation, mutation_somatic_status, pubmed_pmid, id_study, sample_type, tumour_origin, age, tier, hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
    )a);


select distinct legacy_mutation_id, resistance_mutation, tier, mutation_description from cosmicmutantexportcensus
where legacy_mutation_id in (
    select legacy_mutation_id from (
    select distinct gene_name, accession_number, gene_cds_length, hgnc_id, sample_name, id_sample, id_tumour, primary_site, site_subtype_1, site_subtype_2, site_subtype_3, primary_histology, histology_subtype_1, histology_subtype_2, histology_subtype_3, genome_wide_screen, legacy_mutation_id, mutation_id, mutation_cds, mutation_aa, mutation_description, mutation_zygosity, loh, grch, mutation_genome_position, mutation_strand, resistance_mutation, mutation_somatic_status, pubmed_pmid, id_study, sample_type, tumour_origin, age, tier, hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
    )a);

select distinct legacy_mutation_id, resistance_mutation, tier, mutation_description from cosmicmutantexportcensus
group by 1,2,3,4
having count(legacy_mutation_id)>1;


select distinct gene_name, legacy_mutation_id, resistance_mutation, tier, mutation_description, mutation_cds, mutation_aa,
                hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where length(genomic_mutation_id) != 0
                                                                                                                                                                                                                                                               group by 1,2,3,4,5,6,7,8,9,10
having count(genomic_mutation_id)>1;



select gene_name, accession_number, gene_cds_length, hgnc_id, legacy_mutation_id, mutation_id, mutation_cds, mutation_aa, mutation_description, loh, grch, mutation_genome_position, mutation_strand, resistance_mutation, tier, hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where legacy_mutation_id in (
    select legacy_mutation_id from (
    select distinct gene_name, accession_number, gene_cds_length, hgnc_id, legacy_mutation_id, mutation_id, mutation_cds, mutation_aa, mutation_description, loh, grch, mutation_genome_position, mutation_strand, resistance_mutation, tier, hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14, 15,16,17,18
having count(legacy_mutation_id)>1
    )a);


with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             legacy_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus)
select legacy_mutation_id from tab
group by 1
having count(legacy_mutation_id)>1;


select count(distinct sample_name) from cosmicmutantexportcensus;


with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus)
select genomic_mutation_id from tab
                           where length(genomic_mutation_id)!=0
group by 1
having count(genomic_mutation_id)>1
;


select gene_name, accession_number, gene_cds_length, hgnc_id, legacy_mutation_id, mutation_id, mutation_cds, mutation_aa, mutation_description, loh, grch, mutation_genome_position, mutation_strand, resistance_mutation, tier, hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where legacy_mutation_id in (
    select legacy_mutation_id from (
    select distinct gene_name, accession_number, gene_cds_length, hgnc_id, legacy_mutation_id, mutation_id, mutation_cds, mutation_aa, mutation_description, loh, grch, mutation_genome_position, mutation_strand, resistance_mutation, tier, hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14, 15,16,17,18
having count(legacy_mutation_id)>1
    )a)
and legacy_mutation_id in (select legacy_mutation_id from (
    with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             legacy_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus)
select tier from tab
group by 1
having count(legacy_mutation_id)>1
    )b);

with tab1 as
(with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0
             )
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1)
select gene_name, genomic_mutation_id from tab1

left join cosmicmutantexportcensus c
using (genomic_mutation_id)
where length(genomic_mutation_id)!=0;

--656564 + 148
select distinct gene_name, genomic_mutation_id, resistance_mutation, tier, mutation_description, mutation_cds, mutation_aa,
                hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0;

select distinct gene_name, genomic_mutation_id, resistance_mutation, tier, mutation_description, mutation_cds, mutation_aa,
                hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus;


--656860




select distinct mutation_description from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0
and mutation_aa = 'p.?';

select distinct mutation_description from cosmicmutantexportcensus;


select distinct gene_name, genomic_mutation_id, resistance_mutation, tier, mutation_description, mutation_cds, mutation_aa,
                hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0
and mutation_description != 'Unknown'
and mutation_aa != 'p.?'
and resistance_mutation = 'Yes';







select distinct gene_name, genomic_mutation_id, resistance_mutation, tier, mutation_description, mutation_cds, mutation_aa,
                hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0
and mutation_description != 'Unknown'

union

select distinct gene_name, genomic_mutation_id, resistance_mutation, tier, mutation_description, mutation_cds, mutation_aa,
                hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0

and mutation_aa != 'p.?'

union

select distinct gene_name, genomic_mutation_id, resistance_mutation, tier, mutation_description, mutation_cds, mutation_aa,
                hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0

and resistance_mutation = 'Yes';









select distinct genomic_mutation_id from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0
and mutation_description != 'Unknown'

union

select distinct genomic_mutation_id from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0

and mutation_aa != 'p.?'

union

select distinct genomic_mutation_id from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0

and resistance_mutation = 'Yes';





with tab as (
select genomic_mutation_id from cosmicmutantexportcensus where length(genomic_mutation_id)!=0
union
select genomic_mutation_id from cosmicmutantexportcensus where  mutation_aa != 'p.?'
union
select genomic_mutation_id from cosmicmutantexportcensus where mutation_description != 'Unknown')
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1;


select distinct gene_name from cosmicmutantexportcensus
where resistance_mutation = 'Yes';




select distinct gene_name, genomic_mutation_id, resistance_mutation, tier, mutation_description, mutation_cds, mutation_aa,
                hgvsp, hgvsc, hgvsg from cosmicmutantexportcensus
where genomic_mutation_id not in (
    select genomic_mutation_id from (
        with tab as (select distinct gene_name,
                             accession_number,
                             gene_cds_length,
                             hgnc_id,
                             genomic_mutation_id,
                             mutation_id,
                             mutation_cds,
                             mutation_aa,
                             mutation_description,
                             loh,
                             grch,
                             mutation_genome_position,
                             mutation_strand,
                             resistance_mutation,
                             tier,
                             hgvsp,
                             hgvsc,
                             hgvsg
             from cosmicmutantexportcensus
             where length(genomic_mutation_id)!=0)
select genomic_mutation_id from tab
group by 1
having count(genomic_mutation_id)>1
                                   )c
    )
and length(genomic_mutation_id)!=0
and (mutation_description != 'Unknown'
or resistance_mutation = 'Yes');



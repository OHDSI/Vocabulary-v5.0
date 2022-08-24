DROP TABLE IF EXISTS dev_oncokb.genomic_oncokb;
CREATE TABLE dev_oncokb.genomic_oncokb
as (select * from sources.genomic_oncokb);
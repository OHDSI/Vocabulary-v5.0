DROP TABLE IF EXISTS dev_civic.genomic_civic_variantsummaries;
CREATE TABLE dev_civic.genomic_civic_variantsummaries
as (select * from sources.genomic_civic_variantsummaries);
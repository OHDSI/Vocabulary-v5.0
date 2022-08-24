DROP TABLE IF EXISTS dev_jax.genomic_jax_variant;
CREATE TABLE dev_jax.genomic_jax_variant
as (select * from sources.genomic_jax_variant);
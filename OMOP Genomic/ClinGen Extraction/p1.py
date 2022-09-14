import pandas as pd

concept = pd.read_csv(r'~\vocab\CONCEPT.csv', sep = '\t')
arg1 = concept["vocabulary_id"]=="OMOP Genomic"
arg2_1 = concept["concept_class_id"] == "DNA Variant"
arg2_2 = concept["concept_class_id"] == "RNA Variant"
arg2_3 = concept["concept_class_id"] == "Protein Variant"
concept_gen = concept.where(arg1&(arg2_1|arg2_2|arg2_3)).dropna(how = 'all')
concept_synonym = pd.read_csv(r'~\vocab\CONCEPT_SYNONYM.csv', sep = '\t')
syn_gen = concept_gen.merge(concept_synonym, on='concept_id')
syn_gen_f = syn_gen[["concept_id","concept_synonym_name"]].drop_duplicates()
syn_gen_f1 = syn_gen_f.where(syn_gen['concept_synonym_name'].str.startswith('NP', na=False)|
                             syn_gen['concept_synonym_name'].str.startswith('NG', na=False)|
                             syn_gen['concept_synonym_name'].str.startswith('NC', na=False)|
                             syn_gen['concept_synonym_name'].str.startswith('NM', na=False)).dropna(how = 'all').head(10000)


syn_gen_f1.to_csv("hgvs.csv")


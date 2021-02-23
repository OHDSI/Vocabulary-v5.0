select s.concept_code
from devv5.concept c
join concept_stage s  on
	s.concept_name ~ '(Administration|Introduction)' and
	c.concept_class_id = 'Ingredient' and
	c.vocabulary_id = 'RxNorm' and
	c.standard_concept = 'S' and
	s.concept_name ilike '%' || c.concept_name || '%' and
	length (s.concept_code) = 7 and
	c.concept_name not in ('tin','water','neral','RNA', 'bran','acetate')
	 and s.concept_name !~ '\d'
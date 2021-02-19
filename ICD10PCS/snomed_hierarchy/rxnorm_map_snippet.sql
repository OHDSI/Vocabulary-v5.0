{\rtf1\ansi\ansicpg1252\cocoartf2576
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx566\tx1133\tx1700\tx2267\tx2834\tx3401\tx3968\tx4535\tx5102\tx5669\tx6236\tx6803\pardirnatural\partightenfactor0

\f0\fs24 \cf0 select s.concept_code\
from devv5.concept c\
join concept_stage s  on\
	s.concept_name ~ '(Administration|Introduction)' and\
	c.concept_class_id = 'Ingredient' and\
	c.vocabulary_id = 'RxNorm' and\
	c.standard_concept = 'S' and\
	s.concept_name ilike '%' || c.concept_name || '%' and\
	length (s.concept_code) = 7 and\
	c.concept_name not in ('tin','water','neral','RNA', 'bran','acetate')\
	 and s.concept_name !~ '\\-\\d'}
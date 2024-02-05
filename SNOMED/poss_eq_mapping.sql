-- There’re three groups of mappings built using equivalence relationships:
-- 1. Let’s assume that concepts that have only one link "Concept poss_eq to" = “Maps to” have correct mappings;
-- 2. Concepts with several equivalence links were sorted according similarity (row_number window function used) and divided into two subgroups:
--- 2.1 equivalent_target_concept_id = mapped_target_concept_id and row_number = 1
---- they were reviewed and assumed to be correct (exclusions were added to the script)
--- 2.2. equivalent_target_concept_id != mapped_target_concept_id and row_number = 1
---- they were reviewed and added as new mappings to the snomed_mapped spreadsheet (exclusions were added to the script)
-- 3. Mappings for manual review
--- Concepts that need uphill mapping (equivalent target concepts include laterality, level (upper/lower), grade, etc. and various types of 'OR' concepts)
--- Devices, organisms, etc. whose concept_name contains digits require manual review
--- There are concepts that don't have any proper target among equivalents. These mappings should be dropped (e.g. 40518560x) or another target should be found

-- retrieve all possibility relationships
WITH equivalence AS (SELECT s.concept_id AS source_id,
              s.concept_name AS source_name,
       		  s.concept_code AS source_code,
       		  s.concept_class_id AS source_class_id,
       		  s.invalid_reason AS source_invalid_reason,
       		  s.domain_id AS source_domain_id,
       		  cr.invalid_reason,
       		  cr.relationship_id,
       		  NULL AS source,
       		  t.concept_id AS target_id,
			  t.concept_code AS target_code,
			  t.concept_name AS target_name,
			  t.concept_class_id AS target_concept_class_id,
			  t.standard_concept AS target_standard_concept,
			  t.invalid_reason AS target_invalid_reason,
			  t.domain_id AS target_domain_id,
			  t.vocabulary_id AS target_vocabulary_id,
			  devv5.similarity(s.concept_name, t.concept_name) AS similarity,
			  count(t.concept_id) OVER (PARTITION BY s.concept_id) AS eq_no,
			  row_number() OVER (PARTITION BY s.concept_id ORDER BY devv5.similarity(s.concept_name, t.concept_name) DESC) AS row
	   FROM concept_relationship cr
				   JOIN concept s ON cr.concept_id_1 = s.concept_id
				   JOIN concept t ON cr.concept_id_2 = t.concept_id
	   WHERE relationship_id = 'Concept poss_eq to'
		 AND cr.invalid_reason IS NULL
		 AND s.vocabulary_id = 'SNOMED'
		 AND t.vocabulary_id = 'SNOMED'
		 AND t.standard_concept = 'S'
	   ORDER BY source_id, similarity DESC, row),

-- retrieve all mappings built according to relationships of possible equivalence
mapping AS (
       select s.concept_id AS source_id,
			  s.concept_name AS source_name,
			  s.concept_code AS source_code,
			  s.concept_class_id AS source_class_id,
			  s.invalid_reason AS source_invalid_reason,
			  s.domain_id AS source_domain_id,
			  cr.invalid_reason,
			  cr.relationship_id,
			  NULL AS source,
			  t.concept_id AS target_id,
			  t.concept_code AS target_code,
			  t.concept_name AS target_name,
			  t.concept_class_id AS target_concept_class_id,
			  t.standard_concept AS target_standard_concept,
			  t.invalid_reason AS target_invalid_reason,
			  t.domain_id AS target_domain_id,
			  t.vocabulary_id AS target_vocabulary_id,
			  devv5.similarity(s.concept_name, t.concept_name) as similarity
               from concept_relationship cr
               join concept s ON cr.concept_id_1 = s.concept_id
               join concept t on cr.concept_id_2 = t.concept_id
--               join concept_relationship cre on cre.concept_id_1 = cr.concept_id_1
--               and cre.concept_id_2 = cr.concept_id_2
--               and cre.relationship_id = 'Concept poss_eq to'
--               and cre.invalid_reason is null
               WHERE cr.relationship_id = 'Maps to'
               and cr.invalid_reason is null
               and s.vocabulary_id = 'SNOMED'
--               and t.vocabulary_id = 'SNOMED'
               and concept_id_1 in (SELECT DISTINCT source_id from equivalence)
),

-- concept inactivation reasons
inact_reason as (
       SELECT cast(referencedcomponentid AS varchar) as source_code,
              m1.valueid,
              d.term
       FROM sources.der2_crefset_attributevalue_full_merged m1
								  JOIN sources.der2_crefset_assreffull_merged m2 USING (referencedcomponentid)
								  JOIN sources.sct2_desc_full_merged d ON m1.valueid = d.conceptid
					  WHERE m1.refsetid = 900000000000489007 --concept has been made inactive
					    AND m2.refsetid = 900000000000523009 --'Concept poss_eq to'
						/*AND m1.referencedcomponentid NOT IN (SELECT a.referencedcomponentid
															 FROM sources.der2_crefset_assreffull_merged a
															 WHERE a.refsetid IN
																   (900000000000526001, -- 'Concept replaced by'
																	900000000000528000, --'Concept was_a to'
																	900000000000527005, --'Concept same_as to',
																	900000000000530003)--'Concept alt_to to'
					  )*/
					 	and d.typeid = 900000000000003001 -- show only Fully specified inactivation reason
       					and m2.active = 1 -- show only active relationships
),

-- remapping required:
require_remapping AS (SELECT source_id,
							 source_name,
							 source_code,
							 source_class_id,
							 source_invalid_reason,
							 source_domain_id,
							 invalid_reason,
							 relationship_id,
							 NULL AS source,
							 target_id,
							 target_code,
							 target_name,
							 target_concept_class_id,
							 target_standard_concept,
							 target_invalid_reason,
							 target_domain_id,
							 target_vocabulary_id
					  FROM mapping m
					  WHERE source_id IN (4216787, 40350876, 4099418, 439458, 44802664, 40316058, 4145002, 4027497, 4094472, 40324107, 40289588, 4108357, 40293028, 4167071,
							40276889, 4166578, 40489217, 40405364, 40547728, 40377421, 40477803, 40569184, 40319140, 40487300, 40397873, 40573756, 3574178, 40407076,
                           40615076, 4194585,44794409,4125778,40606020,140555,4229617,4167635,4122194,40534454,4117691,4115166,40518248,4122182,73559,40624652,40601138,4099842,4134407,
                           40382248,40280828,4122171,40641850,40592937,437958,40636791,3566333,40316215,4095962,40320820,4003883,4222753,4300279,4308766,4003807,77634,4335588,
                           4069535,4308654,40502851,4342880,4280429,  200781,4220818,40303942,4077762,4337054,75336,40326017,72402, 4159178,40515023,40510153,
                           4087606,40397600,40599528,40321381,4336463,4145027,40645120,40489022,4277532,4183291,40304202,40514988,4079937,44802837,40304144,4249609,
                           40325955, 40626572, 4001729, 4003077, 4003714,433846, 4273441, 4003043,4003073,4000893, 40610569, 4003235, 40330147,40525198,4001389,
	                       4002215,4004038,4002207,4003863,40345468, 40353049,4182901,4322185,44794214,4002047,4003218,4002395, 3565988, 4026050,40375165, 40313032,
	                       76506,4126065,4122896, 4040805, 4003381,40274325,4201294,194325,4273446,4049741, 4303054,4126077,4230396,4003573,434833,4002566, 4002701,
	                       4000873,40635087,4186701,4003228,44802773,40365701,4287872,4217944,4002533,40529330,40444166,4092688,4340107,4119139,40361405,40405273,4272249,
	                       40594461,4340236,40387471,40629296,40320392,40269491,40563359,40320963,42872858,42872859,4115183,40316190,40315654,40347372,
	                       40325428,40516541,40628974,40459343,37396378,378121,4318394,3521744,40348117,40438178,3554004,3554005,40458522,45981748,45981749,4251891,
                           44809247,4251901,46096301,37394502,45971432,4122477,40320883,4115164,44801500,4167722,4291457,40283794,40477735,4122169,4291167,40612996,4244264,
                           40539101,4001531,4002693,4260665,4222440,4157490,4003568,4159657,4045574,4000883,4134152,4000761,4003864,4002376,40591517,3559366,4099728,
                           4018343,3550371,40356090,3558355,3568259,40368745,40603154,40314142,40513489,4170022,40405764,40398176,40630766,3565301,40438489,4122175,
                           4269439,4043775,4025632,40370433,44802425,4118009,3528666,44813698,4181984,3528665,40409416,40373501,40409427,4115165,40407105,
		                   4169194,40263745,4100565,4122181,433702,76502,436195,4014501,46272829,3547881,4122195,40603650,4149074,40571996,4270577,4166149,40380481,
		                   40315454,443188,443123,4234596,77352,40483629,44801945,4270606,4343685,44797616,44813697,40515497,40439834,437891,40304115,40325442,3532075,
		                   3527956,4279225,443740,4270558,40351546,40646725,40617112,4003220,4273327,4277527,72710,4099110,40397597,40326012,40650563,4110478,4087605,
		                   40352981,44802225,40585290,4248585,4273445,4094323,4302771,4273461,4002199,4273454,4107060,4003365,4003241,4002404,4001875,4001373,
		                   40635721,4111184,4001535,40331806,4003238,4003904,4003731,4145765,4113786,4066461,4002556,40456927,40368939,40650232,40366170,
		                   40420723,4003229,4003389,4002696,40389375,40321355,4031261,4221939,4000907,40373487,3527749,4000744,4263121,4223585,443196,
		                   4003543,40391904,4002064,40316170,4133404,4103169,40337761,4003397,4003561,4003225,40304895,40615014,4048174,4003391,44799909,4003862,4002038,
                           4003902,4003379,40504728,4303421,40338009,40462789,40438333,44813537,4067448,4080702,40514910,40326011,40304199,4004045,4100799,4001383,
                           4181060,4312206,4001726,4003873,4238531,40564008,4087393,40643336,40631214,4124300,4127232,40614555,40554033,760970,40436455,3544985,40273859,
                           4092687,4274178,40282186,4220534,40454580,40315488,4226161,40485817,4195367,40527567,3544521,40558354,40449259,40365133,4093297,40485817,
                           4122192,4122193,4335450,40310380,4119051,40370939,4062950,40302759,44794842,3525331,44789795,46271006,37397556,4092689,40380240,4132156,
                           4049033,4005680,40304099,4093522,4065568,40502838,4133022,40284333,44796157,44813227,4088440,40362228,4265916,40417445,4169555,40502420,
                           3553405,40345665,77642,4029484,40310153, 4083400, 44810594, 40309285, 4272616,46128523,4196472,44812876,40395953,40399521, 40308749,40329129,4224741,40508011,4233418,40616013, 4043402,40607510, 40325432,40304104, 40317257,40402778,40547717, 40393289, 40604752,40359653,
  	           40443626, 40431778, 40332400, 79115,40299974,4182392, 40274832,40566260,40515146,40385677,376117,40332937,40301845, 40331949,40439791,440776,4225667, 40397833,
  	           40625816, 40611524,40272139, 40385722,40630968,40645747, 40271498,40284909, 40634007, 4003040,438871,40305652,40310947,40502326,82007,40651751, 40280909,
  	           4117528,40327038,4233286, 40285622,40388623, 4109053,40384376, 40532928,40397421,40420451,40388229,40525231,40395822, 44801824,40413831,198643,40633228,4299724,
  	           44795074,40625418,40314182,40288249,4185094,40301224,4013402,44795095,40610427,40652044,40345150,4122078,4080911,40273780,40354875,3555693,40626026,40431447,
  	           40315453,4119899,40274840,40388523,40455856,40422973,40378091,40378095,4283218,44801753,40348800,40358202,40277853,40570632,4032717,44793320,40345665,40443073,
  	           40630476,40480819,40322426,40310404,40397341,443764,193827)
),

--2.1 equivalent_target_concept_id = mapped_target_concept_id and row_number = 1
--- concepts with multiple 'Concept poss_eq to' links and correct mapping
--- they were reviewed and assumed to be correct (exclusions were added to the script)
multiple_link_true_mapping AS (
       select  m.source_id,
              m.source_name,
			  m.source_code,
			  m.source_class_id,
			  m.source_invalid_reason,
			  m.source_domain_id,
			  m.invalid_reason,
			  m.relationship_id,
			  NULL AS source,
			  m.target_id,
			  m.target_code,
			  m.target_name,
			  m.target_concept_class_id,
			  m.target_standard_concept,
			  m.target_invalid_reason,
			  m.target_domain_id,
			  m.target_vocabulary_id
	   FROM mapping m
				JOIN equivalence e ON m.source_id = e.source_id
			  AND e.target_id = m.target_id
	   WHERE eq_no > 1
		 AND row = 1
		 AND e.target_name !~* ('high|low|upper|lower|malignant|benign|left|right|entire|primary|anterior|posterior|total|partial|bandage|dressing')
		 AND e.source_class_id != 'Organism'
		 AND m.source_name !~* ('(\s)\(&(\s)|\[&(\s)|(\s)or(\s)|(\s)and(\s)|(\s)&\/or(\s)|and/or|(\s)I(\s)|(\s)I$|(\s)II(\s)|III|(\s)IV(\s)') --|\d
		 AND m.source_id NOT IN (SELECT source_id FROM require_remapping)
--order by similarity desc
),

-- true_mapping include:
-- concepts with single 'Concept poss_eq to' link = 'Maps to' (assume this mapping is true)
-- reviewed mapping from the tables above
true_mapping AS (SELECT m.source_id,
						m.source_name,
						m.source_code,
						m.source_class_id,
						m.source_invalid_reason,
						m.source_domain_id,
						m.invalid_reason,
						m.relationship_id,
						NULL AS source,
						m.target_id,
						m.target_code,
						m.target_name,
						m.target_concept_class_id,
						m.target_standard_concept,
						m.target_invalid_reason,
						m.target_domain_id,
						m.target_vocabulary_id
				 FROM mapping m
							 JOIN equivalence e ON m.source_id = e.source_id
						AND e.target_id = m.target_id
				 WHERE eq_no = 1

UNION

SELECT * FROM multiple_link_true_mapping

UNION

SELECT m.source_id,
       m.source_name,
       m.source_code,
       m.source_class_id,
       m.source_invalid_reason,
       m.source_domain_id,
       m.invalid_reason,
       m.relationship_id,
       NULL AS source,
       m.target_id,
       m.target_code,
       m.target_name,
       m.target_concept_class_id,
       m.target_standard_concept,
       m.target_invalid_reason,
       m.target_domain_id,
       m.target_vocabulary_id
FROM mapping m
WHERE m.source_id IN
			 (40352976, 40274430, 40577951, 40542370, 40648413, 40275374, 40440347, 40544208, 40620284, 40640604,
			  4099272, 40623593, 40444565, 3574179, 3546734, 3574180,
				40347516,40438879,40626462,40399527,40288717,40613832,40452977,3543533,40358927, 40350749,40298634,40546618,3545470,40272921,40463512,40259354,
				40404247,40648145,40617882,40261969,3555707,40637034,4248402,40644653,40608973,40583397,40515007,40617978,40346305,3524409,4084295,40608288,4282919,40371513,
				40313153,40390393,253788,40395008,40613321,43531050,40597863,40363212,441227,40637925,40610271,4040376,40376211,40344443,40606992,40635167,40310665,
				40340527,4112990,40569818,4016961,40450530,40441573,40522661,40636288,40489408,4166936,40315452,40384464,40429387,4085884,40308248,4172037,
				40406922,406252672,4271338,3555649,40390761,40310396,40638498,4174300,40388228,40632077,40387701,40629552,44813084,44813002,4090556,40512103,
				40547756,40262314,40448540,40443378,40361104,40444094,40274838,40507239,4211395,40284919,4195280,40303799,40303797,40424161,40323013,
				40258764,44795392,40299070,4089073,40393741,4269627,40263031,3555691,435561,40284926,40376867,40512096,40510461,40591233,40396036,4331828,
				40599010,40380240,40608596,40632531,444082,40571802,40536564,134976,40345602,4093029,40390613,40487145,4058770,40314400,40509492,35622253,
				3528004,40576315,40632563,40538154,40355821,40578067,40396697,40363155,40599947,40450388,40641774,40350814,40442617,4247174,
				40574607,40630387,4172554,40464979,4046035,3562880,44799061,40515068,44796841,3550360,40595989,4314685,40451497)
),

--- 2.2. equivalent_target_concept_id != mapped_target_concept_id and row_number = 1
-- they were reviewed and added as new mappings to the snomed_mapped spreadsheet (exclusions were added to the script)
-- alternative target with highest similarity score (REVIEWED)
alternative_mapping AS (
SELECT m.source_id,
       m.source_name,
       m.source_code,
       m.source_class_id,
       m.source_invalid_reason,
       m.source_domain_id,
       m.invalid_reason,
       m.relationship_id,
       NULL AS source,
       e.target_id,
       e.target_code,
       e.target_name,
       e.target_concept_class_id,
       e.target_standard_concept,
       e.target_invalid_reason,
       e.target_domain_id,
       e.target_vocabulary_id
FROM mapping m
			JOIN equivalence e ON m.source_id = e.source_id
	   AND e.target_id != m.target_id
WHERE eq_no > 1
  AND row = 1
  AND e.target_name !~*   ('high|low|upper|lower|malignant|benign|left|right|entire|primary|anterior|posterior|total|partial|band|girdle')
  AND e.source_class_id != 'Organism'
  AND m.source_name !~*	  ('\(&(\s)|\[&(\s)|(\s)or(\s)|(\s)and(\s)|(\s)&\/or(\s)|and/or|(\s)I(\s)|(\s)I$|(\s)II(\s)|III|(\s)IV(\s)') --|\d
  AND m.source_id NOT IN (SELECT source_id FROM require_remapping)
  AND m.source_id NOT IN (SELECT source_id FROM true_mapping)
  AND m.source_id NOT IN (
	 -- wrong alternative target, wrong current mapping (correct target present among other equivalent relat)
		             40341290,40429870,4299186,40520375,45995764,40530650,44813086,4113603,40400424,4092426,40515497,40417537,40320868,40305132,4162443,40355611,
		             40285824,40622584,40338285,40278564,4048338,40641455,40316174,40612063,40633600,40353268,40448437,40445299,40349090,40599087
	   )
--order by similarity desc
)
/*
SELECT DISTINCT e.source_code, e.source_name,
                COUNT (DISTINCT ir.valueid)
FROM equivalence e
JOIN inact_reason ir using(source_code)
where --ir.valueid = 900000000000482003 -- duplicate
-- 900000000000484002 -- ambiguous
-- 900000000000485001 - erroneous
-- 900000000000486000 -- limited
-- 900000000000487009 -- moved elsewhere
-- 900000000000492006 -- pending move
-- 900000000000483008 -- outdated
e.similarity = 1
GROUP BY e.source_code, e.source_name;
*/
-- extract mapping list for manual review

SELECT source_name,
	   source_code,
	   source_class_id,
	   source_invalid_reason,
	   source_domain_id,
	   invalid_reason,
	   relationship_id,
	   NULL AS source,
	   target_id,
	   target_code,
	   target_name,
	   target_concept_class_id,
	   target_standard_concept,
	   target_invalid_reason,
	   target_domain_id,
	   target_vocabulary_id
FROM require_remapping

         UNION

SELECT m.source_name,
	   m.source_code,
	   m.source_class_id,
	   m.source_invalid_reason,
	   m.source_domain_id,
	   invalid_reason,
	   m.relationship_id,
	   NULL AS source,
	   m.target_id,
	   m.target_code,
	   m.target_name,
	   m.target_concept_class_id,
	   m.target_standard_concept,
	   m.target_invalid_reason,
	   m.target_domain_id,
	   m.target_vocabulary_id
FROM mapping m
WHERE source_id NOT IN (SELECT source_id FROM true_mapping)
AND source_id NOT IN (SELECT source_id FROM alternative_mapping)
AND source_id not in (select a.concept_id_1
                      from concept_relationship a
                      where a.relationship_id  IN ('Concept replaced by',
													'Concept same_as to',
													'Concept alt_to to',
													'Concept was_a to')
						and a.invalid_reason is null)

ORDER BY source_domain_id, source_code

/*SELECT * FROM alternative_mapping

UNION

SELECT m.source_id,
       m.source_name,
       m.source_code,
       m.source_class_id,
       m.source_invalid_reason,
       m.source_domain_id,
       'D' AS invalid_reason,
       m.relationship_id,
       NULL AS source,
       m.target_id,
       m.target_code,
       m.target_name,
       m.target_concept_class_id,
       m.target_standard_concept,
       m.target_invalid_reason,
       m.target_domain_id,
       m.target_vocabulary_id
FROM mapping m
			JOIN alternative_mapping USING (source_id)

ORDER BY source_id, source_invalid_reason*/
;

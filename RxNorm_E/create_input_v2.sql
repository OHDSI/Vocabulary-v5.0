--DCS
DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1131419';--Acetarsol

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1000382';--Bilastine

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP2721034';--Calcium

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1131501';--Camphene

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1131504';--Carbetocin

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1131611';--manna

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1131633';--Oxetacaine

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP2721400';--Potassium

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP997623';--Rupatadine Fumarate

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP2721452';--Sodium

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1131687';--Stiripentol

-- BN work
UPDATE drug_concept_stage
SET concept_name = initcap(regexp_replace(lower(concept_name), '( ltd)|( inc\.)| uk |( eu)( llc)|( limited)| ulc| (ltee)|( msd)|( ulc)|( plc)|( pharmaceuticals)|( gmbh)|( lab.*)|( - .*)| \(royaume-uni\)| france| \(pay-bas\)| canada| uk| \(u\.k\.\)| \(allemagne\)| \(grande-bretagne\)| \(grande bretagne\) \(autriche\)| \(belgique\)| \(irlande\)| \(danemark\)| \(societe\)| \(portugal\)| \(luxmebourg\)| \(republique tcheque\)', '', 'g'))
WHERE concept_class_id = 'Supplier'
	AND concept_code NOT IN (
		SELECT concept_code_1
		FROM suppliers_to_repl
		)
	AND concept_name NOT LIKE '%GmbH & Co%';

UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, '\(.*', '', 'g')
WHERE concept_class_id = 'Supplier'
	AND concept_code NOT IN (
		SELECT concept_code_1
		FROM suppliers_to_repl
		);

UPDATE drug_concept_stage
SET concept_name = initcap(replace(lower(concept_name), ' comp', ''))
WHERE concept_class_id = 'Brand Name'
	AND concept_name ~ '-Q|Beloc|Enala|Prelis|Dormiphen|Eryfer|Provas|Isozid| Al | Ass |Quadronal|Dormiphen|Latanomed|Estramon|Valsacor|Dispadex';

UPDATE drug_concept_stage
SET concept_name = replace(concept_name, ' INJECTABLE', '')
WHERE concept_class_id = 'Brand Name'
	AND concept_name ~ 'ASPEGIC|AZANTAC|SPASMAG|TRIVASTAL|UNACIM';

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Brand Name'
			AND concept_name ~* '( comp$)|comprim|compound|(um .*um )|praeparatum| rh | injectable|zinci|phosphorus|(\d+(\.\d+)? m )|unguentum|molar|zincum|codeinum|apis| oel | oel$|((thym|baum|castor|halibut|lavandula|seed).*( tee | oleum| oil))|graveolens'
			AND NOT concept_name ~* 'PHARM|ABTEI|HEEL|INJEE|WINTHROP| ASS | AL |ROCHE|HEUMANN|MERCK|BLUESFISH|WESTERN|PHARMA|ZENTIVA|PFIZER|PHARMA|MEDE|MEDAC|FAIR|HAMELN|ACCORD|RATIO|AXCOUNT|STADA|SANDOZ|SOLVAY|GLENMARK|APOTHEKE|HEXAL|TEVA|AUROBINDO|ORION|SYXYL|NEURAX|KOHNE|ACTAVIS|CLARIS|NOVUM|ABZ|AXCOUNT|MYLAN|ARISTO|KABI|BENE|HORMOSAN|ZENTIVA|PUREN|BIOMO|ACIS|RATIOPH|SYNOMED|ALPHA|ROTEXMEDICA|BERCO|DURA|DAGO|GASTREU|FORTE|VITAL|VERLA|ONKOVIS|ONCOTRADE|NEOCORP'
			AND NOT concept_name ~* 'asa-|lambert|balneovit|similiaplex|heidac'
		);

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Brand Name'
	AND concept_name ~* '( comp$)|comprim|compound|(um .*um )|praeparatum| rh | injectable|zinci|phosphorus|(\d+(\.\d+)? m )|unguentum|molar|zincum|codeinum|apis| oel | oel$|((thym|baum|castor|halibut|lavandula|seed).*( tee | oleum| oil))|graveolens'
	AND NOT concept_name ~* 'PHARM|ABTEI|HEEL|INJEE|WINTHROP| ASS | AL |ROCHE|HEUMANN|MERCK|BLUESFISH|WESTERN|PHARMA|ZENTIVA|PFIZER|PHARMA|MEDE|MEDAC|FAIR|HAMELN|ACCORD|RATIO|AXCOUNT|STADA|SANDOZ|SOLVAY|GLENMARK|APOTHEKE|HEXAL|TEVA|AUROBINDO|ORION|SYXYL|NEURAX|KOHNE|ACTAVIS|CLARIS|NOVUM|ABZ|AXCOUNT|MYLAN|ARISTO|KABI|BENE|HORMOSAN|ZENTIVA|PUREN|BIOMO|ACIS|RATIOPH|SYNOMED|ALPHA|ROTEXMEDICA|BERCO|DURA|DAGO|GASTREU|FORTE|VITAL|VERLA|ONKOVIS|ONCOTRADE|NEOCORP'
	AND NOT concept_name ~* 'asa-|lambert|balneovit|similiaplex|heidac';

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT d1.concept_code
		FROM drug_concept_stage d1
		JOIN concept c ON LOWER(d1.concept_name) = LOWER(c.concept_name)
			AND d1.concept_class_id = 'Brand Name'
			AND c.concept_class_id IN (
				'ATC 5th',
				'ATC 4th',
				'ATC 3rd',
				'AU Substance',
				'AU Qualifier',
				'Chemical Structure',
				'CPT4 Hierarchy',
				'Gemscript',
				'Gemscript THIN',
				'GPI',
				'Ingredient',
				'Substance',
				'LOINC Hierarchy',
				'Main Heading',
				'Organism',
				'Pharma Preparation'
				)
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT d1.concept_code
		FROM drug_concept_stage d1
		JOIN concept c ON LOWER(d1.concept_name) = LOWER(c.concept_name)
			AND d1.concept_class_id = 'Brand Name'
			AND c.concept_class_id IN (
				'ATC 5th',
				'ATC 4th',
				'ATC 3rd',
				'AU Substance',
				'AU Qualifier',
				'Chemical Structure',
				'CPT4 Hierarchy',
				'Gemscript',
				'Gemscript THIN',
				'GPI',
				'Ingredient',
				'Substance',
				'LOINC Hierarchy',
				'Main Heading',
				'Organism',
				'Pharma Preparation'
				)
		);

--Suppliers
UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, ',.*', '', 'g')
WHERE (concept_name) LIKE '%,%'
	AND concept_class_id = 'Supplier';

UPDATE drug_concept_stage
SET concept_name = 'Les Laboratories Servier'
WHERE concept_code = 'OMOP439865';

UPDATE drug_concept_stage
SET concept_name = 'Les Laboratoires Bio-Sante'
WHERE concept_code = 'OMOP1019085';

UPDATE drug_concept_stage
SET concept_name = 'Les Laboratoires Du Saint-Laurent'
WHERE concept_code = 'OMOP1019086';

UPDATE drug_concept_stage
SET concept_name = 'Les Laboratoires Swisse'
WHERE concept_code = 'OMOP1019087';

UPDATE drug_concept_stage
SET concept_name = 'Les Laboratoires Vachon'
WHERE concept_code = 'OMOP1019088';

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT a.concept_code
		FROM drug_concept_stage a
		JOIN drug_concept_stage b ON a.concept_name = b.concept_name
			AND a.concept_class_id = 'Brand Name'
			AND b.concept_class_id IN (
				'Supplier',
				'Ingredient'
				)
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT dcs.concept_code
		FROM drug_concept_stage dcs
		JOIN concept c ON lower(dcs.concept_name) = lower(c.concept_name)
			AND c.vocabulary_id = 'RxNorm'
			AND dcs.concept_class_id = 'Brand Name'
			AND c.concept_class_id = 'Ingredient'
		);

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Supplier'
	AND concept_name LIKE '%Imported%';

DELETE
FROM drug_concept_stage
WHERE concept_name IN (
		'Ultracare',
		'Ultrabalance',
		'Tussin',
		'Triad',
		'Aplicare',
		'Lactaid'
		)
	AND concept_class_id = 'Supplier';

DELETE
FROM drug_concept_stage
WHERE concept_name = 'Cream'
	AND concept_class_id = 'Brand Name';

--semi-manual suppl
DELETE
FROM internal_relationship_stage --syrup
WHERE concept_code_2 = 'OMOP993256';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP993256';

DELETE
FROM internal_relationship_stage --gomenol
WHERE concept_code_2 = 'OMOP439967';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP439967';

DELETE
FROM internal_relationship_stage -- graphytes
WHERE concept_code_2 = 'OMOP336422';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP336422';

DELETE
FROM internal_relationship_stage --healthaid
WHERE concept_code_2 = 'OMOP336747';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP336747';

--hepatoum
DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = 'OMOP440244';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP440244';

--disso blabla
DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = 'OMOP440141';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP440141';

--changing supplier's names
UPDATE drug_concept_stage dcs
SET concept_name = c.concept_name
FROM (
	SELECT c.concept_name,
		c.concept_code
	FROM drug_concept_stage dcs2
	JOIN concept c ON c.concept_code = dcs2.concept_code
		AND c.vocabulary_id = 'RxNorm Extension'
		AND c.concept_class_id = 'Supplier'
	) c
WHERE dcs.concept_code = c.concept_code;

UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, 'Pharmaceuticals\.|Pharmaceuticals|Pharmaceutical Products|Pharmaceutical Product|Pharmaceutical|Pharmazeutische Produkte|Pharma|Pharms| Pharm$| Pharm ', '', 'gi')
WHERE concept_name ilike '% pharm%'
	AND concept_class_id = 'Supplier';

UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, 'Incorporated|Inc\.|Inc', '', 'g')
WHERE concept_name ilike '% inc%';

UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, 'GmbH & Co\. KG|GmbH & Co\.|GmbH & Co|GmbH|mbH & Co\.KG', '', 'gi')
WHERE (
		concept_name ilike '% mbh%'
		OR concept_name ilike '% gmbh%'
		)
	AND concept_class_id = 'Supplier';

UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, 'Group', '', 'gi')
WHERE concept_class_id = 'Supplier'
	AND concept_name NOT LIKE '%Le Group%';

UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, 'Technologies|Limited|Specialty|Corporation|European|Europe| SERVICES|Manufacturing|Regulatory Solutions|Environmental Solutions|Mobility Solutions|Solutions|Vaccines and Diagnostics|Diagnostics|Life Sciences|Therapeutics|Deutschland|NETHERLANDS|TRADING|Medical Products|Medical', '', 'gi')
WHERE concept_class_id = 'Supplier'
	AND NOT concept_name ~ '^Laboratories|^Healthcare|^Arzneimittel|^International|^Medical|^Product|^Nutrition|^Commercial';

UPDATE drug_concept_stage
SET concept_name = trim(replace(rtrim(concept_name, '-'), '  ', ' '))
WHERE concept_name LIKE '%-';

UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, 'Laboratories|Sweden|Healthcare Products|Healthcare|Commercial|Sales Services|Health Care|Management|Arzneimittel|Canada|Company|\(.*\)|Registration|Nutritionals|Nutrition|Consumer Health|Consumer|Sante| SCIENCES| MALTA|FRANCE|International| Inc\.?| Ltee| Ltd\.?| Plc| PLC| Llc| Ulc| UK| \(UK\)| \(U\.K\.\)|U\.K\.| EU$| Ab$| A/S| AG$|&$| and$| of$', '', 'gi')
WHERE concept_class_id = 'Supplier'
	AND NOT concept_name ~ '^Laboratories|^Healthcare|^Arzneimittel|^International|^Medical|^Product|^Nutrition|^Commercial';

UPDATE drug_concept_stage
SET concept_name = regexp_replace(concept_name, ' \[HIST\]|e\.k\.', '', 'gi')
WHERE concept_class_id = 'Supplier';

UPDATE drug_concept_stage
SET concept_name = initcap(concept_name)
WHERE concept_class_id = 'Supplier'
	AND (
		SELECT count(*)
		FROM regexp_matches(concept_name, '[[:upper:]]', 'g')
		) > 5;

UPDATE drug_concept_stage
SET concept_name = trim(replace(rtrim(concept_name, '-'), '  ', ' '))
WHERE concept_name LIKE '%-';

DO $_ $
BEGIN
	UPDATE drug_concept_stage
	SET concept_name = 'FIDIA FARMACEUTICI'
	WHERE concept_code = 'OMOP898169';

	UPDATE drug_concept_stage
	SET concept_name = 'Dentinox'
	WHERE concept_code = 'OMOP897991';

	UPDATE drug_concept_stage
	SET concept_name = 'Miles'
	WHERE concept_code = 'OMOP1018785';

	UPDATE drug_concept_stage
	SET concept_name = 'Labs Nordic Laboratories'
	WHERE concept_code = 'OMOP1019043';

	UPDATE drug_concept_stage
	SET concept_name = 'Lilly'
	WHERE concept_code = 'OMOP339232';

	UPDATE drug_concept_stage
	SET concept_name = 'TEVA'
	WHERE concept_code = 'OMOP439847';

	UPDATE drug_concept_stage
	SET concept_name = 'Gentium'
	WHERE concept_code = 'OMOP338026';

	UPDATE drug_concept_stage
	SET concept_name = 'ALK'
	WHERE concept_code = 'OMOP1018216';

	UPDATE drug_concept_stage
	SET concept_name = 'Janssen'
	WHERE concept_code = 'OMOP440202';

	UPDATE drug_concept_stage
	SET concept_name = 'Fresenius'
	WHERE concept_code = 'OMOP338813';

	UPDATE drug_concept_stage
	SET concept_name = 'Cutter'
	WHERE concept_code = 'OMOP1018742';

	UPDATE drug_concept_stage
	SET concept_name = 'Ahorn Apotheke'
	WHERE concept_code = 'OMOP898024';

	UPDATE drug_concept_stage
	SET concept_name = 'Amsco'
	WHERE concept_code = 'OMOP1018273';

	UPDATE drug_concept_stage
	SET concept_name = 'Anpharm'
	WHERE concept_code = 'OMOP1018280';

	UPDATE drug_concept_stage
	SET concept_name = 'BASILEA'
	WHERE concept_code = 'OMOP440251';

	UPDATE drug_concept_stage
	SET concept_name = 'BRISTOL-MYERS SQUIBB'
	WHERE concept_code = 'OMOP439842';

	UPDATE drug_concept_stage
	SET concept_name = 'Colgate'
	WHERE concept_code = 'OMOP1018724';

	UPDATE drug_concept_stage
	SET concept_name = 'Diomed'
	WHERE concept_code = 'OMOP900358';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr. Kade'
	WHERE concept_code = 'OMOP900325';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr.Mewes Heilmittel'
	WHERE concept_code = 'OMOP897388';

	UPDATE drug_concept_stage
	SET concept_name = 'FirstGenerixGermany'
	WHERE concept_code = 'OMOP899895';

	UPDATE drug_concept_stage
	SET concept_name = 'Golden Pride'
	WHERE concept_code = 'OMOP1018524';

	UPDATE drug_concept_stage
	SET concept_name = 'Hobon'
	WHERE concept_code = 'OMOP1019157';

	UPDATE drug_concept_stage
	SET concept_name = 'Huronia'
	WHERE concept_code = 'OMOP1019139';

	UPDATE drug_concept_stage
	SET concept_name = ' Intega Skin'
	WHERE concept_code = 'OMOP1019141';

	UPDATE drug_concept_stage
	SET concept_name = 'Canus Goat''S Milk'
	WHERE concept_code = 'OMOP1019089';

	UPDATE drug_concept_stage
	SET concept_name = 'Lotus Lab'
	WHERE concept_code = 'OMOP899585';

	UPDATE drug_concept_stage
	SET concept_name = 'PINNACLE'
	WHERE concept_code = 'OMOP440335';

	UPDATE drug_concept_stage
	SET concept_name = 'Professional'
	WHERE concept_code = 'OMOP1019339';

	UPDATE drug_concept_stage
	SET concept_name = 'Sifi North America'
	WHERE concept_code = 'OMOP1019711';

	UPDATE drug_concept_stage
	SET concept_name = 'Valeant'
	WHERE concept_code = 'OMOP1019618';

	UPDATE drug_concept_stage
	SET concept_name = 'Vallee'
	WHERE concept_code = 'OMOP1019486';

	UPDATE drug_concept_stage
	SET concept_name = 'H & S Tee'
	WHERE concept_code = 'OMOP898496';

	UPDATE drug_concept_stage
	SET concept_name = 'Herbalife'
	WHERE concept_code = 'OMOP1019125';

	UPDATE drug_concept_stage
	SET concept_name = 'Biogen'
	WHERE concept_code = 'OMOP338399';

	UPDATE drug_concept_stage
	SET concept_name = 'Bencard'
	WHERE concept_code = 'OMOP899463';

	UPDATE drug_concept_stage
	SET concept_name = 'Cambridge'
	WHERE concept_code = 'OMOP2018411';

	UPDATE drug_concept_stage
	SET concept_name = 'Ayrton'
	WHERE concept_code = 'OMOP572464';

	UPDATE drug_concept_stage
	SET concept_name = 'Braun'
	WHERE concept_code = 'OMOP440014';

	UPDATE drug_concept_stage
	SET concept_name = 'Aventis'
	WHERE concept_code = 'OMOP1018338';

	UPDATE drug_concept_stage
	SET concept_name = 'Carter'
	WHERE concept_code = 'OMOP1018469';

	UPDATE drug_concept_stage
	SET concept_name = 'Casen'
	WHERE concept_code = 'OMOP338684';

	UPDATE drug_concept_stage
	SET concept_name = 'Celltrion'
	WHERE concept_code = 'OMOP1018695';

	UPDATE drug_concept_stage
	SET concept_name = 'Colgate'
	WHERE concept_code = 'OMOP339265';

	UPDATE drug_concept_stage
	SET concept_name = 'GDS'
	WHERE concept_code = 'OMOP2018500';

	UPDATE drug_concept_stage
	SET concept_name = 'Gentium'
	WHERE concept_code = 'OMOP338026';

	UPDATE drug_concept_stage
	SET concept_name = 'Bailleul'
	WHERE concept_code = 'OMOP440079';

	UPDATE drug_concept_stage
	SET concept_name = 'Lek'
	WHERE concept_code = 'OMOP898216';

	UPDATE drug_concept_stage
	SET concept_name = 'Merrell'
	WHERE concept_code = 'OMOP1018914';

	UPDATE drug_concept_stage
	SET concept_name = 'Neovii'
	WHERE concept_code = 'OMOP338079';

	UPDATE drug_concept_stage
	SET concept_name = 'Nuron B.V'
	WHERE concept_code = 'OMOP1019368';

	UPDATE drug_concept_stage
	SET concept_name = 'Olympus'
	WHERE concept_code = 'OMOP338444';

	UPDATE drug_concept_stage
	SET concept_name = 'Buchholz'
	WHERE concept_code = 'OMOP2018737';

	UPDATE drug_concept_stage
	SET concept_name = 'Mar'
	WHERE concept_code = 'OMOP440422';

	UPDATE drug_concept_stage
	SET concept_name = 'Rapidscan'
	WHERE concept_code = 'OMOP338461';

	UPDATE drug_concept_stage
	SET concept_name = 'Regent'
	WHERE concept_code = 'OMOP439892';

	UPDATE drug_concept_stage
	SET concept_name = 'Rhone-Poulenc'
	WHERE concept_code = 'OMOP1019253';

	UPDATE drug_concept_stage
	SET concept_name = 'Guttroff'
	WHERE concept_code = 'OMOP899637';

	UPDATE drug_concept_stage
	SET concept_name = 'Schoening'
	WHERE concept_code = 'OMOP2018824';

	UPDATE drug_concept_stage
	SET concept_name = 'Schwarzkopf'
	WHERE concept_code = 'OMOP1019775';

	UPDATE drug_concept_stage
	SET concept_name = 'Scott'
	WHERE concept_code = 'OMOP1019793';

	UPDATE drug_concept_stage
	SET concept_name = 'Bernburg'
	WHERE concept_code = 'OMOP897672';

	UPDATE drug_concept_stage
	SET concept_name = 'Squibb'
	WHERE concept_code = 'OMOP900126';

	UPDATE drug_concept_stage
	SET concept_name = 'Sterling'
	WHERE concept_code = 'OMOP1019625';

	UPDATE drug_concept_stage
	SET concept_name = 'Sobi'
	WHERE concept_code = 'OMOP338479';

	UPDATE drug_concept_stage
	SET concept_name = 'Wampole'
	WHERE concept_code = 'OMOP1019503';

	UPDATE drug_concept_stage
	SET concept_name = 'Produits Sanitaires'
	WHERE concept_code = 'OMOP1019336';

	UPDATE drug_concept_stage
	SET concept_name = 'Actavis'
	WHERE concept_code = 'OMOP1018198';

	UPDATE drug_concept_stage
	SET concept_name = 'Cambridge'
	WHERE concept_code = 'OMOP2018411';

	UPDATE drug_concept_stage
	SET concept_name = 'Ayrton'
	WHERE concept_code = 'OMOP572464';

	UPDATE drug_concept_stage
	SET concept_name = 'Braun'
	WHERE concept_code = 'OMOP440014';

	UPDATE drug_concept_stage
	SET concept_name = 'Aventis'
	WHERE concept_code = 'OMOP1018338';

	UPDATE drug_concept_stage
	SET concept_name = 'Carter'
	WHERE concept_code = 'OMOP1018469';

	UPDATE drug_concept_stage
	SET concept_name = 'Casen'
	WHERE concept_code = 'OMOP338684';

	UPDATE drug_concept_stage
	SET concept_name = 'Celltrion'
	WHERE concept_code = 'OMOP1018695';

	UPDATE drug_concept_stage
	SET concept_name = 'Colgate'
	WHERE concept_code = 'OMOP339265';

	UPDATE drug_concept_stage
	SET concept_name = 'GDS'
	WHERE concept_code = 'OMOP2018500';

	UPDATE drug_concept_stage
	SET concept_name = 'Gentium'
	WHERE concept_code = 'OMOP338026';

	UPDATE drug_concept_stage
	SET concept_name = 'Bailleul'
	WHERE concept_code = 'OMOP440079';

	UPDATE drug_concept_stage
	SET concept_name = 'Lek'
	WHERE concept_code = 'OMOP898216';

	UPDATE drug_concept_stage
	SET concept_name = 'Merrell'
	WHERE concept_code = 'OMOP1018914';

	UPDATE drug_concept_stage
	SET concept_name = 'Neovii'
	WHERE concept_code = 'OMOP338079';

	UPDATE drug_concept_stage
	SET concept_name = 'Nuron B.V'
	WHERE concept_code = 'OMOP1019368';

	UPDATE drug_concept_stage
	SET concept_name = 'Olympus'
	WHERE concept_code = 'OMOP338444';

	UPDATE drug_concept_stage
	SET concept_name = 'Buchholz'
	WHERE concept_code = 'OMOP2018737';

	UPDATE drug_concept_stage
	SET concept_name = 'Mar'
	WHERE concept_code = 'OMOP440422';

	UPDATE drug_concept_stage
	SET concept_name = 'Rapidscan'
	WHERE concept_code = 'OMOP338461';

	UPDATE drug_concept_stage
	SET concept_name = 'Regent'
	WHERE concept_code = 'OMOP439892';

	UPDATE drug_concept_stage
	SET concept_name = 'Rhone-Poulenc'
	WHERE concept_code = 'OMOP1019253';

	UPDATE drug_concept_stage
	SET concept_name = 'Guttroff'
	WHERE concept_code = 'OMOP899637';

	UPDATE drug_concept_stage
	SET concept_name = 'Schoening'
	WHERE concept_code = 'OMOP2018824';

	UPDATE drug_concept_stage
	SET concept_name = 'Schwarzkopf'
	WHERE concept_code = 'OMOP1019775';

	UPDATE drug_concept_stage
	SET concept_name = 'Scott'
	WHERE concept_code = 'OMOP1019793';

	UPDATE drug_concept_stage
	SET concept_name = 'Bernburg'
	WHERE concept_code = 'OMOP897672';

	UPDATE drug_concept_stage
	SET concept_name = 'Squibb'
	WHERE concept_code = 'OMOP900126';

	UPDATE drug_concept_stage
	SET concept_name = 'Sterling'
	WHERE concept_code = 'OMOP1019625';

	UPDATE drug_concept_stage
	SET concept_name = 'Sobi'
	WHERE concept_code = 'OMOP338479';

	UPDATE drug_concept_stage
	SET concept_name = 'Wampole'
	WHERE concept_code = 'OMOP1019503';

	UPDATE drug_concept_stage
	SET concept_name = 'Produits Sanitaires'
	WHERE concept_code = 'OMOP1019336';

	UPDATE drug_concept_stage
	SET concept_name = '1 A'
	WHERE concept_code = 'OMOP897322';

	UPDATE drug_concept_stage
	SET concept_name = '2care4'
	WHERE concept_code = 'OMOP2018281';

	UPDATE drug_concept_stage
	SET concept_name = 'A Baur'
	WHERE concept_code = 'OMOP898745';

	UPDATE drug_concept_stage
	SET concept_name = 'A Menarini'
	WHERE concept_code = 'OMOP338242';

	UPDATE drug_concept_stage
	SET concept_name = 'A Nattermann'
	WHERE concept_code = 'OMOP900145';

	UPDATE drug_concept_stage
	SET concept_name = 'Aaston'
	WHERE concept_code = 'OMOP2018285';

	UPDATE drug_concept_stage
	SET concept_name = 'Aatal-Apotheke Christina Schrick'
	WHERE concept_code = 'OMOP898717';

	UPDATE drug_concept_stage
	SET concept_name = 'ABF'
	WHERE concept_code = 'OMOP899680';

	UPDATE drug_concept_stage
	SET concept_name = 'Abis'
	WHERE concept_code = 'OMOP2018288';

	UPDATE drug_concept_stage
	SET concept_name = 'ABJ'
	WHERE concept_code = 'OMOP1018170';

	UPDATE drug_concept_stage
	SET concept_name = 'Abo & Painex'
	WHERE concept_code = 'OMOP899329';

	UPDATE drug_concept_stage
	SET concept_name = 'Abtswinder Naturheilmittel'
	WHERE concept_code = 'OMOP897951';

	UPDATE drug_concept_stage
	SET concept_name = 'AC'
	WHERE concept_code = 'OMOP899626';

	UPDATE drug_concept_stage
	SET concept_name = 'Accura'
	WHERE concept_code = 'OMOP338685';

	UPDATE drug_concept_stage
	SET concept_name = 'ACS'
	WHERE concept_code = 'OMOP898101';

	UPDATE drug_concept_stage
	SET concept_name = 'Adams'
	WHERE concept_code = 'OMOP1018202';

	UPDATE drug_concept_stage
	SET concept_name = 'Adler-Apotheke Dr Christian & Dr Alfons Tenner'
	WHERE concept_code = 'OMOP899205';

	UPDATE drug_concept_stage
	SET concept_name = 'Adler-Apotheke Dr Gerhard Haubold Jun'
	WHERE concept_code = 'OMOP900457';

	UPDATE drug_concept_stage
	SET concept_name = 'Adler-Apotheke Erhard & Ernst Sprakel'
	WHERE concept_code = 'OMOP899756';

	UPDATE drug_concept_stage
	SET concept_name = 'Adler-Apotheke Johannes Jaenicke'
	WHERE concept_code = 'OMOP900016';

	UPDATE drug_concept_stage
	SET concept_name = 'Adler-Apotheke Karl Aisslinger & Kurt Suesser'
	WHERE concept_code = 'OMOP897511';

	UPDATE drug_concept_stage
	SET concept_name = 'ADOH'
	WHERE concept_code = 'OMOP899203';

	UPDATE drug_concept_stage
	SET concept_name = 'Adolf Haupt'
	WHERE concept_code = 'OMOP898754';

	UPDATE drug_concept_stage
	SET concept_name = 'Aframed'
	WHERE concept_code = 'OMOP898297';

	UPDATE drug_concept_stage
	SET concept_name = 'Agence Conseil'
	WHERE concept_code = 'OMOP440113';

	UPDATE drug_concept_stage
	SET concept_name = 'Agepha'
	WHERE concept_code = 'OMOP337876';

	UPDATE drug_concept_stage
	SET concept_name = 'Agfa'
	WHERE concept_code = 'OMOP440197';

	UPDATE drug_concept_stage
	SET concept_name = 'Aktiv'
	WHERE concept_code = 'OMOP897472';

	UPDATE drug_concept_stage
	SET concept_name = 'Alembic'
	WHERE concept_code = 'OMOP338847';

	UPDATE drug_concept_stage
	SET concept_name = 'Alexander-Apotheke Inhaber Anja Henkel'
	WHERE concept_code = 'OMOP897788';

	UPDATE drug_concept_stage
	SET concept_name = 'Alissa'
	WHERE concept_code = 'OMOP338699';

	UPDATE drug_concept_stage
	SET concept_name = 'Alkaloid-Int'
	WHERE concept_code = 'OMOP897758';

	UPDATE drug_concept_stage
	SET concept_name = 'All Star'
	WHERE concept_code = 'OMOP1018218';

	UPDATE drug_concept_stage
	SET concept_name = 'Allcura'
	WHERE concept_code = 'OMOP897812';

	UPDATE drug_concept_stage
	SET concept_name = 'Allens'
	WHERE concept_code = 'OMOP338994';

	UPDATE drug_concept_stage
	SET concept_name = 'Allgaeu Apotheke Inh Erich Pfister'
	WHERE concept_code = 'OMOP900467';

	UPDATE drug_concept_stage
	SET concept_name = 'Allgaeuer Heilmoor Ehrlich'
	WHERE concept_code = 'OMOP898952';

	UPDATE drug_concept_stage
	SET concept_name = 'Aloex'
	WHERE concept_code = 'OMOP1019328';

	UPDATE drug_concept_stage
	SET concept_name = 'Alpenlaendisches Kraeuterhaus'
	WHERE concept_code = 'OMOP898172';

	UPDATE drug_concept_stage
	SET concept_name = 'Alpenpharma'
	WHERE concept_code = 'OMOP898310';

	UPDATE drug_concept_stage
	SET concept_name = 'Alsi'
	WHERE concept_code = 'OMOP1018249';

	UPDATE drug_concept_stage
	SET concept_name = 'Alte Apotheke Beate & Ekkehard Dochtermann'
	WHERE concept_code = 'OMOP898625';

	UPDATE drug_concept_stage
	SET concept_name = 'Alte Apotheke Dieter Bueller'
	WHERE concept_code = 'OMOP899446';

	UPDATE drug_concept_stage
	SET concept_name = 'Alte Apotheke Dr Josef Knipp'
	WHERE concept_code = 'OMOP899937';

	UPDATE drug_concept_stage
	SET concept_name = 'Alte Apotheke Guenter Verres'
	WHERE concept_code = 'OMOP897437';

	UPDATE drug_concept_stage
	SET concept_name = 'Alte Apotheke In Rissen Kurt Moog'
	WHERE concept_code = 'OMOP900223';

	UPDATE drug_concept_stage
	SET concept_name = 'Alte Apotheke Sabine Francke'
	WHERE concept_code = 'OMOP900095';

	UPDATE drug_concept_stage
	SET concept_name = 'Alte Eilbeker Apotheke Nils Bomholt'
	WHERE concept_code = 'OMOP899152';

	UPDATE drug_concept_stage
	SET concept_name = 'Alte Stadt-Apotheke Hans-Juergen Schneider'
	WHERE concept_code = 'OMOP898175';

	UPDATE drug_concept_stage
	SET concept_name = 'Alter'
	WHERE concept_code = 'OMOP440184';

	UPDATE drug_concept_stage
	SET concept_name = 'Altstadt-Apotheke S Wimmer & W Praun'
	WHERE concept_code = 'OMOP899371';

	UPDATE drug_concept_stage
	SET concept_name = 'Alvogen Ipcor L'
	WHERE concept_code = 'OMOP898941';

	UPDATE drug_concept_stage
	SET concept_name = 'AME'
	WHERE concept_code = 'OMOP897995';

	UPDATE drug_concept_stage
	SET concept_name = 'Andreas-Apotheke Baerlehner & Seelentag'
	WHERE concept_code = 'OMOP897957';

	UPDATE drug_concept_stage
	SET concept_name = 'Anton Huebner'
	WHERE concept_code = 'OMOP898787';

	UPDATE drug_concept_stage
	SET concept_name = 'AOP'
	WHERE concept_code = 'OMOP440303';

	UPDATE drug_concept_stage
	SET concept_name = 'APC'
	WHERE concept_code = 'OMOP338977';

	UPDATE drug_concept_stage
	SET concept_name = 'APM'
	WHERE concept_code = 'OMOP1018267';

	UPDATE drug_concept_stage
	SET concept_name = 'Apoforte'
	WHERE concept_code = 'OMOP899013';

	UPDATE drug_concept_stage
	SET concept_name = 'Apollinaris Brands'
	WHERE concept_code = 'OMOP900030';

	UPDATE drug_concept_stage
	SET concept_name = 'Apothex'
	WHERE concept_code = 'OMOP898849';

	UPDATE drug_concept_stage
	SET concept_name = 'Aptevo'
	WHERE concept_code = 'OMOP1018284';

	UPDATE drug_concept_stage
	SET concept_name = 'Ardey Quelle'
	WHERE concept_code = 'OMOP898660';

	UPDATE drug_concept_stage
	SET concept_name = 'Arens Marien Apotheke Andreas Hebenstreit'
	WHERE concept_code = 'OMOP899168';

	UPDATE drug_concept_stage
	SET concept_name = 'Argonal'
	WHERE concept_code = 'OMOP1018303';

	UPDATE drug_concept_stage
	SET concept_name = 'Arjun'
	WHERE concept_code = 'OMOP338610';

	UPDATE drug_concept_stage
	SET concept_name = 'Arkomedika'
	WHERE concept_code = 'OMOP899199';

	UPDATE drug_concept_stage
	SET concept_name = 'Arnica-Apotheke Enno Peppmeierfm'
	WHERE concept_code = 'OMOP897719';

	UPDATE drug_concept_stage
	SET concept_name = 'Arnulf Apotheke Johann Thoma'
	WHERE concept_code = 'OMOP899097';

	UPDATE drug_concept_stage
	SET concept_name = 'Arzneimittel-Heilmittel-Diaetetika'
	WHERE concept_code = 'OMOP899959';

	UPDATE drug_concept_stage
	SET concept_name = 'Asconex'
	WHERE concept_code = 'OMOP2018322';

	UPDATE drug_concept_stage
	SET concept_name = 'AST'
	WHERE concept_code = 'OMOP1018300';

	UPDATE drug_concept_stage
	SET concept_name = 'Athenstaedt'
	WHERE concept_code = 'OMOP899622';

	UPDATE drug_concept_stage
	SET concept_name = 'Atlantic Multipower'
	WHERE concept_code = 'OMOP899512';

	UPDATE drug_concept_stage
	SET concept_name = 'Atlantis-Apotheke Wolfgang & Gisela Langenberg'
	WHERE concept_code = 'OMOP899411';

	UPDATE drug_concept_stage
	SET concept_name = 'Atlas Co'
	WHERE concept_code = 'OMOP1018311';

	UPDATE drug_concept_stage
	SET concept_name = 'Auden Mckenzie'
	WHERE concept_code = 'OMOP339527';

	UPDATE drug_concept_stage
	SET concept_name = 'Australian Bush Oil'
	WHERE concept_code = 'OMOP572437';

	UPDATE drug_concept_stage
	SET concept_name = 'Auvex'
	WHERE concept_code = 'OMOP440150';

	UPDATE drug_concept_stage
	SET concept_name = 'Avondale'
	WHERE concept_code = 'OMOP1018342';

	UPDATE drug_concept_stage
	SET concept_name = 'Azar Baradaran-Kazem Zadeh Galenus-Apotheke'
	WHERE concept_code = 'OMOP899408';

	UPDATE drug_concept_stage
	SET concept_name = 'Azevedos'
	WHERE concept_code = 'OMOP899880';

	UPDATE drug_concept_stage
	SET concept_name = 'Aziende Chimiche Riunite Angelini Sco'
	WHERE concept_code = 'OMOP338034';

	UPDATE drug_concept_stage
	SET concept_name = 'B F Ascher '
	WHERE concept_code = 'OMOP1018318';

	UPDATE drug_concept_stage
	SET concept_name = 'Basi'
	WHERE concept_code = 'OMOP899813';

	UPDATE drug_concept_stage
	SET concept_name = 'Basi Schoeberl'
	WHERE concept_code = 'OMOP898935';

	UPDATE drug_concept_stage
	SET concept_name = 'Basilea'
	WHERE concept_code = 'OMOP337947';

	UPDATE drug_concept_stage
	SET concept_name = 'Bastian'
	WHERE concept_code = 'OMOP900183';

	UPDATE drug_concept_stage
	SET concept_name = 'Bayard'
	WHERE concept_code = 'OMOP440269';

	UPDATE drug_concept_stage
	SET concept_name = 'Bee'
	WHERE concept_code = 'OMOP339160';

	UPDATE drug_concept_stage
	SET concept_name = 'Behany'
	WHERE concept_code = 'OMOP1018348';

	UPDATE drug_concept_stage
	SET concept_name = 'Behring'
	WHERE concept_code = 'OMOP1019553';

	UPDATE drug_concept_stage
	SET concept_name = 'Bene'
	WHERE concept_code = 'OMOP899796';

	UPDATE drug_concept_stage
	SET concept_name = 'Berco- Gottfried Herzberg'
	WHERE concept_code = 'OMOP900152';

	UPDATE drug_concept_stage
	SET concept_name = 'Betz"sche Apotheke Kurt Betz'
	WHERE concept_code = 'OMOP898580';

	UPDATE drug_concept_stage
	SET concept_name = 'BGP'
	WHERE concept_code = 'OMOP338465';

	UPDATE drug_concept_stage
	SET concept_name = 'Bieffe Medital'
	WHERE concept_code = 'OMOP899967';

	UPDATE drug_concept_stage
	SET concept_name = 'Billev'
	WHERE concept_code = 'OMOP897540';

	UPDATE drug_concept_stage
	SET concept_name = 'Bindergass-Apotheke'
	WHERE concept_code = 'OMOP899665';

	UPDATE drug_concept_stage
	SET concept_name = 'Bio Breizh'
	WHERE concept_code = 'OMOP1018420';

	UPDATE drug_concept_stage
	SET concept_name = 'Bio Oil'
	WHERE concept_code = 'OMOP1018421';

	UPDATE drug_concept_stage
	SET concept_name = 'Bio Products'
	WHERE concept_code = 'OMOP337883';

	UPDATE drug_concept_stage
	SET concept_name = 'Bio-Diaet-Berlin'
	WHERE concept_code = 'OMOP900239';

	UPDATE drug_concept_stage
	SET concept_name = 'Biokirch'
	WHERE concept_code = 'OMOP898593';

	UPDATE drug_concept_stage
	SET concept_name = 'Biokosma'
	WHERE concept_code = 'OMOP1018396';

	UPDATE drug_concept_stage
	SET concept_name = 'Biological Homeopathic'
	WHERE concept_code = 'OMOP1018397';

	UPDATE drug_concept_stage
	SET concept_name = 'Biomendi'
	WHERE concept_code = 'OMOP897608';

	UPDATE drug_concept_stage
	SET concept_name = 'Bionorica'
	WHERE concept_code = 'OMOP899944';

	UPDATE drug_concept_stage
	SET concept_name = 'Birnbaum-Apotheke Dr Claus Gernet'
	WHERE concept_code = 'OMOP898490';

	UPDATE drug_concept_stage
	SET concept_name = 'Bischoff'
	WHERE concept_code = 'OMOP2018390';

	UPDATE drug_concept_stage
	SET concept_name = 'Biscova'
	WHERE concept_code = 'OMOP900444';

	UPDATE drug_concept_stage
	SET concept_name = 'Bittermedizin'
	WHERE concept_code = 'OMOP898837';

	UPDATE drug_concept_stage
	SET concept_name = 'Bles'
	WHERE concept_code = 'OMOP1018370';

	UPDATE drug_concept_stage
	SET concept_name = 'Bluecher-Schering'
	WHERE concept_code = 'OMOP898539';

	UPDATE drug_concept_stage
	SET concept_name = 'BMG'
	WHERE concept_code = 'OMOP1019013';

	UPDATE drug_concept_stage
	SET concept_name = 'Boettger'
	WHERE concept_code = 'OMOP899729';

	UPDATE drug_concept_stage
	SET concept_name = 'Bohumil'
	WHERE concept_code = 'OMOP439996';

	UPDATE drug_concept_stage
	SET concept_name = 'Boxo'
	WHERE concept_code = 'OMOP899723';

	UPDATE drug_concept_stage
	SET concept_name = 'Brahms-Apotheke Eckart & Ilse Volke'
	WHERE concept_code = 'OMOP897913';

	UPDATE drug_concept_stage
	SET concept_name = 'Buckley"s'
	WHERE concept_code = 'OMOP1019673';

	UPDATE drug_concept_stage
	SET concept_name = 'C.D.'
	WHERE concept_code = 'OMOP2018374';

	UPDATE drug_concept_stage
	SET concept_name = 'C.P.'
	WHERE concept_code = 'OMOP339405';

	UPDATE drug_concept_stage
	SET concept_name = 'C.P.M.'
	WHERE concept_code = 'OMOP898357';

	UPDATE drug_concept_stage
	SET concept_name = 'Cabot'
	WHERE concept_code = 'OMOP440411';

	UPDATE drug_concept_stage
	SET concept_name = 'Cadillac'
	WHERE concept_code = 'OMOP1019329';

	UPDATE drug_concept_stage
	SET concept_name = 'Calcorp 55'
	WHERE concept_code = 'OMOP1018443';

	UPDATE drug_concept_stage
	SET concept_name = 'Canea'
	WHERE concept_code = 'OMOP897747';

	UPDATE drug_concept_stage
	SET concept_name = 'Cantassium'
	WHERE concept_code = 'OMOP337895';

	UPDATE drug_concept_stage
	SET concept_name = 'Cardinal'
	WHERE concept_code = 'OMOP1018457';

	UPDATE drug_concept_stage
	SET concept_name = 'Carl-Schurz-Apotheke Eva & Sabine Knoll'
	WHERE concept_code = 'OMOP899390';

	UPDATE drug_concept_stage
	SET concept_name = 'Carmaran'
	WHERE concept_code = 'OMOP1018465';

	UPDATE drug_concept_stage
	SET concept_name = 'Cascan'
	WHERE concept_code = 'OMOP899430';

	UPDATE drug_concept_stage
	SET concept_name = 'Casen Recordati'
	WHERE concept_code = 'OMOP338684';

	UPDATE drug_concept_stage
	SET concept_name = 'Cassella-Med'
	WHERE concept_code = 'OMOP897422';

	UPDATE drug_concept_stage
	SET concept_name = 'Cathapham'
	WHERE concept_code = 'OMOP898759';

	UPDATE drug_concept_stage
	SET concept_name = 'CCA'
	WHERE concept_code = 'OMOP1018455';

	UPDATE drug_concept_stage
	SET concept_name = 'Cd'
	WHERE concept_code = 'OMOP337853';

	UPDATE drug_concept_stage
	SET concept_name = 'Cedona'
	WHERE concept_code = 'OMOP1018456';

	UPDATE drug_concept_stage
	SET concept_name = 'Cefak'
	WHERE concept_code = 'OMOP899365';

	UPDATE drug_concept_stage
	SET concept_name = 'Cellex'
	WHERE concept_code = 'OMOP900072';

	UPDATE drug_concept_stage
	SET concept_name = 'Celltrion'
	WHERE concept_code = 'OMOP1018695';

	UPDATE drug_concept_stage
	SET concept_name = 'Cetylite'
	WHERE concept_code = 'OMOP1018705';

	UPDATE drug_concept_stage
	SET concept_name = 'Challenge'
	WHERE concept_code = 'OMOP1018706';

	UPDATE drug_concept_stage
	SET concept_name = 'Charton'
	WHERE concept_code = 'OMOP1019026';

	UPDATE drug_concept_stage
	SET concept_name = 'Chem Affairs Deutschland'
	WHERE concept_code = 'OMOP898127';

	UPDATE drug_concept_stage
	SET concept_name = 'Chemo Iberica Barcelona'
	WHERE concept_code = 'OMOP897876';

	UPDATE drug_concept_stage
	SET concept_name = 'Chephasaar'
	WHERE concept_code = 'OMOP897883';

	UPDATE drug_concept_stage
	SET concept_name = 'Commerce Pharmaceutics'
	WHERE concept_code = 'OMOP1018749';

	UPDATE drug_concept_stage
	SET concept_name = 'Confab'
	WHERE concept_code = 'OMOP1019027';

	UPDATE drug_concept_stage
	SET concept_name = 'Consilient'
	WHERE concept_code = 'OMOP338172';

	UPDATE drug_concept_stage
	SET concept_name = 'Coralite'
	WHERE concept_code = 'OMOP1018774';

	UPDATE drug_concept_stage
	SET concept_name = 'Corden'
	WHERE concept_code = 'OMOP898038';

	UPDATE drug_concept_stage
	SET concept_name = 'Cormontapharm'
	WHERE concept_code = 'OMOP898590';

	UPDATE drug_concept_stage
	SET concept_name = 'Cortunon'
	WHERE concept_code = 'OMOP1019028';

	UPDATE drug_concept_stage
	SET concept_name = 'Country'
	WHERE concept_code = 'OMOP1018701';

	UPDATE drug_concept_stage
	SET concept_name = 'Croma'
	WHERE concept_code = 'OMOP2018425';

	UPDATE drug_concept_stage
	SET concept_name = 'Crucell'
	WHERE concept_code = 'OMOP899357';

	UPDATE drug_concept_stage
	SET concept_name = 'CTRS'
	WHERE concept_code = 'OMOP338414';

	UPDATE drug_concept_stage
	SET concept_name = 'Cusanus-Apotheke Sarah Sauer'
	WHERE concept_code = 'OMOP899949';

	UPDATE drug_concept_stage
	SET concept_name = 'Cuxson Gerrard'
	WHERE concept_code = 'OMOP1018744';

	UPDATE drug_concept_stage
	SET concept_name = 'Cyathus Exquirere'
	WHERE concept_code = 'OMOP900310';

	UPDATE drug_concept_stage
	SET concept_name = 'Cyndea'
	WHERE concept_code = 'OMOP898743';

	UPDATE drug_concept_stage
	SET concept_name = 'D.A.V.I.D.'
	WHERE concept_code = 'OMOP898429';

	UPDATE drug_concept_stage
	SET concept_name = 'D.C.'
	WHERE concept_code = 'OMOP1018763';

	UPDATE drug_concept_stage
	SET concept_name = 'Dana'
	WHERE concept_code = 'OMOP1018769';

	UPDATE drug_concept_stage
	SET concept_name = 'Dauner Sprudel O Hommes'
	WHERE concept_code = 'OMOP898892';

	UPDATE drug_concept_stage
	SET concept_name = 'Debregeas'
	WHERE concept_code = 'OMOP440467';

	UPDATE drug_concept_stage
	SET concept_name = 'Decleor'
	WHERE concept_code = 'OMOP1019029';

	UPDATE drug_concept_stage
	SET concept_name = 'Defiante Sa'
	WHERE concept_code = 'OMOP440119';

	UPDATE drug_concept_stage
	SET concept_name = 'Del'
	WHERE concept_code = 'OMOP1018667';

	UPDATE drug_concept_stage
	SET concept_name = 'Delbert'
	WHERE concept_code = 'OMOP439840';

	UPDATE drug_concept_stage
	SET concept_name = 'Delon'
	WHERE concept_code = 'OMOP1019030';

	UPDATE drug_concept_stage
	SET concept_name = 'Delphin-Apotheke Ruediger Becker'
	WHERE concept_code = 'OMOP897652';

	UPDATE drug_concept_stage
	SET concept_name = 'Demo'
	WHERE concept_code = 'OMOP899213';

	UPDATE drug_concept_stage
	SET concept_name = 'Denorex'
	WHERE concept_code = 'OMOP1019675';

	UPDATE drug_concept_stage
	SET concept_name = 'Dental Health'
	WHERE concept_code = 'OMOP338245';

	UPDATE drug_concept_stage
	SET concept_name = 'Dermo-Cosmetik'
	WHERE concept_code = 'OMOP1019031';

	UPDATE drug_concept_stage
	SET concept_name = 'Desbergers'
	WHERE concept_code = 'OMOP1018675';

	UPDATE drug_concept_stage
	SET concept_name = 'Desomed Dr Trippen'
	WHERE concept_code = 'OMOP898424';

	UPDATE drug_concept_stage
	SET concept_name = 'Deutsche Homoeopathie-Union Dhu'
	WHERE concept_code = 'OMOP897882';

	UPDATE drug_concept_stage
	SET concept_name = 'Diamed'
	WHERE concept_code = 'OMOP900236';

	UPDATE drug_concept_stage
	SET concept_name = 'Diamo'
	WHERE concept_code = 'OMOP899346';

	UPDATE drug_concept_stage
	SET concept_name = 'Dibropharm Distribution'
	WHERE concept_code = 'OMOP899312';

	UPDATE drug_concept_stage
	SET concept_name = 'Die Renchtal-Apotheke Rainer Fettig'
	WHERE concept_code = 'OMOP900066';

	UPDATE drug_concept_stage
	SET concept_name = 'Die Thor-Apotheke Sylvia Thorwarth'
	WHERE concept_code = 'OMOP898733';

	UPDATE drug_concept_stage
	SET concept_name = 'Disphar'
	WHERE concept_code = 'OMOP900249';

	UPDATE drug_concept_stage
	SET concept_name = 'Dm-Drogerie Markt'
	WHERE concept_code = 'OMOP897833';

	UPDATE drug_concept_stage
	SET concept_name = 'Docmorris Apotheke Bad Hersfeldfrkia Hildwein'
	WHERE concept_code = 'OMOP898621';

	UPDATE drug_concept_stage
	SET concept_name = 'Docpharm'
	WHERE concept_code = 'OMOP897483';

	UPDATE drug_concept_stage
	SET concept_name = 'Doliage'
	WHERE concept_code = 'OMOP440174';

	UPDATE drug_concept_stage
	SET concept_name = 'Donovan'
	WHERE concept_code = 'OMOP1018689';

	UPDATE drug_concept_stage
	SET concept_name = 'Dotopharma'
	WHERE concept_code = 'OMOP897464';

	UPDATE drug_concept_stage
	SET concept_name = 'Dovital'
	WHERE concept_code = 'OMOP900270';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr B Scheffler'
	WHERE concept_code = 'OMOP898458';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Behre'
	WHERE concept_code = 'OMOP899309';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Blasberg-Apotheke Dr Matthias Grundmann'
	WHERE concept_code = 'OMOP898639';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Daniel'
	WHERE concept_code = 'OMOP1018565';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Deppe'
	WHERE concept_code = 'OMOP898451';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Die Neue Apotheke'
	WHERE concept_code = 'OMOP897577';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Karl Thomae'
	WHERE concept_code = 'OMOP897504';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Felgentraeger Oeko-Chem'
	WHERE concept_code = 'OMOP899627';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Franz Koehler Chemie Mit Beschraenkter'
	WHERE concept_code = 'OMOP899467';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Friedrichse'
	WHERE concept_code = 'OMOP899409';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Gerhard Mann'
	WHERE concept_code = 'OMOP897500';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Kuhns Apotheke Dr Arne Kuhn'
	WHERE concept_code = 'OMOP900013';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Loges'
	WHERE concept_code = 'OMOP897631';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Marien-Apothekefm'
	WHERE concept_code = 'OMOP899081';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Markt-Apotheke 24'
	WHERE concept_code = 'OMOP897439';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Med Mainz'
	WHERE concept_code = 'OMOP899023';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Poehlmann'
	WHERE concept_code = 'OMOP900334';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr R Pfleger'
	WHERE concept_code = 'OMOP897364';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Ritsert'
	WHERE concept_code = 'OMOP898212';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Rosen Apotheke'
	WHERE concept_code = 'OMOP898027';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Roshdy Ismail'
	WHERE concept_code = 'OMOP899384';

	UPDATE drug_concept_stage
	SET concept_name = 'Dr Stadt-Apotheke'
	WHERE concept_code = 'OMOP899140';

	UPDATE drug_concept_stage
	SET concept_name = 'Dreisessel-Apotheke'
	WHERE concept_code = 'OMOP898389';

	UPDATE drug_concept_stage
	SET concept_name = 'DRK-Blutspendedienst Baden-Wuerttemberg-Hessen'
	WHERE concept_code = 'OMOP900192';

	UPDATE drug_concept_stage
	SET concept_name = 'Drossapharm'
	WHERE concept_code = 'OMOP900006';

	UPDATE drug_concept_stage
	SET concept_name = 'Drula'
	WHERE concept_code = 'OMOP1018572';

	UPDATE drug_concept_stage
	SET concept_name = 'Dtr Dermal Therapy'
	WHERE concept_code = 'OMOP1018578';

	UPDATE drug_concept_stage
	SET concept_name = 'Dustbane'
	WHERE concept_code = 'OMOP1018591';

	UPDATE drug_concept_stage
	SET concept_name = 'Dutch Ophthalmic'
	WHERE concept_code = 'OMOP1018592';

	UPDATE drug_concept_stage
	SET concept_name = 'Dyckerhoff'
	WHERE concept_code = 'OMOP900446';

	UPDATE drug_concept_stage
	SET concept_name = 'Dymatize'
	WHERE concept_code = 'OMOP1018593';

	UPDATE drug_concept_stage
	SET concept_name = 'E.R.I.'
	WHERE concept_code = 'OMOP1018605';

	UPDATE drug_concept_stage
	SET concept_name = 'Easy Motion'
	WHERE concept_code = 'OMOP1018609';

	UPDATE drug_concept_stage
	SET concept_name = 'Easyapotheke'
	WHERE concept_code = 'OMOP897406';

	UPDATE drug_concept_stage
	SET concept_name = 'Eduard Gerlach'
	WHERE concept_code = 'OMOP898066';

	UPDATE drug_concept_stage
	SET concept_name = 'Edwards'
	WHERE concept_code = 'OMOP1018626';

	UPDATE drug_concept_stage
	SET concept_name = 'Efamol'
	WHERE concept_code = 'OMOP1018627';

	UPDATE drug_concept_stage
	SET concept_name = 'Eichendorff Apotheke Patric Sengfm'
	WHERE concept_code = 'OMOP898648';

	UPDATE drug_concept_stage
	SET concept_name = 'Eimsbuetteler-Apotheke'
	WHERE concept_code = 'OMOP900285';

	UPDATE drug_concept_stage
	SET concept_name = 'EKR'
	WHERE concept_code = 'OMOP1018629';

	UPDATE drug_concept_stage
	SET concept_name = 'Elasten'
	WHERE concept_code = 'OMOP897296';

	UPDATE drug_concept_stage
	SET concept_name = 'Elc Group'
	WHERE concept_code = 'OMOP898926';

	UPDATE drug_concept_stage
	SET concept_name = 'Elpen'
	WHERE concept_code = 'OMOP898786';

	UPDATE drug_concept_stage
	SET concept_name = 'Elsass-Apotheke Luecker'
	WHERE concept_code = 'OMOP898267';

	UPDATE drug_concept_stage
	SET concept_name = 'Emasdi'
	WHERE concept_code = 'OMOP897469';

	UPDATE drug_concept_stage
	SET concept_name = 'Emergent Sales And Marketing'
	WHERE concept_code = 'OMOP899679';

	UPDATE drug_concept_stage
	SET concept_name = 'Emu Man L C'
	WHERE concept_code = 'OMOP1019676';

	UPDATE drug_concept_stage
	SET concept_name = 'Engarde'
	WHERE concept_code = 'OMOP1018475';

	UPDATE drug_concept_stage
	SET concept_name = 'Engelhard'
	WHERE concept_code = 'OMOP898631';

	UPDATE drug_concept_stage
	SET concept_name = 'Ernest Jackson'
	WHERE concept_code = 'OMOP338199';

	UPDATE drug_concept_stage
	SET concept_name = 'Espen-Apotheke Gundhilt Mueller'
	WHERE concept_code = 'OMOP900213';

	UPDATE drug_concept_stage
	SET concept_name = 'Ester-C'
	WHERE concept_code = 'OMOP1018601';

	UPDATE drug_concept_stage
	SET concept_name = 'Eu Rho'
	WHERE concept_code = 'OMOP899651';

	UPDATE drug_concept_stage
	SET concept_name = 'Euro-Apotheke Eurapon'
	WHERE concept_code = 'OMOP899251';

	UPDATE drug_concept_stage
	SET concept_name = 'Eurogenerics'
	WHERE concept_code = 'OMOP439862';

	UPDATE drug_concept_stage
	SET concept_name = 'Evepacks'
	WHERE concept_code = 'OMOP900055';

	UPDATE drug_concept_stage
	SET concept_name = 'Exeltis'
	WHERE concept_code = 'OMOP898491';

	UPDATE drug_concept_stage
	SET concept_name = 'F Maltby'
	WHERE concept_code = 'OMOP338835';

	UPDATE drug_concept_stage
	SET concept_name = 'Farmaryn'
	WHERE concept_code = 'OMOP898695';

	UPDATE drug_concept_stage
	SET concept_name = 'Farmigea'
	WHERE concept_code = 'OMOP339522';

	UPDATE drug_concept_stage
	SET concept_name = 'Ferrer'
	WHERE concept_code = 'OMOP439931';

	UPDATE drug_concept_stage
	SET concept_name = 'FGK'
	WHERE concept_code = 'OMOP899136';

	UPDATE drug_concept_stage
	SET concept_name = 'Fides'
	WHERE concept_code = 'OMOP899970';

	UPDATE drug_concept_stage
	SET concept_name = 'Fitne Gesundheits Und Wellness'
	WHERE concept_code = 'OMOP900471';

	UPDATE drug_concept_stage
	SET concept_name = 'Flora-Apotheke Dr Bernhard Cuntze'
	WHERE concept_code = 'OMOP898225';

	UPDATE drug_concept_stage
	SET concept_name = 'Fontus'
	WHERE concept_code = 'OMOP337973';

	UPDATE drug_concept_stage
	SET concept_name = 'Fournier S'
	WHERE concept_code = 'OMOP1019032';

	UPDATE drug_concept_stage
	SET concept_name = 'Frank W Kerr'
	WHERE concept_code = 'OMOP1018619';

	UPDATE drug_concept_stage
	SET concept_name = 'Franken Brunnen'
	WHERE concept_code = 'OMOP898058';

	UPDATE drug_concept_stage
	SET concept_name = 'Frank"s'
	WHERE concept_code = 'OMOP1018620';

	UPDATE drug_concept_stage
	SET concept_name = 'Freesen-Apotheke Petra Engel'
	WHERE concept_code = 'OMOP899749';

	UPDATE drug_concept_stage
	SET concept_name = 'Friedrich Kremer Jr Inh Hans Kremer'
	WHERE concept_code = 'OMOP900008';

	UPDATE drug_concept_stage
	SET concept_name = 'Fritz Oskar Michallik'
	WHERE concept_code = 'OMOP900245';

	UPDATE drug_concept_stage
	SET concept_name = 'Friulchem'
	WHERE concept_code = 'OMOP899958';

	UPDATE drug_concept_stage
	SET concept_name = 'Fujisawa'
	WHERE concept_code = 'OMOP1018633';

	UPDATE drug_concept_stage
	SET concept_name = 'Fuller Brush'
	WHERE concept_code = 'OMOP1018634';

	UPDATE drug_concept_stage
	SET concept_name = 'G & G Food'
	WHERE concept_code = 'OMOP338808';

	UPDATE drug_concept_stage
	SET concept_name = 'G.A.'
	WHERE concept_code = 'OMOP900031';

	UPDATE drug_concept_stage
	SET concept_name = 'G.E.S.'
	WHERE concept_code = 'OMOP900255';

	UPDATE drug_concept_stage
	SET concept_name = 'G.L.'
	WHERE concept_code = 'OMOP898333';

	UPDATE drug_concept_stage
	SET concept_name = 'G2D'
	WHERE concept_code = 'OMOP440396';

	UPDATE drug_concept_stage
	SET concept_name = 'Galenica'
	WHERE concept_code = 'OMOP899942';

	UPDATE drug_concept_stage
	SET concept_name = 'Galenicum'
	WHERE concept_code = 'OMOP897562';

	UPDATE drug_concept_stage
	SET concept_name = 'GDS'
	WHERE concept_code = 'OMOP2018500';

	UPDATE drug_concept_stage
	SET concept_name = 'Gebr Waaning-Tilly'
	WHERE concept_code = 'OMOP899700';

	UPDATE drug_concept_stage
	SET concept_name = 'Geiser'
	WHERE concept_code = 'OMOP898649';

	UPDATE drug_concept_stage
	SET concept_name = 'Genericon'
	WHERE concept_code = 'OMOP900438';

	UPDATE drug_concept_stage
	SET concept_name = 'Genfarma'
	WHERE concept_code = 'OMOP898020';

	UPDATE drug_concept_stage
	SET concept_name = 'Genius- Apotheke'
	WHERE concept_code = 'OMOP898586';

	UPDATE drug_concept_stage
	SET concept_name = 'Genpharm'
	WHERE concept_code = 'OMOP1018500';

	UPDATE drug_concept_stage
	SET concept_name = 'Genzyme'
	WHERE concept_code = 'OMOP337872';

	UPDATE drug_concept_stage
	SET concept_name = 'Gerd Rehme Apotheke Am Behnhaus'
	WHERE concept_code = 'OMOP899362';

	UPDATE drug_concept_stage
	SET concept_name = 'Gerda'
	WHERE concept_code = 'OMOP440064';

	UPDATE drug_concept_stage
	SET concept_name = 'Gernetic'
	WHERE concept_code = 'OMOP1019015';

	UPDATE drug_concept_stage
	SET concept_name = 'Geschwister Popp & Goldmann'
	WHERE concept_code = 'OMOP899262';

	UPDATE drug_concept_stage
	SET concept_name = 'Geymonat'
	WHERE concept_code = 'OMOP900020';

	UPDATE drug_concept_stage
	SET concept_name = 'Gingi-Pak'
	WHERE concept_code = 'OMOP1018508';

	UPDATE drug_concept_stage
	SET concept_name = 'Giovanni Lorenzini'
	WHERE concept_code = 'OMOP899417';

	UPDATE drug_concept_stage
	SET concept_name = 'Gojo'
	WHERE concept_code = 'OMOP1018519';

	UPDATE drug_concept_stage
	SET concept_name = 'Good Oil'
	WHERE concept_code = 'OMOP572456';

	UPDATE drug_concept_stage
	SET concept_name = 'Gothaplast'
	WHERE concept_code = 'OMOP900357';

	UPDATE drug_concept_stage
	SET concept_name = 'Graham'
	WHERE concept_code = 'OMOP1018528';

	UPDATE drug_concept_stage
	SET concept_name = 'Graichen Produktions'
	WHERE concept_code = 'OMOP899414';

	UPDATE drug_concept_stage
	SET concept_name = 'Green'
	WHERE concept_code = 'OMOP1018531';

	UPDATE drug_concept_stage
	SET concept_name = 'Green Medicine'
	WHERE concept_code = 'OMOP1019677';

	UPDATE drug_concept_stage
	SET concept_name = 'Grunitz'
	WHERE concept_code = 'OMOP1018561';

	UPDATE drug_concept_stage
	SET concept_name = 'GSE'
	WHERE concept_code = 'OMOP2018519';

	UPDATE drug_concept_stage
	SET concept_name = 'H C Stark'
	WHERE concept_code = 'OMOP898402';

	UPDATE drug_concept_stage
	SET concept_name = 'H.J. Sutton'
	WHERE concept_code = 'OMOP1018540';

	UPDATE drug_concept_stage
	SET concept_name = 'Hager & Werken'
	WHERE concept_code = 'OMOP900053';

	UPDATE drug_concept_stage
	SET concept_name = 'Hair Cosmetics'
	WHERE concept_code = 'OMOP1018228';

	UPDATE drug_concept_stage
	SET concept_name = 'Hannemarie Brandt'
	WHERE concept_code = 'OMOP900395';

	UPDATE drug_concept_stage
	SET concept_name = 'Haupt Ag'
	WHERE concept_code = 'OMOP899255';

	UPDATE drug_concept_stage
	SET concept_name = 'Haus Schaeben'
	WHERE concept_code = 'OMOP900156';

	UPDATE drug_concept_stage
	SET concept_name = 'HBM'
	WHERE concept_code = 'OMOP899631';

	UPDATE drug_concept_stage
	SET concept_name = 'Health 4 All'
	WHERE concept_code = 'OMOP1018548';

	UPDATE drug_concept_stage
	SET concept_name = 'Health Way'
	WHERE concept_code = 'OMOP1018552';

	UPDATE drug_concept_stage
	SET concept_name = 'Healthcare Sales & Service'
	WHERE concept_code = 'OMOP339068';

	UPDATE drug_concept_stage
	SET concept_name = 'Heilbad Bad Neuenahr-Ahrweiler'
	WHERE concept_code = 'OMOP900384';

	UPDATE drug_concept_stage
	SET concept_name = 'Heinrich Klenk'
	WHERE concept_code = 'OMOP898908';

	UPDATE drug_concept_stage
	SET concept_name = 'Heinrich Kleppe'
	WHERE concept_code = 'OMOP900459';

	UPDATE drug_concept_stage
	SET concept_name = 'Heinrich Mickan'
	WHERE concept_code = 'OMOP899728';

	UPDATE drug_concept_stage
	SET concept_name = 'Heinrich-Heine-Apotheke Alexandra Tscheuschner'
	WHERE concept_code = 'OMOP897565';

	UPDATE drug_concept_stage
	SET concept_name = 'Helenen-Apotheke Dr Rer Nat Guenter Lang'
	WHERE concept_code = 'OMOP899003';

	UPDATE drug_concept_stage
	SET concept_name = 'Henkel Agaa'
	WHERE concept_code = 'OMOP899137';

	UPDATE drug_concept_stage
	SET concept_name = 'Herbages Naturbec'
	WHERE concept_code = 'OMOP1018556';

	UPDATE drug_concept_stage
	SET concept_name = 'Herbalist & Doc'
	WHERE concept_code = 'OMOP897770';

	UPDATE drug_concept_stage
	SET concept_name = 'Herbrand'
	WHERE concept_code = 'OMOP898314';

	UPDATE drug_concept_stage
	SET concept_name = 'Herzogen-Apotheke Sabina Van Dornick'
	WHERE concept_code = 'OMOP899664';

	UPDATE drug_concept_stage
	SET concept_name = 'Heumann'
	WHERE concept_code = 'OMOP899775';

	UPDATE drug_concept_stage
	SET concept_name = 'Hevert'
	WHERE concept_code = 'OMOP900091';

	UPDATE drug_concept_stage
	SET concept_name = 'HFC Prestige'
	WHERE concept_code = 'OMOP1019135';

	UPDATE drug_concept_stage
	SET concept_name = 'Hi-Ga'
	WHERE concept_code = 'OMOP1019148';

	UPDATE drug_concept_stage
	SET concept_name = 'High'
	WHERE concept_code = 'OMOP1019149';

	UPDATE drug_concept_stage
	SET concept_name = 'Highcrest'
	WHERE concept_code = 'OMOP1019150';

	UPDATE drug_concept_stage
	SET concept_name = 'Hilary"s'
	WHERE concept_code = 'OMOP1019151';

	UPDATE drug_concept_stage
	SET concept_name = 'Hipp'
	WHERE concept_code = 'OMOP899260';

	UPDATE drug_concept_stage
	SET concept_name = 'Hirundo'
	WHERE concept_code = 'OMOP2018567';

	UPDATE drug_concept_stage
	SET concept_name = 'HLS'
	WHERE concept_code = 'OMOP1019156';

	UPDATE drug_concept_stage
	SET concept_name = 'Holistic'
	WHERE concept_code = 'OMOP1019161';

	UPDATE drug_concept_stage
	SET concept_name = 'Horizon'
	WHERE concept_code = 'OMOP1018962';

	UPDATE drug_concept_stage
	SET concept_name = 'Hormosan'
	WHERE concept_code = 'OMOP897339';

	UPDATE drug_concept_stage
	SET concept_name = 'Hospal'
	WHERE concept_code = 'OMOP898256';

	UPDATE drug_concept_stage
	SET concept_name = 'Houbigant'
	WHERE concept_code = 'OMOP1018984';

	UPDATE drug_concept_stage
	SET concept_name = 'Humanus'
	WHERE concept_code = 'OMOP2018547';

	UPDATE drug_concept_stage
	SET concept_name = 'Hunza'
	WHERE concept_code = 'OMOP338496';

	UPDATE drug_concept_stage
	SET concept_name = 'Hustadt-Apotheke Dietmar Streit'
	WHERE concept_code = 'OMOP899090';

	UPDATE drug_concept_stage
	SET concept_name = 'HWI Analytik'
	WHERE concept_code = 'OMOP898464';

	UPDATE drug_concept_stage
	SET concept_name = 'I.B.'
	WHERE concept_code = 'OMOP898694';

	UPDATE drug_concept_stage
	SET concept_name = 'I.S.N.'
	WHERE concept_code = 'OMOP900179';

	UPDATE drug_concept_stage
	SET concept_name = 'Ibigen '
	WHERE concept_code = 'OMOP899025';

	UPDATE drug_concept_stage
	SET concept_name = 'ID bio'
	WHERE concept_code = 'OMOP1019189';

	UPDATE drug_concept_stage
	SET concept_name = 'IDD'
	WHERE concept_code = 'OMOP899396';

	UPDATE drug_concept_stage
	SET concept_name = 'Idelle'
	WHERE concept_code = 'OMOP1019190';

	UPDATE drug_concept_stage
	SET concept_name = 'IDL'
	WHERE concept_code = 'OMOP440280';

	UPDATE drug_concept_stage
	SET concept_name = 'IHN-Allaire'
	WHERE concept_code = 'OMOP1018968';

	UPDATE drug_concept_stage
	SET concept_name = 'IIP-Institut'
	WHERE concept_code = 'OMOP898848';

	UPDATE drug_concept_stage
	SET concept_name = 'I-Med'
	WHERE concept_code = 'OMOP899862';

	UPDATE drug_concept_stage
	SET concept_name = 'IMG Institut'
	WHERE concept_code = 'OMOP899361';

	UPDATE drug_concept_stage
	SET concept_name = 'Impuls'
	WHERE concept_code = 'OMOP2018740';

	UPDATE drug_concept_stage
	SET concept_name = 'Incyte'
	WHERE concept_code = 'OMOP1140334';

	UPDATE drug_concept_stage
	SET concept_name = 'Infectopharm'
	WHERE concept_code = 'OMOP897767';

	UPDATE drug_concept_stage
	SET concept_name = 'Inn-Farm'
	WHERE concept_code = 'OMOP898007';

	UPDATE drug_concept_stage
	SET concept_name = 'Innovapharm'
	WHERE concept_code = 'OMOP899604';

	UPDATE drug_concept_stage
	SET concept_name = 'INO'
	WHERE concept_code = 'OMOP1018987';

	UPDATE drug_concept_stage
	SET concept_name = 'Inter Pharm'
	WHERE concept_code = 'OMOP2018575';

	UPDATE drug_concept_stage
	SET concept_name = 'Interdos'
	WHERE concept_code = 'OMOP899123';

	UPDATE drug_concept_stage
	SET concept_name = 'International Medication Systems'
	WHERE concept_code = 'OMOP337798';

	UPDATE drug_concept_stage
	SET concept_name = 'Invent Farma'
	WHERE concept_code = 'OMOP898866';

	UPDATE drug_concept_stage
	SET concept_name = 'Inverma Johannes Lange'
	WHERE concept_code = 'OMOP898455';

	UPDATE drug_concept_stage
	SET concept_name = 'Iovate'
	WHERE concept_code = 'OMOP1019168';

	UPDATE drug_concept_stage
	SET concept_name = 'IPP'
	WHERE concept_code = 'OMOP897924';

	UPDATE drug_concept_stage
	SET concept_name = 'IPS'
	WHERE concept_code = 'OMOP338599';

	UPDATE drug_concept_stage
	SET concept_name = 'Iroko'
	WHERE concept_code = 'OMOP440366';

	UPDATE drug_concept_stage
	SET concept_name = 'Isis'
	WHERE concept_code = 'OMOP338975';

	UPDATE drug_concept_stage
	SET concept_name = 'Ispex'
	WHERE concept_code = 'OMOP899889';

	UPDATE drug_concept_stage
	SET concept_name = 'IVC'
	WHERE concept_code = 'OMOP1019213';

	UPDATE drug_concept_stage
	SET concept_name = 'J Carl Pflueger'
	WHERE concept_code = 'OMOP898087';

	UPDATE drug_concept_stage
	SET concept_name = 'J L Mathieu'
	WHERE concept_code = 'OMOP1019215';

	UPDATE drug_concept_stage
	SET concept_name = 'Jadran Galenski Laboratorij D D'
	WHERE concept_code = 'OMOP899915';

	UPDATE drug_concept_stage
	SET concept_name = 'Jan Marini'
	WHERE concept_code = 'OMOP1019169';

	UPDATE drug_concept_stage
	SET concept_name = 'Jane'
	WHERE concept_code = 'OMOP1019170';

	UPDATE drug_concept_stage
	SET concept_name = 'Jazz'
	WHERE concept_code = 'OMOP1019172';

	UPDATE drug_concept_stage
	SET concept_name = 'Jedmon'
	WHERE concept_code = 'OMOP1019174';

	UPDATE drug_concept_stage
	SET concept_name = 'Jenson'
	WHERE concept_code = 'OMOP899196';

	UPDATE drug_concept_stage
	SET concept_name = 'Jr Carlson'
	WHERE concept_code = 'OMOP1019180';

	UPDATE drug_concept_stage
	SET concept_name = 'Jubilant'
	WHERE concept_code = 'OMOP897378';

	UPDATE drug_concept_stage
	SET concept_name = 'Jura Gollwitzer'
	WHERE concept_code = 'OMOP900141';

	UPDATE drug_concept_stage
	SET concept_name = 'Juvise'
	WHERE concept_code = 'OMOP440440';

	UPDATE drug_concept_stage
	SET concept_name = 'Kabi'
	WHERE concept_code = 'OMOP1019187';

	UPDATE drug_concept_stage
	SET concept_name = 'Kabivitrum'
	WHERE concept_code = 'OMOP2018607';

	UPDATE drug_concept_stage
	SET concept_name = 'Kao'
	WHERE concept_code = 'OMOP1019204';

	UPDATE drug_concept_stage
	SET concept_name = 'Karmed'
	WHERE concept_code = 'OMOP899891';

	UPDATE drug_concept_stage
	SET concept_name = 'Kedrion'
	WHERE concept_code = 'OMOP899873';

	UPDATE drug_concept_stage
	SET concept_name = 'Kerastase'
	WHERE concept_code = 'OMOP1019223';

	UPDATE drug_concept_stage
	SET concept_name = 'Kimed'
	WHERE concept_code = 'OMOP898990';

	UPDATE drug_concept_stage
	SET concept_name = 'Klaire'
	WHERE concept_code = 'OMOP1018979';

	UPDATE drug_concept_stage
	SET concept_name = 'Klemens-Apotheke Dr F U H Reiter'
	WHERE concept_code = 'OMOP899229';

	UPDATE drug_concept_stage
	SET concept_name = 'Klemenz'
	WHERE concept_code = 'OMOP898008';

	UPDATE drug_concept_stage
	SET concept_name = 'Koeniglich Privilegierte Adler Apotheke'
	WHERE concept_code = 'OMOP897590';

	UPDATE drug_concept_stage
	SET concept_name = 'Korea Ginseng'
	WHERE concept_code = 'OMOP899208';

	UPDATE drug_concept_stage
	SET concept_name = 'Kowa'
	WHERE concept_code = 'OMOP897871';

	UPDATE drug_concept_stage
	SET concept_name = 'Kraeuterhaus Sanct Bernhard'
	WHERE concept_code = 'OMOP897290';

	UPDATE drug_concept_stage
	SET concept_name = 'Kraeuterpfarrer Kuenzle'
	WHERE concept_code = 'OMOP897949';

	UPDATE drug_concept_stage
	SET concept_name = 'Kraiss & Friz'
	WHERE concept_code = 'OMOP898345';

	UPDATE drug_concept_stage
	SET concept_name = 'Kreuzapotheke Ruelzheim Inhaber Gabriele Deutsch'
	WHERE concept_code = 'OMOP899030';

	UPDATE drug_concept_stage
	SET concept_name = 'Kroeger Herb'
	WHERE concept_code = 'OMOP1019001';

	UPDATE drug_concept_stage
	SET concept_name = 'Krueger'
	WHERE concept_code = 'OMOP897999';

	UPDATE drug_concept_stage
	SET concept_name = 'KSK-Pharma'
	WHERE concept_code = 'OMOP900456';

	UPDATE drug_concept_stage
	SET concept_name = 'Kutol'
	WHERE concept_code = 'OMOP1019003';

	UPDATE drug_concept_stage
	SET concept_name = 'L & S'
	WHERE concept_code = 'OMOP1019007';

	UPDATE drug_concept_stage
	SET concept_name = 'L Molteni & C Dei F Lli Alitti'
	WHERE concept_code = 'OMOP898281';

	UPDATE drug_concept_stage
	SET concept_name = 'Laboratoire Larima'
	WHERE concept_code = 'OMOP1019021';

	UPDATE drug_concept_stage
	SET concept_name = 'Laboratori Diaco Bioi'
	WHERE concept_code = 'OMOP899334';

	UPDATE drug_concept_stage
	SET concept_name = 'Laboratori Guidotti'
	WHERE concept_code = 'OMOP900432';

	UPDATE drug_concept_stage
	SET concept_name = 'Laboratories For Applied Biology'
	WHERE concept_code = 'OMOP339479';

	UPDATE drug_concept_stage
	SET concept_name = 'Lacorium'
	WHERE concept_code = 'OMOP1019046';

	UPDATE drug_concept_stage
	SET concept_name = 'Laderma'
	WHERE concept_code = 'OMOP1019048';

	UPDATE drug_concept_stage
	SET concept_name = 'Laer'
	WHERE concept_code = 'OMOP1019049';

	UPDATE drug_concept_stage
	SET concept_name = 'Lakeridge Health'
	WHERE concept_code = 'OMOP1019050';

	UPDATE drug_concept_stage
	SET concept_name = 'Lane'
	WHERE concept_code = 'OMOP1019055';

	UPDATE drug_concept_stage
	SET concept_name = 'Lannacher Heilmittel'
	WHERE concept_code = 'OMOP898993';

	UPDATE drug_concept_stage
	SET concept_name = 'Lantheus'
	WHERE concept_code = 'OMOP440450';

	UPDATE drug_concept_stage
	SET concept_name = 'Larose & Fils'
	WHERE concept_code = 'OMOP1019057';

	UPDATE drug_concept_stage
	SET concept_name = 'Laurentius-Apotheke Stephanie Macagnino'
	WHERE concept_code = 'OMOP899597';

	UPDATE drug_concept_stage
	SET concept_name = 'Le Nigen N'
	WHERE concept_code = 'OMOP1019064';

	UPDATE drug_concept_stage
	SET concept_name = 'Lebewohl'
	WHERE concept_code = 'OMOP900115';

	UPDATE drug_concept_stage
	SET concept_name = 'Leda Innovations'
	WHERE concept_code = 'OMOP1019067';

	UPDATE drug_concept_stage
	SET concept_name = 'Lege Artis'
	WHERE concept_code = 'OMOP898302';

	UPDATE drug_concept_stage
	SET concept_name = 'Lek D D'
	WHERE concept_code = 'OMOP898216';

	UPDATE drug_concept_stage
	SET concept_name = 'Bio-SantГ©'
	WHERE concept_code = 'OMOP1019085';

	UPDATE drug_concept_stage
	SET concept_name = 'Chimiques B O D'
	WHERE concept_code = 'OMOP1019081';

	UPDATE drug_concept_stage
	SET concept_name = 'Saint-Laurent'
	WHERE concept_code = 'OMOP1019086';

	UPDATE drug_concept_stage
	SET concept_name = 'Entreprises Plein Sol'
	WHERE concept_code = 'OMOP1019082';

	UPDATE drug_concept_stage
	SET concept_name = 'Servier'
	WHERE concept_code = 'OMOP439865';

	UPDATE drug_concept_stage
	SET concept_name = 'Swisse'
	WHERE concept_code = 'OMOP1019087';

	UPDATE drug_concept_stage
	SET concept_name = 'Lever'
	WHERE concept_code = 'OMOP1019094';

	UPDATE drug_concept_stage
	SET concept_name = 'Lichtenheldt'
	WHERE concept_code = 'OMOP900352';

	UPDATE drug_concept_stage
	SET concept_name = 'Lichtenstein Zeutica'
	WHERE concept_code = 'OMOP899822';

	UPDATE drug_concept_stage
	SET concept_name = 'Lichtwer'
	WHERE concept_code = 'OMOP1019097';

	UPDATE drug_concept_stage
	SET concept_name = 'Liebermann'
	WHERE concept_code = 'OMOP900077';

	UPDATE drug_concept_stage
	SET concept_name = 'Lifeplan'
	WHERE concept_code = 'OMOP338187';

	UPDATE drug_concept_stage
	SET concept_name = 'Lil" Drug Store'
	WHERE concept_code = 'OMOP1019101';

	UPDATE drug_concept_stage
	SET concept_name = 'Limes-Apotheke Andreas Gruenebaum'
	WHERE concept_code = 'OMOP897276';

	UPDATE drug_concept_stage
	SET concept_name = 'Linden'
	WHERE concept_code = 'OMOP898334';

	UPDATE drug_concept_stage
	SET concept_name = 'Logenex'
	WHERE concept_code = 'OMOP898067';

	UPDATE drug_concept_stage
	SET concept_name = 'Lomapharm Rudolf Lohmann'
	WHERE concept_code = 'OMOP898507';

	UPDATE drug_concept_stage
	SET concept_name = 'Lousal'
	WHERE concept_code = 'OMOP1019109';

	UPDATE drug_concept_stage
	SET concept_name = 'Lyocentre'
	WHERE concept_code = 'OMOP439941';

	UPDATE drug_concept_stage
	SET concept_name = 'Vachon'
	WHERE concept_code = 'OMOP1019060';

	UPDATE drug_concept_stage
	SET concept_name = 'Mainopharm'
	WHERE concept_code = 'OMOP898732';

	UPDATE drug_concept_stage
	SET concept_name = 'Majorelle'
	WHERE concept_code = 'OMOP440465';

	UPDATE drug_concept_stage
	SET concept_name = 'Mameca'
	WHERE concept_code = 'OMOP1019331';

	UPDATE drug_concept_stage
	SET concept_name = 'Manai'
	WHERE concept_code = 'OMOP898742';

	UPDATE drug_concept_stage
	SET concept_name = 'Maney Paul'
	WHERE concept_code = 'OMOP1019042';

	UPDATE drug_concept_stage
	SET concept_name = 'Marien-Apotheke Roland Leikertfm'
	WHERE concept_code = 'OMOP897383';

	UPDATE drug_concept_stage
	SET concept_name = 'Martin-Apotheke Guenter Stephan Gisela Heidt-Templin'
	WHERE concept_code = 'OMOP897454';

	UPDATE drug_concept_stage
	SET concept_name = 'Martinus-Apotheke Bernhard Gievert'
	WHERE concept_code = 'OMOP898969';

	UPDATE drug_concept_stage
	SET concept_name = 'Matol Botanique'
	WHERE concept_code = 'OMOP1018943';

	UPDATE drug_concept_stage
	SET concept_name = 'Matramed Mfg'
	WHERE concept_code = 'OMOP1018947';

	UPDATE drug_concept_stage
	SET concept_name = 'Mauermann'
	WHERE concept_code = 'OMOP899774';

	UPDATE drug_concept_stage
	SET concept_name = 'Mavena'
	WHERE concept_code = 'OMOP897966';

	UPDATE drug_concept_stage
	SET concept_name = 'Mayne'
	WHERE concept_code = 'OMOP338706';

	UPDATE drug_concept_stage
	SET concept_name = 'Mayoly Spindler'
	WHERE concept_code = 'OMOP440326';

	UPDATE drug_concept_stage
	SET concept_name = 'Mco'
	WHERE concept_code = 'OMOP2018657';

	UPDATE drug_concept_stage
	SET concept_name = 'Media pharmaceutic'
	WHERE concept_code = 'OMOP2018649';

	UPDATE drug_concept_stage
	SET concept_name = 'Medic Laboratory'
	WHERE concept_code = 'OMOP1018795';

	UPDATE drug_concept_stage
	SET concept_name = 'Medicines'
	WHERE concept_code = 'OMOP339238';

	UPDATE drug_concept_stage
	SET concept_name = 'Medicon'
	WHERE concept_code = 'OMOP899143';

	UPDATE drug_concept_stage
	SET concept_name = 'Medique/Unifirst'
	WHERE concept_code = 'OMOP1018879';

	UPDATE drug_concept_stage
	SET concept_name = 'Medix Team'
	WHERE concept_code = 'OMOP338143';

	UPDATE drug_concept_stage
	SET concept_name = 'Medline'
	WHERE concept_code = 'OMOP1018880';

	UPDATE drug_concept_stage
	SET concept_name = 'Medopharm'
	WHERE concept_code = 'OMOP899724';

	UPDATE drug_concept_stage
	SET concept_name = 'Medrx Llp'
	WHERE concept_code = 'OMOP338764';

	UPDATE drug_concept_stage
	SET concept_name = 'Mekos'
	WHERE concept_code = 'OMOP1018892';

	UPDATE drug_concept_stage
	SET concept_name = 'Menarini'
	WHERE concept_code = 'OMOP440135';

	UPDATE drug_concept_stage
	SET concept_name = 'Merus Luxco'
	WHERE concept_code = 'OMOP339442';

	UPDATE drug_concept_stage
	SET concept_name = 'Metrex'
	WHERE concept_code = 'OMOP1018944';

	UPDATE drug_concept_stage
	SET concept_name = 'Meuselbach'
	WHERE concept_code = 'OMOP897791';

	UPDATE drug_concept_stage
	SET concept_name = 'Meyer Zall'
	WHERE concept_code = 'OMOP1018946';

	UPDATE drug_concept_stage
	SET concept_name = 'Mickan'
	WHERE concept_code = 'OMOP899067';

	UPDATE drug_concept_stage
	SET concept_name = 'Micro-Labs'
	WHERE concept_code = 'OMOP897870';

	UPDATE drug_concept_stage
	SET concept_name = 'Mineralbrunnen Ueberkingen-Teinach'
	WHERE concept_code = 'OMOP900279';

	UPDATE drug_concept_stage
	SET concept_name = 'Mithra'
	WHERE concept_code = 'OMOP899197';

	UPDATE drug_concept_stage
	SET concept_name = 'MM'
	WHERE concept_code = 'OMOP1018928';

	UPDATE drug_concept_stage
	SET concept_name = 'Momaja Elc-Group'
	WHERE concept_code = 'OMOP897730';

	UPDATE drug_concept_stage
	SET concept_name = 'Monarch'
	WHERE concept_code = 'OMOP440034';

	UPDATE drug_concept_stage
	SET concept_name = 'Montavit'
	WHERE concept_code = 'OMOP1019363';

	UPDATE drug_concept_stage
	SET concept_name = 'Montreal Veterinary'
	WHERE concept_code = 'OMOP1018930';

	UPDATE drug_concept_stage
	SET concept_name = 'Morex'
	WHERE concept_code = 'OMOP1018931';

	UPDATE drug_concept_stage
	SET concept_name = 'Mustermann'
	WHERE concept_code = 'OMOP900061';

	UPDATE drug_concept_stage
	SET concept_name = 'mv-Pharma'
	WHERE concept_code = 'OMOP899956';

	UPDATE drug_concept_stage
	SET concept_name = 'Mycare'
	WHERE concept_code = 'OMOP898371';

	UPDATE drug_concept_stage
	SET concept_name = 'Nabisco'
	WHERE concept_code = 'OMOP1018809';

	UPDATE drug_concept_stage
	SET concept_name = 'Nadeau'
	WHERE concept_code = 'OMOP1019016';

	UPDATE drug_concept_stage
	SET concept_name = 'Natali'
	WHERE concept_code = 'OMOP1018815';

	UPDATE drug_concept_stage
	SET concept_name = 'Natural Factors'
	WHERE concept_code = 'OMOP1018823';

	UPDATE drug_concept_stage
	SET concept_name = 'Naturasanitas'
	WHERE concept_code = 'OMOP897530';

	UPDATE drug_concept_stage
	SET concept_name = 'Nature"s Sunshine'
	WHERE concept_code = 'OMOP1018834';

	UPDATE drug_concept_stage
	SET concept_name = 'Negma'
	WHERE concept_code = 'OMOP440260';

	UPDATE drug_concept_stage
	SET concept_name = 'Neitum'
	WHERE concept_code = 'OMOP440140';

	UPDATE drug_concept_stage
	SET concept_name = 'NEL'
	WHERE concept_code = 'OMOP897935';

	UPDATE drug_concept_stage
	SET concept_name = 'Neogen'
	WHERE concept_code = 'OMOP899630';

	UPDATE drug_concept_stage
	SET concept_name = 'Nepenthes'
	WHERE concept_code = 'OMOP440152';

	UPDATE drug_concept_stage
	SET concept_name = 'Nephro Medica'
	WHERE concept_code = 'OMOP899462';

	UPDATE drug_concept_stage
	SET concept_name = 'Nestle'
	WHERE concept_code = 'OMOP339543';

	UPDATE drug_concept_stage
	SET concept_name = 'New Era'
	WHERE concept_code = 'OMOP1018847';

	UPDATE drug_concept_stage
	SET concept_name = 'New Life'
	WHERE concept_code = 'OMOP1018848';

	UPDATE drug_concept_stage
	SET concept_name = 'Newline'
	WHERE concept_code = 'OMOP897567';

	UPDATE drug_concept_stage
	SET concept_name = 'Nibelungen-Apotheke Andreas Hammer'
	WHERE concept_code = 'OMOP898834';

	UPDATE drug_concept_stage
	SET concept_name = 'NM Vital Apotheke'
	WHERE concept_code = 'OMOP898060';

	UPDATE drug_concept_stage
	SET concept_name = 'Nobel'
	WHERE concept_code = 'OMOP1018857';

	UPDATE drug_concept_stage
	SET concept_name = 'Norit'
	WHERE concept_code = 'OMOP898029';

	UPDATE drug_concept_stage
	SET concept_name = 'Normon'
	WHERE concept_code = 'OMOP899802';

	UPDATE drug_concept_stage
	SET concept_name = 'Norwood'
	WHERE concept_code = 'OMOP1018873';

	UPDATE drug_concept_stage
	SET concept_name = 'Novesia'
	WHERE concept_code = 'OMOP899980';

	UPDATE drug_concept_stage
	SET concept_name = 'Nuron Biotech'
	WHERE concept_code = 'OMOP1019368';

	UPDATE drug_concept_stage
	SET concept_name = 'Nutra'
	WHERE concept_code = 'OMOP1019370';

	UPDATE drug_concept_stage
	SET concept_name = 'Nutri'
	WHERE concept_code = 'OMOP440158';

	UPDATE drug_concept_stage
	SET concept_name = 'Nutri-Chem'
	WHERE concept_code = 'OMOP1019396';

	UPDATE drug_concept_stage
	SET concept_name = 'Nutri-Dyn'
	WHERE concept_code = 'OMOP1019398';

	UPDATE drug_concept_stage
	SET concept_name = 'Nutrimedika'
	WHERE concept_code = 'OMOP1019406';

	UPDATE drug_concept_stage
	SET concept_name = 'Nutrivac'
	WHERE concept_code = 'OMOP1019415';

	UPDATE drug_concept_stage
	SET concept_name = 'Nuvo'
	WHERE concept_code = 'OMOP900311';

	UPDATE drug_concept_stage
	SET concept_name = 'Obagi'
	WHERE concept_code = 'OMOP1019426';

	UPDATE drug_concept_stage
	SET concept_name = 'Olympia-Apothekecha Strehmel'
	WHERE concept_code = 'OMOP898118';

	UPDATE drug_concept_stage
	SET concept_name = 'Omrix'
	WHERE concept_code = 'OMOP440069';

	UPDATE drug_concept_stage
	SET concept_name = 'Opti'
	WHERE concept_code = 'OMOP2018726';

	UPDATE drug_concept_stage
	SET concept_name = 'Organika'
	WHERE concept_code = 'OMOP1019417';

	UPDATE drug_concept_stage
	SET concept_name = 'Orpha Devel'
	WHERE concept_code = 'OMOP440321';

	UPDATE drug_concept_stage
	SET concept_name = 'Oshawa Group'
	WHERE concept_code = 'OMOP1019678';

	UPDATE drug_concept_stage
	SET concept_name = 'Osterholz'
	WHERE concept_code = 'OMOP897556';

	UPDATE drug_concept_stage
	SET concept_name = 'P.T. New Tombak'
	WHERE concept_code = 'OMOP1019462';

	UPDATE drug_concept_stage
	SET concept_name = 'Paladin'
	WHERE concept_code = 'OMOP338178';

	UPDATE drug_concept_stage
	SET concept_name = 'Panacea Biotec'
	WHERE concept_code = 'OMOP899217';

	UPDATE drug_concept_stage
	SET concept_name = 'Parall'
	WHERE concept_code = 'OMOP1019356';

	UPDATE drug_concept_stage
	SET concept_name = 'Parfums Parquet'
	WHERE concept_code = 'OMOP1019376';

	UPDATE drug_concept_stage
	SET concept_name = 'Parthenon'
	WHERE concept_code = 'OMOP1019679';

	UPDATE drug_concept_stage
	SET concept_name = 'Pascoe'
	WHERE concept_code = 'OMOP899450';

	UPDATE drug_concept_stage
	SET concept_name = 'Pasteur Apotheke Barbara Henkel'
	WHERE concept_code = 'OMOP899835';

	UPDATE drug_concept_stage
	SET concept_name = 'Patroklus Apotheke Dr F Tenbieg'
	WHERE concept_code = 'OMOP898248';

	UPDATE drug_concept_stage
	SET concept_name = 'Paul Cors'
	WHERE concept_code = 'OMOP900244';

	UPDATE drug_concept_stage
	SET concept_name = 'Paulus Apotheke'
	WHERE concept_code = 'OMOP897617';

	UPDATE drug_concept_stage
	SET concept_name = 'PE'
	WHERE concept_code = 'OMOP2018766';

	UPDATE drug_concept_stage
	SET concept_name = 'Performance'
	WHERE concept_code = 'OMOP1019464';

	UPDATE drug_concept_stage
	SET concept_name = 'Pern'
	WHERE concept_code = 'OMOP339504';

	UPDATE drug_concept_stage
	SET concept_name = 'Pfingstweide-Apotheke Juergen Duerrwang'
	WHERE concept_code = 'OMOP899590';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharma Aktiva-Bitte Nicht Zum Codieren Verwenden '
	WHERE concept_code = 'OMOP897536';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharma Aldenhoven'
	WHERE concept_code = 'OMOP900158';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmacal'
	WHERE concept_code = 'OMOP1019475';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmaceuticals Sales & Development'
	WHERE concept_code = 'OMOP897889';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmachemie'
	WHERE concept_code = 'OMOP897460';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmacie Centrale Des Armees'
	WHERE concept_code = 'OMOP440167';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmafrid'
	WHERE concept_code = 'OMOP900134';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmaki'
	WHERE concept_code = 'OMOP440339';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmaselect'
	WHERE concept_code = 'OMOP440121';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmaswiss'
	WHERE concept_code = 'OMOP440436';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharmtek'
	WHERE concept_code = 'OMOP1019034';

	UPDATE drug_concept_stage
	SET concept_name = 'Pharos-Oriented'
	WHERE concept_code = 'OMOP899703';

	UPDATE drug_concept_stage
	SET concept_name = 'Phytocon'
	WHERE concept_code = 'OMOP898049';

	UPDATE drug_concept_stage
	SET concept_name = 'Pierre Rolland'
	WHERE concept_code = 'OMOP440166';

	UPDATE drug_concept_stage
	SET concept_name = 'Pittsburgh Plastics'
	WHERE concept_code = 'OMOP1019389';

	UPDATE drug_concept_stage
	SET concept_name = 'PKH'
	WHERE concept_code = 'OMOP899320';

	UPDATE drug_concept_stage
	SET concept_name = 'Plosspharma'
	WHERE concept_code = 'OMOP897465';

	UPDATE drug_concept_stage
	SET concept_name = 'PNS'
	WHERE concept_code = 'OMOP1019310';

	UPDATE drug_concept_stage
	SET concept_name = 'Preval'
	WHERE concept_code = 'OMOP1019290';

	UPDATE drug_concept_stage
	SET concept_name = 'Prime'
	WHERE concept_code = 'OMOP1019297';

	UPDATE drug_concept_stage
	SET concept_name = 'Pro Med'
	WHERE concept_code = 'OMOP439851';

	UPDATE drug_concept_stage
	SET concept_name = 'Proactiv'
	WHERE concept_code = 'OMOP1019680';

	UPDATE drug_concept_stage
	SET concept_name = 'ProCura hymed'
	WHERE concept_code = 'OMOP898572';

	UPDATE drug_concept_stage
	SET concept_name = 'Prodeal'
	WHERE concept_code = 'OMOP1019061';

	UPDATE drug_concept_stage
	SET concept_name = 'Prodene Klint'
	WHERE concept_code = 'OMOP1019035';

	UPDATE drug_concept_stage
	SET concept_name = 'Produits Francais'
	WHERE concept_code = 'OMOP1019330';

	UPDATE drug_concept_stage
	SET concept_name = 'Produits Sani Professionel'
	WHERE concept_code = 'OMOP1019334';

	UPDATE drug_concept_stage
	SET concept_name = 'Pronova'
	WHERE concept_code = 'OMOP439878';

	UPDATE drug_concept_stage
	SET concept_name = 'Protina'
	WHERE concept_code = 'OMOP900424';

	UPDATE drug_concept_stage
	SET concept_name = 'PS'
	WHERE concept_code = 'OMOP900282';

	UPDATE drug_concept_stage
	SET concept_name = 'Purity Life'
	WHERE concept_code = 'OMOP1019294';

	UPDATE drug_concept_stage
	SET concept_name = 'QD'
	WHERE concept_code = 'OMOP1019300';

	UPDATE drug_concept_stage
	SET concept_name = 'Quigley'
	WHERE concept_code = 'OMOP1019681';

	UPDATE drug_concept_stage
	SET concept_name = 'Quintessenz'
	WHERE concept_code = 'OMOP2018792';

	UPDATE drug_concept_stage
	SET concept_name = 'Quisisana'
	WHERE concept_code = 'OMOP900114';

	UPDATE drug_concept_stage
	SET concept_name = 'R.I.S.'
	WHERE concept_code = 'OMOP338280';

	UPDATE drug_concept_stage
	SET concept_name = 'Rafarm'
	WHERE concept_code = 'OMOP900201';

	UPDATE drug_concept_stage
	SET concept_name = 'Ramprie'
	WHERE concept_code = 'OMOP572413';

	UPDATE drug_concept_stage
	SET concept_name = 'Rapidscan'
	WHERE concept_code = 'OMOP338461';

	UPDATE drug_concept_stage
	SET concept_name = 'Ratingsee-Apotheke M Roth'
	WHERE concept_code = 'OMOP898258';

	UPDATE drug_concept_stage
	SET concept_name = 'Ravensberg'
	WHERE concept_code = 'OMOP898541';

	UPDATE drug_concept_stage
	SET concept_name = 'Redken'
	WHERE concept_code = 'OMOP1019342';

	UPDATE drug_concept_stage
	SET concept_name = 'Regent'
	WHERE concept_code = 'OMOP439892';

	UPDATE drug_concept_stage
	SET concept_name = 'Regime'
	WHERE concept_code = 'OMOP1019346';

	UPDATE drug_concept_stage
	SET concept_name = 'Repha'
	WHERE concept_code = 'OMOP899520';

	UPDATE drug_concept_stage
	SET concept_name = 'Reusch'
	WHERE concept_code = 'OMOP2018744';

	UPDATE drug_concept_stage
	SET concept_name = 'RMC'
	WHERE concept_code = 'OMOP1019260';

	UPDATE drug_concept_stage
	SET concept_name = 'Robugen'
	WHERE concept_code = 'OMOP899282';

	UPDATE drug_concept_stage
	SET concept_name = 'Ronneburg-Apotheke Peter Frank'
	WHERE concept_code = 'OMOP899569';

	UPDATE drug_concept_stage
	SET concept_name = 'Root'
	WHERE concept_code = 'OMOP1019276';

	UPDATE drug_concept_stage
	SET concept_name = 'Rotexmedica'
	WHERE concept_code = 'OMOP898924';

	UPDATE drug_concept_stage
	SET concept_name = 'Roth'
	WHERE concept_code = 'OMOP900155';

	UPDATE drug_concept_stage
	SET concept_name = 'Rotop'
	WHERE concept_code = 'OMOP440342';

	UPDATE drug_concept_stage
	SET concept_name = 'Rowa-Wagner'
	WHERE concept_code = 'OMOP899494';

	UPDATE drug_concept_stage
	SET concept_name = 'RW'
	WHERE concept_code = 'OMOP1019277';

	UPDATE drug_concept_stage
	SET concept_name = 'S.C. Polipharma'
	WHERE concept_code = 'OMOP900313';

	UPDATE drug_concept_stage
	SET concept_name = 'S+H'
	WHERE concept_code = 'OMOP2018796';

	UPDATE drug_concept_stage
	SET concept_name = 'Saale-Apotheke Kaulsdorf Uta Seitz'
	WHERE concept_code = 'OMOP897505';

	UPDATE drug_concept_stage
	SET concept_name = 'Safetex'
	WHERE concept_code = 'OMOP1019271';

	UPDATE drug_concept_stage
	SET concept_name = 'Sage'
	WHERE concept_code = 'OMOP899924';

	UPDATE drug_concept_stage
	SET concept_name = 'Salzach Apotheke'
	WHERE concept_code = 'OMOP899550';

	UPDATE drug_concept_stage
	SET concept_name = 'Saneca'
	WHERE concept_code = 'OMOP897305';

	UPDATE drug_concept_stage
	SET concept_name = 'Sanesco'
	WHERE concept_code = 'OMOP899955';

	UPDATE drug_concept_stage
	SET concept_name = 'Sanis'
	WHERE concept_code = 'OMOP1019745';

	UPDATE drug_concept_stage
	SET concept_name = 'Sano'
	WHERE concept_code = 'OMOP899855';

	UPDATE drug_concept_stage
	SET concept_name = 'Sanorell'
	WHERE concept_code = 'OMOP897707';

	UPDATE drug_concept_stage
	SET concept_name = 'SantГ© Nature'
	WHERE concept_code = 'OMOP1019201';

	UPDATE drug_concept_stage
	SET concept_name = 'SantГ© Naturelle'
	WHERE concept_code = 'OMOP1019751';

	UPDATE drug_concept_stage
	SET concept_name = 'Sanum Kehlbeck'
	WHERE concept_code = 'OMOP900302';

	UPDATE drug_concept_stage
	SET concept_name = 'Saraya'
	WHERE concept_code = 'OMOP898032';

	UPDATE drug_concept_stage
	SET concept_name = 'SBS'
	WHERE concept_code = 'OMOP1019770';

	UPDATE drug_concept_stage
	SET concept_name = 'SC Infomed Fluids'
	WHERE concept_code = 'OMOP900168';

	UPDATE drug_concept_stage
	SET concept_name = 'Schaper & Bruemmer'
	WHERE concept_code = 'OMOP900288';

	UPDATE drug_concept_stage
	SET concept_name = 'Scholl'
	WHERE concept_code = 'OMOP337824';

	UPDATE drug_concept_stage
	SET concept_name = 'Schubert-Apotheke Dr Matthias Oechsner'
	WHERE concept_code = 'OMOP898434';

	UPDATE drug_concept_stage
	SET concept_name = 'Schuck'
	WHERE concept_code = 'OMOP899844';

	UPDATE drug_concept_stage
	SET concept_name = 'Schumann Apotheke Nadya Hannoudi'
	WHERE concept_code = 'OMOP899671';

	UPDATE drug_concept_stage
	SET concept_name = 'Schur'
	WHERE concept_code = 'OMOP898177';

	UPDATE drug_concept_stage
	SET concept_name = 'Schwarzhaupt'
	WHERE concept_code = 'OMOP899460';

	UPDATE drug_concept_stage
	SET concept_name = 'Schwoerer'
	WHERE concept_code = 'OMOP899276';

	UPDATE drug_concept_stage
	SET concept_name = 'Searle'
	WHERE concept_code = 'OMOP1019796';

	UPDATE drug_concept_stage
	SET concept_name = 'Semmelweis-Apotheke Brigitte Rump'
	WHERE concept_code = 'OMOP899686';

	UPDATE drug_concept_stage
	SET concept_name = 'SFDB'
	WHERE concept_code = 'OMOP440049';

	UPDATE drug_concept_stage
	SET concept_name = 'Siemens'
	WHERE concept_code = 'OMOP338512';

	UPDATE drug_concept_stage
	SET concept_name = 'Sintetica'
	WHERE concept_code = 'OMOP337930';

	UPDATE drug_concept_stage
	SET concept_name = 'Sisir Gupta'
	WHERE concept_code = 'OMOP899317';

	UPDATE drug_concept_stage
	SET concept_name = 'Sivem'
	WHERE concept_code = 'OMOP1019753';

	UPDATE drug_concept_stage
	SET concept_name = 'Smiths ASD'
	WHERE concept_code = 'OMOP1019784';

	UPDATE drug_concept_stage
	SET concept_name = 'Solar Cosmetic'
	WHERE concept_code = 'OMOP1019685';

	UPDATE drug_concept_stage
	SET concept_name = 'Solgar'
	WHERE concept_code = 'OMOP337880';

	UPDATE drug_concept_stage
	SET concept_name = 'Somex'
	WHERE concept_code = 'OMOP338743';

	UPDATE drug_concept_stage
	SET concept_name = 'Sopherion'
	WHERE concept_code = 'OMOP1019696';

	UPDATE drug_concept_stage
	SET concept_name = 'Source Of Life'
	WHERE concept_code = 'OMOP1019716';

	UPDATE drug_concept_stage
	SET concept_name = 'Speciality'
	WHERE concept_code = 'OMOP339172';

	UPDATE drug_concept_stage
	SET concept_name = 'Spitzweg-Apotheke Gertrud Heim'
	WHERE concept_code = 'OMOP898702';

	UPDATE drug_concept_stage
	SET concept_name = 'Sportscience'
	WHERE concept_code = 'OMOP1019723';

	UPDATE drug_concept_stage
	SET concept_name = 'Sprakita'
	WHERE concept_code = 'OMOP1019732';

	UPDATE drug_concept_stage
	SET concept_name = 'SRH Zentralklinikum Suhl'
	WHERE concept_code = 'OMOP900042';

	UPDATE drug_concept_stage
	SET concept_name = 'St Antonius-Apotheke Hans Tauber'
	WHERE concept_code = 'OMOP899594';

	UPDATE drug_concept_stage
	SET concept_name = 'St Johanser Naturmittel'
	WHERE concept_code = 'OMOP898201';

	UPDATE drug_concept_stage
	SET concept_name = 'Stadtbruecken-Apotheke Swetlana Koslowski'
	WHERE concept_code = 'OMOP900233';

	UPDATE drug_concept_stage
	SET concept_name = 'Steierl'
	WHERE concept_code = 'OMOP898852';

	UPDATE drug_concept_stage
	SET concept_name = 'Sterigen'
	WHERE concept_code = 'OMOP1019036';

	UPDATE drug_concept_stage
	SET concept_name = 'Stroschein'
	WHERE concept_code = 'OMOP2018745';

	UPDATE drug_concept_stage
	SET concept_name = 'Stulln'
	WHERE concept_code = 'OMOP897905';

	UPDATE drug_concept_stage
	SET concept_name = 'Summerberry'
	WHERE concept_code = 'OMOP1019720';

	UPDATE drug_concept_stage
	SET concept_name = 'Sunlife'
	WHERE concept_code = 'OMOP899993';

	UPDATE drug_concept_stage
	SET concept_name = 'Sun-Rype'
	WHERE concept_code = 'OMOP1019725';

	UPDATE drug_concept_stage
	SET concept_name = 'Super Diet'
	WHERE concept_code = 'OMOP440189';

	UPDATE drug_concept_stage
	SET concept_name = 'Superieures Solutions'
	WHERE concept_code = 'OMOP1019741';

	UPDATE drug_concept_stage
	SET concept_name = 'Syxyl'
	WHERE concept_code = 'OMOP900097';

	UPDATE drug_concept_stage
	SET concept_name = 'Talecris'
	WHERE concept_code = 'OMOP1019633';

	UPDATE drug_concept_stage
	SET concept_name = 'Tanning'
	WHERE concept_code = 'OMOP1019634';

	UPDATE drug_concept_stage
	SET concept_name = 'Taoasis Natur'
	WHERE concept_code = 'OMOP898523';

	UPDATE drug_concept_stage
	SET concept_name = 'Thermyc'
	WHERE concept_code = 'OMOP1019025';

	UPDATE drug_concept_stage
	SET concept_name = 'Thorne'
	WHERE concept_code = 'OMOP1019663';

	UPDATE drug_concept_stage
	SET concept_name = 'Tianshi'
	WHERE concept_code = 'OMOP1019671';

	UPDATE drug_concept_stage
	SET concept_name = 'Titus-Apotheke Dr Roland Herbst'
	WHERE concept_code = 'OMOP898287';

	UPDATE drug_concept_stage
	SET concept_name = 'Togal-Werk'
	WHERE concept_code = 'OMOP897840';

	UPDATE drug_concept_stage
	SET concept_name = 'Topfit'
	WHERE concept_code = 'OMOP338256';

	UPDATE drug_concept_stage
	SET concept_name = 'TP'
	WHERE concept_code = 'OMOP1019582';

	UPDATE drug_concept_stage
	SET concept_name = 'Trafalgar'
	WHERE concept_code = 'OMOP1019585';

	UPDATE drug_concept_stage
	SET concept_name = 'Trans'
	WHERE concept_code = 'OMOP1019598';

	UPDATE drug_concept_stage
	SET concept_name = 'Trianon'
	WHERE concept_code = 'OMOP1019037';

	UPDATE drug_concept_stage
	SET concept_name = 'Trillium'
	WHERE concept_code = 'OMOP1019509';

	UPDATE drug_concept_stage
	SET concept_name = 'Tyczka'
	WHERE concept_code = 'OMOP898552';

	UPDATE drug_concept_stage
	SET concept_name = 'Tyler'
	WHERE concept_code = 'OMOP1019568';

	UPDATE drug_concept_stage
	SET concept_name = 'Ultra-Love'
	WHERE concept_code = 'OMOP1019573';

	UPDATE drug_concept_stage
	SET concept_name = 'Ultrapac'
	WHERE concept_code = 'OMOP1019062';

	UPDATE drug_concept_stage
	SET concept_name = 'Uni- Kleon Tsetis'
	WHERE concept_code = 'OMOP899250';

	UPDATE drug_concept_stage
	SET concept_name = 'Unichem'
	WHERE concept_code = 'OMOP899523';

	UPDATE drug_concept_stage
	SET concept_name = 'Unimark Remedies'
	WHERE concept_code = 'OMOP897723';

	UPDATE drug_concept_stage
	SET concept_name = 'Unither'
	WHERE concept_code = 'OMOP440370';

	UPDATE drug_concept_stage
	SET concept_name = 'Valda'
	WHERE concept_code = 'OMOP1019044';

	UPDATE drug_concept_stage
	SET concept_name = 'Valmo'
	WHERE concept_code = 'OMOP1019017';

	UPDATE drug_concept_stage
	SET concept_name = 'Velvian'
	WHERE concept_code = 'OMOP440177';

	UPDATE drug_concept_stage
	SET concept_name = 'Vemedia'
	WHERE concept_code = 'OMOP900102';

	UPDATE drug_concept_stage
	SET concept_name = 'Vitalia'
	WHERE concept_code = 'OMOP900410';

	UPDATE drug_concept_stage
	SET concept_name = 'Vitavie Au Naturel'
	WHERE concept_code = 'OMOP1019605';

	UPDATE drug_concept_stage
	SET concept_name = 'Vocate'
	WHERE concept_code = 'OMOP897604';

	UPDATE drug_concept_stage
	SET concept_name = 'W.H. Werk'
	WHERE concept_code = 'OMOP2018900';

	UPDATE drug_concept_stage
	SET concept_name = 'Walter Ritter'
	WHERE concept_code = 'OMOP897988';

	UPDATE drug_concept_stage
	SET concept_name = 'Wampole'
	WHERE concept_code = 'OMOP1019503';

	UPDATE drug_concept_stage
	SET concept_name = 'Wappen'
	WHERE concept_code = 'OMOP2018892';

	UPDATE drug_concept_stage
	SET concept_name = 'Weider'
	WHERE concept_code = 'OMOP1019513';

	UPDATE drug_concept_stage
	SET concept_name = 'Welding'
	WHERE concept_code = 'OMOP899381';

	UPDATE drug_concept_stage
	SET concept_name = 'Welfen-Apotheke Moritz Bringmann'
	WHERE concept_code = 'OMOP897921';

	UPDATE drug_concept_stage
	SET concept_name = 'Welk'
	WHERE concept_code = 'OMOP2018747';

	UPDATE drug_concept_stage
	SET concept_name = 'Wero- Werner Michallik'
	WHERE concept_code = 'OMOP898592';

	UPDATE drug_concept_stage
	SET concept_name = 'Wes Pak'
	WHERE concept_code = 'OMOP1019519';

	UPDATE drug_concept_stage
	SET concept_name = 'Wesergold'
	WHERE concept_code = 'OMOP897726';

	UPDATE drug_concept_stage
	SET concept_name = 'West Chemical'
	WHERE concept_code = 'OMOP1019521';

	UPDATE drug_concept_stage
	SET concept_name = 'Westfalen-Apotheke Hans-Peter Dasbach'
	WHERE concept_code = 'OMOP897552';

	UPDATE drug_concept_stage
	SET concept_name = 'Wieb Pharm'
	WHERE concept_code = 'OMOP897433';

	UPDATE drug_concept_stage
	SET concept_name = 'Wiedemann'
	WHERE concept_code = 'OMOP898936';

	UPDATE drug_concept_stage
	SET concept_name = 'Wilhelm Horn'
	WHERE concept_code = 'OMOP898133';

	UPDATE drug_concept_stage
	SET concept_name = 'WIN Medicare'
	WHERE concept_code = 'OMOP899745';

	UPDATE drug_concept_stage
	SET concept_name = 'Wolf'
	WHERE concept_code = 'OMOP2018749';

	UPDATE drug_concept_stage
	SET concept_name = 'Xo'
	WHERE concept_code = 'OMOP440101';

	UPDATE drug_concept_stage
	SET concept_name = 'Yves Ponroy'
	WHERE concept_code = 'OMOP1018992';

	UPDATE drug_concept_stage
	SET concept_name = 'Zep'
	WHERE concept_code = 'OMOP1019549';
END $_ $;

UPDATE drug_concept_stage
SET concept_name = initcap(concept_name)
WHERE concept_code IN (
		'OMOP1019746',
		'OMOP1140332',
		'OMOP338156',
		'OMOP339265',
		'OMOP439864',
		'OMOP439886',
		'OMOP439966',
		'OMOP440103',
		'OMOP440239',
		'OMOP440255',
		'OMOP440361',
		'OMOP440377',
		'OMOP440390',
		'OMOP440444',
		'OMOP899887',
		'OMOP897787',
		'OMOP440036',
		'OMOP440162',
		'OMOP440311',
		'OMOP440117',
		'OMOP1140336',
		'OMOP897922',
		'OMOP440455',
		'OMOP899299',
		'OMOP1140328',
		'OMOP899903',
		'OMOP899517',
		'OMOP2018490',
		'OMOP440013',
		'OMOP898959',
		'OMOP897843',
		'OMOP440087',
		'OMOP440054',
		'OMOP440424',
		'OMOP900406',
		'OMOP900170',
		'OMOP897576',
		'OMOP898690',
		'OMOP899948',
		'OMOP338526',
		'OMOP898887',
		'OMOP338667',
		'OMOP898603',
		'OMOP899663',
		'OMOP897447',
		'OMOP899827',
		'OMOP897515',
		'OMOP338334',
		'OMOP440052',
		'OMOP1018733',
		'OMOP440380',
		'OMOP898311',
		'OMOP898655',
		'OMOP338104',
		'OMOP440289',
		'OMOP440181',
		'OMOP440146',
		'OMOP898628',
		'OMOP899289',
		'OMOP439979',
		'OMOP899432',
		'OMOP1140327',
		'OMOP898170',
		'OMOP440051',
		'OMOP440071',
		'OMOP440348',
		'OMOP900428',
		'OMOP900167',
		'OMOP899487',
		'OMOP440402',
		'OMOP900154',
		'OMOP899825',
		'OMOP897804',
		'OMOP900318',
		'OMOP440131',
		'OMOP439987',
		'OMOP900452',
		'OMOP440012',
		'OMOP440142',
		'OMOP439963',
		'OMOP897635',
		'OMOP440043',
		'OMOP900241',
		'OMOP440416',
		'OMOP338332',
		'OMOP898096',
		'OMOP899395',
		'OMOP899245',
		'OMOP899978',
		'OMOP897647',
		'OMOP1140335',
		'OMOP899641',
		'OMOP1140340',
		'OMOP898152',
		'OMOP440292',
		'OMOP440068',
		'OMOP898010',
		'OMOP899764',
		'OMOP900050',
		'OMOP440233',
		'OMOP440124',
		'OMOP439970',
		'OMOP899653',
		'OMOP338039',
		'OMOP899256',
		'OMOP1018924',
		'OMOP898373',
		'OMOP440205',
		'OMOP440063',
		'OMOP439969',
		'OMOP440250',
		'OMOP898347',
		'OMOP898814',
		'OMOP440257',
		'OMOP898428',
		'OMOP439905',
		'OMOP439845',
		'OMOP440434',
		'OMOP440053',
		'OMOP898398',
		'OMOP440224',
		'OMOP338500',
		'OMOP440297',
		'OMOP440372',
		'OMOP899611',
		'OMOP899818',
		'OMOP900469',
		'OMOP439981',
		'OMOP338651',
		'OMOP440022',
		'OMOP440284',
		'OMOP899957',
		'OMOP899007',
		'OMOP898853',
		'OMOP898589',
		'OMOP898121',
		'OMOP440449',
		'OMOP440262',
		'OMOP898698',
		'OMOP900307',
		'OMOP439920',
		'OMOP440462',
		'OMOP900109',
		'OMOP898555',
		'OMOP338556',
		'OMOP899730',
		'OMOP440473'
		);

UPDATE drug_concept_stage
SET concept_name = upper(concept_name)
WHERE concept_code IN (
		'OMOP440196',
		'OMOP1018189',
		'OMOP1019188',
		'OMOP2018283',
		'OMOP2018329',
		'OMOP2018371',
		'OMOP1018653',
		'OMOP337858',
		'OMOP2018480',
		'OMOP338558',
		'OMOP2018558',
		'OMOP440033',
		'OMOP898426',
		'OMOP2018544',
		'OMOP1019140',
		'OMOP2018569',
		'OMOP1019173',
		'OMOP1019206',
		'OMOP1019002',
		'OMOP2018615',
		'OMOP1018927',
		'OMOP2018664',
		'OMOP2018690',
		'OMOP1019438',
		'OMOP2018765',
		'OMOP1019472',
		'OMOP2018734',
		'OMOP1019248',
		'OMOP2018853'
		);

--ds_stage
--fix quant homeopathy that is missing unit
UPDATE ds_stage
SET denominator_unit = 'mL'
WHERE numerator_unit IN (
		'[hp_X]',
		'[hp_C]'
		)
	AND denominator_value IS NOT NULL
	AND denominator_unit IS NULL
	AND drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name ~ '^\d+(\.\d+)? ML '
		);

UPDATE ds_stage
SET denominator_unit = 'mg'
WHERE numerator_unit IN (
		'[hp_X]',
		'[hp_C]'
		)
	AND denominator_value IS NOT NULL
	AND denominator_unit IS NULL
	AND drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name ~ '^\d+(\.\d+)? MG '
		);

--fix wrong numerator calculation in homeopathy
UPDATE ds_stage
SET numerator_value = numerator_value / denominator_value
WHERE numerator_unit IN (
		'[hp_X]',
		'[hp_C]'
		)
	AND denominator_value IS NOT NULL
	AND drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		JOIN drug_concept_stage ON concept_code = drug_concept_code
			AND substring(concept_name, '\s(\d+)\s(X|C)\s')::FLOAT != numerator_value
		);

--fix gases
UPDATE ds_stage
SET denominator_value = NULL
WHERE numerator_unit = '%'
	AND denominator_value IS NOT NULL;

--need to somehow figure it out
UPDATE ds_stage
SET numerator_unit = '{cells}' -- M cells
WHERE numerator_unit IS NULL
	AND amount_unit IS NULL
	AND drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		JOIN drug_concept_stage ON concept_code = drug_concept_code
			AND concept_name ilike '%strain%'
		);

UPDATE ds_stage
SET numerator_unit = '[hp_C]'
WHERE numerator_unit IS NULL
	AND amount_unit IS NULL;

--quant homeopathy shouldn't exist without denominator_value
UPDATE ds_stage
SET denominator_unit = NULL
WHERE denominator_value IS NULL
	AND numerator_unit IN (
		'[hp_X]',
		'[hp_C]'
		);

--Fix solid forms with denominator
UPDATE ds_stage
SET amount_unit = numerator_unit,
	amount_value = numerator_value,
	numerator_value = NULL,
	numerator_unit = NULL,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE numerator_unit IN (
				'[hp_X]',
				'[hp_C]'
				)
		)
	AND drug_concept_code IN (
		SELECT a.concept_code
		FROM drug_concept_stage a
		WHERE (
				concept_name LIKE '%Tablet%'
				OR concept_name LIKE '%Capsule%'
				OR concept_name LIKE '%Suppositor%'
				OR concept_name LIKE '%Lozenge%'
				OR concept_name LIKE '%Pellet%'
				OR concept_name LIKE '%Granules%'
				OR concept_name LIKE '%Powder%'
				) -- solid forms defined by their forms
		);

--also fixing those that are Components
UPDATE ds_stage
SET amount_unit = numerator_unit,
	amount_value = numerator_value,
	numerator_value = NULL,
	numerator_unit = NULL,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE drug_concept_code IN (
		SELECT c2.concept_code
		FROM drug_strength
		JOIN concept c ON drug_concept_id = c.concept_id
		JOIN concept_ancestor ON drug_concept_id = descendant_concept_id
		JOIN concept c2 ON c2.concept_id = ancestor_concept_id
			AND c2.concept_class_id IN (
				'Clinical Drug Comp',
				'Branded Drug Comp'
				)
		WHERE numerator_unit_concept_id IN (
				9325,
				9324
				)
			AND (
				c.concept_name LIKE '%Tablet%'
				OR c.concept_name LIKE '%Capsule%'
				OR c.concept_name LIKE '%Suppositor%'
				OR c.concept_name LIKE '%Lozenge%'
				OR c.concept_name LIKE '%Pellet%'
				OR c.concept_name LIKE '%Granules%'
				OR c.concept_name LIKE '%Powder%'
				)
		);

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP995215'
WHERE ingredient_concept_code = 'OMOP1131419';--Acetarsol

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP995215'
WHERE ingredient_concept_code = 'OMOP1000382';--Bilastine

UPDATE ds_stage
SET ingredient_concept_code = '1895'
WHERE ingredient_concept_code = 'OMOP2721034';--Calcium

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP994745'
WHERE ingredient_concept_code = 'OMOP1131501';--Camphene

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP1001875'
WHERE ingredient_concept_code = 'OMOP1131504';--Carbetocin

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP998052'
WHERE ingredient_concept_code = 'OMOP1131611';--manna

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP991296'
WHERE ingredient_concept_code = 'OMOP1131633';--Oxetacaine

UPDATE ds_stage
SET ingredient_concept_code = '8588'
WHERE ingredient_concept_code = 'OMOP2721400';--Potassium

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP1131662'
WHERE ingredient_concept_code = 'OMOP997623';--Rupatadine Fumarate

UPDATE ds_stage
SET ingredient_concept_code = '9853'
WHERE ingredient_concept_code = 'OMOP2721452';--Sodium

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP1001157'
WHERE ingredient_concept_code = 'OMOP1131687';--Stiripentol

--IRS
--insert missing ingredients
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT concept_code,
	'4850'
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Ingredient'
		)
	AND concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		)
	AND concept_class_id = 'Drug Product'
	AND concept_name LIKE '%Glucose%';

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT concept_code,
	'9853'
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Ingredient'
		)
	AND concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		)
	AND concept_class_id = 'Drug Product'
	AND concept_name LIKE '%Sodium%';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP995215'
WHERE concept_code_2 = 'OMOP1131419';--Acetarsol

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP995215'
WHERE concept_code_2 = 'OMOP1000382';--Bilastine

UPDATE internal_relationship_stage
SET concept_code_2 = '1895'
WHERE concept_code_2 = 'OMOP2721034';--Calcium

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP994745'
WHERE concept_code_2 = 'OMOP1131501';--Camphene

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1001875'
WHERE concept_code_2 = 'OMOP1131504';--Carbetocin

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP998052'
WHERE concept_code_2 = 'OMOP1131611';--manna

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP991296'
WHERE concept_code_2 = 'OMOP1131633';--Oxetacaine

UPDATE internal_relationship_stage
SET concept_code_2 = '8588'
WHERE concept_code_2 = 'OMOP2721400';--Potassium

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1131662'
WHERE concept_code_2 = 'OMOP997623';--Rupatadine Fumarate

UPDATE internal_relationship_stage
SET concept_code_2 = '9853'
WHERE concept_code_2 = 'OMOP2721452';--Sodium

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1001157'
WHERE concept_code_2 = 'OMOP1131687';--Stiripentol

-- change drug form to gas
UPDATE internal_relationship_stage
SET concept_code_2 = '316999'
WHERE concept_code_2 = '346161'
	AND concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name ~ 'ML.*%.*Inhalant Solution'
		);

--all the supplier work
DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT a.concept_code
		FROM drug_concept_stage a
		JOIN drug_concept_stage b ON a.concept_name = b.concept_name
			AND a.concept_class_id = 'Brand Name'
			AND b.concept_class_id IN (
				'Supplier',
				'Ingredient'
				)
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Supplier'
			AND concept_name LIKE '%Imported%'
		);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Supplier'
			AND concept_name LIKE '%Imported%'
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT dcs.concept_code
		FROM drug_concept_stage dcs
		JOIN concept c ON lower(dcs.concept_name) = lower(c.concept_name)
			AND c.vocabulary_id = 'RxNorm'
			AND dcs.concept_class_id = 'Brand Name'
			AND c.concept_class_id = 'Ingredient'
		);

--real BN
DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name IN (
				'Ultracare',
				'Ultrabalance',
				'Tussin',
				'Triad',
				'Aplicare',
				'Lactaid'
				)
			AND concept_class_id = 'Supplier'
		);

--semi-manual
UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1017600'
WHERE concept_code_2 = 'OMOP1017607';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1017607';

UPDATE internal_relationship_stage
SET concept_code_2 = '220323'
WHERE concept_code_2 = 'OMOP1016513';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1016513';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1018323'
WHERE concept_code_2 = 'OMOP1018324';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1018324';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP440130'
WHERE concept_code_2 = 'OMOP1018429';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1018429';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1018685'
WHERE concept_code_2 = 'OMOP1018686';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1018686';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP572515'
WHERE concept_code_2 = 'OMOP1018691';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1018691';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP339439'
WHERE concept_code_2 = 'OMOP338286';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP338286';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP338031'
WHERE concept_code_2 = 'OMOP1018618';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1018618';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP440349'
WHERE concept_code_2 = 'OMOP440208';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP440208';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1019137'
WHERE concept_code_2 = 'OMOP1019138';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019138';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP440416'
WHERE concept_code_2 = 'OMOP440408';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP440408';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP440149'
WHERE concept_code_2 = 'OMOP1019102';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019102';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP897383'
WHERE concept_code_2 = 'OMOP897539';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP897539';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1018819'
WHERE concept_code_2 = 'OMOP2018692';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP2018692';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP337929'
WHERE concept_code_2 = 'OMOP1019418';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019418';

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		'OMOP2018741',
		'OMOP440362'
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		'OMOP2018741',
		'OMOP440362'
		);

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP897860'
WHERE concept_code_2 = 'OMOP1019590';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019590';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP339047'
WHERE concept_code_2 = 'OMOP1019539';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019539';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1017600'
WHERE concept_code_2 = 'OMOP1017607';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1017607';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP440424'
WHERE concept_code_2 = 'OMOP339350';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP339350';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP440068'
WHERE concept_code_2 = 'OMOP337877';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP337877';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP898387'
WHERE concept_code_2 = 'OMOP898911';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP898911';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP439969'
WHERE concept_code_2 = 'OMOP337870';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP337870';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1019538'
WHERE concept_code_2 = 'OMOP338727';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP338727';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP439969'
WHERE concept_code_2 = 'OMOP337870';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP337870';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP339321'
WHERE concept_code_2 IN (
		'OMOP1018727',
		'OMOP440341'
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		'OMOP1018727',
		'OMOP440341'
		);

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1018327'
WHERE concept_code_2 = 'OMOP338814';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP338814';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP337838'
WHERE concept_code_2 = 'OMOP1019712';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019712';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP338930'
WHERE concept_code_2 = 'OMOP440306';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP440306';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP339321'
WHERE concept_code_2 IN ('OMOP897524');

DELETE
FROM drug_concept_stage
WHERE concept_code IN ('OMOP897524');

--fix packs
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
SELECT c2.concept_code,
	c.concept_code,
	CASE 
		WHEN c2.concept_name LIKE '%24%'
			THEN 4
		ELSE 7
		END
FROM concept c
JOIN concept_relationship cr ON c.concept_id = concept_id_1
	AND cr.relationship_id = 'Has brand name'
	AND cr.invalid_reason IS NULL
JOIN concept_relationship cr2 ON cr.concept_id_2 = cr2.concept_id_1
	AND cr2.relationship_id = 'Has brand name'
	AND cr.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_id = cr2.concept_id_2
	AND c2.vocabulary_id = 'RxNorm Extension'
WHERE c.concept_name LIKE 'Inert%'
	AND c.vocabulary_id = 'RxNorm Extension'
	AND c.concept_class_id = 'Branded Drug Form'
	AND c2.concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--somehow active pack_comp has amount=7 instead of 21
UPDATE pc_stage
SET amount = 21
WHERE pack_concept_code IN (
		'OMOP573433',
		'OMOP573537',
		'OMOP573357',
		'OMOP573533',
		'OMOP572820',
		'OMOP573009',
		'OMOP1131307',
		'OMOP1131349',
		'OMOP1131350'
		)
	AND drug_concept_code != '748796';

--Linessa 28
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP1131349',
	'748796',
	7
	);

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP573433',
	'748796',
	7
	);

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP573537',
	'748796',
	7
	);

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP573357',
	'748796',
	7
	);

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP1131350',
	'748796',
	7
	);

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP573533',
	'748796',
	7
	);

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP1131307',
	'748796',
	7
	);

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP572820',
	'748796',
	7
	);

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
VALUES (
	'OMOP573009',
	'748796',
	7
	);

--RTC
DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT dcs.concept_code
		FROM drug_concept_stage dcs
		JOIN concept c ON lower(dcs.concept_name) = lower(c.concept_name)
			AND c.vocabulary_id = 'RxNorm'
			AND c.invalid_reason IS NULL
			AND dcs.concept_class_id = 'Brand Name'
			AND c.concept_class_id = 'Brand Name'
			AND dcs.concept_code != c.concept_code
		);

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence
	)
SELECT dcs.concept_code,
	'Rxfix',
	c.concept_id,
	1
FROM drug_concept_stage dcs
JOIN concept c ON lower(dcs.concept_name) = lower(c.concept_name)
	AND c.vocabulary_id = 'RxNorm'
	AND c.invalid_reason IS NULL
	AND dcs.concept_class_id = 'Brand Name'
	AND c.concept_class_id = 'Brand Name'
	AND dcs.concept_code != c.concept_code;;

UPDATE relationship_to_concept
SET concept_id_2 = 19089602
WHERE concept_code_1 = 'OMOP1004367';

UPDATE relationship_to_concept
SET concept_id_2 = 1539954
WHERE concept_code_1 = 'OMOP1131570';

UPDATE relationship_to_concept
SET concept_id_2 = 1505346
WHERE concept_code_1 = 'OMOP1000349';

UPDATE relationship_to_concept --inj susp
SET concept_id_2 = 19082260
WHERE concept_code_1 = 'OMOP1007430';

UPDATE relationship_to_concept --Intravenous Suspension
SET concept_id_2 = 19095915
WHERE concept_code_1 = 'OMOP1007431';

UPDATE relationship_to_concept
SET concept_id_2 = 19082198 --Rectal Powder
WHERE concept_code_1 = 'OMOP1007432';

--ingredients
UPDATE RELATIONSHIP_TO_CONCEPT
SET concept_id_2 = 35604657
WHERE concept_code_1 = 'OMOP1131431';

UPDATE relationship_to_concept
SET concept_id_2 = 43532537
WHERE concept_code_1 = 'OMOP1005778';

UPDATE relationship_to_concept
SET concept_id_2 = 44784806
WHERE concept_code_1 = 'OMOP997397';

UPDATE relationship_to_concept
SET concept_id_2 = 1352213
WHERE concept_code_1 = 'OMOP2721447';

UPDATE relationship_to_concept
SET concept_id_2 = 1505346
WHERE concept_code_1 = 'OMOP1000349';

UPDATE relationship_to_concept
SET concept_id_2 = 19137312
WHERE concept_code_1 = 'OMOP2721489';

UPDATE relationship_to_concept
SET concept_id_2 = 46221433
WHERE concept_code_1 = 'OMOP1131599';

UPDATE relationship_to_concept
SET concept_id_2 = 1539954
WHERE concept_code_1 = 'OMOP1131570';

UPDATE relationship_to_concept
SET concept_id_2 = 35605804
WHERE concept_code_1 = 'OMOP1131529';

UPDATE relationship_to_concept
SET concept_id_2 = 35604657
WHERE concept_code_1 = 'OMOP1131431';

UPDATE relationship_to_concept
SET concept_id_2 = 42903942
WHERE concept_code_1 = 'OMOP2721481';

--additional suppl work
DROP TABLE IF EXISTS irs_suppl;
CREATE TABLE irs_suppl AS
SELECT irs.concept_code_1,
	CASE 
		WHEN s.concept_code_2 IS NOT NULL
			THEN s.concept_code_2
		ELSE irs.concept_code_2
		END AS concept_code_2
FROM internal_relationship_stage irs
LEFT JOIN suppliers_to_repl s ON s.concept_code_1 = irs.concept_code_2;

TRUNCATE TABLE internal_relationship_stage;

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code_1,
	concept_code_2
FROM irs_suppl;


--Suppl+BN

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT b.concept_code
		FROM drug_concept_stage a
		JOIN drug_concept_stage b ON lower(a.concept_name) = lower(b.concept_name)
			AND a.concept_class_id = 'Supplier'
			AND b.concept_class_id = 'Brand Name'
		)
	AND concept_code_2 NOT IN (
		'OMOP881621',
		'OMOP335576'
		)
	AND concept_code_2 LIKE '%OMOP%';

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT b.concept_code
		FROM drug_concept_stage a
		JOIN drug_concept_stage b ON lower(a.concept_name) = lower(b.concept_name)
			AND a.concept_class_id = 'Supplier'
			AND b.concept_class_id = 'Brand Name'
		)
	AND concept_code NOT IN (
		'OMOP881621',
		'OMOP335576'
		)
	AND concept_code LIKE '%OMOP%';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP1018666' --DEl
WHERE concept_code_2 = 'OMOP1018667';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1018667';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP440135'
WHERE concept_code_2 = 'OMOP440228';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP440228';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP897860' --menarini
WHERE concept_code_2 = 'OMOP1019590';

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019590';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP439865'
WHERE concept_code_2 = 'OMOP1019692';--servier

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019692';

UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP337896'
WHERE concept_code_2 = 'OMOP1019636';--Taro

DELETE
FROM drug_concept_stage
WHERE concept_code = 'OMOP1019636';

DROP TABLE IF EXISTS irs_bn;
CREATE TABLE irs_bn AS
SELECT irs.concept_code_1,
	CASE 
		WHEN s.cc2 IS NOT NULL
			THEN s.cc2
		ELSE irs.concept_code_2
		END AS concept_code_2
FROM internal_relationship_stage irs
LEFT JOIN (
	SELECT b.concept_code AS cc1,
		a.concept_code AS cc2
	FROM drug_concept_stage a
	JOIN drug_concept_stage b ON lower(a.concept_name) = lower(b.concept_name)
		AND a.concept_code < b.concept_code
		AND a.concept_class_id = 'Brand Name'
		AND b.concept_class_id = 'Brand Name'
	) s ON s.cc1 = irs.concept_code_2;

TRUNCATE TABLE internal_relationship_stage;

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code_1,
	concept_code_2
FROM irs_bn;

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT b.concept_code
		FROM drug_concept_stage a
		JOIN drug_concept_stage b ON lower(a.concept_name) = lower(b.concept_name)
			AND a.concept_code < b.concept_code
			AND a.concept_class_id = 'Brand Name'
			AND b.concept_class_id = 'Brand Name'
		);

--Merck KG
UPDATE internal_relationship_stage
SET concept_code_2 = 'OMOP339289'
WHERE concept_code_2 = 'OMOP1018908'
	AND concept_code_1 IN (
		'OMOP759641',
		'OMOP759638',
		'OMOP759635',
		'OMOP759905',
		'OMOP759907',
		'OMOP760169',
		'OMOP760171',
		'OMOP517968',
		'OMOP427799'
		);
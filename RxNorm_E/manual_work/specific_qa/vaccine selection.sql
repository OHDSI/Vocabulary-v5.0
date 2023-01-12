DROP TABLE dev_rxe.vaccine_inclusion;

CREATE TABLE dev_rxe.vaccine_inclusion AS (
SELECT
        --general
        'vaccine|virus|Microb|Micr(o|)org|(?<!(anti(| |\-)))Bacter|Booster|antigen|serum|sera|antiserum|globin|globulin|strain|antibody|conjugate|split|live|attenuate|Adjuvant|cellular|inactivate|antitoxin|toxoid|Rho|whole( |-|)cell|polysaccharide'
        || '|' ||
        --vaccine abbrevations
        'DTaP|dTpa|tDPP|Tdap|MMR'
        || '|' ||
        -- influenza
        'influenza|Grippe|Gripe|Orthomyxov|flu$|H(a|)emagglutinin|Neuraminidase|(h\d{1,2}n\d{1,2}(?!\d))|IIV|LAIV'
        || '|' ||
        --botulism
        'botuli|Clostrid|Klostrid|C( )*(\.)?( )*botu'
        || '|' ||
        --gas-gangrene
        '(Gas).*(Gangrene)|(Gangrene).*(Gas)|C( )*(\.)?( )*perf|perfringens|novyi|C( )*(\.)?( )*novy|septicum|C( )*(\.)?( )*septic|ramnosum|C( )*(\.)?( )*ramnos'
        || '|' ||
        --staphylococcus
        'staphyloc|aureus|S( )*(\.)?( )*aure|epidermidis|S( )*(\.)?( )*epiderm'
        || '|' ||
        --cytomegalovirus
        'cytomegalov|cmv|herpes|HHV'
        || '|' ||
        --Coxiella Burnetii
        'Coxiella|burneti|C( )*(\.)?( )*burn|Q( |-|)fever'
        || '|' ||
        --anthrax
        'anthrax|antrax|Bacil|anthracis|B( )*(\.)?( )*ant(h|)rac'
        || '|' ||
        --brucella
        'brucel|(undulant|Mediterranean|Bang).*(fever|disease)|(fever|disease).*(undulant|Mediterranean|Bang)|melitensis|B( )*(\.)?( )*melit|abortus|B( )*(\.)?( )*abort'
        || '|' ||
        --rubella
        'rubella|RuV|Rubiv|Togav|Wistar|(RA).*(27).*(3)'
        || '|' ||
        --mumps
        'mumps|rubulavirus|Jeryl|Lynn'
        || '|' ||
        --measles
        'measles|morbilliv|morbiliv|MeV|Ender|Edmonston'
        || '|' ||
        --poliomyelitis
        'polio|Enterovi|Mahoney|MEF( |-|)1|Saukett|Sabin|IPV|OPV'
        || '|' ||
        --diphtheria
        'dipht|Coryne|Corine|C( )*(\.)?( )*Dipth'
        || '|' ||
        --tetanus
        'tetan(us|i)|C( )*(\.)?( )*tetan|Clostrid|Klostrid'
        || '|' ||
        --pertussis
        'pertuss|Bordat|B( )*(\.)?( )*pert|Pertactin|Fimbri(a|)e|Filamentous'
        || '|' ||
        --hepatitis B
        'hepat|HBV|Orthohepad|Hepadn|ADW2|HBSAG|CpG|HepB|HBIG|Hepa( |-|)Gam'
        || '|' ||
        --hemophilus influenzae B
        'h(a|)emophilus|influenz|hib|H( )*(\.)?( )*inf|Ross|HbOC|PRP(-| |)OMP|PRP(-| |)T|PRP(-| |)D'
        || '|' ||
        --Neisseria
        'mening|N( )*(\.)?( )*men|Neiss|CRM197|MenB|MenC(-| |)TT|MenY(-| |)TT|MenD|MenAC|MenCY|PsA(-| |)TT|MenACWY|MPSV|MCV|Adhesin( |-|)A|Factor( |-|)H|Membrane Vesicle'
        || '|' ||
        --rabies
        'rabies|rhabdo|rabdo|lyssav|PM( |-|)1503|1503( |-|)3M'
        || '|' ||
        --papillomavirus
        'papilloma|HPV'
        || '|' ||
        --smallpox
        'smallpox|small-pox|Variola|Poxv|Orthopoxv|Vaccinia|VACV|VV|Cowpox|Monkeypox|Dryvax|Imvamune|ACAM2000|Calf lymph'
        || '|' ||
        --yellow fever
        'Yellow Fever|Yellow-Fever|Flaviv|17D( |-|)204'
        || '|' ||
        --varicella/zoster
        'varicel|zoster|herpes|chickenpox|VZV|HHV|chicken-pox|(Oka).*(Merck)|ZVL|RZV|VAR'
        || '|' ||
        --rota virus
        'rota( |-|)v|Reov|RV1|RV5'
        || '|' ||
        --hepatitis A
        'hepat|HAV|HM175|HepA'
        || '|' ||
        --typhoid
        't(y|i)ph|Salmone|S( )*(\.)?( )*t(y|i)|S\.e|S\. e|Ty21|ty( |-|)2'
        || '|' ||
        --encephalitis
        'encephalitis|tick|Flaviv|Japanese'
        || '|' ||
        --typhus exanthematicus
        'typhus|exanthematicus|Rickettsia|prowaz|R( )*(\.)?( )*pro(w|v)|Orientia|tsutsug|O( )*(\.)?( )*tsu|R( )*(\.)?( )*t(y|i)p|felis|typhi|R( )*(\.)?( )*fel'
        || '|' ||
        --tuberculosis
        'tuberc|M( )*(\.)?( )*tub|M( )*(\.)?( )*bov|M( )*(\.)?( )*afr|mycobacterium|bcg|Calmet|Guerin|bovis|africanum|Tice|Connaught|Montreal'
        || '|' ||
        --pneumococcus
        'pneumo|S( )*(\.)?( )*pn|PCV|PPSV'
        || '|' ||
        --plague
        'plague|Yersinia|Y( )*(\.)?( )*pes'
        || '|' ||
        --cholera
        'choler|Vibri|V( )*(\.)?( )*cho|Inaba|Ogawa' as vaccine_inclusion
);
-- mapping icd10pcs to SNOMED through concept_attributes:
truncate table icd10pcs_split;
--drop table icd10pcs_split;
create table icd10pcs_split (
concept_code varchar(20),
    concept_name varchar(255),
    method varchar(255),
    procedure_site varchar(255),
    access varchar(255),
    object varchar(255)
        );

insert into icd10pcs_split (select distinct concept_code, concept_name,
       lower(split_part(concept_synonym_name, ' @ ', 3)) as method,
       lower(split_part(concept_synonym_name, ' @ ', 4)) as procedure_site,
       lower(split_part(concept_synonym_name, ' @ ', 5)) as access,
       lower(split_part(concept_synonym_name, ' @ ', 6)) as object
    from concept_synonym s
    join concept c using(concept_id)
where c.concept_class_id = 'ICD10PCS'
and c.standard_concept = 'S');

update icd10pcs_split
    set method = case when method = 'alteration' then 'surgical action'
    when method = 'assessment' then 'evaluation'
    when method = 'caregiver training' then 'training'
    when method = 'change' then 'replacement'
    when method = 'computerized tomography (ct scan)' then 'computed tomography imaging'
    when method = 'control' then 'inspection'
    when method = 'creation' then 'surgical action'
    when method = 'family counseling' then 'counseling'
    when method = 'fluoroscopy' then 'fluoroscopic imaging'
    when method = 'group counseling' then 'counseling'
    when method = 'individual counseling' then 'counseling'
    when method = 'light therapy' then 'phototherapy'
    when method = 'magnetic resonance imaging (mri)' then 'magnetic resonance imaging'
    when method = 'medication management' then 'management'
    when method = 'motor and/or Nerve function assessment' then 'evaluation'
    when method = 'motor treatment' then 'rehabilitation'
    when method = 'other radiation' then 'brachytherapy'
    when method = 'other imaging' then 'imaging'
    when method = 'pharmacotherapy' then 'administration'
    when method = 'plain radiography' then 'plain X-ray imaging'
    when method = 'planar Nuclear medicine imaging' then 'radionuclide imaging'
    when method = 'positron emission tomographic (pet) imaging' then 'positron emission tomographic imaging'
    when method = 'psychological tests' then 'assessment'
    when method = 'reposition' then 'repositioning'
    when method = 'restoration' then 'restore'
    when method = 'speech treatment' then 'rehabilitation'
    when method = 'tomographic (tomo) Nuclear medicine imaging' then 'tomographic imaging'
    when method = 'transfer' then 'surgical transfer'
    when method = 'ultraviolet light therapy' then 'phototherapy'
    when method = 'vestibular treatment' then 'rehabilitation'
    when method = 'vestibular assessment' then 'evaluation'
    when method = 'speech assessment' then 'evaluation'
else method end;

truncate table snomed_split;
--drop table snomed_split;
create table snomed_split (
      concept_code varchar(20),
    concept_name varchar(255),
    method varchar(255),
    procedure_site varchar(255),
    access varchar(255),
    object varchar(255)
);
insert into snomed_split (select --c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       lower(regexp_replace(c2.concept_name, ' - action', '')) as method,
       lower(regexp_replace(c3.concept_name, ' structure', '')) as procedure_site,
       lower(regexp_replace(c4.concept_name, ' approach', '')) as access,
       lower(c5.concept_name) as object
from concept c1
left join concept_relationship cr2 on c1.concept_id = cr2.concept_id_1 and cr2.relationship_id = 'Has method' and cr2.invalid_reason is null
left join concept_relationship cr3 on c1.concept_id = cr3.concept_id_1 and cr3.relationship_id in ('Has proc site', 'Has dir proc site', 'Has indir proc site') and cr3.invalid_reason is null
left join concept_relationship cr4 on c1.concept_id = cr4.concept_id_1 and cr4.relationship_id in ('Has access') and cr4.invalid_reason is null
left join concept_relationship cr5 on c1.concept_id = cr5.concept_id_1 and cr5.relationship_id in ('Using device',
                                                                                                   'Has dir device',
                                                                                                  'Has dir subst',
                                                                                                  'Using subst',
                                                                                                  'Has property',
                                                                                                  'Using energy') and cr5.invalid_reason is null
left join concept c2 on c2.concept_id = cr2.concept_id_2
left join concept c3 on c3.concept_id = cr3.concept_id_2
left join concept c4 on c4.concept_id = cr4.concept_id_2
left join concept c5 on c5.concept_id = cr5.concept_id_2
where c1.vocabulary_id = 'SNOMED'
and c1.standard_concept = 'S'
and c1.domain_id in ('Procedure', 'Observation', 'Measurement')
);

update snomed_split
set method = case when method in ('ablation', 'cryoablation', 'chemical destruction', 'radioactive destruction') then 'destruction'
    when method like '%ultrasound' or method = 'ultrasound imaging' then 'ultrasonography'
    when method = 'ultrasound' then 'ultrasound therapy'
    when method = 'administration' and concept_name ilike '%beam%' then 'ultrasound therapy'
    when method = 'amputation' then 'detachment'
    when method = 'anchoring' and concept_name not ilike '%endovascular%' and procedure_site is not null then 'reattachment'
    when method = 'anastomosis' then 'bypass'
    when method = 'apheresis' then 'pheresis'
    when method = 'application' and object ~* 'brace|cast|pin|spica|immobilizer|splint|sling|fixation|strap' then 'immobilization'
    when method = 'application' and object = 'pressure bandage' then 'compression'
    when method = 'application' and object ~* 'dressing|gauze|hosiery|bandag' then 'dressing'
    when method = 'application' and object ~* 'prosthesis|orthotic' then 'device fitting'
    when method = 'application' and object ~* 'traction' then 'traction'
    when method = 'application' and object ~* 'clamp' then 'occlusion'
    when method = 'application' and object ~* 'electrode' then 'insertion'
    when method = 'application of substance'
        or (method = 'application' and object = 'Hemostatic agent')
        or method = 'administration'
           then 'introduction'
    when method = 'termination' then 'abortion'
    when method = 'surgical action' and concept_name ilike '%revision%' then 'revision'
    when method = 'surgical action' and concept_name ~* 'conduit|shunt' then 'bypass'
    when method = 'surgical action' and concept_name ilike '%transposition%' then 'transposition'
    when method = 'surgical action' and concept_name ~* 'extraction|cataract' then 'extraction'
    when method = 'surgical action' and concept_name ilike '%ectomy%' then 'resection'
    when method = 'surgical action' and concept_name ilike '%ablarion%' then 'destruction'
    when method = 'surgical action' and concept_name ilike '%angioplasty%' then 'dilation'
    when method = 'surgical action' and concept_name ilike '%transplantation%' then 'transplantation'
    when method = 'surgical action' and concept_name ~* 'repair|plasty' then 'repair'
    when method is null and concept_name ~* 'electroconvulsive' then 'electroconvulsive therapy'
    when method is null and concept_name ~* 'electromagnetic' then 'electromagnetic therapy'
    when method = 'evaluation' and concept_name ~* 'hearing' and concept_name ~* 'aid' then 'Hearing aid assessment'
    when method = 'evaluation' and concept_name ~* 'hearing' then 'Hearing assessment'
    when method = 'evaluation' and concept_name ~* 'mapping' then 'map'
    when method = 'insertion' and concept_name ~* 'packing' then 'packing'
    when method is null and concept_name ~* 'hyperthermia' then 'Hyperthermia'
    when method is null and concept_name ~* 'hypnosis' then 'Hypnosis'
    when method is null and concept_name ~* 'hypothermia' then 'Hypothermia'
    when method is null and concept_name ~* 'phototherapy|light therapy' then 'phototherapy'
    when method is null and concept_name ~* 'rehabilitation' then 'rehabilitation'
    else method end
;

-- Procedure site

update snomed_split
set procedure_site = regexp_replace(procedure_site ,'structure of ', '')
where procedure_site like 'structure of%';

update snomed_split
set procedure_site = regexp_replace(procedure_site ,'entire ', '')
where procedure_site like 'entire%';

update snomed_split
set procedure_site = regexp_replace(procedure_site ,'left ', '')
where procedure_site not ilike '%ventricular%'
and procedure_site not ilike '%atrial%'
and procedure_site not ilike '%heart%';

update snomed_split
set procedure_site = regexp_replace(procedure_site ,'right ', '')
where procedure_site not ilike '%ventricular%'
and procedure_site not ilike '%atrial%'
and procedure_site not ilike '%heart%';

update icd10pcs_split
set procedure_site = regexp_replace(procedure_site ,', right', '')
where procedure_site not ilike '%ventricle%'
and procedure_site not ilike '%atrium%'
and procedure_site not ilike '%heart%'
;

update icd10pcs_split
set procedure_site = regexp_replace(procedure_site ,', left', '')
where procedure_site not ilike '%ventricle%'
and procedure_site not ilike '%atrium%'
and procedure_site not ilike '%heart%'
;

update icd10pcs_split
set procedure_site = regexp_replace(procedure_site ,', bilateral', '')
where procedure_site not ilike '%ventricle%'
and procedure_site not ilike '%atrium%'
and procedure_site not ilike '%heart%'
;

update snomed_split
set procedure_site = regexp_replace(procedure_site ,'phalanx of ', '')
where procedure_site ilike '%toe%';


update icd10pcs_split
set procedure_site = case when procedure_site like 'abdomen bursa and ligament%' then 'soft tissue of abdomen'
    when procedure_site like 'abdomen muscle%' then 'skeletal muscle of abdomen'
    when procedure_site like 'abdomen tendon%'
        or procedure_site like 'perineum tendon'
        or procedure_site like 'trunk tendon'
        then 'tendon of trunk'
    when procedure_site like 'acromioclavicular joints' then 'acromioclavicular joint'
    when procedure_site like 'adenoids' then 'adenoidal'
    when procedure_site like 'adrenal glands' then 'adrenal gland'
    when procedure_site like 'anal sphincter' then 'sphincter ani muscle'
    when procedure_site like 'anterior chamber' then 'anterior chamber of eye'
    when procedure_site like 'auditory ossicle' then 'ear ossicle'
    when procedure_site like 'axilla' then 'axillary region'
    when procedure_site like 'azygos vein' then 'azygous vein'
    when procedure_site like 'basal ganglia' then 'basal ganglion'
    when procedure_site like 'bile ducts' then 'bile duct'
    when procedure_site like '%biliary%' then 'biliary tract'
    when procedure_site like 'bladder neck' then 'neck of urinary bladder'
    when procedure_site like 'bladder%' and method like 'insertion' then 'urinary system'
    when procedure_site like 'bladder%' and method not like 'insertion' then 'urinary bladder'
    when procedure_site like 'blood' then 'hematological system'
    when procedure_site like 'bone marrow%' then 'bone marrow'
    when procedure_site like 'bones'
        or procedure_site like 'other bone'
        then 'bone'
    when procedure_site like 'occipital bone'
        or procedure_site like 'parietal bone'
        or procedure_site like 'sphenoid bone'
        then 'facial bone'
    when procedure_site like 'lower bone' then 'bone of lower limb'
    when procedure_site like 'upper bone' then 'bone of upper limb'
    when procedure_site like 'facial bones' then 'facial bone'
    when procedure_site like 'brachiocephalic-subclavian artery' then 'brachiocephalic artery'
    when procedure_site like 'breast%' then 'breast'
    when procedure_site like 'cardiac%' then 'heart'
    when procedure_site like 'carina' then 'carina of trachea'
    when procedure_site like 'carotid bodies' then 'carotid body'
    when procedure_site like 'central nervous%' then 'central nervous system'
    when procedure_site like 'central vein%' then 'systemic venous'
    when procedure_site like 'central arter%' then 'systemic arterial'
    when procedure_site like 'cerebellum' then 'cerebellar'
    when procedure_site like 'cerebral and cerebellar veins' then 'cerebral vein'
    when procedure_site like 'cerebral ventricle%' then 'brain ventricle'
    when procedure_site like 'cerebral meninges' then 'brain meninges'
    when procedure_site like 'cervical' then 'neck'
    when procedure_site like 'spinal meninges' then 'spinal cord meninges'
    when procedure_site like 'cervical disc%'
        or procedure_site like 'cervical vertebral disc'
        then 'cervical intervertebral disc'
    when procedure_site like '%thoracic%' and procedure_site like '%disc%' then 'thoracic intervertebral disc'
    when procedure_site like '%lumb%' and procedure_site like '%disc%' then 'lumbar intervertebral disc'
    when procedure_site like 'cervical facet joint%' then 'facet joint of cervical spine'
    when procedure_site like 'cervical spine' then 'cervical vertebral column'
    when procedure_site like 'cervical vertebra' then 'bone of cervical vertebra'
    when procedure_site like 'cervical vertebral joint%' then 'joint of cervical vertebra other than atlas or axis'
    when procedure_site like 'occipital-cervical joint' then 'atlantooccipital joint'
    when procedure_site like 'cervicothoracic vertebral joint' then 'cervicothoracic junction of vertebral column'
    when procedure_site like 'lumbar vertebra' then 'bone of lumbar vertebra'
    when procedure_site like 'lumbar vertebral joint%' then 'lumbar spine joint'
    when procedure_site like 'lumbar facet joint%' then 'facet joint of lumbar spine'
    when procedure_site like 'thoracolumbar%' and procedure_site like '%joint%' then 'joint of thoracolumbar junction of spine'
    when procedure_site like 'thoracolumbar spine' then 'thoracolumbar region of spine'
    when procedure_site like 'lumbar arter%' then 'lumbar artery'
    when procedure_site like 'cervical plexus'
        or procedure_site like 'sacral plexus'
        then 'nerve plexus'
    when procedure_site like 'cervix' then 'cervix uteri'
    when procedure_site like '%uterus%' then 'uterus'
    when procedure_site like 'uterine supporting structure' then 'uterine ligament'
    when procedure_site like 'skin, chest' then 'skin of chest'
    when procedure_site like 'subcutaneous tissue and fascia, chest' then 'subcutaneous tissue of chest'
    when (procedure_site like 'chest%' and procedure_site !~* 'wall')
        or procedure_site like 'fetal thorax'
        then 'thorax'
    when procedure_site like 'thorax muscle'
        or procedure_site like 'thorax tendon'
        then 'soft tissue of thorax'
    when procedure_site like '%fetus' then 'fetus'
    when procedure_site like 'finger nail' then 'nail of finger'
    when procedure_site like 'finger(s)' then 'finger'
    when procedure_site like 'finger phalangeal joint' then 'interphalangeal joint of finger'
    when procedure_site like 'hand/finger joint' then 'interphalangeal joint of finger'
    when procedure_site like 'hand artery' then 'artery of hand'
    when procedure_site like 'hand muscle' then 'muscle of hand'
    when procedure_site like 'hand tendon' then 'tendon within hand'
    when procedure_site like 'hand vein' then 'vascular of hand'
    when procedure_site like 'hand artery' then 'artery of hand'
    when procedure_site like '%hand%' and procedure_site like '%skin%' then 'skin of hand'
    when procedure_site like 'subcutaneous tissue and fascia hand' then 'hand'
    when procedure_site like 'hand bursa and ligament' then 'bursa of hand'
    when procedure_site like 'hands and wrists' then 'wrist and/or hand'
    when procedure_site like 'face artery' then 'facial artery'
    when procedure_site like 'face vein' then 'vascular of face'
    when procedure_site like 'facial muscle' then 'skeletal muscle of face'
    when procedure_site like 'skin, face' then 'skin of face'
    when procedure_site like 'subcutaneous tissue and fascia, face' then 'subcutaneous tissue of face'
    when procedure_site like 'finger phalanx' then 'bone of phalanx of finger'

    when procedure_site like 'chordae tendineae' then 'chordae tendineae cordis'
    when procedure_site like 'choroid' then 'choroidal'
    when procedure_site like '%circulatory%' then 'systemic circulatory system'
    when procedure_site like 'cisterna' then 'cisterna magna'
    when procedure_site like 'clitoris' then 'clitoral'
    when procedure_site like 'sacrococcygeal joint' then 'joint of sacrococcygeal junction of spine'
    when procedure_site like 'coccygeal joint' then 'joint of coccygeal vertebra'
    when procedure_site like 'sacrum and coccyx' then 'sacrococcygeal region of spine'
    when procedure_site like 'colic artery%' then 'colic artery'
    when procedure_site like 'colic vein%'
        or procedure_site like 'inferior mesenteric vein'
        then 'mesenteric vein'
    when procedure_site like 'celiac and mesenteric arteries' then 'mesenteric artery'
    when procedure_site like 'colic artery, middle' then 'middle colic artery'
    when procedure_site like 'conjunctiva' then 'conjunctival'
    when procedure_site like 'connective tissue, lower extremity' then 'lower limb'
    when procedure_site like 'connective tissue, upper extremity'
        or procedure_site like 'extremity, upper'
        then 'upper limb'
    when procedure_site like 'cornea' then 'cornea of eye'
    when procedure_site like 'coronary arter%' and procedure_site !~* 'graft' then 'coronary artery'
    when procedure_site like 'corpora cavernosa' then 'corpus cavernosum of penis'
    when procedure_site like 'cranial cavity%' then 'cranial cavity'
    when procedure_site like '%cul-de-sac%' then 'rectouterine pouch'
    when procedure_site like 'eye%' then 'eye'
    when procedure_site like 'femoral shaft' then 'bone of shaft of femur'
    when procedure_site like 'female reproductive%' then 'female genital'
    when procedure_site like 'fallopian tube%' then 'fallopian tube'
    when procedure_site like 'lower femur' then 'bone of distal femur'
    when procedure_site like 'upper femur' then 'bone of proximal femur'
    when procedure_site like 'elbow' then 'joint of elbow'
    when procedure_site like 'elbow bursa and ligament' then 'bursa of elbow'
    when procedure_site like 'endometrium' then 'endometrial'
    when procedure_site like 'epididymis%' then 'epididymis'
    when procedure_site like 'epidural space, intracranial' then 'cranial epidural space'
    when procedure_site like 'esophagogastric junction' then 'cardioesophageal junction'
    when procedure_site like 'esophagus, lower' then 'abdominal esophagus'
    when procedure_site like 'esophagus, upper' then 'cervical esophagus'
    when procedure_site like 'esophagus, middle' then 'thoracic esophagus'
    when procedure_site like 'eustachian tube' then 'pharyngotympanic tube'
    when procedure_site like 'jugular vein%' then 'pharyngotympanic tube'
    when procedure_site like 'lower extremity vein%' then 'vein of lower limb'
    when procedure_site like 'lower extremity arter%'
        or procedure_site like 'lower arter%'
        then 'arterial'
    when procedure_site like 'lower extremities'
        or procedure_site like 'lower extremity'
        or procedure_site like 'extremity, lower'
        then 'lower limb'
    when procedure_site like 'lower gi'
        or procedure_site like 'lower intestinal tract'
        then 'lower gastrointestinal tract'
    when procedure_site like 'lower leg tendon' then 'tendon within lower leg'
    when procedure_site like 'lower leg muscle'
        or procedure_site like 'lower muscle'
        then 'skeletal muscle of lower limb'
    when procedure_site like 'skin lower leg' then 'skin of lower leg'
    when procedure_site like 'lower tendon'
        or procedure_site like 'tendons, lower extremity'
        then 'tendon within lower limb'
    when procedure_site like 'lower vein' then 'venous system of lower limb'
    when procedure_site like 'lower%' and procedure_site like '%bursa%' then 'bursa of lower limb'
    when procedure_site like 'aorta and bilateral lower extremity arteries' then 'artery of lower limb'
    when procedure_site like 'lip' then 'lip'
    when procedure_site like 'fetal extremities'
        or procedure_site like 'fetal spine'
        then 'fetal'
    when procedure_site like 'fetal umbilical cord' then 'umbilical cord'
    when procedure_site like 'olfactory' then 'olfactory system'
    when procedure_site like 'foot bursa and ligament' then 'bursa of foot'
    when procedure_site like 'foot muscle' then 'muscle of foot'
    when procedure_site like 'foot tendon' then 'tendon within foot'
    when procedure_site like 'subcutaneous tissue and fascia foot' then 'subcutaneous tissue of foot'
    when procedure_site like 'foot vein' then 'vein of lower leg'
    when procedure_site like 'vein'
        or procedure_site like 'veins%'
        then 'venous'
    when procedure_site like 'foot vein' then 'vein of lower leg'
    when procedure_site like 'forequarter' then 'bone of scapula'
    when procedure_site like 'hindquarter' then 'innominate bone'
    when procedure_site like 'gastrointestinal' then 'gastrointestinal tract'
    when procedure_site like 'genitourinary tract' then 'genitourinary system'
    when procedure_site like 'glenoid cavity' then 'glenoid'
    when procedure_site like '%omentum' then 'omentum'
    when procedure_site like 'great vessel' then 'thoracic great vessel'
    when procedure_site like 'head and neck%' then 'head and/or neck'
    when procedure_site like 'subcutaneous tissue and fascia, head and neck' then 'soft tissue of head and/or neck'
    when procedure_site like 'integumentary system%' then 'integumentary system'
    when procedure_site like 'musculoskeletal system%' then 'musculoskeletal system'
    when procedure_site like 'neurological system%' then 'nervous system'
    when procedure_site like 'respiratory system%' then 'respiratory system'
    when procedure_site like 'humeral head' then 'head of humerus'
    when procedure_site like 'head muscle' then 'skeletal muscle of head'
    when procedure_site like 'hepatic duct, common' then 'hepatic duct'
    when procedure_site like 'hip'
        or procedure_site like 'hips'
        then 'hip region'
    when procedure_site like 'hip bursa and ligament' then 'bursa of hip'
    when procedure_site like 'hip joint%' then 'hip joint'
    when procedure_site like 'hip muscle' then 'muscle acting on hip joint'
    when procedure_site like 'lower arm and wrist tendon' then 'tendon within wrist region'
    when procedure_site like 'shoulder tendon' then 'tendon within shoulder or upper arm'
    when procedure_site like 'upper arm tendon' then 'tendon within upper arm'
    when procedure_site like 'tendons, upper extremity'
        or procedure_site like 'upper tendon'
        then 'tendon within upper arm'
    when procedure_site like 'hip tendon'
        or procedure_site like 'knee tendon'
        or procedure_site like 'upper leg tendon'
        then 'tendon within lower limb'
    when procedure_site like 'humeral shaft' then 'bone of shaft of humerus'
    when procedure_site like 'hypogastric vein' then 'iliac vein'
    when procedure_site like 'coronary vein' then 'cardiac vein'
    when procedure_site like 'epidural veins' then 'vein of head'
    when procedure_site like 'external jugular vein' then 'jugular vein'
    when procedure_site like 'lesser saphenous vein' then 'small saphenous vein'
    when procedure_site like 'pelvic (iliac) veins' then 'pelvic vein'
    when procedure_site like 'pulmonary vein%' then 'pulmonary vein great vessel'
    when procedure_site like 'renal vein%' then 'renal vein'
    when procedure_site like 'vertebral vein' then 'spinal vein'
    when procedure_site like 'portal and splanchnic veins' then 'portal vein'
    when procedure_site like 'hypothalamus' then 'cerebrum'
    when procedure_site like 'ileocecal valve' then 'cecum'
    when procedure_site like 'ileal%' and procedure_site like '%loop%' then 'upper urinary system'
    when procedure_site like 'ophthalmic arteries' then 'ophthalmic artery'
    when procedure_site like 'optic foramina' then 'optic canal'
    when procedure_site like 'oral cavity and throat' then 'oral cavity'
    when procedure_site like 'orbit%' then 'orbit proper'
    when procedure_site like 'ova%' then 'ovary'
    when procedure_site like 'pancreatic duct%' then 'pancreatic duct'
    when procedure_site like 'parathyroid%' then 'parathyroid gland'
    when procedure_site like 'parotid gland%' then 'parotid gland'
    when procedure_site like 'pelvic arteries' then 'artery of pelvic region'
    when procedure_site like 'penile arteries' then 'penile artery'
    when procedure_site like 'intracranial arter%' then 'intracranial artery'
    when procedure_site like 'internal mammary artery' then 'artery of thorax'
    when procedure_site like 'intra-abdominal arteries, other' then 'artery of abdomen'
    when procedure_site like 'lower jaw' then 'lower jaw region'
    when procedure_site like 'lower lip' then 'lip'
    when procedure_site like 'lower lung lobe' then 'lower lobe of lung'
    when procedure_site like 'upper lung lobe'
        or procedure_site like 'lung lingula'
         then 'upper lobe of lung'
    when procedure_site like 'lung apices' then 'apex of lung'
    when procedure_site like 'lungs%' then 'lung'
    when procedure_site like 'middle lung lobe' then 'middle lobe of lung'

    when procedure_site ~* 'upper' and procedure_site ~* 'vein' then 'vein of upper limb'
    when procedure_site ~* 'foot' and procedure_site ~* 'skin' then 'skin of foot'
    when procedure_site like 'common carotid arter%' then 'common carotid artery'
    when procedure_site like 'external carotid arter%' then 'external carotid artery'
    when procedure_site like 'internal carotid arter%' then 'internal carotid artery'
    when procedure_site like 'innominate artery%' then 'brachiocephalic artery'
    when procedure_site like 'innominate vein' then 'brachiocephalic vein'
    when procedure_site like 'long bones, all' then 'long bone'
    when procedure_site like 'brain stem' then 'brainstem'
    when procedure_site like 'lacrimal bone' then 'maxillofacial bone'
    when procedure_site like 'nasal bones' then 'nasal bone'
    when procedure_site like 'pelvic bone%' then 'innominate bone'
    when procedure_site like 'temporal bone%' then 'temporal bone'
    when procedure_site like 'fetal abdomen' then 'abdomen'
    when procedure_site like '%gallbladder%' then 'gallbladder'
    when procedure_site like 'skin, abdomen' then 'skin of abdomen'
    when procedure_site like 'subcutaneous tissue and fascia, abdomen' then 'subcutaneous tissue of abdomen'
    when procedure_site like 'subcutaneous tissue, abdomen and pelvis' then 'subcutaneous tissue of abdomen'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'abdomen' then 'lymphatic abdomen'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'upper extremity' then 'lymphatic upper limb'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'lower extremity' then 'lymphatic lower limb'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'head' then 'lymphatic head'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'thorax|chest' then 'thoracic lymphatic duct'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'axillary' then 'lymphatic axillary'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'inguinal' then 'lymphatic inguinal'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'neck' then 'lymphatic neck'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'pelvis|pelvic' then 'lymphatic pelvis'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'mammary' then 'lymphatic mammary'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'mesenter' then 'lymphatic mesenteric'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'retroperitoneal' then 'lymphatic retroperitoneal'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'aort' then 'lymphatic aortic'
    when procedure_site in ('lymphatic and Hematologic system',
                           'lymphatics, trunk') then 'lymphatic system'
    when procedure_site like '1st toe' then 'Hallux'
    when procedure_site like '2nd toe' then 'second toe'
    when procedure_site like '3rd toe' then 'third toe'
    when procedure_site like '4th toe' then 'fourth toe'
    when procedure_site like '5th toe' then 'lesser toe'
    when procedure_site ilike '%toe%' and procedure_site ~* 'nail' then 'nail of toe'
    when procedure_site ilike '%toe%' and procedure_site ~* 'joint' then 'interphalangeal toe joint'
    when procedure_site ilike '%toe%' and procedure_site ~* 'phalanx' then 'bone of phalanx of foot'
    when procedure_site ilike 'toe(s)' then 'toe'
    when procedure_site ilike '%sympathetic%' then 'sympathetic nerve'
    when procedure_site ilike 'acoustic Nerve%' then 'cochlear nerve'
    when procedure_site ilike 'cranial Nerve%' then ''
    when procedure_site ilike '%nerve%' and procedure_site ~* 'lumbar' then 'lumbar spinal nerve'
    when procedure_site ilike '%nerve%' and procedure_site ~* 'thoracic' then 'thoracic spinal nerve'
    when procedure_site ilike '%nerve%' and procedure_site ~* 'peroneal' then 'common peroneal nerve'
    when procedure_site ilike '%nerve%' and procedure_site ~* 'sacral|cervical|femoral' then 'spinal nerve'
    when procedure_site ilike '%nerve%' and procedure_site ~* 'olfactory' then 'cranial nerve'
    when procedure_site ilike '%peripheral nerve%' then 'peripheral nerve'
    when procedure_site ilike 'accessory sinus' then 'nasal sinus'
    when procedure_site ilike 'paranasal sinuses' then 'nasal sinus'
    when procedure_site ilike 'intracranial sinuses' then 'dural sinus'
    when procedure_site ilike 'sinus%' then 'dural sinus'
    when procedure_site ilike 'mastoid%' then 'mastoid'
    when procedure_site ilike 'calcaneus' then 'bone of calcaneum'
    when procedure_site ~* 'carp' and procedure_site ~* 'metacarp' then 'carpometacarpal joint'
    when procedure_site ~* 'carpal' and procedure_site !~* 'metacarp' then 'radiocarpal joint'
    when procedure_site ilike 'atrial septum' then 'interatrial septum'
    when procedure_site ilike 'atrium, left' then 'left atrial'
    when procedure_site ilike 'atrium, right' then 'right atrial'
    when procedure_site ilike 'ventricle, right' then 'right cardiac ventricular'
    when procedure_site ilike 'ventricle, left' then 'left cardiac ventricular'
    when procedure_site ilike 'ventricular septum' then 'interventricular septum'
    when procedure_site ilike 'heart, left' then 'left side of heart'
    when procedure_site ilike 'heart, right' then 'right side of heart'
    when procedure_site ilike 'heart, right and left'
        or procedure_site ilike 'fetal heart'
        or procedure_site ilike 'pediatric heart'
        or procedure_site ilike 'heart with aorta'
        then 'heart'
    when procedure_site ilike 'acetabulum' then 'bone of acetabulum'
    when procedure_site ilike 'hip joint, acetabular surface' then 'surface of acetabulum'
    when procedure_site ilike 'nasopharynx%' then 'nasopharyngeal'
    when procedure_site ilike 'hypopharynx' then 'hypopharyngeal'
    when (procedure_site ~* 'pharynx' and procedure_site ~* 'mouth')
        or procedure_site like 'oropharynx'
        then 'oropharyngeal'
    when procedure_site ilike 'hypopharynx' then 'hypopharyngeal'
    when procedure_site ilike 'pharynx%' then 'hypopharyngeal'
    when procedure_site ilike 'popliteal artery%' then 'popliteal artery'
    when procedure_site ilike 'renal arter%' then 'renal artery'
    when procedure_site ilike 'spinal arteries' then 'spinal artery'
    when procedure_site ilike 'splenic arter%' then 'splenic artery'
    when procedure_site ilike 'temporal artery' then 'artery of head'
    when procedure_site ilike 'thyroid artery' then 'vascular of thyroid gland'
    when procedure_site ilike 'vertebral arter%' then 'vertebral artery'
    when procedure_site ilike 'upper%' and procedure_site like '%artery' then 'arterial'
    when procedure_site ilike 'thyroid gland isthmus' then 'isthmus of thyroid gland'
    when procedure_site ilike 'thyroid gland lobe' then 'lobe of thyroid gland'
    when procedure_site ilike '%parathyroid gland' then 'parathyroid'
    when procedure_site ilike 'joints' then 'joint'
    when procedure_site ilike 'knee joint%' then 'knee joint'
    when procedure_site ilike 'lower joint' then 'joint of lower extremity'
    when procedure_site ilike 'metatarsal-phalangeal joint' then 'metatarsophalangeal joint'
    when procedure_site ilike 'metatarsal-tarsal joint' then 'tarsometatarsal joint'
    when procedure_site ilike 'tarsal joint' then 'midtarsal joint'
    when procedure_site ilike 'sacroiliac joint%' then 'sacroiliac joint'
    when procedure_site ilike 'shoulder joint' then 'joint of shoulder region'
    when procedure_site ilike 'sternoclavicular joint%' then 'sternoclavicular joint'
    when procedure_site ilike 'temporomandibular joint%' then 'temporomandibular joint'
    when procedure_site ilike 'thoracic facet joint%' then 'facet joint of thoracic spine'
    when procedure_site ilike 'thoracic vertebral joint%' then 'thoracic spine joint'
    when procedure_site ilike 'upper joint' then 'joint of upper limb'
    when procedure_site ilike 'tarsal' then 'tarsal bone'
    when procedure_site ilike 'kidneys%'
        or procedure_site like 'kidney, ureter and bladder'
        then 'kidney'
    when procedure_site ilike 'kidney transplant' then 'transplanted kidney'
    when procedure_site ilike 'kidney pelvis' then 'renal pelvis'
    when procedure_site ilike 'knee' or procedure_site like 'knees' then 'knee joint'
    when procedure_site ilike 'knee bursa and ligament' then 'bursa of knee'
    when procedure_site ilike 'lacrimal duct%' then 'nasolacrimal duct'
    when procedure_site ilike 'lens' then 'lens clear'
    when procedure_site ilike 'liver lobe' then 'lobe of liver'
    when procedure_site ilike 'liver and spleen' then 'liver'
    when procedure_site ilike 'lower arm' then 'forearm'
    when procedure_site ilike 'lower arm and wrist muscle' then 'muscle of forearm'
    when procedure_site ilike 'skin, arm' then 'skin of upper limb'
    when procedure_site ilike 'skin lower arm' then 'skin of upper limb'
    when procedure_site ilike 'skin upper arm' then 'skin of upper arm'
    when procedure_site ilike 'subcutaneous tissue and fascia lower arm' then 'fascia of forearm'
    when procedure_site ilike 'subcutaneous tissue and fascia upper arm' then 'fascia of upper arm'
    when procedure_site ilike 'upper arm muscle' then 'musculoskeletal of upper limb'
    when procedure_site ilike 'back' then 'back of trunk'
    when procedure_site ilike 'lower back' then 'lumbar region of back'
    when procedure_site ilike 'skin, back' then 'skin of back'
    when procedure_site ilike 'subcutaneous tissue and fascia, back' then 'skin and/or subcutaneous tissue of back'
    when procedure_site ilike 'upper back' then 'scapular region of back'
    when procedure_site ilike '%gingiva%' then 'gingival'
    when procedure_site ilike 'tooth%' or procedure_site like '%teeth%' then 'tooth'
    when procedure_site ilike 'lower tooth' then 'mandibular teeth'
    when procedure_site ilike 'upper tooth' then 'maxillary teeth'
    when procedure_site ilike 'submandibular gland%' then 'submandibular salivary gland'
    when procedure_site ilike 'lumbar' then 'lumbosacral region'
    when procedure_site ilike 'lumbosacral joint' then 'joint of lumbosacral junction of spine'
    when procedure_site ilike 'lymphatic'
        or procedure_site like 'lymphatic and hematologic system'
        or procedure_site like 'lymphatics'
        then 'lymphoid system'
    when procedure_site like 'male reproductive%' then 'male genital'
    when procedure_site like 'perineum, female' then 'female perineal'
    when procedure_site like 'perineum, male' then 'male perineal'
    when procedure_site like 'perineum muscle'
        or procedure_site like 'subcutaneous tissue and fascia, perineum'
        then 'perineal'
    when procedure_site like 'skin, perineum' then 'skin of perineum'
    when procedure_site like 'mediastinum' then 'mediastinal'
    when procedure_site like 'medulla oblongata' then 'brainstem'
    when procedure_site like 'middle lobe bronchus'
        or procedure_site like 'lingula bronchus'
        then 'bronchus'
    when procedure_site like 'tracheobronchial tree%' then 'tracheobronchial'
    when procedure_site like 'intercostal and bronchial arteries' then 'bronchial artery'
    when procedure_site like 'mouth%' then 'mouth region'
    when procedure_site like '%mammary duct%' then 'lactiferous duct of breast'
    when procedure_site like 'nasal mucosa and soft tissue' then 'nasal cavity'
    when procedure_site like 'zygomatic arch%' then 'zygomatic arch'
    when procedure_site like 'wrist' then 'wrist joint'
    when procedure_site like 'wrist bursa and ligament' then 'bursa of wrist region'
    when procedure_site like 'uvula' then 'uvula palatina'
    when procedure_site like 'retinal vessel' then 'blood vessel of retina'
    when procedure_site like 'products of conception, ectopic' then 'product of conception of ectopic pregnancy'
    when procedure_site like 'products of conception%' and procedure_site not like '%ectopic%' then 'product of conception'
    when procedure_site like 'skin, buttock' then 'skin of buttock'
    when procedure_site like 'skin ear' then 'skin of ear'
    when procedure_site like 'skin, inguinal' then 'skin of inguinal region'
    when procedure_site like 'skin, leg' then 'skin of lower limb'
    when procedure_site like 'skin, neck' then 'skin of neck'
    when procedure_site like 'skin, scalp' then 'skin of scalp'
    when procedure_site like 'skin, subcutaneous tissue and breast' then 'skin and/or subcutaneous tissue of breast'
    when procedure_site like 'skin upper leg' then 'skin of lower limb'
    when procedure_site like 'skin and mucous membranes' then 'skin and/or mucous membrane'
    when procedure_site like 'skin and breast' then 'breast'
    when procedure_site like 'whole skeleton' then 'skeleton'
    when procedure_site like 'pineal body' then 'pineal'
    when procedure_site like 'placenta' then 'placental'
    when procedure_site like 'pleura' then 'pleural'
    when procedure_site like 'pons' then 'brainstem'
    when procedure_site like 'prepuce' then 'prepuce of penis'
    when procedure_site like 'prefrontal cortex' then 'cerebral cortex'
    when procedure_site like 'prostate and seminal vesicles' then 'male genital'
    when procedure_site like 'pulmonary trunk' then 'trunk of pulmonary artery'
    when procedure_site like 'radius/ulna' then 'bone of forearm'
    when procedure_site like 'radius/ulna' then 'bone of forearm'
    when procedure_site like 'respiratory' then 'respiratory organ'
    when procedure_site like 'retroperitoneum' then 'retroperitoneal region, excluding major organs'
    when procedure_site like 'peritoneum' then 'peritoneum (serous membrane)'
    when procedure_site like 'peripheral nervous' then 'peripheral nerve'
    when procedure_site like 'rib cage' then 'chest wall'
    when procedure_site like 'ribs%' or procedure_site like 'rib(s)%' then 'bone of rib'
    when procedure_site like 'sacrum' then 'bone of sacrum'
    when procedure_site like 'salivary gland%'then 'salivary gland'
    when procedure_site like 'sclera' then 'scleral'
    when procedure_site like 'scrotum' then 'scrotal'
    when procedure_site like 'scrotum and tunica vaginalis' then 'scrotal'
    when procedure_site like 'sella turcica/pituitary gland' then 'pituitary fossa'
    when procedure_site like 'seminal vesicle%' then 'pituitary fossa'
    when procedure_site like 'shoulder muscle' then 'skeletal muscle of shoulder'
    when procedure_site like 'shoulder bursa and ligament' then 'bursa of shoulder'
    when procedure_site like 'shoulder' then 'shoulder region'
    when procedure_site like 'skull' then 'bone of cranium'
    when procedure_site like 'skull and cervical spine' then 'bone of cranium'
    --when procedure_site like 'phalanx of toe' then 'bone of phalanx of foot'
    when procedure_site like 'thumb phalanx' then 'bone of phalanx of thumb'
    when procedure_site like 'small bowel' then 'small intestine'
    when procedure_site like 'upper gi and small bowel' then 'upper gastrointestinal tract'
    when procedure_site like 'spermatic cord%' then 'upper gastrointestinal tract'
    when procedure_site like 'spine%' or procedure_site like 'whole spine' then 'vertebral column'
    when procedure_site like 'upper spine bursa and ligament' then 'ligament of spine'
    when procedure_site like 'sternum bursa and ligament' then 'sternal region'
    when procedure_site like 'stomach, pylorus' then 'pyloric of stomach'
    when procedure_site like 'subarachnoid space, intracranial' then 'subarachnoid space of brain'
    when procedure_site like 'subcutaneous tissue and fascia, buttock' then 'subcutaneous tissue of buttock'
    when procedure_site like 'subcutaneous tissue and fascia, lower extremity' then 'fascia of lower extremity'
    when procedure_site like 'subcutaneous tissue and fascia lower leg' then 'subcutaneous tissue of lower leg'
    when procedure_site like 'subcutaneous tissue and fascia neck' then 'subcutaneous tissue of neck'
    when procedure_site like 'subcutaneous tissue and fascia, pelvic region' then 'subcutaneous tissue of pelvis'
    when procedure_site like 'subcutaneous tissue and fascia, scalp' then 'subcutaneous tissue of head'
    when procedure_site like 'subcutaneous tissue and fascia, trunk' then 'subcutaneous tissue'
    when procedure_site like 'subcutaneous tissue and fascia, upper extremity' then 'subcutaneous tissue of upper extremity'
    when procedure_site like 'subcutaneous tissue and fascia upper leg' then 'subcutaneous tissue of thigh'
    when procedure_site like 'subcutaneous tissue, head/neck' then 'subcutaneous tissue'
    when procedure_site like 'subcutaneous tissue, lower extremity' then 'subcutaneous tissue'
    when procedure_site like 'subcutaneous tissue, thorax' then 'subcutaneous tissue of chest'
    when procedure_site like 'subcutaneous tissue, upper extremity' then 'subcutaneous tissue of upper extremity'
    when procedure_site like 'subdural space, intracranial' then 'intracranial vein'
    when procedure_site like 'supernumerary breast' then 'breast'
    when procedure_site ~* 'testes|testicle|testis' then 'testis'
    when procedure_site like 'upper intestinal tract' then 'duodenum'
    when procedure_site like 'thalamus' then 'thalamic'
    when procedure_site like 'thoracic aorta, arch' then 'aortic arch'
    when procedure_site like 'thoracic aorta, ascending%' then 'ascending aorta'
    when procedure_site like 'thoracic aorta, descending%' then 'descending thoracic aorta'
    when procedure_site like 'thoraco-abdominal aorta' then 'aorta'
    when procedure_site like 'thoracic esophagus' then 'esophageal'
    when procedure_site like 'thoracic vertebra' then 'bone of thoracic vertebra'
    when procedure_site like 'tibia/fibula' then 'bone of lower leg'
    when procedure_site like 'vitreous' then 'vitreous body'
    when procedure_site like 'vestibular gland' then 'bartholin gland'
    when procedure_site like 'whole body%' then 'body as a whole'
    when procedure_site like 'visual' then 'visual system'
    when procedure_site like 'urinary' then 'urinary system'
    when procedure_site like 'upper airways' then 'upper respiratory tract'
    when procedure_site like 'upper bursa and ligament'
        or procedure_site like 'upper extremity bursa and ligament'
        then 'ligament of upper limb'
    when procedure_site like 'upper extremit%' then 'upper limb'
    when procedure_site like 'upper gi' then 'upper digestive tract'
    when procedure_site like 'upper jaw' then 'upper jaw region'
    when procedure_site like 'upper leg' then 'thigh'
    when procedure_site like 'upper leg muscle' then 'thigh'
    when procedure_site like 'upper muscle' then 'skeletal muscle of upper limb'
    when procedure_site like 'ureter%' then 'ureter'
    when procedure_site like 'trunk muscle' then 'skeletal muscle of trunk'
    when procedure_site like 'trunk region' then 'trunk'
    when procedure_site like 'trachea%' then 'tracheal'
    when procedure_site like 'tongue, palate, pharynx muscle' then 'muscle'
    when procedure_site like 'neck muscle' then 'skeletal muscle of neck'
    when procedure_site like 'sphenopalatine ganglion' then 'pterygopalatine ganglion'
    when procedure_site like 'paraganglion extremity' then 'endocrine system'
else procedure_site end;

update snomed_split
set procedure_site = case when procedure_site in ('abdomen proper',
                                                 'cross-sectional abdomen',
                                                 'lower abdomen',
                                                 'structure of abdomen proper',
                                                 'surface region of lower abdomen',
                                                 'surface region of upper abdomen',
                                                 'upper abdomen') then 'abdomen'
when procedure_site ilike '%lymph%' and procedure_site like '%abdomen%' then 'lymphatic abdomen'
    when procedure_site ilike '%skin%' and procedure_site like '%abdomen%' then 'skin of abdomen'
    when procedure_site ilike 'bartholin%' then 'bartholin gland'
    when procedure_site ilike '%soft%' and procedure_site like '%abdomen%' then 'soft tissue of abdomen'
    when procedure_site ilike '%lymph%' and procedure_site like '%lower limb%' then 'lymphatic lower limb'
    when procedure_site ilike '%lymph%' and procedure_site like '%upper limb%' then 'lymphatic upper limb'
    when procedure_site ilike '%lymph%' and procedure_site like '%head%' then 'lymphatic head'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'thorax' then 'lymphatic thorax'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'axilla' then 'lymphatic axillary'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'inguinal' then 'lymphatic inguinal'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'neck' then 'lymphatic neck'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'pelvis' then 'lymphatic pelvis'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'mammary' then 'lymphatic mammary'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'mesenter' then 'lymphatic mesenteric'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'retroperitoneal' then 'lymphatic retroperitoneal'
    when procedure_site ilike '%lymph%' and procedure_site ~* 'aort' then 'lymphatic aortic'
    when procedure_site ilike 'tendon within ankle region' then 'ankle tendon'
    when procedure_site ilike '%urinary bladder%' and procedure_site like'%neck%' then 'neck of urinary bladder'
    when procedure_site ilike 'lumbar disc' then 'lumbar intervertebral disc'
    when procedure_site ilike '%chordae tendineae%' then 'chordae tendineae cordis'
    when procedure_site ilike '%cornea%' then 'cornea of eye'
    when procedure_site ilike 'bursa of ankle'
             or procedure_site ilike 'ligament of ankle joint' then 'ankle bursa and ligament'
    when procedure_site ilike '%femoral vein%' then 'femoral vein'
    when procedure_site ilike '%femoral artery%' then 'femoral artery'
    when procedure_site ilike '%fallopian tube%' then 'fallopian tube'
    when procedure_site like '%hand%' and procedure_site like '%skin%' then 'skin of hand'
    when procedure_site ~* 'foot' and procedure_site ~* 'skin' then 'skin of foot'
    when procedure_site like '%omentum%' then 'omentum'
    when procedure_site ilike 'metatarsophalangeal joint%' then 'metatarsophalangeal joint'
    when procedure_site ilike 'metacarpophalangeal joint%' then 'metacarpophalangeal joint'
    when procedure_site ilike '%tarsometatarsal joint%' then 'tarsometatarsal joint'
   else procedure_site end;

-- Access

update icd10pcs_split
set object = access
where access ~* 'carbon|chromium|cobalt|fluorine|gallium|indium|iodine|krypton|nitrogen|oxygen|phosphorus|rubidium|samarium|strontium|technetium|thallium|xenon'
or access like 'other contrast'
;

update icd10pcs_split
set method = access
where access ~* 'bekesy audiometry'
;

select distinct  access from icd10pcs_split;

update icd10pcs_split
set object = case when object like 'carbon 11 (c-11)' then 'carbon radioisotope'
when object like 'californium 252 (cf-252)' then 'californium-252'
when object like 'cesium 131 (cs-131)' then 'cesium radioisotope'
when object like 'cesium 137 (cs-137)' then 'cesium-137'
when object like 'chromium (cr-51)' then 'chromium-51'
when object like 'cobalt%' then 'cobalt radioisotope'
when object like 'fluorine'
    or object like 'fluorine 18 (f-18)'
    then 'fluorine radioisotope'
when object like 'gallium 67 (ga-67)' then 'gallium-67'
when object like 'indium 111 (in-111)' then 'iodine-123'
when object like 'iodine 123 (i-123)' then 'indium-111'
when object like 'iodine 125 (i-125)' then 'iodine-125'
when object like 'iodine 131 (i-131)' then 'iodine-131'
when object like 'iridium 192 (ir-192)' then 'iridium-192'
when object like 'krypton (kr-81m)' then 'krypton-81m'
when object like 'nitrogen 13 (n-13)' then 'nitrogen radioisotope'
when object like 'nitrogen 13 (n-13)' then 'nitrogen radioisotope'
when object like 'oxygen 15 (o-15)' then 'oxygen radioisotope'
when object like 'phosphorus 32 (p-32)' then 'phosphorus-32'
when object like 'rubidium 82 (rb-82)' then 'rubidium-82'
when object like 'samarium 153 (sm-153)' then 'samarium-153'
when object like 'strontium 89 (sr-89)' then 'strontium-89'
when object like 'strontium 90 (sr-90)' then 'strontium-90'
when object like 'strontium 90 (sr-90)' then 'strontium-90'
when object like 'technetium 99m (tc-99m)' then 'technetium-99m'
when object like 'thallium 201 (tl-201)' then 'thallium-201'
when object like 'thallium 201 (tl-201)' then 'thallium-201'
when object like 'xenon 127 (xe-127)' then 'xenon-127'
when object like 'xenon 133 (xe-133)' then 'xenon-133'
when object like 'hyperpolarized xenon 129 (xe-129)' then 'xenon radioisotope'
when object like 'other isotope'
    or object like 'palladium 103 (pd-103)'
    or object like 'radioactive element%'
    or object like 'radioactive substance'
    then 'radioactive isotope'
when object like 'anesthetic agent' then 'anesthetic'
when object like 'inhalation anesthetic' then 'general inhalation anesthetic'
when object like 'intracirculatory anesthetic' then 'general anesthetic'
when object like 'regional anesthetic' then 'local anesthetic'
when object like '%immunotherap%' then 'immunologic agent'
when object like 'autologous arterial tissue' then 'autologous artery'
when object like '%tissue substitute' then 'tissue graft - material'
when object like 'autologous venous tissue' then 'autologous vein graft'
when object like 'bioengineered allogeneic construct' then 'allograft'
when object like 'engineered allogeneic thymus tissue' then 'allograft'
when object like 'zooplastic tissue%' then 'xenograft'
when object like 'analgesics, hypnotics, sedatives'
    or object like 'anti-inflammatory'
    or object like 'endothelial damage inhibitor'
    or object like 'exagamglogene autotemcel'
    or object like 'lovotibeglogene autotemcel'
    or object like 'omidubicel'
    or object like 'otl-103'
    or object like 'otl-200'
    or object like 'other therapeutic substance'
    or object like 'posoleucel'
    then 'drug or medicament'
when object like 'fresh plasma'
    or object like 'frozen plasma'
    or object like 'plasma cryoprecipitate'
    then 'plasma'
when object like 'platelet inhibitor' then 'platelet aggregation inhibitor'
when object like 'plasma, convalescent (nonautologous)' then 'convalescent plasma'
when object like '%red cell%' then 'blood component'
when object like 'stem cells, cord blood' then 'cord blood stem cell fluid'
when object like 'gas' then 'gaseous substance'
when object like 'globulin' then 'immunoglobulin'
when object like 'high-dose intravenous immune globulin'
    or object like 'hyperimmune globulin'
    or object like 'globulin'
    then 'immunoglobulin'
when object like 'bone marrow'
    or object like 'concentrated bone marrow aspirate'
    then 'bone marrow fluid'
when object like 'indocyanine green dye'
    or object like 'other diagnostic substance'
    then 'diagnostic dye'
when object like 'indocyanine green dye' then 'diagnostic dye'
when object like 'platelets' then 'platelet component of blood'
when object like 'serum, toxoid and vaccine' then 'vaccine, immunoglobulin, and/or antiserum'
when object like 'skin substitute, porcine liver derived' then 'synthetic graft of skin'
when object like 'stem cells, hematopoietic' then 'fluid containing hemopoietic stem cells'
when object like 'stem cells, embryonic' then 'fetal and embryonic material'
when object like 'white cells' then 'lymphocyte component of blood'
when object like 'articulating spacer' then 'joint spacer'
when object like 'audiometer' then 'audiometric testing equipment'
when object like 'cardiac rhythm related device' then 'cardiac pacemaker'
when object like 'intracardiac pacemaker, dual-chamber' then 'intracardiac pacemaker'
when object like 'drainage device' then 'drain'
when object like 'external fixation device%' then 'external fixation device'
when object like 'internal fixation device%' then 'orthopedic internal fixation system'
when object like 'contractility modulation device'
    or object like 'extraluminal device'
    or object like 'interbody fusion device%'
    or object like 'intermittent pressure device'
    or object like 'monitoring device%'
    or object like 'other device'
    then 'device'
when object like 'feeding device' then 'feeding tube'
when object like 'hearing aid selection / fitting / test'
    or object like 'hearing device'
    or object like 'infusion device'
    then 'hearing aid'
when object like 'hearing device, bone conduction' then 'anchored bone-conduction hearing aid'
when object like '%cochlear%' then 'cochlear prosthesis'
when object like 'infusion device, pump' then 'infusion pump'
when object like 'infusion device' then 'infusion pump'
when object like 'intraluminal device'
    or object like 'intraluminal device, branched or fenestrated%'
    or object like 'intraluminal device, flow diverter'
    or object like 'intraluminal device, three'
    or object like 'intraluminal device, two'
    or object like 'intraluminal device, four or more'
     then 'intraluminal vascular device'
when object like 'intraluminal device, airway' then 'airway device'
when object like 'intraluminal device, endotracheal airway' then 'endotracheal tube'
when object like 'intraluminal device%' and object like '%drug-eluting%' then 'intraluminal device, drug-eluting'
when object like 'intraluminal device, endobronchial valve' then 'endobronchial valve'
when object like 'intraluminal device, bioprosthetic valve' then 'biologic cardiac valve prosthesis'
when object like 'intraluminal device, bioactive' then 'biomedical device'
when object like 'intraluminal device, pessary' then 'pessary'
when object like 'intraluminal device, radioactive' then 'radioactive implant'
when object like 'monitoring device' then 'monitor'
when object like 'no device' then null
when object like 'vascular access device, totally implantable' then 'totally implantable venous access device'
when object like 'vascular access device, tunneled' then 'tunneled central venous catheter'
when object like 'vascular access device, tunneled' then 'tunneled central venous catheter'
when object like 'tracheostomy device' then 'computer equipment'
when object like 'computer' then 'tracheostomy tube'
when object like 'cardiac resynchronization defibrillator pulse generator' then 'cardiac resynchronization therapy defibrillator pulse generator'
when object like 'cardiac resynchronization pacemaker pulse generator' then 'pacemaker pulse generator'
when object like 'defibrillator lead'
    or object like 'cardiac lead, defibrillator'
    then 'implantable defibrillator leads'
when object like 'defibrillator generator' then 'defibrillator'
when object like 'subcutaneous defibrillator lead' then 'subcutaneous implantable cardioverter defibrillator'
when object like 'cardiac lead, pacemaker' then 'cardiac pacemaker lead'
when object like 'neurostimulator lead%' then 'neurostimulator electrode'
when object like 'neurostimulator generator' then 'neurostimulator'
else object end;


update snomed_split
set object = case when object like 'artificial%' and object like '%sphincter' then 'artificial sphincter'
    when object like '%drug-eluting%' then 'intraluminal device, drug-eluting'
    when access like 'photons%' then 'ionizing radiation'
else object end
;
update snomed_split
set object = regexp_replace(object, ' agent', '');

update icd10pcs_split
set object = regexp_replace(object, ' agent', '');


select distinct i.object, ss.object
from icd10pcs_split i
full join snomed_split ss on lower(i.object) = lower(ss.object)
order by i.object asc nulls last, ss.object;



select distinct i.concept_code,
       i.concept_name,
       s.concept_code as target_code,
       s.concept_name as target_name
       --devv5.similarity(i.concept_name, s.concept_name) as similarity
from icd10pcs_split i
left join  snomed_split s on lower(i.method) = lower(s.method) and
                       lower(i.procedure_site) = lower(s.procedure_site)
where i.concept_code like 'XRH%'
--and lower(i.object) = lower (s.object)
--and  lower(i.access) = lower (s.access)
order by i.concept_code; /*and
                       lower(i.access) = lower (s.access) /*or
                       lower(i.object) = lower (s.object))*/
order by i.concept_code,similarity desc;
; and
                       (lower(i.access) = lower (s.access) or
                       lower(i.object) = lower (s.object));*/

*/
-- mapping of icd10pcs codes to sNomed using umls ccsr_icd10pcs classification:
--- We can map the rest of ccsr_icd10pcs to sNomed and join to this table
with a as (select m.code  as icd_code,
                  m.str   as icd_name,
                  m1.cui,
                  m1.code as intermediate_code,
                  m1.str  as intermediate_name
           from sources.mrrel r
                    join sources.mrconso m on m.aui = r.aui2
                    join sources.mrconso m1 on m1.aui = r.aui1
           where m.sab = 'ICD10PCS'
             and m1.sab = 'CCSR_ICD10PCS'
             and m.tty in ('PT')
),

s as (
    select * from sources.mrconso
             where sab = 'SNOMEDCT_US'
             and tty = 'PT'
)

select  icd_code,
        icd_name,
        intermediate_code,
        intermediate_name,
       s.code as snomed_code,
       s.str as snomed_name
from a
left join s on a.cui = s.cui
where icd_code in
(select concept_code from concept c
where c.concept_class_id = 'ICD10PCS'
and c.concept_id not in (select cc.concept_id from devv5.concept cc where cc.vocabulary_id = 'ICD10PCS'))

;
# temporary translation table between class_codes and ICD-10 chapters
# should be select concept_name, concept_code from concept where vocabulary_oode='Domain' and class_code='ICD10CM';
%concept_class=(
"Certain infectious and parasitic diseases"=>"Infectious Disease",
"Neoplasms"=>"Neoplasm",
"Diseases of the blood and blood-forming organs and certain disorders involving the immune mechanism"=>"Blood/Immune Disease",
"Endocrine, nutritional and metabolic diseases"=>"Endocrine Disease",
"Mental, Behavioral and Neurodevelopmental disorders"=>"Mental Disease",
"Diseases of the nervous system"=>"Nervous Disease",
"Diseases of the eye and adnexa"=>"Eye Disease",
"Diseases of the ear and mastoid process"=>"Ear Disease",
"Diseases of the circulatory system"=>"Circulatory Disease",
"Diseases of the respiratory system"=>"Respiratory Disease",
"Diseases of the digestive system"=>"Digestive Disease",
"Diseases of the skin and subcutaneous tissue"=>"Skin Disease",
"Diseases of the musculoskeletal system and connective tissue"=>"Soft Tissue Disease",
"Diseases of the genitourinary system"=>"Genitourinary Dis",
"Pregnancy, childbirth and the puerperium"=>"Pregnancy",
"Certain conditions originating in the perinatal period"=>"Perinatal Disease",
"Congenital malformations, deformations and chromosomal abnormalities"=>"Congenital Disease",
"Symptoms, signs and abnormal clinical and laboratory findings, not elsewhere classified"=>"Symptom",
"Injury, poisoning and certain other consequences of external causes"=>"Injury",
"External causes of morbidity"=>"External Cause",
"Factors influencing health status and contact with health services"=>"Health Service",
);

# Log and error log
open LOG, ">>parsing.log" or die "$!";  
open ERRORLOG, ">parsing.bad" or die "$!";

# replace open with reading from downloaded file
open ICD10, "ICD10CM_FY2013_Full_XML_Tabular.xml" or log_die("$!");
# replace with insert into
open CONCEPT, ">concept.txt" or log_die("Writing concept.txt: $!"); printf CONCE"concept_id,concept_name,vocabulary_code,class_code,concept_code,valid_start_date,valid_end_date,invalid_reason\n";
open CONCEPT_RELATIONSHIP, ">concept_relationship.txt" or log_die("Writing concept_relationship.txt: $!"); printf CONCEPT_RELATIONSHIP "concept_code_1,concept_code_2,relationship_code,valid_start_date,valid_end_date,invalid_reason\n";
open CODEALSO, ">codealso.txt" or log_die("Writing codealso.txt: $!"); printf CODEALSO "concept_code,note\n";
open CODEFIRST, ">codefirst.txt" or log_die("Writing codefirst.txt: $!"); printf CODEFIRST "concept_code,note\n";
open EXCLUDES1, ">excludes1.txt" or log_die("Writing excludes1.txt: $!"); printf EXCLUDES1 "concept_code,note\n";
open EXCLUDES2, ">excludes2.txt" or log_die("Writing excludes2.txt: $!"); printf EXCLUDES2 "concept_code,note\n";
open INCLUDES, ">includes.txt" or log_die("Writing includes.txt: $!"); printf INCLUDES "concept_code,note\n";
open INCLUSIONTERM, ">inclusionterm.txt" or log_die("Writing inclusionterm.txt: $!"); printf INCLUSIONTERM "concept_code,note\n";
open USEADDITIONALCODE, ">useadditionalcode.txt" or log_die("Writing useadditionalcode: $!"); printf USEADDITIONALCODE "concept_code,note\n";

$section_id=""; # the section becomes the class_code
$concepts=0; # the total amount of concepts found and written
$relationships=0; # the total amount of concept_relationships written

# start parsing, first get section
while (<ICD10>) {
	next unless $_=~/<chapter>/i;
	chapter();
}
write_log("Wrote $concepts concepts, $relationships relationships");

close ICD10;
close CONCEPT;
close CONCEPT_RELATIONSHIP;
close CODEALSO; 
close CODEFIRST;
close EXCLUDES1;
close EXCLUDES2;
close INCLUDES;
close INCLUSIONTERM;
close USEADDITIONALCODE;

sub chapter { # ($sectionlevel)
	while (<ICD10>) {
		return if $_=~/<\/chapter>/i; # return from this level
		if ($_=~/<section/i) {
			while (<ICD10>) {
				last if $_=~/<\/section>/i;
				diag(0, "") if $_=~/<diag>/i;
			}
		}
		$chapter=$1 if $_=~/<desc>(.+?)\s+\(.+?\)<\/desc>/i;		
	}
}

sub diag { # ($level, calling code, undef at level 0)
	my $level=shift;
	my $parent=shift; # undef at level 0
	my $code, $desc;
	while (<ICD10>) {
		return if $_=~/<\/diag>/i; # return from this level, diags are nested
		if ($_=~/<name>(.+?)<\/name>/i) { # the concept_code
			$code=$1; next;
		}
		if ($_=~/<desc>(.+?)<\/desc>/i) { # the concept_name
			$desc=$1; 
			$concepts++;
			printf CONCEPT "1,\"$desc\",ICD10CM,$concept_class{$chapter},$code,1970-01-01,2099-12-31,\n" or log_die("Writing concept.txt: $!");
			$relationships++, printf CONCEPT_RELATIONSHIP "$parent,$code,Subsumes,1970-01-01,2099-12-31,\n" or log_die("Writing concept_relationship.txt: $!") if $parent;
			printf CONCEPT_RELATIONSHIP "$code,$parent,Isa,1970-01-01,2099-12-31,\n" or log_die("Writing concept_relationship.txt: $!") if $parent;
			next;
		}
		if ($_=~/<sevenChrDef>/i) { # seventh character, treating same as previous 6 characters
			while (<ICD10>) {
				last if $_=~/<\/sevenChrDef>/;
				if ($_=~/<extension char="(\d+)">(.+?)<\/extension>/i) {
					$ext_code=$code.$1; $ext_desc=$desc." - ".$2;
					$count++; $relationships++;
					printf CONCEPT "1,\"$ext_desc\",ICD10CM,$concept_class{$chapter},$ext_code,1970-01-01,2099-12-31,\n" or log_die("Writing concept.txt: $!");
					printf CONCEPT_RELATIONSHIP "$code,$ext_code,Subsumes,1970-01-01,2099-12-31,\n" or log_die("Writing concept_relationship.txt: $!");
					printf CONCEPT_RELATIONSHIP "$ext_code,$code,Isa,1970-01-01,2099-12-31,\n" or log_die("Writing concept_relationship.txt: $!");
					next;
				}
			}
		}
		if ($_=~/<codeAlso>/i) {
			while (<ICD10>) {
				last if $_=~/<\/codeAlso>/i;
				printf CODEALSO "$code,$1\n" if $_=~/<note>(.+?)<\/note>/i or log_die("Writing codealso.txt: $!");
			}
			next;
		}
		if ($_=~/<codeFirst>/i) {
			while (<ICD10>) {
				last if $_=~/<\/codeFirst>/i;
				printf CODEFIRST "$code,$1\n" if $_=~/<note>(.+?)<\/note>/i or log_die("Writing codefirt.txt: $!");
			}
			next;
		}
		if ($_=~/<excludes1>/i) {
			while (<ICD10>) {
				last if $_=~/<\/excludes1>/;
				printf EXCLUDES1 "$code,$1\n" if $_=~/<note>(.+?)<\/note>/i or log_die("Writing excludes1.txt: $!");
			}
			next;
		}
		if ($_=~/<excludes2>/i) {
			while (<ICD10>) {
				last if $_=~/<\/excludes2>/;
				printf EXCLUDES2 "$code,$1\n" if $_=~/<note>(.+?)<\/note>/i or log_die("Writing excludes2.txt: $!");
			}
			next;
		}
		if ($_=~/<includes>/i) {
			while (<ICD10>) {
				last if $_=~/<\/includes>/;
				printf INCLUDES "$code,$1\n" if $_=~/<note>(.+?)<\/note>/i or log_die("Writing includes.txt: $!");
			}
			next;
		}
		if ($_=~/<inclusionTerm>/i) {
			while (<ICD10>) {
				last if $_=~/<\/inclusionTerm>/;
				printf INCLUSIONTERM "$code,$1\n" if $_=~/<note>(.+?)<\/note>/i or log_die("Writing inclusionterm.txt: $!");
			}
			next;
		}
		if ($_=~/<useAdditionalCode>/i) {
			while (<ICD10>) {
				last if $_=~/<\/useAdditionalCode>/;
				printf USEADDITIONALCODE "$code,$1\n" if $_=~/<note>(.+?)<\/note>/i or log_die("Writing useadditionalcode.txt: $!");
			}
			next;
		}
		diag($level+1, $code) if $_=~/<diag>/i; # dive down the hierarchy
	}
}

sub log_die { # (error text)
	$errortext=shift;
	printf ERRORLOG time.": $errortext\n";
	printf LOG time.": Aborted with error. Explore parsing.bad for details.\n";
	warn $errortext;
	die;
}

sub write_log { # (logtext)
	$logtext=shift;
	printf LOG time.": $logtext\n";
	warn $logtext;
	return;
}

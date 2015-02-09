#!/usr/bin/perl

#####################################################################################################################################################
# Dump the vocabulary tables data into a Latin1 encoded file for each table
# with a fields header row and tab separated ASCII values
# within a single zip file.
# Only dumps the table data that corresponds to the vocabulary ids in the vocabulary ids list argument.
# (Defaults to dumping data for all vocabularies if no vocabulary list argument is provided).
#
# Usage:
#    ./dump.pl <user/pass@host/sid> <vocabulary version number> <output.zip> [vocabulary ids]
#    'vocabulary ids' is a comma-separated list of required vocabulary ids, omit the list in order to dump all available
#
# 12/05/2014    Lee Evans    Documented and re-factored original dump.pl code to make it easier to maintain
#                            Updated code to create tab separated output files, compatible with Oracle,PostgreSQL & SqlServer
#                            Added vocabulary version number argument so this single script can handle both 4.5 and 5 vocabulary versions
#####################################################################################################################################################

use warnings;
use strict;
use DBI;
use DBI qw( :sql_types );
use POSIX;
use Archive::Zip;
use Text::Unidecode;

# Subroutines

sub table_colnames_query { 'SELECT COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE OWNER = ? AND TABLE_NAME = ? ORDER BY COLUMN_ID' }
sub table_colnames { [ map { $_->[0] } @{ shift->selectall_arrayref(table_colnames_query, undef, uc shift, uc shift) } ] }
sub all_vocabularies_v45 { map { $_->[0] } @{ shift->selectall_arrayref('SELECT VOCABULARY_ID FROM VOCABULARY') } }
sub all_vocabularies_v5 { map { $_->[0] } @{ shift->selectall_arrayref('SELECT VOCABULARY_ID_V4 FROM VOCABULARY_CONVERSION') } }

sub csv_dump { # (database handler, name of table

		# get arguments passed into this subroutine
        my ($dbh, $table) = @_;

        # display progress info
        warn sprintf('Writing file for table %s to zip file', $table->{name});

        # build and prepare the SQL statement
        my $sql_statement = join(' ', sprintf('SELECT t.* FROM %s t', $table->{name}), $table->{where_clause});
        my $sth = $dbh->prepare($sql_statement) or die "Couldn't prepare statement: " . $dbh->errstr;

        # execute the SQL statement returning a statement handle
		$sth->execute(@{$table->{params}});

        # open a temporary output file in Latin1 encoding
		my $dump = tmpnam;
        open my $fh, ">:encoding(Latin1)", $dump or die "Cannot open temporary output file: $!";

        # print the file header row table column names, tab separated
        my $cols = table_colnames $dbh, $dbh->{Username}, $table->{name};
        print $fh join("\t", @{$cols}) . "\n";

        # fetch each row from the table and write it out as a line to the temporary output file
        my $print_csv_line;
        my $numberoffields = $sth->{NUM_OF_FIELDS};
        my $fieldtype;
        my $fieldmaxlength;
        my $fieldvalue;
        my $i;
        my @fieldarray;
        while (@fieldarray = $sth->fetchrow_array) {

                # process each field in the row to deal with diacritics
                for ($i = 0 ; $i < $numberoffields ; $i++ ) {

                                # only process field if it's value is not null
                                if (defined($fieldarray[$i])) {

                                        # check if field is a character type field
                                        $fieldtype  = $sth->{TYPE}->[$i];
                                        if (($fieldtype == SQL_CHAR) || ($fieldtype == SQL_VARCHAR) || ($fieldtype == SQL_LONGVARCHAR) ||
                                                ($fieldtype == SQL_WCHAR) || ($fieldtype == SQL_WVARCHAR) || ($fieldtype == SQL_WLONGVARCHAR)) {

                                                # use a local variable in loop to speed up processing
                                                $fieldvalue = $fieldarray[$i];

                                                # convert any diacritics characters to nearest ascii equivalent characters
                                                $fieldvalue = unidecode($fieldvalue);

                                                # a single diacritic char may be expanded to multiple chars
                                                # so check if we need to substring to keep field length <= max field length
                                                $fieldmaxlength  = $sth->{PRECISION}->[$i];
                                                if (length($fieldvalue) > $fieldmaxlength) {
                                                        $fieldvalue = substr($fieldvalue, 0, $fieldmaxlength);
                                                }

                                                # save the updated local variable string back to the field array
                                                $fieldarray[$i] = $fieldvalue;
                                        }
                                }
                }

                # convert null (undefined) fields into empty strings
                # and join all into a single string with each field separated by a single tab character
                $print_csv_line = join("\t", map { $_ //= '' } @fieldarray);

				# remove any embedded carriage returns and line feeds from the print line string
                $print_csv_line =~ s/[\r\n]//g;

                # print the line out to the file with a carriage return at the end
                print $fh $print_csv_line . "\n";

    }

        # close the file
		close $fh;

        # finished with SQL statement handle
        warn sprintf("%s row(s) of data exported from table %s", $sth->rows, $table->{name});
        $sth->finish;

        # return the temporary file
		return $dump;
}

# Main program

\do { print <<END
    Usage:
    ./dump.pl \<user/pass\@host/sid\> \<vocabulary version number\> \<output.zip\> [vocabulary ids]
    'vocabulary ids' is a comma-separated list of required vocabulary ids, omit the list in order to dump all available
END
} and exit unless @ARGV;

# Get database connection command line argument and connect to the Oracle database
die "Valid database access information required." unless shift =~ /^(.+)\/(.+)\@(.+)\/(.+)$/;
#warn sprintf("host=%s, sid=%s, userid=%s, password=%s", $3, $4, $1, $2);
my $dbh = DBI->connect(sprintf('dbi:Oracle:host=%s;sid=%s', $3, $4), $1, $2) or die "Valid database access information required.";

# Get vocabulary version number command line argument
my $vocabulary_version_number = shift or die "vocabulary version number required.";

# note.  Only versions 4.5 and 5 currently supported in this code
# note.  To support new versions update the code below and also add code later in this source file to dump additional new version tables
die "vocabulary version number must be either 4.5 or 5." unless ($vocabulary_version_number eq '4.5' or $vocabulary_version_number eq '5');

# map from vocabulary version number to the correct schema to use in this database session
my $schema;
if ($vocabulary_version_number == 4.5)
{
  $schema = "PRODV4";
}
else
{
 $schema = "PRODV5";
}
warn sprintf("Writing version %s vocabularies from schema %s", $vocabulary_version_number, $schema);

$dbh->do(sprintf('ALTER SESSION SET CURRENT_SCHEMA = %s', $schema));
$dbh->do('ALTER SESSION SET NLS_DATE_FORMAT="YYYYMMDD"');

# Get output zip file name command line argument
my $output = shift or die "File name for output file required.";

# if optional comma separated string of vocabulary ids not passed on command line then default to all vocabularies in the database
my @vocabularies;
if ($vocabulary_version_number == 4.5)
{
        # v4.5 selects from VOCABULARY table
        @vocabularies = split /,/, (shift or join ',', all_vocabularies_v45 $dbh);
} else {
        # v5 selects from VOCABULARY_CONVERSION table
        @vocabularies = split /,/, (shift or join ',', all_vocabularies_v5 $dbh);
}

# create ? SQL prepare argument place-holders, one per vocabulary id in the command line vocabularies list argument
my $placeholder = join ', ', split //, '?' x @vocabularies;

# Create output zip file
my $zip = new Archive::Zip;
warn "Writing vocabularies ".join(',', @vocabularies)." to $output.";

# Create one new table data extract file in the zip file for every database table named below
# Each file will be in CSV format (with a single header line)
# and will contain only the table data where the vocabulary id is in the vocabulary ids list

if ($vocabulary_version_number == 5) {

        # dump the v5 versions of the vocabulary tables

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
         {
                name => 'DRUG_STRENGTH',
                where_clause => sprintf('INNER JOIN CONCEPT ON DRUG_CONCEPT_ID = CONCEPT_ID INNER JOIN VOCABULARY_CONVERSION ON VOCABULARY_ID = VOCABULARY_ID_V5 WHERE VOCABULARY_ID_V4 IN (%s)', $placeholder),
                params => [ @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT',
                where_clause => sprintf('WHERE VOCABULARY_ID IN (SELECT VOCABULARY_ID_V5 FROM VOCABULARY_CONVERSION WHERE VOCABULARY_ID_V4 IN (%s))', $placeholder),
                params => [ @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT_RELATIONSHIP',
                where_clause => sprintf('WHERE EXISTS (SELECT 1 FROM CONCEPT WHERE CONCEPT_ID_1 = CONCEPT_ID AND VOCABULARY_ID IN (SELECT VOCABULARY_ID_V5 FROM VOCABULARY_CONVERSION WHERE VOCABULARY_ID_V4 IN (%s))) AND EXISTS (SELECT 1 FROM CONCEPT WHERE CONCEPT_ID_2 = CONCEPT_ID AND VOCABULARY_ID IN (SELECT VOCABULARY_ID_V5 FROM VOCABULARY_CONVERSION WHERE VOCABULARY_ID_V4 IN (%s)))', $placeholder, $placeholder),
                params => [ @vocabularies, @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT_ANCESTOR',
                where_clause => sprintf('WHERE EXISTS (SELECT 1 FROM CONCEPT WHERE ANCESTOR_CONCEPT_ID = CONCEPT_ID AND VOCABULARY_ID IN (SELECT VOCABULARY_ID_V5 FROM VOCABULARY_CONVERSION WHERE VOCABULARY_ID_V4 IN (%s))) AND EXISTS (SELECT 1 FROM CONCEPT WHERE DESCENDANT_CONCEPT_ID = CONCEPT_ID AND VOCABULARY_ID IN (SELECT VOCABULARY_ID_V5 FROM VOCABULARY_CONVERSION WHERE VOCABULARY_ID_V4 IN (%s)))', $placeholder, $placeholder),
                params => [ @vocabularies, @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT_SYNONYM',
                where_clause => sprintf('WHERE EXISTS (SELECT * FROM CONCEPT c WHERE t.CONCEPT_ID = c.CONCEPT_ID AND VOCABULARY_ID IN (SELECT VOCABULARY_ID_V5 FROM VOCABULARY_CONVERSION WHERE VOCABULARY_ID_V4 IN (%s)))', $placeholder),
                params => [ @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'VOCABULARY',
                where_clause => sprintf('WHERE VOCABULARY_ID IN (SELECT VOCABULARY_ID_V5 FROM VOCABULARY_CONVERSION WHERE VOCABULARY_ID_V4 IN (%s))', $placeholder),
                params => [ @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'RELATIONSHIP',
                where_clause => '',
                params => [],
        };

        # note the CONCEPT_CLASS table was added in v5
        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT_CLASS',
                where_clause => '',
                params => [],
        };

        # note the DOMAIN table was added in v5
        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'DOMAIN',
                where_clause => '',
                params => [],
        };

}

if ($vocabulary_version_number == 4.5) {

        # dump the v4.5 versions of the vocabulary tables

        # note the DRUG_APPROVAL table was removed in v4.5

        # note the SOURCE_TO_CONCEPT_MAP table was populated in v4.5 but is not populated in v5
        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'SOURCE_TO_CONCEPT_MAP',
                where_clause => sprintf('WHERE SOURCE_VOCABULARY_ID IN (%s)', $placeholder),
                params => [ @vocabularies ],
        };

        # note the DRUG_STRENGTH table was added in v4.5
        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'DRUG_STRENGTH',
                where_clause => sprintf('INNER JOIN CONCEPT ON DRUG_CONCEPT_ID = CONCEPT_ID WHERE VOCABULARY_ID IN (%s)', $placeholder),
                params => [ @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT',
                where_clause => sprintf('WHERE VOCABULARY_ID IN (%s)', $placeholder),
                params => [ @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT_RELATIONSHIP',
                where_clause => sprintf('WHERE EXISTS (SELECT * FROM CONCEPT WHERE CONCEPT_ID_1 = CONCEPT_ID AND VOCABULARY_ID IN (%s)) AND EXISTS (SELECT * FROM CONCEPT WHERE CONCEPT_ID_2 = CONCEPT_ID AND VOCABULARY_ID IN (%s))', $placeholder, $placeholder),
                params => [ @vocabularies, @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT_ANCESTOR',
                where_clause => sprintf('WHERE EXISTS (SELECT * FROM CONCEPT WHERE ANCESTOR_CONCEPT_ID = CONCEPT_ID AND VOCABULARY_ID IN (%s)) AND EXISTS (SELECT * FROM CONCEPT WHERE DESCENDANT_CONCEPT_ID = CONCEPT_ID AND VOCABULARY_ID IN (%s))', $placeholder, $placeholder),
                params => [ @vocabularies, @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'CONCEPT_SYNONYM',
                where_clause => sprintf('WHERE EXISTS (SELECT * FROM CONCEPT c WHERE t.CONCEPT_ID = c.CONCEPT_ID AND VOCABULARY_ID IN (%s))', $placeholder),
                params => [ @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'VOCABULARY',
                where_clause => sprintf('WHERE VOCABULARY_ID IN (%s)', $placeholder),
                params => [ @vocabularies ],
        };

        $zip->addFile(csv_dump($dbh, $_), sprintf('%s.csv', $_->{name})) for
        {
                name => 'RELATIONSHIP',
                where_clause => '',
                params => [],
        };
}

# write out the zip file
die "Cannot write zip file: $!" unless $zip->writeToFileNamed($output) == Archive::Zip::AZ_OK;
unlink $_->{externalFileName} for $zip->members;

# close the database connection
$dbh->disconnect  or warn $dbh->errstr;

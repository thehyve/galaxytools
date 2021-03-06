#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;

sub parse_command_line();
sub build_regex_string();
sub usage();

my $input_file ;
my $output_file;
my $find_pattern ;
my $replace_pattern ;
my $find_complete_words ;
my $find_pattern_is_regex ;
my $find_in_specific_column ;
my $find_case_insensitive ;
my $replace_global ;
my $skip_first_line ;


##
## Program Start
##
usage() if @ARGV<2;
parse_command_line();
my $regex_string = build_regex_string() ;

# Allow first line to pass without filtering?
if ( $skip_first_line ) {
	my $line = <$input_file>;
	print $output_file $line ;
}


##
## Main loop
##

## I LOVE PERL (and hate it, at the same time...)
##
## So what's going on with the self-compiling perl code?
##
## 1. The program gets the find-pattern and the replace-pattern from the user (as strings).
## 2. If both the find-pattern and replace-pattern are simple strings (not regex), 
##    it would be possible to pre-compile a regex (with qr//) and use it in a 's///'
## 3. If the find-pattern is a regex but the replace-pattern is a simple text string (with out back-references)
##    it is still possible to pre-compile the regex and use it in a 's///'
## However,
## 4. If the replace-pattern contains back-references, pre-compiling is not possible.
##    (in perl, you can't precompile a substitute regex).
##    See these examples:
##    http://www.perlmonks.org/?node_id=84420
##    http://stackoverflow.com/questions/125171/passing-a-regex-substitution-as-a-variable-in-perl
##
##    The solution:
##    we build the regex string as valid perl code (in 'build_regex()', stored in $regex_string ),
##    Then eval() a new perl code that contains the substitution regex as inlined code.
##    Gotta love perl!

my $perl_program ;
if ( $find_in_specific_column ) {
	# Find & replace in specific column

	$perl_program = <<EOF;
	while ( <STDIN> ) {
		chomp ;
		my \@columns = split ;

		#not enough columns in this line - skip it
		next if ( \@columns < $find_in_specific_column ) ;

		\$columns [ $find_in_specific_column - 1 ] =~ $regex_string ;

		print STDOUT join("\t", \@columns), "\n" ;
	}
EOF

} else {
	# Find & replace the entire line
	$perl_program = <<EOF;
		while ( <STDIN> ) {
			$regex_string ;
			print STDOUT;
		}
EOF
}


# The dynamic perl code reads from STDIN and writes to STDOUT,
# so connect these handles (if the user didn't specifiy input / output
# file names, these might be already be STDIN/OUT, so the whole could be a no-op).
*STDIN = $input_file ;
*STDOUT = $output_file ;
eval $perl_program ;


##
## Program end
##


sub parse_command_line()
{
	my %opts ;
	getopts('grsiwc:o:', \%opts) or die "$0: Invalid option specified\n";

	die "$0: missing Find-Pattern argument\n" if (@ARGV==0); 
	$find_pattern = $ARGV[0];
	die "$0: missing Replace-Pattern argument\n" if (@ARGV==1); 
	$replace_pattern = $ARGV[1];

	$find_complete_words = ( exists $opts{w} ) ;
	$find_case_insensitive = ( exists $opts{i} ) ;
	$skip_first_line = ( exists $opts{s} ) ;
	$find_pattern_is_regex = ( exists $opts{r} ) ;
	$replace_global = ( exists $opts{g} ) ;

	# Search in specific column ?
	if ( defined $opts{c} ) {
		$find_in_specific_column = $opts{c};

		die "$0: invalid column number ($find_in_specific_column).\n"
			unless $find_in_specific_column =~ /^\d+$/ ;
			
		die "$0: invalid column number ($find_in_specific_column).\n"
			if $find_in_specific_column <= 0; 
	}
	else {
		$find_in_specific_column = 0 ;
	}

	# Output File specified (instead of STDOUT) ?
	if ( defined $opts{o} ) {
		my $filename = $opts{o};
		open $output_file, ">$filename" or die "$0: Failed to create output file '$filename': $!\n" ;
	} else {
		$output_file = *STDOUT ;
	}


	# Input file Specified (instead of STDIN) ?
	if ( @ARGV>2 ) {
		my $filename = $ARGV[2];
		open $input_file, "<$filename" or die "$0: Failed to open input file '$filename': $!\n" ;
	} else {
		$input_file = *STDIN;
	}
}

sub build_regex_string()
{
	my $find_string ;
	my $replace_string ;

	if ( $find_pattern_is_regex ) {
		$find_string = $find_pattern ;
		$replace_string = $replace_pattern ;
	} else {
		$find_string = quotemeta $find_pattern ;
		$replace_string = quotemeta $replace_pattern;
	}

	if ( $find_complete_words ) {
		$find_string = "\\b($find_string)\\b"; 
	}

	my $regex_string = "s/$find_string/$replace_string/";

	$regex_string .= "i" if ( $find_case_insensitive );
	$regex_string .= "g" if ( $replace_global ) ;
	

	return $regex_string;
}

sub usage()
{
print <<EOF;

Find and Replace
Copyright (C) 2009 - by A. Gordon ( gordon at cshl dot edu )

Usage: $0 [-o OUTPUT] [-g] [-r] [-w] [-i] [-c N] [-l] FIND-PATTERN REPLACE-PATTERN [INPUT-FILE]

   -g   - Global replace - replace all occurences in line/column. 
          Default - replace just the first instance.
   -w   - search for complete words (not partial sub-strings).
   -i   - case insensitive search.
   -c N - check only column N, instead of entire line (line split by whitespace).
   -l   - skip first line (don't replace anything in it)
   -r   - FIND-PATTERN and REPLACE-PATTERN are perl regular expression,
          usable inside a 's///' statement.
          By default, they are used as verbatim text strings.
   -o OUT - specify output file (default = STDOUT).
   INPUT-FILE - (optional) read from file (default = from STDIN).


EOF

	exit;
}

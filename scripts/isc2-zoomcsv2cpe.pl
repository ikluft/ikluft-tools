#!/usr/bin/perl 
#===============================================================================
#         FILE: zoomcsv2cpe.pl
#  DESCRIPTION: convert Zoom webinar attendee report to ISC² CPE list
#       AUTHOR: Ian Kluft
# ORGANIZATION: (ISC)² Silicon Valley Chapter
#      CREATED: 04/14/2021 04:12:54 PM
#===============================================================================
use strict;
use warnings;
use utf8;
use autodie;
use Modern::Perl qw(2018);
use Carp qw(croak);
use Getopt::Long;
use File::Slurp;
use Date::Calc;
use File::BOM qw(:subs);
use Text::CSV_XS qw(csv);
use YAML::XS;

use Data::Dumper;

# configuration
my %config = (
	max_cpe => 2,	# default 2 CPEs
	start_grace_period => 10, # 10 minute connection grace period at schedule start to qualify for max CPEs
	output => "/dev/stdout",
);

# globals
my (%timestamp, %tables, %index, %attendee);

#
# functions
#

# generate name-to-index hash from list of strings (table names or column headings)
sub genIndexHash
{
	my $list = shift;
	if (ref $list ne "ARRAY") {
		croak "genIndexHash() requires ARRAY ref parameter, got ".(defined $list ? (ref $list) : "undef");
	}
	my %indexHash;
	for (my $i=0; $i < scalar @$list; $i++) {
		$indexHash{$list->[$i]} = $i;
	}
	return \%indexHash;
}

# parse date & time string into an array of 6 integers (y-m-d-h-m-s) usable by Date::Calc
sub parseDate
{
	my $date_str = shift;
	defined $date_str or croak "parseDate: undefined data string";
	if ($date_str =~ /(\w+)\s+(\d+),\s+(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM)/) {
		my $month = Date::Calc::Decode_Month($1);
		my $day = $2;
		my $year = $3;
		my $hour = $4;
		my $min = $5;
		my $ampm = $6;
		if ($ampm eq "PM") {
			$hour += 12;
		}
		return ($year, $month, $day, $hour, $min, 0);
	} elsif ($date_str =~ /(\w+)\s+(\d+),\s+(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})/) {
		my $month = Date::Calc::Decode_Month($1);
		my $day = $2;
		my $year = $3;
		my $hour = $4;
		my $min = $5;
		my $sec = $6;
		return ($year, $month, $day, $hour, $min, $sec);
	} elsif ($date_str =~ /(\d{4})-(\d{2})-(\d{2})\s(\d{2}):(\d{2}):(\d{2})/) {
		my $year = $1;
		my $month = $2;
		my $day = $3;
		my $hour = $4;
		my $min = $5;
		my $sec = $6;
		return ($year, $month, $day, $hour, $min, $sec);
	}
	my @date = Date::Calc::Parse_Date($date_str);
	if (not @date) {
		croak "failed to parse date";
	}
	return @date;
}

# combine adjacent attendance timeline entries
# if two adjacent timeline entries are non-overlapping but within 60 seconds, combine them into one
# for promotion of an attendee to panelist without disconnection, the difference will be 0-1 seconds
sub combineTimeline
{
	my $timeline = shift;
	my $index = 0;
	#foreach my $rec (@$timeline) {
	#	say STDERR "debug: combineTimeline: ".join(" ", map { $_."=".$rec->{$_} } sort keys %$rec);
	#}
	while ($index < scalar @$timeline-1) {
		#say STDERR "debug: combineTimeline: index=$index size=".(scalar @$timeline);
		my $cur_end = Date::Calc::Date_to_Time(parseDate($timeline->[$index]{'leave time'}));
		my $next_start = Date::Calc::Date_to_Time(parseDate($timeline->[$index+1]{'join time'}));
		if ($cur_end <= $next_start and $next_start - $cur_end < 60) {
			# endpoints within a minute so merge the timeline entries
			$timeline->[$index]{type} = $timeline->[$index]{type}.'/'.$timeline->[$index+1]{type};
			$timeline->[$index]{'leave time'} = $timeline->[$index+1]{'leave time'};
			$timeline->[$index]{'time in session (minutes)'} += $timeline->[$index+1]{'time in session (minutes)'};
			splice @$timeline, $index+1,1; # delete the second record now merged into the first
		} else {
			$index++;
		}
	}
}

# compute CPEs from attendee timeline data
sub computeCPE
{
	my $attendee = shift;

	my $minutes = 0.0;
	my $prev_type;
	combineTimeline($attendee->{timeline});
	foreach my $timeline_rec (@{$attendee->{timeline}}) {
		# compute minutes of attendance for this timeline record
		# shirt-circuit out of the loop with max CPEs if attendance spans start to end of business
		my @join_time = parseDate($timeline_rec->{'join time'});
		my @leave_time = parseDate($timeline_rec->{'leave time'});
		my $at_start = (Date::Calc::Date_to_Time(@{$timestamp{bus_start}})) >= Date::Calc::Date_to_Time(@join_time);
		my $at_end = Date::Calc::Date_to_Time(@{$timestamp{bus_end}}) <= Date::Calc::Date_to_Time(@leave_time);
		if ($at_start and $at_end) {
			# return max CPEs because one attendance record spans entire meeting from start to end of business
			return $config{max_cpe};
		}
		if ($at_start and not $at_end) {
			$minutes += (Date::Calc::Date_to_Time(@leave_time) - Date::Calc::Date_to_Time(@{$timestamp{start}}))/60.0;
		} elsif (not $at_start and $at_end) {
			$minutes = (Date::Calc::Date_to_Time(@{$timestamp{end}}) - Date::Calc::Date_to_Time(@join_time))/60.0;
		} else { # not present at start or end: use total minutes from join to leave for CPEs
			$minutes += (Date::Calc::Date_to_Time(@leave_time) - Date::Calc::Date_to_Time(@join_time))/60.0;
		}
		$prev_type = $timeline_rec->{type};
	}
	$attendee->{cpe_minutes} = sprintf("%6.3f", $minutes);
	my $cpe = int($minutes/60.0*4+.45)/4.0; # round to the nearest quarter CPE point
	if ($cpe > $config{max_cpe}) {
		$cpe = $config{max_cpe};
	}
	return $cpe;
}

# fetch data from a table by row & column
sub tableFetch
{
	my $args = shift;
	(ref $args eq "HASH")
		or croak "tableFetch() HASH argument required";
	my %missing;
	foreach my $field (qw(table row col)) {
		if (not exists $args->{$field}) {
			$missing{$field} = 1;
		}
	}
	if (%missing) {
		croak "tableFetch() missing parameters: ".(join " ", sort keys %missing);
	}
	my ($table, $row, $col) = ($args->{table}, $args->{row}, $args->{col});
	if (not exists $tables{$table}) {
		croak "tableFetch() no such table $table - defined tables: ".(join ", ", sort keys %tables);
	}
	if (not exists $index{$table}) {
		croak "tableFetch() no index for table $table";
	}
	if (not exists $index{$table}{$col}) {
		croak "tableFetch() no index for $col in table $table";
	}
	if ($row < 0 or $row >= $tables{$table}{count}) {
		croak "tableFetch() no row $row in table $table, max=".($tables{$table}{count}-1);
	}
	return $tables{$table}{data}[$row][$index{$table}{$col}];
}

#
# mainline
#

# read command line arguments
my %cmd_arg;
GetOptions( \%cmd_arg, "max_cpe|cpe:i", "start:s", "end:s", "bus_end|biz:s", "start_grade_period|grace:i",
	"title|meeting_title:s", "config_file|config:s", "output:s")
	or croak "command line argument processing failed";

# read YAML configuration
# YAML configuration can set same options as the command line
# It's also the way to set CPEs for meeting hosts & speakers who aren't properly listed in the Zoom attendee report
if (exists $cmd_arg{config_file} and defined $cmd_arg{config_file}) {
	if (not -f $cmd_arg{config_file}) {
		croak "file ".$cmd_arg{config_file}." does not exist";
	}
	my $data = YAML::XS::LoadFile($cmd_arg{config_file});
	#say "debug: YAML data -> ".Dumper($data);

	if (ref $data eq "HASH") {
		# copy base configuration from YAML to config
		if (exists $data->{config} and ref $data->{config} eq "HASH") {
			foreach my $key (keys %{$data->{config}}) {
				$config{$key} = $data->{config}{$key};
			}
		}

		# copy attendee data (hosts/speakers not documented by Zoom attendee report) from YAML to attendee list
		if (exists $data->{attendee} and ref $data->{attendee} eq "HASH") {
			foreach my $key (keys %{$data->{attendee}}) {
				$attendee{$key} = $data->{attendee}{$key};
			}
		}
	}
}

# apply command-line arguments after YAML configuration so they can override it
foreach my $key (keys %cmd_arg) {
	$config{$key} = $cmd_arg{$key};
}

# read CSV text
my $csv_file = shift @ARGV;
if (not $csv_file) {
	$csv_file = "/proc/self/fd/0"; # use STDIN
}
if (not -f $csv_file) {
	croak "file $csv_file does not exist";
}
open_bom(my $fh, $csv_file, ":utf8"); # use File::BOM::open_bom because Zoom's CSV report is UTF8 with Byte Order Mark
my @lines;
while (<$fh>) {
	chomp; # remove newlines
	push @lines, $_;
}
close $fh;

#
# 1st pass: Divide separate Zoom reports into their own CSV tables.
#

# CSV libraries can't process multiple CSV tables concatenated into one file like Zoom makes.
my $table_title = "none";
my @table_titles;
my %csv_tables;
while (my $line = shift @lines) {
	if ($line =~ /^([^,]+),$/) {
		$table_title = lc $1;
		push @table_titles, $table_title;
		next;
	}
	if ($line =~ /^Report Generated:,"([^"]*)"$/) {
			$timestamp{generated} = [parseDate($1)];
			next;
	}
	if (not exists $csv_tables{$table_title}) {
		$csv_tables{$table_title} = [];
	}
	push @{$csv_tables{$table_title}}, $line;
}

# debug: print names and sizes of tables
#foreach my $table (sort keys %csv_tables) {
#	say $table.": ".scalar(@{$csv_tables{$table}});
#}

#
# 2nd pass: process CSV text tables into array-of-arrays structure
#
foreach my $table (sort keys %csv_tables) {
	$tables{$table} = {};
	$tables{$table}{data} = [];
	my $csv = Text::CSV_XS->new({binary => 1, blank_is_undef => 1, empty_is_undef => 1});
	if (not defined $csv) {
		croak "Text::CSV_XS initialization failed: ".Text::CSV_XS->error_diag ();
	}
	$tables{$table}{count} = -1; # start count from -1 so the header won't be included
	foreach my $csv_line (@{$csv_tables{$table}}) {
		$csv->parse($csv_line);
		if ($tables{$table}{count} == -1) {
			$csv->column_names(map {lc $_} ($csv->fields()));
			$tables{$table}{columns} = [$csv->column_names()];
		} else {
			push @{$tables{$table}{data}}, [$csv->fields()];
		}
		$tables{$table}{count}++;
	}
}

# debug: print data from 2nd pass
#say Dumper(\%tables);

#
# 3rd pass: tally user attendance
#

#
# make indices for tables and columns
#
#$index{tables} = genIndexHash(\@table_titles);
foreach my $table (@table_titles) {
	$index{$table} = genIndexHash($tables{$table}{columns});
}
#say Dumper(\%index);

#
# determine meeting start & end timestamps
# stream_start: start of video stream, collected from webinar report header
# stream_end: end of video stream, collected from webinar report header
# start: scheduled start time
# end: scheduled end time, defaults to max_cpe hours after scheduled start time
# bus_start: start of business is scheduled start time + connection grace period (default 10 minutes)
# bus_end: business end time, defaults to meeting end time
#
my $actual_start = tableFetch({table => 'attendee report', row => 0, col => 'actual start time'});
my $duration = tableFetch({table => 'attendee report', row => 0, col => 'actual duration (minutes)'});
$timestamp{stream_start} = [parseDate($actual_start)];
$timestamp{stream_end} = [Date::Calc::Add_Delta_DHMS(parseDate($actual_start), 0, 0, $duration, 0)];
if (exists $config{start} and defined $config{start}) {
	$timestamp{start} = [parseDate($config{start})];
} else {
	# start time defaults to stream start, highly recommended to use --start parameter to set scheduled start time
	$timestamp{start} = $timestamp{stream_start};
}
$timestamp{bus_start} = [Date::Calc::Add_Delta_DHMS(@{$timestamp{start}}, 0, 0, $config{start_grace_period}, 0)];
if (exists $config{end} and defined $config{end}) {
	$timestamp{end} = [parseDate($config{end})];
} else {
	# end time defaults to start time + max_cpe hours
	$timestamp{end} = [Date::Calc::Add_Delta_DHMS(@{$timestamp{start}}, 0, $config{max_cpe}, 0, 0)];
}
if (exists $config{bus_end} and defined $config{bus_end}) {
	$timestamp{bus_end} = [parseDate($config{bus_end})];
} else {
	# end of business detaults to end of meeting, highly recommended to use --bix parameter to set end of business time
	$timestamp{bus_end} = $timestamp{end};
}
#foreach my $rec (keys %timestamp) {
#	say STDERR "debug: timestamp $rec: ".join("-", @{$timestamp{$rec}});
#}

# assemble per-user attendance data
foreach my $table ('host details', 'attendee details', 'panelist details') {
	my $type;
	if ($table =~ /^(\w+) details/) {
		$type = $1;
	} else {
		$type = $table;
	}
	foreach my $record (@{$tables{$table}{data}}) {
		if ((not exists $record->[$index{$table}{attended}]) or $record->[$index{$table}{attended}] eq "No") {
			next;
		}
		my $email = $record->[$index{$table}{email}];
		defined $email or next;

		# create new attendee record if it doesn't already exist
		# multiple records per attendee may occur for disconnect/reconnect or promotion to panelist
		if (not exists $attendee{$email}) {
			$attendee{$email} = {};
			$attendee{$email}{timeline} = [];
			foreach my $field ('first name', 'last name')
			{
				if ((exists $index{$table}{$field})
					and (exists $record->[$index{$table}{$field}]))
				{
					if (not exists $attendee{$email}{$field}) {
						$attendee{$email}{$field} = $record->[$index{$table}{$field}];
					}
				}
			}

			# rename isc2 field from survey form
			# TODO: allow recognition of various survey field names for the isc2 certification number
			my $isc2field = "(isc)2 certification:";
			if ((exists $index{$table}{$isc2field})
				and (exists $record->[$index{$table}{$isc2field}]))
			{
				if (not exists $attendee{$email}{isc2}) {
					$attendee{$email}{isc2} = $record->[$index{$table}{$isc2field}];
				}
			}
		}

		# add an attendee timeline record for the attendance data
		my $timeline = {type => $type};
		foreach my $field ('join time', 'leave time', 'time in session (minutes)') {
			$timeline->{$field} = $record->[$index{$table}{$field}];
		}
		push @{$attendee{$email}{timeline}}, $timeline;
	}
}

#
# compute attendee CPEs and generate CSV (spreadsheet) output CPE data for ISC²
#
my @isc2_output;

# open CSV output filehandle
open my $out_fh, ">", $config{output}
	or croak "failed to open ".$config{output}." for writing: $!";
my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });
$csv->say($out_fh,
	["(ISC)² Member #", "Member First Name", "Member Last Name", "Title of Meeting", "# CPEs",
	"Date of Activity", "CPE qualifying minutes"]);

# loop through attendee records: compute CPEs and output CSV CPE data for ISC²
foreach my $akey (sort {$attendee{$a}{'last name'} cmp $attendee{$b}{'last name'}} keys %attendee) {
	if (not exists $attendee{$akey}{cpe}) {
		my $cpe = computeCPE($attendee{$akey});
		next if not defined $cpe;
		if ($cpe > 0) {
			$attendee{$akey}{cpe} = $cpe;
		}
	}

	# if ISC² member certificate number is available, generate CSV for ISC²
	if (exists $attendee{$akey}{isc2}) {
		my $record = $attendee{$akey};
		$csv->say ($out_fh,
			[$record->{isc2}, $record->{'first name'}, $record->{'last name'},
			$config{title}, $record->{cpe},
			sprintf("%02d/%02d/%04d", $timestamp{start}[1], $timestamp{start}[2], $timestamp{start}[0]),
			$record->{cpe_minutes}]);
	}
}
close $out_fh
	or croak "failed to close ".$config{output}.": $!";
#say "debug: attendee data -> ".Dumper(\%attendee);

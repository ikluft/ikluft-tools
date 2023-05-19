#!/usr/bin/env perl
#===============================================================================
#         FILE: space-story-count.pl
#        USAGE: ./space-story-count.pl yaml-config-file
#  DESCRIPTION: count space story rankings for JetCityStar Aerospace Chat
#       AUTHOR: Ian Kluft (IKLUFT), ikluft@cpan.org
#      CREATED: 03/02/2023 03:34:32 PM
#
# example YAML input file:
#
#     ---
#     # yamllint disable rule:line-length
#     vote_def: 2023-05-21_space_stories_Sheet1.csv
#     name: JetCityCtar Aerospace Chat space stories 2023-05-21
#     vote_end: Fri 2023-05-19 09:00 US Pacific (11am US Central, 12noon US Eastern, Sat 01:30 Australia Central)
#     method: rankedpairs
#
# where:
# * vote_def is a CSV download of the team voting spreadsheet
#   data sections are delimited by blank lines and start with a [SECTION_NAME] cell in column 1
#   required sections: CHOICE_LIST, RANKINGS
#   suggested sections reserved for future: DUE_DATES
# * name is the title to display on the HTML/PDF output
# * vote_end is the date/time to display for when voting ends/ended
# * method is the preference voting algoritm, either "rankedpairs" or "schulze"
#===============================================================================

use strict;
use warnings;
use utf8;
use autodie;
use feature qw(say fc);
use experimental qw(try);
use Readonly;
use Carp qw(croak);
use File::Slurp qw(read_file);
use IO::ScalarArray;
use DateTime qw(now date time time_zone_short_name);
use PrefVote;
use PrefVote::Core;
use PrefVote::RankedPairs;
use PrefVote::Schulze;
use YAML::XS;
use Text::CSV_XS qw( csv );
use Data::Dumper;

# algorithm data
Readonly::Scalar my $DEFAULT_METHOD => fc("rankedpairs");
Readonly::Hash my %methods => (
    fc("rankedpairs") => {
        name => "RankedPairs",
        class => "PrefVote::RankedPairs",
        description => [
            '<a href="https://en.wikipedia.org/wiki/Ranked_pairs">Ranked Pairs</a> (Wikipedia), ',
            'a href="https://github.com/ikluft/prefvote#ranked-pairs-voting-results-from-the-example-data">PrefVote/Ranked Pairs</a> (GitHub)'
        ]
    },
    fc("schulze") => {
        name => "Schulze",
        class => "PrefVote::Schulze",
        description => [
            'algorithm: <a href="https://en.wikipedia.org/wiki/Schulze_method">Schulze method</a> (Wikipedia), ',
            '<a href="https://github.com/ikluft/prefvote#schulze-method-results-from-the-example-data">PrefVote/Schulze</a> (GitHub)'
        ],
    },
);

# input ballots to a PrefVote::Core-subclass voting method
sub ingest_ballots
{
    my ( $vote_obj, $ballots ) = @_;

    # ingest ballots from YAML data
    my $submitted = 0;
    my $accepted  = 0;
    foreach my $ballot (@$ballots) {
        $submitted++;
        if ( eval { $vote_obj->submit_ballot(@$ballot) } ) {
            $accepted++;
        } else {
            $vote_obj->debug_print("ballot entry failed: $@");
        }
    }
    $vote_obj->debug_print("votes: submitted=$submitted accepted=$accepted");
    return;
}

# convert CSV text to data
sub csv_text2data {
    my @csv_text = @_;
    my $csv_handle = IO::ScalarArray->new(\@csv_text);
    my $csv_data;
    try {
        $csv_data = csv (in => $csv_handle, headers => "auto", comment => "#");
    } catch ($e) {
        croak "CSV processing failure $e\nCSV text: ".join("", @csv_text);
    } finally {
        $csv_handle->close();
    }
    return $csv_data;
}

# get YAML config file name from command line
if (scalar @ARGV < 1) {
    croak "usage: $0 yaml-config-file";
}
my $yaml_config_file = $ARGV[0];

# read YAML config
if (not -f $yaml_config_file) {
    croak "file not found: $yaml_config_file";
}
my @yaml_docs = eval { YAML::XS::LoadFile($yaml_config_file) };
if ($@) {
    croak "failed to read YAML data: $@"; 
}
if (scalar @yaml_docs > 0 and not exists $yaml_docs[0]{vote_def}) {
    croak "vote_def parameter (CSV file path) not found in YAML config";
}
my $csv_path = $yaml_docs[0]{vote_def};
if (scalar @yaml_docs > 0 and not exists $yaml_docs[0]{name}) {
    croak "name parameter (vote title) not found in YAML config";
}
my $name = $yaml_docs[0]{name};
if (scalar @yaml_docs > 0 and not exists $yaml_docs[0]{vote_end}) {
    croak "vote_end parameter (sheduled end) not found in YAML config";
}
my $vote_end = $yaml_docs[0]{vote_end};
my $method = (exists $yaml_docs[0]{method}) ? fc($yaml_docs[0]{method}) : $DEFAULT_METHOD;
if (not exists $methods{$method}) {
    croak "method $method not recognized"
}

# read CSV file
my @csv_text = read_file( $csv_path);

# parse file into CSV groupings delimited by blank lines
my %csv_group;
my (@current_group, $current_name);
for (my $line=0; $line < scalar @csv_text; $line++) {
    #chomp $csv_text[$line];
    if ($csv_text[$line] =~ /^,+\s*$/x) {
        if (defined $current_name) {
            # remove any blank fields at the end of the header line
            $current_group[0] =~ s/,+(\s*)$/$1/x;

            # save CSV group
            $csv_group{$current_name} = [ @current_group ];
            $current_name = undef;
            @current_group = ();
        }
        next;
    }
    if (( not scalar @current_group ) and $csv_text[$line] =~ /^\[([\w]+)\]/x) {
        $current_name = $1;
        next;
    }
    if (defined $current_name) {
        push @current_group, $csv_text[$line];
    }
}

# save last accumulated entry
if (defined $current_name) {
    # remove any blank fields at the end of the header line
    $current_group[0] =~ s/,+(\s*)$/$1/x;

    # save CSV group
    $csv_group{$current_name} = [ @current_group ];
    $current_name = undef;
    @current_group = ();
}

# process choice data
say STDERR "CSV groups: ".Dumper(\%csv_group);
my $choice_data = csv_text2data(@{$csv_group{"CHOICE_LIST"}});
say STDERR "choice data: ".Dumper($choice_data);
my $ranking_data = csv_text2data(@{$csv_group{"RANKINGS"}});
say STDERR "ranking data: ".Dumper($ranking_data);

# process rankings
my %rankings;
foreach my $rank_vote (@$ranking_data) {
    my ($member, $ranking) = ( $rank_vote->{"space team member"}, $rank_vote->{"ranking order"});
    next if ( $ranking =~ /^\s*$/x );
    $rankings{$member} = [ split(/\s+/x, $ranking)];
}
say STDERR "rankings processed: ".Dumper(\%rankings);

# start output
say "<html>";
say "<head>";
say "<title>$name</title>";
say '<link rel="stylesheet" href="ranking.css">';
say "</head>";
say "<body>";
my $timestamp = DateTime->now(time_zone => "US/Pacific");
say "<h1>$name</h1>";
say "<p>";
say "processed rankings from: ".join(", ", sort keys(%rankings));
say "<br/>";
say "time: ".$timestamp->date()." ".$timestamp->time()." ".$timestamp->time_zone_short_name();
say "<br/>";
say "voting ends: $vote_end";
say "<br/>";
say 'algorithm: ';
foreach my $alg_desc_line ( @{$methods{$method}{description}} ) {
    say $alg_desc_line;
}
say "<p/>";

# set up voting parameters
my %vote_def;
my $method_name = $methods{$method}{name};
$vote_def{method} = $method_name;
$vote_def{params} = {};
$vote_def{params}{name} = $name;
$vote_def{params}{seats} = 2;
$vote_def{params}{choices} = {};
foreach my $csv_choice (@$choice_data) {
    my $id = $csv_choice->{"choice identifier"};
    my $title = $csv_choice->{"URL/title"};
    my $source = $csv_choice->{"story source"};
    $vote_def{params}{choices}{$id} = $title." - ".$source;
}

# run vote count
PrefVote->debug(1);
say STDERR "vote def: ".Dumper(\%vote_def);
my $method_class = $methods{$method}{class};
my $vote_obj = eval { $method_class->instance(%{$vote_def{params}}) };
if ( $@ ) {
    croak "failed to instantiate $method_name object: $@";
}
if ( not defined $vote_obj ) {
    croak "failed to instantiate $method_name object";
}
ingest_ballots($vote_obj, [values %rankings]);
$vote_obj->count();
$vote_obj->format_output("HTML");
say '</body>';
say '</html>';

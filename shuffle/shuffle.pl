#!/usr/bin/env perl 
#===============================================================================
#         FILE: shuffle.pl
#        USAGE: ./shuffle.pl < input.txt > output.txt 
#  DESCRIPTION: randomly shuffle lines of text input
#       AUTHOR: Ian Kluft
#      CREATED: 07/11/2022 09:53:52 PM
#===============================================================================

use strict;
use warnings;
use utf8;
use List::Util qw(shuffle);

# shuffle the list
print shuffle ( <> );

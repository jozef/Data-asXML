#!/usr/bin/perl -T
use utf8;
use strict;
use warnings;

use Data::asXML qw();
use Test::More tests => 7;
use Test::Differences;
binmode(Test::More->builder->$_ => q(encoding('UTF-8'))) for qw(output failure_output todo_output);

my $dxml = Data::asXML->new;

my @baggage = (qw(normal %de Österreich),                         # SvUTF8 on
"normal", "%de", "\303\226sterreich", chr(0).chr(1).chr(2));      # SvUTF8 off

for my $before (@baggage) {
    my $after = $dxml->decode($dxml->encode($before));
    eq_or_diff $after, $before, "$before makes an explicit round-trip";
#     is(utf8::is_utf8($after), utf8::is_utf8($before));    # we should not care about that.
#     use Devel::Peek; diag Dump [$before, $after];
}

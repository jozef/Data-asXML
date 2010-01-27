#!/usr/bin/perl -T
use utf8;
use strict;
use warnings;

use Data::asXML qw();
use Test::More tests => 263;
binmode(Test::More->builder->$_ => q(encoding(:UTF-8))) for qw(output failure_output todo_output);

my $dxml = Data::asXML->new;

my @baggage = (qw(normal %de Österreich),                         # SvUTF8 on
"normal", "%de", "\214sterreich", chr(0).chr(1).chr(2));      # SvUTF8 off

for my $before (@baggage) {
    my $after = $dxml->decode($dxml->encode($before));
    is($after, $before, "$before makes an explicit round-trip");
#     is(utf8::is_utf8($after), utf8::is_utf8($before));    # we should not care about that.
#     use Devel::Peek; diag Dump [$before, $after];
}

for my $char_number (0..255) {
    my $before = 'a'.chr($char_number).'z';
    my $xml_string = $dxml->encode($before)->toString;
    my $after  = $dxml->decode($xml_string);
    is($after, $before, 'chr('.$char_number.') makes an explicit XML ('.$xml_string.') round-trip');
}

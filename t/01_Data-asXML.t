#!/usr/bin/perl

use strict;
use warnings;

#use Test::More 'no_plan';
use Test::More tests => 8;
use Test::Differences;
use Test::Exception;
use Encode;

BEGIN {
	use_ok ( 'Data::asXML' ) or exit;
}

exit main();

sub main {

	encode_scalar: {
		my $dxml = Data::asXML->new();
		my $dom;
		
		$dom = $dxml->encode(123);
		is(
			$dom->toString,
			'<VALUE>123</VALUE>',
			'encode numeric scalar',
		);

		$dom = $dxml->encode('ščžťľžô');
		my $string = decode("utf8", '<VALUE>ščžťľžô</VALUE>');
		is(
			$dom->toString,
			$string,
			'encode utf-8 scalar',
		);
		
		$dom = $dxml->encode(undef);
		is(
			$dom->toString,
			'<VALUE/>',
			'encode undef',
		);

		$dom = $dxml->encode('');
		is(
			$dom->toString,
			'<VALUE></VALUE>',
			'encode empty string',
		);
	}

	encode_array: {
		my $dxml = Data::asXML->new();
		my $data = [ 'a', 'b', 1, 2 ];
		
		my $dom = $dxml->encode($data);
		eq_or_diff(
			$dom->toString,
			'<ARRAY>'."\n".
			'	<VALUE>a</VALUE>'."\n".
			'	<VALUE>b</VALUE>'."\n".
			'	<VALUE>1</VALUE>'."\n".
			'	<VALUE>2</VALUE>'."\n".
			'</ARRAY>',
			'encode simple array',
		);
	}

	encode_hash: {
		my $dxml = Data::asXML->new();
		my $data = { 'a' => { 'b' => 'c' } };
		
		my $dom = $dxml->encode($data);
		eq_or_diff(
			$dom->toString,
			'<HASH>'."\n".
			'	<KEY name="a">'."\n".
			'		<HASH>'."\n".
			'			<KEY name="b">'."\n".
			'				<VALUE>c</VALUE>'."\n".
			'			</KEY>'."\n".
			'		</HASH>'."\n".
			'	</KEY>'."\n".
			'</HASH>',
			'encode simple hash',
		);
	}

	encode_complex_data: {
		my $dxml = Data::asXML->new();
		my $data = {
			'that' => {
				'is' => [
					'nested',
					'lot',
					[ 'of', { 'time' => 's' } ],
					{ 'ss' => '...' }
				],
			},
		};

		my $dom = $dxml->encode($data);
		eq_or_diff(
			$dom->toString,
			'<HASH>'."\n".
			'	<KEY name="that">'."\n".
			'		<HASH>'."\n".
			'			<KEY name="is">'."\n".
			'				<ARRAY>'."\n".
			'					<VALUE>nested</VALUE>'."\n".
			'					<VALUE>lot</VALUE>'."\n".
			'					<ARRAY>'."\n".
			'						<VALUE>of</VALUE>'."\n".
			'						<HASH>'."\n".
			'							<KEY name="time">'."\n".
			'								<VALUE>s</VALUE>'."\n".
			'							</KEY>'."\n".
			'						</HASH>'."\n".
			'					</ARRAY>'."\n".
			'					<HASH>'."\n".
			'						<KEY name="ss">'."\n".
			'							<VALUE>...</VALUE>'."\n".
			'						</KEY>'."\n".
			'					</HASH>'."\n".
			'				</ARRAY>'."\n".
			'			</KEY>'."\n".
			'		</HASH>'."\n".
			'	</KEY>'."\n".
			'</HASH>',
			'encode complex nested hashes+arrays',
		);
	};
	
	return 0;
	
	# TODO

	decode_comples_data: {	
		my $dxml = Data::asXML->new();
		my $data = $dxml->decode(q{
			<HASH>
				<KEY name="some">value</KEY>
				<KEY name="in">
					<ARRAY>
						<VALUE>a</VALUE>
						<VALUE>data</VALUE>
						<VALUE>structure</VALUE>
					</ARRAY>
				</KEY>
			</HASH>
		});
	}

	
	return 0;
}


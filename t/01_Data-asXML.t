#!/usr/bin/perl

use strict;
use warnings;

use utf8;

#use Test::More 'no_plan';
use Test::More tests => 21;
use Test::Differences;
use Test::Exception;

BEGIN {
	use_ok ( 'Data::asXML' ) or exit;
}

exit main();

sub main {

	my @test_conversions = (
		# simple
		['123','<VALUE>123</VALUE>','numeric scalar'],
		['ščžťľžô', '<VALUE>ščžťľžô</VALUE>', 'utf-8 scalar'],
		[undef, '<VALUE type="undef"/>', 'undef'],
		['','<VALUE></VALUE>','empty string'],
		
		# array
		[
			[ 'a', 'b', 1, 2 ],
			'<ARRAY>'."\n".
			'	<VALUE>a</VALUE>'."\n".
			'	<VALUE>b</VALUE>'."\n".
			'	<VALUE>1</VALUE>'."\n".
			'	<VALUE>2</VALUE>'."\n".
			'</ARRAY>',
			'simple array',
		],
		
		# hash
		[
			{ 'a' => { 'b' => 'c' } },
			'<HASH>'."\n".
			'	<KEY name="a">'."\n".
			'		<HASH>'."\n".
			'			<KEY name="b">'."\n".
			'				<VALUE>c</VALUE>'."\n".
			'			</KEY>'."\n".
			'		</HASH>'."\n".
			'	</KEY>'."\n".
			'</HASH>',
			'simple hash',
		],
		
		# complex data
		[
			{
				'that' => {
					'is' => [
						'nested',
						'lot',
						[ 'of', { 'time' => 's' } ],
						{ 'ss' => '...' }
					],
				},
			},
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
			'complex nested hashes+arrays',
		],
	);

	encode: {
		foreach my $test (@test_conversions) {
			my $dxml = Data::asXML->new();
			my $dom = $dxml->encode($test->[0]);
			is(
				$dom->toString,
				$test->[1],
				'encode() - '.$test->[2],
			);
		}
	}
	
	decode: {
		foreach my $test (@test_conversions) {
			my $dxml = Data::asXML->new();
			my $data = $dxml->decode($test->[1]);
			
			is_deeply(
				$data,
				$test->[0],
				'decode() - '.$test->[2],
			);
		}
	}

	
	return 0;
}


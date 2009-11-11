#!/usr/bin/perl

use strict;
use warnings;

#use Test::More 'no_plan';
use Test::More tests => 15;
use Test::Differences;
use Test::Exception;
use Encode;

BEGIN {
	use_ok ( 'Data::asXML' ) or exit;
}

exit main();

sub main {

	my @test_conversions = (
		# simple
		['123','<VALUE>123</VALUE>','numeric scalar'],
		[decode("utf8", 'ščžťľžô'), decode("utf8", '<VALUE>ščžťľžô</VALUE>'), 'utf-8 scalar'],
		[undef, '<VALUE/>', 'undef'],
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
			
		    local $TODO = 'see http://rt.cpan.org/Public/Bug/Display.html?id=51442'
				if ($test->[2] eq 'undef');
			
			is_deeply(
				$data,
				$test->[0],
				'decode() - '.$test->[2],
			);
		}
	}

	
	return 0;
}


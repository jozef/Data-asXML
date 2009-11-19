#!/usr/bin/perl

use strict;
use warnings;

use utf8;

#use Test::More 'no_plan';
use Test::More tests => 52;
use Test::Differences;
use Test::Exception;

BEGIN {
	use_ok ( 'Data::asXML' ) or exit;
}

exit main();

sub main {
	
	test_make_relative_xpath();
	test_href_key();

	my @test_conversions = (
		# simple
		['123','<VALUE>123</VALUE>','numeric scalar'],
		['ščžťľžô', '<VALUE>ščžťľžô</VALUE>', 'utf-8 scalar'],
		['迪拉斯', '<VALUE>迪拉斯</VALUE>', 'another utf-8 scalar'],
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
		
		# wird data
		['|<"><">&|','<VALUE>|&lt;"&gt;&lt;"&gt;&amp;|</VALUE>','xml chars'],
		
		# binary
		[
			chr(0).chr(1).chr(2).chr(3).chr(253).chr(254).chr(255),
			'<VALUE type="base64">AAECA/3+/w==</VALUE>',
			'binary'
		],
		
	);
	
	# scalar reference
	my $scalar_ref  = \"hi there!";
	my $scalar_ref2 = \("hi there!".chr(255));
	push @test_conversions, [
		$scalar_ref,
		'<VALUE subtype="ref">hi there!</VALUE>',
		'simple scalar reference'
	], [
		$scalar_ref2,
		'<VALUE type="base64" subtype="ref">aGkgdGhlcmUh/w==</VALUE>',
		'simple scalar reference to binary'
	];
	
	
	# double reference
	my $hash_ref = { 'hey' => 'there' };
	push @test_conversions, [
		[ $hash_ref, $hash_ref ],
		'<ARRAY>'."\n".
		'	<HASH>'."\n".
		'		<KEY name="hey">'."\n".
		'			<VALUE>there</VALUE>'."\n".
		'		</KEY>'."\n".
		'	</HASH>'."\n".
		'	<HASH href="*[1]"/>'."\n".
		'</ARRAY>',
		'2x same hash references'
	], [
		[ 1, 2, $scalar_ref, 4, $scalar_ref ],
		'<ARRAY>'."\n".
		'	<VALUE>1</VALUE>'."\n".
		'	<VALUE>2</VALUE>'."\n".
		'	<VALUE subtype="ref">hi there!</VALUE>'."\n".
		'	<VALUE>4</VALUE>'."\n".
		'	<VALUE href="*[3]"/>'."\n".
		'</ARRAY>',
		'2x same scalar references'
	];
	push @test_conversions, [
		[ $hash_ref, [ $hash_ref ] ],
		'<ARRAY>'."\n".
		'	<HASH>'."\n".
		'		<KEY name="hey">'."\n".
		'			<VALUE>there</VALUE>'."\n".
		'		</KEY>'."\n".
		'	</HASH>'."\n".
		'	<ARRAY>'."\n".
		'		<HASH href="../*[1]"/>'."\n".
		'	</ARRAY>'."\n".
		'</ARRAY>',
		'2x same hash references, once in []'
	];

	my $array_ref = [ 1 ];
	push @test_conversions, [
		[ $array_ref, [ $array_ref ] ],
		'<ARRAY>'."\n".
		'	<ARRAY>'."\n".
		'		<VALUE>1</VALUE>'."\n".
		'	</ARRAY>'."\n".
		'	<ARRAY>'."\n".
		'		<ARRAY href="../*[1]"/>'."\n".
		'	</ARRAY>'."\n".
		'</ARRAY>',
		'double array reference'
	];

	# circular reference
	my $array_ref2 = [];
	push @$array_ref2, $array_ref2;
	push @test_conversions, [
		$array_ref2,
		'<ARRAY>'."\n".
		'	<ARRAY href="../*[1]"/>'."\n".
		'</ARRAY>',
		'array with array ref to self',
	];
	
	my (%hash_one, %hash_two);
	$hash_one{'other'} = \%hash_two;
	$hash_two{'other'} = \%hash_one;
	push @test_conversions, [
		[ \%hash_one, \%hash_two ],
		'<ARRAY>'."\n".
		'	<HASH>'."\n".
		'		<KEY name="other">'."\n".
		'			<HASH>'."\n".
		'				<KEY name="other">'."\n".
		'					<HASH href="../../../../*[1]"/>'."\n".
		'				</KEY>'."\n".
		'			</HASH>'."\n".
		'		</KEY>'."\n".
		'	</HASH>'."\n".
		'	<HASH href="*[1]/*[1]/*[1]"/>'."\n".
		'</ARRAY>',
		'two hashes refering to self',
	];
	

	my (%hash1, %hash2, %hash3, $scalar_ref3);
	$hash1{'info'} = '/me hash1';
	$hash1{'next'} = \%hash2;
	$hash1{'prev'} = \%hash3;
	$hash1{'more'} = \$scalar_ref3;
	$hash2{'info'} = '/me hash2';
	$hash2{'next'} = \%hash3;
	$hash2{'prev'} = \%hash1;
	$hash2{'more'} = \$scalar_ref3;
	$hash3{'info'} = '/me hash3';
	$hash3{'next'} = \%hash1;
	$hash3{'prev'} = \%hash2;
	$hash3{'more'} = \$scalar_ref3;
	push @test_conversions, [
		[ \%hash1, \%hash2, \%hash3 ],
		'<ARRAY>'."\n".
		'	<HASH>'."\n".
		'		<KEY name="info">'."\n".
		'			<VALUE>/me hash1</VALUE>'."\n".
		'		</KEY>'."\n".
		'		<KEY name="next">'."\n".
		'			<HASH>'."\n".
		'				<KEY name="info">'."\n".
		'					<VALUE>/me hash2</VALUE>'."\n".
		'				</KEY>'."\n".
		'				<KEY name="next">'."\n".
		'					<HASH>'."\n".
		'						<KEY name="info">'."\n".
		'							<VALUE>/me hash3</VALUE>'."\n".
		'						</KEY>'."\n".
		'						<KEY name="next">'."\n".
		'							<HASH href="../../../../../../*[1]"/>'."\n".
		'						</KEY>'."\n".
		'						<KEY name="prev">'."\n".
		'							<HASH href="../../../../*[1]"/>'."\n".
		'						</KEY>'."\n".
		'						<KEY name="more">'."\n".
		'							<VALUE type="undef" subtype="ref"/>'."\n".
		'						</KEY>'."\n".
		'					</HASH>'."\n".
		'				</KEY>'."\n".
		'				<KEY name="prev">'."\n".
		'					<HASH href="../../../../*[1]"/>'."\n".
		'				</KEY>'."\n".
		'				<KEY name="more">'."\n".
		'					<VALUE href="../*[2]/*[1]/*[4]/*[1]"/>'."\n".
		'				</KEY>'."\n".
		'			</HASH>'."\n".
		'		</KEY>'."\n".
		'		<KEY name="prev">'."\n".
		'			<HASH href="../*[2]/*[1]/*[2]/*[1]"/>'."\n".
		'		</KEY>'."\n".
		'		<KEY name="more">'."\n".
		'			<VALUE href="../*[2]/*[1]/*[2]/*[1]/*[4]/*[1]"/>'."\n".
		'		</KEY>'."\n".
		'	</HASH>'."\n".
		'	<HASH href="*[1]/*[2]/*[1]"/>'."\n".
		'	<HASH href="*[1]/*[2]/*[1]/*[2]/*[1]"/>'."\n".
		'</ARRAY>',
		'three hashes referencing to each other'
	];

	my $dxml  = Data::asXML->new();
	my $dxml2 = Data::asXML->new();
	foreach my $test (@test_conversions) {
		my $dom   = $dxml->encode($test->[0]);
		my $data  = $dxml2->decode($test->[1]);

		# encode
		eq_or_diff(
			$dom->toString,
			$test->[1],
			'encode() - '.$test->[2],
		);

		# decode
		is_deeply(
			$data,
			$test->[0],
			'decode() - '.$test->[2],
		);
	}
	
	SAFE_MODE: {
		my $dxml = Data::asXML->new(safe_mode => 1);
		lives_ok
			{ $dxml->encode({ 'hi' => 'there' }) }
			'encode with safe_mode on'
		;
		lives_ok
			{ $dxml->decode('<HASH><KEY name="hi"><VALUE>there</VALUE></KEY></HASH>') }
			'decode with safe_mode on'
		;
	}
	
	NAME_SPACE {
		my $dxml = Data::asXML->new(namespace => 1, pretty => 0);
		eq_or_diff(
			$dxml->encode({ 'hi' => 'there' })->toString,
			'<HASH xmlns="http://search.cpan.org/perldoc?Data::asXML"><KEY name="hi"><VALUE>there</VALUE></KEY></HASH>',
			'encode with namespace "1"',
		);

		my $dxml2 = Data::asXML->new(namespace => 'wellns', pretty => 0);
		eq_or_diff(
			$dxml2->encode({ 'hi' => 'there' })->toString,
			'<HASH xmlns="wellns"><KEY name="hi"><VALUE>there</VALUE></KEY></HASH>',
			'encode with namespace "1"',
		);
	}
	
	return 0;
}

sub test_make_relative_xpath {
	my $dxml  = Data::asXML->new();
	is(
		$dxml->_make_relative_xpath(
			[1,1],
			[1,2],
		),
		'*[1]',
		'relative xpath at the same level'
	);
	is(
		$dxml->_make_relative_xpath(
			[1,1,1],
			[1,2],
		),
		'*[1]/*[1]',
		'relative xpath at the same level + 1'
	);
	is(
		$dxml->_make_relative_xpath(
			[1,1,1],
			[1,2,1],
		),
		'../*[1]/*[1]',
		'relative xpath with ..'
	);
	is(
		$dxml->_make_relative_xpath(
			[1,2,3,4,5],
			[1,2,6,7],
		),
		'../*[3]/*[4]/*[5]',
		'relative xpath with ..'
	);
	is(
		$dxml->_make_relative_xpath(
			[1,1,3,4,5],
			[1,2,6,7],
		),
		'../../*[1]/*[3]/*[4]/*[5]',
		'relative xpath with ../..'
	);
	is(
		$dxml->_make_relative_xpath(
			[1,1],
			[1,1,3,4],
		),
		'../../*[1]',
		'self referencing'
	);
}

sub test_href_key {
	my $dxml  = Data::asXML->new();
	$dxml->{'_cur_xpath_steps'} = [ 1,2 ];

	is(
		$dxml->_href_key('*[1]'),
		'1,2,1',
		'href_key mapping, same level'
	);	
	is(
		$dxml->_href_key('*[1]/*[1]/*[2]'),
		'1,2,1,1,2',
		'href_key mapping, same level'
	);	
	is(
		$dxml->_href_key('../*[1]'),
		'1,1',
		'href_key mapping, level up'
	);	
}

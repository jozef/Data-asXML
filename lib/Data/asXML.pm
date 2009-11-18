package Data::asXML;

=head1 NAME

Data::asXML - convert data structures to/from XML

=head1 SYNOPSIS

    use Data::asXML;
    my $dxml = Data::asXML->new();
    my $dom = $dxml->encode({
        'some' => 'value',
        'in'   => [ qw(a data structure) ],
    });

    my $data = $dxml->decode(q{
        <HASH>
            <KEY name="some"><VALUE>value</VALUE></KEY>
            <KEY name="in">
                <ARRAY>
                    <VALUE>a</VALUE>
                    <VALUE>data</VALUE>
                    <VALUE>structure</VALUE>
                </ARRAY>
            </KEY>
        </HASH>
    });

For more examples see F<t/01_Data-asXML.t>.

=head1 WARNING

experimental, use on your own risk :-)

=head1 DESCRIPTION

There are couple of modules mapping XML to data structures. (L<XML::Compile>,
L<XML::TreePP>, L<XML::Simple>, ...) but they aim at making data structures
adapt to XML structure. This defines simple XML tags to represent data structures.
It makes the serialization to (later also from) XML possible.
For the moment it is an experiment. I plan to use it for passing data
structures to XSLT for transformations.

=cut

use warnings;
use strict;

use utf8;
use 5.010;
use feature 'state';

use Carp 'croak';
use XML::LibXML 'XML_ELEMENT_NODE';
use Scalar::Util 'blessed';
use MIME::Base64 'encode_base64', 'decode_base64';
use Encode 'is_utf8';

our $VERSION = '0.04';

use base 'Class::Accessor::Fast';

=head1 PROPERTIES

=over 4

=item pretty

(default 1) will insert text nodes to the XML to make the output indented.

=back

=cut

__PACKAGE__->mk_accessors(qw{
    pretty
});

=head1 METHODS

=head2 new()

Object constructor.

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new({
        'pretty' => 1,
        @_
    });
    
    return $self;
}

sub _xml {
    my($self) = @_;
    if(not exists $self->{'_xml'}) {
        my $xml = XML::LibXML::Document->new("1.0", "UTF-8");
        $self->{'_xml'} = $xml;
    }
    return $self->{'_xml'};
}


sub _indent {
    my $self   = shift;
    my $where  = shift;
    my $indent = shift;
    
    $where->addChild( $self->_xml->createTextNode( "\n".("\t" x $indent) ) )
        if $self->pretty;
}


=head2 encode($what)

From structure C<$what> generates L<XML::LibXML::Document> DOM. Call
C<< ->toString >> to get XML string. For more actions see L<XML::LibXML>.

=cut

sub encode {
    my $self  = shift;
    my $what  = shift;
    my $pos   = shift || 1;
    my $where;
    
    state $indent = 0;
    
    if (not $self->{'_cur_xpath_steps'}) {
        $self->{'_href_mapping'}    = {};
        $self->{'_cur_xpath_steps'} = [];
    }
    
    given (ref $what) {
        # create DOM for hash element
        when ('HASH') {
            $where = $self->_xml->createElement('HASH');
            $indent++;
            push @{$self->{'_cur_xpath_steps'}}, $pos;
            # already encoded reference
            if (exists $self->{'_href_mapping'}->{$what}) {
                $where->setAttribute(
                    'href' =>
                    $self->_make_relative_xpath(
                        [ split(',', $self->{'_href_mapping'}->{$what}) ],
                        $self->{'_cur_xpath_steps'}
                    )
                );
                $indent--;
                pop @{$self->{'_cur_xpath_steps'}};
                return $where;
            }
            $self->{'_href_mapping'}->{$what} = $self->_xpath_steps_string();
            
            my $key_pos = 0;
            while (my ($key, $value) = each %{$what}) {
                $key_pos++;
                $self->_indent($where, $indent);
                $indent++;

                my $el = $self->_xml->createElement('KEY');
                push @{$self->{'_cur_xpath_steps'}}, $key_pos;
                $self->_indent($el, $indent);
                $el->setAttribute('name', $key);
                $el->addChild($self->encode($value));

                $indent--;
                $self->_indent($el, $indent);
                pop @{$self->{'_cur_xpath_steps'}};

                $where->addChild($el);
            }
            
            $indent--;
            $self->_indent($where, $indent);
            pop @{$self->{'_cur_xpath_steps'}};
        }
        # create DOM for array element
        when ('ARRAY') {
            $where = $self->_xml->createElement('ARRAY');
            $indent++;
            push @{$self->{'_cur_xpath_steps'}}, $pos;
            # already encoded reference
            if (exists $self->{'_href_mapping'}->{$what}) {
                $where->setAttribute(
                    'href' =>
                    $self->_make_relative_xpath(
                        [ split(',', $self->{'_href_mapping'}->{$what}) ],
                        $self->{'_cur_xpath_steps'}
                    )
                );
                $indent--;
                pop @{$self->{'_cur_xpath_steps'}};
                return $where;
            }
            $self->{'_href_mapping'}->{$what.''} = $self->_xpath_steps_string();
            
            my $array_pos = 0;
            foreach my $value (@{$what}) {
                $array_pos++;
                $self->_indent($where, $indent);
                $where->addChild($self->encode($value, $array_pos));
            }
            
            $indent--;
            $self->_indent($where, $indent);
            pop @{$self->{'_cur_xpath_steps'}};
        }
        # scalar reference
        when ('SCALAR') {
            push @{$self->{'_cur_xpath_steps'}}, $pos;
            # already encoded reference
            if (exists $self->{'_href_mapping'}->{$what}) {
                $where = $self->_xml->createElement('VALUE');
                $where->setAttribute(
                    'href' =>
                    $self->_make_relative_xpath(
                        [ split(',', $self->{'_href_mapping'}->{$what}) ],
                        $self->{'_cur_xpath_steps'}
                    )
                );
                pop @{$self->{'_cur_xpath_steps'}};
                return $where;
            }
            $self->{'_href_mapping'}->{$what.''} = $self->_xpath_steps_string();

            $where = $self->encode($$what);
            $where->setAttribute('subtype' => 'ref');

            pop @{$self->{'_cur_xpath_steps'}};
        }
        # create text node
        default {
            $where = $self->_xml->createElement('VALUE');
            if (defined $what) {
                if ((not is_utf8($what, 1)) and ($what !~ m/^[[:ascii:]]*$/xms)) {
                    $what = encode_base64($what);
                    $what =~ s/\s*$//;
                    $where->setAttribute('type' => 'base64');
                }
                $where->addChild( $self->_xml->createTextNode( $what ) )
            }
            else {
                # no better way to distinguish between empty string and undef - see http://rt.cpan.org/Public/Bug/Display.html?id=51442
                $where->setAttribute('type' => 'undef');
            }
                
        }
    }

    # cleanup at the end
    if ($indent == 0) {
        $self->{'_href_mapping'}    = {};
        $self->{'_cur_xpath_steps'} = [];
    }
    
    return $where;
}

sub _xpath_steps_string {
    my $self       = shift;
    my $path_array = shift || $self->{'_cur_xpath_steps'};
    return join(',',@{$path_array});
}

sub _make_relative_xpath {
    my $self      = shift;
    my $orig_path = shift;
    my $cur_path  = shift;
    
    # find how many elements (from beginning) the paths are sharing
    my $common_root_index = 0;
    while (
            ($common_root_index < @$orig_path)
            and ($orig_path->[$common_root_index] == $cur_path->[$common_root_index])
    ) {
        $common_root_index++;
    }
    
    # add '..' to move up the element hierarchy until the common element
    my @rel_path = ();
    my $i = $common_root_index+1;
    while ($i < scalar @$cur_path) {
        push @rel_path, '..';
        $i++;
    }
    
    # add the original element path steps
    $i = $common_root_index;
    while ($i < scalar @$orig_path) {
        push @rel_path, $orig_path->[$i];
        $i++;
    }
    
    # in case of self referencing the element index is needed
    if ($i == $common_root_index) {
        push @rel_path, '..', $orig_path->[-1];
    }
    
    # return relative xpath
    return join('/', map { $_ eq '..' ? $_ : '*['.$_.']' } @rel_path);
}

=head2 decode($xmlstring)

Takes C<$xmlstring> and converts to data structure.

=cut

sub decode {
    my $self = shift;
    my $xml  = shift;
    my $pos   = shift || 1;

    if (not $self->{'_cur_xpath_steps'}) {
        local $self->{'_href_mapping'}    = {};
        local $self->{'_cur_xpath_steps'} = [];
    }

    my $value;
    
    if (not blessed $xml) {
        my $parser       = XML::LibXML->new();
        my $doc          = $parser->parse_string($xml);
        my $root_element = $doc->documentElement();
        
        return $self->decode($root_element);
    }
    
    given ($xml->nodeName) {
        when ('HASH') {
            if (my $xpath_path = $xml->getAttribute('href')) {
                my $href_key = $self->_href_key($xpath_path);                
                return $self->{'_href_mapping'}->{$href_key} || die 'invalid reference - '.$href_key.' ('.$xml->toString.')';
            }
            
            push @{$self->{'_cur_xpath_steps'}}, $pos;
            
            my %data;
            $self->{'_href_mapping'}->{$self->_xpath_steps_string()} = \%data;
            my @keys =
                grep { $_->nodeName eq 'KEY' }
                grep { $_->nodeType eq XML_ELEMENT_NODE }
                $xml->childNodes()
            ;
            my $key_pos = 1;
            foreach my $key (@keys) {
                push @{$self->{'_cur_xpath_steps'}}, $key_pos;
                my $key_name  = $key->getAttribute('name');
                my $key_value = $self->decode(grep { $_->nodeType eq XML_ELEMENT_NODE } $key->childNodes());     # is always only one
                $data{$key_name} = $key_value;
                pop @{$self->{'_cur_xpath_steps'}};
                $key_pos++;
            }
            pop @{$self->{'_cur_xpath_steps'}};
            return \%data;
        }
        when ('ARRAY') {
            if (my $xpath_path = $xml->getAttribute('href')) {
                my $href_key = $self->_href_key($xpath_path);
                
                return $self->{'_href_mapping'}->{$href_key} || die 'invalid reference - '.$href_key.' ('.$xml->toString.')';
            }

            push @{$self->{'_cur_xpath_steps'}}, $pos;

            my @data;
            $self->{'_href_mapping'}->{$self->_xpath_steps_string()} = \@data;
            
            my $array_element_pos = 1;
            @data = map { $self->decode($_, $array_element_pos++) } grep { $_->nodeType eq XML_ELEMENT_NODE } $xml->childNodes();
            pop @{$self->{'_cur_xpath_steps'}};
            return \@data;
        }
        when ('VALUE') {
            if (my $xpath_path = $xml->getAttribute('href')) {
                my $href_key = $self->_href_key($xpath_path);                
                return $self->{'_href_mapping'}->{$href_key} || die 'invalid reference - '.$href_key.' ('.$xml->toString.')';
            }

            push @{$self->{'_cur_xpath_steps'}}, $pos;
            my $value;
            $self->{'_href_mapping'}->{$self->_xpath_steps_string()} = \$value;
            pop @{$self->{'_cur_xpath_steps'}};
            
            given ($xml->getAttribute('type')) {
                when ('undef')  { $value = undef; }
                when ('base64') { $value = decode_base64($xml->textContent) }
                default         { $value = $xml->textContent }
            }
            return \$value
                if ($xml->getAttribute('subtype') ~~ 'ref');
            return $value;
        }
        default {
            die 'invalid (unknown) element "'.$xml->toString.'"'
        }
    }
    
}

sub _href_key {
    my $self               = shift;
    my $xpath_steps_string = shift;
    
    my @path        = @{$self->{'_cur_xpath_steps'}};
    my @xpath_steps =
        map { $_ =~ m/^\*\[(\d+)\]$/xms ? $1 : $_ }
        split('/', $xpath_steps_string)
    ;
    
    my $i = 0;
    while ($i < @xpath_steps) {
        given ($xpath_steps[$i]) {
            when ('..') { pop @path }
            default     { push @path, $_ }
        }
        $i++;
    }
    return $self->_xpath_steps_string(\@path)
}

1;


__END__

=head1 AUTHOR

Jozef Kutej, C<< <jkutej at cpan.org> >>

=head1 CONTRIBUTORS
 
The following people have contributed to the Sys::Path by commiting their
code, sending patches, reporting bugs, asking questions, suggesting useful
advices, nitpicking, chatting on IRC or commenting on my blog (in no particular
order):

    Lars Dɪᴇᴄᴋᴏᴡ 迪拉斯
    Emmanuel Rodriguez

=head1 TODO

    * safe_mode() to add extra decode after encoding and compare the results if they match
    * int, float encoding ? (string enough?)
    * allow setting namespace
    * XSD
    * anyone else has an idea?

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-asxml at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-asXML>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::asXML


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-asXML>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-asXML>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-asXML>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-asXML/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Jozef Kutej.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Data::asXML

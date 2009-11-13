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
    my $where;
    
    state $indent = 0;
    
    given (ref $what) {
        # create DOM for hash element
        when ('HASH') {
            $where = $self->_xml->createElement('HASH');
            $indent++;
            
            while (my ($key, $value) = each %{$what}) {
                $self->_indent($where, $indent);
                $indent++;

                my $el = $self->_xml->createElement('KEY');
                $self->_indent($el, $indent);
                $el->setAttribute('name', $key);
                $el->addChild($self->encode($value));

                $indent--;
                $self->_indent($el, $indent);

                $where->addChild($el);
            }
            
            $indent--;
            $self->_indent($where, $indent);
        }
        # create DOM for array element
        when ('ARRAY') {
            $where = $self->_xml->createElement('ARRAY');
            $indent++;
            
            foreach my $value (@{$what}) {
                $self->_indent($where, $indent);
                $where->addChild($self->encode($value));
            }
            
            $indent--;
            $self->_indent($where, $indent);
        }
        # create text node
        default {
            $where = $self->_xml->createElement('VALUE');
            if (defined $what) {
                $where->addChild( $self->_xml->createTextNode( $what ) )
            }
            else {
                # no better way to distinguish between empty string and undef - see http://rt.cpan.org/Public/Bug/Display.html?id=51442
                $where->setAttribute('type' => 'undef');
            }
                
        }
    }
    

    return $where;
}


=head2 decode($xmlstring)

Takes C<$xmlstring> and converts to data structure.

=cut

sub decode {
    my $self = shift;
    my $xml  = shift;

    my $value;
    
    if (not blessed $xml) {
        my $parser       = XML::LibXML->new();
        my $doc          = $parser->parse_string($xml);
        my $root_element = $doc->documentElement();
        
        return $self->decode($root_element);
    }
    
    given ($xml->nodeName) {
        when ('HASH') {
            my %data;
            my @keys =
                grep { $_->nodeName eq 'KEY' }
                grep { $_->nodeType eq XML_ELEMENT_NODE }
                $xml->childNodes()
            ;
            foreach my $key (@keys) {
                my $key_name  = $key->getAttribute('name');
                my $key_value = $self->decode(grep { $_->nodeType eq XML_ELEMENT_NODE } $key->childNodes());     # is always only one
                $data{$key_name} = $key_value;
            }
            return \%data;
        }
        when ('ARRAY') {
            return [ map { $self->decode($_) } grep { $_->nodeType eq XML_ELEMENT_NODE } $xml->childNodes() ];
        }
        when ('VALUE') {
            given ($xml->getAttribute('type')) {
                when ('undef') { return undef; }
            }
            return $xml->textContent;
        }
        default {
            die 'invalid (unknown) element "'.$xml->toString.'"'
        }
    }
    
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

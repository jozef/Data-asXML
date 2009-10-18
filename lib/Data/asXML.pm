package Data::asXML;

=head1 NAME

Data::asXML - convert data structures to/from XML

=head1 SYNOPSIS

    my $dxml = Data::asXML->new();
    my $dom = $dxml->encode({
        'some' => 'value',
        'in'   => [ qw(a data structure) ],
    });

    # not implemented jet
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

use 5.010;
use feature 'state';

use Carp 'croak';
use XML::LibXML;

our $VERSION = '0.01';

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
    
    croak 'pass something to encode'
        if not $what;
    
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
            $where->addChild( $self->_xml->createTextNode( $what ) );
        }
    }
    

    return $where;
}


=head2 decode

Not implemented jet.

=cut

sub decode {
    my $self = shift;
    
    die 'not implemented jet.'
}

1;


__END__

=head1 AUTHOR

Jozef Kutej, C<< <jkutej at cpan.org> >>

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

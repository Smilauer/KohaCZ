package C4::ItemType;

# Copyright Liblime 2009
# Parts Copyright Tamil 2011
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use strict;
use warnings;
use C4::Context;
use C4::Languages;
use Encode qw( encode );

our $AUTOLOAD;




=head1 NAME

C4::ItemType - objects from the itemtypes table

=head1 SYNOPSIS

    use C4::ItemType;
    my @itemtypes = C4::ItemType->all;
    print join("\n", map { $_->description } @itemtypes), "\n";

=head1 DESCRIPTION

Objects of this class represent a row in the C<itemtypes> table.

Currently, the bare minimum for using this as a read-only data source has
been implemented.  The API was designed to make it easy to transition to
an ORM later on.

=head1 API

=head2 Class Methods

=cut

=head3 C4::ItemType->new(\%opts)

Given a hashref, a new (in-memory) C4::ItemType object will be instantiated.
The database is not touched.

=cut

sub new {
    my ($class, $opts) = @_;
    bless $opts => $class;
}




=head3 C4::ItemType->all

This returns all the itemtypes as objects.  By default they're ordered by
C<description>.

=cut

sub all {
    my ($class) = @_;
    my $dbh = C4::Context->dbh;

    my $language = C4::Languages::getlanguage();
    my @itypes;
    for ( @{$dbh->selectall_arrayref(q|
        SELECT *,
            COALESCE( localization.translation, itemtypes.description ) AS translated_description
        FROM itemtypes
        LEFT JOIN localization ON itemtypes.itemtype = localization.code
            AND localization.entity = 'itemtypes'
            AND localization.lang = ?
        ORDER BY description
    |, { Slice => {} }, $language)} )
    {
        push @itypes, $class->new($_);
    }
    return @itypes;
}




=head3 C4::ItemType->get

Return the itemtype indicated by the itemtype given as argument, as
an object.

=cut

sub get {
    my ($class, $itemtype) = @_;

    return unless defined $itemtype;

    my $dbh = C4::Context->dbh;

    my $data = $dbh->selectrow_hashref(
        "SELECT * FROM itemtypes WHERE itemtype = ?", undef, $itemtype
    );
    return unless defined $data;
    return $class->new($data);
}




=head2 Object Methods

These are read-only accessors for attributes of a C4::ItemType object.

=head3 $itemtype->itemtype

=cut

=head3 $itemtype->description

=cut

=head3 $itemtype->renewalsallowed

=cut

=head3 $itemtype->rentalcharge

=cut

=head3 $itemtype->notforloan

=cut

=head3 $itemtype->imageurl

=cut

=head3 $itemtype->checkinmsg

=cut

=head3 $itemtype->summary

=cut

sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*://;
    if (exists $self->{$attr}) {
        return $self->{$attr};
    } else {
        return undef;
    }
}

sub DESTROY { }



# ack itemtypes | grep '\.pm' | awk '{ print $1 }' | sed 's/:.*$//' | sort | uniq | sed -e 's,/,::,g' -e 's/\.pm//' -e 's/^/L<C4::/' -e 's/$/>,/'

=head1 SEE ALSO

The following modules make reference to the C<itemtypes> table.

L<C4::Biblio>,
L<C4::Circulation>,
L<C4::Context>,
L<C4::Items>,
L<C4::Koha>,
L<C4::Labels>,
L<C4::Overdues>,
L<C4::Reserves>,
L<C4::Search>,
L<C4::XSLT>



=head1 AUTHOR

John Beppu <john.beppu@liblime.com>

=cut

1;

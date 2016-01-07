#!/usr/bin/perl

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

use Modern::Perl;

use C4::Context;
use C4::Biblio qw( AddBiblio );
use Koha::Database;
use Koha::Borrowers;
use Koha::Branches;
use Koha::Item;

use Test::More tests => 23;

use_ok('Koha::Hold');

my $schema = Koha::Database->new()->schema();
$schema->storage->txn_begin();

my $dbh = C4::Context->dbh;
$dbh->{RaiseError} = 1;

my @branches = Koha::Branches->search();
my $borrower = Koha::Borrowers->search()->next();

my $biblio = MARC::Record->new();
my $title  = 'Silence in the library';
$biblio->append_fields(
    MARC::Field->new( '100', ' ', ' ', a => 'Moffat, Steven' ),
    MARC::Field->new( '245', ' ', ' ', a => $title ),
);
my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $biblio, '' );

my $item = Koha::Item->new(
    {
        biblionumber     => $biblionumber,
        biblioitemnumber => $biblioitemnumber,
        holdingbranch    => $branches[0]->branchcode(),
        homebranch       => $branches[0]->branchcode(),
    }
);
$item->store();

my $hold = Koha::Hold->new(
    {
        biblionumber     => $biblionumber,
        itemnumber => $item->id(),
        found          => 'W',
        waitingdate    => '2000-01-01',
        borrowernumber => $borrower->borrowernumber(),
        branchcode     => $branches[1]->branchcode(),
    }
);
$hold->store();

$item = $hold->item();

my $hold_borrower = $hold->borrower();
ok( $hold_borrower, 'Got hold borrower' );
is( $hold_borrower->borrowernumber(), $borrower->borrowernumber(), 'Hold borrower matches correct borrower' );

C4::Context->set_preference( 'ReservesMaxPickUpDelay', '' );
my $dt = $hold->waiting_expires_on();
is( $dt, undef, "Koha::Hold->waiting_expires_on returns undef if ReservesMaxPickUpDelay is not set" );

is( $hold->is_waiting, 1, 'The hold is waiting' );
is( $hold->is_found, 1, 'The hold is found');
ok( !$hold->is_in_transit, 'The hold is not in transit' );

C4::Context->set_preference( 'ReservesMaxPickUpDelay', '5' );
$dt = $hold->waiting_expires_on();
is( $dt->ymd, "2000-01-06",
    "Koha::Hold->waiting_expires_on returns DateTime of waitingdate + ReservesMaxPickUpDelay if set" );

$hold->found('T');
$dt = $hold->waiting_expires_on();
is( $dt, undef, "Koha::Hold->waiting_expires_on returns undef if found is not 'W' ( Set to 'T' )" );
isnt( $hold->is_waiting, 1, 'The hold is not waiting (T)' );
is( $hold->is_found, 1, 'The hold is found');
is( $hold->is_in_transit, 1, 'The hold is in transit' );

$hold->found(q{});
$dt = $hold->waiting_expires_on();
is( $dt, undef, "Koha::Hold->waiting_expires_on returns undef if found is not 'W' ( Set to empty string )" );
isnt( $hold->is_waiting, 1, 'The hold is not waiting (W)' );
is( $hold->is_found, 0, 'The hold is not found' );
ok( !$hold->is_in_transit, 'The hold is not in transit' );

# Test method is_cancelable
$hold->found(undef);
ok( $hold->is_cancelable(), "Unfound hold is cancelable" );
$hold->found('W');
ok( $hold->is_cancelable, "Waiting hold is cancelable" );
$hold->found('T');
ok( !$hold->is_cancelable, "In transit hold is not cancelable" );

# Test method is_at_destination
$hold->found(undef);
ok( !$hold->is_at_destination(), "Unfound hold cannot be at destination" );
$hold->found('T');
ok( !$hold->is_at_destination(), "In transit hold cannot be at destination" );
$hold->found('W');
ok( !$hold->is_at_destination(), "Waiting hold where hold branchcode is not the same as the item's holdingbranch is not at destination" );
$item->holdingbranch( $branches[1]->branchcode() );
ok( $hold->is_at_destination(), "Waiting hold where hold branchcode is the same as the item's holdingbranch is at destination" );

$schema->storage->txn_rollback();

1;

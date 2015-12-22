#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2015 Biblibre
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

use Test::More tests => 5;
use Test::MockModule;
use t::lib::TestBuilder;
use t::lib::Mocks qw( mock_preference );

use C4::Members;
use Koha::Database;

BEGIN {
    use_ok('C4::Members');
}

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $date_time = new Test::MockModule('DateTime');
$date_time->mock(
    'now', sub {
        return DateTime->new(
            year      => 2015,
            month     => 6,
            day       => 15,
        );

});

t::lib::Mocks::mock_preference('MembershipExpiryDaysNotice', 15);

my $builder = t::lib::TestBuilder->new();
$builder->build({
    source => 'Category',
    value  => {
        categorycode            => 'AD',
        description             => 'Adult',
        enrolmentperiod         => 18,
        upperagelimit           => 99,
        category_type           => 'A',
    },
});

$builder->build({
    source => 'Branch',
    value  => {
        branchcode              => 'CR',
        branchname              => 'My branch',
    },
});

$builder->build({
    source => 'Borrower',
    value  => {
        firstname               => 'Vincent',
        surname                 => 'Martin',
        cardnumber              => '80808081',
        categorycode            => 'AD',
        branchcode              => 'CR',
        dateexpiry              => '2015-06-30'
    },
});

$builder->build({
    source => 'Borrower',
    value  => {
        firstname               => 'Claude',
        surname                 => 'Dupont',
        cardnumber              => '80808082',
        categorycode            => 'AD',
        branchcode              => 'CR',
        dateexpiry              => '2015-06-29'
    },
});

$builder->build({
    source => 'Borrower',
    value  => {
        firstname               => 'Gilles',
        surname                 => 'Dupond',
        cardnumber              => '80808083',
        categorycode            => 'AD',
        branchcode              => 'CR',
        dateexpiry              => '2015-07-02'
    },
});

my $upcoming_mem_expires = C4::Members::GetUpcomingMembershipExpires();
is(scalar(@$upcoming_mem_expires), 1, 'Get upcoming membership expires should return 1 borrower.');

is($upcoming_mem_expires->[0]{surname}, 'Martin', 'Get upcoming membership expires should return borrower "Martin".');

# Test GetUpcomingMembershipExpires() with MembershipExpiryDaysNotice == 0
t::lib::Mocks::mock_preference('MembershipExpiryDaysNotice', 0);

$upcoming_mem_expires = C4::Members::GetUpcomingMembershipExpires();
is(scalar(@$upcoming_mem_expires), 0, 'Get upcoming membership expires with 0 MembershipExpiryDaysNotice should return 0.');

# Test GetUpcomingMembershipExpires() with MembershipExpiryDaysNotice == undef
t::lib::Mocks::mock_preference('MembershipExpiryDaysNotice', undef);

$upcoming_mem_expires = C4::Members::GetUpcomingMembershipExpires();
is(scalar(@$upcoming_mem_expires), 0, 'Get upcoming membership expires without MembershipExpiryDaysNotice should return 0.');

$schema->storage->txn_rollback;

1;

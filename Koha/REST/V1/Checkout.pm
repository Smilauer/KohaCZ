package Koha::REST::V1::Checkout;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;

use C4::Auth qw( haspermission );
use C4::Context;
use C4::Circulation;
use Koha::Issues;
use Koha::OldIssues;

sub list {
    my ($c, $args, $cb) = @_;

    my $borrowernumber = $c->param('borrowernumber');
    my $checkouts = C4::Circulation::GetIssues({
        borrowernumber => $borrowernumber
    });

    $c->$cb($checkouts, 200);
}

sub get {
    my ($c, $args, $cb) = @_;

    my $checkout_id = $args->{checkout_id};
    my $checkout = Koha::Issues->find($checkout_id);

    if (!$checkout) {
        return $c->$cb({
            error => "Checkout doesn't exist"
        }, 404);
    }

    return $c->$cb($checkout->unblessed, 200);
}

sub renew {
    my ($c, $args, $cb) = @_;

    my $checkout_id = $args->{checkout_id};
    my $checkout = Koha::Issues->find($checkout_id);

    if (!$checkout) {
        return $c->$cb({
            error => "Checkout doesn't exist"
        }, 404);
    }

    my $borrowernumber = $checkout->borrowernumber;
    my $itemnumber = $checkout->itemnumber;

    # Disallow renewal if OpacRenewalAllowed is off and user has insufficient rights
    unless (C4::Context->preference('OpacRenewalAllowed')) {
        my $user = $c->stash('koha.user');
        unless ($user && haspermission($user->userid, { circulate => "circulate_remaining_permissions" })) {
            return $c->$cb({error => "Opac Renewal not allowed"}, 403);
        }
    }

    my ($can_renew, $error) = C4::Circulation::CanBookBeRenewed(
        $borrowernumber, $itemnumber);

    if (!$can_renew) {
        return $c->$cb({error => "Renewal not authorized ($error)"}, 403);
    }

    AddRenewal($borrowernumber, $itemnumber, $checkout->branchcode);
    $checkout = Koha::Issues->find($checkout_id);

    return $c->$cb($checkout->unblessed, 200);
}

sub renewability {
    my ($c, $args, $cb) = @_;

    my $user = $c->stash('koha.user');

    my $checkout_id = $args->{checkout_id};
    my $checkout = Koha::Issues->find($checkout_id);

    if (!$checkout) {
        return $c->$cb({
            error => "Checkout doesn't exist"
        }, 404);
    }

    my $borrowernumber = $checkout->borrowernumber;
    my $itemnumber = $checkout->itemnumber;

    my $OpacRenewalAllowed;
    if ($user->borrowernumber == $borrowernumber) {
        $OpacRenewalAllowed = C4::Context->preference('OpacRenewalAllowed');
    }

    unless ($user && ($OpacRenewalAllowed
        || haspermission($user->userid, { circulate => "circulate_remaining_permissions" }))) {
            return $c->$cb({error => "You don't have the required permission"}, 403);
    }

    my ($can_renew, $error) = C4::Circulation::CanBookBeRenewed(
        $borrowernumber, $itemnumber);

    return $c->$cb({ renewable => Mojo::JSON->true, error => undef }, 200) if $can_renew;
    return $c->$cb({ renewable => Mojo::JSON->false, error => $error }, 200);
}

sub listhistory {
    my ($c, $args, $cb) = @_;

    my $borrowernumber = $c->param('borrowernumber');

    my %attributes = ( itemnumber => { "!=", undef } );
    if ($borrowernumber) {
        return $c->$cb({
            error => "Patron doesn't exist"
        }, 404) unless Koha::Patrons->find($borrowernumber);

        $attributes{borrowernumber} = $borrowernumber;
    }

    # Retrieve all the issues in the history, but only the issue_id due to possible perfomance issues
    my $checkouts = Koha::OldIssues->search(
      \%attributes,
      { columns => [qw/issue_id/]}
    );

    $c->$cb($checkouts->unblessed, 200);
}

sub gethistory {
    my ($c, $args, $cb) = @_;

    my $checkout_id = $args->{checkout_id};
    my $checkout = Koha::OldIssues->find($checkout_id);

    if (!$checkout) {
        return $c->$cb({
            error => "Checkout doesn't exist"
        }, 404);
    }

    return $c->$cb($checkout->unblessed, 200);
}

1;

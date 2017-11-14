package Koha::REST::V1::Accountline;

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

use Scalar::Util qw( looks_like_number );

use C4::Auth qw( haspermission );
use Koha::Account::Lines;
use Koha::Account;

use Try::Tiny;

sub list {
    my $c = shift->openapi->valid_input or return;

    my $params  = $c->req->params->to_hash;
    my $accountlines = Koha::Account::Lines->search($params);

    return $c->render(status => 200, openapi => $accountlines);
}


sub edit {
    my $c = shift->openapi->valid_input or return;

    my $accountlines_id = $c->validation->param('accountlines_id');

    my $accountline = Koha::Account::Lines->find($accountlines_id);
    unless ($accountline) {
        return $c->render(status => 404, openapi => {error => "Accountline not found"});
    }

    my $body = $c->req->json;

    $accountline->set( $body );
    $accountline->store();

    return $c->render(status => 200, openapi => $accountline);
}


sub pay {
    my $c = shift->openapi->valid_input or return;

    my $args = $c->req->params->to_hash // {};
    my $accountlines_id = $c->validation->param('accountlines_id');

    return try {
        my $accountline = Koha::Account::Lines->find($accountlines_id);
        unless ($accountline) {
            return $c->render(status => 404, openapi => {error => "Accountline not found"});
        }

        my $body = $c->req->json;
        my $amount = $body->{amount};
        my $note = $body->{note} || '';

        Koha::Account->new(
            {
                patron_id => $accountline->borrowernumber,
            }
          )->pay(
            {
                lines  => [$accountline],
                amount => $amount,
                note => $note,
            }
          );

        $accountline = Koha::Account::Lines->find($accountlines_id);
        return $c->render(status => 200, openapi => $accountline);
    } catch {
        if ($_->isa('DBIx::Class::Exception')) {
            return $c->render(status => 500, openapi => { error => $_->msg });
        }
        else {
            return $c->render(status => 500, openapi => {
                error => 'Something went wrong, check the logs.'
            });
        }
    };
}


1;

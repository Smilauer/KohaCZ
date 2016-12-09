package Koha::REST::V1::Patron;

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

use C4::Auth qw( haspermission checkpw_internal );

use Koha::AuthUtils qw(hash_password);
use Koha::Patrons;
use Koha::Patron::Categories;
use Koha::Libraries;

use Scalar::Util qw(blessed);
use Try::Tiny;

sub list {
    my ($c, $args, $cb) = @_;

    my $params = $c->req->query_params->to_hash;
    my $patrons;
    if (keys %$params) {
        my @valid_params = Koha::Patrons->columns;
        foreach my $key (keys %$params) {
            delete $params->{$key} unless grep { $key eq $_ } @valid_params;
        }
        $patrons = Koha::Patrons->search($params);
    } else {
        $patrons = Koha::Patrons->search;
    }

    $c->$cb($patrons->unblessed, 200);
}

sub get {
    my ($c, $args, $cb) = @_;

    my $patron = Koha::Patrons->find($args->{borrowernumber});
    unless ($patron) {
        return $c->$cb({error => "Patron not found"}, 404);
    }

    return $c->$cb($patron->unblessed, 200);
}

sub add {
    my ($c, $args, $cb) = @_;

    try {
        my $body = $c->req->json;

        if ($body->{password}) { $body->{password} = hash_password($body->{password}) }; # bcrypt password if given

        my $patron = Koha::Patron->new($body)->validate->store;
        return $c->$cb($patron->unblessed, 201);
    }
    catch {
        unless (blessed $_ && $_->can('rethrow')) {
            return $c->$cb({error => "Something went wrong, check Koha logs for details."}, 500);
        }
        if ($_->isa('Koha::Exceptions::Patron::DuplicateObject')) {
            return $c->$cb({ error => $_->error, conflict => $_->conflict }, 409);
        }
        elsif ($_->isa('Koha::Exceptions::Library::BranchcodeNotFound')) {
            return $c->$cb({ error => "Library with branchcode \"".$_->branchcode."\" does not exist" }, 404);
        }
        elsif ($_->isa('Koha::Exceptions::Category::CategorycodeNotFound')) {
            return $c->$cb({error => "Patron category \"".$_->categorycode."\" does not exist"}, 404);
        }
        else {
            return $c->$cb({error => "Something went wrong, check Koha logs for details."}, 500);
        }
    };
}

sub edit {
    my ($c, $args, $cb) = @_;

    my $patron;
    try {
        $patron = Koha::Patrons->find($args->{borrowernumber});
        my $body = $c->req->json;

        if ($body->{password}) { $body->{password} = hash_password($body->{password}) }; # bcrypt password if given

        die unless $patron->set($body)->validate;

        return $c->$cb({}, 204) unless $patron->is_changed; # No Content = No changes made
        $patron->store;
        return $c->$cb($patron->unblessed, 200);
    }
    catch {
        unless ($patron) {
            return $c->$cb({error => "Patron not found"}, 404);
        }
        unless (blessed $_ && $_->can('rethrow')) {
            return $c->$cb({error => "Something went wrong, check Koha logs for details."}, 500);
        }
        if ($_->isa('Koha::Exceptions::Patron::DuplicateObject')) {
            return $c->$cb({ error => $_->error, conflict => $_->conflict }, 409);
        }
        elsif ($_->isa('Koha::Exceptions::Library::BranchcodeNotFound')) {
            return $c->$cb({ error => "Library with branchcode \"".$_->branchcode."\" does not exist" }, 404);
        }
        elsif ($_->isa('Koha::Exceptions::Category::CategorycodeNotFound')) {
            return $c->$cb({error => "Patron category \"".$_->categorycode."\" does not exist"}, 404);
        }
        else {
            return $c->$cb({error => "Something went wrong, check Koha logs for details."}, 500);
        }
    };
}

sub delete {
    my ($c, $args, $cb) = @_;

    my $patron = Koha::Patrons->find($args->{borrowernumber});
    unless ($patron) {
        return $c->$cb({error => "Patron not found"}, 404);
    }

    # check if loans, reservations, debarrment, etc. before deletion!
    my $res = $patron->delete;

    if ($res eq '1') {
        return $c->$cb({}, 200);
    } elsif ($res eq '-1') {
        return $c->$cb({}, 404);
    } else {
        return $c->$cb({}, 400);
    }
}

sub changepassword {
    my ($c, $args, $cb) = @_;

    my $user = $c->stash('koha.user');
    my $patron = Koha::Patrons->find($args->{borrowernumber});
    return $c->$cb({ error => "Patron not found." }, 404) unless $patron;

    my $pw = $args->{'body'};
    my $dbh = C4::Context->dbh;
    unless (checkpw_internal($dbh, $user->userid, $pw->{'current_password'})) {
        return $c->$cb({ error => "Wrong current password." }, 400);
    }

    my ($success, $errmsg) = $user->change_password_to($pw->{'new_password'});
    if ($errmsg) {
        return $c->$cb({ error => $errmsg }, 400);
    }
    return $c->$cb({}, 200);
}

1;

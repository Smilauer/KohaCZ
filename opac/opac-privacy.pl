#!/usr/bin/perl
# This script lets the users change their privacy rules
#
# copyright 2009, BibLibre, paul.poulain@biblibre.com
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
use CGI qw ( -utf8 );

use C4::Auth;    # checkauth, getborrowernumber.
use C4::Context;
use C4::Circulation;
use C4::Members;
use C4::Output;
use Koha::Borrowers;

my $query = new CGI;

# if OPACPrivacy is disabled, leave immediately
if ( ! C4::Context->preference('OPACPrivacy') || ! C4::Context->preference('opacreadinghistory') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $dbh   = C4::Context->dbh;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-privacy.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        debug           => 1,
    }
);

my $op                         = $query->param("op");
my $privacy                    = $query->param("privacy");
my $privacy_guarantor_checkouts = $query->param("privacy_guarantor_checkouts");

if ( $op eq "update_privacy" ) {
    ModMember(
        borrowernumber             => $borrowernumber,
        privacy                    => $privacy,
        privacy_guarantor_checkouts => $privacy_guarantor_checkouts,
    );
    $template->param( 'privacy_updated' => 1 );
}
elsif ( $op eq "delete_record" ) {

    # delete all reading records for items returned
    # uses a hardcoded date ridiculously far in the future
    my ( $rows, $err_history_not_deleted ) =
      AnonymiseIssueHistory( '2999-12-12', $borrowernumber );

    # confirm the user the deletion has been done
    if ( !$err_history_not_deleted ) {
        $template->param( 'deleted' => 1 );
    }
    else {
        $template->param( 'err_history_not_deleted' => 1 );
    }
}

# get borrower privacy ....
my $borrower = Koha::Borrowers->find( $borrowernumber );;

$template->param(
    'Ask_data'                       => 1,
    'privacy' . $borrower->privacy() => 1,
    'privacyview'                    => 1,
    'borrower'                       => $borrower,
    'surname'                        => $borrower->surname,
    'firstname'                      => $borrower->firstname,
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };

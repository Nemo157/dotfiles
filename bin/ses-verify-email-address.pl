#!/usr/bin/perl -w

# Copyright 2010 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not 
# use this file except in compliance with the License. A copy of the License 
# is located at
#
#        http://aws.amazon.com/apache2.0/
#
# or in the "LICENSE" file accompanying this file. This file is distributed 
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either 
# express or implied. See the License for the specific language governing 
# permissions and limitations under the License.

# This is a code sample showing how to use the Amazon Simple Email Service from the
# command line.  To learn more about this code sample, see the AWS Simple Email
# Service Developer Guide. 


use strict;
use warnings;
use Switch;
use Getopt::Long;
use Pod::Usage;
use XML::LibXML;
use SES;


my %opts = ();
my %params = ();


# Parse the command line arguments and place them in the %opts hash.
sub parse_args {
    GetOptions(verbose => \$opts{'verbose'},
               'e=s' => \$opts{'e'},
               'k=s' => \$opts{'k'},
               'v=s' => \$opts{'v'},
               'd=s' => \$opts{'d'},
               l => \$opts{'l'},
               help => \$opts{'h'}) or pod2usage(-exitval => 2);

    pod2usage(-exitstatus => 0, -verbose => 2) if ($opts{'h'});
}


# Validate the arguments passed on the command line.
sub validate_opts {
    pod2usage(-exitval => 2) unless (defined($opts{'v'}) ^ defined($opts{'l'}) ^ defined($opts{'d'}));
}


# Prepare the parameters for the service call.
sub prepare_params {
    if ($opts{'v'}) {
        $params{'EmailAddress'} = $opts{'v'};
        $params{'Action'}       = 'VerifyEmailAddress';
    } elsif ($opts{'l'}) {
        $params{'Action'}       = 'ListVerifiedEmailAddresses';
    } elsif ($opts{'d'}) {
        $params{'EmailAddress'} = $opts{'d'};
        $params{'Action'}       = 'DeleteVerifiedEmailAddress';
    }
}


# Prints tha data returned by the service call.
sub print_response {
    my $response_content = shift;

    my $parser = XML::LibXML->new();
    my $dom = $parser->parse_string($response_content);
    my $xpath = XML::LibXML::XPathContext->new($dom);
    $xpath->registerNs('ns', $SES::aws_email_ns);

    my @nodes = $xpath->findnodes('/ns:ListVerifiedEmailAddressesResponse' .
                                  '/ns:ListVerifiedEmailAddressesResult' .
                                  '/ns:VerifiedEmailAddresses' .
                                  '/ns:member');

    foreach my $node (@nodes) {
        my $text = $node->textContent();
        print "$text\n";
    }
}


# Main sequence of steps required to make a successful service call
# and send the email.
parse_args;
validate_opts;
prepare_params;
my ($response_code, $response_content) = SES::call_ses \%params, \%opts;
switch ($response_code) {
    case '200' {              # OK
        print_response $response_content;
        exit  0;
    }
    case '400' { exit  1; }   # BAD_INPUT
    case '403' { exit 31; }   # SERVICE_ACCESS_ERROR
    case '500' { exit 32; }   # SERVICE_EXECUTION_ERROR
    case '503' { exit 30; }   # SERVICE_ERROR
    else       { exit -1; }
}


=head1 NAME

ses-verify-email-address.pl - Verify email addresses to be used with the Amazon Simple Email Service (SES).

=head1 SYNOPSIS

B<ses-verify-email-address.pl> [B<--help>] [B<-e> URL] [B<-k> FILE] [B<--verbose>] B<-v> EMAIL | B<-l> | B<-d> EMAIL

=head1 DESCRIPTION

B<ses-verify-email-address.pl> send email to one or more recipients. It reads the message body from B<STDIN>.

=head1 OPTIONS

=over 8

=item B<--help>

Print the manual page.

=item B<-e> URL

The Amazon SES endpoint URL to use. If an endpoint is not provided then a default one will be used.
The default endpoint is "https://email.us-east-1.amazonaws.com/".

=item B<-k> FILE

The Amazon Web Services (AWS) credentials file to use. If the credentials
file is not provided the script will try to get the credentials file from the
B<AWS_CREDENTIALS_FILE> environment variable and if this fails then the script will fail
with an error message.

=item B<--verbose>

Be verbose and display detailed information about the endpoint response.

=item B<-v> EMAIL

The email address to verify.

=item B<-l>

List verified email addresses.

=item B<-d> EMAIL

The verified email address to delete.

=back

=head1 COPYRIGHT

Amazon.com, Inc. or its affiliates

=cut

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
use MIME::Base64;
use Getopt::Long;
use Pod::Usage;
use SES;
use Encode;

binmode STDIN, ":utf8";

my %opts = ();
my %params = ();


# Parse the command line arguments and place them in the %opts hash.
sub parse_args {
    GetOptions(verbose => \$opts{'verbose'},
               'e=s' => \$opts{'e'},
               'k=s' => \$opts{'k'},
               's=s' => \$opts{'s'},
               'f=s' => \$opts{'f'},
               'c=s' => \$opts{'c'},
               'b=s' => \$opts{'b'},
               r => \$opts{'r'},
               help => \$opts{'h'}) or pod2usage(-exitval => 2);

    pod2usage(-exitstatus => 0, -verbose => 2) if ($opts{'h'});

    $opts{t} = parse_list(shift(@ARGV) || '', '[, ]');
    $opts{c} = parse_list($opts{'c'}, ',') if ($opts{'c'});
    $opts{b} = parse_list($opts{'b'}, ',') if ($opts{'b'});
}


sub parse_list {
    my $list = shift;
    my $delim = shift;
    my @list = split(/$delim/, $list);
    @list = grep(!/^$/, @list);
    return $#list == -1 ? undef : \@list;
}


# Validate the arguments passed on the command line.
sub validate_opts {
    if (defined($opts{'r'})) {
        print "Subject is not allowed in raw mode!\n" and pod2usage(-exitval => 2) if defined($opts{'s'});
    } else {
        print "Missing subject!\n"   and pod2usage(-exitval => 2) unless defined($opts{'s'});
        print "Missing sender!\n"    and pod2usage(-exitval => 2) unless defined($opts{'f'});
        print "Missing recipient!\n" and pod2usage(-exitval => 2) unless defined($opts{'t'});
    }
}


# Read message body from STDIN.
sub read_message {
    $opts{'m'} = join '', readline *STDIN;
    $opts{'m'} =~ s/^\x{FEFF}//;
}


# Prepare the parameters for the SendRawEmail service call.
sub prepare_raw_params {
    if ($opts{'f'}) {
        $params{'Source'}                                      = $opts{'f'};
    }
    if ($opts{'t'}) {
	my @opt_t = @{$opts{'t'}};
        for (my $i = 0; $i <= $#opt_t; $i++) {
            $params{'Destinations.member.'.($i+1)}             = $opt_t[$i];
        }
    }
    $params{'RawMessage.Data'}                                 = encode_base64(encode("utf8", $opts{'m'}));
    $params{'Action'}                                          = 'SendRawEmail';
}


# Prepare the parameters for the SendEmail service call.
sub prepare_simple_params {
    $params{'Source'}                                          = $opts{'f'};
    my @opt_t = @{$opts{'t'}};
    for (my $i = 0; $i <= $#opt_t; $i++) {
        $params{'Destination.ToAddresses.member.'.($i+1)}      = $opt_t[$i];
    }
    if ($opts{'c'}) {
	my @opt_c = @{$opts{'c'}};
        for (my $i = 0; $i <= $#opt_c; $i++) {
            $params{'Destination.CcAddresses.member.'.($i+1)}  = $opt_c[$i];
        }
    }
    if ($opts{'b'}) {
	my @opt_b = @{$opts{'b'}};
        for (my $i = 0; $i <= $#opt_b; $i++) {
            $params{'Destination.BccAddresses.member.'.($i+1)} = $opt_b[$i];
        }
    }
    $params{'Message.Subject.Data'}                            = $opts{'s'};
    $params{'Message.Body.Text.Data'}                          = $opts{'m'};
    $params{'Action'}					       = 'SendEmail';
}


# Prepare the parameters for the service call.
sub prepare_params {
    if (defined($opts{'r'})) {
        prepare_raw_params;
    } else {
        prepare_simple_params;
    }
}


# Main sequence of steps required to make a successful service call
# and send the email.
parse_args;
validate_opts;
read_message;
prepare_params;
my ($response_code) = SES::call_ses \%params, \%opts;
switch ($response_code) {
    case '200' { exit  0; }   # OK
    case '400' { exit  1; }   # BAD_INPUT
    case '403' { exit 31; }   # SERVICE_ACCESS_ERROR
    case '500' { exit 32; }   # SERVICE_EXECUTION_ERROR
    case '503' { exit 30; }   # SERVICE_ERROR
    else       { exit -1; }
}


=head1 NAME

ses-send-email.pl - Send email using the Amazon Simple Email Service (SES).

=head1 SYNOPSIS

B<ses-send-email.pl> [B<--help>] [B<-e> URL] [B<-k> FILE] [B<--verbose>] B<-s> SUBJECT B<-f> FROM_EMAIL [B<-c> CC_EMAIL[,CC_EMAIL]...] [B<-b> BCC_EMAIL[,BCC_EMAIL]...] TO_EMAIL[,TO_EMAIL]...

B<ses-send-email.pl> [B<--help>] [B<-e> URL] [B<-k> FILE] [B<--verbose>] [B<-f> FROM_EMAIL] B<-r> TO_EMAIL[,TO_EMAIL]...

=head1 DESCRIPTION

B<ses-send-email.pl> send email to one or more recipients. It reads the message body from B<STDIN>.

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

=item B<-s> SUBJECT

The subject of the email.

=item B<-f> FROM_EMAIL

The email of the sender. This will be the value of the "From" email header.

=item B<-c> CC_EMAIL[,CC_EMAIL]...

The value of the "CC" email header.

=item B<-b> BCC_EMAIL[,BCC_EMAIL]...

The value of the "BCC" email header.

=item B<-r>

Send a raw email.

=back

=head1 COPYRIGHT

Amazon.com, Inc. or its affiliates

=cut

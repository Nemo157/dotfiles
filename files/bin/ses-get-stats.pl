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
               s => \$opts{'s'},
               q => \$opts{'q'},
               help => \$opts{'h'}) or pod2usage(-exitval => 2);

    pod2usage(-exitstatus => 0, -verbose => 2) if ($opts{'h'});
}


# Validate the arguments passed on the command line.
sub validate_opts {
    pod2usage(-exitval => 2) unless (defined($opts{'s'}) ^ defined($opts{'q'}));
}


# Prepare the parameters for the service call.
sub prepare_params {
    if ($opts{'s'}) {
        $params{'Action'} = 'GetSendStatistics';
    } elsif ($opts{'q'}) {
        $params{'Action'} = 'GetSendQuota';
    }
}


# Calculates the optimal number of tabs per column for best display style.
sub compute_tabs {
    my @nodes = @{shift()};
    my $xpath = shift;
    my $tab_size = shift;

    my @headers = map {$_->nodeName()} $xpath->findnodes('ns:*', $nodes[0]);
    my @tabs = ();

    for (my $i = 0; $i < @headers; $i++) {
        $tabs[$i] = int(length($headers[$i]) / $tab_size) + 1;
    }

    foreach my $n (@nodes) {
        my @columns = map {$_->textContent()} $xpath->findnodes('ns:*', $n);
        for (my $i = 0; $i < @columns; $i++) {
            my $t = int(length($columns[$i]) / $tab_size) + 1;
            if ($t > $tabs[$i]) {
                $tabs[$i] = $t;
            }
        }
    }

    return @tabs;
}


# Print an XML node.
sub print_node {
    my $node = shift;
    my $xpath = shift;
    my $is_header = shift;
    my @tabs = @{shift()};
    my $first_column = shift;
    my $tab_size = shift;

    my @children = $xpath->findnodes('ns:*', $node);

    if ($first_column) {
        my $index = -1;
        for (my $i = 0; $i < @children; $i++) {
            if ($first_column eq $children[$i]->nodeName()) {
                $index = $i;
                last;
            }
        }
        if ($index != -1) {
            unshift(@children, splice(@children, $index, 1));
            unshift(@tabs, splice(@tabs, $index, 1));
        }
    }

    for (my $i = 0; $i < @children; $i++) {
        my $text = $is_header ? $children[$i]->nodeName() : $children[$i]->textContent();

	# format number nodes without trailing zeroes after the decimal point
	if ($text =~ /(\d+)\.0+/) {
		$text = $1;
	}

        printf("%-" . ($tab_size * $tabs[$i]) . "s", $text);
    }
    print "\n";
}


# Prints the data returned by the service call.
sub print_response {
    my $response_content = shift;

    my $parser = XML::LibXML->new();
    my $dom = $parser->parse_string($response_content);
    my $xpath = XML::LibXML::XPathContext->new($dom);
    $xpath->registerNs('ns', $SES::aws_email_ns);

    my $first_column;
    my @nodes;

    if ($opts{'s'}) {
        @nodes = $xpath->findnodes('/ns:GetSendStatisticsResponse' .
                                   '/ns:GetSendStatisticsResult' .
                                   '/ns:SendDataPoints' .
                                   '/ns:member');
        @nodes = sort {
            my ($x) = $a->getChildrenByLocalName('Timestamp');
            my ($y) = $b->getChildrenByLocalName('Timestamp');
            $x->textContent() cmp $y->textContent();
        } @nodes;
	$first_column = 'Timestamp';
    } elsif ($opts{'q'}) {
        @nodes = $xpath->findnodes('/ns:GetSendQuotaResponse' .
                                   '/ns:GetSendQuotaResult');
    }

    if ($#nodes != -1) {
        my $tab_size = 8;
        my @tabs = compute_tabs(\@nodes, $xpath, $tab_size);
        print_node($nodes[0], $xpath, 1, \@tabs, $first_column, $tab_size);
        foreach my $node (@nodes) {
            print_node($node, $xpath, 0, \@tabs, $first_column, $tab_size);
        }
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

ses-get-stats.pl - Retrieve statistics about an Amazon Simple Email Service (SES) account usage.

=head1 SYNOPSIS

B<ses-get-stats.pl> [B<--help>] [B<-e> URL] [B<-k> FILE] [B<--verbose>] B<-s> | B<-q>

=head1 DESCRIPTION

B<ses-get-stats.pl> will get the email sending statistics and/or Amazon SES account quotas and
transactions per second (TPS) limit.
The B<-s> option will instruct the script to retrieve the email sending statistics,
while the B<-q> option will retrieve the account quota and TPS limit.

=head1 OPTIONS

=over 8

=item B<--help>

Print the manual page.

=item B<-s>

Retrieve the email sending statistics.

=item B<-q>

Retrieve the account quota and TPS limit.

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

=back

=head1 COPYRIGHT

Amazon.com, Inc. or its affiliates

=cut


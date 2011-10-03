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

package SES;

use strict;
use warnings;
our $VERSION = '1.00';
use base 'Exporter';
our @EXPORT = qw();
use Switch;
use Digest::SHA qw (hmac_sha1_base64 hmac_sha256_base64 sha256);
use URI::Escape qw (uri_escape_utf8);
use LWP;


my $endpoint = 'https://email.us-east-1.amazonaws.com/';
my $service_version = '2010-12-01';
my $signature_version = 'HTTP';
my %opts;
my %params;
my $aws_access_key_id;
my $aws_secret_access_key;

our $aws_email_ns = "http://ses.amazonaws.com/doc/$service_version/";

# RFC3986 unsafe characters
my $unsafe_characters = "^A-Za-z0-9\-\._~";


# Read the credentials from $AWS_CREDENTIALS_FILE file.
sub read_credentials {
    my $file;
    if ($opts{'k'}) {
        $file = $opts{'k'};
    } else {
        $file = $ENV{'AWS_CREDENTIALS_FILE'};
    }
    die "Unspecified AWS credentials file." unless defined($file);
    open (FILE, '<:utf8', $file) or die "Cannot open credentials file <$file>.";
    while (my $line = <FILE>) {
        $line =~ /^\s*(.*?)=(.*?)\s*$/ or die "Cannot parse credentials entry <$line> in <$file>.";
        my ($key, $value) = ($1, $2);
        switch ($key) {
            case 'AWSAccessKeyId' { $aws_access_key_id     = $value; }
            case 'AWSSecretKey'   { $aws_secret_access_key = $value; }
            else                  { die "Unrecognized credential <$key> in <$file>."; }
        }
    }
    close (FILE);
}


# Prepares AWS-specific service call parameters.
sub prepare_aws_params {
    $params{'AWSAccessKeyId'}   = $aws_access_key_id;
    $params{'Timestamp'}        = sprintf(
	                                "%04d-%02d-%02dT%02d:%02d:%02d.000Z",
	                                sub {($_[5]+1900,$_[4]+1,$_[3],$_[2],$_[1],$_[0])}
	                                    ->(gmtime(time))
	                            );
    $params{'Version'}          = $service_version;
}


# Compute the V1 AWS request signature.
# (see http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1928#HTTP)
sub get_signature_v1 {
    $params{'SignatureMethod'}  = 'HmacSHA1';
    $params{'SignatureVersion'} = '1';

    my $data = '';
    for my $key (sort {lc($a) cmp lc($b)} keys %params) {
        my $value = $params{$key};
        $data .= $key . $value;
    }

    return hmac_sha1_base64($data, $aws_secret_access_key) . '=';
}


# Compute the V2 AWS request signature.
# (see http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1928#HTTP)
sub get_signature_v2 {
    $params{'SignatureMethod'}  = 'HmacSHA256';
    $params{'SignatureVersion'} = '2';

    my $endpoint_name = $endpoint;
    $endpoint_name =~ s!^https?://(.*?)/?$!$1!;

    my $data = '';
    $data .= 'POST';
    $data .= "\n";
    $data .= $endpoint_name;
    $data .= "\n";
    $data .= '/';
    $data .= "\n";

    my @params = ();
    for my $key (sort keys %params) {
        my $evalue = uri_escape_utf8($params{$key}, $unsafe_characters);
        push @params, "$key=$evalue";
    }
    my $query_string = join '&', @params;
    $data .= $query_string;

    return hmac_sha256_base64($data, $aws_secret_access_key) . '=';
}


# Add the V1 signature to service call parameters.
sub sign_v1 {
    $params{'Signature'} = get_signature_v1;
}


# Add the V2 signature to service call parameters.
sub sign_v2 {
    $params{'Signature'} = get_signature_v2;
}


# Compute HTTP signature.
sub sign_http_request {
    my $request = shift;

    my $data = '';
    $data .= 'POST';
    $data .= "\n";
    $data .= '/';
    $data .= "\n";
    $data .= $request->content();
    $data .= "\n";
    $data .= 'date:'.$request->header('Date');
    $data .= "\n";
    $data .= 'host:'.$request->header('Host');
    $data .= "\n";
    $data .= "\n";

    my $sig = hmac_sha256_base64(sha256($data), $aws_secret_access_key) . '=';

    my $signature = '';
    $signature .= 'AWS3 ';
    $signature .= "AWSAccessKeyId=$params{'AWSAccessKeyId'}, ";
    $signature .= "Signature=$sig, ";
    $signature .= 'Algorithm=HmacSHA256, ';
    $signature .= 'SignedHeaders=Date;Host';

    return $signature;
}


# Compute HTTPS signature.
sub sign_https_request {
    my $request = shift;

    my $data = '';
    $data .= $request->header('Date');

    my $sig = hmac_sha256_base64($data, $aws_secret_access_key) . '=';;

    my $signature = '';
    $signature .= 'AWS3-HTTPS ';
    $signature .= "AWSAccessKeyId=$params{'AWSAccessKeyId'}, ";
    $signature .= "Signature=$sig, ";
    $signature .= 'Algorithm=HmacSHA256';

    return $signature;
}


# Sign the HTTP request.
sub sign_http {
    my $request = shift;

    my $endpoint_name = $endpoint;
    $endpoint_name =~ s!^https?://(.*?)/?$!$1!;

    $request->date(time);
    $request->header('Host', $endpoint_name);

    my $signature;
    my $use_https = $endpoint =~ m!^https://!;
    if ($use_https) {
        $signature = sign_https_request $request;
    } else {
        $signature = sign_http_request $request;
    }

    $request->header('x-amzn-authorization', $signature);
}


# Build the service call payload.
sub build_payload {
    my @params = ();
    my $payload;
    for my $key (sort keys %params) {
        my $value = $params{$key};
        my ($ekey, $evalue) = (uri_escape_utf8($key, $unsafe_characters), 
			       uri_escape_utf8($value, $unsafe_characters));
        push @params, "$ekey=$evalue";
    }
    $payload = join '&', @params;
    return $payload;
}


# Call the service.
sub call_ses {
    my $params = shift;
    my $opts = shift;

    %opts = %$opts;
    %params = %$params;

    $endpoint = $opts{'e'} if defined($opts{'e'});
    read_credentials;

    prepare_aws_params;

    switch ($signature_version) {
	case 'V1'   { sign_v1; }
	case 'V2'   { sign_v2; }
	case 'HTTP' { }
	else        { die "Unrecognized signature version <$signature_version>."; }
    }

    my $payload = build_payload;

    my $browser = new LWP::UserAgent(agent => "SES-Perl/$service_version");
    my $request = new HTTP::Request 'POST', $endpoint;
    $request->content($payload);
    $request->content_type('application/x-www-form-urlencoded');
    if ($signature_version eq 'HTTP') {
        sign_http $request;
    }
    my $response = $browser->request($request);

    # print the detailed response in verbose mode
    print($response->content) if ($opts{'verbose'});

    my $status = $response->is_success;
    if (!$status) {
        my $content = $response->content;
        $content =~ /<Message>(.*?)<\/Message>/s;
        my $errmsg = $content;
        if ($1) {
            $errmsg = $1;
        }
        print STDERR $errmsg, "\n";
    }
    return ($response->code, $response->content);
}

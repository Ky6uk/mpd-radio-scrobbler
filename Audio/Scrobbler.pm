package Audio::Scrobbler;

use Exporter 'import';
@EXPORT_OK = qw(auth_getToken auth_getSession);

use strict;
use warnings;
use JSON::XS;
use WWW::Curl::Easy;
use Digest::MD5 qw( md5_hex );

my $curl = WWW::Curl::Easy->new;

# CURL basic settings
$curl->setopt(CURLOPT_CONNECTTIMEOUT, 10);
$curl->setopt(CURLOPT_TIMEOUT, 30);

sub auth_getToken {
    my ($api_key) = @_;
    my $response;

    $curl->setopt(CURLOPT_URL, &api_url({ method => "auth.getToken", api_key => $api_key }));
    $curl->setopt(CURLOPT_WRITEDATA, \$response);
    $curl->perform;

    return decode_json($response)->{"token"} if defined decode_json($response)->{"token"};
    return 0;
}

sub auth_getSession {
    my ($api_key, $api_secret, $api_token) = @_;

    my $sig_params = {
        api_key => $api_key,
        method  => "auth.getSession",
        token   => $api_token
    };

    my $url_options = {
        method  => "auth.getSession",
        api_key => $api_key,
        token   => $api_token,
        api_sig => &api_signature($sig_params, $api_secret)
    };

    my $response;
    $curl->setopt(CURLOPT_URL, &api_url($url_options));
    $curl->setopt(CURLOPT_WRITEDATA, \$response);
    $curl->perform;

    if ( defined decode_json($response)->{"session"} ) {
        return decode_json($response)->{"session"}->{"key"};
    }

    return decode_json($response);
}

sub api_signature {
    my ($params, $api_secret) = @_;
    my $signature = join("", map { $_ . $params->{$_} } sort keys %$params);

    return md5_hex( $signature . $api_secret );
}

sub api_url {
    my ($params) = @_;

    return join(
        "&",
        "http://ws.audioscrobbler.com/2.0/?format=json",
        map { join("=", $_, $params->{$_}) } keys(%$params)
    );
}

1;

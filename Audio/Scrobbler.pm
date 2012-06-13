package Audio::Scrobbler;

use Exporter 'import';
@EXPORT_OK = qw(
    auth_getToken
    auth_getSession
    track_updateNowPlaying
);

use strict;
use warnings;
use JSON::XS;
use WWW::Curl::Easy;
use Digest::MD5 qw( md5_hex );

my $curl = WWW::Curl::Easy->new;

sub auth_getToken {
    my ($api_key) = @_;
    my $response = &send_request(&api_url({ method => "auth.getToken", api_key => $api_key }));

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

    my $response = &send_request(&api_url($url_options));

    if ( defined decode_json($response)->{"session"} ) {
        return decode_json($response)->{"session"}->{"key"};
    }

    return decode_json($response);
}

sub track_updateNowPlaying {
    my ($track, $artist, $api_key, $api_secret, $api_session) = @_;

    my $sig_params = {
        track   => $track,
        artist  => $artist,
        api_key => $api_key,
        sk      => $api_session,
        method  => "track.updateNowPlaying"
    };

    my $url_options = {
        track   => $track,
        artist  => $artist,
        api_key => $api_key,
        sk      => $api_session,
        method  => "track.updateNowPlaying",
        api_sig => &api_signature($sig_params, $api_secret)
    };

    my $response = &send_request(&api_url($url_options), "POST");

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
        map { join("=", $_, $params->{$_}) } keys %$params
    );
}

sub send_request {
    my ($url, $method) = @_;

    my $response;
    $curl->setopt(CURLOPT_CONNECTTIMEOUT, 10);
    $curl->setopt(CURLOPT_TIMEOUT, 30);
    $curl->setopt(CURLOPT_POST, 1) if $method;
    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_WRITEDATA, \$response);
    $curl->perform;
    $curl->cleanup;

    return $response;
}

1;
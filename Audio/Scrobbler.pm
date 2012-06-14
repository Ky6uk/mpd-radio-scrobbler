package Audio::Scrobbler;

use Exporter 'import';
@EXPORT_OK = qw(
    auth_getToken
    auth_getSession
    track_updateNowPlaying
    track_scrobble
);

use strict;
use warnings;
use JSON::XS;
use URI::Escape;
use WWW::Curl::Easy;
use Digest::MD5 qw( md5_hex );

my $curl = WWW::Curl::Easy->new;

sub auth_getToken {
    my ($api_key) = @_;
    my $response = &send_request({ method => "auth.getToken", api_key => $api_key });

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

    my $response = &send_request({%$sig_params, api_sig => &api_signature($sig_params, $api_secret)});

    if ( defined decode_json($response)->{"session"} ) {
        return decode_json($response)->{"session"}->{"key"};
    }

    return decode_json($response);
}

sub track_updateNowPlaying {
    my ($artist, $track, $api_key, $api_secret, $api_session) = @_;

    my $sig_params = {
        track   => $track,
        artist  => $artist,
        api_key => $api_key,
        sk      => $api_session,
        method  => "track.updateNowPlaying"
    };

    my $response = &send_request({%$sig_params, api_sig => &api_signature($sig_params, $api_secret)}, "POST");

    return decode_json($response);
}

sub track_scrobble {
    my ($artist, $track, $api_key, $api_secret, $api_session) = @_;

    my $sig_params = {
        track     => $track,
        artist    => $artist,
        api_key   => $api_key,
        timestamp => time,
        sk        => $api_session,
        method    => "track.scrobble"
    };

    my $response = &send_request({%$sig_params, api_sig => &api_signature($sig_params, $api_secret)}, "POST");

    return decode_json($response);
}

sub api_signature {
    my ($params, $api_secret) = @_;
    my $signature = join("", map { $_ . $params->{$_} } sort keys %$params);

    return md5_hex( $signature . $api_secret );
}

sub send_request {
    my ($params, $method) = @_;
    my $response;
    my $url = "http://ws.audioscrobbler.com/2.0/";
    my $fields = join("&", "format=json", map { join("=", $_, uri_escape($params->{$_})) } keys %$params);

    if ( $method and $method eq "POST" ) {
        $curl->setopt(CURLOPT_POST, 1);
        $curl->setopt(CURLOPT_POSTFIELDS, $fields);
    }
    else {
        $url = join("?", $url, $fields);
    }

    $curl->setopt(CURLOPT_CONNECTTIMEOUT, 5);
    $curl->setopt(CURLOPT_TIMEOUT, 30);
    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_WRITEDATA, \$response);
    $curl->perform;
    $curl->cleanup;

    return $response;
}

1;
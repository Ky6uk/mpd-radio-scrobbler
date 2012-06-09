package Audio::Scrobbler;

use Exporter 'import';
@EXPORT_OK = qw(auth_user);

use strict;
use warnings;
use 5.01;
use JSON::XS;
use WWW::Curl::Easy;
use Digest::MD5 qw( md5_hex );
use Data::Dumper;

my $curl       = WWW::Curl::Easy->new;
my $api_key    = "fc8ebcbc6bfec2cf047b3c163f5682eb";
my $api_secret = "b57a5629f48d691ac178dc6b02ca58f5";
my $api_token;

# CURL basic settings
$curl->setopt(CURLOPT_CONNECTTIMEOUT, 10);
$curl->setopt(CURLOPT_TIMEOUT, 30);

sub auth_user {
    auth_getToken();

    say "auth url: http://www.last.fm/api/auth/?api_key=$api_key&token=$api_token" if $api_token;
    print "\nPress [Enter] to continue...";
    <>;

    auth_getSession();
}

sub auth_getToken {
    say "auth.getToken";

    my $response;
    $curl->setopt(CURLOPT_URL, &api_url({ method => "auth.getToken", api_key => $api_key }));
    $curl->setopt(CURLOPT_WRITEDATA, \$response);
    $curl->perform;

    $api_token = decode_json($response)->{"token"};
}

sub auth_getSession {
    say "auth.getSession";

    my $url_options = {
        method  => "auth.getSession",
        api_key => $api_key,
        api_sig => api_signature("auth.getSession"),
        token   => $api_token
    };

    my $response;
    $curl->setopt(CURLOPT_URL, &api_url($url_options));
    $curl->setopt(CURLOPT_WRITEDATA, \$response);
    $curl->perform;

    say Dumper decode_json($response);
}

sub api_signature {
    my ($method) = @_;

    return md5_hex( join("", "api_key", $api_key, "method", $method, "token", $api_token, $api_secret) );
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

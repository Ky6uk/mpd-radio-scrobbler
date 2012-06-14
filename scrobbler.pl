#!/usr/bin/env perl

use 5.01;
use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;

use Audio::Scrobbler qw(
    auth_getToken
    auth_getSession
    track_updateNowPlaying
    track_scrobble
);

my $api_key    = "fc8ebcbc6bfec2cf047b3c163f5682eb";
my $api_secret = "b57a5629f48d691ac178dc6b02ca58f5";
my $api_session = "";
my $options = {};

getopts('rs:', $options);

if ( $options->{"s"} ) {
    ( $options->{"s"} =~ m/^[0-9a-f]{32}$/ ) ?
        ( $api_session = $options->{"s"} ) :
        ( die "invalid session string in -s" );
}

if ( $options->{"r"} and not $api_session ) {
    my $api_token = auth_getToken($api_key);

    if ($api_token and ref \$api_token eq "SCALAR" ) {
        say "auth url: http://www.last.fm/api/auth/?api_key=$api_key&token=$api_token" ;
        print "\nPress [Enter] to continue...";
        <>;
    }
    else { die "auth_getToken() exception", Dumper $api_token }

    $api_session = auth_getSession($api_key, $api_secret, $api_token);

    if ( $api_session and ref \$api_session eq "SCALAR" ) {
        say "Your API session key: $api_session";
    }
    else { die "auth_getSession() exception: ", Dumper $api_session }
}

print Dumper track_updateNowPlaying("Nice Ain't Got Me Nothing", "Storyville", $api_key, $api_secret, $api_session) if $api_session;
#print Dumper track_scrobble("Nice Ain't Got Me Nothing", "Storyville", $api_key, $api_secret, $api_session) if $api_session;
#!/usr/bin/env perl

use EV;
use 5.01;
use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;
use IO::Socket::INET;

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
my $mpd_host = "localhost";
my $mpd_port = "6600";
my $update_interval = 10;
my $scrobble_interval = 90;
my $counter = 0;
my $scrobbled = 0;
my $current_track = '';

getopts('rhs:', $options);

&usage() if $options->{"h"};

if ( $options->{"s"} ) {
    ( $options->{"s"} =~ m/^[0-9a-f]{32}$/ ) ?
        ( $api_session = $options->{"s"} ) :
        ( die "invalid session string in -s" );
}

if ( $options->{"r"} and not $api_session ) {
    my $api_token = auth_getToken($api_key);

    if ($api_token and ref \$api_token eq "SCALAR") {
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

sub get_track_info {
    my $mpd = IO::Socket::INET->new(
        PeerAddr => $mpd_host,
        PeerPort => $mpd_port,
        Proto    => 'tcp'
    ) or die "Can't connect to MPD: $@\n";

    <$mpd>;
    print $mpd "status\n";

    my $song_id;
    my $found = 0;
    while ( my $line = <$mpd> ) {
        chomp $line;

        last if $line =~ m/^OK$/;
        next if $found;

        if ( $line =~ m/^state\:\s+(.+?)$/ ) {
            if ( $1 ne "play" ) {
                $mpd->close();
                warn 'state should be "play"';
                last;
            }

            next;
        }

        if ( $line =~ m/^songid\:\s+(\d+)$/ ) {
            $song_id = $1;
            $found = 1;
        }
    }

    my ($artist, $track);
    if ( defined $song_id ) {
        print $mpd "playlistinfo $song_id\n";

        while ( my $line = <$mpd> ) {
            chomp $line;

            last if $line =~ m/^OK$/;

            if ( $line =~ m/^Title\:\s+[\s\-]*(.+?)\s*\-\s*(.+?)$/ ) {
                $artist = $1;
                $track  = $2;
                last;
            }
        }
    }

    $mpd->close();

    return ($artist, $track);
}

sub usage {
    say <<"USAGE";

    -r                  get session key
    -s <session_key>    run script with <session_key> string
    -h                  show this help
USAGE
    exit;
}

my $watcher = EV::timer 0, $update_interval, sub {
    my ($artist, $track) = &get_track_info();

    if ($artist and $track) {
        my $response = track_updateNowPlaying($artist, $track, $api_key, $api_secret, $api_session);

        if ($response->{"error"}) {
            say "Update exception: " . $response->{"message"};
        }
        else {
            say "Updated: $artist - $track";

            if ( $counter > 0 and $current_track ne "$artist - $track" ) {
                $counter = 1;
                $scrobbled = 0;
                $current_track = "$artist - $track";
            }
            else {
                $counter++;
                $current_track = "$artist - $track";

                if ( not $scrobbled and $scrobble_interval / $update_interval <= $counter ) {
                    my $response = track_scrobble($artist, $track, $api_key, $api_secret, $api_session);

                    if ($response->{"error"}) {
                        say "Scrobble exception: " . $response->{"message"};
                    }
                    else {
                        say "Scrobbled: $artist - $track";
                        $scrobbled = 1;
                    }
                }
            }
        }
    }
} if $api_session;

EV::run;
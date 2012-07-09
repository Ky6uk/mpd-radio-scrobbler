#!/usr/bin/env perl

use strict;
use warnings;

use EV;
use 5.01;
use Getopt::Std;
use Data::Dumper;
use IO::Socket::INET;
use Audio::Scrobbler2;

# user variables
my $api_key    = "fc8ebcbc6bfec2cf047b3c163f5682eb";
my $api_secret = "b57a5629f48d691ac178dc6b02ca58f5";
my $mpd_host = "localhost";
my $mpd_port = "6600";
my $update_interval = 10;
my $scrobble_interval = 90;

# system variables
my $scrobbler = Audio::Scrobbler2->new($api_key, $api_secret);
my $counter = 0;
my $scrobbled = 0;
my $current_track = '';
my $options = {};

getopts('rhs:', $options);

&usage() if $options->{"h"};

if ( $options->{"s"} ) {
    ( $options->{"s"} =~ m/^[0-9a-f]{32}$/ ) ?
        ( $scrobbler->set_session_key($options->{"s"}) ) :
        ( die "invalid session string in -s" );
}

if ( $options->{"r"} ) {
    my $api_token = $scrobbler->auth_getToken();

    if ($api_token and ref \$api_token eq "SCALAR") {
        say "auth url: http://www.last.fm/api/auth/?api_key=$api_key&token=$api_token" ;
        print "\nPress [Enter] to continue...";
        <>;
    }
    else { die "auth_getToken() exception", Dumper $api_token }

    my $api_session = $scrobbler->auth_getSession();

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

        if ( $line =~ m/^song\:\s+(\d+)$/ ) {
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
        my $response = $scrobbler->track_updateNowPlaying($artist, $track);

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
                    my $response = $scrobbler->track_scrobble($artist, $track);

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
};

EV::run;
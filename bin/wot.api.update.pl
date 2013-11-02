#!/usr/bin/perl
use strict;
use warnings;
use Mango;
use Mojo::IOLoop;
use Mojo::UserAgent;
use Getopt::Long;

my $config  = {};
my $cfile   = undef;

GetOptions(
    'config=s'      => \$cfile,
);

die 'Usage: ', $0, ' --config <path to config file>', "\n" unless(defined($cfile));

my $craw = '';
if(my $fh = IO::File->new($cfile)) {
    $craw .= $_ while(<$fh>);
    $fh->close;

    $config = eval($craw);

    die 'Error parsing configuration: ', $@, "\n" if($@);
} else {
    die 'Could not open configuration file "', $cfile, '": ', $!, "\n";
}
my $mango = Mango->new($config->{mongodb}->{host});
my $ua    = Mojo::UserAgent->new;

my $cursor = $mango->db('wot-replays')->collection('replays')->find()->fields({ 'players' => 1, 'roster' => 1 });
my $delay  = Mojo::IOLoop->delay(sub {
    exit(0);
});
$cursor->all(sub {
    my ($coll, $err, $docs) = (@_);
    my $fetch = {};

    foreach my $doc (@$docs) {
        foreach my $pname (keys(%{$doc->{players}})) {  
            my $re = $doc->{roster}->[$doc->{players}->{$pname} + 0];
            my $pl = $re->{player};
            my $id = $pl->{dbid} || $pl->{accountDBID};
            $fetch->{$id}++;
        }
    }

    $fetch = [ keys(%$fetch) ];
    my $num = scalar(@$fetch);

    for(1..$num) {
        my $end = $delay->begin;
        fetch_api(shift(@$fetch) => sub {
            $end->();
        });
    }
});
$delay->wait unless(Mojo::IOLoop->is_running);

sub fetch_api {
    my $id   = shift;
    my $cb   = shift;

    if(my $url_host = get_stat_server($id)) {
        my $url = sprintf('http://%s/uc/accounts/%d/api/%s/?source_token=%s', $url_host, $id, $config->{apistats}->{version}, $config->{apistats}->{token});
        $ua->get($url => sub {
            my ($ua, $tx) = (@_);
            if(my $res = $tx->success) {
                my $j = Mojo::JSON->new();
                my $jres = $j->decode($res->body);
                if($jres->{status} eq 'ok') {
                    my $data = {
                        _id     => $id + 0,
                        ctime   => Mango::BSON::bson_time,
                        stats   => $jres,
                    };
                    $mango->db('wot-replays')->collection('player.stats')->save($data => sub { 
                        my ($coll, $err, $oid) = (@_);
                        warn 'saved for ', $id, ' -> ', $url, "\n";
                        $cb->(($err) ? undef : 1);
                    });
                } else {
                    warn 'STATUS ERROR', "\n";
                    $cb->(undef);
                }
            } else {
                warn 'HTTP STATUS ERROR', "\n";
                $cb->(undef);
            }
        });
    } else {
        warn 'NO STAT SERVER', "\n";
        $cb->(undef);
    }
}

sub get_stat_server {
    my $id = shift;
    my $map = {
        'ru'    => [ 0,            499999999 ],
        'eu'    => [ 500000000,    999999999 ],
        'sea'   => [ 2000000000,   2499999999 ],
        'vn'    => [ 2500000000,   2999999999 ],
        'kr'    => [ 3000000000,   3499999999 ],
    };
    my $servers = {
        'na' => 'api.worldoftanks.com',
        'eu' => 'api.worldoftanks.eu',
        'ru' => 'api.worldoftanks.ru',
        'vn' => 'portal-wot.go.vn',
        'kr' => 'worldoftanks.kr',
        'sea' => 'api.worldoftanks.asia',
    };
    my $s = undef;

    foreach my $server (keys(%$map)) {
        $s = $server and last if($id >= $map->{$server}->[0] && $id <= $map->{$server}->[1]);
    }
    if($s) {
        return $servers->{$s};
    } else {
        return undef;
    }
}


package WR::ServerFinder;
use Moose;
use Mojo::UserAgent;
use Try::Tiny;

has 'ua' => (is => 'ro', isa => 'Mojo::UserAgent', required => 1, default => sub { return Mojo::UserAgent->new() });

use constant SERVERS => {
    'na' => 'worldoftanks.com/community/accounts/%d-%s/',
    'eu' => 'worldoftanks.eu/community/accounts/%d-%s/',
    'ru' => 'worldoftanks.ru/community/accounts/%d-%s/',
    'vn' => 'portal-wot.go.vn/community/accounts/%d-%s/',
    'kr' => 'worldoftanks.kr/community/accounts/%d-%s/',
    'sea' => 'worldoftanks-sea.com/community/accounts/%d-%s/',
    };

use constant SERVER_INDICES => {
    0   => 'ru',
    1   => 'eu',
    2   => 'na',
    3   => 'sea',
    4   => 'vn',
    5   => 'kr',
};

use constant SERVER_ID_MAPPING => {
    'ru'    => [ 0,            499999999 ],
    'eu'    => [ 500000000,    999999999 ],
    'sea'   => [ 2000000000,   2499999999 ],
    'vn'    => [ 2500000000,   2999999999 ],
    'kr'    => [ 3000000000 .. 3499999999 ],
};

sub get_server_by_id {
    my $self = shift;
    my $id   = shift;

    foreach my $server (keys(%{__PACKAGE__->SERVER_ID_MAPPING})) {
        my $v = __PACKAGE__->SERVER_ID_MAPPING->{$server};
        return $server if($id >= $v->[0] && $id <= $v->[1]);
    }
    return undef;
}

sub get_ua_res {
    my $self = shift;
    my $url = shift;

    if(my $tx = $self->ua->get($url)) {
        if(my $res = $tx->success) {
            return $res;
        } else {
            return undef;
        }
    }
    return undef;
}

sub find_user {
    my $self = shift;
    my $id   = shift;
    my $server = shift;
    my $res;
    my $e;

    try {
        $res = $self->get_ua_res(sprintf(__PACKAGE__->SERVERS->{$server}, $id, ''));
    } catch {
        $e = $_;
    };

    return undef if($e);

    if($res) {
        my $content = $res->dom->at('div.l-content');
        my $user    = $content->h1->text;
        return $user;
    }
    return undef;
}

sub find_server {
    my $self = shift;
    my $id   = shift;
    my $name = shift;

    foreach my $cluster (qw/eu na sea vn ru kr/) {
        my $title = $self->ua->get(sprintf(__PACKAGE__->SERVERS->{$cluster}, $id, $name))->res->dom->at('title')->text;
        if($title =~ /\s$name\s\|/) {
            return $cluster;
        }
    }
    return undef;
}

__PACKAGE__->meta->make_immutable;

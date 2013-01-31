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
    'sea' => 'worldoftanks-sea.com/community/accounts/%d-%s/',
    };

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

    foreach my $cluster (qw/na eu ru sea vn/) {
        my $title = $self->ua->get(sprintf(__PACKAGE__->SERVERS->{$cluster}, $id, $name))->res->dom->at('title')->text;
        if($title =~ /\s$name\s\|/) {
            return $cluster;
        }
    }
    return undef;
}

__PACKAGE__->meta->make_immutable;

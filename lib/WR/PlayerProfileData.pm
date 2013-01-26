package WR::PlayerProfileData;
use Moose;
use Mojo::UserAgent;
use Try::Tiny;
use Data::Dumper;

has 'db' => (is => 'ro', isa => 'MongoDB::Database', required => 1);
has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'server' => (is => 'ro', isa => 'Str', required => 1);
has 'id' => (is => 'ro', isa => 'Num', required => 1);

has 'ua' => (is => 'ro', isa => 'Mojo::UserAgent', required => 1, default => sub { return Mojo::UserAgent->new() });

use constant SERVERS => {
    'na' => 'worldoftanks.com',
    'eu' => 'worldoftanks.eu',
    'ru' => 'worldoftanks.ru',
    'sea' => 'worldoftanks-sea.com',
    };

use constant T_RESULT_LAYOUT => [
    qw/battles victories defeats survived destroyed detected hit_ratio damage capture_points defense_points total_experience average_experience maximum_experience/,
];

use constant T_RESULT_FORMAT => [
    qw/num splitnum splitnum splitnum num num asis num num num numsub numsub numsub/
];
    

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

sub load_user {
    my $self = shift;
    my $res;
    my $e;
    my $data = {
        id      =>  $self->id,
        name    =>  $self->name,
    };

    try {
        $res = $self->get_ua_res(sprintf(__PACKAGE__->SERVERS->{$self->server} . '/community/accounts/%d-%s/', $self->id, $self->name));
    } catch {
        $e = $_;
    };

    return undef if($e);

    # given $res, go dom it up
    if($res->dom->at('a.b-link-clan')) {
        $data->{clan} = {
            link => 'http://' . __PACKAGE__->SERVERS->{$self->server} . $res->dom->at('a.b-link-clan')->attrs('href'),
            tag  => $res->dom->at('a.b-link-clan span.tag')->text,
            name => $res->dom->at('a.b-link-clan span.name')->text,
        }
    } else {
        $data->{clan} = undef;
    }

    $data->{updated} = $res->dom->at('div.b-data-date span.js-datetime-format')->attrs('data-timestamp') + 0;

    my $table = $res->dom->find('table.t-result')->[0];
    my $i = 0;

    $table->find('td.td-number-nowidth')->each(sub {
        my $f = __PACKAGE__->T_RESULT_LAYOUT->[$i];
        if(__PACKAGE__->T_RESULT_FORMAT->[$i] eq 'num') {
            my $t = shift->text;
            $t =~ s/\s+//g;
            $data->{$f} = $t + 0;
        } elsif(__PACKAGE__->T_RESULT_FORMAT->[$i] eq 'splitnum') {
            $data->{$f} = (split(/\s/, shift->text))[0] + 0,
        } elsif(__PACKAGE__->T_RESULT_FORMAT->[$i] eq 'numsub') {
            my $t = shift->text;
            $t =~ s/\s+//g;
            $data->{$f} = $t + 0;
        } elsif(__PACKAGE__->T_RESULT_FORMAT->[$i] eq 'asis') {
            $data->{$f} = shift->text;
        }
        $i++;
    });

    return $data;
}


__PACKAGE__->meta->make_immutable;

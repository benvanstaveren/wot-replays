package WR::PlayerProfileData;
use Moose;
use Mojo::UserAgent;
use Try::Tiny;
use Data::Dumper;
use WR::Efficiency;

has 'db' => (is => 'ro', isa => 'MongoDB::Database', required => 1);
has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'server' => (is => 'ro', isa => 'Str', required => 1);
has 'id' => (is => 'ro', isa => 'Num', required => 1);

has 'ua' => (is => 'ro', isa => 'Mojo::UserAgent', required => 1, default => sub { return Mojo::UserAgent->new() });

use constant SERVERS => {
    'na'    => 'worldoftanks.com',
    'eu'    => 'worldoftanks.eu',
    'ru'    => 'worldoftanks.ru',
    'sea'   => 'worldoftanks-sea.com',
    'vn'    => 'portal-wot.go.vn',
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

sub unroman {
    my $self = shift;
    my $table = {
        'I' => 1,
        'II' => 2,
        'III' => 3,
        'IV' => 4,
        'V' => 5,
        'VI' => 6,
        'VII' => 7,
        'VIII' => 8,
        'IX' => 9,
        'X' => 10
        };
    my $r = shift;

    $r =~ s/\s+//g;
    return $table->{uc($r)};
}

sub load_user {
    my $self = shift;
    my $res;
    my $e;
    my $data = {
        id      =>  $self->id,
        name    =>  $self->name,
    };

    if(my $rec = $self->db->get_collection('cache.ppd')->find_one({ _id => sprintf('%s_%s', $self->id, $self->name) })) {
        if($rec->{last} + 86400 > time()) {
            return $rec->{data};
        } 
    }

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

    my $vehicles = [];
    my $seen     = {};
    my $tier     = 0;
    my $skip     = 1;

    $res->dom->find('table.t-statistic')->[1]->find('tr')->each(sub {
        if($skip == 1) {
            $skip = 0;
            return;
        }
        my $tr = shift;

        my $vtier = $self->unroman($tr->find('td')->[0]->at('span.level a')->text);
        my $vname = $tr->find('td')->[1]->at('a')->text;
        my $battles = $tr->find('td')->[2]->text + 0;
        my $victories = $tr->find('td')->[3]->text + 0;

        push(@$vehicles, { 
            name => $vname,
            tier => $vtier,
            battles => $battles,
            victories => $victories,
            });

        $tier += ($vtier * $battles),
    });

    $data->{vehicles} = $vehicles;
    $data->{average_tier} = $tier / $data->{battles};

    $self->db->get_collection('cache.ppd')->save({
        _id     => sprintf('%s_%s', $self->id, $self->name),
        last    => time(),
        data    => $data,
    });

    return $data;
}

sub efficiency {
    my $self = shift;
    my $type = shift;
    my $user = $self->load_user;

    my %args = (
        killed          => $user->{destroyed} / $user->{battles} + 0,
        spotted         => $user->{detected} / $user->{battles} + 0,
        damaged         => 0,
        damage_direct   => $user->{damage} / $user->{battles} + 0,
        damage_spotted  => 0,
        winrate         => 100/($user->{battles}/$user->{victories}) + 0,
        capture_points  => $user->{capture_points} / $user->{battles},
        defense_points  => $user->{defense_points} / $user->{battles},
        tier            => $user->{average_tier} + 0,
        );

    my $e = WR::Efficiency->new(%args);
    if(defined($type)) {
        my $m = 'eff_' . $type;
        return $e->$m();
    } else {
        my $eff = {};
        for(qw/xvm vba wn6/) {
            my $m = 'eff_' . $_;
            $eff->{$_} = $e->$m();
        }
        return $eff;
    }
}

__PACKAGE__->meta->make_immutable;

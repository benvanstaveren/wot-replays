package WR::App::Controller::Auto;
use Mojo::Base 'WR::App::Controller';
use Data::Dumper;
use WR::Res::Achievements;
use WR::Res::Bonustype;
use WR::Res::Gametype;
use WR::Res::Servers;
use WR::Res::Country;
use WR::Res::Vehicleclass;

use constant ROMAN_NUMERALS => [qw(0 I II III IV V VI VII VIII IX X)];

sub generate_vehicle_select {
    my $self = shift;
    my $p = [];
    my $l = { 
        china => 'China',
        france => 'France',
        germany => 'Germany',
        usa => 'USA',
        ussr => 'USSR',
        uk => 'UK',
        };
   
    foreach my $country (qw/china france germany usa ussr uk/) {
        my $d = { label => $l->{$country}, country => $country };
        my $cursor = $self->db('wot-replays')->get_collection('data.vehicles')->find({ country => $country })->sort({ label => 1 });
        while(my $obj = $cursor->next()) {
            push(@{$d->{items}}, {
                id => $obj->{name},
                value => $obj->{label},
            });
        }
        push(@$p, $d);
    }
    return $p;
}

sub get_match_result {
    my $self = shift;
    my $surv_player_team = $self->stash('req_replay')->{team_survivors}->[0];
    my $surv_enemy_team = $self->stash('req_replay')->{team_survivors}->[1];

    my $win = $self->stash('req_replay')->{game}->{isWin};
    my $draw = $self->stash('req_replay')->{game}->{isDraw};

    my $win_reasons = {
        13  =>  [ 'by godlike slaughter' ],
        10  =>  [ 'by shooting them like fish in a barrel' ],
        8   =>  [ 'by utter annihilation' ],
        5   =>  [ 'by annihilation' ],
        2   =>  [ 'by attrition '],
        1   =>  [ 'by that lucky last dude' ],
    };

    my $loss_reasons = {
        13  =>  [ 'due to getting lollerstomped', 'due to surprise buttsecks, no lube.' ],
        10  =>  [ 'due to overzealous use of high explosives' ],
        8   =>  [ 'due to decisive action on the enemy\'s part' ],
        5   =>  [ 'by annihilation' ],
        2   =>  [ 'by attrition '],
        1   =>  [ 'due to that last living bastard on the enemy team' ],
    };
        
    return 'Draw' if($draw);

    if($win) {
        if($surv_enemy_team == 0) {
            # won by annihilation
            my $v = 'Victory';
            foreach my $l (sort { $b <=> $a } (keys(%$win_reasons))) {
                if($surv_player_team >= $l) {
                    my $r = $win_reasons->{$l};
                    my $rr = $r->[int(rand(scalar(@$)))];
                    $v .= ' ' . $rr;
                    return $v;
                }
            }
            return "$v by miracle";
        } else {
            return 'Victory by capture';
        }
    } else {
        if($surv_player_team == 0) {
            # lost by annihilation
            my $v = 'Defeat';

            foreach my $l (sort { $b <=> $a } (keys(%$loss_reasons))) {
                if($surv_enemy_team >= $l) {
                    my $r = $loss_reasons->{$l};
                    my $rr = $r->[int(rand(scalar(@$)))];
                    $v .= ' ' . $rr;
                    return $v;
                }
            }
            return $v;
        } else {
            return 'Defeat by capture';
        }
    }
}

sub index {
    my $self = shift;

    $self->stash('timing.start' => [ Time::HiRes::gettimeofday ]);

    my $last_seen = $self->session('last_seen') || 0;
    $self->session('last_seen' => time());
    $self->session('first_visit' => 1) if($last_seen + 86400 < time());

    $self->stash('hint_signin' => 1) unless(defined($self->session('gotit_signin')) && $self->session('gotit_signin') > 0);

    if(my $notify = $self->session->{'notify'}) {
        delete($self->session->{'notify'});
        $self->stash(notify => $notify);
    }

    $self->stash(
        settings => {
            first_visit => $self->session('first_visit'),
        },
    );

    # twiddle peoples' openID username and password
    if($self->is_user_authenticated) {
        my $o = $self->current_user->{openid};
        if($o =~ /https:\/\/(.*?)\..*\/id\/(\d+)-(.*)\//) {
            my $server = $1;
            my $pname = $3;
            $self->stash('current_player_name' => $pname);
            $self->stash('current_player_server' => uc($server));
        } else {
            die 'wotdafuq: ', $o, "\n";
        }
    }

    return 1;
}

1;



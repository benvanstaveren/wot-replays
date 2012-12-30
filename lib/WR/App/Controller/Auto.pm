package WR::App::Controller::Auto;
use Mojo::Base 'WR::App::Controller';
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
        };
   
    foreach my $country (qw/china france germany usa ussr/) {
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

    my $wr;
    $wr = {
            get_id => sub { return shift->{_id} },
            match_result => sub { return $self->get_match_result() },
            res => sub { return $self->app->wr_res },
            generate_vehicle_select => sub {
                return $self->generate_vehicle_select();
            },
            generate_map_select => sub {
                my $list = [];
                my $cursor = $self->db('wot-replays')->get_collection('data.maps')->find()->sort({ label => 1 });

                while(my $o = $cursor->next()) {
                    push(@$list, {
                        id => $o->{_id},
                        label => $o->{label}
                    });
                }
                return $list;
            },
            map_name => sub {
                my $mid = shift;

                if(my $obj = $self->db('wot-replays')->get_collection('data.maps')->find_one({ 
                    '$or' => [
                        { _id => $mid },
                        { name_id => $mid },
                    ],
                })) {
                    return $obj->{label};
                } else {
                    return sprintf('404:%s', $mid);
                }
            },
            vehicle_icon => sub {
                my $v = shift;
                my $s = shift || 32;
                my ($c, $n) = split(/:/, $v, 2);

                return lc(sprintf('//images.wot-replays.org/vehicles/%d/%s-%s.png', $s, $c, $n));
            },
            vehicle_tier => sub {
                my $v = shift;
                if(my $obj = $self->db('wot-replays')->get_collection('data.vehicles')->find_one({ _id => $v })) {
                    return sprintf('//images.wot-replays.org/icon/tier/%02d.png', $obj->{level});
                } else {
                    return '-';
                }
            },
            vehicle_url => sub {
                my $v = shift;
                my ($c, $n) = split(/:/, $v, 2);

                return sprintf('/vehicle/%s/%s/', $c, $n);
            },
            vehicle_description => sub {
                my $v = shift;
                my ($c, $n) = split(/:/, $v, 2);

                if(my $obj = $self->db('wot-replays')->get_collection('data.vehicles')->find_one({ _id => $v })) {
                    return $obj->{description};
                } else {
                    return sprintf('nodesc:%s', $v);
                }
            },
            vehicle_name_short => sub {
                my $v = shift;
                my ($c, $n) = split(/:/, $v, 2);

                if(my $obj = $self->db('wot-replays')->get_collection('data.vehicles')->find_one({ _id => $v })) {
                    return $obj->{label_short} || $obj->{label};
                } else {
                    return sprintf('nolabel_short:%s', $v);
                }
            },
            fix_map_id => sub {
                return shift;
            },
            equipment_name => sub {
                my $id = shift;
                if(my $obj = $self->db('wot-replays')->get_collection('data.equipment')->find_one({ wot_id => $id })) {
                    return $obj->{label};
                } else {
                    return undef;
                }
            },
            equipment_icon => sub {
                my $id = shift;
                if(my $obj = $self->db('wot-replays')->get_collection('data.equipment')->find_one({ wot_id => $id })) {
                    return $obj->{icon};
                } else {
                    return undef;
                }
            },
            component_name => sub {
                my $cnt = shift;
                my $cmp = shift;
                my $id  = shift;
                if(my $obj = $self->db('wot-replays')->get_collection('data.components')->find_one({ 
                    country => $cnt,
                    component => $cmp,
                    component_id => $id,
                })) {
                    return $obj->{label};
                } else {
                    return undef;
                }
            },
            vehicle_name => sub {
                my $v = shift;
                my ($c, $n) = split(/:/, $v, 2);

                if(my $obj = $self->db('wot-replays')->get_collection('data.vehicles')->find_one({ _id => $v })) {
                    return $obj->{label};
                } else {
                    return sprintf('nolabel:%s', $v);
                }
            },
            epoch_to_dt => sub {
                my $epoch = shift;
                my $dt = DateTime->from_epoch(epoch => $epoch);
                return $dt;
            },
            sprintf => sub {
                my $fmt = shift;
                return sprintf($fmt, @_);
            },
            percentage_of => sub {
                my $a = shift;
                my $b = shift;

                return 0 unless(($a > 0) && ($b > 0));

                # a = 200, b = 100 -> 50% 
                return sprintf('%.0f', 100/($a/$b));
            },
            is_user_authenticated => sub {
                return $self->is_user_authenticated;
            },
            is_own_replay => sub {
                if(my $r = $self->stash('req_replay')) {
                    return (defined($r->{site}->{uploaded_by}) && ($r->{site}->{uploaded_by}->to_string eq $self->current_user->{_id}->to_string))
                        ? 1 
                        : 0
                }
                return 0;
            },
            is_the_boss => sub {
                return ($self->is_user_authenticated && $self->current_user->{email} eq 'scrambled@xirinet.com') ? 1 : 0
            },
            user => sub {
                return $self->current_user;
            },
            user_display_name => sub {
                return $self->current_user->{display_name};
            },
            map_slug => sub {
                my $name = shift;
                my $slug = lc($name);
                $slug =~ s/\s+/_/g;
                $slug =~ s/'//g;
                return $slug;
            },
            map_image => sub {
                my $size = shift;
                my $id   = shift;
                if(my $map = $self->db('wot-replays')->get_collection('data.maps')->find_one({ _id => $id })) {
                    return lc(sprintf('//images.wot-replays.org/maps/%d/%s', $size, $map->{icon}));
                } else {
                    return undef;
                }
            },
        };

    $self->stash(
        settings => {
            first_visit => $self->session('first_visit'),
        },
        wr => $wr,
    );

    return 1;
}

1;



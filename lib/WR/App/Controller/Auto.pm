package WR::App::Controller::Auto;
use Mojo::Base 'WR::Controller';
use WR::Res::Achievements;
use Data::Dumper;

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

    my $last_seen = $self->session('last_seen') || 0;
    $self->session('last_seen' => time());
    $self->session('first_visit' => 1) if($last_seen + 86400 < time());

    $self->stash(
        settings => {
            first_visit => $self->session('first_visit'),
            upload_use_premium => 
                ($self->is_user_authenticated) 
                    ? ($self->current_user->{profile}->{premium})
                        ? 1 
                        : ($self->session('upload_use_premium') == 1) 
                            ? 1 
                            : 0
                    : ($self->session('upload_use_premium') == 1) 
                        ? 1 
                        : 0
            ,
            upload_server => 
                ($self->is_user_authenticated) 
                    ? ($self->current_user->{profile}->{server})
                        ? $self->current_user->{profile}->{server}
                        : ($self->session('upload_server'))
                            ? $self->session('upload_server')
                            : ''
                    : ($self->session('upload_server'))  
                        ? $self->session('upload_server')
                        : ''
            ,
        },
        wr => {
            match_result => sub { return $self->get_match_result() },
            res => {
                achievements => WR::Res::Achievements->new(),
            },
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

                if(my $obj = $self->db('wot-replays')->get_collection('data.maps')->find_one({ _id => $mid })) {
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
                    return __PACKAGE__->ROMAN_NUMERALS->[$obj->{level}];
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
            user => sub {
                return $self->current_user;
            },
            user_display_name => sub {
                return $self->current_user->{display_name};
            },
            dump => sub {
                return Dumper([@_]);
            }
        },
    );

    return 1;
}

1;



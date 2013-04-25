package WR::App::Helpers;
use strict;
use warnings;
use WR::Query;
use WR::Res;
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
        uk => 'UK',
        };
   
    foreach my $country (qw/china france germany usa ussr uk/) {
        my $d = { label => $l->{$country}, country => $country };
        my $cursor = $self->db('wot-replays')->get_collection('data.vehicles')->find({ country => $country })->sort({ label => 1 });
        while(my $obj = $cursor->next()) {
            push(@{$d->{items}}, {
                id => $obj->{name},
                value => $obj->{label},
                level => $obj->{level},
            });
        }
        push(@$p, $d);
    }
    return $p;
}

sub add_helpers {
    my $class = shift;
    my $self  = shift; # not really self but the Mojo app

    $self->helper(is_user_authenticated => sub {
        my $ctrl = shift;

        if(my $openid = $ctrl->session('openid')) {
            if(my $user = $ctrl->model('wot-replays.accounts')->find_one({ openid => $openid })) {
                return 1;
            } else {
                return 0; # because the verification step will actually create it
            }
        } else {
            return 0;
        }
    });

    $self->helper(current_user => sub {
        my $ctrl = shift;
        if(my $openid = $ctrl->session('openid')) {
            if(my $user = $ctrl->model('wot-replays.accounts')->find_one({ openid => $openid })) {
                return $user;
            } else {
                return undef;
            }
        }
        return undef;
    });

    $self->helper(wr_query => sub {
        my $self = shift;
        return WR::Query->new(@_, coll => $self->db('wot-replays')->get_collection('replays'));
    });

    $self->helper('lc' => sub {
        shift and return lc(shift);
    });

    $self->helper('partner_name' => sub {
        my $self = shift;
        my $pid  = shift;
        my $temptable = {
            'vbaddict' => 'www.vbaddict.net',
        };

        my $n = $temptable->{$pid} || 'unknown';
        return $n;
    });

    $self->helper('replay_wpa' => sub {
        my $self = shift;
        my $r = shift;

        if(my $wpa = $self->model('wot-replays.cache.wpa')->find_one({ _id => sprintf('%s-%s', $r->{player}->{vehicle}->{full}, $r->{map}->{id})})) {
            return $wpa;
        } else {
            return {};
        }
    });

    $self->helper('has_role' => sub {
        my $self = shift;
        my $u    = shift;
        my $r    = shift;

        return 0 unless(defined($u));
        return 0 unless(defined($u->{roles}));

        foreach my $role (@{$u->{roles}}) {
            return 1 if($role eq $r);
        }
        return 0;
    });

    $self->helper(to_json => sub {
        my $self = shift;
        my $v    = shift;

        if(ref($v) eq 'ARRAY') {
            return $self->app->json->encode([ map { WR::Query->fuck_mojo_json($_) } @$v ]);
        } else {
            return $self->app->json->encode(WR::Query->fuck_mojo_json($v));
        }
    });

    $self->helper('clear_replay_page' => sub {
        my $self = shift;
        my $id   = shift;

        my $filename = sprintf('%s/%s.html', $self->stash('config')->{paths}->{pages}, $id);
        unlink($filename);
    });

    $self->helper(is_event_account => sub {
        my $self = shift;
        my $r    = shift;

        if($r->{player}->{server} eq 'sea') {
            return ($r->{player}->{name} =~ /^WG_/) ? 1 : 0;
        }
        return 0;
    });

    $self->helper(get_id => sub { return $_[1]->{_id} });
    $self->helper(res => sub { return shift->app->wr_res });
    $self->helper(generate_vehicle_select => \&generate_vehicle_select);
    $self->helper(eff_color => sub {
        my $self = shift;
        my $eff = shift;
        my $col;

        return '<span>-</span>' unless(defined($eff));

        if($eff < 600) {
            $col = '#e02225';
        } elsif($eff >= 600 && $eff < 900) {
            $col = '#b86162';
        } elsif($eff >= 900 && $eff < 1200) {
            $col = '#40c077';
        } elsif($eff >= 1200 && $eff < 1500) {
            $col = '#539770'
        } elsif($eff >= 1500 && $eff < 1800) {
            $col = '#5899B7';
        } else {
            $col = '#17A6E8';
        }

        return sprintf('<span style="color: %s">%d</span>', $col, $eff);
    });

    $self->helper(show_efficiency => sub {
        my $self = shift;
        my $show = 1;

        if($self->is_user_authenticated) {
            if($self->current_user->{settings}->{hide_efficiency} == 1) {
                $show = 0;
            }
        } 

        if(my $user = $self->model('wot-replays.accounts')->find_one({ 
            player_name     => $self->stash('req_replay')->{player}->{name},
            player_server   => $self->stash('req_replay')->{player}->{server},
        })) {
            if($user->{settings}->{hide_my_efficiency} == 1) {
                $show = 0;
            }
        }
        my $pname = $self->stash('req_replay')->{player}->{name};
        $show = 0 if($self->stash('req_replay')->{efficiency}->{$pname}->{xvm} == 0);
        return $show;
    });
    $self->helper(vehicles_by_frags => sub {
        my $self = shift;
        my $hash = shift;

        return [ (sort({ $b->{kills} <=> $a->{kills} } values(%$hash))) ];
    });
    $self->helper(vehicles_by_xp => sub {
        my $self = shift;
        my $hash = shift;

        return [ (sort({ $b->{xp} <=> $a->{xp} } values(%$hash))) ];
    });
    $self->helper(consumable_icon_style => sub {
        my $self = shift;
        my $a = shift;

        if($a) {
            my $i = (ref($a) eq 'HASH') ? $a->{id} : $a;
            if(my $c = $self->model('wot-replays.data.consumables')->find_one({ wot_id => $i + 0 })) {
                return sprintf('style="background: transparent url(http://images.wot-replays.org/consumables/24x24/%s) no-repeat scroll 0 0"', $c->{icon});
            } else {
                return undef;
            }
        } else {
            return undef;
        }
    });
    $self->helper(get_vehicle_by_id => sub {
        my $self = shift;
        my $id   = shift;

        return $self->stash('req_replay')->{vehicles}->{$id};
    });
    $self->helper(ammo_icon_style => sub {
        my $self = shift;
        my $a = shift;
        if($a) {
            my $i = (ref($a) eq 'HASH') ? $a->{id} : $a;
            if(my $c = $self->model('wot-replays.data.components')->find_one({ component => 'shells', _id => $i + 0 })) {
                my $n = ($a->{count} > 0) ? $c->{kind} : sprintf('NO_%s', $c->{kind});
                return sprintf('style="background: transparent url(http://images.wot-replays.org/ammo/24x24/%s.png) no-repeat scroll 0 0"', $n);
            } else {
                return undef;
            }
        } else {
            return undef;
        }
    });
    $self->helper(ammo_name => sub {
        my $self = shift;
        my $a = shift;
        my $kind_map = {
            'ARMOR_PIERCING' => 'Armor-Piercing',
            'ARMOR_PIERCING_CR' => 'AP Composite-Rigid',
            'ARMOR_PIERCING_HE' => 'AP High-Explosive',
            'HIGH_EXPLOSIVE' => 'High-Explosive',
            'HOLLOW_CHARGE' => 'High-Explosive Anti-Tank',
        };

        if($a) {
            my $i = (ref($a) eq 'HASH') ? $a->{id} : $a;
            if(my $c = $self->model('wot-replays.data.components')->find_one({ component => 'shells', _id => $i + 0 })) {
                return sprintf('%s %dmm %s %s', 
                    ($a->{count} > 0) ? sprintf('%d x', $a->{count}) : '',
                    $c->{caliber}, 
                    $kind_map->{$c->{kind}},
                    $c->{label}
                    );
            } else {
                return undef;
            }
        } else {
            return undef;
        }
    });
    $self->helper(consumable_name => sub {
        my $self = shift;
        my $a = shift;
        
        if($a) {
            my $i = (ref($a) eq 'HASH') ? $a->{id} : $a;
            if(my $c = $self->model('wot-replays.data.consumables')->find_one({ wot_id => $i + 0 })) {
                return $c->{label} || $c->{name};
            } else {
                return sprintf('404:%d', $i);
            }
        } else {
            return undef;
        }
    });
    $self->helper(generate_map_select => sub {
        my $self = shift;
        my $list = [];
        my $cursor = $self->model('wot-replays.data.maps')->find()->sort({ label => 1 });

        while(my $o = $cursor->next()) {
            push(@$list, {
                id => $o->{_id},
                label => $o->{label}
            });
        }
        return $list;
    });
    $self->helper(map_name => sub {
        my $self = shift;
        my $mid = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ 
            '$or' => [
                { _id => $mid },
                { name_id => $mid },
                { slug => $mid },
            ],
        })) {
            return $obj->{label};
        } else {
            return sprintf('404:%s', $mid);
        }
    });
    $self->helper(vehicle_icon => sub {
        my $self = shift;
        my $v    = shift;
        my $s    = shift || 32;
        my ($c, $n) = split(/:/, $v, 2);

        return lc(sprintf('//images.wot-replays.org/vehicles/%d/%s-%s.png', $s, $c, $n));
    });
    $self->helper(vehicle_tier => sub {
        my $self = shift;
        my $v = shift;
        if(my $obj = $self->model('wot-replays.data.vehicles')->find_one({ _id => $v })) {
            return sprintf('//images.wot-replays.org/icon/tier/%02d.png', $obj->{level});
        } else {
            return '-';
        }
    });
    $self->helper(vehicle_url => sub {
        my $self = shift;
        my $v = shift;
        my ($c, $n) = split(/:/, $v, 2);

        return sprintf('/vehicle/%s/%s/', $c, $n);
    });
    $self->helper(vehicle_description => sub {
        my $self = shift;
        my $v = shift;
        my ($c, $n) = split(/:/, $v, 2);

        if(my $obj = $self->model('wot-replays.data.vehicles')->find_one({ _id => $v })) {
            return $obj->{description};
        } else {
            return sprintf('nodesc:%s', $v);
        }
    });
    $self->helper(vehicle_name_short => sub {
        my $self = shift;
        my $v = shift;
        my ($c, $n) = split(/:/, $v, 2);

        if(my $obj = $self->model('wot-replays.data.vehicles')->find_one({ _id => $v })) {
            return $obj->{label_short} || $obj->{label};
        } else {
            return sprintf('nolabel_short:%s', $v);
        }
    });
    $self->helper(equipment_name => sub {
        my $self = shift;
        my $id = shift;

        # here's a fun one, we need to see if id is a string or not, if it is, it's one of those
        # weird unicode characters that came out wrong, so we want to convert that to something we can use

        return unless defined($id);
        return if($id == 0);

        if(my $obj = $self->model('wot-replays.data.equipment')->find_one({ wot_id => $id })) {
            return $obj->{label};
        } else {
            return sprintf('nolabel:%d', $id);
        }
    });
    $self->helper(equipment_icon => sub {
        my $self = shift;
        my $id = shift;

        return unless defined($id);
        return if($id == 0);

        if(my $obj = $self->model('wot-replays.data.equipment')->find_one({ wot_id => $id })) {
            return $obj->{icon};
        } else {
            return undef;
        }
    });
    $self->helper(component_name => sub {
        my $self = shift;
        my $cnt = shift;
        my $cmp = shift;
        my $id  = shift;

        if(my $obj = $self->model('wot-replays.data.components')->find_one({ 
            country => $cnt,
            component => $cmp,
            component_id => $id,
        })) {
            return $obj->{label};
        } else {
            return sprintf('nolabel:%s/%s/%d', $cnt, $cmp, $id);
        }
    });
    $self->helper(vehicle_name => sub {
        my $self = shift;
        my $v = shift;
        my ($c, $n) = split(/:/, $v, 2);

        if(my $obj = $self->model('wot-replays.data.vehicles')->find_one({ _id => $v })) {
            return $obj->{label};
        } else {
            return sprintf('nolabel:%s', $v);
        }
    });
    $self->helper(epoch_to_dt => sub {
        my $self = shift;
        my $epoch = shift;
        my $dt = DateTime->from_epoch(epoch => $epoch);
        return $dt;
    });
    $self->helper(sprintf => sub {
        my $self = shift;
        my $fmt = shift;

        return CORE::sprintf($fmt, @_);
    });
    $self->helper(percentage_of => sub {
        my $self = shift;
        my $a = shift;
        my $b = shift;

        return 0 unless(($a > 0) && ($b > 0));

        # a = 200, b = 100 -> 50% 
        return sprintf('%.0f', 100/($a/$b));
    });
    $self->helper(is_own_replay => sub {
        my $self = shift;
        if(my $r = $self->stash('req_replay')) {
            return (defined($r->{site}->{uploaded_by}) && ($r->{site}->{uploaded_by}->to_string eq $self->current_user->{_id}->to_string))
                ? 1 
                : 0
        }
        return 0;
    });
    $self->helper(is_the_boss => sub {
        return ($self->is_user_authenticated && $self->current_user->{email} eq 'scrambled@xirinet.com') ? 1 : 0
    });
    $self->helper(user => sub {
        return shift->current_user;
    });
    $self->helper(map_slug => sub {
        my $self = shift;
        my $name = shift;
        my $slug = lc($name);
        $slug =~ s/\s+/_/g;
        $slug =~ s/'//g;
        return $slug;
    });
    $self->helper(map_image => sub {
        my $self = shift;
        my $size = shift;
        my $id   = shift;
        if(my $map = $self->db('wot-replays.data.maps')->find_one({ _id => $id })) {
            return lc(sprintf('//images.wot-replays.org/maps/%d/%s.png', $size, $id));
        } else {
            return '404:' . $id;
        }
    });
    $self->helper(datadumper => sub {
        shift;
        return Dumper([ shift ]);
    });
    $self->helper(bonus_type_name => sub {
        return shift->app->wr_res->bonustype->get(shift, 'label_short');
    });
    $self->helper(game_type_name => sub {
        return shift->app->wr_res->gametype->i18n(shift);
    });
    $self->helper('achievement_is_award' => sub {
        my $self = shift;
        return $self->app->wr_res->achievements->is_award(shift);
    });
    $self->helper('achievement_is_class' => sub {
        my $self = shift;
        return $self->app->wr_res->achievements->is_class(shift);
    });
    $self->helper('get_achievements' => sub {
        return shift->app->wr_res->achievements;
    });
    $self->helper('get_res' => sub {
        return shift->app->wr_res;
    });
}

1;

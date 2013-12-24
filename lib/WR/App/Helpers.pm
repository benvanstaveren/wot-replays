package WR::App::Helpers;
use strict;
use warnings;
use WR::Query;
use WR::Res;
use WR::Util::CritDetails;
use WR::Provider::ServerFinder;
use File::Slurp qw/read_file/;
use WR::Constants qw/nation_id_to_name gameplay_id_to_name/;
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;
use Data::Dumper;
use DateTime;

use constant ROMAN_NUMERALS => [qw(0 I II III IV V VI VII VIII IX X)];

# there are a few helpers that still make database calls, these need to be
# replaced with "better" solutions since blocking DB calls can really mess
# up the works... 

sub generate_vehicle_select {
    my $self = shift;

    my $p = [];
    my $l = { 
        china => 'China',
        france => 'France',
        germany => 'Germany',
        usa => 'USA',
        ussr => 'USSR',
        japan => 'Japan',
        uk => 'UK',
        };
   
    foreach my $country (qw/china france germany usa japan ussr uk/) {
        my $d = { label => $l->{$country}, country => $country };
        my $cursor = $self->model('wot-replays.data.vehicles')->find({ country => $country })->sort({ label => 1 });
        while(my $obj = $cursor->next()) {
            push(@{$d->{items}}, {
                id => $obj->{_id},
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

    ### DB CALLING HELPERS - FIXME FIXME FIXME
    $self->helper(generate_item_icon_with_count => sub {
        my $self = shift;
        my $i    = shift;
        my $tc   = parse_int_compact_descr($i->{item});

        my $type    = type_id_to_name($tc->{type_id});
        my $model   = ($type eq 'equipment') ? 'wot-replays.data.consumables' : 'wot-replays.data.equipment'; 
        my $path    = ($type eq 'equipment') ? 'consumables' : 'equipment';

        # the typecomp is the ID of the item 
        if(my $c = $self->model($model)->find_one({ wot_id => $tc->{id} })) {
            return sprintf('<span data-placement="bottom" data-toggle="tooltip" title="%s x%d" class="bs-tooltip mission-icon rounded" style="background: transparent url(http://images.wotreplays.org/%s/32x32/%s) no-repeat scroll 0 0"><b>%d</b></span>', $c->{label}, $i->{count}, $path, $c->{icon}, $i->{count});
        } else {
            return undef;
        }
    });

    $self->helper(generate_vehicle_select => \&generate_vehicle_select);
    $self->helper(consumable_icon_style => sub {
        my $self = shift;
        my $a = shift;

        return undef unless(defined($a));

        if(ref($a)) {
            $self->app->log->debug('new style consumable');
            return sprintf('style="background: transparent url(http://images.wotreplays.org/consumables/24x24/%s) no-repeat scroll 0 0"', $a->{icon});
        } else {
            $self->app->log->debug('old style consumable');
            my $tc = parse_int_compact_descr($a);
            my $i = $tc->{id};
            if(my $c = $self->model('wot-replays.data.consumables')->find_one({ wot_id => $i + 0 })) {
                return sprintf('style="background: transparent url(http://images.wotreplays.org/consumables/24x24/%s) no-repeat scroll 0 0"', $c->{icon});
            } else {
                return undef;
            }
        }
    });

    $self->helper(ammo_icon_style => sub {
        my $self = shift;
        my $a = shift;

        return undef unless(defined($a) && ref($a) eq 'HASH');

        if(defined($a->{ammo})) {
            # new style
            my $n = ($a->{count} > 0) ? $a->{ammo}->{kind} : sprintf('NO_%s', $a->{ammo}->{kind});
            $self->app->log->debug('new style ammo');
            return sprintf('style="background: transparent url(http://images.wotreplays.org/ammo/24x24/%s.png) no-repeat scroll 0 0"', $n);
        } else {
            $self->app->log->debug('old style ammo');
            my $i = $a->{id};
            if(my $c = $self->model('wot-replays.data.components')->find_one({ component => 'shells', _id => $i + 0 })) {
                my $n = ($a->{count} > 0) ? $c->{kind} : sprintf('NO_%s', $c->{kind});
                return sprintf('style="background: transparent url(http://images.wotreplays.org/ammo/24x24/%s.png) no-repeat scroll 0 0"', $n);
            } else {
                return undef;
            }
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

        return undef unless(defined($a) && ref($a) eq 'HASH');

        if(defined($a->{ammo})) {
            $self->app->log->debug('new style ammo');
            my $c = $a->{ammo};
            return sprintf('%s %dmm %s %s', 
                sprintf('%d x', $a->{count}),
                $c->{caliber}, 
                $kind_map->{$c->{kind}},
                $self->loc($c->{i18n}),
                );
        } else {
            $self->app->log->debug('old style ammo');
            my $i = $a->{id};
            if(my $c = $self->model('wot-replays.data.components')->find_one({ component => 'shells', _id => $i + 0 })) {
                return sprintf('%s %dmm %s %s', 
                    sprintf('%d x', $a->{count}),
                    $c->{caliber}, 
                    $kind_map->{$c->{kind}},
                    $c->{label}
                    );
            } else {
                return undef;
            }
        }
    });

    ### DB CALLING HELPERS END

    $self->helper(wr_query => sub {
        my $self = shift;
        return WR::Query->new(@_, coll => $self->model('wot-replays.replays'), log => $self->app->log);
    });


    $self->attr(_sf => sub { WR::Provider::ServerFinder->new });
    $self->helper(resolve_server_by_playerid => sub {
        my $self = shift;
        my $id   = shift;

        return $self->app->_sf->get_server_by_id($id + 0);
    });

    $self->helper(fix_server => sub {
        my $self = shift;
        my $server = shift;

        return ($server eq 'sea') ? 'asia' : $server;
    });

    $self->helper(strftime => sub {
        my $self = shift;
        my $fmt  = shift;
        my $time = shift;

        my $dt = DateTime->from_epoch(epoch => $time / 1000, time_zone => 'UTC');
        return $dt->strftime($fmt);
    });

    $self->helper(basename => sub {
        my $self = shift;
        my $n    = shift;
        my @a    = split(/\//, $n);

        return pop(@a);
    });

    $self->helper(browse_page => sub {
        my $self = shift;
        my $p    = shift;

        my $f = $self->stash('browse_filter_raw');
        $f->{p} = $p;

        if($self->stash('pageid') eq 'vehicle') {
            delete($f->{$_}) for(qw/vehicle tier_min tier_max/);
        } elsif($self->stash('pageid') eq 'map') {
            delete($f->{$_}) for(qw/map/);
        } elsif($self->stash('pageid') eq 'player') {
            delete($f->{$_}) for(qw/tplayer player/);
        }

        my @a = ();
        
        foreach my $key (sort { $a cmp $b } (keys(%$f))) {
            push(@a, $key, $f->{$key});
        }

        return join('/', @a);
    });

    $self->helper(wot_version => sub {
        my $self = shift;
        my $version = shift;

        my @parts = split(/, /, $version);
        pop(@parts); # drop the last 0
        return join('.', @parts);
    });

    $self->helper(is_user_authenticated => sub {
        my $ctrl = shift;

        if(my $openid = $ctrl->session('openid')) {
            return 1;
        } else {
            return 0; # because the verification step will actually create it
        }
    });

    $self->helper(is_victory => sub {
        my $self = shift;
        my $replay = shift;

        return ($replay->{game}->{winner} == $self->get_recorder_vehicle($replay)->{player}->{team}) ? 1 : 0;
    });

    $self->helper(is_draw => sub {
        my $self = shift;
        my $replay = shift;

        return ($replay->{game}->{winner} < 1) ? 1 : 0;
    });

    $self->helper(is_defeat => sub {
        my $self = shift;
        my $replay = shift;

        return ($self->is_victory($replay)) ? 0 : 1;
    });

    $self->helper(current_user => sub {
        my $ctrl = shift;
        if(my $openid = $ctrl->session('openid')) {
            return $ctrl->stash('current_user') || {};
        } else {
            return undef;
        }
    });

    $self->helper(get_replay_stats => sub {
        my $self = shift;
        my $r = shift;
        my $field = shift;

        return $r->{stats}->{$field};
    });

    $self->helper(is_old_version => sub {
        my $self = shift;
        my $r    = shift;

        $r =~ s/\D+//g;
        $r += 0;
        if($self->stash('config')->{wot}->{version_numeric} > $r) {
            return 1;
        } else {
            return 0;
        }
    });

    $self->helper('hashbucket' => sub {
        my $self = shift;
        my $name = shift;
        my $size = shift || 7;

        my @parts = split(//, substr($name, 0, $size));
        return join('/', @parts);
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

    $self->helper(as_json => sub {
        my $self = shift;
        my $v    = shift;
        my $s = $self->app->json->encode($v);
        return $s;
    });

    $self->helper(get_id => sub { return $_[1]->{_id} });
    $self->helper(res => sub { return shift->app->wr_res });


    $self->helper(get_battleviewer_icon => sub {
        my $self = shift;
        my $r = shift;
        my $i = shift;

        my $roster = $self->get_roster_by_vid($r, $i);

        my $color = ($roster->{player}->{team} == $r->{game}->{recorder}->{team}) ? 'g' : 'r';
        if(my $obj = $self->model('wot-replays.data.vehicles')->find_one({ _id => $roster->{vehicle}->{ident}})) {
            return sprintf('%s_%s.png', lc($obj->{type}), $color);
        } else {
            return 'blank.png';
        }
    });

    $self->helper(consumable_name => sub {
        my $self = shift;
        my $a = shift;

        return undef unless(defined($a));

        if(ref($a)) {
            # new style
            $self->app->log->debug('new style consumable');
            return $a->{label} || $a->{name};
        } else {
            $self->app->log->debug('old style consumable');
            my $tc = parse_int_compact_descr($a);
            if(my $c = $self->model('wot-replays.data.consumables')->find_one({ wot_id => $tc->{id} + 0 })) {
                return $c->{label} || $c->{name};
            } else {
                return sprintf('404:%d', $a);
            }
        }
    });

    $self->helper(generate_map_select => sub {
        my $self = shift;
        my $list = [];
        my $cursor = $self->model('wot-replays.data.maps')->find()->sort({ label => 1 });

        while(my $o = $cursor->next()) {
            push(@$list, {
                id => $o->{numerical_id},
                label => $o->{label}
            });
        }
        return $list;
    });

    $self->helper(map_icon => sub {
        my $self   = shift;
        my $replay = shift;

        if(defined($replay->{game}->{map_extra})) {
            return $replay->{game}->{map_extra}->{icon};
        } else {
            if(my $obj = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $replay->{game}->{map} })) {
                return $obj->{icon};
            } else {
                return sprintf('404:%s', $replay->{game}->{map});
            }
        }
    });

    $self->helper(map_positions_by_ident => sub {
        my $self    = shift;
        my $ident   = shift;
        my $type    = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ _id => $ident })) {
            return $obj->{attributes}->{positions}->{$type};
        } else {
            return undef;
        }
    });     

    $self->helper(map_positions => sub {
        my $self    = shift;
        my $replay  = shift;
        my $type    = $replay->{game}->{type};

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $replay->{game}->{map} })) {
            return $obj->{attributes}->{positions}->{$type};
        } else {
            return undef;
        }
    });     

    $self->helper(map_boundingbox_by_ident => sub {
        my $self    = shift;
        my $ident  = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ _id => $ident })) {
            return [ $obj->{attributes}->{geometry}->{bottom_left}, $obj->{attributes}->{geometry}->{upper_right} ];
        } else {
            return undef;
        }
    });


    $self->helper(map_boundingbox => sub {
        my $self    = shift;
        my $replay  = shift;

        if(defined($replay->{game}->{map_extra})) {
            return $replay->{game}->{map_extra}->{geometry};
        } else {
            if(my $obj = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $replay->{game}->{map} })) {
                return [ $obj->{attributes}->{geometry}->{bottom_left}, $obj->{attributes}->{geometry}->{upper_right} ];
            } else {
                return undef;
            }
        }
    });

    $self->helper(vehicle_link => sub {
        my $self = shift;
        my $ident = shift;

        $ident =~ s/:/\//g;
        return $ident;
    });

    $self->helper(map_ident => sub {
        my $self = shift;
        my $replay = shift;

        if(defined($replay->{game}->{map_extra})) {
            return $replay->{game}->{map_extra}->{ident};
        } else {
            if(my $obj = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $replay->{game}->{map} })) {
                return $obj->{_id};
            } else {
                return sprintf('404:%s', $replay->{game}->{map});
            }
        }
    });

    $self->helper(map_name => sub {
        my $self = shift;
        my $replay = shift;

        if(defined($replay->{game}->{map_extra})) {
            return $replay->{game}->{map_extra}->{label};
        } else {
            if(my $obj = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $replay->{game}->{map} })) {
                return $obj->{label};
            } else {
                return sprintf('404:%s', $replay->{game}->{map});
            }
        }
    });

    $self->helper(was_killed_by_recorder => sub {
        my $self = shift;
        my $r    = shift;
        my $id   = shift;
        my $rec  = $self->get_recorder_vehicle($r);
        return 0 unless(defined($id));
        return ($id == $rec->{vehicle}->{id}) ? 1 : 0;
    });

    # this parses out the crit info
    $self->helper(get_crit_details => sub {
        my $self = shift;
        my $crit = shift;

        return WR::Util::CritDetails->new(crit => $crit)->parse;
    });

    $self->helper(get_roster_by_vid => sub {
        my $self = shift;
        my $r    = shift;
        my $v    = shift;

        return $self->get_roster_entry($r, $r->{vehicles}->{$v});
    });

    $self->helper(get_roster_entry => sub {
        my $self = shift;
        my $r    = shift;
        my $i    = shift;

        return $r->{roster}->[$i];
    });

    $self->helper(get_recorder_vehicle => sub {
        my $self = shift;
        my $r = shift;

        return $self->get_roster_entry($r, $r->{game}->{recorder}->{index});
    });

    $self->helper(vehicle_icon => sub {
        my $self = shift;
        my $v    = shift;
        my $s    = shift || 32;
        my ($c, $n) = split(/:/, $v, 2);

        return lc(sprintf('//images.wotreplays.org/vehicles/%d/%s-%s.png', $s, $c, $n));
    });

    $self->helper(vehicle_tier => sub {
        my $self = shift;
        my $v = shift;
        if(my $obj = $self->model('wot-replays.data.vehicles')->find_one({ _id => $v })) {
            return sprintf('//images.wotreplays.org/icon/tier/%02d.png', $obj->{level});
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
        my $nid  = shift;
        my $type = shift;
        my $id  = shift;

        return 'missing' unless(defined($nid) && defined($type) && defined($id));

        # nation->text
        my $nation = nation_id_to_name($nid);

        $id = -1 unless(defined($id));
        $id = -1 if(length($id) == 0);

        if(my $obj = $self->model('wot-replays.data.components')->find_one({ country => $nation, component => $type, component_id => $id + 0 })) {
            return $self->loc($obj->{i18n}) if(defined($obj->{i18n}));
            return $obj->{label} || sprintf('nodblabel: %d', $id);
        } else {
            return sprintf('nolabel:%s/%s/%d', $nation, $type, $id);
        }
    });

    $self->helper(epoch_to_dt => sub {
        my $self = shift;
        my $epoch = shift;
        my $dt = DateTime->from_epoch(epoch => $epoch);
        return $dt;
    });

    $self->helper(nonegative => sub {
        my $self = shift;
        my $v    = shift;

        return ($v >= 0) ? $v : 0;
    });

    $self->helper(int => sub {
        shift and return CORE::int(shift);
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
        my $r = shift;
	
        if($self->is_user_authenticated && ( ($self->current_user->{player_name} eq $r->{game}->{recorder}->{name}) && ($self->current_user->{player_server} eq $r->{game}->{server}))) {
            return 1;
        } else {
            return 0;
        }
    });

    $self->helper(is_the_boss => sub {
        my $self = shift;
        if($self->is_user_authenticated && ( ($self->current_user->{player_name} eq 'Scrambled') && ($self->current_user->{player_server} eq 'sea'))) {
            return 1;
        } else {
            return 0;
        }
    });

    $self->helper(user => sub {
        return shift->current_user;
    });

    $self->helper(map_slug => sub {
        my $self = shift;
        my $replay = shift;

        if(defined($replay->{game}->{map_extra})) {
            return $replay->{game}->{map_extra}->{slug};
        } else {
            if(my $obj = $self->model('wot-replays.data.maps')->find_one({ numerical_id => $replay->{game}->{map} })) {
                return $obj->{slug};
            } else {
                return sprintf('404:%s', $replay->{game}->{map});
            }
        }
    });

    $self->helper(map_image => sub {
        my $self = shift;
        my $size = shift;
        my $id   = shift;
        if(my $map = $self->db('wot-replays.data.maps')->find_one({ _id => $id })) {
            return lc(sprintf('//images.wotreplays.org/maps/%d/%s.png', $size, $id));
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

    $self->helper(crit_component_name => sub {
        return shift->app->wr_res->components->i18n(shift);
    });

    $self->helper(crit_tankman_name => sub {
        return shift->app->wr_res->tankman->i18n(shift);
    });

    $self->helper(short_game_type => sub {
        my $self = shift;
        my $gametype = shift;

        my $long = $self->game_type_name($gametype);
        return lc(substr($long, 0, 3));
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
    $self->helper(wn7_color => sub {
        my $self = shift;
        my $rating = shift;
        my $class_map = [
            [ 1, 499, 'verybad' ],
            [ 500, 699, 'bad' ],
            [ 700, 899, 'belowaverage' ],
            [ 900, 1099, 'average' ],
            [ 1100, 1349, 'good' ],
            [ 1350, 1499, 'verygood' ],
            [ 1500, 1699, 'great' ],
            [ 1700, 1999, 'unicum' ],
            [ 2000, 99999, 'superunicum' ]
        ];
        foreach my $entry (@$class_map) {
            return $entry->[2] if($rating >= $entry->[0] && $rating <= $entry->[1]);
        }
        return 'unavailable';
    });

    # i18n helpers 
    $self->helper(loc_short => sub {
        my $self = shift;
        my $str  = shift;

        # append /short to the string
        return $self->loc(sprintf('%s/short', $str), @_);
    });

    $self->helper(loc_desc => sub {
        my $self = shift;
        my $str  = shift;

        # append /desc to the string
        return $self->loc(sprintf('%s/desc', $str), @_);
    });

    $self->helper(loc => sub {
        my $self = shift;
        my $str  = shift;
        my @args = (@_);
        my $l    = 'site';  # default localizer "language"

        # find out if the string is a WoT style userString
        if($str =~ /^#(.*?):(.*)/) {
            $l   = $1;
            $str = $2;
        }

        if(my $localizer = $self->stash('i18n_localizer')) {
            if(my $xlat = $localizer->localize_for(lang => $l, id => $str, args => \@args)) {
                return $xlat;
            } else {
                return $str;
            }
        } else {
            return $str;
        }
    });
}

1;

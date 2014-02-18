package WR::App::Helpers;
use strict;
use warnings;
use WR::Query;
use WR::Res;
use WR::Util::CritDetails;
use WR::Provider::ServerFinder;
use WR::Localize::Formatter;
use File::Slurp qw/read_file/;
use WR::Constants qw/nation_id_to_name gameplay_id_to_name/;
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;
use Data::Dumper;
use DateTime;
use Mojo::Util qw/encode decode/;
use Try::Tiny qw/try catch/;

use constant ROMAN_NUMERALS => [qw(0 I II III IV V VI VII VIII IX X)];

# this module is basically a collection of miscellaneous junk that's been slopped in
# over time, some of it isn't used anymore, some of it is, some of it leaks memory,
# most of it is butt-ugly. 
#
# beware. dragons, and such.


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
                value => $obj->{i18n},
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

    $self->helper(debug => sub {
        my $self = shift;
        my $msg = join(' ', @_);

        $self->app->log->debug($msg);
    });

    $self->helper(error => sub {
        my $self = shift;
        my $msg = join(' ', @_);

        $self->app->log->error($msg);
    });

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
            my $c = $a->{ammo};
            return sprintf('%s %dmm %s %s', 
                sprintf('%d x', $a->{count}),
                $c->{caliber}, 
                $kind_map->{$c->{kind}},
                (defined($c->{i18n})) ? $self->loc($c->{i18n}) : $c->{label},
                );
        } else {
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
        return WR::Query->new(@_, coll => $self->model('wot-replays.replays'), log => $self->app->log, user => $self->current_user);
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

    $self->helper('usertime' => sub {
        my $self = shift;
        my $fmt  = shift;
        my $time = shift;

        return $self->strftime($fmt, $time) unless($self->is_user_authenticated);
        my $dt = DateTime->from_epoch(epoch => $time / 1000, time_zone => $self->current_user->{settings}->{timezone} || 'UTC');
        return $dt->strftime($fmt);
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

        if($version =~ /^\d+$/) {
            # new style numeric version
            return $self->wot_version_numeric_to_string($version);

        } else {
            # old style version, we want to ensure we split this properly for temporary 0.8.11 ones
            return $self->wot_version_numeric_to_string($self->wot_version_string_to_numeric($version));
        }
    });

    $self->helper(wot_version_string_to_numeric => sub {
        my $self = shift;
        my $v    = shift;

        my @ver = split(/\,/, $v);
        my @wgfix = ();
        while(@ver) {
            my $a = shift(@ver);
            $a =~ s/^\s+//g;
            $a =~ s/\s+$//g; # ffffuck
            if($a =~ /\s+/) {
                push(@wgfix, (split(/\s+/, $a)));
            } else {
                push(@wgfix, $a);
            }
        }

        return $wgfix[0] * 1000000 + $wgfix[1] * 10000 + $wgfix[2] * 100 + $wgfix[3];
    });

    $self->helper(wot_version_numeric_to_string => sub {
        my $self = shift;
        my $v    = shift;
        my @ver  = ();

        push(@ver, int($v / 1000000));
        $v -= $ver[-1] * 1000000;
        push(@ver, int($v / 10000));
        $v -= $ver[-1] * 10000;
        push(@ver, int($v / 100));
        $v -= $ver[-1] * 100;
        push(@ver, $v);

        return sprintf('%d.%d.%d', (@ver[0..3]));
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

    $self->helper(get_replay_stats => sub {
        my $self = shift;
        my $r = shift;
        my $field = shift;

        return $r->{stats}->{$field};
    });

    $self->helper(is_old_version => sub {
        my $self = shift;
        my $version = shift;

        if($version !~ /^\d+$/) {
            # new style numeric version
            $version = $self->wot_version_string_to_numeric($version);
        }

        my $v = ($version < $self->config->{wot}->{version_numeric}) ? 1 : 0;
        return $v;
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

        return 1 if($self->is_the_boss);

        if(!defined($r)) {
            $r = $u;
            $u = $self->current_user;
        }

        return 0 unless(defined($u));
        return 0 unless(defined($u->{roles}));

        foreach my $role (@{$u->{roles}}) {
            $self->debug('has_role check ', $role, ' against ', $r);
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
            return $self->loc($a->{i18n});
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
                label => $o->{label},
                i18n => $o->{i18n}
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
            return $self->loc(sprintf('#arenas:%s/name', $replay->{game}->{map_extra}->{ident}));
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
            if(defined($obj->{i18n})) {
                return $self->loc($obj->{i18n});
            } else {
                return $obj->{label};
            }
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
            return $self->loc($obj->{i18n});
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

        $self->debug('percentage_of: a: ', $a, ' b: ', $b);

        $self->debug('return 0') and return '0' unless(($a > 0) && ($b > 0));

        my $v = sprintf('%.0f', 100/($a/$b));
        $self->debug('returning: ', $v);
        return $v;
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

    $self->helper(short_game_type => sub {
        my $self = shift;
        my $gametype = shift;

        my $long = $self->game_type_name($gametype);
        return lc(substr($long, 0, 3));
    });

    $self->helper('achievement_name' => sub {
        my $self = shift;
        my $str  = shift;

        return $self->loc(sprintf('#achievements:%s', $str));
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

    $self->helper(rating_color => sub {
        my $self = shift;
        my $type = shift;
        my $rating = shift;

        my $func = sprintf('%s_color', $type);
        return $self->$func($rating);
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

    $self->helper(wn8_color => sub {
        my $self = shift;
        my $rating = shift;
        my $class_map = [
            [ 1, 300, 'verybad' ],
            [ 300, 599, 'bad' ],
            [ 600, 899, 'belowaverage' ],
            [ 900, 1249, 'average' ],
            [ 1250, 1599, 'good' ],
            [ 1600, 1899, 'verygood' ],
            [ 1900, 2349, 'great' ],
            [ 2350, 2899, 'unicum' ],
            [ 2900, 99999, 'superunicum' ]
        ];
        foreach my $entry (@$class_map) {
            return $entry->[2] if($rating >= $entry->[0] && $rating <= $entry->[1]);
        }
        return 'unavailable';
    });

    $self->helper(rating_status => sub {
        my $self   = shift;
        my $rating = shift;

        # an undefined rating or a rating < 1 is probably due to a failure in fetching the
        # rating, so we also return undef and don't show the chiclets; 
        # returned is the class name 

        return undef if(!defined($rating) || (defined($rating) && $rating == 0));
        return 'above' if($rating >= 1250);
        return 'below' if($rating < 900);
        return 'equal';
    });

    $self->helper('defined_count' => sub {
        my $self = shift;
        my $a    = shift;
        my $c    = 0;

        return 0 unless(defined($a));

        foreach my $e (@$a) {
            $c++ if(defined($e));
        }
        return $c;
    });

    $self->helper('get_camo_by_id' => sub {
        my $self    = shift;
        my $country = shift;
        my $id      = shift;

        my $_id = sprintf('camo-%s-%d', $country, $id);

        if(my $camo = $self->model('wot-replays.data.customization')->find_one({ _id => $_id })) {
            return $camo;
        } else {
            return undef;
        }
    });

    $self->helper('get_emblem_by_id' => sub {
        my $self    = shift;
        my $id      = shift;

        if(my $emblem = $self->model('wot-replays.data.customization')->find_one({ wot_id => $id, type => 'emblem' })) {
            return $emblem;
        } else {
            return undef;
        }
    });

    $self->helper('get_oid' => sub {
        my $self = shift;
        my $oid = Mango::BSON::bson_oid;
        return $oid . '';
    });

    $self->helper('get_inscription_by_id' => sub {
        my $self    = shift;
        my $country = shift;
        my $id      = shift;
    
        my $_id = sprintf('inscription-%s-%d', $country, $id);

        if(my $i = $self->model('wot-replays.data.customization')->find_one({ _id => $_id })) {
            return $i;
        } else {
            return undef;
        }
    });
   
    $self->helper('make_args' => sub {
        my $self = shift;
        my $args = shift || [];
        my $res  = [];

        foreach my $a (@$args) {
            if($a =~ /l:(.*?):(.*)/) {
                my $root = $1;
                my $key  = $2;

                push(@$res, $self->loc(sprintf('%s.%s', $root, $self->stash($key))));
            } elsif($a =~ /^d:(.*?):(.*?):(.*?):(.*)/) {
                my $coll = $1;
                my $field = $2;
                my $_v   = $3;
                my $val = $self->stash($_v);
                my $rfield = $4;
                # here's the issue we'll have, this is all blocking... 
                warn 'make_args: d: coll: ', $coll, ' field: ', $field, ' val: ', $val, ' rfield: ', $rfield, "\n";
                if(my $r = $self->model(sprintf('wot-replays.%s', $coll))->find_one({ $field => $val })) {
                    push(@$res, $self->loc($r->{$rfield}));
                } else {
                    push(@$res, 'd:failed');
                }
            } else {
                push(@$res, $self->stash($a));
            }
        }
        return $res;
    });

    $self->helper(time_diff => sub {
        my $self = shift;
        my $then = shift;
        my $now  = Mango::BSON::bson_time;

        return sprintf('%.2f', ($now - $then) / 1000);
    });

    $self->helper(nonce => sub {
        return Mango::BSON::bson_time;
    });

    $self->helper('parse_message' => sub {
        my $self = shift;
        my $m    = shift;

        # here's the deal, when mods are involved, this may or may not come out hideously fucked, so we want to use some dom magic here
        my $dom = Mojo::DOM->new($m);

        my @parts = ();
        my $base_color = $dom->find('font')->first->attr('color');
        $dom->children->each(sub {
            push(@parts, shift->text);
        });

        my $name    = shift(@parts);
        my $message = shift(@parts);

        $name =~ s/://g;

        my $n = {};

        if($name =~ /(.*)\[(.*)\]\s+\((.*)\)/) {
            $n = { name => $1, clan => $2, vehicle => $3 };
        } elsif($name =~ /(.*)\s+\((.*)\)/) {
            $n = { name => $1, clan => undef, vehicle => $2 };
        } else {
            $n = { name => $name, clan => undef, vehicle => undef };
        }

        # yurk
        $n->{vehicle} = decode('UTF-8', $n->{vehicle}) if(defined($n->{vehicle}));
        return { base => $base_color, name => $n, message => $message };
    });

    $self->helper(i18n_attr => sub {
        my $self = shift;
        my $val  = shift;

        return sprintf(q|data-i18n-attr='%s'|, $self->as_json($val));
    });

    $self->helper('is_translator_for' => sub {
        my $self = shift;
        my $lang = shift;

        return 0 unless($self->is_user_authenticated);
        return 0 unless($self->has_admin_access);
        return 0 unless($self->has_admin_role('language'));

        my $r = 0;
        try {
            my $allowed = $self->current_user->{admin}->{languages}->{allowed};
            foreach my $l (@$allowed) {
                if($l eq $lang) {
                    $r = 1;
                    last;
                }
            }
        } catch {
            $r = 0;
        };
        return $r;
    });

}

1;

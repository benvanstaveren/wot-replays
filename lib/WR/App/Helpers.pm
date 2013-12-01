package WR::App::Helpers;
use strict;
use warnings;
use WR::Query;
use WR::Res;
use WR::Util::CritDetails;
use WR::Provider::ServerFinder;
use WR::Constants qw/nation_id_to_name/;
use WR::Util::TypeComp qw/parse_int_compact_descr/;
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

    $self->attr(_sf => sub { WR::Provider::ServerFinder->new });

    $self->helper(resolve_server_by_playerid => sub {
        my $self = shift;
        my $id   = shift;

        return $self->app->_sf->get_server_by_id($id + 0);
    });

    $self->helper(browse_page => sub {
        my $self = shift;
        my $p    = shift;

        my $f = $self->stash('browse_filter_raw');
        $f->{p} = $p;

        my @a = ();
        
        foreach my $key (sort { $a cmp $b } (keys(%$f))) {
            push(@a, $key, $f->{$key});
        }

        return join('/', @a);
    });

    $self->helper(wot_version => sub {
        my $self = shift;
        my $replay = shift;

        my @parts = split(/, /, $replay->{game}->{version});
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

        if($self->stash('config')->{wot}->{version_numeric} != $r->{game}->{version_numeric}) {
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

    $self->helper(wr_query => sub {
        my $self = shift;
        return WR::Query->new(@_, coll => $self->model('wot-replays.replays'), log => $self->app->log);
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

        return $self->app->json->encode($v);
    });

    $self->helper('clear_replay_page' => sub {
        my $self = shift;
        my $id   = shift;

        my $filename = sprintf('%s/%s.html', $self->stash('config')->{paths}->{pages}, $id);
        unlink($filename);
    });

    $self->helper(get_id => sub { return $_[1]->{_id} });
    $self->helper(res => sub { return shift->app->wr_res });

    $self->helper(generate_vehicle_select => \&generate_vehicle_select);

    $self->helper(consumable_icon_style => sub {
        my $self = shift;
        my $a = shift;

        return undef unless(defined($a));
        my $tc = parse_int_compact_descr($a);
        my $i = $tc->{id};
        if(my $c = $self->model('wot-replays.data.consumables')->find_one({ wot_id => $i + 0 })) {
            return sprintf('style="background: transparent url(http://images.wotreplays.org/consumables/24x24/%s) no-repeat scroll 0 0"', $c->{icon});
        } else {
            return undef;
        }
    });

    $self->helper(ammo_icon_style => sub {
        my $self = shift;
        my $a = shift;

        return undef unless(defined($a) && ref($a) eq 'HASH');
        my $i = $a->{id};
        if(my $c = $self->model('wot-replays.data.components')->find_one({ component => 'shells', _id => $i + 0 })) {
            my $n = ($a->{count} > 0) ? $c->{kind} : sprintf('NO_%s', $c->{kind});
            return sprintf('style="background: transparent url(http://images.wotreplays.org/ammo/24x24/%s.png) no-repeat scroll 0 0"', $n);
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

        return undef unless(defined($a) && ref($a) eq 'HASH');
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
    });

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
        my $tc = parse_int_compact_descr($a);
        if(my $c = $self->model('wot-replays.data.consumables')->find_one({ wot_id => $tc->{id} + 0 })) {
            return $c->{label} || $c->{name};
        } else {
            return sprintf('404:%d', $a);
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
        my $self = shift;
        my $mid  = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ 
            '$or' => [
                { _id => $mid },
                { numerical_id => $mid },
                { name_id => $mid },
                { slug => $mid },
            ],
        })) {
            return $obj->{icon};
        } else {
            return sprintf('404:%s', $mid);
        }
    });

    $self->helper(map_boundingbox => sub {
        my $self = shift;
        my $mid  = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ 
            '$or' => [
                { _id => $mid },
                { numerical_id => $mid },
                { name_id => $mid },
                { slug => $mid },
            ],
        })) {
            return [ $obj->{attributes}->{geometry}->{bottom_left}, $obj->{attributes}->{geometry}->{upper_right} ];
        } else {
            return undef;
        }
    });

    $self->helper(vehicle_link => sub {
        my $self = shift;
        my $ident = shift;

        $ident =~ s/:/\//g;
        return $ident;
    });

    $self->helper(map_numericid => sub {
        my $self = shift;
        my $mid = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ 
            '$or' => [
                { _id => $mid },
                { numerical_id => $mid },
                { name_id => $mid },
                { slug => $mid },
            ],
        })) {
            return $obj->{numerical_id} + 0;
        } else {
            return 0;
        }
    });

    $self->helper(map_ident => sub {
        my $self = shift;
        my $mid = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ 
            '$or' => [
                { _id => $mid },
                { numerical_id => $mid },
                { name_id => $mid },
                { slug => $mid },
            ],
        })) {
            return $obj->{_id};
        } else {
            return sprintf('404:%s', $mid);
        }
    });

    $self->helper(map_name => sub {
        my $self = shift;
        my $mid = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ 
            '$or' => [
                { _id => $mid },
                { numerical_id => $mid },
                { name_id => $mid },
                { slug => $mid },
            ],
        })) {
            return $obj->{label};
        } else {
            return sprintf('404:%s', $mid);
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

    $self->helper(model_for_replay => sub {
        my $self = shift;
        my $r    = shift || $self->stash('req_replay');
        my $v    = $r->{version};

        return ($self->stash('config')->{wot}->{version} eq $v)
            ? 'wot-replays.replays'
            : sprintf('wot-replays.replays.%s', $v);
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
        return ($self->is_user_authenticated && ($self->current_user->{player_name} eq 'Scrambled' && $self->current_user->{player_server} eq 'sea')) ? 1 : 0
    });

    $self->helper(user => sub {
        return shift->current_user;
    });

    $self->helper(map_slug => sub {
        my $self = shift;
        my $mid = shift;

        if(my $obj = $self->model('wot-replays.data.maps')->find_one({ 
            '$or' => [
                { _id => $mid },
                { numerical_id => $mid },
                { name_id => $mid },
                { slug => $mid },
            ],
        })) {
            return $obj->{slug};
        } else {
            return undef;
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
}

1;

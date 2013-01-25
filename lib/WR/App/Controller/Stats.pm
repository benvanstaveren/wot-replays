package WR::App::Controller::Stats;
use Mojo::Base 'WR::App::Controller';
use boolean;
use WR::MR;

sub index {
    my $self = shift;
    my $graphdata = {};

    $self->respond(
        template => 'stats/index',
        stash => {
            page => { title => 'Statistics' },
            graphdata => $graphdata
        },
    );
}

sub view {
    my $self = shift;
    my $statid = $self->stash('statid');

    my $m = sprintf('stats_%s', $statid);
    my $graphdata = ($self->can($m)) ? $self->$m() : {};
    $self->respond(
        template => sprintf('stats/%s', $statid),
        stash => {
            page => { title => 'Statistics' },
            graphdata => $graphdata,
        }
    );
}

sub stats_cluster {
    return {}
}

sub stats_vehicle {
    return {}
}

sub stats_map {
    return {} 
}

sub stats_global {
    my $self = shift;
    my $graphdata = {};
    my $refresh = 0;

    if(my $last = $self->model('wot-replays.stats.times')->find_one({ _id => 'global' })) {
        $refresh = 1 if($last->{last} + 3600 < time());
    } else {
        $refresh = 1;
    }

    if($refresh == 1) {
        for(qw/bybonustype byclass bycountry bygametype bytier byserver/) {
            my $folder = sprintf('%s/stats_%s', $self->app->home->rel_dir('etc/mr'), $_);
            my $out    = sprintf('stats.%s', $_);
            my $mr     = WR::MR->new(db => $self->db('wot-replays'), folder => $folder);
            $mr->execute('replays' => $out);
            $graphdata->{$_} = [ $self->model(sprintf('wot-replays.%s', $out))->find()->all() ];
        }

        $self->model('wot-replays.stats.times')->update({ _id => 'global' }, {
            '$set' => { last => time() }
        }, { upsert => 1 });
    } else {
        for(qw/bybonustype byclass bycountry bygametype bytier byserver/) {
            $graphdata->{$_} = [ $self->model(sprintf('wot-replays.stats.%s', $_))->find()->all() ];
        }
    }
    return $graphdata;
}


1;

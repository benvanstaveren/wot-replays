package WR::App::Controller::Stats;
use Mojo::Base 'WR::App::Controller';
use boolean;

sub index {
    my $self = shift;
    my $graphdata = {};

    for(qw/bybonustype byclass bycountry bygametype bytier byversion/) {
        $graphdata->{$_} = [ $self->db('wot-replays')->get_collection(sprintf('stats.%s', $_))->find()->all() ];
    }

    $self->respond(
        template => 'stats/index',
        stash => {
            page => { title => 'Statistics' },
            graphdata => $graphdata
        },
    );
}

1;

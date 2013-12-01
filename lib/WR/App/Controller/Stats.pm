package WR::App::Controller::Stats;
use Mojo::Base 'WR::App::Controller';

sub index {
    shift->respond(template => 'stats/index', stash => { page => { title => 'Statistics' } });
}

1;

package WR::Process::Player;
use Mojo::Base '-base';

use constant LEFT => 0;
use constant RIGHT => 1;

use constant DAMAGED => 1;
use constant DESTROYED => 2;
use constant OK => 0;

has 'name'              => undef;
has 'health'            => 0;
has 'events'            => sub { [] };
has 'track_state'       => sub { [ 0, 0 ] };
has 'last_shot_by'      => undef;
has 'clock'             => undef;
has 'last_destroyed_track' => undef;

1;

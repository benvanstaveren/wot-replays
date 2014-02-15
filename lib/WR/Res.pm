package WR::Res;
use Mojo::Base '-base';

use WR::Res::Achievements;

has 'achievements'  =>  sub { WR::Res::Achievements->new() };

1;

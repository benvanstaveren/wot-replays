package WR::Res;
use Mojo::Base '-base';

use WR::Res::Achievements;
use WR::Res::Bonustype;
use WR::Res::Country;
use WR::Res::Gametype;
use WR::Res::Servers;
use WR::Res::Vehicleclass;

has 'achievements'  =>  sub { WR::Res::Achievements->new() };
has 'bonustype'     =>  sub { WR::Res::Bonustype->new() };
has 'country'       =>  sub { WR::Res::Country->new() };
has 'gametype'      =>  sub { WR::Res::Gametype->new() };
has 'servers'       =>  sub { WR::Res::Servers->new() };
has 'vehicleclass'  =>  sub { WR::Res::Vehicleclass->new() };

1;

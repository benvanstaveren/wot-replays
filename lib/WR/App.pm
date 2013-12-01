package WR::App;
use Mojo::Base 'Mojolicious';
use Mojo::JSON;
use Mango;

# this is a bit cheesy but... 
use FindBin;
use lib "$FindBin::Bin/../lib";

use WR;
use WR::Query;
use WR::Res;
use WR::Renderer;
use WR::App::Helpers;

use Time::HiRes qw/gettimeofday/;

$Template::Stash::PRIVATE = undef;

# This method will run once at server start
sub startup {
    my $self = shift;
    
    $self->attr(json => sub { return Mojo::JSON->new() });

    my $config = $self->plugin('Config', { file => 'wr.conf' });

    $self->secret($config->{secrets}->{app});
    $config->{wot}->{bf_key} = join('', map { chr(hex($_)) } (split(/\s/, $config->{wot}->{bf_key})));

    # set up the mango stuff here
    $self->attr(mango => sub { Mango->new($config->{mongodb}->{host}) });
    $self->helper(model => sub {
        my $s = shift;
        my ($d, $c) = split(/\./, shift, 2);

        unless(defined($c)) {
            $c = $d ;
            $d = $config->{mongodb}->{database};
        }

        return $s->app->mango->db($d)->collection($c);
    });

    $self->routes->namespaces([qw/WR::App::Controller/]);

    my $r = $self->routes->bridge('/')->to('auto#index');

    $r->route('/')->to('ui#index', pageid => 'home');

    $r->route('/browse/*filter')->to('replays#browse');
    $r->route('/browse')->to(cb => sub {
        my $self = shift;
        $self->stash('browse_filter_raw' => {
            p => 1,
            vehiclepov => 1,
            vehicleinv => 0,
            tier_min => 1,
            tier_max => 10,
            vehicle => '*',
            map => '*',
            server => '*',
            matchmode => '*',
            matchtype => '*',
            sort => 'upload',
        });
        $self->redirect_to(sprintf('/browse/%s', $self->browse_page(1)));
    });
    $r->route('/about')->to('ui#about', pageid => 'about');
    $r->route('/donate')->to('ui#donate', pageid => 'donate');
    $r->route('/credits')->to('ui#credits', pageid => 'credits');
    $r->route('/upload')->to('replays-upload#upload', pageid => 'upload');

    $r->route('/process/:jobid')->to('replays-upload#process_replay', pageid => 'upload');

    my $xhr = $r->under('/xhr');
        $xhr->route('/qs')->to('ui#xhr_qs');

    my $rb = $r->under('/replay/:replay_id');
        $rb->route('/')->to('replays-view#view', pageid => undef)->name('viewreplay');
        $rb->route('/desc')->to('replays#desc', pageid => undef);
        $rb->route('/download')->to('replays-export#download', pageid => undef);
        $rb->route('/csv')->to('replays-export#csv', pageid => undef);
        $rb->route('/up')->to('replays-rate#rate_up', pageid => undef);
        $rb->route('/stats')->to('replays-view#stats', pageid => undef);
        $rb->route('/incview')->to('replays-view#incview', pageid => undef);
        $rb->route('/comparison')->to('replays-view#comparison', pageid => undef);
        $rb->route('/packets')->to('replays-view#packets', pageid => undef);

    $r->route('/players')->to('player#index', pageid => 'player');
    my $playerbridge = $r->bridge('/player/:server/:player_name')->to('player#player_bridge');
        $playerbridge->route('/')->to('player#view', pageid => 'player');
        $playerbridge->route('/involved')->to('player#involved', pageid => 'player');
        $playerbridge->route('/latest')->to('player#latest', pageid => 'player');

    my $vehicles = $r->under('/vehicles');
        $vehicles->route('/:country')->to('vehicle#index', pageid => 'vehicle');

    my $vehicle = $r->under('/vehicle');
        $vehicle->route('/:country/:vehicle')->to('vehicle#view', pageid => 'vehicle');

    $r->route('/maps')->to('map#index', pageid => 'map');
    my $map = $r->under('/map');
        $map->route('/:map_id')->to('map#view', pageid => 'map');

    $r->any('/login')->to('ui#do_login', pageid => 'login');
    $r->any('/logout')->to('ui#do_logout');

    my $openid = $r->under('/openid');
        $openid->any('/return')->to('ui#openid_return');

    my $pb = $r->bridge('/profile')->to('profile#check');
        $pb->route('/replays/type/:type/page/:page')->to('profile#replays', pageid => 'profile');

        my $pbj = $pb->under('/j');
            $pbj->route('/sr')->to('profile#sr', pageid => 'profile');
            $pbj->route('/hr')->to('profile#hr', pageid => 'profile');

    $self->sessions->default_expiration(86400 * 365); 
    $self->sessions->cookie_name('wrsession');
    $self->sessions->cookie_domain($config->{urls}->{app_c}) if(!defined($config->{mode}) || $config->{mode} ne 'dev');

    has 'wr_res' => sub { return WR::Res->new() };

    WR::App::Helpers->add_helpers($self);

    # in order to mess around with our template paths we need to:
    $self->renderer->paths([]); # clear this out

    my $tt = WR::Renderer->build(
        mojo => $self,
        template_options => {
            COMPILE_DIR  => undef,
            COMPILE_EXT  => undef,
            PRE_CHOMP    => 0,
            POST_CHOMP   => 1,
            TRIM => 1,
            FILTERS => {
                'js' =>  sub {
                    my $text = shift;
                    $text =~ s/\'/\\\'/gi;
                    return $text;
                },
                'tabtospan' =>  sub {
                    my $text = shift;
                    $text =~ s/\\t/<br\/><span style="margin-left: 20px"><\/span>/g;
                    return $text;
                },
            },
            RELATIVE => 1,
            ABSOLUTE => 1, # otherwise hypnotoad gets a bit cranky, for some reason
            INCLUDE_PATH => [ $self->app->home->rel_dir('templates') ],
        },
    );
    $self->types->type(csv => 'text/csv; charset=utf-8');
    $self->renderer->add_handler(tt => $tt);
    $self->renderer->default_handler('tt');
}

1;

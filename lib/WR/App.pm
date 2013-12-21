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
    $self->helper(get_database => sub {
        my $s = shift;
        my $d = $config->{mongodb}->{database};
        return $s->app->mango->db($d);
    });
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


    $r->route('/browse/*filter')->to('replays#browse', filter_opts => {}, pageid => 'browse', page => { title => 'browse.page.title' }, filter_root => 'browse');
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

    # these are all simple pages
    for(qw/about donate credits/) {
        $r->route(sprintf('/%s', $_))->to(sprintf('ui#%s', $_), pageid => $_);
    }

    # funky bits
    $r->route('/upload')->to('replays-upload#upload', pageid => 'upload');
    $r->route('/postaction')->to('ui#nginx_post_action');

    my $xhr = $r->under('/xhr');
        $xhr->route('/qs')->to('ui#xhr_qs');
        $xhr->route('/ds')->to('ui#xhr_ds');
        $xhr->route('/du')->to('ui#xhr_du');

    my $bv = $r->under('/battleviewer/:replay_id');
        $bv->route('/')->to('replays-view#battleviewer', pageid => 'battleviewer');

    my $rb = $r->under('/replay/:replay_id');
        $rb->route('/')->to('replays-view#view', pageid => undef)->name('viewreplay');
        $rb->route('/desc')->to('replays#desc', pageid => undef);
        $rb->route('/download')->to('replays-export#download', pageid => undef);
        $rb->route('/packets')->to('replays-view#packets', pageid => undef);
        $rb->route('/up')->to('replays-rate#rate_up', pageid => undef);
        $rb->route('/comparison')->to('replays-view#comparison', pageid => undef);

    $r->route('/players')->to('player#index', pageid => 'player');
    my $player = $r->under('/player');
        $player->route('/:server/:player_name')->to(cb => sub {
            my $self = shift;
            $self->stash('browse_filter_raw' => {
                p => 1,
                vehiclepov => 1,
                map => '*',
                server => '*',
                matchmode => '*',
                matchtype => '*',
                sort => 'upload',
                playerpov => 1, 
                playerinv => 0,
            });
            $self->redirect_to(sprintf('/player/%s/%s/%s', $self->stash('server'), $self->stash('player_name'), $self->browse_page(1)));
        }, pageid => 'player');
        $player->route('/:server/:player_name/latest')->to('player#latest', pageid => 'player');
        $player->route('/:server/:player_name/*filter')->to('replays#browse',
            page => {
                title => 'player.page.title',
            },
            pageid => 'player',
            filter_opts => {
                base_query => sub {
                    my $self = shift;
                    return { 'player' => $self->stash('player_name'), 'server' => $self->stash('server') };
                },
                filter_root => sub {
                    my $self = shift;
                    return sprintf('player/%s/%s', $self->stash('server'), $self->stash('player_name'));
                }
            }
        );


    my $vehicles = $r->under('/vehicles');
        $vehicles->route('/:country')->to('vehicle#index', pageid => 'vehicle');

    my $vehicle = $r->under('/vehicle');
        $vehicle->route('/:country/:vehicle')->to(cb => sub {
            my $self = shift;
            $self->stash('browse_filter_raw' => {
                p => 1,
                vehiclepov => 1,
                map => '*',
                server => '*',
                matchmode => '*',
                matchtype => '*',
                sort => 'upload',
            });
            $self->redirect_to(sprintf('/vehicle/%s/%s/%s', $self->stash('country'), $self->stash('vehicle'), $self->browse_page(1)));
        }, pageid => 'vehicle');
        $vehicle->route('/:country/:vehicle/*filter')->to('replays#browse', 
            page => {
                title => 'vehicle.page.title',
            },
            pageid => 'vehicle',
            filter_opts => {
                base_query => sub {
                    my $self = shift;
                    return { 'vehicle' => sprintf('%s:%s', $self->stash('country'), $self->stash('vehicle')) };
                },
                filter_root => sub {
                    my $self = shift;
                    return sprintf('vehicle/%s/%s', $self->stash('country'), $self->stash('vehicle'));
                }
            }
        );


    $r->route('/maps')->to('map#index', pageid => 'map');

    my $heatmaps = $r->under('/heatmaps');
        $heatmaps->route('/:map_ident')->to('heatmap#view');

    my $map = $r->under('/map');
        $map->route('/:map_id')->to(cb => sub {
            my $self = shift;
            $self->stash('browse_filter_raw' => {
                p => 1,
                vehiclepov => 1,
                tier_min => 1,
                tier_max => 10,
                vehicle => '*',
                server => '*',
                matchmode => '*',
                matchtype => '*',
                sort => 'upload',
            });
            $self->redirect_to(sprintf('/map/%s/%s', $self->stash('map_id'), $self->browse_page(1)));
        }, pageid => 'map');
        $map->route('/:map_id/*filter')->to('replays#browse', 
            page => {
                title => 'map.page.title',
            },
            pageid => 'map',
            filter_opts => {
                async      => 1,
                base_query => sub {
                    my $self = shift;
                    my $cb   = shift;
                    my $slug = $self->stash('map_id');

                    $self->model('wot-replays.data.maps')->find_one({ slug => $slug } => sub {
                        my ($coll, $err, $doc) = (@_);

                        warn 'gonna return ', $doc->{numerical_id}, ' from: ', $slug, "\n";
                        $cb->({ map => $doc->{numerical_id }});
                    });
                },
                filter_root => sub {
                    my $self = shift;
                    return sprintf('map/%s', $self->stash('map_id'));
                }
            }
        );

    my $login = $r->under('/login');
        $login->route('/')->to('ui#do_login', pageid => 'login');
        $login->route('/:s')->to('ui#do_login', pageid => 'login');

    $r->route('/logout')->to('ui#do_logout');

    my $openid = $r->under('/openid');
        $openid->any('/return')->to('ui#openid_return');

    my $pb = $r->bridge('/profile')->to('profile#check');
        $pb->route('/replays/type/:type/page/:page')->to('profile#replays', pageid => 'profile');
        $pb->route('/uploads/page/:page')->to('profile#uploads', pageid => 'profile');

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
            COMPILE_DIR  => $self->app->home->rel_dir('tmp/tmplc'),
            COMPILE_EXT  => '.compiled',
        },
    );
    $self->types->type(csv => 'text/csv; charset=utf-8');
    $self->renderer->add_handler(tt => $tt);
    $self->renderer->default_handler('tt');
}

1;

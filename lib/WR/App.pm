package WR::App;
use Mojo::Base 'Mojolicious';

# this is a bit cheesy but... 
use FindBin;
use lib "$FindBin::Bin/../lib";

use WR;
use WR::Query;
use WR::Res;

use Time::HiRes qw/gettimeofday/;

$Template::Stash::PRIVATE = undef;

# This method will run once at server start
sub startup {
    my $self = shift;
    
    $self->secret(q|a superbly secret secret that nobody will ever guess in their entire damn life|);

    my $config = $self->plugin('Config', { file => 'wr.conf' });
    $self->plugin('mongodb', { host => $config->{mongodb}, patch_mongodb => 1 });
    $self->plugin('tt_renderer', { template_options => {
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
    }});

    # set up the key string
    $config->{wot}->{bf_key} = join('', map { chr(hex($_)) } (split(/\s/, $config->{wot}->{bf_key})));

    # add some helpers here because we need to 
    # "fake" some of it
    $self->helper(is_user_authenticated => sub {
        my $ctrl = shift;

        if(my $openid = $ctrl->session('openid')) {
            if(my $user = $ctrl->model('wot-replays.accounts')->find_one({ openid => $openid })) {
                return 1;
            } else {
                return 0; # because the verification step will actually create it
            }
        } else {
            return 0;
        }
    });

    $self->helper(current_user => sub {
        my $ctrl = shift;
        if(my $openid = $ctrl->session('openid')) {
            if(my $user = $ctrl->model('wot-replays.accounts')->find_one({ openid => $openid })) {
                return $user;
            } else {
                return undef;
            }
        }
        return undef;
    });

    $self->routes->namespaces([qw/WR::App::Controller/]);

    my $r = $self->routes->bridge('/')->to('auto#index');

    $r->route('/')->to('ui#index', pageid => 'home');

    $r->route('/browse')->to('replays#browse', pageid => 'browse');
    $r->route('/faq')->to('ui#faq', pageid => 'faq');
    $r->route('/donate')->to('ui#donate', pageid => 'donate');
    $r->route('/about')->to('ui#about', pageid => 'about');
    $r->route('/credits')->to('ui#credits', pageid => 'credits');

    $r->route('/upload')->to('replays-upload#upload', pageid => 'upload');

    $r->route('/download/:replay_id')->to('replays-export#download');

    my $dlg = $r->under('/dlg');
        $dlg->route('/achievement/:achievement')->to('ui#dlg_achievement');

    $r->route('/replay/browse')->to('replays#browse');

    my $rb = $r->bridge('/replay/:replay_id')->to('replays#bridge');
        $rb->route('/')->to('replays-view#view', pageid => undef)->name('viewreplay');
        $rb->route('/desc')->to('replays#desc', pageid => undef);
        $rb->route('/up')->to('replays-rate#rate_up', pageid => undef);
        $rb->route('/stats')->to('replays-view#stats', pageid => undef);
        $rb->route('/incview')->to('replays-view#incview', pageid => undef);
        $rb->route('/comparison')->to('replays-view#comparison', pageid => undef);

    $r->route('/players/:server')->to('player#index', pageid => 'player', server => 'any');

    $r->route('/player/:server/:player_name/involved')->to('player#involved', pageid => 'player');
    $r->route('/player/:server/:player_name')->to('player#view', pageid => 'player');
    $r->route('/player/:player_name')->to('player#ambi', pageid => 'player');

    $r->route('/clans')->to('clan#index', pageid => 'clan');

    $r->route('/vehicles')->to('vehicle#index', pageid => 'vehicle');
    $r->route('/vehicle/:country/:vehicle')->to('vehicle#view', pageid => 'vehicle');

    $r->route('/maps')->to('map#index', pageid => 'map');
    $r->route('/map/:map_id')->to('map#view', pageid => 'map');

    $r->route('/tournaments')->to('tournament#index', pageid => 'tournament');

    $r->route('/register')->to('ui#register', pageid => 'register');

    $r->any('/login')->to('ui#do_login', pageid => 'login');
    $r->any('/logout')->to('ui#do_logout');

    my $openid = $r->under('/openid');
        $openid->any('/return')->to('ui#openid_return');

    my $pb = $r->bridge('/profile')->to('profile#check');
        $pb->route('/')->to('profile#index', pageid => 'profile');
        $pb->route('/replays')->to('profile#replays', pageid => 'profile');
        $pb->route('/sr')->to('profile#sr', pageid => 'profile');
        $pb->route('/hr')->to('profile#hr', pageid => 'profile');
        $pb->route('/reclaim')->to('profile#reclaim', pageid => 'profile');

    my $stats = $r->under('/stats');
        $stats->route('/')->to('stats#index');
        $stats->route('/:statid')->to('stats#view');

    my $api = $r->under('/api/v1');
        $api->route('/bootstrap')->to('api#bootstrap');

    $self->sessions->default_expiration(86400 * 365); 
    $self->sessions->cookie_name('wrsession');

    $self->helper(wr_query => sub {
        my $self = shift;
        return WR::Query->new(@_, coll => $self->db('wot-replays')->get_collection('replays'));
    });

    $self->helper(cachable => sub {
        my $self = shift;
        my %opts = (@_);

        my $ttl = $opts{'ttl'} || 120;

        if(my $obj = $self->db('wot-replays')->get_collection('ui.cache')->find_one({ _id => $opts{'key'} })) {
            return $obj->{value} unless($obj->{created} + $ttl < time());
        }

        my $method = $opts{'method'};
        if(my $res = $self->$method()) {
            my $data = {
                _id     => $opts{'key'},
                created => time(),
                value   => $res || {},
            };
            $self->db('wot-replays')->get_collection('cache')->save($data, { safe => 1 });
            return $res;
        } else {
            return undef;
        }
    });

    has 'wr_res' => sub {
        return {
            achievements    => WR::Res::Achievements->new(),
            bonustype       => WR::Res::Bonustype->new(),
            gametype        => WR::Res::Gametype->new(),
            servers         => WR::Res::Servers->new(),
            country         => WR::Res::Country->new(),
            vehicleclass    => WR::Res::Vehicleclass->new(),
        }
    };
}

1;

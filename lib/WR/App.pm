package WR::App;
use Mojo::Base 'Mojolicious';
use WR;
use WR::Query;

$Template::Stash::PRIVATE = undef;

# This method will run once at server start
sub startup {
    my $self = shift;
    
    $self->secret(q|youwillneverguessthissecretitssosecret|);

    $self->plugin('Config', { file => 'wr.conf' });
    $self->plugin('mongodb', { host => 'localhost', patch_mongodb => 1 });
    $self->plugin('tt_renderer', { template_options => {
        PRE_CHOMP => 0,
        POST_CHOMP => 1,
        TRIM => 1,
        FILTERS => {
            'js' =>  sub {
                my $text = shift;
                $text =~ s/\'/\\\'/gi;
                return $text;
            },
        },
        RELATIVE => 1,
        ABSOLUTE => 1, # otherwise hypnotoad gets a bit cranky
    }});

    $self->plugin('authentication', {
        validate_user => sub {
            my $self = shift;
            my $u = shift;
            my $p = shift;

            if(my $user = $self->db('wot-replays')->get_collection('accounts')->find_one({ email => $u })) {
                return $user->{_id}->to_string() if(crypt($p, 'wr') eq $user->{password});
            }
            return undef;
        },
        load_user => sub {
            my $self = shift;
            my $uid = shift;

            if(my $user = $self->db('wot-replays')->get_collection('accounts')->find_one({ _id => bless({ value => $uid }, 'MongoDB::OID') })) {
                return $user;
            } else {
                return undef;
            }
        }
    });

    $self->routes->namespace('WR::App::Controller');

    my $r = $self->routes->bridge('/')->to('auto#index');

    $r->route('/')->to('ui#index', pageid => 'home');

    $r->route('/browse')->to('replays#browse', pageid => 'browse');
    $r->route('/faq')->to('ui#faq', pageid => 'faq');
    $r->route('/donate')->to('ui#donate', pageid => 'donate');
    $r->route('/about')->to('ui#about', pageid => 'about');

    $r->route('/upload')->to('replays-upload#upload', pageid => 'upload');

    $r->route('/download/:replay_id')->to('replays-export#download');
    $r->route('/raw/:replay_id')->to('replays-export#raw');

    $r->route('/replay/browse')->to('replays#browse');

    my $rb = $r->bridge('/replay/:replay_id')->to('replays#bridge');
        $rb->route('/')->to('replays-view#view', pageid => undef);
        $rb->route('/desc')->to('replays#desc', pageid => undef);
        $rb->route('/up')->to('replays-rate#rate_up', pageid => undef);
        $rb->route('/comments')->to('replays-comment#index', pageid => undef);
        $rb->route('/addcomment')->to('replays-comment#add', pageid => undef);

    $r->route('/players/:server')->to('player#index', pageid => 'player', server => 'any');

    $r->route('/player/:server/:player_name/involved')->to('player#involved', pageid => 'player');
    $r->route('/player/:server/:player_name')->to('player#view', pageid => 'player');
    $r->route('/player/:player_name')->to('player#ambi', pageid => 'player');

    $r->route('/clans')->to('clan#index', pageid => 'clan');

    $r->route('/vehicles')->to('vehicle#index', pageid => 'vehicle');
    $r->route('/vehicle/:country/:vehicle')->to('vehicle#view', pageid => 'vehicle');

    $r->route('/maps')->to('map#index', pageid => 'map');
    $r->route('/map/:map_id')->to('map#view', pageid => 'map');


    $r->route('/register')->to('ui#register', pageid => 'register');
    $r->route('/login')->to('ui#login', pageid => 'login');
    $r->route('/logout')->to('ui#do_logout');

    my $pb = $r->bridge('/profile')->to('profile#check');
        $pb->route('/')->to('profile#index', pageid => 'profile');
        $pb->route('/replays')->to('profile#replays', pageid => 'profile');
        $pb->route('/sr')->to('profile#sr', pageid => 'profile');
        $pb->route('/hr')->to('profile#hr', pageid => 'profile');

        $pb->route('/settings/auto')->to('profile#settings_auto', pageid => 'profile');

    $r->route('/wru')->to('wru#index', pageid => 'wru');
    $r->route('/wru/get_token')->to('wru#get_token');
    $r->route('/wru/upload')->to('wru#upload');

    $self->sessions->default_expiration(86400 * 365); 

    $self->helper(wr_query => sub {
        my $self = shift;
        return WR::Query->new(@_, coll => $self->db('wot-replays')->get_collection('replays'));
    });

}

1;

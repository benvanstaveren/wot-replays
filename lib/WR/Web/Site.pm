package WR::Web::Site;
use Mojo::Base 'Mojolicious';
use Mojo::JSON;
use Mango;
use Mojo::Util qw/url_escape decode encode/;

# this is a bit cheesy but... 
#use FindBin;
#use lib "$FindBin::Bin/../lib";

use WR;
use WR::Res;
use WR::Query;
use WR::Util::QuickDB;
use WR::Util::HashTable;
use Time::HiRes qw/gettimeofday/;

use WR::Web::Site::Helpers;
use WR::Web::Site::Startup;

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->attr(json => sub { return Mojo::JSON->new() });
    $self->attr(wr_res => sub { WR::Res->new(path => $self->home->rel_dir('etc/res')) });

    my $config = $self->plugin('Config', { file => 'wr.conf' });
    
    $config->{plugins} ||= {};
    
    $self->secrets([ $config->{secrets}->{app} ]);
    $self->attr('_tconfig' => sub { 
        my $self = shift;
        return WR::Util::HashTable->new(data => $config);
    });

    # the session cookie stays for a year
    $self->sessions->default_expiration(86400 * 365); 
    $self->sessions->cookie_name('wrsession');
    $self->log->debug('we are in dev mode, cookie_domain not set') if(defined($config->{mode}) && $config->{mode} eq 'dev');
    $self->sessions->cookie_domain($config->{urls}->{app_c}) if(!defined($config->{mode}) || $config->{mode} ne 'dev');

    $self->plugin('WR::Plugin::Mango', $config->{mongodb});

    WR::Web::Site::Helpers->install($self);

    for(qw/Auth Timing Notify Logging Thunderpush/) {
        $self->plugin(sprintf('WR::Plugin::%s', $_) => $config->{plugins}->{$_} || {});
    }

    $self->plugin('WR::Plugin::I18N', { versions => [qw/0.9.0 0.9.1 0.9.2 0.9.3/] });

    $self->renderer->paths([]); # clear this out
    $self->plugin('Mojolicious::Plugin::TtRenderer', {
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
                'ucfirste' => sub {
                    my $text = shift;

                    return join(' ', map { ucfirst($_) } (split(/\s/, $text)));
                },
                'uri_path' => sub {
                    my $text = shift;
                    my @parts = split(/\//, $text);
                    my $file  = url_escape(pop(@parts));

                    return join('/', @parts, $file);
                },
                'encode_utf8' => sub {
                    my $str = shift;
                    my $res = encode('UTF-8', $str);

                    return (defined($res)) ? $res : $str;
                },
                'decode_utf8' => sub {
                    my $str = shift;
                    my $res = decode('UTF-8', $str);

                    return (defined($res)) ? $res : $str;
                },
            },
            RELATIVE => 1,
            ABSOLUTE => 1, # otherwise hypnotoad gets a bit cranky, for some reason
            INCLUDE_PATH => [ $self->app->home->rel_dir('templates') ],
            COMPILE_DIR  => undef,
            COMPILE_EXT  => undef,
        },
    });
    $self->types->type(csv => 'text/csv; charset=utf-8');
    $self->renderer->default_handler('tt');

    $self->routes->namespaces([qw/WR::Web::Site::Controller/]);

    # anything that we don't want to run over auth has to go up in here
    $self->routes->route('/postaction')->to('postaction#nginx_post_action');
    my $login = $self->routes->under('/login');
        $login->any('/')->to('auth#do_login', pageid => 'login');
        $login->any('/:s')->to('auth#do_login', pageid => 'login');

    $self->routes->any('/logout')->to('auth#do_logout');

    my $openid = $self->routes->under('/openid');
        $openid->any('/return/:type')->to('auth#openid_return', type => 'default');

    my $r = $self->routes->under('/')->to(cb => sub {
        my $self = shift;
    
        $self->tdebug('main under cb top');
        my $r = $self->init_auth();
        $self->tdebug('main under cb bottom, returning undef: ', (defined($r)) ? 'no' : 'yes');
        return $r;
    })->name('authbridge');

    $r->get('/')->to('replays#browse', 
        filter_opts => {},
        pageid      => 'home', 
        filter_root => 'browse',
        page        => { 
            title       => 'index.page.title' 
        }, 
        browse => { 
            heading     => 'index.page.header' 
        },
        browse_filter_raw   =>  {
            p   =>  1,
            v   =>  '*',
            tmi =>  1,
            tma =>  10,
            m   =>  '*',
            mt  =>  '*',
            mm  =>  '*',
            sr  =>  'upload',
            s   =>  '*',
            vp  =>  1,
            vi  =>  0
        },
        initialize_with => [ '_fp_competitions', '_fp_notifications' ],
    );

    my $rb = $r->under('/replay/:replay_id');
        $rb->get('/')->to('replays-view#view', pageid => 'replay')->name('viewreplay');
        $rb->get('/battleviewer')->to('replays-view#battleviewer', pageid => 'battleviewer', page => { title => 'replay.battleviewer.page.title' });
        $rb->get('/download')->to('replays-export#download', pageid => undef);
        $rb->get('/packets')->to('replays-view#packets', pageid => undef);
        $rb->get('/comment')->to('replays-view#addcomment');
        $rb->get('/delcomment/:comment_id')->to('replays-view#delcomment');
        $rb->get('/heatmap')->to('replays-view#heatmap', pageid => 'battleheatmap', page => { title => 'replay.heatmap.page.title' });
        $rb->get('/desc')->to('replays#desc', pageid => undef);
        $rb->get('/up')->to('replays-rate#rate_up', pageid => undef);

    $r->get('/')->to('replays#browse', 
        filter_opts => {},
        pageid      => 'home', 
        filter_root => 'browse',
        page        => { 
            title       => 'index.page.title' 
        }, 
        browse => { 
            heading     => 'index.page.header' 
        },
        browse_filter_raw   =>  {
            p   =>  1,
            v   =>  '*',
            tmi =>  1,
            tma =>  10,
            m   =>  '*',
            mt  =>  '*',
            mm  =>  '*',
            sr  =>  'upload',
            s   =>  '*',
            vp  =>  1,
            vi  =>  0
        },
        initialize_with => [ '_fp_competitions', '_fp_notifications' ],
    );

    $r->get('/browse/*filter')->to('replays#browse', filter_opts => {}, pageid => 'browse', page => { title => 'browse.page.title' }, filter_root => 'browse');
    $r->get('/browse')->to(cb => sub {
        my $self = shift;
        $self->stash('browse_filter_raw' => {
            p   => 1,
            vp  => 1,
            vi  => 0,
            tmi => 1,
            tma => 10,
            v   => '*',
            m   => '*',
            s   => '*',
            mm  => '*',
            mt  => '*',
            sr  => 'upload',
        }, pageid => 'browse');
        $self->redirect_to(sprintf('/browse/%s', $self->browse_page(1)));
    });

    my $upload = $r->under('/upload');
        $upload->get('/')->to('replays-upload#upload', pageid => 'upload', upload_type => 'single');
        $upload->any('/process')->to('replays-upload#process_upload');
        $upload->any('/:upload_type')->to('replays-upload#upload', pageid => 'upload');

    my $xhr = $r->under('/xhr');
        $xhr->any('/qs')->to('ui#xhr_qs');
        $xhr->any('/ds')->to('ui#xhr_ds');
        $xhr->any('/du')->to('ui#xhr_du');
        $xhr->any('/dn_d')->to(cb => sub {
            my $self = shift;
            
            $self->render_later;
            if($self->req->is_xhr) {
                $self->dismiss_notification($self->req->param('id') => sub {
                    $self->render(json => { ok => 1 });
                });
            } else {
                $self->render(text => 'No.', status => 403);
            }
        });
    
    my $lang = $r->under('/lang');
        $lang->get('/:lang')->to('ui#xhr_po');

    my $bv = $r->under('/battleviewer/:replay_id');
        $bv->get('/')->to('replays-view#battleviewer', pageid => 'battleviewer', page => { title => 'replay.battleviewer.page.title' });

    my $bhm = $r->under('/battleheatmap/:replay_id');
        $bhm->get('/')->to('replays-view#heatmap', pageid => 'battleheatmap', page => { title => 'replay.heatmap.page.title' });

    $r->route('/clans')->to('clan#index', pageid => 'clan', page => { title => 'clans.page.title' });
    my $clan = $r->under('/clan');
        $clan->get('/:server/:clanticker')->to(cb => sub {
            my $self = shift;
            $self->stash('browse_filter_raw' => {
                p   => 1,
                vp  => 1,
                m   => '*',
                s   => '*',
                mm  => '*',
                mt  => '*',
                sr  => 'upload',
                pp  => 1, 
                pi  => 0,
            });
            $self->redirect_to(sprintf('/clan/%s/%s/%s', $self->stash('server'), $self->stash('clanticker'), $self->browse_page(1)));
        }, pageid => 'clan');

        $clan->get('/:server/:clanticker/*filter')->to('replays#browse', next => 'browse',
            page => {
                title => 'clan.page.title',
                title_args => [ 'clanticker' ],
            },
            pageid => 'clan',
            filter_opts => {
                base_query => sub {
                    my $self = shift;
                    return { 'c' => $self->stash('clanticker'), 's' => $self->stash('server') };
                },
                filter_root => sub {
                    my $self = shift;
                    return sprintf('clan/%s/%s', $self->stash('server'), $self->stash('clanticker'));
                }
            }
        );

    $r->get('/players')->to('player#index', pageid => 'player', page => { title => 'players.page.title' });
    my $player = $r->under('/player');
        $player->get('/:server/:player_name')->to(cb => sub {
            my $self = shift;
            $self->stash('browse_filter_raw' => {
                p   => 1,
                vp  => 1,
                m   => '*',
                s   => '*',
                mm  => '*',
                mt  => '*',
                sr  => 'upload',
                pp  => 1, 
                pi  => 0,
            });
            $self->redirect_to(sprintf('/player/%s/%s/%s', $self->stash('server'), $self->stash('player_name'), $self->browse_page(1)));
        }, pageid => 'player');
        $player->get('/:server/:player_name/latest')->to('player#latest', pageid => 'player');
        $player->get('/:server/:player_name/*filter')->to('replays#browse', next => 'browse',
            page => {
                title => 'player.page.title',
                title_args => [ 'player_name' ],
            },
            pageid => 'player',
            filter_opts => {
                base_query => sub {
                    my $self = shift;
                    return { 'pl' => $self->stash('player_name'), 's' => $self->stash('server') };
                },
                filter_root => sub {
                    my $self = shift;
                    return sprintf('player/%s/%s', $self->stash('server'), $self->stash('player_name'));
                }
            }
        );


    my $vehicles = $r->under('/vehicles');
        $vehicles->get('/')->to('vehicle#select', 
            pageid  => 'vehicle', 
            page    => { 
                title   => 'vehicles.page.title', 
                title_args => [ 't:Select Nation' ],
            }
        );
        $vehicles->get('/:country')->to('vehicle#index', 
            pageid  => 'vehicle', 
            page    => { 
                title   => 'vehicles.page.title', 
                title_args => [ 'l:nations:country' ],
            }
        );

    my $vehicle = $r->under('/vehicle');
        $vehicle->get('/:country/:vehicle')->to(cb => sub {
            my $self = shift;
            $self->stash('browse_filter_raw' => {
                p   => 1,
                vp  => 1,
                m   => '*',
                s   => '*',
                mm  => '*',
                mt  => '*',
                sr  => 'upload',
            });
            $self->redirect_to(sprintf('/vehicle/%s/%s/%s', $self->stash('country'), $self->stash('vehicle'), $self->browse_page(1)));
        }, pageid => 'vehicle');
        $vehicle->get('/:country/:vehicle/*filter')->to('replays#browse', 
            page => {
                title       => 'vehicle.page.title',
                title_args  => [ 'd:data.vehicles:name:vehicle:i18n' ],
            },
            pageid => 'vehicle',
            filter_opts => {
                base_query => sub {
                    my $self = shift;
                    return { 'v' => sprintf('%s:%s', $self->stash('country'), $self->stash('vehicle')) };
                },
                filter_root => sub {
                    my $self = shift;
                    return sprintf('vehicle/%s/%s', $self->stash('country'), $self->stash('vehicle'));
                }
            }
        );


    $r->get('/maps')->to('map#index', pageid => 'map');

    my $map = $r->under('/map');
        $map->get('/:map_id')->to(cb => sub {
            my $self = shift;
            $self->stash('browse_filter_raw' => {
                p   => 1,
                vp  => 1,
                tmi => 1,
                tma => 10,
                v   => '*',
                s   => '*',
                mm  => '*',
                mt  => '*',
                sr  => 'upload',
            });
            $self->redirect_to(sprintf('/map/%s/%s', $self->stash('map_id'), $self->browse_page(1)));
        }, pageid => 'map');
        $map->get('/:map_id/*filter')->to('replays#browse', 
            page => {
                title => 'map.page.title',
                title_args => [ 'map_name' ],
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
                        $self->stash('map_name' => $self->loc($doc->{i18n}));
                        $cb->({ m => $doc->{numerical_id }});
                    });
                },
                filter_root => sub {
                    my $self = shift;
                    return sprintf('map/%s', $self->stash('map_id'));
                }
            }
        );
   
    $r->get('/competitions')->to('competition#list', pageid => 'competition', page => { title => 'competitions.page.title' });
    my $competition = $r->under('/competition');
        my $cbridge = $competition->under('/:competition_id')->to('competition#bridge'); # loads the competition
            $cbridge->get('/')->to('competition#view', pageid => 'competition', page => { title => 'competition.page.title', title_args => [ 'competition_title' ] });
            $cbridge->get('/:server/:identifier')->to('replays#browse',
                pageid      => 'competition', 
                filter_opts => {
                    async      => 1,
                    # never should've named it that but hey... 
                    base_query => sub {
                        my $self     = shift;
                        my $cb       = shift;
                        my $id       = $self->stash('identifier');
                        my $server   = $self->stash('server');
                        my $config   = $self->stash('competition')->{config};
                        my $event    = WR::Event->new(log => $self->app->log, db => $self->get_database, %$config);

                        # get the merge args
                        my $base = $event->get_leaderboard_entries({ pi => 0, pp => 1, pl => $id, s => $server, _inc => [qw/pi pp pl s/] });
                        $cb->($base);
                    },
                    filter_root => sub {
                        my $self = shift;
                        return sprintf('competition/%s/%s/%s', $self->stash('competition_id'), $self->stash('server'), $self->stash('identifier'));
                    }
                },
                page        => { 
                    title       => 'competition.page.entries.title',
                    title_args  => [ 'competition_name', 'identifier' ],
                }, 
            );
            $cbridge->get('/:server/:identifier/*filter')->to('replays#browse', 
                pageid      => 'competition', 
                filter_opts => {
                    async      => 1,
                    # never should've named it that but hey... 
                    base_query => sub {
                        my $self = shift;
                        my $cb   = shift;
                        my $server = $self->stash('server');
                        my $id   = $self->stash('identifier');
                        my $config = $self->stash('competition')->{config};
                        my $event = WR::Event->new(log => $self->app->log, db => $self->get_database, %$config);

                        # get the merge args
                        my $base = $event->get_leaderboard_entries({ pi => 0, pp => 1, pl => $id, s => $server, _inc => [qw/pi pp pl s/] });
                        $cb->($base);
                    },
                    filter_root => sub {
                        my $self = shift;
                        return sprintf('competition/%s/%s/%s', $self->stash('competition_id'), $self->stash('server'), $self->stash('identifier'));
                    }
                },
                page        => { 
                    title       => 'competition.page.entries.title',
                    title_args  => [ 'competition_name', 'identifier' ],
                }, 
            );


    my $doc = $r->under('/doc');
        for(qw/about credits missions replayprivacy/) {
            $doc->get(sprintf('/%s', $_))->to('ui#doc', docfile => $_, pageid => $_);
        }

        $doc->get('/donate')->to(cb => sub {
            my $self = shift;
            $self->redirect_to('http://www.patreon.com/scrambled');
        });


    my $pb = $r->under('/profile')->to('profile#bridge');
        $pb->get('/replays/type/:type/page/:page')->to('profile#replays', mustauth => 1, pageid => 'profile', page => { title => 'profile.replays.page.title' });
        $pb->get('/uploads/page/:page')->to('profile#uploads', pageid => 'profile', page => { title => 'profile.uploads.page.title' });
        $pb->any('/settings')->to('profile#settings', pageid => 'profile', page => { title => 'profile.settings.page.title' });
        $pb->get('/sl/:lang')->to('profile#sl', pageid => 'profile');
        $pb->get('/link')->to('auth#do_link', pageid => 'profile');
        $pb->get('/link/:s')->to('auth#do_link', pageid => 'profile');
        $pb->get('/linked/:status')->to('profile#linked', pageid => 'profile');

        my $pbj = $pb->under('/j');
            $pbj->any('/sr')->to('profile#sr', pageid => 'profile');
            $pbj->any('/hr')->to('profile#hr', pageid => 'profile');
            $pbj->any('/pr')->to('profile#pr', pageid => 'profile');
            $pbj->any('/cr')->to('profile#cr', pageid => 'profile');
            $pbj->any('/plr')->to('profile#plr', pageid => 'profile');
            $pbj->any('/tr')->to('profile#tr', pageid => 'profile');
            $pbj->any('/setting')->to('profile#setting', pageid => 'profile');

    my $statistics = $r->under('/statistics');
        my $mastery = $statistics->under('/mastery');
            $mastery->get('/')->to('statistics-mastery#index', pageid => 'statistics/mastery');
            $mastery->get('/csv/:filedate')->to('statistics-mastery#as_csv', pageid => 'statistics/mastery');

    my $admin = $r->under('/admin')->to('admin#bridge');
        $admin->get('/')->to('admin#index', pageid => 'admin/home');
        $admin->get('/usersonline')->to('admin#get_online_users');
        $admin->get('/uploadslist')->to('admin#get_upload_queue');
        $admin->get('/todaycount')->to('admin#get_today_count');
        $admin->get('/replaycount')->to('admin#get_replay_count');

        $admin->get('/events')->to('admin-events#index', pageid => 'admin/events');

        my $language = $admin->under('/language');
            $language->get('/')->to('admin-language#redir', pageid => 'admin/language');
            my $langroot = $language->under('/:lang')->to('admin-language#language_bridge');
                $langroot->get('/')->to('admin-language#index', pageid => 'admin/language', section => '--');
                $langroot->any('/publish')->to('admin-language#publish', pageid => 'admin/language');
                my $section = $langroot->under('/:section');
                    $section->any('/')->to('admin-language#section', pageid => 'admin/language');
                    $section->any('/single')->via(qw/POST/)->to('admin-language#save_single');
                    $section->any('/all')->via(qw/POST/)->to('admin-language#save_all');

        my $site = $admin->under('/site');
            my $replays = $site->under('/replays');
                $replays->get('/page/:page')->to('admin-site#replays', pageid => 'admin/site');
            my $uploads = $site->under('/uploads');
                $uploads->get('/page/:page')->to('admin-site#uploads', pageid => 'admin/site');
            my $notifications = $site->under('/notifications');
                $notifications->get('/')->to('admin-site#notifications', pageid => 'admin/notifications');

    WR::Web::Site::Startup->run($self);

    $self->plugin('WR::Plugin::Preloader' => [ 'components', 'consumables', 'customization', 'equipment', 'maps', 'vehicles' ]);
}

1;

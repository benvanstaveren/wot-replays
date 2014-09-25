package WR::App;
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

use WR::App::Helpers;
use WR::App::Routes;
use WR::App::Minion;

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->attr(json => sub { return Mojo::JSON->new() });

    my $config = $self->plugin('Config', { file => 'wr.conf' });
    
    $config->{plugins} ||= {};
    
    $self->secrets([ $config->{secrets}->{app} ]);
    $config->{wot}->{bf_key} = join('', map { chr(hex($_)) } (split(/\s/, $config->{wot}->{bf_key})));

   
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

    for(qw/Auth Timing Notify/) {
        $self->plugin(sprintf('WR::Plugin::%s', $_) => $config->{plugins}->{$_} || {});
    }

    WR::App::Helpers->install($self);
    WR::App::Minion->install($self);

    $self->plugin('WR::Plugin::I18N', { versions => [qw/0.9.0 0.9.1 0.9.2/] });
    $self->plugin('WR::Plugin::Thunderpush', $config->{thunderpush});
    $self->plugin('Mojolicious::Plugin::Minion' => { Mango => 'mongodb://127.0.0.1:27017/' });

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

    has 'wr_res' => sub { return WR::Res->new() };

    my $preload = [ 'components', 'consumables', 'customization', 'equipment', 'maps', 'vehicles' ];
    foreach my $type (@$preload) {
        my $aname = sprintf('data_%s', $type);
        $self->attr($aname => sub {
            my $self = shift;
            return WR::Util::QuickDB->new(data => $self->mango->db('wot-replays')->collection(sprintf('data.%s', $type))->find()->all());
        });
        $self->helper($aname => sub {
            return shift->app->$aname();
        });
        $self->$aname();
    }

    $self->routes->namespaces([qw/WR::App::Controller/]);
    WR::App::Routes->install($self => $self->routes);
}

1;

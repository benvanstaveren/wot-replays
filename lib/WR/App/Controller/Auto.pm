package WR::App::Controller::Auto;
use Mojo::Base 'WR::App::Controller';
use Data::Localize;
use Data::Localize::Gettext;
use WR::Localize::Formatter;

sub index {
    my $self = shift;

    $self->stash('timing.start' => [ Time::HiRes::gettimeofday ]);

    if(my $notify = $self->session->{'notify'}) {
        delete($self->session->{'notify'});
        $self->stash(notify => $notify);
    }

    if($self->is_user_authenticated) {
        my $o = $self->session('openid');
        if($o =~ /https:\/\/(.*?)\..*\/id\/(\d+)-(.*)\//) {
            my $server = $1;
            my $pname = $3;

            $server = 'sea' if(lc($server) eq 'asia'); # fuck WG and renaming endpoints

            $self->stash('current_player_name' => $pname);
            $self->stash('current_player_server' => uc($server));
            $self->stash('current_user' => {
                player_name   => $pname,
                player_server => $server,
            });
        }
    }

    my $language = $self->session('lang');
    $language ||= 'en';
    my $langpath = $self->app->home->rel_dir(sprintf('lang/%s', $language));
    $language = 'en' unless(-e $langpath);

    my $localizer = Data::Localize::Gettext->new(formatter => WR::Localize::Formatter->new(), path => sprintf('%s/*.po', $langpath));
    $self->stash('i18n_localizer' => $localizer);

    return 1;
}

1;

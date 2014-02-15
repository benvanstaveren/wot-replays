package WR::Plugin::I18N;
use Mojo::Base 'Mojolicious::Plugin';
use Data::Localize::Gettext;

sub get_paths {
    my $self = shift;
    my %args = (@_);
    my $app  = $args{using};
    my $lang = $args{for};

    # wargaming language file set
    my $wg_path = sprintf('%s/*.po', $app->home->rel_dir(sprintf('lang/wg/%s', $lang)));

    # for each language, read the site/<lang> folder for the appropriate files 
    my $common_path = sprintf('%s/*.po', $app->home->rel_dir(sprintf('lang/site/%s', $lang)));

    return ($common_path, $wg_path);
}

sub register {
    my $self  = shift;
    my $app   = shift;

    my $g = {};

    # during registration we want to set up the paths for each language that's configured
    $g->{'common'} = [ $self->get_paths(for => 'common', using => $app) ];
    $g->{'en'}     = $g->{common};

    foreach my $language (@{$app->config->{i18n}->{languages}}) {
        $g->{$language} = [ $g->{'common'}, $self->get_paths(for => $language, using => $app) ];
    }
    $app->config('i18n_language_paths' => $g);

    $app->hook(before_routes => sub {
        my $c = shift;

        my $language = $c->session('language') || 'en';
        $c->app->log->info('before_routes: language: ' . $language . ' paths: ' . join(', ', @{$c->config('i18n_language_paths')->{$language}}));
        $c->stash('i18n_localizer' => $c->get_localizer_for($language));
        $c->stash('user_lang' => $language);
    });

    $app->helper(set_language => sub {
        my $c = shift;
        my $language = shift;

        $c->session(language => $language);
        $c->stash('i18n_localizer' => $c->get_localizer_for($language));
        $c->stash('user_lang' => $language);
    });

    $app->helper(loc_short => sub {
        my $self = shift;
        my $str  = shift;

        # append /short to the string
        return $self->loc(sprintf('%s/short', $str), @_);
    });

    $app->helper(loc_desc => sub {
        my $self = shift;
        my $str  = shift;

        # append /desc to the string
        return $self->loc(sprintf('%s/desc', $str), @_);
    });

    $app->helper(get_localizer_for => sub {
        my $self = shift;
        my $lang = shift;

        return Data::Localize::Gettext->new(formatter => WR::Localize::Formatter->new(), paths => $self->config('i18n_language_paths')->{$lang});
    });

    $app->helper(loc => sub {
        my $self = shift;
        my $str  = shift;
        my $args = shift;
        my $l    = 'site';  # default localizer "language", here to ensure that anything that doesn't get the #whatever:foo prefix treatment is picked up normally
        my $ostr = $str;

        return $str if(defined($self->config->{loc_disabled}));

        $args = [ $args, @_ ] if(ref($args) ne 'ARRAY');

        $self->app->log->error('no language string passed, caller: ' . (caller(0))[3]) and return 'no.lang.string.given' unless(defined($str));

        # find out if the string is a WoT style userString
        if($str =~ /^#(.*?):(.*)/) {
            $l   = $1;
            $str = $2;
        } else {
            $str = lc($str);
        }

        if(my $localizer = $self->stash('i18n_localizer')) {
            if(my $xlat = $localizer->localize_for(lang => $l, id => $str, args => $args)) {
                return $xlat;
            } else {
                $self->error('WR::Plugin::I18N: localisation for ', $self->stash('user_lang'), ' root: ', $l, ' str: ', $str, ' did not give a translation') if($self->is_the_boss && !defined($xlat));
                if($l ne 'site') {
                    # okay, stupid WG inconsistency, some tanks have a _short, some don't, so if our str contains _short, retry it 
                    $self->error('WR::Plugin::I18N: localisation for ', $self->stash('user_lang'), ' root: ', $l, ' str: ', $str, ' did not give a translation, trying to see if WG was stupid');
                    if($str =~ /_short$/) {
                        $ostr =~ s/_short$//g;
                        return $self->loc($ostr);
                    } else {
                        $self->error('WR::Plugin::I18N: apparently WG is not stupid');
                        return $ostr;
                    }
                } else {
                    $self->error('WR::Plugin::I18N: root: ', $l, ' str: ', $str, ' will return ', $ostr) if($self->is_the_boss && !defined($xlat));
                    return $ostr;
                }
            }
        } else {
            $self->error('WR::Plugin::I18N: no localizer in stash');
            return $ostr;
        }
    });
}

1;

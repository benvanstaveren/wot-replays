package WR::Plugin::I18N;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my $self = shift;
    my $app  = shift;

    $app->hook(before_routes => sub {
        my $c = shift;

        my $language = $c->session('lang') || 'en';
        my $langpath = (-e $c->app->home->rel_dir(sprintf('lang/%s', $language))) ? $c->app->home->rel_dir(sprintf('lang/%s', $language)) : $c->home->rel_dir('lang/en');
        $c->stash('i18n_localizer' => Data::Localize::Gettext->new(formatter => WR::Localize::Formatter->new(), path => sprintf('%s/*.po', $langpath)));
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

    $app->helper(loc => sub {
        my $self = shift;
        my $str  = shift;
        my @args = (@_);
        my $l    = 'site';  # default localizer "language"
        my $ostr = $str;

        $self->app->log->debug('no language string passed, caller: ' . (caller(1))[3]) and return 'no.lang.string.given' unless(defined($str));

        # find out if the string is a WoT style userString
        if($str =~ /^#(.*?):(.*)/) {
            $l   = $1;
            $str = $2;
        }

        if(my $localizer = $self->stash('i18n_localizer')) {
            if(my $xlat = $localizer->localize_for(lang => $l, id => $str, args => \@args)) {
                return $xlat;
            } else {
                # okay, stupid WG inconsistency, some tanks have a _short, some don't, so if our str contains _short, retry it 
                if($str =~ /_short$/) {
                    $ostr =~ s/_short$//g;
                    return $self->loc($ostr);
                } else {
                    return $str;
                }
            }
        } else {
            return $str;
        }
    });
}

1;

package WR::Plugin::I18N;
use Mojo::Base 'Mojolicious::Plugin';
use Data::Localize::Gettext;

sub register {
    my $self = shift;
    my $app  = shift;

    $app->hook(before_routes => sub {
        my $c = shift;

        my $language = $c->session('language') || 'en';

        # set up the paths 
        my $paths = [
            sprintf('%s/*.po', $c->app->home->rel_dir('lang/site/common')),
            sprintf('%s/*.po', $c->app->home->rel_dir('lang/wg/common')),
        ];

        if($language ne 'en') {
            push(@$paths, 
                sprintf('%s/*.po', $c->app->home->rel_dir(sprintf('lang/site/%s', $language))),
                sprintf('%s/*.po', $c->app->home->rel_dir(sprintf('lang/wg/%s', $language))),
            );
        }
        $c->stash('i18n_localizer' => Data::Localize::Gettext->new(formatter => WR::Localize::Formatter->new(), paths => $paths));
        $c->stash('user_lang' => $language);
    });

    $app->helper(set_language => sub {
        my $c = shift;
        my $language = shift;

        $c->session(language => $language);

        my $paths = [
            sprintf('%s/*.po', $c->app->home->rel_dir('lang/site/common')),
            sprintf('%s/*.po', $c->app->home->rel_dir('lang/wg/common')),
        ];

        if($language ne 'en') {
            push(@$paths, 
                sprintf('%s/*.po', $c->app->home->rel_dir(sprintf('lang/site/%s', $language))),
                sprintf('%s/*.po', $c->app->home->rel_dir(sprintf('lang/wg/%s', $language))),
            );
        }
        $c->stash('i18n_localizer' => Data::Localize::Gettext->new(formatter => WR::Localize::Formatter->new(), paths => $paths));
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
        my $args = shift;
        my $l    = 'site';  # default localizer "language"
        my $ostr = $str;

        $args = [ $args, @_ ] if(ref($args) ne 'ARRAY');

        $self->app->log->debug('no language string passed, caller: ' . (caller(1))[3]) and return 'no.lang.string.given' unless(defined($str));

        # find out if the string is a WoT style userString
        if($str =~ /^#(.*?):(.*)/) {
            $l   = $1;
            $str = $2;
        }

        if(my $localizer = $self->stash('i18n_localizer')) {
            if(my $xlat = $localizer->localize_for(lang => $l, id => $str, args => $args)) {
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

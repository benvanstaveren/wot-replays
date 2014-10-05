package WR::Plugin::I18N;
use utf8;
use Mojo::Base 'Mojolicious::Plugin';
use Data::Localize::Gettext;
use WR::Plugin::I18N::Formatter;
use Data::Dumper;
use Try::Tiny qw/try catch/;
use Encode qw/encode decode from_to/;

sub get_paths {
    my $self = shift;
    my %args = (@_);
    my $app  = $args{using};
    my $lang = $args{for};
    my $versions = $args{'versions'} || [];

    my @paths = ();
    push(@paths,  sprintf('%s/*.po', $app->home->rel_dir(sprintf('lang/site/%s', $lang))));

    foreach my $v (@$versions) {
        push(@paths,  sprintf('%s/*.po', $app->home->rel_dir(sprintf('lang/wg/%s/%s', $lang, $v))));
    }

    push(@paths,  sprintf('%s/*.po', $app->home->rel_dir('lang/wg/fixes')));
    return @paths;
}

sub register {
    my $self  = shift;
    my $app   = shift;
    my $conf  = shift || {};

    my $g = {};

    # during registration we want to set up the paths for each language that's configured
    $g->{'common'} = [ $self->get_paths(for => 'common', using => $app, versions => $conf->{versions} || []) ];
    $g->{'en'}     = $g->{common};
    
    $app->attr('i18n_localizers' => sub { {} });

    if(defined($app->get_config('languages'))) {
        foreach my $language (@{$app->get_config('languages')}) {
            next if($language->{ident} eq 'en');
            next if($language->{active} < 1);
            $g->{$language->{ident}} = [ 
                @{$g->{'common'}}, 
                $self->get_paths(for => $language->{ident}, using => $app) ,
            ];
        }
    }

    $app->log->debug('[I18N]: Using paths: ' . Dumper($g->{'common'}));
    $app->config('i18n_language_paths' => $g);

    $app->log->debug('[I18N]: Instantiating localizers');
    foreach my $ident (keys(%$g)) {
        $app->i18n_localizers->{$ident} = Data::Localize::Gettext->new(encoding => 'utf8', formatter => WR::Plugin::I18N::Formatter->new(), paths => $g->{$ident});
        $app->log->debug('[I18N]: - ' . $ident);
    }
    $app->log->debug('[I18N]: Localizers instantiated');

    $app->hook(before_routes => sub {
        my $c = shift;

        my $language = $c->session('language') || 'en';
        $c->stash('user_lang' => $language);
    });

    $app->helper(set_language => sub {
        my $c = shift;
        my $language = shift;

        $c->session(language => $language);
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

    $app->helper(fix_utf8_for_js => sub {
        my $self = shift;
        my $str  = shift;
        my $new  = '';

        my @b = split(//, $str);
        foreach my $c (@b) {
            if(ord($c) > 127) {
                $new .= sprintf('&#%d;', ord($c));
            } else {
                $new .= $c;
            }
        }
        return $new;
    });

    $app->helper(get_catalog_for_js => sub {
        my $self = shift;
        if(my $localizer = $self->stash('i18n_localizer')) {
            my $catalog = {};
            foreach my $id (keys(%{$localizer->get_lexicon_map('site')})) {
                # only add certain keys to it
                if($id =~ /^(growl)\./) {
                    $catalog->{$id} = $localizer->get_lexicon('site', $id);
                    $self->app->log->debug('adding ' . $id . ' to site catalog');
                }
            }
            return $catalog;
        } else {
            return {};
        }
    });

    $app->helper(loc => sub {
        my $self = shift;
        my $str  = shift;
        my $args = shift;
        my $nolc = $self->stash('loc_nolc') || 0;
        my $l    = 'site';  # default localizer "language", here to ensure that anything that doesn't get the #whatever:foo prefix treatment is picked up normally
        my $ostr = $str;

        $args = [ $args, @_ ] if(ref($args) ne 'ARRAY');

        $self->error('no language string passed, caller: ' . (caller(0))[3]) and return 'no.lang.string.given' unless(defined($str));

        # find out if the string is a WoT style userString
        if($str =~ /^#(.*?):(.*)/) {
            $l   = $1;
            $str = $2;
            # it is...
        } else {
            $str = lc($str) unless($nolc == 1);
        }

        my $result;

        if(my $localizer = $self->app->i18n_localizers->{$self->stash('user_lang')}) {
            if(my $xlat = $localizer->localize_for(lang => $l, id => $str, args => $args)) {
                $result = $xlat;
                if($l ne 'site') {
                    # which means it's a WoT thing
                    utf8::decode($result);
                }
            } else {
                if($l ne 'site') {
                    # okay, stupid WG inconsistency, some tanks have a _short, some don't, so if our str contains _short, retry it 
                    if($str =~ /_short$/) {
                        $ostr =~ s/_short$//g;
                        $result = $self->loc($ostr);
                    } elsif($str =~ /_(mk\d|class\d)$/i) {
                        # another one
                        $str =~ s/(.*?)_.*/$1/g;
                        $result = $self->loc($ostr);
                    } else {
                        $result = $ostr;
                    }
                } else {
                    # we mighta fucked it with the LC
                    if($nolc == 1) {
                        $result = $ostr;
                    } else {
                        $self->stash('loc_nolc' => 1);
                        $result = $self->loc($ostr, $args);
                    }
                }
            }
        } else {
            $self->error('WR::Plugin::I18N: no localizer in stash, requested language: ', $self->stash('user_lang'), ' key: ', $ostr);
            $result = $ostr;
        }

        $self->stash('loc_nolc' => 0);
        return $result;
    });
}

1;

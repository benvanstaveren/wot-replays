package WR::App::Controller::Admin::Language;
use Mojo::Base 'WR::App::Controller';
use WR::HashTable;

has 'layout' => sub { 
    [
        { 
            title    => 'Global Elements',
            children => [ 
                { id => 'nav', title => 'Navigation' },
                { id => 'modal', title => 'Global Modals' },
                { id => 'footer', title => 'Footer' },
            ],
        },
        { 
            title    => 'Pages',
            children => [ 
                { id => 'index',  title => 'Index' },
                { 
                    id => 'browse', title => 'Browse',
                },
                { 
                    title => 'Players',
                    children => [ 
                        { id => 'players', title => 'Index' },
                        { id => 'player', title => 'Browse Player' },
                    ],
                },
                { 
                    title => 'Clans', 
                    children => [ 
                        { id => 'clans', title => 'Index' },
                        { id => 'clan', title => 'Browse Clan' },
                    ],
                },
                { 
                    title => 'Maps',
                    children => [ 
                        { id => 'maps', title => 'Index' },
                        { id => 'map', title => 'Browse Map' },
                    ],
                },
                { 
                    title => 'Vehicles', 
                    children => [ 
                        { id => 'vehicles', title => 'Index' },
                        { id => 'vehicle', title => 'Browse Vehicles' },
                    ],
                },
                { title => 'Heatmaps',  id => 'heatmaps' },
                { title => 'Upload Form',  id => 'upload' },
                { 
                    title => 'Player Profile',
                    children => [
                        { id => 'profile-replays', title => 'Replays' },
                        { id => 'profile-uploads', title => 'Uploads' },
                        { id => 'profile-settings', title => 'Settings' },
                    ],
                },
            ],
        },
        { 
            id => 'filter', 
            title => 'Browse Filter',
        },
        { 
            id => '#', 
            title => 'Replays',
            children => [
                { id => 'panel', title => 'Panel' },
                { id => 'replay-header', title => 'Page Header' },
                { id => 'replay-nav', title => 'Page Navigation' },
                { id => 'replay-battleviewer', title => 'Battle Viewer' },
                { id => 'replay-heatmap', title => 'Battle Heatmap' },
                { 
                    title => 'Page Tabs' ,
                    children => [
                        { id => 'replay-overview', title => 'Overview' },
                        { id => 'replay-earnings', title => 'Earnings' },
                        { id => 'replay-missions', title => 'Missions' },
                        { id => 'replay-teams', title => 'Teams' },
                        { id => 'replay-loadout', title => 'Loadout' },
                        { id => 'replay-chat', title => 'Chat' },
                    ],
                },
                { 
                    title => 'Modals' ,
                    children => [
                        { id => 'replay-modal-embed', title => 'Embed' },
                    ],
                },
            ],
        },
        {
            title   => 'Misc. Elements',
            children => [ 
                { id => 'bonustype', title => 'Bonus Types' },
                { id => 'gametype', title => 'Game Types' },
                { id => 'nations', title => 'Nations' },
                { id => 'server', title => 'Server Names' },
                { id => 'vehicleclass', title => 'Vehicle Class' },
                { id => 'camokinds', title => 'Camouflage Types' },
                { id => 'critdetails', title => 'Crit Detail Types' },
                { id => 'privacy', title => 'Privacy Settings' },
                { id => 'tooltip', title => 'Tooltips' },
                { id => 'language', title => 'Languages' },
            ],
        },
    ]
};

sub get_data {
    my $self = shift;
    my $e    = shift;
    my $lang  = $self->stash('lang');

    if(my $hashtable = $self->load_section_for($lang, $e)) {
        my $export = $hashtable->export;
        return $export;
    } 
    return {};
}

sub publish {
    my $self = shift;
    my $ht   = WR::HashTable->new;
    my $lang  = $self->stash('lang');
    my $pub   = {};

    foreach my $i (@{$self->layout}) {
        if(defined($i->{id})) { 
            my $ex = $self->get_data($i->{id});
            foreach my $key (keys(%$ex)) {
                $pub->{$key} = $ex->{$key};
            }
        }
        if(defined($i->{children})) {
            foreach my $child (@{$i->{children}}) {
                my $ex = $self->get_data($child->{id});
                foreach my $key (keys(%$ex)) {
                    $pub->{$key} = $ex->{$key};
                }
                if(defined($child->{children})) {
                    foreach my $subchild (@{$child->{children}}) {
                        my $ex = $self->get_data($subchild->{id});
                        foreach my $key (keys(%$ex)) {
                            $pub->{$key} = $ex->{$key};
                        }
                    }
                }
            }
        }
    }

    my $fh = IO::File->new(sprintf('>%s/%s/site.po', $self->app->home->rel_dir('lang/site'), $lang));
    foreach my $key (sort(keys(%$pub))) {
        $fh->print(sprintf(q|msgid "%s"|, $key), "\n");
        $fh->print(sprintf(q|msgstr "%s"|, $pub->{$key}), "\n");
        $fh->print("\n");
    }
    $fh->close;
    $self->render(json => { ok => 1 });
}

sub language_bridge {
    my $self = shift;
    my $lang = $self->stash('lang');

    return 1;
}

sub make_title {
    my $self = shift;
    my $t    = shift;

    if($t =~ /^page_(.*)/) {
        my $a = $1;
        return 'Page: ' . ucfirst($a);
    } elsif($t =~ /^include_(.*)/) {
        my $a = $1;
        return 'Include: ' . ucfirst($a);
    } else {
        return 'Misc: ' . ucfirst($t);
    }
}

sub index {
    my $self = shift;
    my $lang = $self->stash('lang');

    if(!defined($lang)) {
        # find out what language(s) they're allowed to edit and send them there
        if($self->is_the_boss) {
            $self->redirect_to('/admin/language/common');
        } else {
            my $elang = $self->current_user->{admin}->{language}->{allowed};
            $self->redirect_to(sprintf('/admin/language/%s/', $elang->[0]));
        }
    } else {
        $self->respond(template => 'admin/language/index', stash => {
            page => { title => 'Language Manager' },
            sections => $self->layout,
        });
    }
}

sub save_all {
    my $self = shift;
    my $lang    = $self->stash('lang');
    my $section = $self->stash('section');

    my $args = $self->req->params->to_hash;
    my $set  = {};
    my $file = sprintf('%s/%s/%s.po', $self->app->home->rel_dir('lang/src'), $lang, $section);

    foreach my $key (keys(%$args)) {
        if($key =~ /strings\[(.*?)\]/) {
            my $rk = $1;
            my $v  = $args->{$key};

            $v =~ s/"/&quot;/g;
            $v =~ s/\&/&amp;/g;
            $v =~ s/\</&lt;/g;
            $v =~ s/\>/&gt;/g;

            $set->{$rk} = $args->{$key} unless($v =~ /[<>]/); # don't accept html...
        }
    }

    if(my $fh = IO::File->new(sprintf('>%s', $file))) {
        foreach my $key (sort(keys(%$set))) {
            $fh->print(sprintf('msgid "%s"', $key), "\n");
            $fh->print(sprintf('msgstr "%s"', $set->{$key}), "\n");
            $fh->print("\n");
        }
        $fh->close;
        $self->render(json => { ok => 1 });
    } else {
        warn 'save_all storing fail: ', $file, ' - ', $!, "\n";
        $self->render(json => { ok => 0 });
    }
}

sub save_single {
    my $self = shift;
    my $lang    = $self->stash('lang');
    my $section = $self->stash('section');

    my $file = sprintf('%s/%s/%s.po', $self->app->home->rel_dir('lang/src'), $lang, $section);
    my $export = {};
    my $path = $self->req->param('path');
    my $val  = $self->req->param('value');

    if(my $hashtable = $self->load_section_for($lang, $section)) {
        $export = $hashtable->export;
    }
    $export->{$path} = $val;
    if(my $fh = IO::File->new(sprintf('>%s', $file))) {
        foreach my $key (sort(keys(%$export))) {
            my $v = $export->{$key};
            $v =~ s/"/&quot;/g;
            $v =~ s/\&/&amp;/g;
            $v =~ s/\</&lt;/g;
            $v =~ s/\>/&gt;/g;
            $fh->print(sprintf('msgid "%s"', $key), "\n");
            $fh->print(sprintf('msgstr "%s"', $v), "\n");
            $fh->print("\n");
        }
        $fh->close;
        $self->render(json => { ok => 1 });
    } else {
        warn 'save_single storing fail: ', $file, ' - ', $!, "\n";
        $self->render(json => { ok => 0 });
    }
}

sub load_section_for {
    my $self = shift;
    my $lang = shift;
    my $section = shift;

    warn 'load_section_for ', $lang, ' ', $section, "\n";

    if(my $fh = IO::File->new(sprintf('%s/%s/%s.po', $self->app->home->rel_dir('lang/src'), $lang, $section))) {
        my $id = undef;
        my $val = undef;
        my $hash = {};
        while(my $line = <$fh>) {
            if($line =~ /msgid\s+\"(.*?)\"/) {
                $id = $1;
            } elsif($line =~ /msgstr\s+"(.*?)\"/) {
                $hash->{$id} = $1;
                $id = undef;
            }
        }
        $fh->close;
        return WR::HashTable->new(data => $hash);
    } else {
        return undef;
    }
}

sub section {
    my $self    = shift;
    my $lang    = $self->stash('lang');
    my $section = $self->stash('section');
    my $hash    = {};

    if(my $langt = $self->load_section_for($lang, $section)) {
        $self->stash('export' => $langt->export);
    }
    if(my $commont = $self->load_section_for('common', $section)) {
        $self->stash('common' => $commont->export);
    }
    $self->respond(template => 'admin/language/index', stash => {
        page => { title => 'Language Manager' },
        sections => $self->layout,
    });
}

1;

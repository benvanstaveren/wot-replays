package WR::App::Controller::Admin::Language;
use utf8;
use Mojo::Base 'WR::App::Controller';
use WR::Util::HashTable;
use Data::Dumper;
use Mojo::Util qw/xml_escape/;

has 'layout' => sub { 
    [
        { 
            title    => 'Global Elements',
            children => [ 
                { id => 'nav', title => 'Navigation' },
                { id => 'modal', title => 'Global Modals' },
                { id => 'growl', title => 'Growl Notifications' },
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
                { title => 'Competitions',  id => 'competitions' },
                {
                    title => 'Statistics',
                    children => [
                        { id => 'statistics-mastery', title => 'Mastery' }
                    ],
                },
                { title => 'Upload Form',  id => 'upload' },
                { 
                    title => 'Player Profile',
                    children => [
                        { id => 'profile-replays', title => 'Replays' },
                        { id => 'profile-uploads', title => 'Uploads' },
                        { id => 'profile-settings', title => 'Settings' },
                    ],
                },
                { id => 'misc-pages',  title => 'Misc. Pages' },
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
                        { id => 'replay-comments', title => 'Comments' },
                    ],
                },
                { 
                    title => 'Modals' ,
                    children => [
                        { id => 'replay-modal-embed', title => 'Embed' },
                        { id => 'replay-modal-comment', title => 'Comments' },
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

sub get_id_list {
    my $self = shift;
    my $s    = shift;
    my $id   = [];

    push(@$id, $s->{id}) if(defined($s->{id}));
    if(defined($s->{children})) {
        foreach my $child (@{$s->{children}}) {
            push(@$id, @{$self->get_id_list($child)});
        }
    }
    return $id;
}

sub find_missing {
    my $self     = shift;
    my $lang     = $self->stash('lang');
    my $sections = [];
    my $missing  = [];

    foreach my $entry (@{$self->layout}) {
        push(@$sections, @{$self->get_id_list($entry)});
    }

    my $export = {};
    my $common = {};

    foreach my $section (@$sections) {
        next if($section eq 'language');
        if(my $langt = $self->load_section_for($lang, $section)) {
            $export->{$section} = $langt->export;
        }
        if(my $commont = $self->load_section_for('common', $section)) {
            $common->{$section} = $commont->export;
        }

        foreach my $key (keys(%{$common->{$section}})) {
            next if($key eq 'new-value');
            next if($key eq 'new-string');
            push(@$missing, {
                section => $section,
                string  => $key
            }) unless(defined($export->{$section}->{$key}) && length($export->{$section}->{$key}) > 0);
        }
    }
    $self->stash(missing => [ sort { $a->{string} cmp $b->{string} } @$missing ], common => $common, export => $export);
}

sub publish {
    my $self = shift;
    my $ht   = WR::Util::HashTable->new;
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

    if(open(my $fh, '>:encoding(utf-8)', sprintf('%s/%s/site.po', $self->app->home->rel_dir('lang/site'), $lang))) {
	    foreach my $key (sort(keys(%$pub))) {
            utf8::decode($pub->{$key});
            print($fh sprintf(q|msgid "%s"|, $key), "\n", sprintf(q|msgstr "%s"|, $pub->{$key}), "\n\n");
	    }
        close($fh);
    }

    # unlink the cached entry so it will regenerate on the next reload
    unlink(sprintf('%s/lang/%s.js', $self->config('paths')->{public}, $lang));

    $self->render(json => { ok => 1 });
}

sub redir {
    my $self = shift;

    $self->redirect_to('/admin') and return undef unless($self->has_role('language'));

    if($self->is_the_boss) {
        $self->redirect_to('/admin/language/common');
    } else {
        my $elang = $self->current_user->{admin}->{languages}->{allowed};
        $self->redirect_to(sprintf('/admin/language/%s/', $elang->[0]));
    }
}

sub language_bridge {
    my $self = shift;
    my $lang = $self->stash('lang');

    $self->redirect_to('/admin') and return undef unless($self->has_role('language'));

    return 1 if($self->is_the_boss);
    my $r = 0;
    my $elang = $self->current_user->{admin}->{languages}->{allowed};
    foreach my $l (@$elang) {
        $r = 1 if($l eq $lang);
    }
    $self->render(template => 'admin/language/forbidden') and return undef if($r == 0);
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

    $self->find_missing if($lang ne 'common');

    $self->respond(template => 'admin/language/index', stash => {
        page => { title => 'Language Manager' },
        sections => $self->layout,
    });
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
            next if($rk =~ /^new-(string|value)/);
            my $v  = xml_escape($args->{$key});
            utf8::decode($args->{$key});

            # restore entities
            while($v =~ /\&amp;(.*?);/) {
                my $e = $1;
                $v =~ s/\&amp;$e;/\&$e;/g;
            }
    
            if(defined($args->{$key}) && length($args->{$key}) > 0) {
                $set->{$rk} = $args->{$key};
            }
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
    if(defined($val) && length($val) > 0) {
        $export->{$path} = $val;
    } else {
        delete($export->{$path});
    }
    if(my $fh = IO::File->new(sprintf('>%s', $file))) {
        foreach my $key (sort(keys(%$export))) {
            my $v = xml_escape($export->{$key});
            # restore entities
            while($v =~ /\&amp;(.*?);/) {
                my $e = $1;
                $v =~ s/\&amp;$e;/\&$e;/g;
            }
            utf8::decode($v);
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
        return WR::Util::HashTable->new(data => $hash);
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

package WR::App::Controller::Ui;
use Mojo::Base 'WR::App::Controller';
use WR::Res::Achievements;
use Time::HiRes qw/gettimeofday tv_interval/;
use Filesys::DiskUsage::Fast qw/du/;
use Mojo::Util qw/url_escape/;
use Mango::BSON;
use Data::Dumper;

sub doc {
    my $self = shift;
    
    $self->respond(template => 'doc/index', stash => {
        page => { title => $self->loc(sprintf('page.%s.title', $self->stash('docfile'))) }
    })
}

sub frontpage {
    my $self    = shift;
    my $start   = [ gettimeofday ];
    my $newest  = [];
    my $replays = [];
    my $filter  = (defined($self->stash('frontpage.filter'))) ? $self->stash('frontpage.filter') : {};

    my $query = $self->wr_query(
        sort    => { 'site.uploaded_at' => -1 },
        perpage => 15,
        filter  => $filter,
        panel   => 1,
        );
    $query->page(1 => sub {
        my ($q, $replays) = (@_);

        my $template = ($self->req->is_xhr) ? 'replay/list' : 'index';
        $self->respond(template => $template, stash => {
            replays         => $replays || [],
            page            => { title => 'index.page.title' },
            timing_query    => tv_interval($start),
            sidebar         => {
                info    => {
                    title => 'Languages',
                    text  => q|Did you know you can change the site language in your settings? Currently we have <strong>English</strong>, <strong>Malaysian</strong> and <strong>German</strong> available, with more languages being added!|,
                },
            },
        });
    });
}

sub xhr_du {
    my $self = shift;

    $self->render_later;

    my $bytes = du($self->stash('config')->{paths}->{replays});
    
    $self->render(
        json => {
            bytes => $bytes,
            megabytes => sprintf('%.2f', $bytes / (1024 * 1024)),
            gigabytes => sprintf('%.2f', $bytes / (1024 * 1024 * 1024)),
        }
    );
}

sub xhr_ds {
    my $self = shift;

    $self->render_later;
    $self->get_database->command(Mango::BSON::bson_doc('dbStats' => 1, 'scale' => (1024 * 1024)) => sub {
        my ($db, $err, $doc) = (@_);

        if(defined($doc)) {
            my $n = {};
            for(qw/dataSize storageSize indexSize/) {
                $n->{$_} = sprintf('%.2f', $doc->{$_});
            }
            $self->render(json => { ok => 1, data => $n });
        } else {
            $self->render(json => { ok => 0 });
        }
    });
}

sub nginx_post_action {
    my $self = shift;
    my $file = $self->req->param('f');
    my $stat = $self->req->param('s');

    $self->render_later;
    if(defined($stat) && lc($stat) eq 'ok') {
        my $real_file = substr($file, 1); # because we want to ditch that leading slash
        if($real_file =~ /^(mods|patches)/) {
            $self->render(text => 'OK');
        } else {
            $self->model('replays')->update({ file => $real_file }, { '$inc' => { 'site.downloads' => 1 } } => sub {
                $self->render(text => 'OK');
            });
        }
    } else {
        $self->render(text => 'OK');
    }
}

sub xhr_qs {
    my $self = shift;

    $self->render_later;
    $self->model('jobs')->find({ ready => Mango::BSON::bson_true, complete => Mango::BSON::bson_false })->count(sub {
        my ($c, $e, $d) = (@_);

        if(defined($d)) {
            $self->render(json => { ok => 1, count => $d });
        } else {
            $self-render(json => { ok => 0 });
        }
    });
}

sub xhr_po {
    my $self = shift;
    $self->stash(catalog => $self->i18n_catalog);
    $self->render(template => 'xhr/po');
}

1;

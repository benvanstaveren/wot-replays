package WR::App::Startup;
use strict;
use warnings;
use Module::Load qw/load/;
use Try::Tiny qw/try catch/;

sub run {
    my $dummy = shift;
    my $app   = shift;

    my $preload = [ 'components', 'consumables', 'customization', 'equipment', 'maps', 'vehicles' ];
    foreach my $type (@$preload) {
        $app->debug('[Startup]: preloading: ',  $type);

        my $aname = sprintf('data_%s', $type);
        $app->attr($aname => sub {
            my $self = shift;
            return WR::Util::QuickDB->new(data => $self->mango->db('wot-replays')->collection(sprintf('data.%s', $type))->find()->all());
        });
        $app->helper($aname => sub {
            return shift->app->$aname();
        });
        $app->$aname();
    }

    for my $t (qw/Tanks Components/) {
        $app->debug('[Startup]: updating ', $t);
        my $m = sprintf('WR::Update::%s', $t);
        try {
            load $m;
            my $updater = $m->new(app => $app);
            $updater->run;
        } catch {
            $app->log->fatal('[Startup]: updater for ' . $t .  ' failed: ' . $_);
            die $_, "\n";
        };
    }

}

1;

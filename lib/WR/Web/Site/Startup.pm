package WR::Web::Site::Startup;
use strict;
use warnings;
use Module::Load qw/load/;
use Try::Tiny qw/try catch/;

sub run {
    my $dummy = shift;
    my $app   = shift;

    for my $t (qw/Tanks Components/) {
        $app->debug('[Startup]: updating ', $t);
        my $m = sprintf('WR::Update::%s', $t);
        try {
            load $m;
            my $updater = $m->new(app => $app);
            $updater->run;
        } catch {
            $app->log->fatal('[Startup]: updater for ' .  $t . ' failed: ' .  $_);
            die $_, "\n";
        };
    }
}

1;

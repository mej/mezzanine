# Mezzanine Autobuilder Perl Module
# 
# Copyright (C) 2005-2011, Michael Jennings <mej@eterm.org>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies of the Software, its documentation and marketing & publicity
# materials, and acknowledgment shall be given in the documentation, materials
# and software packages that this Software was used.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# $Id: Builder.pm,v 1.2 2011/02/10 02:11:35 mej Exp $
#

package Mezzanine::Builder;
use strict;
use Exporter;
use POSIX;
use Mezzanine::Util;

our $VERSION     = 0.1;
our @EXPORT      = ('&preclean', '&update', '&repair', '&get_phase', '&build', '&createrepo', '&flush', '&sync');
our @EXPORT_OK   = ('$VERSION');
our %EXPORT_TAGS = ( "FIELDS" => [ @EXPORT_OK, @EXPORT ] );

my $TIME_FORMAT = "[%Y-%m-%d %H:%M:%S]";

sub
tprint(@)
{
    return print POSIX::strftime($TIME_FORMAT, localtime(time())), ' ', @_;
}

sub
tprintf(@)
{
    print POSIX::strftime($TIME_FORMAT, localtime(time())), ' ';
    return printf @_;
}

sub
new(@)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self;

    $self = {};
    bless($self, $class);
    return $self->init(@_);
}

sub
get($)
{
    my ($self, @keys) = @_;
    my @values;

    dprint &print_args(@_);
    foreach my $key (@keys) {
        if (($key !~ /^\w+$/) || (!exists($self->{$key}))) {
            push @values, undef;
        } else {
            push @values, $self->{$key};
        }
    }
    dprintf("Returning \"%s\".\n", join(", ", @values));
    if (wantarray()) {
        return @values;
    } else {
        return $values[0];
    }
}

sub
set($$)
{
    my ($self, %pairs) = @_;
    my $final;

    dprint &print_args(@_);
    foreach my $key (keys(%pairs)) {
        if (($key !~ /^\w+$/) || (!exists($self->{$key}))) {
            $final = undef;
        } elsif (defined($pairs{$key})) {
            $final = $self->{$key} = $pairs{$key};
        }
    }
    dprintf("Returning %s.\n", ((defined($final)) ? ($final) : ("<undef>")));
    return $final;
}

sub
init($)
{
    my ($self, $config) = @_;

    $self->{"CONFIG"} = $config;
    if ($config->get("TIME_FORMAT")) {
        $TIME_FORMAT = $config->get("TIME_FORMAT");
    }

    # Constants
    $self->{"ARCHDIR"} = sprintf("%s/%s", $config->get("BUILDDIR"), $config->get("ARCH"));
    $self->{"SRPMDIR"} = $config->get("BUILDDIR") . "/SRPMS";
    $self->{"LOGDIR"} = $self->{"ARCHDIR"} . "/00_LOGS";

    foreach my $dir ("ARCHDIR", "SRPMDIR", "LOGDIR") {
        &mkdirhier($self->{$dir});
    }
    @{$self->{"BUILDTREES"}} = $self->find_build_trees();

    return $self;
}

sub
preclean()
{
    my $self = shift;
    my @dirs;

    if ($self->get("CONFIG")->get("PRECLEAN")) {
        tprint "Beginning preclean step.\n";
    } else {
        tprint "Skipping preclean step.\n";
        return;
    }
    dprintf("Pre-cleaning in %s\n", &get_temp_dir());
    @dirs = glob(&get_temp_dir() . "/mezzanine*");
    if (scalar(@dirs)) {
        dprintf("Got %d leftover temporary directories.\n", scalar(@dirs));
        &nuke_tree(@dirs);
    } else {
        tprint "Preclean step not needed -- no leftover temporary directories.\n";
    }
    tprint "Preclean step complete.\n";
}

sub
repair()
{
    my $self = shift;
    my $buildroot = $self->{"CONFIG"}->get("BUILDROOT");

    if ($self->get("CONFIG")->get("REPAIR")) {
        tprint "Beginning repair step.\n";
    } else {
        tprint "Skipping repair step.\n";
        return;
    }

    tprint "Repairing buildroot $buildroot.\n";
    &nuke_tree(glob("$buildroot/var/lib/rpm/__db.*"));
    &run_cmd("/usr/sbin/chroot", "$buildroot rpm --rebuilddb", "buildroot repair -> ", 120);
    &nuke_tree(glob("$buildroot/var/lib/rpm/__db.*"));
    tprint "Repair step complete.\n";
}

sub
update()
{
    my $self = shift;
    my $buildroot = $self->{"CONFIG"}->get("BUILDROOT");
    my $err;

    if ($self->get("CONFIG")->get("UPDATE")) {
        tprint "Beginning update step.\n";
    } else {
        tprint "Skipping update step.\n";
        return;
    }
    $err = &run_cmd("/usr/sbin/chroot", sprintf("$buildroot %s check-update", $self->{"CONFIG"}->get("DEPSOLVER")),
                    "buildroot update -> ");
    &nuke_tree(glob("$buildroot/var/lib/rpm/__db.*"));
    if ($err) {
        wprint "Buildroot $buildroot has updates pending.  This is probably not good.\n";
    }
    tprint "Update step complete.\n";
}

sub
get_phase()
{
    my $self = shift;

    if ($self->get("CONFIG")->get("GET")) {
        tprint "Beginning get step.\n";
    } else {
        tprint "Skipping get step.\n";
        return;
    }

    if (!scalar(@{$self->{"BUILDTREES"}})) {
        wprint "No build trees found!  Nothing to do!\n";
        return;
    }

    foreach my $dir (@{$self->{"BUILDTREES"}}) {
        my $save_cwd = &getcwd();

        tprint "Getting package updates for $dir.\n";
        chdir($dir);
        &run_cmd("/usr/bin/revtool", "-g", "buildtree get ($dir) -> ");
        chdir($save_cwd);
    }
    tprint "Get step complete.\n";
}

sub
build()
{
    my $self = shift;
    my $common_params;

    if (!scalar(@{$self->{"BUILDTREES"}})) {
        wprint "Nothing to build!\n";
        return;
    } elsif ($self->get("CONFIG")->get("BUILD")) {
        tprint "Beginning build step.\n";
    } else {
        tprint "Skipping build step.\n";
        return;
    }

    $common_params = sprintf("%s -b orc --di '%s' -i '%s' -L '/src.rpm\$/=%s,/rpm\$/=%s' %s",
                             (($self->{"CONFIG"}->get("DEBUG")) ? ("--debug") : ("")),
                             $self->{"CONFIG"}->get("DEPSOLVER"), $self->{"CONFIG"}->get("BUILDROOT"),
                             $self->{"SRPMDIR"}, $self->{"ARCHDIR"}, $self->{"CONFIG"}->get("OPTIONS"));

    foreach my $tree (@{$self->{"BUILDTREES"}}) {
        my $build_tag = &basename($tree);
        my ($params, $err);

        tprint "Building $build_tag (log is $self->{LOGDIR}/$build_tag/build.log)....\n";
        &mkdirhier($self->{"LOGDIR"} . "/$build_tag");
        $params = sprintf("%s -s '%s' --builddir '%s/%s' -l '%s/%s/build.log'", $common_params, $tree, 
                          $self->{"LOGDIR"}, $build_tag, $self->{"LOGDIR"}, $build_tag);
        # Indent output 3 spaces for readability.
        $err = &run_cmd("/usr/bin/buildtool", $params, "   ", 0);
        if (($err > 0) && ($err <= 128)) {
            tprint "Built $err package(s).\n";
        } elsif (($err < 0) || (($err > 128) && $err < 256)) {
            if ($err > 128) {
                $err -= 256;
            }
            $err = -$err;
            eprint "$err package(s) failed to build.\n";
        } else {
            tprint "No packages needed building.\n";
        }
    }
    tprint "Build step complete.\n";
}

sub
createrepo()
{
    my $self = shift;

    if ($self->get("CONFIG")->get("CREATEREPO")) {
        tprint "Beginning createrepo step.\n";
    } else {
        tprint "Skipping createrepo step.\n";
        return;
    }

    foreach my $cmd ("yum-arch", "createrepo") {
        local *OUTFILE;
        my $outfile = $self->{"LOGDIR"} . "/$cmd.out";
        my @output;

        tprint "Creating repository metadata with $cmd.\n";
        @output = &run_cmd("/usr/bin/$cmd", "-vv -x '00_LOGS/*' " . $self->{"ARCHDIR"}, " -> ");
        if (open(OUTFILE, ">$outfile")) {
            print OUTFILE join("", @output);
            close(OUTFILE);
        } else {
            eprint "Unable to write to $outfile -- $!\n";
        }
    }
    tprint "Createrepo step complete.\n";
}

sub
flush()
{
    my $self = shift;
    my @output;

    if ($self->get("CONFIG")->get("FLUSH")) {
        tprint "Beginning flush step.\n";
    } else {
        tprint "Skipping flush step.\n";
        return;
    }

    foreach my $dir ($self->{"ARCHDIR"}, $self->{"SRPMDIR"}) {
        tprint "Finding outdated packages in $dir.\n";
        push @output, &run_cmd("/usr/bin/mzreposcan", "--old $dir", "outdated:  ");
    }
    #&nuke_tree(@output);

    tprint "Flush step complete.\n";
}

sub
sync()
{
    my $self = shift;
    my $sync_target;

    if ($self->get("CONFIG")->get("SYNC")) {
        tprint "Beginning sync step.\n";
    } else {
        tprint "Skipping sync step.\n";
        return;
    }

    $sync_target = $self->get("CONFIG")->get("SYNCTARGET");
    if ($sync_target) {
        my $params = sprintf("-Hav --delete-after %s %s %s", $self->{"ARCHDIR"}, $self->{"SRPMDIR"}, $sync_target);

        tprint "Syncing to $sync_target.\n";
        &run_cmd("/usr/bin/rsync", $params, "-sync-> ");
    } else {
        tprint "Sync step unavailable -- no target.\n";
    }
    tprint "Sync step complete.\n";
}

### Private methods.

sub
find_build_trees()
{
    my $self = shift;
    my @trees;

    foreach my $tree (split(':', $self->{"CONFIG"}->get("BUILDTREES"))) {
        foreach my $dir (glob($tree)) {
            if ((&basename($dir) eq "CVS") || (&basename($dir) eq ".svn")) {
                next;
            }
            if ($dir =~ /^([^\`\$\(\)]*)$/) {
                $dir = $1;
            } else {
                next;
            }
            if (-d $dir) {
                dprint "Found build tree $dir.\n";
                push @trees, $dir;
            }
        }
    }
    return @trees;
}

1;

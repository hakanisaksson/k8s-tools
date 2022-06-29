#!/usr/bin/env perl
#
# This script will dump selected k8s objects from all (or selected ns/project) as text files
# useful to save configuration in a human readable format before major upgrade
# Files are saved to working directory by default
#
use warnings;
use strict;
use Getopt::Long;
use Pod::Usage;
use File::Basename;

use FindBin;
use Data::Dumper;
#use YAML::Any qw'DumpFile LoadFile';

### Global vars
our %g = (
    DEBUG => 0,
    TEST => 0,
    OBJECTTYPES => ['deploy','sts','ds','svc','cm','secrets','sa','pvc','ep','quota','cronjobs','netpol','hpa','ingress'],
    FILETYPE => 'yaml',
    SAVEDIR => './',
    K8S_CMD => 'kubectl',
    );

my $USAGE="Dump all selected k8s objects to files.\nUsage $0: [-d] [-t] [-n ns]\n\noptions:\n  -d Debug\n  -t Test\n  -n Namespace (defaults to all)\n  -o Object types to export (comma separated string)\n  default: @{$g{OBJECTTYPES}}\n  -f Export Filetype (yaml or json)\n  -s Savedir\n";

sub debug {
    my $msg = shift;
    msg ("DEBUG: ".$msg) if $g{DEBUG};
}

sub msg {
    my $msg = shift(@_);
    printf "$msg\n";
}

sub error {
    msg ("ERROR: ".shift(@_));
    exit(1);
}

sub usage {
    print $USAGE."\n";
    exit(1);
}

sub parse_argv {

    my $objs = join(',', @{ $g{OBJECTTYPES} });
    GetOptions(
        "help" => sub { usage(); },
        "test" => \$g{TEST},
        "debug" => \$g{DEBUG},
        "ns|namespace|project=s" => \$g{NAMESPACE},
        "objects=s" => \$objs,
        "filetype=s" => \$g{FILETYPE},
        "savedir=s" => \$g{SAVEDIR},
        ) || usage();

    my @objectlist = split /\,/m, $objs;
    $g{OBJECTTYPES} = \@objectlist;

    debug("DEBUG=$g{DEBUG}");
    debug("TEST=$g{TEST}");
    debug("NAMESPACE=$g{NAMESPACE}") if $g{NAMESPACE};
    debug("OBJECTS=". join(',', @{ $g{OBJECTTYPES} } ));
    debug("SAVEDIR=$g{SAVEDIR}");

}

# Execute shell command
# Note: returns stdout as $d_opt{'stdout'} if you supply the function with a hashref as second arg
# Note: returns stdoutlines a arrayref if you supply the function with a hashref as second arg
# %d_opts:
#   verbose: print the command before executing it with shell (even when debug is off)
#   print: always print stdout from the command
#   halt: halt script executin on error
#   printonerr: will print stdout if the command failed
#   stderr: set to 0 to not combine stdout and stderr, stderr will be discarded
#   newline: replace newline (for example with  newline=>'<br>' for HTML line breaks
# Examples:
# shell("echo foo", {verbose => 1});
# shell("echo foo", \%sh_opts);
#
sub shell {
    my $cmd = shift;
    my $opt = shift;
    my %d_opt = ( verbose=>0, print=>0, test=>0, halt=>1, exitcode=>0, printonerr=>1, stderr=>1 );
    debug "shell( $cmd )";
    if (ref($opt) eq 'HASH') {
        foreach my $key ( keys(%{$opt})) {
            $d_opt{$key} = $opt->{$key};
        }
    }
    if ($d_opt{'test'} ne 1) {
        msg "$cmd" if $d_opt{'verbose'};
        my $out; 
        $out = qx($cmd 2>&1) if $d_opt{stderr};
        $out = qx($cmd ) if $d_opt{stderr} eq 0;
        $opt->{'exitcode'} = $? >> 8; 
        $out =~ s/\n/$d_opt{newline}/ if $d_opt{newline};
        my @outlines = split /^/m, $out; 
        s/\n\z// for @outlines;
        chomp($out);
        $opt->{'stdout'} = $out;
        $opt->{'stdoutlines'} = \@outlines;
        msg $out,"" if $d_opt{'print'};
        msg $out,"" if $d_opt{'printonerr'} and $opt->{'exitcode'};
        error("$cmd FAILED!") if $d_opt{'halt'} and $opt->{'exitcode'};
    } else {
        msg "[TEST] $cmd" if $d_opt{'verbose'};
        $opt->{'exitcode'} = 0;
    }
    return $opt->{'exitcode'};
}


sub dump_object {
    my $objtype = shift;
    my $objname = shift;
    my $ns = shift;
    my $filename = $g{SAVEDIR}.$ns.".".$objtype.".".$objname.".".$g{FILETYPE};
    my $cmd = "$g{K8S_CMD} get $objtype $objname -n $ns -o $g{FILETYPE} > $filename";
    my %sh_opts = ( verbose=>1, print=>$g{DEBUG}, test=>$g{TEST}, output=>'' );
    my $exitcode = shell($cmd, \%sh_opts);
    $filename="" if $exitcode ne 0;
    return $filename;
}

#
# Main
#
parse_argv();

my %sh_opts = ( verbose=>1, print => $g{DEBUG}, output=>'',stderr=>0 );

my @projects = ();
if ( $g{NAMESPACE} ) {
    @projects=$g{NAMESPACE};
} else {
    shell("$g{K8S_CMD} --no-headers=true get ns|awk '{print \$1}'", \%sh_opts);
    @projects=@{ $sh_opts{stdoutlines} };
}

foreach my $proj (@projects ) {
    debug "Namespace: $proj";
    foreach my $objtype ( @{ $g{OBJECTTYPES} } ) {
        shell("$g{K8S_CMD} --no-headers=true get $objtype -n $proj", \%sh_opts);
        foreach my $objline ( @{ $sh_opts{stdoutlines} } ) {
            my @objarr = split( /\s/, $objline);
            my $objname = $objarr[0];
            debug "Objectname: $objname";
            dump_object($objtype,$objname,$proj);
        }
    }
#    exit(1);
}

package openwrt;
##
## rancid 3.13
## Copyright (c) 1997-2019 by Henry Kilmer and John Heasley
## All rights reserved.
##
## This code is derived from software contributed to and maintained by
## Henry Kilmer, John Heasley, Andrew Partan,
## Pete Whiting, Austin Schutz, and Andrew Fort.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
## 1. Redistributions of source code must retain the above copyright
##    notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in the
##    documentation and/or other materials provided with the distribution.
## 3. Neither the name of RANCID nor the names of its
##    contributors may be used to endorse or promote products derived from
##    this software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY Henry Kilmer, John Heasley AND CONTRIBUTORS
## ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
## TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
## PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COMPANY OR CONTRIBUTORS
## BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##
## It is the request of the authors, but not a condition of license, that
## parties packaging or redistributing RANCID NOT distribute altered versions
## of the etc/rancid.types.base file nor alter how this file is processed nor
## when in relation to etc/rancid.types.conf.  The goal of this is to help
## suppress our support costs.  If it becomes a problem, this could become a
## condition of license.
# 
#  The expect login scripts were based on Erik Sherk's gwtn, by permission.
# 
#  The original looking glass software was written by Ed Kern, provided by
#  permission and modified beyond recognition.
# 
#  RANCID - Really Awesome New Cisco confIg Differ
#
#  openwrt.pm - OpenWRT ACS rancid procedures
#  (formerly Cyclades)

use 5.010;
use strict 'vars';
use warnings;
require(Exporter);
our @ISA = qw(Exporter);
$Exporter::Verbose=1;

use rancid 3.13;

our $ShowChassisSCB;			# Only run ShowChassisSCB() once
our $ShowChassisFirmware;		# Only run ShowChassisFirmware() once


@ISA = qw(Exporter rancid main);
#our @EXPORT = qw($VERSION)

# load-time initialization
sub import {
    0;
}

# post-open(collection file) initialization
sub init {
    # add content lines and separators
    ProcessHistory("","","","#RANCID-CONTENT-TYPE: $devtype\n#\n");

    0;
}

# main loop of input of device output
sub inloop {
    my($INPUT, $OUTPUT) = @_;
    my($cmd, $rval);

TOP: while(<$INPUT>) {
	tr/\015//d;
	if (/^Error:/) {
	    print STDOUT ("$host login error: $_");
	    print STDERR ("$host login error: $_") if ($debug);
	    $clean_run = 0;
	    last;
	}
	while (/[#\$]\s*($cmds_regexp)\s*$/) {
	    $cmd = $1;
	    if (!defined($prompt)) {
		$prompt = ($_ =~ /^([^#\$]+[#\$])/)[0];
		$prompt =~ s/([][}{)(\\\$])/\\$1/g;
		print STDERR ("PROMPT MATCH: $prompt\n") if ($debug);
	    }
	    print STDERR ("HIT COMMAND:$_") if ($debug);
	    if (! defined($commands{$cmd})) {
		print STDERR "$host: found unexpected command - \"$cmd\"\n";
		$clean_run = 0;
		last TOP;
	    }
	    $rval = &{$commands{$cmd}}($INPUT, $OUTPUT, $cmd);
	    delete($commands{$cmd});
	    if ($rval == -1) {
		$clean_run = 0;
		last TOP;
	    }
	}
	if (/[#\$]\s*exit$/) {
	    $clean_run = 1;
	    last;
	}
    }
}

# This routine parses "cat"
sub CatFile {
    my($INPUT, $OUTPUT, $cmd) = @_;
    print STDERR "    In CatFile: $_" if ($debug);
    my($catfile) = $cmd;

    $catfile =~ s/cat //;
    ProcessHistory("COMMENTS","","","# $catfile:\n");
    while (<$INPUT>) {
	tr/\015//d;
	last if (/^$prompt/);
	next if (/^(\s*|\s*$cmd\s*)$/);
	return(-1) if (/: Permission denied/);

	ProcessHistory("COMMENTS","","","$_");
    }
    ProcessHistory("COMMENTS","","","#\n");
    if ($catfile eq "/etc/passwd") {
	$found_end = 1; $clean_run = 1;
    }
    return(0);
}

# This routine parses "cat" w/ output commented
sub CatFileComment {
    my($INPUT, $OUTPUT, $cmd) = @_;
    print STDERR "    In CatFile: $_" if ($debug);
    my($catfile) = $cmd;

    $catfile =~ s/cat //;
    ProcessHistory("COMMENTS","","","# $catfile:\n");
    while (<$INPUT>) {
	tr/\015//d;
	last if (/^$prompt/);
	next if (/^(\s*|\s*$cmd\s*)$/);
	return(-1) if (/: Permission denied/);

	ProcessHistory("COMMENTS","","","# $_");
    }
    ProcessHistory("COMMENTS","","","#\n");
    if ($catfile eq "/etc/passwd") {
	$found_end = 1; $clean_run = 1;
    }
    return(0);
}

# This routine parses "cat /proc/meminfo"
sub Meminfo {
    my($INPUT, $OUTPUT, $cmd) = @_;
    print STDERR "    In Meminfo: $_" if ($debug);
    my($catfile) = $cmd;

    $catfile =~ s/cat //;
    ProcessHistory("COMMENTS","","","# $catfile:\n");
    while (<$INPUT>) {
	tr/\015//d;
	last if (/^$prompt/);
	next if (/^(\s*|\s*$cmd\s*)$/);
	return(-1) if (/: Permission denied/);

	if (/memtotal:\s+(\d+.*)/i) {
	    # MemTotal:       256944 kB
	    my($size) = bytes2human(human2bytes($1));
	    ProcessHistory("COMMENTS","","","# Memory: total $size\n");
	}
    }
    ProcessHistory("COMMENTS","","","#\n");
    return(0);
}

1;

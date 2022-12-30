#!/usr/bin/perl
# 
# File retrieval over SMTP - Tom Van de Wiele 2012
#
# Commands to be sent in the subject of an e-mail to your target address that has maildrop and the following .mailfilter file:
# .mailfilter:
#   to "| perl smtp-concierge.pl"
#
# Possible commands to be put in the subject of your e-mail:
#
# Getting a dir listing:
#   ls <path>
#
# Getting a file with no size restriction:
#   get file
#
# Getting a file and spliting it into chunks of 10M each. To be reassembled in Windows using: "copy /b +part1 +part2 bigfile" 
#   get bigfile 10             
#
# Notes:
#
# Postfix: main.cf 
#   message_size_limit 20480000
#   mailbox_command = /usr/bin/maildrop -d ${USER}
# 
# /etc/maildroprc:
#   include $HOME/.mailfilter
#
use strict;
use MIME::Lite;
use File::MimeInfo;

my $retval = time();
my $local_time = gmtime($retval);
my $dest;
open (F, ">>concierge.log") || die "Could not open log file conciere.log: $!\n";

while (<>) {

    if (/From:\s+.*<(.*)>$/) {
    	$dest = $1;
    	system("touch .dest");
    }
    elsif (/Subject:\s+(.*)/) {
	if (-e ".dest") {
		my $params = $1;
		my @paramarray = split(/\s+/, $params);
		my $cmd = $paramarray[0];
		my $filepath = $paramarray[1];
		my $threshold = $paramarray[2];

		print F "Parsed: " . $dest . "-" . $cmd . "-" . $filepath . "-" . $threshold . "--\n";
		print "Parsed: " . $dest . "-" . $cmd . "-" . $filepath . "-" . $threshold . "\n";
                       
		if ($cmd eq "ls" || $cmd eq "get") {

			if ($cmd eq "ls") {
				# if we get an argument to ls
				if (length $filepath > 0) {
					system ("rm .ls.log > /dev/null");
					system ("echo $filepath > .ls.log");
					system("ls -al $filepath >> .ls.log");
					print F "$local_time - Sent list of $filepath to $dest\n";
					sendit($dest,".ls.log");

				}
				else {
					system ("rm .ls.log > /dev/null");
					system ("pwd > .ls.log");
					system("ls -al >> .ls.log");
					print F "$local_time - Sent list of homedir to $dest\n";
					sendit($dest,".ls.log");
				}
			}
			elsif ($cmd eq "get") {
				if (-e $filepath ) {
				 	if ($threshold =~ /\d+/) {
						chomp($threshold);
    						my $maxkb = $threshold * 1024;
						my $filepath_kbsize = `ls -kl $filepath | awk '{ print \$5 }'`;
						chomp $filepath_kbsize;

						if ($filepath_kbsize <= $maxkb) { # within the limits permitted
							sendit ($dest,$filepath);
							print F "$local_time - Sent $filepath to $dest\n";
						}
						else { # too big, slice it up
							my $slicecmd = "split -b " . $threshold . "M " . $filepath . " c_";
							system($slicecmd);
							my @slices = `ls c_*`;
							my $total = @slices;
							if ($total != 0) {
								my $c = 0;
								foreach my $slice (@slices) {
									$c++;
									chomp($slice);
									my $newslice = $slice . "_part_" . $c . "_of_" . $total;
									print "newslice is $newslice\n";
									system("mv $slice $newslice");
									sendit ($dest,$newslice);
									print F "$local_time - Sent $filepath to $dest -> slice $newslice\n";
									print "Removing $newslice\n";
									system("rm $newslice");
								}
							}
							else {
								print "Error - no slices found\n";
								print F "Error - no slices found\n";
							}
						}
					}		

					else { # didn't receive a restriction so just send it
						sendit ($dest,$filepath);
						print F "$local_time - Sent $filepath to $dest\n";
					}
				}
				else {
					print F "$local_time - $filepath could not be sent to $dest due to file error - perms?\n";
					system("echo file_error > .file_error");
					sendit ($dest,".file_error");
					system("rm .file_error");
				}
			}                           
               		undef $dest;
               		undef $params;
               		system("rm .dest");
			}
		}		
	}
}

sub sendit {

	my $maildest = $_[0];
        my $mailfile = $_[1];
	my $msg;

        my $from = "concierge\@test.org";
        my $to = $maildest;
        my $subject = 'Your order is ready';
        my $mime = mimetype($mailfile);

	if ($mailfile eq ".ls.log") {
		my $lslog = `cat .ls.log`;
        	$msg = MIME::Lite->new(
                	From     => $from,
                	To       => $to,
                	Subject  => $subject,
			Data	 => $lslog
		);
	}
	else {
        	$msg = MIME::Lite->new(
                	From     => $from,
                	To       => $to,
                	Subject  => $subject,
                	Type     => $mime,
                	Path     => $mailfile
        	);
	}
        print F "Sent $mailfile to $maildest\n";
        $msg->send;
}

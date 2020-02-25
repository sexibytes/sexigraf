#!/usr/bin/perl -w
# If your copy of perl is not in /usr/bin, please adjust the line above.
#
# Copyright 1998-2011 VMware, Inc.  All rights reserved.
#
# Tar package manager for VMware

use strict;

# Use Config module to update VMware host-wide configuration file
# BEGINNING_OF_CONFIG_DOT_PM
# END_OF_CONFIG_DOT_PM

# BEGINNING_OF_UTIL_DOT_PL
#!/usr/bin/perl

use strict;
no warnings 'once'; # Warns about use of Config::Config in config.pl

# Moved out of config.pl to support $gOption in spacechk_answer
my %gOption;
# Moved from various scripts that include util.pl
my %gHelper;

#
# Table mapping vmware_product() strings to applicable services script or
# Upstart job name.
#

my %cProductServiceTable = (
   'viperl'  => 'vmware-viperl',
   'vicli'   => 'vmware-vcli',
);

my $cTerminalLineSize = 79;

# Strings for Block Appends.
my $cMarkerBegin = "# Beginning of the block added by the VMware software\n";
my $cMarkerEnd = "# End of the block added by the VMware software\n";

# util.pl Globals
my %gSystem;

# Needed to access $Config{...}, the Perl system configuration information.
require Config;

# Use the Perl system configuration information to make a good guess about
# the bit-itude of our platform.
sub is64BitUserLand {
  if ($Config::Config{archname} =~ /^(x86_64|amd64)-/) {
    return 1;
  } else {
    return 0;
  }
}

# Determine whether SELinux is enabled.
sub is_selinux_enabled {
   if (-x "/usr/sbin/selinuxenabled") {
      my $rv = system("/usr/sbin/selinuxenabled");
      return ($rv eq 0);
   } else {
      return 0;
   }
}

# Wordwrap system: append some content to the output
sub append_output {
  my $output = shift;
  my $pos = shift;
  my $append = shift;

  $output .= $append;
  $pos += length($append);
  if ($pos >= $cTerminalLineSize) {
    $output .= "\n";
    $pos = 0;
  }

  return ($output, $pos);
}

# Wordwrap system: deal with the next character
sub wrap_one_char {
  my $output = shift;
  my $pos = shift;
  my $word = shift;
  my $char = shift;
  my $reserved = shift;
  my $length;

  if (not (($char eq "\n") || ($char eq ' ') || ($char eq ''))) {
    $word .= $char;

    return ($output, $pos, $word);
  }

  # We found a separator.  Process the last word

  $length = length($word) + $reserved;
  if (($pos + $length) > $cTerminalLineSize) {
    # The last word doesn't fit in the end of the line. Break the line before
    # it
    $output .= "\n";
    $pos = 0;
  }
  ($output, $pos) = append_output($output, $pos, $word);
  $word = '';

  if ($char eq "\n") {
    $output .= "\n";
    $pos = 0;
  } elsif ($char eq ' ') {
    if ($pos) {
      ($output, $pos) = append_output($output, $pos, ' ');
    }
  }

  return ($output, $pos, $word);
}

# Wordwrap system: word-wrap a string plus some reserved trailing space
sub wrap {
  my $input = shift;
  my $reserved = shift;
  my $output;
  my $pos;
  my $word;
  my $i;

  if (!defined($reserved)) {
      $reserved = 0;
  }

  $output = '';
  $pos = 0;
  $word = '';
  for ($i = 0; $i < length($input); $i++) {
    ($output, $pos, $word) = wrap_one_char($output, $pos, $word,
                                           substr($input, $i, 1), 0);
  }
  # Use an artifical last '' separator to process the last word
  ($output, $pos, $word) = wrap_one_char($output, $pos, $word, '', $reserved);

  return $output;
}


# Print an error message and exit
sub error {
  my $msg = shift;

  print STDERR wrap($msg . 'Execution aborted.' . "\n\n", 0);

  exit 1;
}

# Convert a string to its equivalent shell representation
sub shell_string {
  my $single_quoted = shift;

  $single_quoted =~ s/'/'"'"'/g;
  # This comment is a fix for emacs's broken syntax-highlighting code
  return '\'' . $single_quoted . '\'';
}

# Create a temporary directory
#
# They are a lot of small utility programs to create temporary files in a
# secure way, but none of them is standard. So I wrote this
sub make_tmp_dir {
  my $prefix = shift;
  my $tmp;
  my $serial;
  my $loop;

  $tmp = defined($ENV{'TMPDIR'}) ? $ENV{'TMPDIR'} : '/tmp';

  # Don't overwrite existing user data
  # -> Create a directory with a name that didn't exist before
  #
  # This may never succeed (if we are racing with a malicious process), but at
  # least it is secure
  $serial = 0;
  for (;;) {
    # Check the validity of the temporary directory. We do this in the loop
    # because it can change over time
    if (not (-d $tmp)) {
      error('"' . $tmp . '" is not a directory.' . "\n\n");
    }
    if (not ((-w $tmp) && (-x $tmp))) {
      error('"' . $tmp . '" should be writable and executable.' . "\n\n");
    }

    # Be secure
    # -> Don't give write access to other users (so that they can not use this
    # directory to launch a symlink attack)
    if (mkdir($tmp . '/' . $prefix . $serial, 0755)) {
      last;
    }

    $serial++;
    if ($serial % 200 == 0) {
      print STDERR 'Warning: The "' . $tmp . '" directory may be under attack.' . "\n\n";
    }
  }

  return $tmp . '/' . $prefix . $serial;
}

# Call restorecon on the supplied file if selinux is enabled
sub restorecon {
  my $file = shift;

   if (is_selinux_enabled()) {
     system("/sbin/restorecon " . $file);
     # Return a 1, restorecon was called.
     return 1;
   }

  # If it is not enabled, return a -1, restorecon was NOT called.
  return -1;
}

# Insert a clearly delimited block to an unstructured text file
#
# Uses a regexp to find a particular spot in the file and adds
# the block at the first regexp match.
#
# Result:
#  1 on success
#  0 on no regexp match (nothing added)
#  -1 on failure
sub block_insert {
   my $file = shift;
   my $regexp = shift;
   my $begin = shift;
   my $block = shift;
   my $end = shift;
   my $line_added = 0;
   my $tmp_dir = make_tmp_dir('vmware-block-insert');
   my $tmp_file = $tmp_dir . '/tmp_file';

   if (not open(BLOCK_IN, '<' . $file) or
       not open(BLOCK_OUT, '>' . $tmp_file)) {
      return -1;
   }

   foreach my $line (<BLOCK_IN>) {
     if ($line =~ /($regexp)/ and not $line_added) {
       print BLOCK_OUT $begin . $block . $end;
       $line_added = 1;
     }
     print BLOCK_OUT $line;
   }

   if (not close(BLOCK_IN) or not close(BLOCK_OUT)) {
     return -1;
   }

   if (not system(shell_string($gHelper{'mv'}) . " $tmp_file $file")) {
     return -1;
   }

   remove_tmp_dir($tmp_dir);

   # Call restorecon to set SELinux policy for this file.
   restorecon($file);

   # Our return status is 1 if successful, 0 if nothing was added.
   return $line_added
}


# Test if specified file contains line matching regular expression
# Result:
#  undef on failure
#  first matching line on success
sub block_match {
   my $file = shift;
   my $block = shift;
   my $line = undef;

   if (open(BLOCK, '<' . $file)) {
      while (defined($line = <BLOCK>)) {
         chomp $line;
         last if ($line =~ /$block/);
      }
      close(BLOCK);
   }
   return defined($line);
}


# Remove all clearly delimited blocks from an unstructured text file
# Result:
#  >= 0 number of blocks removed on success
#  -1 on failure
sub block_remove {
   my $src = shift;
   my $dst = shift;
   my $begin = shift;
   my $end = shift;
   my $count;
   my $state;

   if (not open(SRC, '<' . $src)) {
      return -1;
   }

   if (not open(DST, '>' . $dst)) {
      close(SRC);
      return -1;
   }

   $count = 0;
   $state = 'outside';
   while (<SRC>) {
      if      ($state eq 'outside') {
         if ($_ eq $begin) {
            $state = 'inside';
            $count++;
         } else {
            print DST $_;
         }
      } elsif ($state eq 'inside') {
         if ($_ eq $end) {
            $state = 'outside';
         }
      }
   }

   if (not close(DST)) {
      close(SRC);
      # Even if close fails, make sure to call restorecon on $dst.
      restorecon($dst);
      return -1;
   }

   # $dst file has been modified, call restorecon to set the
   #  SELinux policy for it.
   restorecon($dst);

   if (not close(SRC)) {
      return -1;
   }

   return $count;
}

# Similar to block_remove().  Find the delimited text, bracketed by $begin and $end,
# and filter it out as the file is written out to a tmp file. Typicaly, block_remove()
# is used in the pattern:  create tmp dir, create tmp file, block_remove(), mv file,
# remove tmp dir. This encapsulates the pattern.
sub block_restore {
  my $src_file = shift;
  my $begin_marker = shift;
  my $end_marker = shift;
  my $tmp_dir = make_tmp_dir('vmware-block-restore');
  my $tmp_file = $tmp_dir . '/tmp_file';
  my $rv;

  $rv = block_remove($src_file, $tmp_file, $begin_marker, $end_marker);
  if ($rv >= 0) {
    system(shell_string($gHelper{'mv'}) . ' ' . $tmp_file . ' ' . $src_file);
  }
  remove_tmp_dir($tmp_dir);

  # Call restorecon on the source file.
  restorecon($src_file);

  return $rv;
}

# Remove leading and trailing whitespaces
sub remove_whitespaces {
  my $string = shift;

  $string =~ s/^\s*//;
  $string =~ s/\s*$//;
  return $string;
}

# Ask a question to the user and propose an optional default value
# Use this when you don't care about the validity of the answer
sub query {
    my $message = shift;
    my $defaultreply = shift;
    my $reserved = shift;
    my $reply;
    my $default_value = $defaultreply eq '' ? '' : ' [' . $defaultreply . ']';
    my $terse = 'no';

    # Allow the script to limit output in terse mode.  Usually dictated by
    # vix in a nested install and the '--default' option.
    if (db_get_answer_if_exists('TERSE')) {
      $terse = db_get_answer('TERSE');
      if ($terse eq 'yes') {
        $reply = remove_whitespaces($defaultreply);
        return $reply;
      }
    }

    # Reserve some room for the reply
    print wrap($message . $default_value, 1 + $reserved);

    # This is what the 1 is for
    print ' ';

    if ($gOption{'default'} == 1) {
      # Simulate the enter key
      print "\n";
      $reply = '';
    } else {
      $reply = <STDIN>;
      $reply = '' unless defined($reply);
      chomp($reply);
    }

    print "\n";
    $reply = remove_whitespaces($reply);
    if ($reply eq '') {
      $reply = $defaultreply;
    }
    return $reply;
}

# Execute the command passed as an argument
# _without_ interpolating variables (Perl does it by default)
sub direct_command {
  return `$_[0]`;
}

# If there is a pid for this process, consider it running.
sub check_is_running {
  my $proc_name = shift;
  my $rv = system(shell_string($gHelper{'pidof'}) . " " . $proc_name . " > /dev/null");
  return $rv eq 0;
}

# Emulate a simplified ls program for directories
sub internal_ls {
  my $dir = shift;
  my @fn;

  opendir(LS, $dir) or return ();
  @fn = grep(!/^\.\.?$/, readdir(LS));
  closedir(LS);

  return @fn;
}


# Emulate a simplified dirname program
sub internal_dirname {
  my $path = shift;
  my $pos;

  $path = dir_remove_trailing_slashes($path);

  $pos = rindex($path, '/');
  if ($pos == -1) {
    # No slash
    return '.';
  }

  if ($pos == 0) {
    # The only slash is at the beginning
    return '/';
  }

  return substr($path, 0, $pos);
}

sub internal_dirname_vcli {
  my $path = shift;
  my $pos;

  $path = dir_remove_trailing_slashes($path);

  $pos = rindex($path, '/');
  if ($pos == -1) {
    # No slash
    return '.';
  }

  my @arr1 = split(/\//, $path);

  # if "/bin" is top directory return parent directory as base directory
  if ( $arr1[scalar(@arr1) -1] eq "bin" ) {
    return substr($path, 0, $pos);
  }

  return $path;
}

##
# vmware_service_basename
#
# Simple product name -> service script map accessor.  (See
# $cProductServiceTable.)
#
# @return Service script basename on valid product, undef otherwise.
#
sub vmware_service_basename {
   return $cProductServiceTable{vmware_product()};
}


##
# vmware_service_path
#
# @return Valid service script's path relative to INITSCRIPTSDIR unless
# vmware_product() has no such script.
#

sub vmware_service_path {
   my $basename = vmware_service_basename();

   return $basename
      ? join('/', db_get_answer('INITSCRIPTSDIR'), $basename)
      : undef;
}


##
# removeDuplicateEntries
#
# Removes duplicate entries from a given string and delimeter
# @param - string to cleanse
# @param - the delimeter
# @returns - String without duplicate entries.
#
sub removeDuplicateEntries {
   my $string = shift;
   my $delim = shift;
   my $newStr = '';

   if (not defined $string or not defined $delim) {
      error("Missing parameters in removeDuplicateEntries\n.");
   }

   foreach my $subStr (split($delim, $string)) {
      if ($newStr !~ /(^|$delim)$subStr($delim|$)/ and $subStr ne '') {
	 if ($newStr ne '') {
	    $newStr = join($delim, $newStr, $subStr);
	 } else {
	    $newStr = $subStr;
	 }
      }
   }

   return $newStr;
}


##
# addEntDBList
#
# Adds an entry to a list within the DB.  This function also removes
# duplicate entries from the list.
#
sub addEntDBList {
   my $dbKey = shift;
   my $ent = shift;

   if (not defined $dbKey or $dbKey eq '') {
      error("Bad dbKey value in addEntDBList.\n");
   }

   if ($ent =~ m/,/) {
      error("New list entry can not contain commas.\n");
   }

   my $list = db_get_answer_if_exists($dbKey);
   my $newList = $list ? join(',', $list, $ent) : $ent;
   $newList = removeDuplicateEntries($newList, ',');
   db_add_answer($dbKey, $newList);
}


##
# internalMv
#
# mv command for Perl that works across file system boundaries.  The rename
# function may not work across FS boundaries and I don't want to introduce
# a dependency on File::Copy (at least not with this installer/configurator).
#
sub internalMv {
   my $src = shift;
   my $dst = shift;
   return system("mv $src $dst");
}


##
# addTextToKVEntryInFile
#
# Despite the long and confusing function name, this function is very
# useful.  If you have a key value entry in a file, this function will
# allow you to add an entry to it based on a special regular expression.
# This regular expression must capture the pre-text, the values, and any
# post text by using regex back references.
# @param - Path to file
# @param - The regular expression.  See example below...
# @param - The delimeter between values
# @param - The new entry
# @returns - 1 if the file was modified, 0 otherwise.
#
# For example, if I have
#   foo = 'bar,baz';
# I can add 'biz' to the values by calling this function with the proper
# regex.  A regex for this would look like '^(foo = ')(\.*)(;)$'.  The
# delimeter is ',' and the entry would be 'biz'.  The result should look
# like
#   foo = 'bar,baz,biz';
#
# NOTE1:  This function will only add to the first KV pair found.
#
sub addTextToKVEntryInFile {
   my $file = shift;
   my $regex = shift;
   my $delim = shift;
   my $entry = shift;
   my $modified = 0;
   my $firstPart;
   my $origValues;
   my $newValues;
   my $lastPart;

   $regex = qr/$regex/;

   if (not open(INFILE, "<$file")) {
      error("addTextToKVEntryInFile: File $file not found\n");
   }

   my $tmpDir = make_tmp_dir('vmware-file-mod');
   my $tmpFile = join('/', $tmpDir, 'new-file');
   if (not open(OUTFILE, ">$tmpFile")) {
      error("addTextToKVEntryInFile: Failed to open output file\n");
   }

   foreach my $line (<INFILE>) {
      if ($line =~ $regex and not $modified) {
         # We have a match.  $1 and $2 have to be deifined; $3 is optional
         if (not defined $1 or not defined $2) {
            error("addTextToKVEntryInFile: Bad regex.\n");
         }
         $firstPart = $1;
         $origValues = $2;
         $lastPart = ((defined $3) ? $3 : '');
         chomp $firstPart;
         chomp $origValues;
         chomp $lastPart;

         # Modify the origValues and remove duplicates
         # Handle white space as well.
         if ($origValues =~ /^\s*$/) {
            $newValues = $entry;
         } else {
            $newValues = join($delim, $origValues, $entry);
            $newValues = removeDuplicateEntries($newValues, $delim);
         }
         print OUTFILE join('', $firstPart, $newValues, $lastPart, "\n");

         $modified = 1;
      } else {
         print OUTFILE $line;
      }
   }

   close(INFILE);
   close(OUTFILE);

   return 0 unless (internalMv($tmpFile, $file));
   remove_tmp_dir($tmpDir);

   # Our return status is 1 if successful, 0 if nothing was added.
   return $modified;
}


##
# removeTextInKVEntryInFile
#
# Does exactly the opposite of addTextToKVEntryFile.  It will remove
# all instances of the text entry in the first KV pair that it finds.
# @param - Path to file
# @param - The regular expression.  See example above...
# @param - The delimeter between values
# @param - The entry to remove
# @returns - 1 if the file was modified, 0 otherwise.
#
# NOTE1:  This function will only remove from the first KV pair found.
#
sub removeTextInKVEntryInFile {
   my $file = shift;
   my $regex = shift;
   my $delim = shift;
   my $entry = shift;
   my $modified = 0;
   my $firstPart;
   my $origValues;
   my $newValues = '';
   my $lastPart;

   $regex = qr/$regex/;

   if (not open(INFILE, "<$file")) {
      error("removeTextInKVEntryInFile:  File $file not found\n");
   }

   my $tmpDir = make_tmp_dir('vmware-file-mod');
   my $tmpFile = join('/', $tmpDir, 'new-file');
   if (not open(OUTFILE, ">$tmpFile")) {
      error("removeTextInKVEntryInFile:  Failed to open output file $tmpFile\n");
   }

   foreach my $line (<INFILE>) {
      if ($line =~ $regex and not $modified) {
         # We have a match.  $1 and $2 have to be deifined; $3 is optional
         if (not defined $1 or not defined $2) {
            error("removeTextInKVEntryInFile:  Bad regex.\n");
         }
         $firstPart = $1;
         $origValues = $2;
         $lastPart = ((defined $3) ? $3 : '');
         chomp $firstPart;
         chomp $origValues;
         chomp $lastPart;

         # Modify the origValues and remove duplicates
         # If $origValues is just whitespace, no need to modify $newValues.
         if ($origValues !~ /^\s*$/) {
            foreach my $existingEntry (split($delim, $origValues)) {
               if ($existingEntry ne $entry) {
                  $newValues = join($delim, $newValues, $existingEntry);
               }
            }
         }
         print OUTFILE join('', $firstPart, $newValues, $lastPart, "\n");

         $modified = 1;
      } else {
         print OUTFILE $line;
      }
   }

   close(INFILE);
   close(OUTFILE);

   return 0 unless (internalMv($tmpFile, $file));
   remove_tmp_dir($tmpDir);

   # Our return status is 1 if successful, 0 if nothing was added.
   return $modified;
}

# END_OF_UTIL_DOT_PL

# Needed for WIFSIGNALED and WTERMSIG
use POSIX;
use Config;


# Constants
my $cInstallerFileName = 'vmware-install.pl';
my $cModuleUpdaterFileName = 'install.pl';
my $cRegistryDir = '/etc/vmware';
my $cInstallerMainDB = $cRegistryDir . '/locations';
my $cInstallerObject = $cRegistryDir . '/installer.sh';
my $cConfFlag = $cRegistryDir . '/not_configured';
# Constant defined as the smallest vmnet that is allowed
my $gMinVmnet = '0';
# Linux doesn't allow more than 7 characters in the names of network
# interfaces. We prefix host only interfaces with 'vmnet' leaving us only 2
# characters.
# Constant defined as the largest vmnet that is allowed
my $gMaxVmnet = '99';

# Has the uninstaller been installed?
my $gIsUninstallerInstalled;

# Hash of multi architecture supporting products
my %multi_arch_products;
# Hash of product conflicts
my %product_conflicts;

# BEGINNING OF THE SECOND LIBRARY FUNCTIONS
# Global variables
my $gRegistryDir;
my $gFirstCreatedDir = undef;
my $gStateDir;
my $gInstallerMainDB;
my $gInstallerObject;
my $gConfFlag;
my $gUninstallerFileName;
my $gConfigurator;
my $gConfig;
my $gConfigFile;
my @gOldUninstallers = '';

my %gDBAnswer;
my %gDBFile;
my %gDBDir;
my %gDBLink;
my %gDBMove;
my %gDBModule;


my @gLower; # list of modules whose versions are less than the shipped
my @gMissing; # list of modules not installed

# list of files that are config failes users may modify
my %gDBUserModified;
my %gDBConfig;

#
# db_clear
#
# Unsets all variables modified in the db_load process
#
sub db_clear {
  undef %gDBAnswer;
  undef %gDBFile;
  undef %gDBDir;
  undef %gDBLink;
  undef %gDBMove;
  undef %gDBConfig;
  undef %gDBUserModified;
  undef %gDBModule;
}

#
# db_load
#
# Reads in the database file specified in $gInstallerMainDB and loads the values
# into the 7 variables mentioned below.
#
sub db_load {
  db_clear();
  open(INSTALLDB, '<' . $gInstallerMainDB)
    or error('Unable to open the installer database '
             . $gInstallerMainDB . ' in read-mode.' . "\n\n");
  while (<INSTALLDB>) {
    chomp;
    if (/^answer (\S+) (.+)$/) {
      $gDBAnswer{$1} = $2;
    } elsif (/^answer (\S+)/) {
      $gDBAnswer{$1} = '';
    } elsif (/^remove_answer (\S+)/) {
      delete $gDBAnswer{$1};
    } elsif (/^file (.+) (\d+)$/) {
      $gDBFile{$1} = $2;
    } elsif (/^file (.+)$/) {
      $gDBFile{$1} = 0;
    } elsif (/^remove_file (.+)$/) {
      delete $gDBFile{$1};
    } elsif (/^directory (.+)$/) {
      $gDBDir{$1} = '';
    } elsif (/^module (.+)$/) {
      $gDBModule{$1} = '';
    } elsif (/^remove_directory (.+)$/) {
      delete $gDBDir{$1};
    } elsif (/^link (\S+) (\S+)/) {
      $gDBLink{$2} = $1;
    } elsif (/^move (\S+) (\S+)/) {
      $gDBMove{$2} = $1;
    } elsif (/^config (\S+)/) {
      $gDBConfig{$1} = 'config';
    } elsif (/^modified (\S+)/) {
      $gDBUserModified{$1} = 'modified';
    }
  }
  close(INSTALLDB);
}

# Open the database on disk in append mode
sub db_append {
  if (not open(INSTALLDB, '>>' . $gInstallerMainDB)) {
    error('Unable to open the installer database ' . $gInstallerMainDB . ' in append-mode.' . "\n\n");
  }
  # Force a flush after every write operation.
  # See 'Programming Perl', p. 110
  select((select(INSTALLDB), $| = 1)[0]);
}

# Add a file to the tar installer database
# flags:
#  0x1 write time stamp
sub db_add_file {
  my $file = shift;
  my $flags = shift;

  if ($flags & 0x1) {
    my @statbuf;

    @statbuf = stat($file);
    if (not (defined($statbuf[9]))) {
      error('Unable to get the last modification timestamp of the destination file ' . $file . '.' . "\n\n");
    }

    $gDBFile{$file} = $statbuf[9];
    print INSTALLDB 'file ' . $file . ' ' . $statbuf[9] . "\n";
  } else {
    $gDBFile{$file} = 0;
    print INSTALLDB 'file ' . $file . "\n";
  }
}

# Remove a file from the tar installer database
sub db_remove_file {
  my $file = shift;

  print INSTALLDB 'remove_file ' . $file . "\n";
  delete $gDBFile{$file};
}

# Remove a directory from the tar installer database
sub db_remove_dir {
  my $dir = shift;

  print INSTALLDB 'remove_directory ' . $dir . "\n";
  delete $gDBDir{$dir};
}

# Determine if a file belongs to the tar installer database
sub db_file_in {
  my $file = shift;

  return defined($gDBFile{$file});
}

# Determine if a directory belongs to the tar installer database
sub db_dir_in {
  my $dir = shift;

  return defined($gDBDir{$dir});
}

# Return the timestamp of an installed file
sub db_file_ts {
  my $file = shift;

  return $gDBFile{$file};
}

# Add a directory to the tar installer database
sub db_add_dir {
  my $dir = shift;

  $gDBDir{$dir} = '';
  print INSTALLDB 'directory ' . $dir . "\n";
}

# Remove an answer from the tar installer database
sub db_remove_answer {
  my $id = shift;

  if (defined($gDBAnswer{$id})) {
    print INSTALLDB 'remove_answer ' . $id . "\n";
    delete $gDBAnswer{$id};
  }
}

# add an module from the tar installer database
sub db_add_module {
  my $module = shift;

  $gDBModule{$module} = '';
  print INSTALLDB 'module ' . $module . "\n";
}

# Remove an module from the tar installer database
sub db_remove_module {
  my $module = shift;

  print INSTALLDB 'remove_module ' . $module . "\n";
  delete $gDBModule{$module};
}

# Add an answer to the tar installer database
sub db_add_answer {
  my $id = shift;
  my $value = shift;

  db_remove_answer($id);
  $gDBAnswer{$id} = $value;
  print INSTALLDB 'answer ' . $id . ' ' . $value . "\n";
}

# Retrieve an answer that must be present in the database
sub db_get_answer {
  my $id = shift;

  if (not defined($gDBAnswer{$id})) {
    error('Unable to find the answer ' . $id . ' in the installer database ('
          . $gInstallerMainDB . '). You may want to re-install '
          . vmware_product_name() . "." .  "\n\n");
  }

  return $gDBAnswer{$id};
}

# Retrieves an answer if it exists in the database, else returns undef;
sub db_get_answer_if_exists {
  my $id = shift;
  if (not defined($gDBAnswer{$id})) {
    return undef;
  }
  if ($gDBAnswer{$id} eq '') {
    return undef;
  }
  return $gDBAnswer{$id};
}

# Save the tar installer database
sub db_save {
  close(INSTALLDB);
}

# Parse an installer database and return a specified answer if it exists
sub ext_db_get_answer_if_exists {
   # parse arguments
   my $InstallDB = shift;
   my $id = shift;

   # temporary database
   my %DBAnswer;
   my %DBFile;
   my %DBDir;
   my %DBLink;
   my %DBMove;

   # Open the installdb, or error.
   open(INSTDB, '<' . $InstallDB)
      or error('Unable to open the installer database '
               . $InstallDB . ' in read-mode.' . "\n\n");

   # parse the installdb
   while (<INSTDB>) {
      chomp;
      if (/^answer (\S+) (.+)$/) {
         $DBAnswer{$1} = $2;
      } elsif (/^answer (\S+)/) {
         $DBAnswer{$1} = '';
      } elsif (/^remove_answer (\S+)/) {
         delete $DBAnswer{$1};
      } elsif (/^file (.+) (\d+)$/) {
         $DBFile{$1} = $2;
      } elsif (/^file (.+)$/) {
         $DBFile{$1} = 0;
      } elsif (/^remove_file (.+)$/) {
         delete $DBFile{$1};
      } elsif (/^directory (.+)$/) {
         $DBDir{$1} = '';
      } elsif (/^remove_directory (.+)$/) {
         delete $DBDir{$1};
      } elsif (/^link (\S+) (\S+)/) {
         $DBLink{$2} = $1;
      } elsif (/^move (\S+) (\S+)/) {
         $DBMove{$2} = $1;
      }
   }
   close(INSTDB);

   # return the requested answer key value
   if (not defined($DBAnswer{$id})) {
      return undef;
   } elsif($DBAnswer{$id} eq '') {
      return undef;
   } else {
      return $DBAnswer{$id};
   }
}

# uninstall a product
#
# returns true if product was successfully uninstalled, false otherwise
sub uninstall_product {
   my $product = shift;

   # try to use an installer object if it exists
   my $InstallerObject = $cRegistryDir . '-' . $product . '/installer.sh';
   if ( -x $InstallerObject ) {
      system(shell_string($InstallerObject) . ' uninstall');
      if (!($? >> 8 eq 0)) {
         print wrap("warning: could not uninstall $product with its installer object\n\n", 0);
      } else {
         return 1;
      }
   }

   # check for an uninstaller in BINDIR
   my $InstallDB = $cRegistryDir . '-' . $product . '/locations';
   if ( -e $InstallDB ) {
      my $bindir = ext_db_get_answer_if_exists($InstallDB, 'BINDIR');
      if (not(defined($bindir))) {
         print wrap("warning: could not find uninstaller for $product", 0);
         return 0;
      }
      my $uninstaller = $bindir . '/vmware-uninstall-' . $product . '.pl';
      if (! -x $uninstaller) {
         print wrap("warning: could not find uninstaller for $product", 0);
         return 0;
      }
      system(shell_string($uninstaller));
      if (!($? >> 8 eq 0)) {
         print wrap("warning: could not uninstall $product with its uninstaller", 0);
      } else {
         return 1;
      }
   }

   # nothing worked
   return 0;
}

# END OF THE SECOND LIBRARY FUNCTIONS

# BEGINNING OF THE LIBRARY FUNCTIONS
# Global variables
my %gAnswerSize;
my %gCheckAnswerFct;

# Tell if the user is the super user
sub is_root {
  return $> == 0;
}

# Contrary to a popular belief, 'which' is not always a shell builtin command.
# So we can not trust it to determine the location of other binaries.
# Moreover, SuSE 6.1's 'which' is unable to handle program names beginning with
# a '/'...
#
# Return value is the complete path if found, or '' if not found
sub internal_which {
  my $bin = shift;

  if (substr($bin, 0, 1) eq '/') {
    # Absolute name
    if ((-f $bin) && (-x $bin)) {
      return $bin;
    }
  } else {
    # Relative name
    my @paths;
    my $path;

    if (index($bin, '/') == -1) {
      # There is no other '/' in the name
      @paths = split(':', $ENV{'PATH'});
      foreach $path (@paths) {
   my $fullbin;

   $fullbin = $path . '/' . $bin;
   if ((-f $fullbin) && (-x $fullbin)) {
     return $fullbin;
   }
      }
    }
  }

  return '';
}

# Check the validity of an answer whose type is yesno
# Return a clean answer if valid, or ''
sub check_answer_binpath {
  my $answer = shift;
  my $source = shift;

  my $fullpath = internal_which($answer);
  if (not ("$fullpath" eq '')) {
    return $fullpath;
  }

  if ($source eq 'user') {
    print wrap('The answer "' . $answer . '" is invalid. It must be the complete name of a binary file.' . "\n\n", 0);
  }
  return '';
}
$gAnswerSize{'binpath'} = 20;
$gCheckAnswerFct{'binpath'} = \&check_answer_binpath;

# Prompts the user if a binary is not found
# Return value is:
#  '': the binary has not been found
#  the binary name if it has been found
sub DoesBinaryExist_Prompt {
  my $bin = shift;
  my $answer;

  $answer = check_answer_binpath($bin, 'default');
  if (not ($answer eq '')) {
    return $answer;
  }

  if (get_answer('Setup is unable to find the "' . $bin . '" program on your machine. Please make sure it is installed. Do you want to specify the location of this program by hand?', 'yesno', 'yes') eq 'no') {
    return '';
  }

  return get_answer('What is the location of the "' . $bin . '" program on your machine?', 'binpath', '');
}

# chmod() that reports errors
sub safe_chmod {
  my $mode = shift;
  my $file = shift;

  if (chmod($mode, $file) != 1) {
    error('Unable to change the access rights of the file ' . $file . '.' . "\n\n");
  }
}

# Install a file permission
sub install_permission {
  my $src = shift;
  my $dst = shift;
  my @statbuf;
  my $mode;
  @statbuf = stat($src);
  if (not (defined($statbuf[2]))) {
    error('Unable to get the access rights of source file "' . $src . '".' . "\n\n");
  }

  # ACE packages may be installed from CD/DVDs, which don't have the same file
  # permissions of the original package (no write permission). Since these
  # packages are installed by a user under a single directory, it's safe to do
  # 'u+w' on everything.
  $mode = $statbuf[2] & 07777;
  if (vmware_product() eq 'acevm') {
    $mode |= 0200;
  }
  safe_chmod($mode, $dst);
}

# Emulate a simplified sed program
# Return 1 if success, 0 if failure
# XXX as a side effect, if the string being replaced is '', remove
# the entire line.  Remove this, once we have better "block handling" of
# our config data in config files.
sub internal_sed {
  my $src = shift;
  my $dst = shift;
  my $append = shift;
  my $patchRef = shift;
  my @patchKeys;

  if (not open(SRC, '<' . $src)) {
    return 0;
  }
  if (not open(DST, (($append == 1) ? '>>' : '>') . $dst)) {
    return 0;
  }

  @patchKeys = keys(%$patchRef);
  if ($#patchKeys == -1) {
    while(defined($_ = <SRC>)) {
      print DST $_;
    }
  } else {
    while(defined($_ = <SRC>)) {
      my $patchKey;
      my $del = 0;

      foreach $patchKey (@patchKeys) {
        if (s/$patchKey/$$patchRef{$patchKey}/g) {
          if ($_ eq "\n") {
            $del = 1;
          }
        }
      }
      next if ($del);
      print DST $_;
    }
  }

  close(SRC);
  close(DST);
  return 1;
}

# Check if a file name exists
sub file_name_exist {
  my $file = shift;

  # Note: We must test for -l before, because if an existing symlink points to
  #       a non-existing file, -e will be false
  return ((-l $file) || (-e $file))
}

# Check if a file name already exists and prompt the user
# Return 0 if the file can be written safely, 1 otherwise
sub file_check_exist {
  my $file = shift;

  if (not file_name_exist($file)) {
    return 0;
  }

  my $lib_dir = $Config{'archlib'} || $ENV{'PERL5LIB'} || $ENV{'PERLLIB'} ;
  my $share_dir = $Config{'installprivlib'} || $ENV{'PERLSHARE'} ;

  # donot ovewrite perl module files
  if($file =~ m/$lib_dir|$share_dir/) {
    return 1;
  }


  # The default must make sure that the product will be correctly installed
  # We give the user the choice so that a sysadmin can perform a normal
  # install on a NFS server and then answer 'no' NFS clients
  return (get_answer('The file ' . $file . ' that this program was about to '
                     . 'install already exists. Overwrite?',
                     'yesno', 'yes') eq 'yes') ? 0 : 1;
}

# Install one file
# flags are forwarded to db_add_file()
sub install_file {
  my $src = shift;
  my $dst = shift;
  my $patchRef = shift;
  my $flags = shift;

  uninstall_file($dst);
  # because any modified config file is not removed but left in place,
  # it will already exist and coveniently avoid processing here.  It's
  # not added to the db so it will not be uninstalled next time.
  if (file_check_exist($dst)) {
    return;
  }
  # The file could be a symlink to another location. Remove it
  unlink($dst);
  if (not internal_sed($src, $dst, 0, $patchRef)) {
    error('Unable to copy the source file ' . $src . ' to the destination file ' . $dst . '.' . "\n\n");
  }
  db_add_file($dst, $flags);
  install_permission($src, $dst);
}

# mkdir() that reports errors
sub safe_mkdir {
  my $file = shift;

  if (mkdir($file, 0000) == 0) {
    print wrap('Unable to create the directory ' . $file . '.' . "\n\n", 0);
    uninstall_file($gInstallerObject);
    uninstall_file($gInstallerMainDB);
    exit 1;
  }
}

# Remove trailing slashes in a dir path
sub dir_remove_trailing_slashes {
  my $path = shift;

  for(;;) {
    my $len;
    my $pos;

    $len = length($path);
    if ($len < 2) {
      # Could be '/' or any other character. Ok.
      return $path;
    }

    $pos = rindex($path, '/');
    if ($pos != $len - 1) {
      # No trailing slash
      return $path;
    }

    # Remove the trailing slash
    $path = substr($path, 0, $len - 1)
  }
}


# Create a hierarchy of directories with permission 0755
# flags:
#  0x1 write this directory creation in the installer database
# Return 1 if the directory existed before
sub create_dir {
  my $dir = shift;
  my $flags = shift;

  if (-d $dir) {
    return 1;
  }

  if (index($dir, '/') != -1) {
    create_dir(internal_dirname($dir), $flags);
  }
  safe_mkdir($dir);
  if ($flags & 0x1) {
    db_add_dir($dir);
  }
  safe_chmod(0755, $dir);
  return 0;
}

# Get a valid non-persistent answer to a question
# Use this when the answer shouldn't be stored in the database
sub get_answer {
  my $msg = shift;
  my $type = shift;
  my $default = shift;
  my $answer;

  if (not defined($gAnswerSize{$type})) {
    die 'get_answer(): type ' . $type . ' not implemented :(' . "\n\n";
  }
  for (;;) {
    $answer = check_answer(query($msg, $default, $gAnswerSize{$type}), $type, 'user');
    if (not ($answer eq '')) {
      return $answer;
    }
    if ($gOption{'default'} == 1) {
      error('Invalid default answer!' . "\n");
    }
  }
}

# Get a valid persistent answer to a question
# Use this when you want an answer to be stored in the database
sub get_persistent_answer {
  my $msg = shift;
  my $id = shift;
  my $type = shift;
  my $default = shift;
  my $isdefault = shift;
  my $answer;

  if (defined($gDBAnswer{$id}) && !defined($isdefault) ) {
    # There is a previous answer in the database
    $answer = check_answer($gDBAnswer{$id}, $type, 'db');
    if (not ($answer eq '')) {
      # The previous answer is valid. Make it the default value
      $default = $answer;
    }
  }

  $answer = get_answer($msg, $type, $default);
  db_add_answer($id, $answer);
  return $answer;
}

# Check available space when asking the user for destination directory.
sub spacechk_answer_vcli {
  my $msg = shift;
  my $type = shift;
  my $default = shift;
  my $srcDir = shift;
  my $id = shift;
  my $ifdefault = shift;
  my $answer;
  my $space = -1;
  my $packagedir = -1;

  while ($space < 0 || $packagedir < 0) {

    if (!defined($id)) {
      $answer = get_answer($msg, $type, $default);
    } else {
      if (!defined($ifdefault)) {
         $answer = get_persistent_answer($msg, $id, $type, $default);
      } else {
         $answer = get_persistent_answer($msg, $id, $type, $default, $ifdefault);
      }
    }

    my $pkgPath = getcwd();
    if ($answer && ($pkgPath eq $answer)) {
      my $lmsg;
      $lmsg = 'You have selected product installation directory  ' . $answer . ' to install the executable files.';
      if ($gOption{'default'} == 1) {
        error($lmsg . ".\n");
      }
      print wrap($lmsg . " Please choose another directory.\n\n ", 0);
    } else {
      $packagedir = 1;
    }

    # XXX check $answer for a null value which can happen with the get_answer
    # in config.pl but not with the get_answer in pkg_mgr.pl.  Moving these
    # (get_answer, get_persistent_answer) routines into util.pl eventually.
    if ($answer && ($space = check_disk_space($srcDir, $answer)) < 0) {
      my $lmsg;
      $lmsg = 'There is insufficient disk space available in ' . $answer
              . '.  Please make at least an additional ' . -$space
              . 'KB available';
      error($lmsg . ".\n");
    }
  }
  return $answer;
}

# Find a suitable backup name and backup a file
sub backup_file {
  my $file = shift;
  my $i;

  for ($i = 0; $i < 100; $i++) {
    if (not file_name_exist($file . '.old.' . $i)) {
      my %patch;

      undef %patch;
      if (internal_sed($file, $file . '.old.' . $i, 0, \%patch)) {
         print wrap('File ' . $file . ' is backed up to ' . $file .
         '.old.' . $i . '.' . "\n\n", 0);
      } else {
         print STDERR wrap('Unable to backup the file ' . $file .
         ' to ' . $file . '.old.' . $i .'.' . "\n\n", 0);
      }
      return;
    }
  }

   print STDERR wrap('Unable to backup the file ' . $file .
   '. You have too many backups files. They are files of the form ' .
   $file . '.old.N, where N is a number. Please delete some of them.' . "\n\n", 0);
}

# Uninstall a file previously installed by us
sub uninstall_file {
  my $file = shift;

  if (not db_file_in($file)) {
    # Not installed by this program
    return;
  }

  if (file_name_exist($file)) {
    # If this file is a config file and already exists or is modified,
    # leave it in place to save the users' modifications.
    if (defined($gDBConfig{$file}) && defined($gDBUserModified{$file})) {
      db_remove_file($file);
      return;
    }
    if (db_file_ts($file)) {
      my @statbuf;

      @statbuf = stat($file);
      if (defined($statbuf[9])) {
        if (db_file_ts($file) != $statbuf[9]) {
          # Modified since this program installed it
          if (defined($gDBConfig{$file})) {
            # Because config files need to survive the install and uninstall
            # process.
            $gDBUserModified{$file} = 'modified';
            db_remove_file($file);
            return;
          } else {
            backup_file($file);
          }
        }
      } else {
        print STDERR wrap('Unable to get the last modification timestamp of '
                          . 'the file ' . $file . '.' . "\n\n", 0);
      }
    }

    if (not unlink($file)) {
      error('Unable to remove the file "' . $file . '".' . "\n");
    } else {
      db_remove_file($file);
    }

  } elsif (vmware_product() ne 'acevm') {
    print wrap('This program previously created the file ' . $file . ', and '
               . 'was about to remove it.  Somebody else apparently did it '
               . 'already.' . "\n\n", 0);
    db_remove_file($file);
  }
}

# Uninstall a directory previously installed by us
sub uninstall_dir {
  my $dir = shift;
  my $force = shift;

  if (not db_dir_in($dir)) {
    # Not installed by this program
    return;
  }

  if (-d $dir) {
    if ($force eq '1') {
      system(shell_string($gHelper{'rm'}) . ' -rf ' . shell_string($dir));
    } elsif (not rmdir($dir)) {
      print wrap('This program previously created the directory ' . $dir
                 . ', and was about to remove it. Since there are files in '
                 . 'that directory that this program did not create, it will '
                 . 'not be removed.' . "\n\n", 0);
      if (   defined($ENV{'VMWARE_DEBUG'})
          && ($ENV{'VMWARE_DEBUG'} eq 'yes')) {
        system('ls -AlR ' . shell_string($dir));
      }
    }
  } elsif (vmware_product() ne 'acevm') {
    print wrap('This program previously created the directory ' . $dir
               . ', and was about to remove it. Somebody else apparently did '
               . 'it already.' . "\n\n", 0);
  }

  db_remove_dir($dir);
}

# Return the version of VMware
sub vmware_version {
  my $buildNr;

  $buildNr = '6.7.0 build-8156551';
  return remove_whitespaces($buildNr);
}

# Check the validity of an answer whose type is yesno
# Return a clean answer if valid, or ''
sub check_answer_yesno {
  my $answer = shift;
  my $source = shift;

  if (lc($answer) =~ /^y(es)?$/) {
    return 'yes';
  }

  if (lc($answer) =~ /^n(o)?$/) {
    return 'no';
  }

  if ($source eq 'user') {
    print wrap('The answer "' . $answer . '" is invalid. It must be one of "y" or "n".' . "\n\n", 0);
  }
  return '';
}
$gAnswerSize{'yesno'} = 3;
$gCheckAnswerFct{'yesno'} = \&check_answer_yesno;

# Check the validity of an answer based on its type
# Return a clean answer if valid, or ''
sub check_answer {
  my $answer = shift;
  my $type = shift;
  my $source = shift;

  if (not defined($gCheckAnswerFct{$type})) {
    die 'check_answer(): type ' . $type . ' not implemented :(' . "\n\n";
  }
  return &{$gCheckAnswerFct{$type}}($answer, $source);
}

# END OF THE LIBRARY FUNCTIONS

# Emulate a simplified basename program
sub internal_basename {
  return substr($_[0], rindex($_[0], '/') + 1);
}

# Set the name of the main /etc/vmware* directory.
sub initialize_globals {
  my $dirname = shift;

  $gRegistryDir = '/etc/vmware-vcli';
  @gOldUninstallers = qw( /etc/vmware-vicli/installer.sh /etc/vmware-rcli/installer.sh);
  $gUninstallerFileName = 'vmware-uninstall-vSphere-CLI.pl';

  $gStateDir = $gRegistryDir . '/state';
  $gInstallerMainDB = $gRegistryDir . '/locations';
  $gInstallerObject = $gRegistryDir . '/installer.sh';
  $gConfFlag = $gRegistryDir . '/not_configured';

  $gOption{'default'} = 0;
  $gOption{'nested'} = 0;
  $gOption{'upgrade'} = 0;
  $gOption{'eula_agreed'} = 0;
  $gOption{'create_shortcuts'} = 1;

  if (defined $gConfigFile) {
      load_config();
  }
}

sub load_config() {
    $gConfig = new VMware::Config;
    $gConfig->readin($gConfigFile);
}

# Set up the location of external helpers
sub initialize_external_helpers {
  my $program;
  my @programList;

  if (not defined($gHelper{'more'})) {
    $gHelper{'more'} = '';
    if (defined($ENV{'PAGER'})) {
      my @tokens;

      # The environment variable sometimes contains the pager name _followed by
      # a few command line options_.
      #
      # Isolate the program name (we are certain it does not contain a
      # whitespace) before dealing with it.
      @tokens = split(' ', $ENV{'PAGER'});
      $tokens[0] = DoesBinaryExist_Prompt($tokens[0]);
      if (not ($tokens[0] eq '')) {
        # Whichever PAGER the user has, we want them to have the same
        # behavior, that is automatically exit the first time it reaches
        # end-of-file.
        # This is the behavior of `more', regardless of the command line
        # options. If `less' is used, however, the option '-E' should be
        # specified (see bug 254808).
        if ($tokens[0] eq internal_which('less')) {
           push(@tokens,'-E');
        }
        $gHelper{'more'} = join(' ', @tokens); # This is _already_ a shell string
      }
    }
    if ($gHelper{'more'} eq '') {
      $gHelper{'more'} = DoesBinaryExist_Prompt('more');
      if ($gHelper{'more'} eq '') {
        error('Unable to continue.' . "\n\n");
      }
      $gHelper{'more'} = shell_string($gHelper{'more'}); # Save it as a shell string
    }
  }

  @programList = ('tar', 'sed', 'rm', 'lsmod', 'umount', 'mv', 'gzip',
                  'uname', 'mount', 'du', 'df', 'depmod', 'ldd');

  foreach $program (@programList) {
    if (not defined($gHelper{$program})) {
      $gHelper{$program} = DoesBinaryExist_Prompt($program);
      if ($gHelper{$program} eq '') {
        error('Unable to continue.' . "\n\n");
      }
    }
  }

  # Used for removing links that were not added as files to the database.
  $gHelper{'insserv'} = internal_which('insserv');
  $gHelper{'chkconfig'} = internal_which('chkconfig');
  $gHelper{'update-rc.d'} = internal_which('update-rc.d');
}

# Check the validity of an answer whose type is dirpath
# Return a clean answer if valid, or ''
sub check_answer_dirpath {
  my $answer = shift;
  my $source = shift;

  $answer = dir_remove_trailing_slashes($answer);

  if (substr($answer, 0, 1) ne '/') {
      print wrap('The path "' . $answer . '" is a relative path. Please enter '
		 . 'an absolute path.' . "\n\n", 0);
      return '';
  }

  if (-d $answer) {
    # The path is an existing directory
    return $answer;
  }

  # The path is not a directory
  if (file_name_exist($answer)) {
    if ($source eq 'user') {
      print wrap('The path "' . $answer . '" exists, but is not a directory.'
                 . "\n\n", 0);
    }
    return '';
  }

  # The path does not exist
  if ($source eq 'user') {
    return (get_answer('The path "' . $answer . '" does not exist currently. '
                       . 'This program is going to create it, including needed '
                       . 'parent directories. Is this what you want?',
                       'yesno', 'yes') eq 'yes') ? $answer : '';
  } else {
    return $answer;
  }
}
$gAnswerSize{'dirpath'} = 20;
$gCheckAnswerFct{'dirpath'} = \&check_answer_dirpath;

# Check the validity of an answer whose type is existdirpath
# Return a clean answer if valid, or ''
sub check_answer_existdirpath {
  my $answer = shift;
  my $source = shift;

  $answer = dir_remove_trailing_slashes($answer);

  if (substr($answer, 0, 1) ne '/') {
      print wrap('The path "' . $answer . '" is a relative path. Please enter '
		 . 'an absolute path.' . "\n\n", 0);
      return '';
  }

  if (-d $answer) {
    # The path is an existing directory
    return $answer;
  }

  # The path is not a directory
  if (file_name_exist($answer)) {
    if ($source eq 'user') {
      print wrap('The path "' . $answer . '" exists, but is not a directory.'
		 . "\n\n", 0);
    }
  } else {
    if ($source eq 'user') {
      print wrap('The path "' . $answer . '" is not an existing directory.'
		 . "\n\n", 0);
    }
  }
  return '';
}
$gAnswerSize{'existdirpath'} = 20;
$gCheckAnswerFct{'existdirpath'} = \&check_answer_existdirpath;

# Check the validity of an answer whose type is username
# Return a clean answer if valid, or ''
sub check_answer_username {
  my $answer = shift;
  my $source = shift;

  my ($name, $passwd, $uid, $gid) = getpwnam($answer);
  if (!defined $name) {
    print wrap('The answer '. $answer . ' is invalid. Please enter a valid '
	       . 'user on this system.' . "\n\n", 0);
    return '';
  }
  return $answer;
}

$gAnswerSize{'username'} = 8;
$gCheckAnswerFct{'username'} = \&check_answer_username;

# Install one symbolic link
sub install_symlink {
  my $to = shift;
  my $name = shift;

  uninstall_file($name);
  if (file_check_exist($name)) {
    return;
  }
  # The file could be a symlink to another location.  Remove it
  unlink($name);
  if (not symlink($to, $name)) {
    error('Unable to create symbolic link "' . $name . '" pointing to file "'
          . $to . '".' . "\n\n");
  }
  db_add_file($name, 0);
}

# Create symlink (recursively)
sub install_bin_symlink {
  my $src_dir = shift;
  my $dst_dir = shift;
  my $file;
  
  foreach $file (internal_ls($src_dir)) {
    my $src = $src_dir . '/' . $file;
    my $src_loc = '/usr/bin/' . $file;
    my $dst_loc = $dst_dir . '/' . $file;
    if (-l $dst_loc) {
      install_symlink(readlink($dst_loc), $src_loc);
    } else {
      install_symlink($dst_loc, $src_loc);
    }
  }
  return 0;
}

# Install one directory (recursively)
# flags are forwarded to install_file calls and recursive install_dir calls
sub install_dir {
  my $src_dir = shift;
  my $dst_dir = shift;
  my $patchRef = shift;
  my $flags = shift;
  my $is_suid_dir;
  if (@_ < 1) {
    $is_suid_dir=0;
  } else {
    $is_suid_dir=shift;
  }
  my $file;
  my $dir_existed = create_dir($dst_dir, $flags);

  if ($dir_existed) {
    my @statbuf;

    @statbuf = stat($dst_dir);
    if (not (defined($statbuf[2]))) {
      error('Unable to get the access rights of destination directory "' . $dst_dir . '".' . "\n\n");
    }

    # Was bug 15880
    if (   ($statbuf[2] & 0555) != 0555
        && get_answer('Current access permissions on directory "' . $dst_dir
                      . '" will prevent some users from using '
                      . vmware_product_name()
                      . '. Do you want to set those permissions properly?',
                      'yesno', 'yes') eq 'yes') {
      safe_chmod(($statbuf[2] & 07777) | 0555, $dst_dir);
    }
  } else {
    install_permission($src_dir, $dst_dir);
  }

  if ($is_suid_dir)
  {
    # Here is where we check (if necessary) for file ownership in this folder to actually "work"
    # This is due to the fact that if the destdir is on a squash_root nfs mount, things fail miserably
    my $tmpfilenam = $dst_dir . '/' . 'vmware_temp_'.$$;
    if (not open(TESTFILE, '>' . $tmpfilenam)) {
      error('Unable to write into ' . $dst_dir . "\n\n");
    }
    print TESTFILE 'garbage';
    close(TESTFILE);
    safe_chmod(04755, $tmpfilenam);
    my @statbuf;
    @statbuf = stat($tmpfilenam);
    if ($statbuf[4]!=0 or ($statbuf[2] & 07000)!=04000) {
      if (! $dir_existed)
      {
        # Remove the directory if we had to create it.
        # XXX This could leave a dangling hierarhcy
        # but that is a more complicated issue.
        rmdir($dst_dir);
      }
      # Ask the user what to do, default to 'no'(abort install) to avoid infinite loop on --default.
      my $answer = get_answer('The installer was unable to set-uid to root on files in ' . $dst_dir . '.  Would you like ' .
                              'to select a different directory?  If you select no, the install will be aborted.','yesno','no');
      if ($answer eq 'no')
      {
        # We have to clean up the ugliness before we abort.
        uninstall();
        error ('User aborted install.');
      }
      return 1;
    }
    unlink($tmpfilenam);
  }

  foreach $file (internal_ls($src_dir)) {
    my $src_loc = $src_dir . '/' . $file;
    my $dst_loc = $dst_dir . '/' . $file;

    if (-l $src_loc) {
      install_symlink(readlink($src_loc), $dst_loc);
    } elsif (-d $src_loc) {
      install_dir($src_loc, $dst_loc, $patchRef, $flags);
    } else {
      install_file($src_loc, $dst_loc, $patchRef, $flags);
    }
  }
  return 0;
}

# Display the end-user license agreement
sub show_EULA {
  if ((not defined($gDBAnswer{'EULA_AGREED'}))
      || (db_get_answer('EULA_AGREED') eq 'no')) {
    query('You must read and accept the ' . vmware_product_name()
          . ' End User License Agreement to continue.'
          .  "\n" . 'Press enter to display it.', '', 0);

    open(EULA, './doc/EULA') ||
      error("$0: can't open EULA file: $!\n");

    my $origRecordSeparator = $/;
    undef $/;

    my $eula = <EULA>;
    close(EULA);

    $/ = $origRecordSeparator;

    $eula =~ s/(.{50,76})\s/$1\n/g;

    # Trap the PIPE signal to avoid broken pipe errors on RHEL4 U4.
    local $SIG{PIPE} = sub {};

    open(PAGER, '| ' . $gHelper{'more'}) ||
      error("$0: can't open $gHelper{'more'}: $!\n");
    print PAGER $eula . "\n";
    close(PAGER);

    print "\n";

    # Make sure there is no default answer here
    if (get_answer('Do you accept? (yes/no)', 'yesno', '') eq 'no') {
      print wrap('Please try again when you are ready to accept.' . "\n\n", 0);
      uninstall_file($gInstallerMainDB);
      exit 1;
    }
    print wrap('Thank you.' . "\n\n", 0);
  }
}

#BEGIN UNINSTALLER SECTION
# Uninstaller section for old style MUI installer: Most of this code is
# directly copied over from the old installer
my %gConfData;

# Read the config vars to our internal array
sub readConfig {
  my $registryFile = shift;
  if (open(OLDCONFIG, $registryFile)) {
    # Populate our array with everthing from the conf file.
    while (<OLDCONFIG>) {
      m/^\s*(\S*)\s*=\s*(\S*)/;
      $gConfData{$1} = $2;
    }
    close(OLDCONFIG);
    return(1);
  }
  return(0);
}

# END UNINSTALLER SECTION
sub get_home_dir {
   return (getpwnam(get_user()))[7] || (getpwuid($<))[7];
}

sub get_user {
   if (defined $ENV{'SUDO_USER'}) {
      return $ENV{'SUDO_USER'};
   }
   else {
      return $ENV{'USER'};
   }
}

# Install a tar package or upgrade an already installed tar package
sub install_or_upgrade {
  print wrap('Installing ' . vmware_longname() . ".\n\n", 0);

  ## if (vmware_product() eq 'vicli')
  install_content_vicli();

  print wrap('The installation of ' . vmware_longname()
             . ' completed successfully. '
             . 'You can decide to remove this software from your system at any '
             . 'time by invoking the following command: "'
             . db_get_answer('BINDIR') . '/' . $gUninstallerFileName . '".'
             . "\n\n", 0);

  if (vmware_product() eq 'vicli') {
    print wrap('This installer has successfully installed both '
               . vmware_product_name() . ' and the vSphere SDK for Perl.'
               . "\n\n", 0);
  }

}

# Uninstall files, directories and modules beginning with a given prefix
sub uninstall_prefix {
  my $prefix = shift;
  my $prefix_len;
  my $file;
  my $dir;
  my $module;

  $prefix_len = length($prefix);

  # Remove all files beginning with $prefix
  foreach $file (keys %gDBFile) {
    if (substr($file, 0, $prefix_len) eq $prefix) {
      uninstall_file($file);
    }
  }

  # Remove all directories beginning with $prefix
  # We sort them by decreasing order of their length, to ensure that we will
  # remove the inner ones before the outer ones
  foreach $dir (sort {length($b) <=> length($a)} keys %gDBDir) {
    if (substr($dir, 0, $prefix_len) eq $prefix) {
      uninstall_dir($dir,'1');
    }
  }

  # Remove all modules beginning with $prefix
  foreach $module (keys %gDBModule) {
    if (substr($module, 0, $prefix_len) eq $prefix) {
      if ( eval "require $module" ) {
        uninstall_perlmodule($module);
      }
    }
  }
}

sub uninstall_perlmodule {
  my $mod = shift;
  my $inst;
  my $packfile;
  my $skipped_packfile;
  my @mod_files; 

  if ( eval { require ExtUtils::Installed } ) {
     $inst = ExtUtils::Installed->new();
     eval { @mod_files= $inst->files($mod); };
     if ($@) {
       return;
     } else { 
       foreach my $item (sort(@mod_files)) {
         unlink $item;
       }
         if ($mod =~ /^Compress::/){
           #To removing IO::Compress module
           $mod = "IO::Compress";
           eval { @mod_files= $inst->files($mod); };
           if ($@) {
             return;
           } else {
              foreach my $skipped_item (sort(@mod_files)) {
              unlink $skipped_item;
           }
              }
              if ( eval { require ExtUtils::packlist } ) {
                 $skipped_packfile = $inst->packlist($mod)->packlist_file();
                 unlink $skipped_packfile;
              }
         }
     }
  }

  if ( eval { require ExtUtils::packlist } ) {
     $packfile = $inst->packlist($mod)->packlist_file();
     unlink $packfile;
  }
  db_remove_module($mod);
}

# Uninstall a tar package
sub uninstall {
  my $eclipse_dir = db_get_answer_if_exists('ECLIPSEDIR');
  if (defined $eclipse_dir) {
     system($gHelper{'rm'} . ' -rf ' . $eclipse_dir . '/../configuration/com.vmware.bfg*');
  }

  uninstall_prefix('');
}

#
# Given two strings where the format is a tuple of things separated by a '.'
# if more than one, i.e. X.Y, A.B.C, Z, determine which of the strings is
# of higher value representing a more recent version of a lib, say.
# This works 0.0.0b style lettered version strings.
#
# Result:
# If the Base String is greater than the New string, return 1.
# If the two are equal, return 0
# If the Base String is less than the New string, return -1.
sub compare_dot_version_strings {
   my ($base, $new) = @_;
   my @base_digits = split(/\./, $base);
   my @new_digits = split(/\./, $new);

   my $i = 0;

   # Use the smaller limit value so we dont go outside the bounds of the array.
   my $limit = $#base_digits > $#new_digits ? $#new_digits : $#base_digits;

   while (($i < $limit) && ($base_digits[$i] eq $new_digits[$i])) {
      $i++;
   }

   my $result;
   if (($i == $limit) && ($base_digits[$i] eq $new_digits[$i])) {
      if ($#base_digits == $#new_digits) {
         $result = 0;
      } elsif ($#base_digits < $#new_digits) {
         # if the new_digits string is longer, then it is greater.
         $result = -1;
      } else {
         # Else the base_digits is longer, and thus is greater
         $result = 1;
      }
   } else {
      if ($base_digits[$i] gt $new_digits[$i]) {
         $result = 1;
      } else {
         $result = -1;
      }
   }
   return $result;
}


sub install_content_vicli_perl {
   my %patch;
   my $shipped_ssl_version = '0.9.8';
   my $installed_ssl_version = '0';
   my $minimum_ssl_version = '0.9.7';
   my $ssleay_installed = 0;
   my $link_ssleay = 0;
   my $linker_installed = `which ld`;
   my $minimum_libxml_version = '2.6.26';
   my $installed_libxml_version = '0';

   my $OpenSSL_installed = 0;
   my $LibXML2_installed = 0;
   my $OpenSSL_dev_installed = 0;
   my $libxml_perl_installed = 1;

   my $e2fsprogs_installed = 0;
   my $e2fsprogs_version = '0';
   my $minimum_e2fsprogs_version = '1.38';
   my $e2fsprogs_devel_installed = 0;
   my $internet_available = 0;
   my $install_rhel55_local = 0;

   my $vicliName = vmware_product_name();
   if ($] < 5.008) {
      error($vicliName . " requires Perl version 5.8 or later.\n\n");
   }

   unless(direct_command("perldoc -V 2> /dev/null")) {
      print wrap("warning: " . $vicliName . " requires Perldoc.\n Please install perldoc.\n\n");
   }


   # Determine version of libxml2 that's installed.
   foreach my $line (direct_command("ldconfig -v 2> /dev/null")) {
      chomp($line);
      # Only find lines related to libxml2
      if ($line !~ /->\s+libxml2\.so\.(\d+\.?\d*\.?\d*[a-zA-Z]*)/) {
         next;
      }

      if (compare_dot_version_strings($installed_libxml_version, $1) <= 0) {
         # report back the highest installed version of libxml2
         $installed_libxml_version = $1;
      }
   }

   if ( $installed_libxml_version eq '0' ) {
      print wrap("libxml2 is not installed on the system \n");
   } else {
      $LibXML2_installed = 1;
   }

   if (compare_dot_version_strings($installed_libxml_version, $minimum_libxml_version) < 0) {
       print wrap("libxml2 $minimum_libxml_version is required for " . $vicliName . ". \n" .
		   "Please install libxml2 $minimum_libxml_version or greater.\n\n");
       $LibXML2_installed = 0;
   }

   # Determine greatest version of OpenSSL that's installed.
   # We need version 0.9.7 or greater.  We ship 0.9.8
   # Since we are root, lets use ldconfig to view the installed libraries
   foreach my $line (direct_command("ldconfig -v 2> /dev/null")) {
      chomp($line);
      # Only find lines related to libssl
      if ($line !~ /->\s+libssl\.so\.(\d+\.?\d*\.?\d*[a-zA-Z]*)/) {
         next;
      }
      if (compare_dot_version_strings($installed_ssl_version, $1) <= 0) {
         # report back the highest installed version of libssl
         $installed_ssl_version = $1;
      }
   }

   if ( $installed_ssl_version eq '0' ) {
      print wrap(" OpenSSL is not installed on the system \n");
   } else {
      $OpenSSL_installed = 1;
   }

   if (compare_dot_version_strings($installed_ssl_version, $minimum_ssl_version) < 0) {
	   print wrap("OpenSSL $minimum_ssl_version is required for encrypted connections.\n" .
                 "Please install OpenSSL and OpenSSL-devel version $minimum_ssl_version or greater.\n\n", 0);
   }

   # check for e2fsprogs-devel installed
   if ( direct_command("cat /etc/*-release | grep -i ubuntu") || direct_command("cat /proc/version | grep -i ubuntu") ) {
       my $libssl_dev = direct_command("dpkg-query -W -f='\${Version}\n' '*ssl-dev*' ");
       if ( $libssl_dev ) {
		   $OpenSSL_dev_installed = 1;
       }   else {
            print wrap("libssl-dev $minimum_ssl_version is required for encrypted connections.\n" .
                  "Please install libssl-dev version $minimum_ssl_version or greater.\n\n", 0);
       }

       my $e2fsprogs = direct_command("dpkg-query -W -f='\${Version}\n' e2fsprogs ");
       if ($e2fsprogs) {
          my @e2fs = split('-', $e2fsprogs);
          $e2fsprogs_version = $e2fs[0];
          $e2fsprogs_installed = 1;
       }

       if ( direct_command("dpkg-query -W -f'\${Status}\n' libxml-libxml-perl | grep not-installed ") ) {
           print wrap("libxml-libxml-perl package is not installed on the system. libxml-libxml-perl package must be installed for use by " . $vicliName . ":\n\n", 0);
           $libxml_perl_installed = 0;
       }

   } else {
      my @openssl_dev = direct_command("rpm -qa | grep 'ssl-dev'");

      foreach my $line (@openssl_dev)  {
         chomp($line);
         if ($line =~ /[a-zA-Z]*ssl-dev[a-zA-Z]*-(\d+\.?\d*\.?\d*[a-zA-Z]*)/) {
            $OpenSSL_dev_installed = 1;
         }
      }

      if (! $OpenSSL_dev_installed) {
         print wrap("Openssl-devel is not installed on the system.\n" .
              "openssl-devel $minimum_ssl_version is required for encrypted connections.\n" .
              "Please install openssl-devel version $minimum_ssl_version or greater.\n\n", 0);
      }

      my @e2fsprogs = split('\n', direct_command("rpm -qa | grep 'e2fsprogs'"));
      foreach my $line (@e2fsprogs)  {
         chomp($line);
         if ($line =~ /e2fsprogs-+([0-9\.]+)/) {
            $e2fsprogs_version = "$1";
            $e2fsprogs_installed = 1;
         }
         if ( ! $install_rhel55_local ) {
            if ( -e "/etc/SuSE-release" ) {
               if ($line =~ /e2fsprogs-devel-+([0-9\.]+)/) {
                  $e2fsprogs_devel_installed = 1;
               }
            }
         }
      }
   }

   if (! $e2fsprogs_installed ) {
      print wrap("e2fsprogs is not installed on the system \n\n", 0);
   }

   if (compare_dot_version_strings($e2fsprogs_version, $minimum_e2fsprogs_version) < 0) {
       print wrap("e2fsprogs $minimum_e2fsprogs_version is required for UUID.\n" .
                 "Please install e2fsprogs $minimum_e2fsprogs_version or greater.\n\n", 0);
   }

   if ( ( ! $install_rhel55_local ) && ( -e "/etc/SuSE-release" ) && (! $e2fsprogs_devel_installed ) ) {
      print wrap("e2fsprogs-devel is not installed on the system \n\n", 0);
      uninstall_file($gInstallerMainDB);
      exit 1;
   }

   # Exit the installation if OpenSSL or LibXML or e2fsprogs not installed on system.
   if ( ! $OpenSSL_installed || ! $LibXML2_installed || ! $e2fsprogs_installed || ! $OpenSSL_dev_installed || ! $libxml_perl_installed ) {
      uninstall_file($gInstallerMainDB);
      exit 1;
   }

   # Make sure we are using a valid path for Crypt-SSLeay
   # Valid paths are
   # Crypt-SSLeay-0.55-0.9.7
   # Crypt-SSLeay-0.55-0.9.8
   # Use 0.9.8 for newer ssl libs
   my $SSLeay_ssl_version = '0.9.7';
   if (compare_dot_version_strings('0.9.8', $installed_ssl_version) <= 0) {
      # Then use 0.9.8
      $SSLeay_ssl_version = '0.9.8';
   }

   my @modules = (
    ## CPAN modules for vAPI
    # Modules directly consumed by vAPI
    {'module' => 'Time::Piece',                   'version' => '1.31',     'path' => 'Time-Piece-1.31'},
     # vCLI Modules
    {'module' => 'Archive::Zip',                  'version' => '1.28',     'path' => 'Archive-Zip-1.28'},
    {'module' => 'ExtUtils::Installed',           'version' => '1.54',     'path' => 'ExtUtils-Install-1.54'},
    {'module' => 'Path::Class',                   'version' => '0.33',     'path' => 'Path-Class-0.33'},
    {'module' => 'Try::Tiny',                     'version' => '0.28',     'path' => 'Try-Tiny-0.28'},
    {'module' => 'Crypt::SSLeay',                 'version' => '0.72',     'path' => "Crypt-SSLeay-0.72-$SSLeay_ssl_version"},
    {'module' => 'version',                       'version' => '0.78',     'path' => 'version-0.78'},
    {'module' => 'Data::Dumper',                  'version' => '2.121',    'path' => 'Data-Dumper-2.121'},
    {'module' => 'HTML::Parser',                  'version' => '3.60',     'path' => 'HTML-Parser-3.60'},
    {'module' => 'UUID',                          'version' => '0.27',     'path' => 'UUID-0.27'},
    {'module' => 'XML::SAX',                      'version' => '0.99',     'path' => 'XML-SAX-0.99'},
    {'module' => 'XML::NamespaceSupport',         'version' => '1.12',     'path' => 'XML-NamespaceSupport-1.12'},
    {'module' => 'XML::LibXML::Common',           'version' => '2.0129',   'path' => 'XML-LibXML-Common-2.0129'},
    {'module' => 'XML::LibXML',                   'version' => '2.0129',   'path' => 'XML-LibXML-2.0129'},
    {'module' => 'LWP',                           'version' => '6.26',     'path' => 'libwww-perl-6.26'},
    {'module' => 'LWP::Protocol::https',          'version' => '6.07',     'path' => 'LWP-Protocol-https-6.07'},
    {'module' => 'Socket6 ',                      'version' => '0.28',     'path' => 'Socket6-0.28'},
    {'module' => 'Text::Template',                'version' => '1.47',     'path' => 'Text-Template-1.47'},
    {'module' => 'IO::Socket::INET6',             'version' => '2.72',     'path' => 'IO-Socket-INET6-2.72'},
    {'module' => 'Net::INET6Glue',                'version' => '0.603',    'path' => 'Net-INET6Glue-0.603'},
    {'module' => 'Net::HTTP',                     'version' => '6.09',     'path' => 'Net-HTTP-6.09'}
   );

   my @vmware_modules = (
     {'module' => 'VMware::VIRuntime',     'version' => '0.9',    'path' => 'VMware'},
     {'module' => 'WSMan::StubOps',        'version' => '0.1',    'path' => 'WSMan'}
   );

   my @included_modules = (
     # Modules consumed by vAPI
     {'module' => 'Time::Piece',           'version' => '1.31',   'path' => 'Time-Piece-1.31'},
     # vCLI Modules
     {'module' => 'Crypt::SSLeay',         'version' => '0.72',   'path' => "Crypt-SSLeay-0.72-$SSLeay_ssl_version"},
     {'module' => 'version',               'version' => '0.78',   'path' => 'version-0.78'},
     {'module' => 'Archive::Zip',          'version' => '1.28',   'path' => 'Archive-Zip-1.28'},
     {'module' => 'Data::Dumper',          'version' => '2.121',  'path' => 'Data-Dumper-2.121'},
     {'module' => 'HTML::Parser',          'version' => '3.60',   'path' => 'HTML-Parser-3.60'},
     {'module' => 'UUID',                  'version' => '0.27',   'path' => 'UUID-0.27'},
     {'module' => 'XML::LibXML::Common',   'version' => '2.0129', 'path' => 'XML-LibXML-Common-2.0129'},
     {'module' => 'XML::NamespaceSupport', 'version' => '1.12',   'path' => 'XML-NamespaceSupport-1.12'},
     {'module' => 'XML::SAX',              'version' => '0.99',   'path' => 'XML-SAX-0.99'},
     {'module' => 'XML::LibXML',           'version' => '2.0129', 'path' => 'XML-LibXML-2.0129'},
     {'module' => 'Try::Tiny',             'version' => '0.28',   'path' => 'Try-Tiny-0.28'},
     {'module' => 'LWP',                   'version' => '6.26',   'path' => 'libwww-perl-6.26'},
     {'module' => 'LWP::Protocol::https',  'version' => '6.07',   'path' => 'LWP-Protocol-https-6.07'},
     {'module' => 'VMware::VIRuntime',     'version' => '0.9',    'path' => 'VMware'},
     {'module' => 'WSMan::StubOps',        'version' => '0.1',    'path' => 'WSMan'},
     {'module' => 'Socket6 ',              'version' => '0.28',   'path' => 'Socket6-0.28'},
     {'module' => 'Text::Template',        'version' => '1.47',   'path' => 'Text-Template-1.47'},
     {'module' => 'IO::Socket::INET6',     'version' => '2.72',   'path' => 'IO-Socket-INET6-2.72'},
     {'module' => 'Net::INET6Glue',        'version' => '0.603',  'path' => 'Net-INET6Glue-0.603'},
     {'module' => 'Net::HTTP',             'version' => '6.09',   'path' => 'Net-HTTP-6.09'}
   );

   my @module_to_verify = (
      {'module' => 'ExtUtils::MakeMaker',  'version' => '6.96',    'path' => 'BINGOS/ExtUtils-MakeMaker-6.96.tar.gz'},
      {'module' => 'Module::Build',        'version' => '0.4205',  'path' => 'LEONT/Module-Build-0.4205.tar.gz'},
      {'module' => 'Net::FTP',             'version' => '2.77',    'path' => 'GBARR/libnet-1.22.tar.gz'},
   );

   my @install; # list of modules to be installed

   my @install_bundled; #list of bundled modules to install

   my $lib_dir = $Config{'archlib'} || $ENV{'PERL5LIB'} || $ENV{'PERLLIB'} ||
      error("Unable to determine the Perl module directory.  You may set the " .
            "destination manually by setting the PERLLIB directory.\n\n");

   my $share_dir = $Config{'installprivlib'} || $ENV{'PERLSHARE'} ||
      error("Unable to determine share_dir.  You may set the destination " .
            "manually using PERLSHARE.\n\n");

   foreach my $module (@modules) {
      if (system("perl -M$module->{'module'} -e 1 2>/dev/null") >> 8)
      {
         push @install, $module;
         if ($module->{'module'} eq 'Crypt::SSLeay') {
            #If SSLeay is going to be installed by us, they must have a linker on the system
            if (! $linker_installed) {
                print wrap("No Crypt::SSLeay Perl module or linker could be found on the " .
                "system.  Please either install SSLeay from your distribution " .
                "or install a development toolchain and run this installer " .
                "again for encrypted connections.\n\n", 0);
                uninstall();
                exit 1;
            } else {
               $link_ssleay = 1;
            }
         }
      } else {
         eval "require $module->{'module'}";
         if ( $@) {
            push @install, $module;
         } elsif (!$module->{'module'}->VERSION or $module->{'module'}->VERSION lt $module->{'version'}) {
            push @gLower, $module;
         }
      }
   }

   # Determine if internet connection is available.
   if ( ( ! $install_rhel55_local ) && ( scalar(@install) > 0 ) ) {
       my $internetConnect = `ping -c 10 -W 4 www.vmware.com | grep -c "64 bytes"`;
       if ( $internetConnect ne '') {
         $internet_available = ($internetConnect > 3 ) ? 1:0;
       }
   }
   # install modules in @install using CPAN from internet if internet connection available or install it from
   # modules bundled with installer.
   #------------------------------------------------------------------------
   if ( ( ! $install_rhel55_local ) && ( $internet_available ) ) {

      eval "require CPAN";
      if ($@) {
         print wrap("CPAN module not installed on the system.\n" .
                    "CPAN module is required to install missing pre-requisite Perl modules. Please install CPAN.\n\n", 0);
         uninstall_file($gInstallerMainDB);
         exit 1;
      }

      my $httpproxy =0;
      my $ftpproxy =0;

      if ( direct_command("env | grep -i http_proxy") ) {
         $httpproxy = 1;
      } else {
         print wrap("WARNING: The http_proxy environment variable is not set. If your system is using a proxy for Internet access, you must set the http_proxy environment variable .  \n\n", 0);
		 print wrap("If your system has direct Internet access, you can ignore this warning .  \n\n", 0);
      }
      if ( direct_command("env | grep -i ftp_proxy") ) {
         $ftpproxy = 1;
      } else {
         print wrap("WARNING: The ftp_proxy environment variable is not set.  If your system is using a proxy for Internet access, you must set the ftp_proxy environment variable . \n\n", 0);
		 print wrap("If your system has direct Internet access, you can ignore this warning .  \n\n", 0);
      }

      require CPAN;
      no warnings;
      my $cpan_init= "$Config{privlib}/CPAN/FirstTime.pm";
      my $cpan_config= "$Config{privlib}/CPAN/Config.pm";
      $ENV{'PERL_MM_USE_DEFAULT'} = 1;
      $ENV{'PERL_AUTOINSTALL_PREFER_CPAN'} = 1;
      $ENV{'FTP_PASSIVE'} = 1;
      my $initlog = "/dev/null";
      my $cpanlog = "/dev/null";

      if ( defined($ENV{'VMWARE_DEBUG'}) && ($ENV{'VMWARE_DEBUG'} eq 'yes')) {
         $initlog = "cpanintlog.txt";
         $cpanlog = "cpanlog.txt";
      }

      if ( -e $cpan_init )  {
         safe_chmod(0755, $cpan_init);
         print wrap("Please wait while configuring CPAN ...\n\n", 0);
         if ((system($^X, '-pi', '-e', '$. == 73 and s/yes/no/',"$cpan_init")) >> 8) {
         }

         # make CPAN set itself up with defaults and no intervention
         if (system("perl -MCPAN -MCPAN::Config -MCPAN::FirstTime -e 'CPAN::FirstTime::init' >> $initlog 2>&1") >> 8) {
            if (system("perl -MCPAN -MConfig -MCPAN::FirstTime -e 'CPAN::FirstTime::init()' >> $initlog 2>&1") >> 8) {
               if (system("perl -MCPAN -MConfig -MCPAN::FirstTime -e 'CPAN::FirstTime::init(q{$cpan_config})' >> $initlog 2>&1") >> 8) {
                  if ( -e "/etc/redhat-release" ) {
                     print wrap("please restart the installer. \n\n", 0);
                  } else {
                     print "CPAN config Command failed .\n\n";
                     print wrap("Install not able to configure CPAN. Please configure CPAN manually and re-run the Installer. \n\n", 0);
                  }
                  uninstall();
                  exit 1;
                  print  "\n";
               }
            }
         }

         # undo the change
         if ((system($^X, '-pi', '-e', '$. == 73 and s/no/yes/',"$cpan_init")) >> 8) { }

         ## This is required on RedHat 9 for DBD::mysql installation
         my $lang = $ENV{'LANG'};
         $ENV{'LANG'} = 'C' if ($ENV{'LANG'} =~ /UTF\-8/);
         $CPAN::Config->{'inactivity_timeout'} = 0; ## disable timeout to prevent timeout during modules installation
         $CPAN::Config->{'colorize_output'} = 1;
         $CPAN::Config->{'build_requires_install_policy'} = 'yes';  ## automatically installed prerequisites without asking
         $CPAN::Config->{'prerequisites_policy'} = 'follow'; ## build prerequisites automatically
         $CPAN::Config->{'load_module_verbosity'} = 'none';  ## minimum verbosity during module loading
         $CPAN::Config->{'tar_verbosity'} = 'none';  ## minimum verbosity with tar command
         $CPAN::Config->{'connect_to_internet_ok'} = 'yes';
         $CPAN::Config->{'ftp_passive'} = 'yes';
         $CPAN::Config->{'tar'} = 'ptar';

         # Block to verify specific perl module
         my $module_to_verify;
         my @specific_module_install;
         foreach $module_to_verify (@module_to_verify) {
            my $version = direct_command("perl -M$module_to_verify->{'module'} -le 'print \$$module_to_verify->{'module'}::VERSION'");
            if ( ($module_to_verify->{'version'} > $version) || ($module_to_verify->{'version'} < $version)){
               push @specific_module_install, $module_to_verify;
            }
         }
         # Module available to upgrade/downgrade
         if((scalar @specific_module_install) gt "0"){
            print "Below mentioned modules with their version needed to be installed,\n";
            print "these modules are available in your system but vCLI need specific \n";
            print "version to run properly\n\n";
            foreach my $specific_module_install (@specific_module_install) {
               print ("Module: $specific_module_install->{'module'}, Version: $specific_module_install->{'version'} \n");
            }
         }

         # To get user's input to install specific modules
         if (!$gOption{'default'}) {
            print wrap('Please try again when you are ready to accept.' . "\n\n", 0);
            uninstall();
            print wrap('Thank you.' . "\n\n", 0);
            exit 1;
         }
         else {
            foreach my $specific_module_install (@specific_module_install) {
               system("cpan $specific_module_install->{'path'} >> $cpanlog 2>&1") >> 8;
               if ($@) {
                  push @gMissing, $specific_module_install;
               }
            }
         }
         print wrap("Please wait while configuring perl modules using CPAN ...\n\n", 0);

         foreach my $module (@install) {
            my $mod = $module->{'module'};
            if ($mod eq "Net::INET6Glue"){
               my $lwpversion = direct_command("perl -MLWP -le 'print $LWP::VERSION'");
               if($lwpversion != 6.26){
                   # Installing LWP module
                   system("cpan -f OALDERS/libwww-perl-6.26.tar.gz >> $cpanlog 2>&1") >> 8;
               }
	       my $lwp_https_version = direct_command("perl -MLWP::Protocol::https -le 'print $LWP::Protocol::https::VERSION'");
               if($lwp_https_version != 6.07){
                   # Installing LWP-Protocol-https module
                   system("cpan -f OALDERS/LWP-Protocol-https-6.07.tar.gz >> $cpanlog 2>&1") >> 8;
               }
            }
            print wrap('CPAN is downloading and installing pre-requisite Perl module "' .  $mod  . '" .'. "\n\n", 0);
            if (system("perl -MCPAN -e  'CPAN::Shell->force(q{install},$mod)' >> $cpanlog 2>&1") >> 8) {
               print "$mod Install Command failed .\n\n";
            }

            ## Check if module has been successfuly installed
            if (system("perl -M$mod -e 1 2>/dev/null") >> 8) {
               if ($mod ne 'ExtUtils::Installed') {
                  push @gMissing, $module;
               }
            } else {
               db_add_module($mod);
            }
            ## Restore lang
            $ENV{'LANG'} = $lang if (defined $lang);
         }

         @install_bundled = @vmware_modules;
      } else {
         @gMissing = @install;
      }

   } elsif ( $install_rhel55_local ) {
      # @install_bundled all modules
      @install_bundled = @included_modules;
   } else {
      # No Perl module installed
      @gMissing = @install;
      # Install VMware modules
      @install_bundled = @vmware_modules;
   }

   foreach my $module (@install_bundled) {
      if ($module->{'module'} eq 'Crypt::SSLeay') {
         if ($link_ssleay) {
            my $path = "./lib/$module->{'path'}/lib/auto/Crypt/SSLeay";
            if ($] >= 5.010 && ( -e "./lib/5.10/$module->{'path'}/lib" ) )  {
               $path = "./lib/5.10/$module->{'path'}/lib/auto/Crypt/SSLeay";
            }

            if (system("ld -shared -o $path/SSLeay.so $path/SSLeay.o -lcrypto -lssl") >> 8) {
               print wrap("Unable to link the Crypt::SSLeay Perl module.  Secured " .
                          "connections will be unavailable until you install the " .
                          "Crypt::SSLeay module.\n\n", 0);
               uninstall();
               exit 1;
             }
         } else {
            next;
         }
      }

      if ( $install_rhel55_local ) {
         # ExtUtils and https are not bundled for RHEL 5.5
         if ( ( $module->{'module'} eq 'ExtUtils::Installed' ) || ( $module->{'module'} eq 'LWP::Protocol::https' ) ) {
            next;
         }
      }

      undef %patch;
      if ($] >= 5.010 && ( -e "./lib/5.10/$module->{'path'}/lib" ) )  {
         install_dir("./lib/5.10/$module->{'path'}/lib", "$lib_dir", \%patch, 0x1);
      } elsif (-e "./lib/$module->{'path'}/lib") {
         install_dir("./lib/$module->{'path'}/lib", "$lib_dir", \%patch, 0x1);
      }

      undef %patch;
      if ($] >= 5.010 && ( -e "./lib/5.10/$module->{'path'}/share" ) )  {
         install_dir("./lib/5.10/$module->{'path'}/share", "$share_dir", \%patch, 0x1);
      } elsif (-e "./lib/$module->{'path'}/share") {
         install_dir("./lib/$module->{'path'}/share", "$share_dir", \%patch, 0x1);
      }

      if ($] < 5.010) {
         eval "require $module->{'module'}";
         if ($@) {
            push @gMissing, $module;
         }
      }
   }

   if ( scalar(@gMissing) > 0 ) {
      if ( ! $install_rhel55_local ) {
         if ( $internet_available ) {
            print wrap("CPAN not able to install following Perl modules on the system. These must be installed manually for use by " . $vicliName . ":\n\n", 0);
         } else {
            print wrap("Network is unavailable, please configure the network first otherwise please install the following modules manually for use by " . $vicliName . ":\n\n", 0);
         }
      } else {
         print wrap(" The following Perl modules were not found on the system. These must be installed for use by " . $vicliName . ":\n\n", 0);
      }

      for my $module (@gMissing) {
         print "$module->{'module'} $module->{'version'} or newer \n";
      }

      if ( $install_rhel55_local ) {
         print wrap("\n Installation using prebuilt Perl modules for RHEL did not succeed.\n Please copy console output to a file and report this incident with console output file to VMware support." . "\n\n", 0);
         print wrap(" Please also report output of uname -a and last patches installed from RHN (if possible) to VMware support." . "\n\n", 0);
         print wrap(" Please retry using CPAN based install by answering 'no' when prompted to install using prebuilt modules for RHEL" . "\n\n", 0);
      }

      uninstall();
      exit 1;
      print "\n";
   }
}

# Display list of Modules not installed or whose version is less.
sub check_content_vicli_perl {
   my $vicliName = vmware_product_name();

   if (scalar(@gLower) > 0) {
      print wrap(" The following Perl modules were found on the system but may be too old to " .
                 "work with " . $vicliName . ":\n\n", 0);
      for my $module (@gLower) {
         print "$module->{'module'} $module->{'version'} or newer \n";
      }
      print "\n";
   }
}

sub install_content_vicli {
  my $rootdir;
  my $bindir;
  my $answer;
  my %patch;
  my $docdir;
  my $mandir;
  my $libdir;

  my $previous = $gOption{'default'};
  $gOption{'default'} = 0;
  show_EULA();
  $gOption{'default'} = $previous;

  if ((check_disk_space('.', '/usr/lib')) < 0) {
     my $lmsg;
     $lmsg = 'There is not enough space available to install ' . vmware_product_name()
             . '.  Please make at least 100 MB free space available'; 
     print wrap("$lmsg \n\n", 0);
     uninstall_file($gInstallerMainDB);
     exit 1;
  }

  # Install the necessary perl modules first since it is the most fragile
  # piece of this install.
  install_content_vicli_perl();

  db_add_answer('BUILD_NUMBER', "8156551");

  # Prompt for VCLI bin directory
  $rootdir = $gOption{'prefix'} ||
             internal_dirname_vcli(spacechk_answer_vcli('In which directory do you want to install ' .
               'the executable files?', 'dirpath', '/usr/bin', './bin', 'BINDIR', 'default'));

  undef %patch;
  # Install shell uninstall script
  install_dir('./etc', $gRegistryDir, \%patch, 0x1);

  # Don't display a double slash
  if ($rootdir eq '/') {
    $rootdir = '';
  }

  my $vicliName = vmware_product_name();
  print wrap("Please wait while copying " . $vicliName . " files...\n\n", 0);

  undef %patch;
  $bindir = "$rootdir/bin";
  # Install VCLIs in VCLI bin directory
  install_dir('./bin', $bindir, \%patch, 0x1);
  db_add_answer('BINDIR', "$rootdir/bin");

  $gIsUninstallerInstalled = 1;

  $libdir = "$rootdir" . '/lib/vmware-vcli';
  undef %patch;
  # Install vSphere SDK for Perl apps
  install_dir('./apps', "$libdir/apps", \%patch, 0x1);
  # Install VCLIs
  install_dir('./lib/bin', "$libdir/bin", \%patch, 0x1);
  install_dir('./lib/VMware', "$libdir/VMware", \%patch, 0x1);
  install_dir('./lib/lib32', "$libdir/lib32", \%patch, 0x1);
  install_dir('./lib/lib64', "$libdir/lib64", \%patch, 0x1);
  #for rhel 6
  if ( file_name_exist("/etc/redhat-release") && direct_command("cat /etc/redhat-release | grep \"Red\ Hat\ Enterprise.*6\"")) {
    if (is64BitUserLand()) {
       my $rhellibdir = "/lib";
       install_dir('./lib/rhel', "$rhellibdir", \%patch, 0x1);
       my $lib_dir = $Config{'archlib'} || $ENV{'PERL5LIB'} || $ENV{'PERLLIB'} ;
       install_dir('./lib/5.10/Socket6-0.23-rhel6', "$lib_dir/auto/Socket6", \%patch, 0x1);
    }
    else {
      my $lib_dir = $Config{'archlib'} || $ENV{'PERL5LIB'} || $ENV{'PERLLIB'} ;
      install_dir('./lib/5.10/XML-LibXML-1.63-rhel6', "$lib_dir/auto/XML/LibXML", \%patch, 0x1);
      install_dir('./lib/5.10/Socket6-0.23-rhel6', "$lib_dir/auto/Socket6", \%patch, 0x1);
  }
}
  $gIsUninstallerInstalled = 1;
  db_add_answer('LIBDIR', $libdir);

  # Install a symlink for ESXCLI, which is in the library
  install_symlink("$libdir/bin/esxcli/esxcli", "$bindir/esxcli");
  # Install a symlink for DCLI, which is in the library
  install_symlink("$libdir/bin/vmware-dcli/dcli", "$bindir/dcli");
  safe_chmod(755, "$bindir/esxcli");
  safe_chmod(755, "$bindir/dcli");

  # Install a symlink for VCLI
  if ( "$rootdir/bin" ne "/usr/bin") {
     install_bin_symlink('./bin', "$rootdir/bin");
     install_symlink("$libdir/bin/esxcli/esxcli", "/usr/bin/esxcli");
     install_symlink("$libdir/bin/vmware-dcli/dcli", "/usr/bin/dcli");
     # Making esxcli and dcli executable
	 safe_chmod(755, "/usr/bin/esxcli");
     safe_chmod(755, "/usr/bin/dcli");
  }

  # Install a symlink to make /lib point to the correct library
  # based on the architecture of our system
  if (is64BitUserLand()) {
     install_symlink("$libdir/lib64", "$libdir/lib");
  }
  else {
     install_symlink("$libdir/lib32", "$libdir/lib");
  }

  # Make sure that, in particular, libvmacore.so's exec text permission needs
  # are ok with any SELinux setup.  This is a sledge hammer.
  $gHelper{'setsebool'} = internal_which('setsebool');
  if (defined($gHelper{'setsebool'})) {
     system(shell_string($gHelper{'setsebool'}) . " -P allow_execheap=1 > /dev/null 2>&1");
  }

  # Install vSphere SDK for Perl content excluding "apps"
  $docdir = $rootdir . '/share/doc/vmware-vcli';
  install_dir('./doc', $docdir, \%patch, 0x1);
  db_add_answer('DOCDIR', $docdir);

  # Install resxtop man files
  $mandir = "$rootdir/share/man/man1";
  undef %patch;
  install_dir('./man', $mandir, \%patch, 0x1);

  write_vmware_config();

  return 1;
}

# Return the specific VMware product
sub vmware_product {
  return 'vicli';
}

# this is a function instead of a macro in the off chance that product_name
# will one day contain a language-specific escape character.
sub vmware_product_name {
  return 'vSphere CLI';
}

# This function returns i386 under most circumstances, returning x86_64 when
# the product is Workstation and is the 64bit version at that.
sub vmware_product_architecture {
  return 'x86_64';
}

# Return product name and version
sub vmware_longname {
   my $name = vmware_product_name() . ' ' . vmware_version();

   $name .= ' for Linux';

   return $name;
}

# Display a usage error message for the install program and exit
sub install_usage {
  print STDERR wrap(vmware_longname() . ' installer' . "\n" . 'Usage: ' . $0
                    . ' [[-][-]d[efault]]' . "\n"
                    . '    default: Automatically answer questions with the '
                    . 'proposed answer.'
		    . "\n"
                    . ' [[-][-]prefix=<path to install product: bin, lib, doc>]'
                    . '    Put the installation at <path> instead of the default '
                    . "location.  This implies '--default'."
		    . "\n"
		    . '--clobber-kernel-modules=<module1,module2,...>'
		    . '    Forcefully removes any VMware related modules '
		    . 'installed by any other installer and installs the modules provided '
		    . 'by this installer.  This is a comma seperated list of modules.'
		    . "\n\n", 0);
  exit 1;
}

# Remove a temporary directory
sub remove_tmp_dir {
  my $dir = shift;

  if (system(shell_string($gHelper{'rm'}) . ' -rf ' . shell_string($dir))) {
    error('Unable to remove the temporary directory ' . $dir . '.' . "\n\n");
  };
}

# ARGH! More code duplication from pkg_mgr.pl
# We really need to have some kind of include system
sub get_cc {
  $gHelper{'gcc'} = '';
  if (defined($ENV{'CC'}) && (not ($ENV{'CC'} eq ''))) {
    $gHelper{'gcc'} = internal_which($ENV{'CC'});
    if ($gHelper{'gcc'} eq '') {
      print wrap('Unable to find the compiler specified in the CC environnment variable: "'
                 . $ENV{'CC'} . '".' . "\n\n", 0);
    }
  }
  if ($gHelper{'gcc'} eq '') {
    $gHelper{'gcc'} = internal_which('gcc');
    if ($gHelper{'gcc'} eq '') {
      $gHelper{'gcc'} = internal_which('egcs');
      if ($gHelper{'gcc'} eq '') {
        $gHelper{'gcc'} = internal_which('kgcc');
        if ($gHelper{'gcc'} eq '') {
          $gHelper{'gcc'} = DoesBinaryExist_Prompt('gcc');
        }
      }
    }
  }
  print wrap('Using compiler "' . $gHelper{'gcc'}
             . '". Use environment variable CC to override.' . "\n\n", 0);
  return $gHelper{'gcc'};
}

# These quaddot functions and compute_subnet are from config.pl and are needed
# for the tar4|rpm4 upgrade
# Converts an quad-dotted IPv4 address into a integer
sub quaddot_to_int {
  my $quaddot = shift;
  my @quaddot_a;
  my $int;
  my $i;

  @quaddot_a = split(/\./, $quaddot);
  $int = 0;
  for ($i = 0; $i < 4; $i++) {
    $int <<= 8;
    $int |= $quaddot_a[$i];
  }

  return $int;
}

# Converts an integer into a quad-dotted IPv4 address
sub int_to_quaddot {
  my $int = shift;
  my @quaddot_a;
  my $i;

  for ($i = 3; $i >= 0; $i--) {
    $quaddot_a[$i] = $int & 0xFF;
    $int >>= 8;
  }

  return join('.', @quaddot_a);
}

# Compute the subnet address associated to a couple IP/netmask
sub compute_subnet {
  my $ip = shift;
  my $netmask = shift;

  return int_to_quaddot(quaddot_to_int($ip) & quaddot_to_int($netmask));
}

#
# Check to see if a conflicting product is installed and how it relates
# to the new product being installed, asking the user relevant questions.
# Based on user feedback, the conflicting product will either be removed,
# or the installation will be aborted.
#
sub prompt_and_uninstall_conflicting_products {

  if (vmware_product() eq 'vicli') {
    # Uninstall any viperl specific installs, remnants of the pre-unified vicli work.
    my $viperlUninstaller = "/usr/bin/vmware-uninstall-viperl.pl";
    if (-e $viperlUninstaller) {
      my $msg = 'You have a conflicting installation of vSphere SDK for Perl installed.  '
              . 'Continuing this install will UNINSTALL the conflicting product '
              . 'before continuing the installation of ' . vmware_product_name()
              . '  Do you wish to continue? (yes/no)';
      if (get_answer($msg, 'yesno', 'yes') eq 'no') {
        error "User cancelled install.\n";
      }
      if (!uninstall_product('viperl')) {
        error('vSphere SDK for Perl Uninstall Failure' . "\n\n");
      }
    }
  }

}

#
# This sub fetches the installed product's binfile and returns it.
# It returns '' if there is no product, 'UNKNOWN' if a product but
# no known bin.
#
sub get_installed_product_bin {
  my $binfile;

  # If there's no database, then there isn't any
  # previously installed product.
  my $tmp_db = $gInstallerMainDB;

  if ((not isDesktopProduct()) && (not isServerProduct())) {
    return 'UNKNOWN';
  }

  # If the installer DB is missing there is no product already installed so
  # there is no mismatch.
  # If not_configured is found, then install has already run once and has
  # uninstalled everything.
  if (not -e $gInstallerMainDB || -e $gRegistryDir . '/' . $gConfFlag) {
    return '';
  }

  db_load();
  my $bindir = db_get_answer('BINDIR');
  if (-f $bindir . "/vmware") {
    $binfile = $bindir . "/vmware";
  } else {
    # There is no way to tell what may currently be installed, but something
    # is still around if the database is found.
    return 'UNKNOWN';
  }
  return $binfile;
}

#
# Check to see if the product we are installing is the same as the
# currently installed product, this is used to tell whether we are in
# what would be considered an upgrade situation or a conflict.
#
# return = 0:  There is a match
#        = 1:  There is a mismatch
#
sub installed_product_mismatch {
  my $msg;
  my $binfile = get_installed_product_bin();
  if ( $binfile eq '' ){
    return 0;
  }
  if ( $binfile eq 'UNKNOWN' ){
    return 1;
  }
  my $product_str = direct_command($binfile . ' -v');
  my $product_name = vmware_product_name();
  if ($product_str =~ /$product_name/){
    return 0;
  }

  return 1;
}

#
# Given a product version string ala 'vSphere CLI X.X.X build-000000', break
# down the Xs and return a value that shows which string represents a newer
# version number, the same version number, or an older version number.  X may be
# a digit or a letter, as in e.x.p build-000000
#
sub compare_version_strings {
   my $version_str_A = shift;
   my $version_str_B = shift;
   my $index = 0;

   # Match on non-spaces to allow for either numbers or letters.  I.E. e.x.p and 1.0.4
   $version_str_A =~ s/\D*(\S+.\S+.\S+)\s+build-(\d+)/$1.$2/;
   $version_str_B =~ s/\D*(\S+.\S+.\S+)\s+build-(\d+)/$1.$2/;

   chomp($version_str_A);
   chomp($version_str_B);
   my @versions_A = split(/\./, $version_str_A);
   my @versions_B = split(/\./, $version_str_B);

   while (($index < $#versions_A + 1) && ($versions_A[$index] eq $versions_B[$index])) {
      $index++;
   }
   if ($index > $#versions_A) {
      $index = $#versions_A;
   }

   my $result;
   if ($versions_A[$index] =~ /\d+/ && $versions_B[$index] =~ /\d+/) {
      $result = $versions_A[$index] - $versions_B[$index];
   } elsif ($versions_A[$index] =~ /\w+/ && $versions_B[$index] =~ /\d+/) {
      $result = -1;
   } elsif ($versions_A[$index] =~ /\d+/ && $versions_B[$index] =~ /\w+/) {
      $result =  1;
   } else {
      $result =  0;
   }

   return $result;
}

#
# Check to see what product is installed, and how it relates to the
# new product being installed, asking the user relevant questions,
# and allowing the user to abort(error out) if they don't want the
# existing installed product to be removed (as in for an up/downgrade
# or conflicting product).
#
sub prompt_user_to_remove_installed_product {
   if ((vmware_product() eq 'vicli')) {
      my $msg = "You have a version of " . vmware_product_name() . " installed.  "
              . "Continuing will remove it in preparation for installing a new "
              . vmware_product_name() . ".  Do you want to continue?\n";
      if (get_answer($msg, 'yesno', 'yes') eq 'no') {
         error "User cancelled install.\n";
      }
      return;
   }

  #Now that the group of other-conflicting products is handled, we are sure this product simply
  #conflicts with itself, even if its one of those.
  my $binfile = get_installed_product_bin();
  if ( $binfile eq 'UNKNOWN' or $binfile eq '' ){
    #Without a binfile, we can't detect version, so we simply warn the user we are about to uninstall
    #and ask them if they want that.
    if (get_answer('You have a version of '.vmware_product_name().' installed.  ' .
                   'Continuing this install will first uninstall the currently installed version.' .
                   '  Do you wish to continue? (yes/no)', 'yesno', 'yes') eq 'no') {
      error "User cancelled install.\n";
    }
    return;
  }

  my $product_str = direct_command($binfile . ' -v');
  my $installed_version = direct_command($binfile . ' -v');
  my $product_version = vmware_version();
  if (compare_version_strings($installed_version, $product_version) > 0) {
    if (get_answer('You have a more recent version of '.vmware_product_name().' installed.  ' .
                   'Continuing this install will DOWNGRADE to the latest version by first ' .
                   'uninstalling the more recent version.  Do you wish to continue? (yes/no)', 'yesno', 'no') eq 'no') {
      error "User cancelled install.\n";
    }
  } else {
    if (get_answer('You have a previous version of '.vmware_product_name().' installed.  ' .
                   'Continuing this install will upgrade to the latest version by first ' .
                   'uninstalling the previous version.  Do you wish to continue? (yes/no)', 'yesno', 'yes') eq 'no') {
      error "User cancelled install.\n";
    }
  }
}

#
# remove_outdated_products
#
# Based on the gOldUninstallers list, prompt the user to remove these
# installations of these programs if they exist.  Otherwise bail out
# if the user does not want to uninstall them.
#
# SIDE EFFECTS:
#    Will invoke old installers if found and may cause the install
#    to fail if the old installer fails.
#

sub remove_outdated_products {
  my $oldUninstaller;
  my $status;
  foreach $oldUninstaller (@gOldUninstallers) {
     if ( -x $oldUninstaller ) {
        # Then we have found an old named version of this program, and should
        # uninstall it.  We also have to nuke the database because it will
        # contain incorrect information regarding older path names. -astiegmann
        my $msg = 'An Older version of ' . vmware_product_name() . ' with a '
                . 'different name was found on your system.  Would you like '
                . 'to uninstall it?';
        if (get_answer($msg, 'yesno', 'yes') eq 'no') {
           error("User cancelled install.\n");
        }
        print wrap('Running ' . $oldUninstaller . "...\n",0);
        $status = system(shell_string($oldUninstaller) . ' uninstall');
        if ($status) {
           error("Uninstall of the old program has failed. "
               . " Please correct the failure and re run the install.\n\n");
        }
     }
  }
}

#
# Make sure we have an initial database suitable for this installer. The goal
# is to encapsulates all the compatibilty issues in this (consequently ugly)
# function
#
# SIDE EFFECTS:
#      This function uninstalls previous products found (now managed by
#      prompt_user_to_remove_installed_product)
#

sub get_initial_database {
  my $made_dir1;
  my $made_dir2;
  my $bkp_dir;
  my $bkp;
  my $kind;
  my $version;
  my $intermediate_format;
  my $status;
  my $state_file;
  my $state_files;
  my $clear_db = 0;

  # Check for older products with a different name, and uninstall them if
  # we can find their uninstall programs.
  remove_outdated_products();

  if (not (-e $gInstallerMainDB)) {
    create_initial_database();
    return;
  }

  print wrap('A previous installation of ' . vmware_product_name()
             . ' has been detected.' . "\n\n", 0);

  #
  # Convert the previous installer database to our format and backup it
  # Uninstall the previous installation
  #

  $bkp_dir = make_tmp_dir('vmware-installer');
  $bkp = $bkp_dir . '/prev_db.tar.gz';

  if (-x $gInstallerObject) {
    $kind = direct_command(shell_string($gInstallerObject) . ' kind');
    chop($kind);
    if (system(shell_string($gInstallerObject) . ' version >/dev/null 2>&1')) {
      # No version method -> this is version 1
      $version = '1';
    } else {
      $version = direct_command(shell_string($gInstallerObject) . ' version');
      chop($version);
    }
    print wrap('The previous installation was made by the ' . $kind
               . ' installer (version ' . $version . ').' . "\n\n", 0);

    if ($version < 2) {
      # The best database format those installers know is tar. We will have to
      # upgrade the format
      $intermediate_format = 'tar';
    } elsif ($version == 2) {
      # Those installers at least know about the tar2 database format. We won't
      # have to do too much
      $intermediate_format='tar2'
    } elsif ($version == 3) {
      # Those installers at least know about the tar3 database format. We won't
      # have to do much
      $intermediate_format = 'tar3';
    } else {
      # Those installers at least know about the tar4 database format. We won't
      # have to do anything
      $intermediate_format = 'tar4';
    }
    system(shell_string($gInstallerObject) . ' convertdb '
           . shell_string($intermediate_format) . ' ' . shell_string($bkp));

    # Remove any installed product *if* user accepts.
    prompt_user_to_remove_installed_product();
    $status = system(shell_string($gInstallerObject) . ' uninstall --upgrade');
    if ($status) {
      error("Uninstall failed.  Please correct the failure and re run the install.\n\n");
    }

    # Beware, beyond this point, $gInstallerObject does not exist
    # anymore.
  } else {
    # No installer object -> this is the old installer, which we don't support
    # anymore.
    $status = 1;
  }
  if ($status) {
    remove_tmp_dir($bkp_dir);
    # remove the installer db so the next invocation of install can proceed.
    if (get_answer('Uninstallation of previous install failed. ' .
		   'Would you like to remove the install DB?', 'yesno', 'no') eq 'yes') {
      print wrap('Removing installer DB, please re-run the installer.' . "\n\n", 0);
      unlink $gInstallerMainDB;
    }

    error('Failure' . "\n\n");
  }

  if ($clear_db == 1) {
    create_initial_database();
    return;
  }

  # Create the directory structure to welcome the restored database
  $made_dir1 = 0;
  if (not (-d $gRegistryDir)) {
    safe_mkdir($gRegistryDir);
    $made_dir1 = 1;
  }
  safe_chmod(0755, $gRegistryDir);
  $made_dir2 = 0;
  if ($version >= 2) {
    if (not (-d $gStateDir)) {
      safe_mkdir($gStateDir);
      $made_dir2 = 1;
    }
    safe_chmod(0755, $gStateDir);
  }

  # Some versions of tar (1.13.17+ are ok) do not untar directory permissions
  # as described in their documentation (they overwrite permissions of
  # existing, non-empty directories with permissions stored in the archive)
  #
  # Because we didn't know about that at the beginning, the previous
  # uninstallation may have included the directory structure in their database
  # backup.
  #
  system(shell_string($gHelper{'tar'}) . ' -C ' . shell_string($bkp_dir)
         . ' -xzopf ' . shell_string($bkp));
  $state_files = '';
  if (-d $bkp_dir . $gStateDir) {
    foreach $state_file (internal_ls($bkp_dir . $gStateDir)) {
      $state_files .= ' ' . shell_string('.' . $gStateDir . '/'. $state_file);
    }
  }
  $bkp = $bkp_dir . '/prev_db2.tar.gz';
  system(shell_string($gHelper{'tar'}) . ' -C ' . shell_string($bkp_dir)
         . ' -czopf ' . shell_string($bkp) . ' '
         . shell_string('.' . $gInstallerMainDB) . $state_files);

  # Restore the database ready to be used by our installer
  system(shell_string($gHelper{'tar'}) . ' -C / -xzopf ' . shell_string($bkp));
  remove_tmp_dir($bkp_dir);

  if ($version < 2) {
    print wrap('Converting the ' . $intermediate_format
               . ' installer database format to the tar4 installer database format.'
               . "\n\n", 0);
    # Upgrade the database format: keep only the 'answer' statements, and add a
    # 'file' statement for the main database file
    my $id;

    db_load();
    if (not open(INSTALLDB, '>' . $gInstallerMainDB)) {
      error('Unable to open the tar installer database ' . $gInstallerMainDB
            . ' in write-mode.' . "\n\n");
    }
    db_add_file($gInstallerMainDB, 0);
    foreach $id (keys %gDBAnswer) {
      print INSTALLDB 'answer ' . $id . ' ' . $gDBAnswer{$id} . "\n";
    }
    db_save();
  } elsif( $version == 2 ) {
    print wrap('Converting the ' . $intermediate_format
               . ' installer database format to the tar4 installer database format.'
               . "\n\n", 0);
    # Upgrade the database format: keep only the 'answer' statements, and add a
    # 'file' statement for the main database file
    my $id;

    db_load();
    if (not open(INSTALLDB, '>' . $gInstallerMainDB)) {
      error('Unable to open the tar installer database ' . $gInstallerMainDB
            . ' in write-mode.' . "\n\n");
    }
    db_add_file($gInstallerMainDB, 0);
    foreach $id (keys %gDBAnswer) {
      # For the rpm3|tar3 format, a number of keywords were removed.  In their
      # place a more flexible scheme was implemented for which each has a semantic
      # equivalent:
      #
      #   VNET_HOSTONLY          -> VNET_1_HOSTONLY
      #   VNET_HOSTONLY_HOSTADDR -> VNET_1_HOSTONLY_HOSTADDR
      #   VNET_HOSTONLY_NETMASK  -> VNET_1_HOSTONLY_NETMASK
      #   VNET_INTERFACE         -> VNET_0_INTERFACE
      #
      # Note that we no longer use the samba variables, so these entries are
      # removed (and not converted):
      #   VNET_SAMBA             -> VNET_1_SAMBA
      #   VNET_SAMBA_MACHINESID  -> VNET_1_SAMBA_MACHINESID
      #   VNET_SAMBA_SMBPASSWD   -> VNET_1_SAMBA_SMBPASSWD
      my $newid = $id;
      if ("$id" eq 'VNET_SAMBA') {
         next;
      } elsif ("$id" eq 'VNET_SAMBA_MACHINESID') {
         next;
      } elsif ("$id" eq 'VNET_SAMBA_SMBPASSWD') {
         next;
      } elsif ("$id" eq 'VNET_HOSTONLY') {
        $newid='VNET_1_HOSTONLY';
      } elsif ("$id" eq 'VNET_HOSTONLY_HOSTADDR') {
        $newid='VNET_1_HOSTONLY_HOSTADDR';
      } elsif ("$id" eq 'VNET_HOSTONLY_NETMASK') {
        $newid='VNET_1_HOSTONLY_NETMASK';
      } elsif ("$id" eq 'VNET_INTERFACE') {
        $newid='VNET_0_INTERFACE';
      }

      print INSTALLDB 'answer ' . $newid . ' ' . $gDBAnswer{$id} . "\n";
    }

    # For the rpm4|tar4 format, two keyword were added. We add them here if
    # necessary.  Note that it is only necessary to check the existence of two
    # VNET_HOSTONLY_ keywords since the rpm2|tar2 format contained only a few
    # VNET_ keywords
    my $addr = db_get_answer_if_exists('VNET_HOSTONLY_HOSTADDR');
    my $mask = db_get_answer_if_exists('VNET_HOSTONLY_NETMASK');
    if (defined($addr) and defined($mask)) {
       print INSTALLDB 'answer VNET_1_HOSTONLY_SUBNET ' .
                        compute_subnet($addr, $mask) . "\n";
       print INSTALLDB "answer VNET_1_DHCP yes\n";
    }

    db_save();
  } elsif ( $version == 3 ) {
    print wrap('Converting the ' . $intermediate_format
               . ' installer database format to the tar4 installer database format.'
               . "\n\n", 0);
    # Upgrade the database format: keep only the 'answer' statements, and add a
    # 'file' statement for the main database file
    my $id;

    db_load();
    if (not open(INSTALLDB, '>' . $gInstallerMainDB)) {
      error('Unable to open the tar installer database ' . $gInstallerMainDB
            . ' in write-mode.' . "\n\n");
    }
    db_add_file($gInstallerMainDB, 0);

    # No conversions necessary between version 3 and 4, so add all answers
    foreach $id (keys %gDBAnswer) {
      print INSTALLDB 'answer ' . $id . ' ' . $gDBAnswer{$id} . "\n";
    }

    # Check whether we need to add the two new keywords for each virtual network:
    #   VNET_n_HOSTONLY_SUBNET -> set if VNET_n_HOSTONLY_{HOSTADDR,NETMASK} are set
    #   VNET_n_DHCP            -> 'yes' iff VNET_n_INTERFACE is not defined and
    #                              VNET_n_HOSTONLY_{HOSTADDR,NETMASK} are defined
    #
    my $i;
    for ($i = $gMinVmnet; $i < $gMaxVmnet; $i++) {
      my $pre = 'VNET_' . $i . '_';
      my $interface = db_get_answer_if_exists($pre . 'INTERFACE');
      my $hostaddr  = db_get_answer_if_exists($pre . 'HOSTONLY_HOSTADDR');
      my $netmask   = db_get_answer_if_exists($pre . 'HOSTONLY_NETMASK');

      if (defined($hostaddr) && defined($netmask)) {
         my $subnet = compute_subnet($hostaddr, $netmask);
         print INSTALLDB 'answer ' . $pre . 'HOSTONLY_SUBNET ' . $subnet . "\n";

         if (not defined($interface)) {
            print INSTALLDB 'answer ' . $pre . "DHCP yes\n";
         }
      }
    }

    db_save();
  }

  db_load();
  db_append();
  if ($made_dir1) {
    db_add_dir($gRegistryDir);
  }
  if ($made_dir2) {
    db_add_dir($gStateDir);
  }
}

sub create_initial_database {
  my $made_dir1;
  undef %gDBAnswer;
  undef %gDBFile;
  undef %gDBDir;
  undef %gDBLink;
  undef %gDBMove;

  # This is the first installation. Create the installer database from
  # scratch
  print wrap('Creating a new ' . vmware_product_name()
             . ' installer database using the tar4 format.' . "\n\n", 0);

  $made_dir1 = create_dir($gRegistryDir, 0);
  safe_chmod(0755, $gRegistryDir);

  if (not open(INSTALLDB, '>' . $gInstallerMainDB)) {
    if ($made_dir1) {
      rmdir($gRegistryDir);
    }
    error('Unable to open the tar installer database ' . $gInstallerMainDB
          . ' in write-mode.' . "\n\n");
  }
  # Force a flush after every write operation.
  # See 'Programming Perl', p. 110
  select((select(INSTALLDB), $| = 1)[0]);

  if ($made_dir1) {
    db_add_dir($gRegistryDir);
  }
  # This file is going to be modified after its creation by this program.
  # Do not timestamp it
  db_add_file($gInstallerMainDB, 0);
}

# SIGINT handler. We will never reset the handler to the DEFAULT one, because
# with the exception of pre-uninstaller not being installed, this one does
# the same thing as the default (kills the process) and even sends the end
# RPC for us in tools installations.
sub sigint_handler {
  if ($gIsUninstallerInstalled == 0) {
    print STDERR wrap("\n\n" . 'Ignoring attempt to kill the installer with Control-C, because the uninstaller has not been installed yet. Please use the Control-Z / fg combination instead.' . "\n\n", 0);

    return;
  }

  error('');
}

#  Write the VMware host-wide configuration file - only if console
sub write_vmware_config {
  my $name;

  $name = $gRegistryDir . '/config';

  uninstall_file($name);
  if (file_check_exist($name)) {
    return;
  }
  # The file could be a symlink to another location. Remove it
  unlink($name);

  open(CONFIGFILE, '>' . $name) or error('Unable to open the configuration file '
                                         . $name . ' in write-mode.' . "\n\n");
  db_add_file($name, 0x1);
  safe_chmod(0444, $name);
  print CONFIGFILE 'libdir = "' . db_get_answer('LIBDIR') . '"' . "\n";
  close(CONFIGFILE);
}

# Get the installed version of VMware
# Return the version if found, or ''
sub get_installed_version() {
  my $backslash;
  my $dollar;
  my $pattern;
  my $version;
  my $nameTag;

  # XXX In the future, we should use a method of the installer object to
  #     retrieve the installed version

  #
  # Try to retrieve the installed version from the configurator program. This
  # works for both the tar and the rpm installers
  #

  if (not defined($gDBAnswer{'BINDIR'})) {
    return '';
  }

  if (not open(FILE, '<' . db_get_answer('BINDIR') . $gConfigurator)) {
    return '';
  }

  # Build the pattern without using the dollar character, so that CVS doesn't
  # modify the pattern in tagged builds (bug 9303)
  $backslash = chr(92);
  $dollar = chr(36);
  $pattern = '^  ' . $backslash . $dollar . 'buildNr = ' .
      "'" . '(\S+) ' . "'" . ' ' . $backslash . '. q' .
      $backslash . $dollar . 'Name: (\S+)? ' . $backslash . $dollar . ';' . $dollar;

  $version = '';
  $nameTag = '';
  while (<FILE>) {
    if (/$pattern/) {
      $version = $1;
      $nameTag = defined($2) ? $2 : '';
    }
  }
  close(FILE);

  return $version;
}

# Get the installed kind of VMware
# Return the kind if found, or ''
sub get_installed_kind() {
  my $kind;

  if (not (-x $cInstallerObject)) {
    return '';
  }

  $kind = direct_command(shell_string($cInstallerObject) . ' kind');
  chop($kind);

  return $kind;
}

# Install the content of the module package
sub install_module {
  my %patch;

  print wrap('Installing the kernel modules contained in this package.' . "\n\n", 0);

  undef %patch;
  install_dir('./lib', db_get_answer('LIBDIR'), \%patch, 0x1);
}

# Uninstall modules
sub uninstall_module {
  print wrap('Uninstalling currently installed kernel modules.' . "\n\n", 0);

  uninstall_prefix(db_get_answer('LIBDIR') . '/modules');
}

# XXX Duplicated in config.pl
# format of the returned hash:
#          - key is the system file
#          - value is the backed up file.
# This function should never know about filenames. Only database
# operations.
sub db_get_files_to_restore {
  my %fileToRestore;
  undef %fileToRestore;
  my $restorePrefix = 'RESTORE_';
  my $restoreBackupSuffix = '_BAK';
  my $restoreBackList = 'RESTORE_BACK_LIST';

  if (defined db_get_answer_if_exists($restoreBackList)) {
    my $restoreStr;
    foreach $restoreStr (split(/:/, db_get_answer($restoreBackList))) {
      if (defined db_get_answer_if_exists($restorePrefix . $restoreStr)) {
        $fileToRestore{db_get_answer($restorePrefix . $restoreStr)} =
          db_get_answer($restorePrefix . $restoreStr
                        . $restoreBackupSuffix);
      }
    }
  }
  return %fileToRestore;
}

# Returns an array with the list of files that changed since we installed
# them.
sub db_is_file_changed {

  my $file = shift;
  my @statbuf;

  @statbuf = stat($file);
  if (defined $gDBFile{$file} && $gDBFile{$file} ne '0' &&
      $gDBFile{$file} ne $statbuf[9]) {
    return 'yes';
  } else {
    return 'no';
  }
}

sub filter_out_bkp_changed_files {

  my $filesToRestoreRef = shift;
  my $origFile;

  foreach $origFile (keys %$filesToRestoreRef) {
    if (db_file_in($origFile) && !-l $origFile &&
        db_is_file_changed($origFile) eq 'yes') {
      # We are in the case of bug 25444 where we are restoring a file
      # that we backed up and was changed in the mean time by someone else
      db_remove_file($origFile);
      backup_file($$filesToRestoreRef{$origFile});
      unlink $$filesToRestoreRef{$origFile};
      print wrap("\n" . 'File ' . $$filesToRestoreRef{$origFile}
                 . ' was not restored from backup because our file '
                 . $origFile
                 . ' got changed or overwritten between the time '
                 . vmware_product_name()
                 . ' installed the file and now.' . "\n\n"
                 ,0);
      delete $$filesToRestoreRef{$origFile};
    }
  }
}

sub restore_backedup_files {
  my $fileToRestore = shift;
  my $origFile;

  foreach $origFile (keys %$fileToRestore) {
    if (file_name_exist($origFile) &&
        file_name_exist($$fileToRestore{$origFile})) {
      backup_file($origFile);
      unlink $origFile;
    }
    if ((not file_name_exist($origFile)) &&
        file_name_exist($$fileToRestore{$origFile})) {
      rename $$fileToRestore{$origFile}, $origFile;
    }
  }
}

#
# For files modified with block_append(), rather than restoring a backup file
# remove what was appended.  This will preserve any changes a user may have made
# to these files after install/config ran.
sub restore_appended_files {
   my $list = '';

   $list = db_get_answer_if_exists('APPENDED_FILES');
   if (not defined($list)) {
      return;
   }

   foreach my $file (split(':', $list)) {
      if (-f $file) {
         block_restore($file, $cMarkerBegin, $cMarkerEnd);
      }
   }
}

### Does the dstDir have enough space to hold srcDir
sub check_disk_space {
  my $srcDir = shift;
  my $dstDir = shift;
  my $srcSpace;
  my $dstSpace;
  my @parser;

  # get the src usage
  open (OUTPUT, shell_string($gHelper{'du'}) . ' -sk ' . shell_string($srcDir)
	. ' 2>/dev/null|') or error("Failed to open 'du'.");
  $_ = <OUTPUT>;
  @parser = split(/\s+/);
  $srcSpace = $parser[0];
  close OUTPUT;

  # Before we can check the space, $dst must exist. Walk up the directory path
  # until we find something that exists.
  while (! -d $dstDir) {
    $dstDir = internal_dirname($dstDir);
  }
  open (OUTPUT, shell_string($gHelper{'df'}) . ' -k ' .  shell_string($dstDir)
	. ' 2>/dev/null|');
  while (<OUTPUT>) {
    @parser = split(/\s+/);
    if ($parser[0] ne 'Filesystem') {
      $dstSpace = $parser[3];
    }
  }
  close OUTPUT;

  # Return the amount of space available in kbytes.
  return ($dstSpace - $srcSpace);
}

### Does the user have permission to write to this directory?
sub check_dir_writeable {
  my $dstDir = shift;

  # Before we can check the permission, $dst must exist. Walk up the directory path
  # until we find something that exists.
  while (! -d $dstDir) {
    $dstDir = internal_dirname($dstDir);
  }

  # Return whether this directory is writeable.
  return (-w $dstDir);
}

#
#  Check to see that the product architecture is a mismatch for this os.
#  Return an error string if there is a mismatch, otherwise return undef
#
sub product_os_match {

  init_product_arch_hash();
  if (!defined($multi_arch_products{vmware_product()})) {
    return undef;
  }

  if (is64BitUserLand() == (vmware_product_architecture() eq "x86_64")) {
    return undef;
  }
  if (is64BitUserLand() != (vmware_product_architecture() ne "x86_64")) {
    return undef;
  }

  return sprintf('This version of "%s" is incompatible with this '
		. 'operating system.  Please install the "%s" '
		. 'version of this program instead.'
		. "\n\n", vmware_product_name(),
		  is64BitUserLand() ? 'x86_64' : 'i386');
}

#
#  Create a list of products that support both a 32bit and a 64bit
#  architecture and thus should be matched to the running OS.
#
sub init_product_arch_hash {
  $multi_arch_products{'vicli'} = 1;
}

# Program entry point
sub main {
   my (@setOption, $opt);
   my $chk_msg;
   my $progpath = $0;
   my $scriptname = internal_basename($progpath);

   $chk_msg = product_os_match();
   if (defined($chk_msg)) {
     error($chk_msg);
   }

   if (!is_root()) {
     error('Please re-run this program as the super user.' . "\n\n");
   }

   # Force the path to reduce the risk of using "modified" external helpers
   # If the user has a special system setup, he will will prompted for the
   # proper location anyway
   $ENV{'PATH'} = '/bin:/usr/bin:/sbin:/usr/sbin';

   initialize_globals(internal_dirname($0));
   initialize_external_helpers();

   # List of questions answered with command-line arguments
   @setOption = ();

   if (internal_basename($0) eq $cInstallerFileName) {
     my $answer;

     if ($#ARGV > -1) {
       # There are only two possible arguments
       while ($#ARGV != -1) {
         my $arg;
         $arg = shift(@ARGV);

         if (lc($arg) =~ /^(-)?(-)?d(efault)?$/) {
           $gOption{'default'} = 1;
         } elsif (lc($arg) =~ /^--clobber-kernel-modules=([\w,]+)$/) {
           $gOption{'clobberKernelModules'} = "$1";
	 } elsif (lc($arg) =~ /^(-)?(-)?nested$/) {
           $gOption{'nested'} = 1;
         } elsif (lc($arg) =~ /^-?-?prefix=(.+)/) {
           $gOption{'prefix'} = $1;
         } elsif ($arg =~ /=yes/ || $arg =~ /=no/) {
           push(@setOption, $arg);
         } elsif (lc($arg) =~ /^(-)?(-)?(no-create-shortcuts)$/) {
           $gOption{'create_shortcuts'} = 0;
         } else {
           install_usage();
         }
       }
     }

     # Other installers will be able to remove this installation cleanly only if
     # they find the uninstaller. That's why we:
     # . Install the uninstaller ASAP
     # . Prevent users from playing with Control-C while doing so

    $gIsUninstallerInstalled = 0;

    # Install the SIGINT handler. Don't bother resetting it, see
    # sigint_handler for details.
    $SIG{INT} = \&sigint_handler;
    $SIG{QUIT} = \&sigint_handler;

    if ( $progpath =~ /(.*?)\/$scriptname/ ) {
      chdir($1);
    }

    # if a nested install, it is the responsibility of the parent to
    # make sure no conflicting products are installed
    if ($gOption{'nested'} != 1) {
      prompt_and_uninstall_conflicting_products();
    }
    my $dstDir = $gRegistryDir;
    $gFirstCreatedDir = $dstDir;
    while (!-d $dstDir) {
      $gFirstCreatedDir = $dstDir;
      $dstDir = internal_dirname($dstDir);
    }
    get_initial_database();
    # Binary wrappers can be run by any user and need to read the
    # database.
    safe_chmod(0644, $gInstallerMainDB);

    db_add_answer('INSTALL_CYCLE', 'yes');

    foreach $opt (@setOption) {
      my ($key, $val);
      ($key, $val) = ($opt =~ /^([^=]*)=([^=]*)/);
      db_add_answer($key, $val);
    }

    install_or_upgrade();

    if (vmware_product() eq 'vicli') {
       check_content_vicli_perl();
    }

    # Reset these answers in case we have installed new versions of these
    # documents.
    if (vmware_product() eq 'vicli') {
      db_remove_answer('EULA_AGREED');
      db_remove_answer('ISC_COPYRIGHT_SEEN');
    }

    db_save();

    my $configResult;

    print wrap('Enjoy,' . "\n\n" . '    --the VMware team' . "\n\n", 0);

    exit 0;
  }

  #
  # Module updater.
  #
  # XXX This is not clean. We really need separate packages, managed
  #     by the VMware package manager
  #

  if (internal_basename($0) eq $cModuleUpdaterFileName) {
    my $installed_version;
    my $installed_kind;
    my $answer;

    print wrap('Looking for a currently installed '
               . vmware_longname() . ' tar package.' . "\n\n", 0);

    if (not (-e $cInstallerMainDB)) {
      error('Unable to find the ' . vmware_product_name() .
      ' installer database file (' . $cInstallerMainDB . ').' .
      "\n\n" . 'You may want to re-install the ' .
      vmware_longname() . ' package, then re-run this program.' . "\n\n");
    }
    db_load();

    $installed_version = get_installed_version();
    $installed_kind = get_installed_kind();

    if (not (($installed_version eq '6.7.0') and
             ($installed_kind eq 'tar'))) {
      error('This ' . vmware_product_name()
            . ' Kernel Modules package is intended to be used in conjunction '
            . 'with the ' . vmware_longname() . ' tar package only.' . "\n\n");
    }

    # All module files are under LIBDIR
    if (not defined($gDBAnswer{'LIBDIR'})) {
       error('Unable to determine where the ' . vmware_longname()
       . ' package installed the library files.' . "\n\n"
       . 'You may want to re-install the ' . vmware_product_name() . ' '
       . vmware_version() . ' package, then re-run this program.' . "\n\n");
    }

    db_append();
    uninstall_module();
    install_module();

    print wrap('The installation of ' . vmware_product_name()
               . ' Kernel Modules '
               . vmware_version() . ' completed successfully.' . "\n\n", 0);

    if (-e $cConfFlag) {
       $answer = get_persistent_answer('Before running the VMware software for '
                                       . 'the first time after this update, you'
                                       . ' need to configure it for your '
                                       . 'running kernel by invoking the '
                                       . 'following command: "'
                                       . db_get_answer('BINDIR')
                                       . '/' . $gConfigurator . '". Do you want this '
                                       . 'program to invoke the command for you now?',
                                       'RUN_CONFIGURATOR', 'yesno', 'yes');
    } else {
      $answer = 'no';
    }

    db_save();

    if ($answer eq 'yes') {
       system(shell_string(db_get_answer('BINDIR') . '/' . $gConfigurator));
    } else {
       print wrap('Enjoy,' . "\n\n" . '    --the VMware team' . "\n\n", 0);
    }
    exit 0;
  }

  if (internal_basename($0) eq $gUninstallerFileName) {
    print wrap('Uninstalling the tar installation of ' .
    vmware_product_name() . '.' . "\n\n", 0);

    if ($#ARGV > -1) {
      @setOption = ();
      # There is currently only one option:  --upgrade.
      while ($#ARGV != -1) {
        my $arg;
        $arg = shift(@ARGV);
        if (lc($arg) =~ /^(-)?(-)?u(pgrade)?$/) {
           $gOption{'upgrade'} = 1;
        } elsif ($arg =~ /=yes/ || $arg =~ /=no/) {
            push(@setOption, $arg);
        }
      }
    }

    if (not (-e $gInstallerMainDB)) {
      error('Unable to find the tar installer database file (' .
      $gInstallerMainDB . ')' . "\n\n");
    }
    db_load();

    db_append();

    ### Begin check for non-VMware modules ###
    foreach $opt (@setOption) {
       my ($key, $val);
      ($key, $val) = ($opt =~ /^([^=]*)=([^=]*)/);
      delete $gDBAnswer{$key};
      db_add_answer($key, $val);
    }

    uninstall('/vmware-vcli');

    db_save();
    my $msg = 'The removal of ' . vmware_longname() . ' completed '
              . 'successfully.';
    if (!defined($gOption{'upgrade'}) || $gOption{'upgrade'} == 0) {
       $msg .= "  Thank you for having tried this software.";
    }
    $msg .= "\n\n";
    print wrap($msg, 0);

    exit 0;
  }

  error('This program must be named ' . $cInstallerFileName . ' or '
        . $gUninstallerFileName . '.' . "\n\n");
}

main();

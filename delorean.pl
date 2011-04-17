#!/usr/bin/perl
# DeLorean 1.0 by Dave Hensley
# Usage: find /important/data/ -print | delorean.pl /backup/directory/

use Date::Manip qw(UnixDate);
use File::Copy;
use File::Path;

sub set_stat {
  my ($file, @stat) = @_;
  chown $stat[4], $stat[5], $file;
  utime $stat[8], $stat[9], $file;
}

sub get_parent_dir {
  my ($file) = @_;
  $file =~ s/\/[^\/]+\/?$//;
  return $file;
}

$TARGET_DIR = shift;
$date_str = UnixDate('now', '%Y-%m-%d');
($day_of_month, $day_of_week) = split /\s/, UnixDate($date_str, '%d %w');
# We refuse to start if there's already a '.tmp' directory. Maybe DeLorean is already running?
(-e "$TARGET_DIR/daily/.tmp") && die "Temporary directory '$TARGET_DIR/daily/.tmp' already exists! Aborting.\n";
mkpath "$TARGET_DIR/daily/.tmp";

while (<STDIN>) {
  chomp($file = $_);
  @file_stat = lstat $file;
  $parent_dir = get_parent_dir($file);
  @parent_dir_stat = stat $parent_dir;
  (-d $file) && mkpath "$TARGET_DIR/daily/.tmp/$file"; # If this is a directory

  if (-l $file) {
    symlink(readlink $file, "$TARGET_DIR/daily/.tmp/$file"); # If this is a symlink
  } elsif (-f $file) { # If this is a normal file
    if (-e "$TARGET_DIR/current/$file") { # If file already exists in backup
      @old_file_info = stat "$TARGET_DIR/current/$file";
    } else { # File is new, so no old stats to grab.
      @old_file_info = ();
    }

    if ($file_stat[9] == $old_file_info[9]) { # Modified date is the same. Make a hard link.
      link "$TARGET_DIR/current/$file", "$TARGET_DIR/daily/.tmp/$file";
    } else { # File is new or modified! Copy it.
      copy $file, "$TARGET_DIR/daily/.tmp/$file";
    }
  }

  # Set file permissions/timestamps for the file AND the parent directory (whose stats which will have changed).
  # (Skip symlinks because lchown() and lchmod() are not implemented in perl, and lutime() requires
  # kernel >= 2.6.22, which is not offered in some distributions (e.g. RHEL 5).)
  if (!-l $file) {
    set_stat("$TARGET_DIR/daily/.tmp/$file", @file_stat);
  }

  set_stat("$TARGET_DIR/daily/.tmp/$parent_dir", @parent_dir_stat);

  if ($day_of_week == 1) { # Make weekly snapshot (if today is Monday)
    mkpath "$TARGET_DIR/weekly/$date_str";

    if (-d $file) {
      mkpath "$TARGET_DIR/weekly/$date_str/$file";
    } else {
      link "$TARGET_DIR/daily/.tmp/$file", "$TARGET_DIR/weekly/$date_str/$file";
    }

    set_stat("$TARGET_DIR/weekly/$date_str/$file", @file_stat);
    set_stat("$TARGET_DIR/weekly/$date_str/$parent_dir", @parent_dir_stat);
  }

  if ($day_of_month == 1) { # Make monthly snapshot (if today is the 1st)
    mkpath "$TARGET_DIR/monthly/$date_str";

    if (-d $file) {
      mkpath "$TARGET_DIR/monthly/$date_str/$file";
    } else {
      link "$TARGET_DIR/daily/.tmp/$file", "$TARGET_DIR/monthly/$date_str/$file";
    }

    set_stat("$TARGET_DIR/monthly/$date_str/$file", @file_stat);
    set_stat("$TARGET_DIR/monthly/$date_str/$parent_dir", @parent_dir_stat);
  }
}

# Label our new snapshot with today's date and point the 'current' directory to it
move "$TARGET_DIR/daily/.tmp", "$TARGET_DIR/daily/$date_str";
unlink "$TARGET_DIR/current";
symlink "$TARGET_DIR/daily/$date_str", "$TARGET_DIR/current";

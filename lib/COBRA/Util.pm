package COBRA::Util;

=head1 NAME

COBRA::Util - Utilities and configuration for COBRA

=head1 VERSION

This documentation refers to COBRA::Util version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

use Smart::Comments '###';

use Readonly              qw(Readonly);
use File::Spec::Functions qw(catfile catdir updir);
use FindBin               qw();

use Fatal qw(open close);
# NOTE: whenever Fatal takes care of a function that behaves depending on the
# context (using wantarray()), the context recognition doesn't work!
#
# for read_file we can do: my $array_ref = read_file($file, array_ref => 1)
# (use COBRA::Util::read_file for this purpose)
#
# no solutions (yet) for: readdir, closedir(!)

use base qw(Exporter);
our @EXPORT_OK = qw(
  %DIR_NAME_FOR %DIR_PATH_FOR %FILE_NAME_FOR
  $HELP_ON_LEARNERS $HELP_ON_FORMATS
  check_for_files write_class_map read_file
);


################################################################################
# CONSTANTS                                                                    #
################################################################################

Readonly our %DIR_NAME_FOR => (
  collect => q{collect},
  etc     => q{etc},
  import  => q{import},
  export  => q{export},
  records => q{records},
  state   => q{STATE},
);

my $base_dir = catdir($FindBin::Bin, updir);
Readonly our %DIR_PATH_FOR => (
  base    => $base_dir,
  collect => catdir($base_dir, $DIR_NAME_FOR{collect}),
  etc     => catdir($base_dir, $DIR_NAME_FOR{etc}),
);

Readonly our %FILE_NAME_FOR => (
  collect_conf      => q{collect.conf},
  initial_class_map => q{initial_class.map},
  result_class_map  => q{result_class.map},
  state             => q{state},
);

Readonly our $HELP_ON_LEARNERS =>
  q{List of available learning algorithms

    DecisionTree - Decision Tree Learner
    Guesser      - Simple guessing based on class probabilities
    KNN          - K Nearest Neighbour Algorithm
    NaiveBayes   - Naive Bayes Algorithm
    Rocchio      - Rocchio Algorithm
    SVM          - Support Vector Machine Learner
  };

Readonly our $HELP_ON_FORMATS =>
  q{List of available export formats

    Midos   - Midos2000 database
    Gnuplot - plot scripts for Gnuplot
  };


################################################################################
# FUNCTIONS                                                                    #
################################################################################

sub check_for_files {
  my ($dir_name) = @_;

  # sanity check required arguments:
  ### require: defined $dir_name && length $dir_name

  opendir(my $directory => $dir_name);

  my $files = scalar
              grep { -f catfile($dir_name, $_) }
              readdir($directory);

  closedir $directory;

  return $files;
}


sub write_class_map {
  my ($class_map, %class_hash) = @_;

  # sanity check required arguments:
  ### require: defined $class_map && length $class_map

  open(my $class_file, '>', $class_map);

  foreach my $id (sort keys %class_hash) {
    print $class_file join(q{ } => $id, @{$class_hash{$id}}), "\n";
  }

  close $class_file;

  return;
}


sub read_file {
  # whenever Fatal takes care of a function that behaves depending on the
  # context (using wantarray()), the context recognition doesn't work!
  # for File::Slurp::read_file we can do:
  #
  #   my $array_ref = read_file($file, array_ref => 1)
  #
  # (we use this utility function as a convenience wrapper)

  my ($file) = @_;
  my $array_ref = File::Slurp::read_file($file, array_ref => 1)
    or croak("Couldn't read file '$file': $!");

  return wantarray ? @{$array_ref} : $array_ref;
}


1;


__END__

=head1 SYNOPSIS [STILL MISSING!]

    use COBRA::Util qw(...);
    # Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


=head1 DESCRIPTION [STILL MISSING!]

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.)

=head1 SUBROUTINES [STILL MISSING!]

A separate section listing the public components of the module's interface.
These normally consist of subroutines that may be exported.

=head2 Exported subroutines

NONE.

=head2 Importable subroutines

=over

=item check_for_files

TO-BE-DOCUMENTED

=item write_class_map

TO-BE-DOCUMENTED

=back


=head1 EXAMPLES [STILL MISSING!]

Many people learn better by example than by explanation, and most learn better
by a combination of the two. Providing a I</demo> directory stocked with well-
commented examples is an excellent idea, but users might not have access to the
original distribution, and demos are unlikely to have been installed for them.
Adding a few illustrative examples in the documentation itself can greatly
increase the "learnability" of your code.


=head1 DIAGNOSTICS [STILL MISSING!]

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.


=head1 CONFIGURATION AND ENVIRONMENT [STILL MISSING!]

A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables and properties that can be set. These
descriptions must also include details of any configuration language used.


=head1 DEPENDENCIES [STILL MISSING!]

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules
are part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.


=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indications of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.

There are no known bugs in this module. Please report problems to Jens Wille
C<< <jens.wille@gmail.com> >>. Patches are welcome.


=head1 AUTHOR

Jens Wille C<< <jens.wille@gmail.com> >>


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006 Jens Wille C<< <jens.wille@gmail.com> >>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


=head1 SEE ALSO/REFERENCES

Often there will be other modules and applications that are possible
alternatives to using your software. Or other documentation that would be of
use to the users of your software. Or a journal article or book that explains
the ideas on which the software is based. Listing those in a "See Also" section
allows people to understand your software better and to find the best solution
for their problems themselves, without asking you directly.

L<COBRA|COBRA>


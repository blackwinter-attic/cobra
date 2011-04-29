package COBRA::WrapIndexer;

=head1 NAME

COBRA::WrapIndexer - Abstract base class for wrapping automatic indexers

=head1 VERSION

This documentation refers to COBRA::WrapIndexer version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

use Carp;

use Smart::Comments '###';

use Class::Std;

use File::chdir qw($CWD);
use Cwd         qw(realpath);
use POSIX       qw(WIFEXITED);


################################################################################
# CONSTRUCTOR                                                                  #
################################################################################

# provide own constructor to prevent this class from being used directly
{
  # suppress "Subroutine new redefined" warning
  no warnings 'redefine';

  sub new {
    croak("Don't use this class directly, use an appropriate subclass instead!");
  }
}


################################################################################
# INSTANCE METHODS                                                             #
################################################################################

sub run {
  my $self = shift;
  my @files = @_;

  my $cmd = $self->get_cmd();
  #my @args = map { realpath($_) } @files;
  my @args = ();
  @files = map { realpath($_) } @files;

  # sanity check required argument:
  ### require: -x $cmd

  # use provided arguments if applicable
  if ($self->can('get_args')) {
    my $init_args = $self->get_cmd_args();

    if (ref $init_args eq 'ARRAY' && @{$init_args}) {
      unshift(@args => @{$init_args});
    }
  }

  # run command...
  {
    # change working directory if necessary
    local $CWD;
    $CWD = $self->get_chdir()
      if $self->can('get_chdir');

    # dunno how to overcome "argument list too long" restriction :-(
    # WORKAROUND: process only 100 files at a time...
    while (my @chunk_of_files = splice(@files => 0, 100)) {
      my @current_args = (@args, @chunk_of_files);

      # now run...
      WIFEXITED(system($cmd, @current_args))
        or croak("Couldn't execute: $cmd @current_args: $!");
    }
  }

  return;
}


sub get_results {
  # to be overridden by subclass

  croak("This method has to be overridden by subclass!");

  # must return a hash of arrays of hashes:
  #
  # %results = (
  #   <file> => [
  #               { term => 'bla', weight => 1, ... },
  #               ...
  #             ],
  #   ...
  #);
  #
  # with at least a 'term' key in the final hash
}


sub get_plain_results {
  my $self = shift;
  my @files = @_;

  my $repeat = $self->can('get_repeat') ? $self->get_repeat()
             :                            0;

  my %results = $self->get_results(@files);

  my %plain_results = ();
  foreach my $file (keys %results) {
    foreach my $result (@{$results{$file}}) {
      my $count = $repeat ? $result->{weight} || 1
                :           1;

      push(@{$plain_results{$file}} => $result->{term})
        for 1 .. $count;
    }
  }

  # %plain_results = hash of arrays of terms:
  #
  # %plain_results = (
  #   <file> => [ 'bla', ... ],
  #   ...
  #);

  return wantarray ? %plain_results : \%plain_results;
}


1;


__END__

=head1 SYNOPSIS

    Don't use COBRA::WrapIndexer directly, use an appropriate subclass instead.


=head1 DESCRIPTION [STILL MISSING!]

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.)


=head1 METHODS [STILL MISSING!]

A separate section listing the public components of the module's interface.
These normally consist of methods that may be called on objects belonging to
the classes that the module provides.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.

=head2 Constructor

=over

=item new

TO-BE-DOCUMENTED

=back

=head2 Public interface methods

=over

=item run

TO-BE-DOCUMENTED

=item get_results

TO-BE-DOCUMENTED

=item get_plain_results

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

Copyright (C) 2006-2011 Jens Wille C<< <jens.wille@gmail.com> >>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Affero General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


=head1 SEE ALSO/REFERENCES

Often there will be other modules and applications that are possible
alternatives to using your software. Or other documentation that would be of
use to the users of your software. Or a journal article or book that explains
the ideas on which the software is based. Listing those in a "See Also" section
allows people to understand your software better and to find the best solution
for their problems themselves, without asking you directly.

L<COBRA|COBRA>, L<COBRA::WrapIndexer::Lingo|COBRA::WrapIndexer::Lingo>


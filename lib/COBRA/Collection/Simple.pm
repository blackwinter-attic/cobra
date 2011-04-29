package COBRA::Collection::Simple;

=head1 NAME

COBRA::Collection::Simple - Abstract base class for collections from "simple" records

=head1 VERSION

This documentation refers to COBRA::Collection::Simple version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

use Carp;

use Smart::Comments '###';

use Class::Std;

use COBRA::Util qw(read_file);

use base qw(COBRA::Collection);


################################################################################
# OBJECT ATTRIBUTES                                                            #
################################################################################

# internal attributes (set during START())
my %delimiter_re : ATTR(:get<delimiter_re>);


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
# INITIALIZATION                                                               #
################################################################################

sub START {
  my ($self, $ident, $arg_ref) = @_;

  # regular expression that separates a field label from its content
  $delimiter_re{$ident} = qr{\s*:\s*}o;
}


################################################################################
# INSTANCE METHODS                                                             #
################################################################################

sub parse_records {
  my $self = shift;
  my ($data_files_ref, $arg_ref) = @_;

  my $field_re           = $arg_ref->{field_re};
  my $ratio              = $arg_ref->{ratio};
  my $integrity_checking = $arg_ref->{integrity_checking};

  # sanity check required arguments:
  ### require: defined $data_files_ref && ref $data_files_ref eq "ARRAY"
  ### require: defined $field_re && length $field_re
  ### require: defined $ratio && length $ratio
  ### require: $ratio =~ m{\A -[12] \z}xms || ($ratio >= 0 && $ratio <= 100)

  my $delimiter_re   = $self->get_delimiter_re();
  my $id_re          = $self->get_id_re();
  my $class_re       = $self->get_class_re();
  my $class_split_re = $self->get_class_split_re();

  # build regexp to match desired fields
  $field_re = qr{\A(?:$field_re)$delimiter_re}o;

  # map classes to record id's
  my %class_hash = ();

  # remember written files for indexing
  my @outfiles = ();

  foreach my $infile (@{$data_files_ref}) {
    my @lines = read_file($infile);

    # specifies where to put imported data; if ratio is not equal to 0,
    # the target set ('train' or 'test') will be chosen randomly, based
    # on that ratio
    my $target_set = '';

    # other containers
    my $id          = '';
    my %seen        = ();
    my @buffer      = ();
    my @classes     = ();
    my $line_number = 0;

    LINE:
    foreach my $line (@lines) {
      $line_number++;
      chomp $line;

      # records are separated by empty lines
      unless ($line) {
        # write buffer
        if (@buffer) {
          croak("Invalid record at $infile, line $line_number")
            unless $id && $target_set && @classes;

          # skip duplicates
          unless ($seen{$id}++) {
            my @written = $self->write_record(
                            \@buffer,
                            { id         => $id,
                              target_set => $target_set,
                              duplicate  => $integrity_checking, }
                          );
            push(@outfiles => @written);

            @{$class_hash{$id}} = @classes;
          }

          # clear buffer and classes
          @buffer  = ();
          @classes = ();
        }

        next LINE;
      }

      if ($line =~ $id_re) {
        # encountered an id
        $id = $1;

        $target_set = $self->_determine_target_set($ratio);
      }

      if ($line =~ $class_re) {
        # class assignments
        (my $class_list = $line) =~ s{$class_re}{};
        @classes = map { $_ =~ s{\A\*}{}o; $_ }
                   sort
                   split($class_split_re => $class_list)
      }

      if ($line =~ $field_re) {
        # ordinary line matching one of the desired fields
        # (may be id or class field as well)
        (my $content = $line) =~ s{$field_re}{};
        push(@buffer => $content);
      }
      else {
        # other line -- just skip
      }
    }
  }

  return \%class_hash, \@outfiles;
}


1;


__END__

=head1 SYNOPSIS

    Don't use COBRA::Collection::Simple directly, use an appropriate subclass instead.


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

=item parse_records

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

L<COBRA|COBRA>, L<COBRA::Collection|COBRA::Collection>


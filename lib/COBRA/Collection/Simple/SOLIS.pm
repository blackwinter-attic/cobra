package COBRA::Collection::Simple::SOLIS;

=head1 NAME

COBRA::Collection::Simple::SOLIS - Create collection from "simple" SOLIS records

=head1 VERSION

This documentation refers to COBRA::Collection::Simple::SOLIS version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

use Carp;

use Smart::Comments '###';

use Class::Std;

use Readonly qw(Readonly);

use COBRA::Util qw(read_file);

use base qw(Exporter);
our @EXPORT_OK = qw($HELP_ON_FIELDS);

use base qw(COBRA::Collection::Simple);


################################################################################
# CONSTANTS                                                                    #
################################################################################

Readonly my $PACKNAME => __PACKAGE__;

Readonly our $HELP_ON_FIELDS =>
 qq{List of available fields for $PACKNAME

    TI - title
    ME - method
    LA - language
    DN - document number
    CT - controlled term
    CC - classification code
    AB - abstract
  };


################################################################################
# OBJECT ATTRIBUTES                                                            #
################################################################################

# internal attributes (set during START())
my %id_re          : ATTR(:get<id_re>         );
my %class_re       : ATTR(:get<class_re>      );
my %class_split_re : ATTR(:get<class_split_re>);


################################################################################
# INITIALIZATION                                                               #
################################################################################

sub START {
  my ($self, $ident, $arg_ref) = @_;

  # get delimiter from parent class
  my $delimiter_re = $self->get_delimiter_re();

  # regular expression to extract the record identifier, captured by parentheses
  $id_re{$ident}          = qr{\A#(\d+)}o;
  # regular expression to extract the assigned classes
  $class_re{$ident}       = qr{\ACC$delimiter_re}o;
  # regular expression to split the assigned classes
  $class_split_re{$ident} = qr{\s*;\s*}o;
}


1;


__END__

=head1 SYNOPSIS [STILL MISSING!]

    use COBRA::Collection::Simple::SOLIS;
    # Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


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

L<COBRA|COBRA>, L<COBRA::Collection|COBRA::Collection>


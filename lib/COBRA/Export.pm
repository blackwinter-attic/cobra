package COBRA::Export;

=head1 NAME

COBRA::Export - Export collection to original format

=head1 VERSION

This documentation refers to COBRA::Export version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

use Carp;
#use Fatal qw(open close);

use Class::Std;


# provide own constructor to throw error when used
{
  # suppress "Subroutine new redefined" warning
  no warnings 'redefine';

  sub new {
    croak("Not implemented yet!");
  }
}


1;


__END__

=head1 SYNOPSIS

    NOT IMPLEMENTED YET!


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.)


=head1 METHODS

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



=back


=head1 EXAMPLES

Many people learn better by example than by explanation, and most learn better
by a combination of the two. Providing a I</demo> directory stocked with well-
commented examples is an excellent idea, but users might not have access to the
original distribution, and demos are unlikely to have been installed for them.
Adding a few illustrative examples in the documentation itself can greatly
increase the "learnability" of your code.


=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.


=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables and properties that can be set. These
descriptions must also include details of any configuration language used.


=head1 DEPENDENCIES

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

L<COBRA|COBRA>, L<COBRA::Export::Midos|COBRA::Export::Midos>,
L<COBRA::Export::Gnuplot|COBRA::Export::Gnuplot>


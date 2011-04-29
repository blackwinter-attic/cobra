package COBRA::WrapIndexer::Lingo;

=head1 NAME

COBRA::WrapIndexer::Lingo - Wrapper for the automatic indexing program Lingo

=head1 VERSION

This documentation refers to COBRA::WrapIndexer::Lingo version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

use Carp;

use Smart::Comments '###';

use Class::Std;

use File::Spec::Functions qw(catfile);
use Cwd                   qw(realpath);
use POSIX                 qw(WIFEXITED);

use COBRA::Util qw(read_file);

use base qw(COBRA::WrapIndexer);


################################################################################
# OBJECT ATTRIBUTES                                                            #
################################################################################

# external attributes (arguments)
# don't provide any (sensible) default values: they have to be supplied when
# creating the object (and they are sanity checked when first needed)
my %path   : ATTR(:name<path>   :default(''));
my %args   : ATTR(:name<args>   :default(''));
my %effect : ATTR(:name<effect> :default(''));
my %repeat : ATTR(:name<repeat> :default(''));

# internal attributes (set during START())
my %ruby       : ATTR(:get<ruby>      );
my %ruby_args  : ATTR(:get<ruby_args> );
my %lingo      : ATTR(:get<lingo>     );
my %lingo_args : ATTR(:get<lingo_args>);
my %lingo_conf : ATTR(:get<lingo_conf>);
my %cmd        : ATTR(:get<cmd>       );
my %cmd_args   : ATTR(:get<cmd_args>  );
my %chdir      : ATTR(:get<chdir>     );


################################################################################
# INITIALIZATION                                                               #
################################################################################

sub START {
  my ($self, $ident, $arg_ref) = @_;

  my $path = $arg_ref->{path};

  # sanity check required argument:
  ### require: defined $path && length $path
  ### require: -d $path

  $ruby{$ident}       = '/usr/bin/ruby';
  $ruby_args{$ident}  = ['-Kn', '-S'];
  $lingo{$ident}      = catfile($path, 'lingo.rb');
  $lingo_args{$ident} = $arg_ref->{args} || [];
  $lingo_conf{$ident} = catfile($arg_ref->{cobra_etc}, 'lingo.conf');

  croak("Couldn't find lingo.rb '$lingo{$ident}'\n"
      . "(Perhaps your path is wrong?)")
    unless -f $lingo{$ident};

  croak("Couldn't find lingo configuration file '$lingo_conf{$ident}'")
    unless -r $lingo_conf{$ident};

  $cmd{$ident}      = $ruby{$ident};
  $cmd_args{$ident} = [
    @{$ruby_args{$ident}},
    $lingo{$ident},
    '-c', realpath($lingo_conf{$ident}),
    @{$lingo_args{$ident}},
  ];

  # lingo needs to be called from its base directory
  $chdir{$ident} = $path;
}


sub get_results {
  my $self = shift;
  my @files = @_;

  my %results = ();

  # do the actual reading...
  foreach my $file (@files) {
    my $results_file = $file . '.vec';

    my @result_lines = read_file($results_file);

    foreach my $line (@result_lines) {
      chomp $line;

      if ($line =~ m{\A \s* (\d+|\d*\.\d+) \s+ (.*?) \s* \z}xms) {
        my ($term, $weight) = ($2, $1);

        push(@{$results{$file}} => { term => $term, weight => $weight });
      }
      else {
        carp("Invalid entry in file '$results_file':\n"
           . "$line");
      }
    }

    unlink $results_file;
  }

  # %results = hash of arrays of hashes:
  #
  # %results = (
  #   <file> => [
  #               { term => 'bla', weight => 1, ... },
  #               ...
  #             ],
  #   ...
  #);

  return wantarray ? %results : \%results;
}


1;


__END__

=head1 SYNOPSIS

    use COBRA::WrapIndexer::Lingo;
    # Brief but working code examples here showing the most common usages:

    # This section will be as far as many users ever read, so we
    # try to make it as educational and exemplary as possible ;-)

    # Create lingo object:
    my $lingo = COBRA::WrapIndexer::Lingo->new({ path => $path_to_lingo,
                                                 args => \@lingo_args });

    # Run indexing:
    $lingo->run(@files);

    # Get results (hash of arrays of hashes):
    my $results = $lingo->get_results(@files);

    # Or, in "plain" form (hash of arrays of terms):
    my $results = $lingo->get_plain_results(@files, $repeat);


=head1 DESCRIPTION [STILL MISSING!]

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.)

NOTE: The Lingo configuration has to be in line with the L<get_results>
function! See below for details. Also the Lingo program has to meet certain
conditions that weren't present as of version 1.6.1 -- see the following diff:


    *** lib/attendee/textwriter.rb       2006-06-20 13:42:11.000000000 +0200
    --- lib/attendee/textwriter.rb~      2006-03-25 03:06:37.000000000 +0100
    ***************
    *** 95,96 ****
    !                       #@filename = par.gsub(/[^\.]+$/, @ext)
    !                       @filename = par.sub(/(?:\.[^.]+)?$/, '.'+@ext)
    --- 95 ----
    !                       @filename = par.gsub(/[^\.]+$/, @ext)
    ===============================================================================
    *** lib/config.rb       2006-06-20 13:42:11.000000000 +0200
    --- lib/config.rb~      2006-03-25 03:06:37.000000000 +0100
    ***************
    *** 34 ****
    !               @options = load_yaml_file(prog.sub(/\.[^\.]+$/, ''), '.opt')
    --- 34 ----
    !               @options = load_yaml_file(prog, '.opt')
    ***************
    *** 90,94 ****
    -               #if file_name =~ /\./
    -               #       yaml_file = file_name.sub(/\.([^\.]+)$/, file_ext)
    -               #else
    -               #       yaml_file = file_name + file_ext
    -               #end
    --- 89 ----
    ***************
    *** 96 ****
    !                       yaml_file = file_name
    --- 91 ----
    !                       yaml_file = file_name.sub(/\.([^\.]+)$/, file_ext)
    ***************
    *** 100 ****
    --- 96 ----
    +


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

=item get_results

Parses the resulting C<< .vec >> files, thus giving access to the indexing
results. Takes a list of indexed files as argument, inferring from these the
particular result files. Returns a hash of C<< file name => array of hashes >>
pairs, with the latter hashes consisting of C<< 'term' => index term >> and
C<< 'weight' => assigned weight >> pairs. In order for this to work properly
the Lingo configuration must adhere to the following constraints: 1) The
I<vector_filter> must sort by absolute term frequency (C<< sort: 'term_abs' >>),
yielding a C<< frequency term >> format of the result file; 2) the I<textwriter>
must assign the extension C<< .vec >> to the result files (C<< ext: vec >>) and
3) must separate entries in the result file by newlines (C<< sep: "\n" >>).
Also see the sample Lingo configuration file F<etc/lingo.conf>.

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

L<COBRA|COBRA>, L<COBRA::WrapIndexer|COBRA::WrapIndexer>


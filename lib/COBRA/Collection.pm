package COBRA::Collection;

=head1 NAME

COBRA::Collection - Abstract base class for bibliographic collections

=head1 VERSION

This documentation refers to COBRA::Collection version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

use Carp;

use Smart::Comments '###';

use Class::Std;

use Readonly              qw(Readonly);
use File::Spec::Functions qw(catfile catdir);
use File::Copy            qw(copy);
use File::Find            qw(find);
use File::Slurp           qw(write_file);

use COBRA::Util qw(check_for_files write_class_map read_file);

use Fatal qw(opendir copy write_file open close);
# NOTE: whenever Fatal takes care of a function that behaves depending on the
# context (using wantarray()), the context recognition doesn't work!
#
# for read_file we can do: my $array_ref = read_file($file, array_ref => 1)
# (use COBRA::Util::read_file for this purpose)
#
# no solutions (yet) for: readdir, closedir(!)

use base qw(Exporter);
our @EXPORT_OK = qw($HELP_ON_FIELDS);


################################################################################
# CONSTANTS                                                                    #
################################################################################

Readonly our $HELP_ON_FIELDS =>
  q{List of available fields (FALLBACK MESSAGE)

The collection type you specified doesn't seem to supply this help text. Maybe
see its documentation for more information.
  };


################################################################################
# OBJECT ATTRIBUTES                                                            #
################################################################################

# external attributes (arguments)
# don't provide any (sensible) default values: they have to be supplied when
# creating the object (and they are sanity checked when first needed)
my %collect_dir : ATTR(:name<collect_dir> :default(''));
my %import_dir  : ATTR(:name<import_dir>  :default(''));
my %records_dir : ATTR(:name<records_dir> :default(''));
my %indexer     : ATTR(:name<indexer>     :default(''));


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

  # sanity check required arguments:
  ### require: -d $collect_dir{$ident}
  ### require: -d $import_dir{$ident}
  ### require: -d $records_dir{$ident}
  ### require: defined $indexer{$ident}

  # these attributes need to be supplied by subclasses, so make sure they do
  ### require: $self->can("get_id_re")
  ### require: $self->can("get_class_re")
  ### require: $self->can("get_class_split_re")
}


################################################################################
# INSTANCE METHODS                                                             #
################################################################################

sub do_import {
  my $self = shift;
  my ($arg_ref) = @_;

  my $supplied_files = $arg_ref->{data_files};
  my $class_map      = $arg_ref->{class_map};
  my $fields         = $arg_ref->{fields};
  my $ratio          = $arg_ref->{ratio};
  my $keepold        = $arg_ref->{keepold};

  my $records_dir = $self->get_records_dir();

  # what are we doing?
  my %do = (
    train           => $ratio >= 0 && $ratio <  100,
    test            => $ratio >  0 && $ratio <= 100,
    categorize      => $ratio == -1,
    check_integrity => $ratio == -2,
  );

  # sanity check required arguments:
  ### require: defined $supplied_files
  ### require: defined $class_map && length $class_map
  ### check: defined $fields && ref $fields eq "ARRAY"
  ### require: defined $ratio && length $ratio
  ### require: $ratio =~ m{\A -[12] \z}xms || ($ratio >= 0 && $ratio <= 100)
  ### require: defined $keepold

  # get data files, place supplied ones in import dir
  my @data_files = $self->_get_data_files($supplied_files)
    or croak("No data files found in import directory");

  # check if directories already contain files
  my %num_files = ();
  foreach my $directory (grep { $do{$_} && $_ ne 'check_integrity' } keys %do) {
    my $num = check_for_files(catdir($records_dir, $directory));
    $num_files{$directory} = $num
      if $num;
  }

  my $files_message = "The following directories already contain files:\n"
                    . join(q{} => map { "$_: $num_files{$_}\n" } sort keys %num_files);

  if (%num_files) {
    $keepold ? carp($files_message  . "(These files will be kept.)")
    :          croak($files_message . "(Perhaps you forgot to clean up? Otherwise"
                                    . " use '-keepold' to keep these files.)");
  }

  # build regexp to match desired fields (OR-list)
  my $field_re = join('|' => map { $_ =~ s{\A#ALL#\z}{};
                                   quotemeta($_) } @{$fields})
                 || '.*?';

  my %parse_args = (
    field_re           => $field_re,
    ratio              => $ratio,
    integrity_checking => $do{check_integrity},
  );

  # read and write records
  my ($class_hash_ref, $outfiles_ref)
    = $self->parse_records(\@data_files, \%parse_args);

  write_class_map($class_map => %{$class_hash_ref})
    unless $do{categorize};

  $self->_do_indexing(@{$outfiles_ref});

  return;
}


sub parse_records {
  # to be overridden by subclass

  croak("This method has to be overridden by subclass!");

  # must return hash ref of class map
  # and array ref of written files
}


sub write_record {
  my $self = shift;
  my ($buffer_ref, $arg_ref) = @_;

  my $id         = $arg_ref->{id};
  my $target_set = $arg_ref->{target_set};
  my $duplicate  = $arg_ref->{duplicate};

  my $records_dir = $self->get_records_dir();

  # sanity check required arguments:
  ### require: defined $buffer_ref && ref $buffer_ref eq "ARRAY"
  ### require: defined $id && length $id
  ### require: defined $target_set && length $target_set
  ### require: defined $duplicate
  ### require: defined $records_dir && length $records_dir
  ### require: -d $records_dir

  my @buffer = map {
                     # clean up use of white-space -- really?!?
                     $_ =~ s{\s+}{ }g;
                     # make each entry in buffer a line ending
                     # with a dot (i.e., a "sentence")
                     $_ =~ s{[.;?!]*\z}{}; $_ .= ".\n"
                   } @{$buffer_ref};

  # in case ratio is -1, target set is always 'train' (see below)
  my @target_sets = ($target_set);
  push(@target_sets => 'test')
    if $duplicate;

  my @outfiles = ();
  foreach my $set (@target_sets) {
    my $outfile = catfile($records_dir, $set, $id);
    write_file($outfile, @buffer);

    push(@outfiles => $outfile);
  }

  return @outfiles;
}


################################################################################
# INTERNAL UTILITIES                                                           #
################################################################################

sub _get_data_files : RESTRICTED {
  my $self = shift;
  my ($supplied_files) = @_;

  my $import_dir = $self->get_import_dir();

  # sanity check required arguments:
  ### require: defined $supplied_files
  ### require: defined $import_dir && length $import_dir
  ### require: -d $import_dir

  my @data_files = ();

  if (ref $supplied_files eq 'ARRAY'
     && @{$supplied_files}) {
    @data_files = @{$supplied_files};

    foreach my $file (@data_files) {
      copy($file => $import_dir);
    }
  }
  else {
    my $wanted = sub {
      push(@data_files => $File::Find::name)
        if -f $_;
    };
    find($wanted, $import_dir);
  }

  return @data_files;
}


sub _determine_target_set : RESTRICTED {
  my $self  = shift;
  my ($ratio) = @_;

  # sanity check required arguments:
  ### require: defined $ratio && length $ratio
  ### require: $ratio =~ m{\A -[12] \z}xms || ($ratio >= 0 && $ratio <= 100)

  # in case ratio is -2, the target set is always 'train'
  return $ratio == -1             ? 'categorize'
  # TODO: more sophisticated decision making, based on class probabilities!?
       : (rand(1) > $ratio / 100) ? 'train'
       :                            'test';
}


sub _do_indexing {
  my $self = shift;
  my @files = @_;

  my $indexer = $self->get_indexer();

  # only do indexing if requested
  return unless length $indexer && $indexer->isa('COBRA::WrapIndexer');

  # do indexing...
  $indexer->run(@files);

  # ...and get results
  my %results = $indexer->get_plain_results(@files);

  # add or replace?
  my $effect = $indexer->get_effect();

  foreach my $file (@files) {
    my @buffer = $effect ne 'replace' ? read_file($file)
               :                        ();

    write_file($file, @buffer, map { $_ .= "\n" } @{$results{$file}});
  }

  return;
}


1;


__END__

=head1 SYNOPSIS

    Don't use COBRA::Collection directly, use an appropriate subclass instead.


=head1 DESCRIPTION [STILL MISSING!]

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

=item do_import

Imports the collection by first detecting which files to import (using the
L<_get_data_files()|/item__get_data_files> function) and checking if there
already are any data imported (using the
L<COBRA::Util::check_for_files()|COBRA::Util/item_check_for_files> function)
which will then be kept only if the C<< keepold >> option was true. Then
calls the collection object's L<parse_records()|/item_parse_records> method,
saves the initial category information to a file (using the
L<COBRA::Util::write_class_map()|COBRA::Util/item_write_class_map> function)
and finally calls the indexer through L<_do_indexing|/item__do_indexing>.

Takes a hash reference of options as argument. These include: C<< data_files >>,
the data files to import (alternatively will be taken from the collection's
F<import/> directory); C<< class_map >>, the file the initial category information
shall be written to; C<< fields >>, the list of fields to import from records;
C<< ratio >>, the percentage of records to use for testing (vs. training),
additionally indicates whether the documents are determined for testing/training
or categorizing or class integrity checking; and C<< keepold >>, a boolean value
specifying whether to exit when there already are imported data or to just give
a warning.

=item parse_records

Not implemented here, has to be overridden by subclasses in order to reflect
collection type-specific characteristics. Takes a reference to the list of
to-be-imported files and a reference to an option hash as arguments. Returns
a reference to a hash of the class mapping and a reference to the array of
written record files. See appropriate subclass for details.

=item write_record

Writes each individual record to a file. Takes a reference to a list of lines
to write and a reference to an option hash as arguments. Options include:
C<< id >>, the record identifier; C<< target_set >>, the set, i.e. directory,
to write the record to; and C<< duplicate >>, a boolean value specifying whether
all records shall be duplicated in the test directory (e.g., for class integrity
checks). Returns a list of the files written.

=back

=head2 Internal utility subroutines

=over

=item _get_data_files

Determines the data files to import, i.e. either the supplied files (which will
also be copied to the collection's F<import/> directory) or the files from the
collection's F<import/> directory. Takes a list of data files as argument.
Returns the list of files found (or simply those passed).

=item _determine_target_set

Determines the set, i.e. the directory, the current record file shall be written
to, depending on the value of the ratio. Currently, it simply uses the ratio as
probability -- in the future a more sophisticated approach may be implemented.
Takes the ratio as argument. Returns the name of the target set (one of
C<< 'train' >>, C<< 'test' >> or C<< 'categorize' >> -- in case the ratio is
set up for integrity checking, the target set will be C<< 'train' >>).

=item _do_indexing

Does the actual indexing of the record files by passing these files to the
L<COBRA::WrapIndexer::run()|COBRA::WrapIndexer/item_run> method, and
subsequently calling the
L<COBRA::WrapIndexer::get_plain_results()|COBRA::WrapIndexer/item_get_plain_results>
method. Decides whether indexing shall be performed at all if an object of a
subclass of L<COBRA::WrapIndexer|COBRA::WrapIndexer> was supplied (created by
L<COBRA::do_import()|COBRA/item_do_import>). Depending on the value of the
C<< effect >> attribute, the indexing results will be added to the original
records or just replace them.

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

L<COBRA|COBRA>, L<COBRA::Collection::Generic|COBRA::Collection::Generic>,
L<COBRA::Collection::STN::SOLIS|COBRA::Collection::STN::SOLIS>,
L<COBRA::Collection::SimpleSOLIS|COBRA::Collection::SimpleSOLIS>


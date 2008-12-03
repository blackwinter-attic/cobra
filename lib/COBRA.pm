package COBRA;

=head1 NAME

COBRA - Classification Of Bibliographic Records, Automatic

=head1 VERSION

This documentation refers to COBRA version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

require UNIVERSAL::require;

use Carp;
use Smart::Comments '###';

use Class::Std;

use AI::Categorizer;

use File::Spec::Functions qw(catfile catdir);
use File::Path            qw(mkpath rmtree);
use File::Slurp           qw(write_file);

use COBRA::Util qw(%DIR_PATH_FOR %DIR_NAME_FOR %FILE_NAME_FOR
                   check_for_files write_class_map read_file);

use Fatal qw(mkpath rmtree write_file);
# NOTE: whenever Fatal takes care of a function that behaves depending on the
# context (using wantarray()), the context recognition doesn't work!
#
# for read_file we can do: my $array_ref = read_file($file, array_ref => 1)
# (use COBRA::Util::read_file for this purpose)
#
# no solutions (yet) for: readdir, closedir


################################################################################
# OBJECT ATTRIBUTES                                                            #
################################################################################

# external attributes (arguments)
# don't provide any (sensible) default values: they have to be supplied when
# creating the object (and they are sanity checked when first needed)
my %action       : ATTR(:name<action>       :default(''));
my %collection   : ATTR(:name<collection>   :default(''));
my %verbosity    : ATTR(:name<verbosity>    :default(''));
my %config_file  : ATTR(:name<config_file>  :default(''));
my %type         : ATTR(:name<type>         :default(''));
my %use_fields   : ATTR(:name<use_fields>   :default(''));
my %indexer      : ATTR(:name<indexer>      :default(''));
my %indexer_base : ATTR(:name<indexer_base> :default(''));
my %indexer_args : ATTR(:name<indexer_args> :default(''));
my %effect       : ATTR(:name<effect>       :default(''));
my %repeat       : ATTR(:name<repeat>       :default(''));
my %ratio        : ATTR(:name<ratio>        :default(''));
my %keepold      : ATTR(:name<keepold>      :default(''));
my %data_files   : ATTR(:name<data_files>   :default(''));
my %learner      : ATTR(:name<learner>      :default(''));
my %format       : ATTR(:name<format>       :default(''));

# internal attributes (set during START())
my %collect_dir        : ATTR(:get<collect_dir>       );
my %etc_dir            : ATTR(:get<etc_dir>           );
my %import_dir         : ATTR(:get<import_dir>        );
my %export_dir         : ATTR(:get<export_dir>        );
my %records_dir        : ATTR(:get<records_dir>       );
my %train_dir          : ATTR(:get<train_dir>         );
my %test_dir           : ATTR(:get<test_dir>          );
my %categorize_dir     : ATTR(:get<categorize_dir>    );
my %state_dir          : ATTR(:get<state_dir>         );
my %collect_conf       : ATTR(:get<collect_conf>      );
my %initial_class_map  : ATTR(:get<initial_class_map> );
my %result_class_map   : ATTR(:get<result_class_map>  );
my %collect_class      : ATTR(:get<collect_class>     );
my %indexer_class      : ATTR(:get<indexer_class>     );
my %learner_class      : ATTR(:get<learner_class>     );
my %categorizer_params : ATTR(:get<categorizer_params>);


################################################################################
# INITIALIZATION                                                               #
################################################################################

sub START {
  my ($self, $ident, $arg_ref) = @_;

  my $collection = $arg_ref->{collection};
  my $type       = $arg_ref->{type};
  my $indexer    = $arg_ref->{indexer};
  my $learner    = $arg_ref->{learner};

  # sanity check required argument:
  ### require: defined $collection && length $collection
  ### require: defined $type && length $type
  ### require: defined $learner && length $learner

  my $collect_dir = catdir($DIR_PATH_FOR{collect}, $collection);
  my $records_dir = catdir($collect_dir, $DIR_NAME_FOR{records});

  $collect_dir{$ident} = $collect_dir;
  $etc_dir{$ident}     = catdir($collect_dir, $DIR_NAME_FOR{etc}  );
  $import_dir{$ident}  = catdir($collect_dir, $DIR_NAME_FOR{import});
  $export_dir{$ident}  = catdir($collect_dir, $DIR_NAME_FOR{export});
  $state_dir{$ident}   = catdir($collect_dir, $DIR_NAME_FOR{state});

  $records_dir{$ident}    = $records_dir;
  $train_dir{$ident}      = catdir($records_dir, 'train'    );
  $test_dir{$ident}       = catdir($records_dir, 'test'     );
  $categorize_dir{$ident} = catdir($records_dir, 'categorize');

  $collect_conf{$ident}      = catfile($etc_dir{$ident},
                                       $FILE_NAME_FOR{collect_conf});
  $initial_class_map{$ident} = catfile($state_dir{$ident},
                                       $FILE_NAME_FOR{initial_class_map});
  $result_class_map{$ident}  = catfile($state_dir{$ident},
                                       $FILE_NAME_FOR{result_class_map});

  ($collect_class{$ident} = 'COBRA::Collection::' . $type) =~ s{/}{::}o;
  $indexer_class{$ident} = 'COBRA::WrapIndexer::'       . $indexer
    if defined $indexer && length $indexer;
  $learner_class{$ident} = 'AI::Categorizer::Learner::' . $learner;

  $categorizer_params{$ident} = {
    'training_set'  => $train_dir{$ident},
    'test_set'      => $test_dir{$ident},
    'category_file' => $initial_class_map{$ident},
    'progress_file' => catfile($state_dir{$ident}, $FILE_NAME_FOR{state}),
    'verbose'       => $self->get_verbosity(),
  };
}


################################################################################
# INSTANCE METHODS                                                             #
################################################################################

sub do_action {
  my $self = shift;
  my ($action_ref) = @_;

  $action_ref ||= $self->get_action();

  # transform to array ref if necessary
  $action_ref = [ $action_ref ]
    unless ref $action_ref eq 'ARRAY';

  # sanity check required argument:
  ### require: defined $action_ref && ref $action_ref eq "ARRAY"

  ACTION:
  foreach my $action (@{$action_ref}) {
    next ACTION unless length $action;

    my $do_action = 'do_' . $action;
    ### require: $self->can($do_action)

    $self->$do_action;
  }

  return;
}


sub do_create {
  my $self = shift;

  my $collection     = $self->get_collection();
  my $collect_dir    = $self->get_collect_dir();
  my $etc_dir        = $self->get_etc_dir();
  my $import_dir     = $self->get_import_dir();
  my $export_dir     = $self->get_export_dir();
  my $state_dir      = $self->get_state_dir();
  my $train_dir      = $self->get_train_dir();
  my $test_dir       = $self->get_test_dir();
  my $categorize_dir = $self->get_categorize_dir();
  my $global_conf    = $self->get_config_file();
  my $collect_conf   = $self->get_collect_conf();

  # sanity check required argument:
  ### require: defined $collection && length $collection

  croak("Collection '$collection' already exists")
    if -d $collect_dir;

  # create directory structure
  # TODO: maybe clone from some "modelcol"?
  foreach my $path ($etc_dir, $import_dir, $export_dir, $state_dir,
                    $train_dir, $test_dir, $categorize_dir) {
    mkpath($path);
  }

  # clone global config file
  $self->_clone_conf($global_conf => $collect_conf,
                      { collection => $collection });

  return;
}


sub do_import {
  my $self = shift;

  my $collection    = $self->get_collection();
  my $collect_dir   = $self->get_collect_dir();
  my $import_dir    = $self->get_import_dir();
  my $records_dir   = $self->get_records_dir();
  my $class_map     = $self->get_initial_class_map();
  my $use_fields    = $self->get_use_fields();
  my $indexer_base  = $self->get_indexer_base();
  my $indexer_args  = $self->get_indexer_args();
  my $effect        = $self->get_effect();
  my $repeat        = $self->get_repeat();
  my $ratio         = $self->get_ratio();
  my $keepold       = $self->get_keepold();
  my $data_files    = $self->get_data_files();
  my $indexer_class = $self->get_indexer_class();
  my $collect_class = $self->get_collect_class();

  # sanity check required arguments:
  ### require: defined $collection && length $collection
  ### require: -d $collect_dir

  # do indexing if requested
  my $indexer_obj = '';
  if (defined $indexer_class) {
    $indexer_class->require()
      or croak("Could not load $indexer_class: $@");

    $indexer_obj = $indexer_class->new({ path      => $indexer_base,
                                         cobra_etc => $DIR_PATH_FOR{etc},
                                         args      => $indexer_args,
                                         effect    => $effect,
                                         repeat    => $repeat, });
  }

  # create collection object
  $collect_class->require()
    or croak("Could not load $collect_class: $@");
  my $collect_obj = $collect_class->new({ collect_dir => $collect_dir,
                                          import_dir  => $import_dir,
                                          records_dir => $records_dir,
                                          indexer     => $indexer_obj, });

  $collect_obj->do_import({ data_files => $data_files,
                            class_map  => $class_map,
                            fields     => $use_fields,
                            ratio      => $ratio,
                            keepold    => $keepold });

  return;
}


sub do_train {
  my $self = shift;

  my $collection    = $self->get_collection();
  my $collect_dir   = $self->get_collect_dir();
  my $records_dir   = $self->get_records_dir();
  my $train_dir     = $self->get_train_dir();
  my $learner_class = $self->get_learner_class();

  my $categorizer_params = $self->get_categorizer_params();
  $categorizer_params->{learner_class} = $learner_class;

  # sanity check required arguments:
  ### require: defined $collection && length $collection
  ### require: -d $collect_dir
  ### require: -d $records_dir
  ### require: -d $train_dir
  ### require: ref $categorizer_params eq "HASH"

  # make sure there are files for training
  croak("No files for training")
    unless check_for_files($train_dir);

  # create categorizer object
  my $categorizer_obj = AI::Categorizer->new(%{$categorizer_params});

  # train ('train')...
  $categorizer_obj->scan_features();
  $categorizer_obj->read_training_set();
  $categorizer_obj->train();

  return;
}


sub do_test {
  my $self = shift;

  my $collection         = $self->get_collection();
  my $collect_dir        = $self->get_collect_dir();
  my $test_dir           = $self->get_test_dir();
  my $categorizer_params = $self->get_categorizer_params();

  # sanity check required arguments:
  ### require: defined $collection && length $collection
  ### require: -d $collect_dir
  ### require: -d $test_dir
  ### require: ref $categorizer_params eq "HASH"

  # make sure there are files for testing
  croak("No files for testing")
    unless check_for_files($test_dir);

  # create categorizer object
  my $categorizer_obj = AI::Categorizer->new(%{$categorizer_params});

  # categorize ('test')...
  $self->_evaluate_test_set($categorizer_obj);

  # print stats...
  print $categorizer_obj->stats_table();

  return;
}


sub do_categorize {
  my $self = shift;

  my $collection         = $self->get_collection();
  my $collect_dir        = $self->get_collect_dir();
  my $categorize_dir     = $self->get_categorize_dir();
  my $class_map          = $self->get_result_class_map();

  my $categorizer_params = $self->get_categorizer_params();
  $categorizer_params->{category_file} = '';

  # sanity check required arguments:
  ### require: defined $collection && length $collection
  ### require: -d $collect_dir
  ### require: -d $categorize_dir
  ### require: ref $categorizer_params eq "HASH"

  # make sure there are files for categorizing
  croak("No files for categorizing")
    unless check_for_files($categorize_dir);

  # create categorizer object
  my $categorizer_obj = AI::Categorizer->new(%{$categorizer_params});

  # categorize ('categorize')...
  my %class_hash = $self->_categorize_collection($categorizer_obj);

  # write results
  write_class_map($class_map => %class_hash);

  return;
}


sub do_export {
  my $self = shift;

  my $collection  = $self->get_collection();
  my $collect_dir = $self->get_collect_dir();

  # sanity check required arguments:
  ### require: defined $collection && length $collection
  ### require: -d $collect_dir

  # export ('train'/'test'/'categorize' => 'export')...

  return;
}


sub do_purge {
  my $self = shift;

  my $collection     = $self->get_collection();
  my $collect_dir    = $self->get_collect_dir();
  my $export_dir     = $self->get_export_dir();
  my $state_dir      = $self->get_state_dir();
  my $train_dir      = $self->get_train_dir();
  my $test_dir       = $self->get_test_dir();
  my $categorize_dir = $self->get_categorize_dir();

  # sanity check required arguments:
  ### require: defined $collection && length $collection
  ### require: -d $collect_dir

  foreach my $dir ($export_dir, $state_dir,
                   $train_dir, $test_dir, $categorize_dir) {
    my @items = glob("$dir/*");
    rmtree(\@items)
      if @items;
  }

  return;
}


sub do_remove {
  my $self = shift;

  my $collection  = $self->get_collection();
  my $collect_dir = $self->get_collect_dir();

  # sanity check required arguments:
  ### require: defined $collection && length $collection
  ### require: -d $collect_dir

  rmtree($collect_dir);

  return;
}


################################################################################
# INTERNAL UTILITIES                                                           #
################################################################################

sub _clone_conf : PRIVATE {
  my $self = shift;
  my ($original_conf, $clone_conf, $arg_ref) = @_;

  my $collection = $arg_ref->{collection};

  # create collection's config file (by
  # duplicating the global config file)
  # TODO: use some kind of skeleton/template?
  my @conf = read_file($original_conf);

  # make some substitutions on the first line
  $conf[0] =~ s{Global}{Collection-specific};
  $conf[0] =~ s{COBRA}{$& collection '$collection'};

  # write config file
  write_file($clone_conf, @conf);

  return;
}


# use this imitation of AI::Categorizer::evaluate_test_set to
# 1. restore the learner properly
# 2. overcome problem with AI::Categorizer::Learner::NaiveBayes
# (via _restore_learner())
sub _evaluate_test_set : PRIVATE {
  my $self = shift;
  my ($categorizer_obj) = @_;

  # restore state
  $categorizer_obj->_load_progress('03', 'learner');

  # restore learner!!
  my $learner = $self->_restore_learner($categorizer_obj);

  # create collection from $set
  my $collection = $categorizer_obj->create_delayed_object(
    'collection',
    path => $categorizer_obj->{test_set},
  );

  # categorize collection
  $categorizer_obj->{experiment} = $learner->categorize_collection(
    collection => $collection,
  );

  # save state
  $categorizer_obj->_save_progress('04', 'experiment');

  return $categorizer_obj->{experiment};
}


sub _categorize_collection : PRIVATE {
  my $self = shift;
  my ($categorizer_obj) = @_;

  # restore state
  $categorizer_obj->_load_progress('03', 'learner');

  # restore learner!!
  my $learner = $self->_restore_learner($categorizer_obj);

  # create collection from $set
  my $collection = $categorizer_obj->create_delayed_object(
    'collection',
    path => $self->get_categorize_dir(),
  );

  # categorize collection
  my %class_hash = ();
  while (my $document = $self->_next_document($collection)) {
    my $hypothesis = $learner->categorize($document);
    my $name       = $document->name();

    my @categories = $hypothesis->categories();

    $class_hash{$name} = \@categories;
  }

  return %class_hash;
}


sub _restore_learner : PRIVATE {
  my $self = shift;
  my ($categorizer_obj) = @_;

  my $specified_learner = $self->get_learner_class();

  my $learner = $categorizer_obj->learner();
  my $learner_class = ref $learner;

  carp("Ignoring specified learner '$specified_learner', since "
     . "a different one has been restored ('$learner_class')")
    unless $learner_class eq $specified_learner;

  # import restored learner
  $learner_class->use();

  # Can't locate object method "labels" via package
  # "Algorithm::NaiveBayes::Model::Frequency" at
  # /usr/lib/perl5/site_perl/5.8.1/AI/Categorizer/Learner/NaiveBayes.pm
  # line 46.
  #
  # inspired by: Ken Williams, Wed, Sep 1 2004 5:02 AM;
  # <perl.ai> "AI::Categorizer restore problem"
  'Algorithm::NaiveBayes::Model::Frequency'->use()
    if $learner_class eq 'AI::Categorizer::Learner::NaiveBayes';

  return $learner;
}


# get rid of those annoying warnings: of course there
# is no category information when categorizing!
sub _next_document : PRIVATE {
  my $self = shift;
  my ($collection_obj) = @_;

  my $file = $collection_obj->_read_file();
  return unless defined $file;

  return $collection_obj->call_method(
    'document',
    'read',
    path       => catfile($collection_obj->{cur_dir}, $file),
    name       => $file,
    categories => [],
  );
}


1;


__END__

=for readme stop

=head1 SYNOPSIS [STILL MISSING!]

    use COBRA;
    # Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.)

=head2 Actions

=over

=item create

Create initial collection. (See L<do_create()|do_create>)

=item import

Import data into collection. (See L<do_import()|do_import>)

=item train

Train learner on collection training data. (See L<do_train()|do_train>)

=item test

Categorize test data and print statistics. (See L<do_test()|do_test>)

=item categorize

Categorize imported data. (See L<do_categorize()|do_categorize>)

=item export

Export collection data/statistics to specified format. (See
L<do_export()|do_export>)

=item purge

Clean up the collection (don't delete it though). Use with caution! (See
L<do_purge()|do_purge>)

=item remove

Finally remove the collection (are you sure?). Use with extra caution!!
(See L<do_remove()|do_remove>)

=back

=head2 Learners [STILL MISSING!]

Description of machine learning algorithms.

=head2 Export formats [STILL MISSING!]

Description of export formats.


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

=item do_action

Performs the specified actions, calling the appropriate C<< do_<action>() >>
methods in turn. Takes an array reference of actions or a string of an
action as optional argument, otherwise uses the object's action attribute,
which itself can be an array ref or a string.

=item do_create

Creates the specified collection, taken from the object's collection attribute,
by creating a directory structure below the F<collect/> directory and by
cloning the global configuration file, thus providing the possibility to write
down collection-specific settings.

=item do_import

Imports the data into the collection by creating a new
L<COBRA::Collection|COBRA::Collection> object according to the collection type
attribute and subsequently calling this collection object's
L<do_import()|COBRA::Collection/item_do_import> method. Also allows to carry out
automatic indexing by creating a new L<COBRA::WrapIndexer|COBRA::WrapIndexer>
object if requested and passing that object to the collection constructor.

=item do_train

Trains a learner of the specified class on previously imported training data by
creating a new L<AI::Categorizer|AI::Categorizer> object and then calling the
appropriate methods on that object.

=item do_test

Tests previously imported test data against the previously trained learner by
creating a new L<AI::Categorizer|AI::Categorizer> object, which then restores
its state, and then calling the appropriate methods on that object.

=item do_categorize

Categorizes previously imported to-be-categorized data using the previously
trained learner by creating a new L<AI::Categorizer|AI::Categorizer> object,
which then restores its state, and then calling the utility method
L<_categorize_collection()|/item__categorize_collection> and finally the helper
subroutine L<COBRA::Util::write_class_map()|COBRA::Util/item_write_class_map>.

=item do_export

Exports the collection to various formats, including the original one, by
creating an appropriate L<COBRA::Export|COBRA::Export> object. B<NOT
IMPLEMENTED YET!>

=item do_purge

Cleans up the collection, i.e. deletes any files in the collection's
F<records/> directories as well as in its F<export/> and F<state/>
directories.

=item do_remove

Removes the collection completely by simply deleting its base directory. Make
sure you don't need it anymore, since all data will be lost!

=back

=head2 Internal utility subroutines

=over

=item _clone_conf

Clones the global configuration file and writes it to the collection's F<etc/>
directory. (Nothing exciting here at the moment ;-)

=item _evaluate_test_set

Imitates the
L<AI::Categorizer::evaluate_test_set()|AI::Categorizer/item_evaluate_test_set>
function, but differs in that it restores the learner I<properly> (see
L<_restore_learner()|_restore_learner>). Takes an
L<AI::Categorizer|AI::Categorizer> object as argument. Returns the
L<AI::Categorizer::Experiment|AI::Categorizer::Experiment> object created by
that object.

=item _categorize_collection

Does the actual L<AI::Categorizer|AI::Categorizer> method calls to categorize
the collection. Takes an L<AI::Categorizer|AI::Categorizer> object as argument.
Returns a hash of C<< document => list of assigned categories >> pairs.

=item _restore_learner

Restores the learner from the saved state, thereby ignoring any specified
learner. At the same time works around a bug in
L<AI::Categorizer::Learner::NaiveBayes|AI::Categorizer::Learner::NaiveBayes>.
Takes an L<AI::Categorizer|AI::Categorizer> object as argument. Returns the
restored L<AI::Categorizer::Learner|AI::Categorizer::Learner> object.

=item _next_document

Imitates the
L<AI::Categorizer::Collection::next()|AI::Categorizer::Collection/item_next>
function, but differs in that it suppresses those annoying warnings when there
is no category information for the document -- of course there is none when
categorizing!

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


=begin readme

=head1 INTRODUCTION

The Perl extension COBRA is basically a wrapper around AI::Categorizer aimed at
categorizing bibliographic records, with the intended purpose to ease its use
and allow for proper integration into a library's workflow. It originated from
the author's diploma thesis "Automatisches Klassifizieren bibliographischer
Beschreibungsdaten: Vorgehensweise und Ergebnisse" while studying librarianship
at the Institute of Information Science, University of Applied Sciences Cologne
(Germany).

COBRA has been developed and tested on Linux with Perl 5.8.1. However, it
I<should> run on other platforms just as well. If you encounter any problems,
platform-related or not, please don't hesitate to drop me a line.


=head1 INSTALLATION

=for readme include file=INSTALL type=text start=^Actually stop=^For

=end readme


=for readme stop

=head1 CONFIGURATION AND ENVIRONMENT [STILL MISSING!]

A full explanation of any configuration systems used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables and properties that can be set. These
descriptions must also include details of any configuration language used.


=for readme continue

=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules
are part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

Some of these may themselves require additional modules. Use the CPAN shell
(or ppm on Windows) to follow these dependencies automatically.

=over

=item *
Perl

Version greater than 5.8.1 (check with C<< perl -v >>).

=item *
AI::Categorizer

At least version 0.07. Available from CPAN.

=item *
Carp

[STANDARD MODULE]

=item *
Class::Std

At least version 0.0.8. Available from CPAN.

=item *
Config::General

Available from CPAN.

=item *
Cwd

[STANDARD MODULE]

=item *
Fatal

[STANDARD MODULE]

=item *
File::chdir

Available from CPAN.

=item *
File::Copy

[STANDARD MODULE]

=item *
File::Find

[STANDARD MODULE]

=item *
File::Path

[STANDARD MODULE]

=item *
File::Slurp

Available from CPAN.

=item *
File::Spec

[STANDARD MODULE]

=item *
FindBin

[STANDARD MODULE]

=item *
Getopt::Euclid

At least version 0.0.5. Available from CPAN.

=item *
IO::Prompt

Available from CPAN.

=item *
List::MoreUtils

Available from CPAN.

=item *
POSIX

[STANDARD MODULE]

=item *
Readonly

Available from CPAN.

=item *
Smart::Comments

Available from CPAN.

=item *
Test::More

[STANDARD MODULE]

=item *
version

Available from CPAN.

=back


=begin readme

=head1 RECENT CHANGES

=for readme include file=Changes type=text start=^\d+\.

=end readme


=for readme stop

=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indications of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.

There are no known bugs in this module. Please report problems to Jens Wille
C<< <jens.wille@gmail.com> >>. Patches are welcome.

=head2 Known issues

=over

=item *
Statistics::Contingency error: Can't take log of 0 at
/usr/lib/perl5/site_perl/5.8.1/Statistics/Contingency.pm line 183.

    modified: my $after_point = $figs - int log($number)/log(10);
    =>        my $after_point = $figs - ($number ? int log($number)/log(10) : 0);

(modified version in F<lib/>)

=item *
AI::Categorizer::KnowledgeSet error: Modification of a read-only value attempted
at /usr/lib/perl5/site_perl/5.8.1/AI/Categorizer/KnowledgeSet.pm line 415.

    modified: while (<$fh>) {
                next if /^#/;
                /^(.*)\t([\d.]+)$/ or croak "Malformed line: $_";
    =>        while (my $l = <$fh>) {
                next if $l =~ /^#/;
                $l =~ /^(.*)\t([\d.]+)$/ or croak "Malformed line: $l";

(modified version in F<lib/>)

=back


=head1 AUTHOR

Jens Wille C<< <jens.wille@gmail.com> >>


=for readme continue

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


=for readme stop

=head1 SEE ALSO/REFERENCES

Often there will be other modules and applications that are possible
alternatives to using your software. Or other documentation that would be of
use to the users of your software. Or a journal article or book that explains
the ideas on which the software is based. Listing those in a "See Also" section
allows people to understand your software better and to find the best solution
for their problems themselves, without asking you directly.

COBRA was named after the article "Classification of text, automatic" by
Fabrizio Sebastiani (In: Keith Brown (ed.), The Encyclopedia of Language and
Linguistics, Volume 14, 2nd Edition, Elsevier Science Publishers, Amsterdam,
NL, 2006, pp. 457-462.), available online at
L<http://www.math.unipd.it/~fabseb60/Publications/ELL06.pdf>.

L<COBRA::Collection|COBRA::Collection>, L<COBRA::Export|COBRA::Export>,
L<COBRA::WrapIndexer|COBRA::WrapIndexer>, L<COBRA::Util|COBRA::Util>


=begin readme

=head1 FURTHER READING

For more information see the documentation of the various packages in this
distribution.

=end readme


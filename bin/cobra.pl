#! /usr/bin/perl

=head1 NAME

cobra.pl - classification of bibliographic records, automatic

=head1 VERSION

This documentation refers to cobra.pl version 0.0.1

=cut


use strict;
use warnings;

# require at least perl version 5.8.1
use 5.008_001;

use version; our $VERSION = qv('0.0.1');

require UNIVERSAL::require;

use Carp;

use FindBin               qw();
use Readonly              qw(Readonly);
use File::Spec::Functions qw(catfile catdir updir);
use List::MoreUtils       qw(any);
use IO::Prompt            qw(prompt);

use lib "$FindBin::Bin/../lib";

# Getopt::Euclid must be imported *after* 'use lib ...'
use Getopt::Euclid qw(:minimal_keys);
use Config::General;

use COBRA;
use COBRA::Util qw(%DIR_PATH_FOR %DIR_NAME_FOR %FILE_NAME_FOR
                   $HELP_ON_LEARNERS $HELP_ON_FORMATS);

# this is only a fallback, providing a standard message
use COBRA::Collection qw($HELP_ON_FIELDS);

# import appropriate help message from collection type
BEGIN {
  (my $type = $ARGV{type}) =~ s{\A#DEFAULT#}{};
  $type =~ s{/}{::};

  "COBRA::Collection::$type"->use(qw($HELP_ON_FIELDS));
};


################################################################################
# constants                                                                    #
################################################################################

# our name
Readonly my $PROGNAME => $FindBin::Script;

# interactive help (KEEP IN SYNC WITH ACTUAL CLASSES!)
Readonly my %HELP_ON => (
  'use_fields' => "$PROGNAME: $HELP_ON_FIELDS",
  'learner'    => "$PROGNAME: $HELP_ON_LEARNERS",
  'format'     => "$PROGNAME: $HELP_ON_FORMATS",
);


################################################################################
# program configuration                                                        #
################################################################################

# also see pod section (KEEP IN SYNC!)

# shortcuts for option names:
#   available = cghjmnoqswxyz
#        used = abdefiklprtuv

# option constraints
my %is_valid = (
  # generic
  verbosity    => sub { $_[0] >= 0 && $_[0] <= 2},

  # import
  type         => sub { "COBRA::Collection::$_[0]"->require() },
  use_fields   => sub { $_[0] eq '#ALL#' || $_[0] =~ m{\A \w+(?:,\w+)* \z}xms },
  indexer      => sub { "COBRA::WrapIndexer::$_[0]"->require() },
  indexer_base => sub { -d $_[0] },
  indexer_args => sub { 1 },
  effect       => sub { $_[0] =~ m{\A (?:add|replace) \z}xms },
  repeat       => sub { defined $_[0] },
  ratio        => sub { $_[0] =~ m{\A (?:train|test|categorize|check_integrity|-[12]) \z}xms
                    || ($_[0] =~ m{\A \d+ \z}xms && ($_[0] >= 0 && $_[0] <= 100)) },
  keepold      => sub { defined $_[0] },
  #data_files   => sub { -r $_ || return foreach @{$_[0]}; 1 },
  data_files   => sub { 1 },

  # train
  learner      => sub { "AI::Categorizer::Learner::$_[0]"->require() },

  # export
  format       => sub { "COBRA::Export::$_[0]"->require() },
);

# action names:
# number => name
my %named_action = (
  1 => 'create',
  2 => 'import',
  3 => 'train',
  4 => 'test',
  5 => 'categorize',
  6 => 'export',
  7 => 'purge',
  8 => 'remove',
);

# inverse (easier to calculate with):
# name => num
my %action_num = ();
@action_num{values %named_action} = keys %named_action;

# inverse:
# num => num (for convenience)
@action_num{values %action_num} = values %action_num;

# action names:
# name => name (for convenience)
@named_action{values %named_action} = values %named_action;

# ratio values:
# keyword => value
my %ratio_value = (
  train           => 0,
  test            => 100,
  categorize      => -1,
  check_integrity => -2,
);

# make path absolute
$ARGV{config_file} = catfile($DIR_PATH_FOR{base}, $ARGV{config_file})
  if is_default($ARGV{config_file});


################################################################################
# command-line arguments                                                       #
################################################################################

# see pod section, thanks to Getopt::Euclid ;-)

# delete shorthand keys from %ARGV to enforce consistency in use
clean_argv();

# print help if requested
print_help();

# allow ranges of actions
my ($creating, $removing) = parse_action();

# check if collection exists (unless we're creating it, of course)
my $collect_dir = catdir($DIR_PATH_FOR{collect}, $ARGV{collection});
unless ($creating) {
  die "Collection '$ARGV{collection}' does not exist yet.\n"
    . "(Try: $PROGNAME create $ARGV{collection})\n"
    unless -d $collect_dir;
}

# make sure the user really wants to delete the collection
if ($removing) {
  prompt("Are you sure you want to remove the collection '$ARGV{collection}'? "
       . "ALL DATA WILL BE LOST! (y/n) [n]: ", -tty, -yes, -default => 'n')
    or exit;
}


################################################################################
# configuration file(s)                                                        #
################################################################################

# parse global and collection's configuration file (if appropriate)
# (the latter taking precedence over the former)
my @config_files = ($ARGV{config_file});

# add collection's config file only if not creating a new collection
push(@config_files => catfile($collect_dir,
                              $DIR_NAME_FOR{etc},
                              $FILE_NAME_FOR{collect_conf}))
  unless $creating;

# configuration hash
my %conf = parse_conf(@config_files);

# merge config file settings into %ARGV
merge_conf(%conf);


################################################################################
# post-processing                                                              #
################################################################################

# transform certain args to array ref
split_argv(
  use_fields   => q{,},
  indexer_args => q{::},
  data_files   => q{::},
);

# use ratio's value instead of keyword
$ARGV{ratio} = $ratio_value{$ARGV{ratio}}
  if exists $ratio_value{$ARGV{ratio}};

# if a range of actions was specified we might want to drop some
drop_action();

# see if there are enough fields specified for COBRA::Collection::Generic
if ($ARGV{type} eq 'Generic' && any { $_ eq 'import' } @{$ARGV{action}}) {
  my $n_fields = scalar @{$ARGV{use_fields}};

  die "When importing a collection of type Generic, you must specify at least"
    . " 3 fields, but there " . ($n_fields == 1 ? "was" : "were")
    . " only $n_fields in '" . join(q{,} => @{$ARGV{use_fields}}) . "'.\n"
    unless $n_fields > 2;
}


################################################################################
# action                                                                       #
################################################################################

my $cobra = COBRA->new(\%ARGV);

$cobra->do_action();


# that's it
exit 0;


################################################################################
# subroutines                                                                  #
################################################################################

sub clean_argv {
  foreach my $key (keys %ARGV) {
    delete $ARGV{$key}
      unless $key =~ m{\A (?:action|collection|config_file) \z}xms
          || exists $is_valid{$key};
  }

  return;
}

sub print_help {
  foreach my $key (keys %HELP_ON) {
    die "$HELP_ON{$key}\n"
      if $ARGV{$key} && $ARGV{$key} eq 'help';
  }

  return;
}

sub parse_action {
  (my $action_spec, $ARGV{action}) = ($ARGV{action}, []);

  foreach my $range_spec (split(q{,} => $action_spec)) {
    if ($range_spec =~ m{\A (.*?)-(.*?) \z}xms) {
      my ($start_action, $end_action) = map { $action_num{$_}
                                              || die "Value out of range: $_\n" }
                                        ($1, $2);

      die "Invalid range specification: $range_spec\n"
        . "(Try: $PROGNAME --help)\n"
        unless $start_action < $end_action;

      push(@{$ARGV{action}} => map { $named_action{$_} }
                               ($start_action .. $end_action));
    }
    else {
      # transform to array ref anyway and use action's name
      # instead of number (to allow for consistent handling)
      push(@{$ARGV{action}} => $named_action{$range_spec}
                            || die "Value out of range: $range_spec\n");
    }
  }

  # are we creating a new collection?
  my $are_creating = any { $_ eq  'create'} @{$ARGV{action}};

  # are we removing a collection?
  my $are_removing = any { $_ eq  'remove'} @{$ARGV{action}};

  return ($are_creating, $are_removing);
}

sub parse_conf {
  my @files = @_;
  my %conf_hash = ();

  foreach my $config_file (@files) {
    my %current_conf = ParseConfig(
      -ConfigFile        => $config_file,
      -AllowMultiOptions => 0,
      -LowerCaseNames    => 1,
    );

    # sanity checks
    foreach my $opt (sort keys %current_conf) {
      die "Unknown option in configuration file $config_file:\n"
        . "$opt\n"
        . "(Try: $PROGNAME --help)\n"
        unless exists $is_valid{$opt};

      die "Invalid option value in configuration file $config_file:\n"
        . "$opt = $current_conf{$opt}\n"
        . "(Try: $PROGNAME --help)\n"
        unless &{$is_valid{$opt}}($current_conf{$opt});
    }

    # merge with existing config
    @conf_hash{keys %current_conf} = values %current_conf;
  }

  return %conf_hash;
}

sub merge_conf {
  my %conf_hash = @_;

  foreach my $arg (sort keys %ARGV) {
    # remove leading '#DEFAULT#' (indicating default value)
    if (is_default(ref $ARGV{$arg} eq 'ARRAY' ? $ARGV{$arg}->[0] : $ARGV{$arg})) {
      # overwrite default value with config file setting
      $ARGV{$arg} = $conf_hash{$arg}
        if exists $conf_hash{$arg};
    }
  }

  return;
}

sub is_default {
  $_[0] =~ s{\A#DEFAULT#}{};
}

sub split_argv {
  my %args = @_;

  while (my ($arg, $string) = each %args) {
    $ARGV{$arg} = [ split($string => $ARGV{$arg}) ]
      unless ref $ARGV{$arg} eq 'ARRAY';
  }

  return;
}

sub drop_action {
  return unless scalar @{$ARGV{action}} > 1;

  # categorize vs. train vs. test vs. integrity check
  (my $ratio = $ARGV{ratio}) =~ s{\A#DEFAULT#}{};
  my $drop_action = $ratio == -1  ? 'train|test'        # categorize
                  : $ratio == 0   ? 'test|categorize'   # train only
                  : $ratio == 100 ? 'train|categorize'  # test only
                  :                 'categorize';       # train and test

  $ARGV{action} = [ grep { $_ !~ m{\A (?:$drop_action) \z}xms }
                    @{$ARGV{action}} ];

  return;
}


__END__

=head1 USAGE

    # Brief working invocation examples here showing the most common usages:

    # This section will be as far as many users ever read, so we
    # try to make it as educational and exemplary as possible ;-)

    # Create new collection 'testcol':
    cobra.pl create testcol
    cobra.pl 1      testcol  # Numbers are recognized as well
                             # (Extra whitespace just for
                             # improved readability)

    # Copy data to import directory...
    <whatever your copy command is>

    # ...and import collection data:
    cobra.pl import testcol
    cobra.pl 2      testcol  # ditto

    # Alternatively, specify data to import:
    # (By default, data are imported for training/testing; if
    # you want to categorize your data specify a ratio of '-1')
    cobra.pl import testcol -d data.txt

    # Train DecisionTree learner:
    cobra.pl train testcol -l DecisionTree
    cobra.pl 3     testcol -l DecisionTree  # ditto

    # Test learner on reserved data:
    cobra.pl test testcol
    cobra.pl 4    testcol  # ditto

    # Export collection as Midos2000 database [NOT IMPLEMENTED YET!]:
    cobra.pl export testcol -f Midos
    cobra.pl 6      testcol -f Midos  # ditto


    # Or in one go ;-) (Phase 5/categorize will be skipped; see above)
    cobra.pl create-export testcol -l DecisionTree -f Midos -d data.txt
    cobra.pl 1-6           testcol -l DecisionTree -f Midos -d data.txt

See section L</EXAMPLES> for more detailed demonstrations. [STILL MISSING!]


=head1 REQUIRED ARGUMENTS

A complete list of every argument that must appear on the command line
when the application is invoked, explaining what each of them does, any
restrictions on where each one may appear (i.e., flags that must appear
before or after filenames), and how the various arguments and options
may interact (i.e., mutual exclusions, required combinations, etc.).

=over

=item <action>

The action to perform (May be number or name):

1. L<create|COBRA/item_create>

2. L<import|COBRA/item_import>

3. L<train|COBRA/item_train>

4. L<test|COBRA/item_test>

5. L<categorize|COBRA/item_categorize>

6. L<export|COBRA/item_export> [NOT IMPLEMENTED YET!]

7. L<purge|COBRA/item_purge>

8. L<remove|COBRA/item_remove>

With a properly set up configuration file or command-line you may even specify
ranges of actions. Examples: C<< 'import-export' >>, or equivalently
C<< '2-6' >> (phase 5/categorize or phases 3/train and 4/test will be skipped;
see below); C<< 'purge,import' >>, or equivalently C<< '7,2' >>;
C<< 'create-train,export' >>, or equivalently C<< '1-3,6' >> -- note that
order matters!). Whether training (and testing) or categorizing will be
inferred from the C<< -ratio >> option.

=for Euclid:
    action.type : string, action =~ m{\A \w+(?:-\w+)?(?:,\w+(?:-\w+)?)* \z}xms

=item <collection>

The name of the collection to operate on.

=for Euclid:
    collection.type : string

=back

B<MIND THE ORDER: E<lt>actionE<gt> I<before> E<lt>collectionE<gt>!>


=head1 OPTIONS

A complete list of every available option with which the application
can be invoked, explaining what each does, and listing any restrictions,
or interactions.

=head2 Generic options

=over

=item -v[erbosity] [=] <verbosity>

Controls the verbosity of output (0=none, 2=lots). NOTE: At the moment the
level of verbosity is not accounted for, since there is no information to
display (however, there will be some information from
L<AI::Categorizer|AI::Categorizer> according to the specified verbosity level);
this will change in the future. [default: C<< '1' >> -- spits out some
explanatory information]

=for Euclid:
    verbosity.type    : integer, verbosity >= 0 && verbosity <= 2
    verbosity.default : '#DEFAULT#1'

=item -conf[ig[_file]] [=] <config_file>

Global configuration file to use. [default: C<< 'etc/cobra.conf' >>]

=for Euclid:
    config_file.type    : readable
    config_file.default : '#DEFAULT#etc/cobra.conf'

=back

=head2 Import options

=over

=item -t[ype] [=] <collection_type>

Type of collection to import. See L<COBRA::Collection|COBRA::Collection> for
available types (NOTE: specify, e.g., C<< 'Simple::SOLIS' >> as 
C<< 'Simple/SOLIS' >>). [default: C<< 'Simple/SOLIS' >>]

=for Euclid:
    collection_type.type    : string, eval { require "COBRA/Collection/collection_type.pm" }
    collection_type.default : '#DEFAULT#Simple/SOLIS'

=item -u[se[_fields]] [=] <fields>

Comma-separated list of fields to use from records. Type C<< 'help' >> for a
list of available fields. Use C<< '#ALL#' >> as the I<only> value to consider
all available fields. [default: C<< 'TI,CT,AB,ME' >>]

=for Euclid:
    fields.type    : string, fields eq '#ALL#' || fields =~ m{\A \w+(?:,\w+)* \z}xms
    fields.default : '#DEFAULT#TI,CT,AB,ME'

=item -i[ndexer] [=] <indexer>

This option tells us to perform automatic indexing on the records, using the
specified type of indexer. See L<COBRA::WrapIndexer|COBRA::WrapIndexer> for
available types. Also set the C<< -effect >> option to decide whether the
indexing results shall be added to the records or replace them. [default:
C<< '' >> -- i.e., don't index]

=for Euclid:
    indexer.type    : string, eval { require "COBRA/WrapIndexer/indexer.pm" }
    indexer.default : '#DEFAULT#'

=item -[indexer_]b[ase] [=] <base_directory>

Path to the indexer's base directory. [default: C<< '' >>]

=for Euclid:
    base_directory.type    : string, -d base_directory
    base_directory.default : '#DEFAULT#'

=item -[indexer_]a[rgs] [=] <argument>...

Additional arguments for the indexer. NOTE: If you specify this option on the
command-line, it must be the last one. [default: C<< '' >>]

=for Euclid:
    argument.type    : string
    argument.default : '#DEFAULT#'

=item -e[ffect] [=] <add_or_replace>

Specifies whether the indexing results shall be added to the records or replace
them. [default: C<< 'add' >>]

=for Euclid:
    add_or_replace.type    : string, add_or_replace =~ m{\A (?:add|replace) \z}xms
    add_or_replace.default : '#DEFAULT#add'

=item -[re]p[eat]

If specified, indexing results will be repeated according to their weight
(assuming integer values, representing the term frequency).

=item -r[atio] [=] <ratio>

Percentage of documents to use for testing (vs. training). Also implies the
intended purpose, i.e. whether training (and testing) or categorizing or doing a
class integrity check (testing the training data). Use the following keywords or
values:

C<< 'train' >>: Training only, equivalent to C<< '0' >>.

C<< 'test' >>: Testing only, equivalent to C<< '100' >>.

C<< 'categorize' >>: Categorizing, equivalent to C<< '-1' >>.

C<< 'check_integrity' >>: Class integrity check, equivalent to C<< '-2' >>. All documents
will be used for both training and testing.

[default: C<< '10' >> -- thus reserves 10% of the documents for testing and uses
the rest for training]

=for Euclid:
    ratio.type    : string, ratio =~ m{\A (?:train|test|categorize|check_integrity|-[12]) \z}xms || (ratio =~ m{\A \d+ \z}xms && (ratio >= 0 && ratio <= 100))
    ratio.default : '#DEFAULT#10'

=item -k[eepold]

Keeps already imported data, i.e. adds specified data onto existing ones. Use
with care.

=item -d[ata[_file[s]]] [=] <data_file>...

Data files to import; alternatively, copy your to-be-imported data into the
F<collect/E<lt>colnameE<gt>/import/> directory, which will be done anyway. All
files from the aforementioned directory will be used if this option is omitted.
NOTE: If you specify this option on the command-line, it must be the last one.
[default: C<< '' >> -- thus uses files from the import directory]

=for Euclid:
    data_file.type    : readable
    data_file.default : '#DEFAULT#'

=back

=head2 Training options

=over

=item -l[earner] [=] <learner>

Machine learning algorithm to use. Type C<< 'help' >> for a list of available
algorithms or see L<COBRA/Learners> for more information, including
learner-specific parameters and order of magnitude for their processing time.
[default: C<< 'NaiveBayes' >>]

=for Euclid:
    learner.type    : string, learner eq 'help' || eval { require "AI/Categorizer/Learner/learner.pm" }
    learner.default : '#DEFAULT#NaiveBayes'

=back

=head2 Export options

=over

=item -f[ormat] [=] <export_format>

Format to export collection to. Type C<< 'help' >> for a list of available
formats or see L<COBRA::Export|COBRA::Export> for more information. [default:
C<< 'Midos' >>]

=for Euclid:
    export_format.type    : string, export_format eq 'help' || eval { require "COBRA/Export/export_format.pm" }
    export_format.default : '#DEFAULT#Midos'

=back

NOTE: Unfortunately, you can't specify both C<< -indexer_args >> and
C<< -data_files >> on the command-line at the same time (due to restrictions in
Getopt::Euclid) -- hopefully, this will be fixed in the future, either by
Getopt::Euclid or by this module. For now, either use the configuration file or
the alternative import method through the import directory. Sorry for any
inconvenience ;-)


=head1 DESCRIPTION [STILL MISSING!]

A full description of the application and its features.
May include numerous subsections (i.e., =head2, =head3, etc.)


=head1 SUBROUTINES

The following subroutines are simply used to segment the code.

=over

=item clean_argv

Cleans up the global C<< %ARGV >> hash to enforce consistency in use
throughout the code -- i.e., deletes any shortnames introduced by
L<Getopt::Euclid|Getopt::Euclid>, uses only the names specified in the
C<< %is_valid >> hash instead (apart from certain exceptions). Updates
the global C<< %ARGV >> hash.

=item print_help

Prints a help message for certain arguments if requested (usually by specifying
C<< 'help' >> as argument value).

=item parse_action

Parses any range specifications in the action string. Returns boolean values for
whether we are creating a new collection and/or removing an existing one.
Updates the global C<< %ARGV >> hash.

=item parse_conf

Reads and parses the given configuration files. Takes a list of configuration
files as argument. Returns a hash containing the configuration settings.

=item merge_conf

Merges the config file settings with the command-line arguments, the latter
taking precedence over the former. Takes the config hash as argument. Updates
the global C<< %ARGV >> hash.

=item split_argv

Splits the given arguments at specified strings to array references. Takes a
hash of C<< argument => string >> pairs as argument. Updates the global
C<< %ARGV >> hash.

=item drop_action

Drops certain actions, according to the specified ratio. Updates the global
C<< %ARGV >> hash.

=back


=head1 EXAMPLES [STILL MISSING!]

Many people learn better by example than by explanation, and most learn better
by a combination of the two. Providing a I</demo> directory stocked with well-
commented examples is an excellent idea, but users might not have access to the
original distribution, and demos are unlikely to have been installed for them.
Adding a few illustrative examples in the documentation itself can greatly
increase the "learnability" of your code.


=head1 DIAGNOSTICS [STILL MISSING!]

A list of every error and warning message that the application can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies. If the
application generates exit status codes (e.g., under UNIX), then list the exit
status associated with each error.


=head1 CONFIGURATION AND ENVIRONMENT [STILL MISSING!]

A full explanation of any configuration systems used by the application,
including the names and locations of any configuration files, and the
meaning of any environment variables and properties that can be set. These
descriptions must also include details of any configuration language used.


=head1 DEPENDENCIES [STILL MISSING!]

A list of all the other programs or modules that this application relies upon,
including any restrictions on versions, and an indication of whether these
required programs and modules are part of the standard Perl distribution,
part of the application's distribution, or must be installed separately.


=head1 BUGS AND LIMITATIONS

A list of known problems with the application, together with some indications
of whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the application does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.

There are no known bugs in this application. Please report problems to Jens
Wille C<< <jens.wille@gmail.com> >>. Patches are welcome.


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

L<COBRA|COBRA>, L<COBRA::Collection|COBRA::Collection>,
L<COBRA::Util|COBRA::Util>


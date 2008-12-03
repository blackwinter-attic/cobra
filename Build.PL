use strict;
use warnings;

use Module::Build;

# I WANT AN 'ALL' TARGET! (and some others, too ;-)
my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code  => <<'HERE_CODE' );

sub ACTION_html {
  my $self = shift;

  $self->SUPER::ACTION_html();

  # clean up temporary files
  unlink(glob('pod2htm*.tmp'));
}

sub ACTION_makedoc {
    my $self = shift;

    qx{./Build manpages};
    qx{./Build html};

    use File::Slurp    qw(read_file write_file);
    use File::Path     qw(rmtree mkpath);
    use File::Basename qw(basename);
    use File::Copy     qw(copy);
    use File::Find;

    rmtree("doc");

    my %index = ();
    my $base  = 'doc/html/';
    my $html  = <<'HERE_HTML';
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>Documentation for perl extension COBRA</title>
</head>

<body style="background-color: white">
<table border="0" width="100%" cellspacing="0" cellpadding="3">
<tr><td class="block" style="background-color: #cccccc" valign="middle">
<big><strong><span class="block">&nbsp;Documentation for perl extension COBRA</span></strong></big>
</td></tr>
</table>

<table border="0" width="100%" cellspacing="0" cellpadding="3" style="padding: 40px;">
HERE_HTML

    find({ wanted => sub {
      if (/(?:\.pl\.1|\.3pm|\.html)$/) {
        my $name = basename $_;
        my $full = $File::Find::name;
        my $tdir = $File::Find::dir;

        return if $tdir =~ /script/;

        $tdir =~ s:^blib/bindoc:doc/man/bin:;
        $tdir =~ s:^blib/binhtml:doc/html:;
        $tdir =~ s:^blib/libdoc:doc/man/site/lib:;
        $tdir =~ s:^blib/libhtml:doc/html:;

        mkpath $tdir;

        if (/\.html$/ && /cobra/i) {
          my $pod = read_file($full) or die "$!";
          if ($pod =~ m:<span class="block">&nbsp;(.*?)\s+-\s+(.*?)</span>:) {
            my ($nm, $ab) = ($1, $2);
            (my $rdir = $tdir) =~ s:$base::;
            $index{$nm} = <<"HERE_HTML";
<tr>
  <td><a href="$rdir/$name">$nm</a></td>
  <td>$ab</td>
</tr>
HERE_HTML
          }

          $pod =~ s:<li><a href="#(introduction|installation)">\1</a></li>::gi;
          $pod =~ s:<li><a href="#recent_changes">RECENT CHANGES</a></li>::g;
          $pod =~ s:<li><a href="#further_reading">FURTHER READING</a></li>::g;
          $pod =~ s%(?<!bin)/([[:lower:]_]+)\.html%.html#$1%g;
          write_file($full => $pod) or die "$!";
        }

        copy($full => "$tdir/$name");
      }
    }, no_chdir => 1 } => 'blib');

    $html .= join('' => map { $index{$_} } sort keys %index);

    $html .= <<'HERE_HTML';
</table>
<table border="0" width="100%" cellspacing="0" cellpadding="3">
<tr><td class="block" style="background-color: #cccccc" valign="middle">
<big><strong><span class="block">&nbsp;Documentation for perl extension COBRA</span></strong></big>
</td></tr>
</table>

</body>

</html>
HERE_HTML

    write_file('doc/html/index.html' => $html) or die "$!";
}

sub ACTION_most {
    my $self = shift;

    $self->ACTION_build();

    $self->ACTION_makedoc();

    $self->ACTION_distmeta();
    print "Deleting MANIFEST\n";
    unlink('MANIFEST');
    $self->ACTION_manifest();

    $self->ACTION_dist();
}

sub ACTION_all {
    my $self = shift;

    $self->ACTION_distclean();

    qx{perl Build.PL};

    $self->ACTION_most();

    eval { $self->ACTION_test() };
    eval { $self->ACTION_fakeinstall() };
}
HERE_CODE

my $builder = $class->new(
    module_name           => 'COBRA',
    license               => 'gpl',
    dist_author           => 'Jens Wille <jens.wille@gmail.com>',
    dist_version_from     => 'lib/COBRA.pm',
    create_makefile_pl    => 'passthrough',  # creates a Makefile.PL that simply
                                             # passes through to Build.PL
    create_readme         => 1,              # creates a README file using Pod::Readme
    requires => {
        'perl'            => '5.8.1',
        'AI::Categorizer' => '0.07',
        'Carp'            => 0,
        'Class::Std'      => '0.000008',
        'Config::General' => 0,
        'Cwd'             => 0,
        'Fatal'           => 0,
        'File::chdir'     => 0,
        'File::Copy'      => 0,
        'File::Find'      => 0,
        'File::Path'      => 0,
        'File::Slurp'     => 0,
        'File::Spec'      => 0,
        'FindBin'         => 0,
        'Getopt::Euclid'  => '0.000005',
        'IO::Prompt'      => 0,
        'List::MoreUtils' => 0,
        'POSIX'           => 0,
        'Readonly'        => 0,
        'Smart::Comments' => 0,
        'Test::More'      => 0,
        'version'         => 0,
    },
    add_to_cleanup      => [ 'COBRA-*' ],
);

$builder->create_build_script();


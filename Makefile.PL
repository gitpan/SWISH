use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'SWISH',
    'VERSION_FROM'	=> 'SWISH.pm', # finds $VERSION
    'dist' => { COMPRESS=>"gzip",
                SUFFIX=>"gz",
                PREOP=> 'pod2text -80 < SWISH.pm > README',
              },

);

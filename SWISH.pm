package SWISH;
use strict;

use vars (qw/$VERSION $errstr/);

$VERSION = 0.03;


sub connect {
    my $class = shift;
    my $driver = shift;

    unless ( $driver ) {
        $errstr = "Must supply Access Method";
        return;
    }

    eval { require "SWISH/$driver.pm"; };
    if ( $@ ) {
        $errstr = $@;
        return;
    }


    $driver = "SWISH::$driver";

    

    my $drh;

    eval { $drh = $driver->new( @_ ); };

    return $drh if ref $drh;

    $errstr = $driver->errstr || $@ || "Unknown error calling $driver->new()";
    return;
}

package SWISH::Results;
use strict;
use vars ( '$AUTOLOAD' );

{
    my %available = (
        score       => undef,
        file        => undef,
        title       => undef,
        size        => undef,
        position    => undef,
        total_hits  => undef,
       #date        => undef,
        properties  => undef,
    );
    sub _readable{ exists $available{$_[1]} };
    #sub _writable{ $available{$_[1]} };
}


sub new {
    my ( $class, $attr ) = @_;
    my %attr = %$attr if $attr;
    return bless \%attr, $class;
}

sub as_string {
    my $self = shift;
    my $delimiter = shift || ' ';

    my $blank = $delimiter =~ /^\s+$/;

    my @properties = @{$self->{properties}} if $self->{properties};

    return join $delimiter, map { $blank && /\s/ ? qq["$_"] : $_ }
                            map( { $self->{$_} || '???' } qw/score file title size/),
                            @properties,
                            "($self->{position}/$self->{total_hits})" ;
}

sub DESTROY {
}

sub AUTOLOAD {
    my $self = shift;
    no strict "refs";

    # only access methods at this point

    if ( $AUTOLOAD =~ /.*::(\w+)/ && $self->_readable( $1 ) ) {
        my $attribute = $1;
        *{$AUTOLOAD} = sub {
            return unless $_[0]->{$attribute};

            return wantarray && ref( $_[0]->{$attribute} ) eq 'ARRAY'
                   ? @{$_[0]->{$attribute}}
                   : $_[0]->{$attribute};
        };

        return $self->{$attribute} || undef;
    }

    # catch error?
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

SWISH - Perl interface to the SWISH-E search engine.

=head1 SYNOPSIS

    use SWISH;

    $sh = SWISH->connect('Fork',
        prog     => '/usr/local/bin/swish-e',
        indexes  => 'index.swish-e',
        results  => sub { print $_[1]->as_string,"\n" },
    );

    die $SWISH::errstr unless $sh;    

    $hits = $sh->query('metaname=(foo or bar)');

    print $hits ? "Returned $hits documents\n" : 'failed query:' . $sh->errstr . "\n";

    # Variations

    $sh = SWISH->connect('Fork',
        prog     => '/usr/local/bin/swish-e',
        indexes  => \@indexes,
        results  => \&results,      # callback
        headers  => \&headers,
        maxhits  => 200,
        timeout  => 20,
        -e       => undef,      # add just a switch
    );

    $sh = SWISH->connect('Library', %parameters );
    $sh = SWISH->connect('Library', \%parameters );

    $sh = SWISH->connect('Server',
        port     => $port_number,
        host     => $host_name,
        %parameters,
    );

    $hits = $sh->query( $query_string );
    $hits = $sh->query( query => $query_string );

    $hits = $sh->query(
        query       => $query_string,
        results     => \&results,
        headers     => \&headers,
        properties  => [qw/title subject/],
        sortorder   => 'subject',
        startnum    => 100,
        maxhits     => 1000,
    );

    $error_msg = $sh->error unless $hits;


    # Unusual, but might want to use in your headers() callback.
    $sh->abort_query;

    @raw_results = $sh->raw_query( \%query_settings );


    $r = $sh->index( '/path/to/config' );
    $r = $sh->index( \%indexing_settings );

    # If all config settings were stored in the index header
    $r = $sh->reindex;


    $header_array_ref = $sh->indexheaders;


    # returns words as swish sees them for indexing
    $search_words = $sh->swish_words( \$doc );

    $stemmed = $sh->stem_word( $word );


    $sh->disconnect;
    # or an alias: 
    $sh->close;

                   

=head1 DESCRIPTION

NOTE: This is alpha code and is not to be used in a production environment.  Testing and feedback
on using this module is B<gratefully appreciated>.

This module provides a standard interface to the SWISH-E search engine.
With this interface your program can use SWISH-E in the standard forking/exec
method, or with the SWISH-E C library routines, and, if ever developed, the SWISH-E
server with only a small change.

The idea is that you can change the way your program accesses a SWISH-E index without having
to change your code.  Much, that is.

=head1 METHODS

Most methods will take either a hash, or a reference to a hash as a named parameter list.
Parameters set in the connect() method will be defaults, with parameters in other methods
overriding the defaults.

=over 4

=item B<connect>

C<$sh = SWISH-E<gt>connect( $access_method, \%params );>

The connect method uses the C<$access_method> to initiate a connection with SWISH-E.
What that means depends on the access method.
The return value is an object used to access methods below, or undefined if failed.
Errors may be retrieved with the package variable $SWISH::errstr.

The SWISH module will load the driver for the type of access specified in the access method, if
available, by loading the C<SWISH::$access_method module>.

Parameters are described below in B<PARAMETERS>, but must include the path to the
swish binary program if using the File access_method and index file(s).  (index files?)

=item B<query>

C<$hits = $sh-E<gt>query( query =E<gt> $query, \%parameters );>

The query method executes a query and returns the number of hits found.  C<$hits> is undefined
if there is an error.  The last error may be retrieved with C<$sh-E<gt>error>.

query can be passed a single scalar as the search string, a hash, or a reference to a hash.
Parameters passed override the defaults specified in the connect method.

    Examples:
        $hits = $sh->query( 'foo or bar' );
        $hits = $sh->query( 'subject=(foo or bar)' );
        $hits = $sh->query( query => 'foo or bar' );
        $hits = $sh->query( %parameters );
        $hits = $sh->query( \%parameters );

It is recommended to use a callback function to receive the search results.  See C<headers> below.
        


=item B<raw_query>

A raw_query returns a list containing every output line from the query, including index
header lines.  This can generate a large list, so using C<query> with a callback function
is recommended.

    Example:
        @results = $sh->raw_query('foo');
        

=item B<indexheaders>

The indexheaders method accesses the headers from the last C<query> call.  Since SWISH
may return more than one set of headers (e.g. when searching multiple indexes), this method
returns a reference to an array of hashes.

    Example:
        foreach my $header_set ( @{$sh->indexheaders} ) {
            print "\nHeaders:\n";
            print "$_:$header_set->{$_}\n" for sort keys %$header_set;
        }


=item B<abort_query>

Calling $sh->abort_query within your callback handlers (C<results> and C<headers>) will terminate
the current request.  You could also probably just die() and get the same results.

=item B<index>

** To Be Implemented **

The index method creates a swish index file.  You may pass C<index> either
a path to a SWISH-E configuration file, or reference to a hash with the index parameters
stored in name =E<gt> value pairs.

The parameters in the hash will be written to a temporary file
before indexing in with the Fork method.  If passing a reference to a hash, you may include a key B<tempfile>
that specifies the location of the temporary file.  Otherwise, /tmp will be assumed.

If a parameter is not passed it will look in the object for an attribute named B<indexparam>

=item B<reindex>

** To Be Implemented? **

This is a wish list method.  The idea is all the indexing parameters would be stored in the
header on an index so to all one would need to do to reindex is call swish with the name of
the index file.

=item B<stem_word>

** To Be Implemented **

stem_word returns the stem of the word passed.  This may be left to a separate module, but
could be require()d on the fly.  The swish stemming routine is needed to highlight search terms
when the index contains stemmed words.

=item B<swish_words>

** To Be Implemented? **

swish_words takes a scalar or a reference to a scalar and tokenizes the words as swish would
do during indexing. The return value is a reference to an array where each element is a token.
Each token is also a reference to an array where the first element is the word, and the second
element is a flag indicating if this is an indexable word.  Confused?

This requires HTML::Parser (HTML::TokeParser?) to be installed.

The point of this is for enable phrase highlighting.  You can read your source and,
if lucky, highlight phrase found in searches.

    Example:
        $words = $sh->swish_words( 'This is a phrase of words' );
                                      0 1 2345   6  7 89  10

        $words->[0][0] is 'This'
        $words->[0][1] is 1 indicating that swish would have this indexed
        $words->[0][2] is 0 this is swish word zero
        $words->[0][3] is the stemmed version of 'This', if using stemming.

        $words->[1][0] is ' '
        $words->[1][1] is 0 indicating that swish would not index
        $words->[1][2] is undef (not a word)
    
        $words->[2][0] is 'is'
        $words->[2][1] is 0 indicating that swish would not index (stop word)
        $words->[2][2] is undef (not a word)

        $words->[6][0] is 'phrase'
        $words->[6][1] is 1 indicating that it is a swish word
        $words->[6][2] is 2 this is the second swish word
                          ('is' and 'a' are stop words)

=back

=head1 ACCESS METHODS

Two access methods are available:  `Fork' and `Library'.

The B<Fork> method requires a C<prog> parameter passed to the C<connect> class method.
This parameter specifies the location of the swish-e executable program

The B<Library> method does not require any special parameters, but does require that the
SWISH::Library module is installed and can be found within @INC.

The B<Server> method is a proposed method to access a SWISH-E server.  Required
parameters may include C<port>, C<host>, C<user>, and C<password> to gain access
to the SWISH-E server.

=head1 PARAMETERS

Parameters can be specified when starting a swish connection.  The parameters are stored
as defaults within the object and will be used on each query, unless other overriding
parameters are specified in an individual method call.

Most parameters have been given longer names (below).  But, any valid parameter may be specified
by using the standard dash followed by a letter.  That is:

    maxhits => 100,

is the same as

    -m      => 100,

And to add just a switch without a parameter:
    -e      => undef,

Keep in mind that not all switches may work with all access methods.  The swish
binary may have different options than the swish library.
    


=over 4

=item B<prog>

prog defines the path to the swish executable.  This is only used in the B<Fork> access method.

    Example:
        $parameters{ path } = '/usr/local/bin/swish-e';

=item B<indexes>

indexes defines the index files used in the next query or raw_query operation.

    Examples:
        $parameters{ indexes } = '/path/to/index.swish-e';
        $parameters{ indexes } = ['/path/to/index.swish-e', '/another/index'];

=item B<query>

query defines the search words (-w switch for SWISH-E)

    Example:
        $parameters{ query } = 'keywords=(apples or oranges) and subject=(trees)';

=item B<tags> or B<context>

tags (or the alias context) is a string that defines where to look in a HTML document (-t switch)

=item B<properties>

properties defines which properties to return in the search results.
Properties must be defined during indexing.
You must pass an array reference if using more than one property.

    Examples:
        $sh = query( query => 'foo', properties => 'title' );
        $sh = query( query => 'foo', properties => [qw/title subject/] );
       

=item B<maxhits>

Define the maximum number of results to return.  Currently, If you specify more than one index
file maxhits is B<per index file>.

=item B<startnum>

Defines the starting number in the results.  This is used for generating paged results.
Should there be pagesize and pagenum parameters?

=item B<sortorder>

Sorts the results based on properties listed.  Properties must be defined during indexing.
You may specify ascending or descending sorts in future version of swish.

    Example:
        $parameters{ sortorder } = 'subject';

        # under developement
        $parameters{ sortorder } = [qw/subject category/];
        $parameters{ sortorder } = [qw/subject asc category desc/];

=item B<start_date>

** Not implemented **

Specify a starting dates in unix seconds.  Only results after this date will be returned.

=item B<end_date>

** Not implemented **

Ending date in unix seconds.


=item B<results>

results defines a callback subroutine.  This routine is called for each result returned
by a query.

    Example:
        $parameters{ results } = \&display_results
        $parameters{ results } = sub { print $_[1]->file, "\n" };

Two paramaters are passed: the current search object (created by C<connect>) and
an object blessed into the SWISH::Results class.


    Example:

        sub display_results {
            my ($sh, $hit) = @_;

            # SWISH::Results attributes
            my @show = qw/score file title size position total_hits/;
            
            my %results = map { ($_, $hit->$_) } @show;
            my @properties = @{$hit->{properties}} if $hit->{properties};
            print join( ':', @results{ @show }, @properties ), "\n";
        }

The callback routines (C<results> and C<headers>) are called while inside an eval block.
If you die within your handlers the program will NOT exit, but any message you pass to die()
will be available in $sh->errstr.  In general, do as little as possible with your callback
routines.

The SWISH::Results class is currently within the SWISH module.  This may change.        
    

=item B<headers>

headers defines a callback subroutine.  This routine is called for each result returned
by a query.

    Example:
        $parameters{ headers } = \&headers;

Your subroutine is called with three parameters: the current object, and the header and value.

    sub headers {
        my ( $sh, $header, $value ) = @_;
        print "$header: $value\n";
    }

In general, it will be better to call the C<headers> method.

=item B<timeout>

timeout is the number of seconds to wait before aborting a query request.
Don't spend too much time in your results callback routine if you are using a timeout.
Timeout is emplemented as a $SIG{ALRM} handler and funny things happen with perl's signal
handlers.



=back

=head1 TO DO

=over 4

How to detect a new index if library holds the file open?

Is it ok to change index files on the same object?
Does the library keep the index file open between requests?

Interface for Windows platform?

=back

=head1 SEE ALSO

http://sunsite.berkeley.edu/SWISH-E/

=head1 AUTHOR

Bill Moseley E<lt>moseley@hank.orgE<gt>


=cut

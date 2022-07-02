#!perl -T

use Test::More tests => 10;

BEGIN {
	use_ok( 'WebFetch' );
	use_ok( 'WebFetch::Data::Store' );
	use_ok( 'WebFetch::Data::Record' );
	use_ok( 'WebFetch::Input::PerlStruct' );
	use_ok( 'WebFetch::Input::SiteNews' );
	use_ok( 'WebFetch::Output::Dump' );
	use_ok( 'WebFetch::Output::TWiki' );

    eval "use XML::Atom::Client";
    SKIP: {
        skip "Optional module 'XML::Atom::Client' not installed",1 if($@);
        use_ok( 'WebFetch::Input::Atom' );
    };

    eval "use XML::RSS";
    SKIP: {
        skip "Optional module 'XML::RSS' not installed",1 if($@);
	    use_ok( 'WebFetch::Input::RSS' );
    };

    eval "use Template";
    SKIP: {
        skip "Optional module 'Template' not installed",1 if($@);
        use_ok( 'WebFetch::Output::TT' );
    };
}

diag( "Testing WebFetch $WebFetch::VERSION, Perl $], $^X" );

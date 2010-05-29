#!/usr/bin/perl
# -*- cperl-indent-level: 8; -*-
use warnings;
use strict;
use File::Temp qw{tempdir};

BEGIN {
	unless (eval { require Locale::Po4a::Chooser }) {
		eval q{
			use Test::More skip_all => "Locale::Po4a::Chooser::new is not available"
		}
	}
	unless (eval { require Locale::Po4a::Po }) {
		eval q{
			use Test::More skip_all => "Locale::Po4a::Po::new is not available"
		}
	}
}

use Test::More tests => 82;

BEGIN { use_ok("IkiWiki"); }

my $msgprefix;

my $dir = tempdir("ikiwiki-test-po.XXXXXXXXXX",
		  DIR => File::Spec->tmpdir,
		  CLEANUP => 1);

### Init
%config=IkiWiki::defaultconfig();
$config{srcdir} = "$dir/src";
$config{destdir} = "$dir/dst";
$config{discussion} = 0;
$config{po_master_language} = { code => 'en',
				name => 'English'
			      };
$config{po_slave_languages} = {
			       es => 'Castellano',
			       fr => "Français"
			      };
$config{po_translatable_pages}='index or test1 or test2 or translatable or test4.fr';
$config{po_link_to}='negotiated';
IkiWiki::loadplugins();
IkiWiki::checkconfig();
ok(IkiWiki::loadplugin('po'), "po plugin loaded");

### seed %pagesources and %pagecase
$pagesources{'index'}='index.mdwn';
$pagesources{'index.fr'}='index.fr.po';
$pagesources{'index.es'}='index.es.po';
$pagesources{'test1'}='test1.mdwn';
$pagesources{'test1.fr'}='test1.fr.po';
$pagesources{'test2'}='test2.mdwn';
$pagesources{'test2.es'}='test2.es.po';
$pagesources{'test2.fr'}='test2.fr.po';
$pagesources{'test3'}='test3.mdwn';
$pagesources{'test3.es'}='test3.es.mdwn';
$pagesources{'test4.fr'}='test4.fr.mdwn';
$pagesources{'test4.en'}='test4.en.po';
$pagesources{'test4.es'}='test4.es.po';
$pagesources{'translatable'}='translatable.mdwn';
$pagesources{'translatable.fr'}='translatable.fr.po';
$pagesources{'translatable.es'}='translatable.es.po';
$pagesources{'nontranslatable'}='nontranslatable.mdwn';
foreach my $page (keys %pagesources) {
    $IkiWiki::pagecase{lc $page}=$page;
}

### populate srcdir
writefile('index.mdwn', $config{srcdir}, '[[translatable]] [[nontranslatable]]');
writefile('test1.mdwn', $config{srcdir}, 'test1 content');
writefile('test2.mdwn', $config{srcdir}, 'test2 content');
writefile('test3.mdwn', $config{srcdir}, 'test3 content');
writefile('test4.fr.mdwn', $config{srcdir}, 'test4 (en français)');
writefile('translatable.mdwn', $config{srcdir}, '[[nontranslatable]]');
writefile('nontranslatable.mdwn', $config{srcdir}, '[[/]] [[translatable]]');

### istranslatable/istranslation
# we run these tests twice because memoization attempts made them
# succeed once every two tries...
foreach (1, 2) {
ok(IkiWiki::Plugin::po::istranslatable('index'), "index is translatable");
ok(IkiWiki::Plugin::po::istranslatable('/index'), "/index is translatable");
ok(! IkiWiki::Plugin::po::istranslatable('index.fr'), "index.fr is not translatable");
ok(! IkiWiki::Plugin::po::istranslatable('index.es'), "index.es is not translatable");
ok(! IkiWiki::Plugin::po::istranslatable('/index.fr'), "/index.fr is not translatable");
ok(! IkiWiki::Plugin::po::istranslation('index'), "index is not a translation");
ok(IkiWiki::Plugin::po::istranslation('index.fr'), "index.fr is a translation");
ok(IkiWiki::Plugin::po::istranslation('index.es'), "index.es is a translation");
ok(IkiWiki::Plugin::po::istranslation('/index.fr'), "/index.fr is a translation");
ok(IkiWiki::Plugin::po::istranslatable('test2'), "test2 is translatable");
ok(! IkiWiki::Plugin::po::istranslation('test2'), "test2 is not a translation");
ok(! IkiWiki::Plugin::po::istranslatable('test3'), "test3 is not translatable");
ok(! IkiWiki::Plugin::po::istranslation('test3'), "test3 is not a translation");
ok(IkiWiki::Plugin::po::istranslatable('test4.fr'), "test4.fr is translatable");
ok(! IkiWiki::Plugin::po::istranslation('test4.fr'), "test4.fr is not a translation");
}

### links
require IkiWiki::Render;

sub refresh_n_scan(@) {
	my @masterfiles_rel=@_;
	foreach my $masterfile_rel (@masterfiles_rel) {
		my $masterfile=srcfile($masterfile_rel);
		IkiWiki::scan($masterfile_rel);
		next unless IkiWiki::Plugin::po::istranslatable(pagename($masterfile_rel));
		my @pofiles=IkiWiki::Plugin::po::pofiles($masterfile);
		IkiWiki::Plugin::po::refreshpot($masterfile);
		IkiWiki::Plugin::po::refreshpofiles($masterfile, @pofiles);
		map IkiWiki::scan(IkiWiki::abs2rel($_, $config{srcdir})), @pofiles;
	}
}

$config{po_link_to}='negotiated';
$msgprefix="links (po_link_to=negotiated)";
refresh_n_scan('index.mdwn', 'translatable.mdwn', 'nontranslatable.mdwn');
is_deeply(\@{$links{'index'}}, ['translatable', 'nontranslatable'], "$msgprefix index");
is_deeply(\@{$links{'index.es'}}, ['translatable.es', 'nontranslatable'], "$msgprefix index.es");
is_deeply(\@{$links{'index.fr'}}, ['translatable.fr', 'nontranslatable'], "$msgprefix index.fr");
is_deeply(\@{$links{'translatable'}}, ['nontranslatable'], "$msgprefix translatable");
is_deeply(\@{$links{'translatable.es'}}, ['nontranslatable'], "$msgprefix translatable.es");
is_deeply(\@{$links{'translatable.fr'}}, ['nontranslatable'], "$msgprefix translatable.fr");
is_deeply(\@{$links{'nontranslatable'}}, ['/', 'translatable', 'translatable.fr', 'translatable.es'], "$msgprefix nontranslatable");

$config{po_link_to}='current';
$msgprefix="links (po_link_to=current)";
refresh_n_scan('index.mdwn', 'translatable.mdwn', 'nontranslatable.mdwn');
is_deeply(\@{$links{'index'}}, ['translatable', 'nontranslatable'], "$msgprefix index");
is_deeply(\@{$links{'index.es'}}, [ map bestlink('index.es', $_), ('translatable.es', 'nontranslatable')], "$msgprefix index.es");
is_deeply(\@{$links{'index.fr'}}, [ map bestlink('index.fr', $_), ('translatable.fr', 'nontranslatable')], "$msgprefix index.fr");
is_deeply(\@{$links{'translatable'}}, [bestlink('translatable', 'nontranslatable')], "$msgprefix translatable");
is_deeply(\@{$links{'translatable.es'}}, ['nontranslatable'], "$msgprefix translatable.es");
is_deeply(\@{$links{'translatable.fr'}}, ['nontranslatable'], "$msgprefix translatable.fr");
is_deeply(\@{$links{'nontranslatable'}}, ['/', 'translatable', 'translatable.fr', 'translatable.es'], "$msgprefix nontranslatable");

### targetpage
$config{usedirs}=0;
$msgprefix="targetpage (usedirs=0)";
is(targetpage('test1', 'html'), 'test1.en.html', "$msgprefix test1");
is(targetpage('test1.fr', 'html'), 'test1.fr.html', "$msgprefix test1.fr");
is(targetpage('test4.fr', 'html'), 'test4.fr.html', "$msgprefix test4.fr");
is(targetpage('test4.en', 'html'), 'test4.en.html', "$msgprefix test4.en");
is(targetpage('test4.es', 'html'), 'test4.es.html', "$msgprefix test4.es");
$config{usedirs}=1;
$msgprefix="targetpage (usedirs=1)";
is(targetpage('index', 'html'), 'index.en.html', "$msgprefix index");
is(targetpage('index.fr', 'html'), 'index.fr.html', "$msgprefix index.fr");
is(targetpage('test1', 'html'), 'test1/index.en.html', "$msgprefix test1");
is(targetpage('test1.fr', 'html'), 'test1/index.fr.html', "$msgprefix test1.fr");
is(targetpage('test3', 'html'), 'test3/index.html', "$msgprefix test3 (non-translatable page)");
is(targetpage('test3.es', 'html'), 'test3.es/index.html', "$msgprefix test3.es (non-translatable page)");
# XXX: test4

### urlto -> index
$config{po_link_to}='current';
$msgprefix="urlto (po_link_to=current)";
is(urlto('', 'index'), './index.en.html', "$msgprefix index -> ''");
is(urlto('', 'nontranslatable'), '../index.en.html', "$msgprefix nontranslatable -> ''");
is(urlto('', 'translatable.fr'), '../index.fr.html', "$msgprefix translatable.fr -> ''");
$config{po_link_to}='negotiated';
$msgprefix="urlto (po_link_to=negotiated)";
is(urlto('', 'index'), './', "$msgprefix index -> ''");
is(urlto('', 'nontranslatable'), '../', "$msgprefix nontranslatable -> ''");
is(urlto('', 'translatable.fr'), '../', "$msgprefix translatable.fr -> ''");

### bestlink
$config{po_link_to}='current';
$msgprefix="bestlink (po_link_to=current)";
is(bestlink('test1.fr', 'test2'), 'test2.fr', "$msgprefix test1.fr -> test2");
is(bestlink('test1.fr', 'test2.es'), 'test2.es', "$msgprefix test1.fr -> test2.es");
$config{po_link_to}='negotiated';
$msgprefix="bestlink (po_link_to=negotiated)";
is(bestlink('test1.fr', 'test2'), 'test2.fr', "$msgprefix test1.fr -> test2");
is(bestlink('test1.fr', 'test2.es'), 'test2.es', "$msgprefix test1.fr -> test2.es");

### beautify_urlpath
$config{po_link_to}='default';
$msgprefix="beautify_urlpath (po_link_to=default)";
is(IkiWiki::beautify_urlpath('test1/index.en.html'), './test1/index.en.html', "$msgprefix test1/index.en.html");
is(IkiWiki::beautify_urlpath('test1/index.fr.html'), './test1/index.fr.html', "$msgprefix test1/index.fr.html");
$config{po_link_to}='negotiated';
$msgprefix="beautify_urlpath (po_link_to=negotiated)";
is(IkiWiki::beautify_urlpath('test1/index.html'), './test1/', "$msgprefix test1/index.html");
is(IkiWiki::beautify_urlpath('test1/index.en.html'), './test1/', "$msgprefix test1/index.en.html");
is(IkiWiki::beautify_urlpath('test1/index.fr.html'), './test1/', "$msgprefix test1/index.fr.html");

### support for master file not being in the master language
$msgprefix="otherlanguages";
is(${IkiWiki::Plugin::po::otherlanguages('test1')}{fr}, 'test1.fr', "$msgprefix test1, fr");
is(${IkiWiki::Plugin::po::otherlanguages('test1')}{en}, undef, "$msgprefix test1, en");
is(${IkiWiki::Plugin::po::otherlanguages('test4.fr')}{es}, 'test4.es', "$msgprefix test4, es");
is(${IkiWiki::Plugin::po::otherlanguages('test4.fr')}{en}, 'test4.en', "$msgprefix test4, en");
is(${IkiWiki::Plugin::po::otherlanguages('test4.fr')}{fr}, undef, "$msgprefix test4, fr");

### pofile
$msgprefix="pofile";
is(IkiWiki::Plugin::po::pofile('test1.mdwn','fr'), 'test1.fr.po', "$msgprefix test1.mdwn, fr");
is(IkiWiki::Plugin::po::pofile('test4.fr.mdwn','es'), 'test4.es.po', "$msgprefix test4.fr.mdwn, es");
is(IkiWiki::Plugin::po::pofile('test4.fr.mdwn','en'), 'test4.en.po', "$msgprefix test4.fr.mdwn, en");

### pofiles
$msgprefix="pofiles";
is_deeply([sort(IkiWiki::Plugin::po::pofiles('test1.mdwn'))], ['test1.es.po', 'test1.fr.po'], "$msgprefix test1");
is_deeply([sort(IkiWiki::Plugin::po::pofiles('test4.fr.mdwn'))], ['test4.en.po', 'test4.es.po'], "$msgprefix test4");

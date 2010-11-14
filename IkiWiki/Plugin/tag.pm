#!/usr/bin/perl
# Ikiwiki tag plugin.
package IkiWiki::Plugin::tag;

use warnings;
use strict;
use IkiWiki 3.00;

sub import {
	hook(type => "getopt", id => "tag", call => \&getopt);
	hook(type => "getsetup", id => "tag", call => \&getsetup);
	hook(type => "preprocess", id => "tag", call => \&preprocess_tag, scan => 1);
	hook(type => "preprocess", id => "taglink", call => \&preprocess_taglink, scan => 1);
	hook(type => "pagetemplate", id => "tag", call => \&pagetemplate);
}

sub getopt () {
	eval q{use Getopt::Long};
	error($@) if $@;
	Getopt::Long::Configure('pass_through');
	GetOptions("tagbase=s" => \$config{tagbase});
}

sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => undef,
		},
		tagbase => {
			type => "string",
			example => "tag",
			description => "parent page tags are located under",
			safe => 1,
			rebuild => 1,
		},
		tag_autocreate => {
			type => "boolean",
			example => 1,
			description => "autocreate new tag pages?",
			safe => 1,
			rebuild => undef,
		},
}

sub taglink ($) {
	my $tag=shift;
	
	if ($tag !~ m{^/} &&
	    defined $config{tagbase}) {
		$tag="/".$config{tagbase}."/".$tag;
		$tag=~y#/#/#s; # squash dups
	}

	return $tag;
}

sub htmllink_tag ($$$;@) {
	my $page=shift;
	my $destpage=shift;
	my $tag=shift;
	my %opts=@_;

	return htmllink($page, $destpage, taglink($tag), %opts);
}

sub gentag ($) {
	my $tag=shift;

	if ($config{tag_autocreate} ||
	    ($config{tagbase} && ! defined $config{tag_autocreate})) {
		my $tagpage=taglink($tag);
		if ($tagpage=~/^\.\/(.*)/) {
			$tagpage=$1;
		}
		else {
			$tagpage=~s/^\///;
		}

		my $tagfile = newpagefile($tagpage, $config{default_pageext});

		add_autofile($tagfile, "tag", sub {
			my $message=sprintf(gettext("creating tag page %s"), $tagpage);
			debug($message);

			my $template=template("autotag.tmpl");
			$template->param(tagname => IkiWiki::basename($tag));
			$template->param(tag => $tag);
			writefile($tagfile, $config{srcdir}, $template->output);
			if ($config{rcs}) {
				IkiWiki::disable_commit_hook();
				IkiWiki::rcs_add($tagfile);
				IkiWiki::rcs_commit_staged(message => $message);
				IkiWiki::enable_commit_hook();
			}
		});
	}
}

sub preprocess_tag (@) {
	if (! @_) {
		return "";
	}
	my %params=@_;
	my $page = $params{page};
	delete $params{page};
	delete $params{destpage};
	delete $params{preview};

	foreach my $tag (keys %params) {
		$tag=linkpage($tag);
		
		# hidden WikiLink
		add_link($page, taglink($tag), 'tag');
		
		gentag($tag);
	}
		
	return "";
}

sub preprocess_taglink (@) {
	if (! @_) {
		return "";
	}
	my %params=@_;
	return join(" ", map {
		if (/(.*)\|(.*)/) {
			my $tag=linkpage($2);
			add_link($params{page}, taglink($tag), 'tag');
			gentag($tag);
			return htmllink_tag($params{page}, $params{destpage}, $tag,
				linktext => pagetitle($1));
		}
		else {
			my $tag=linkpage($_);
			add_link($params{page}, taglink($tag), 'tag');
			gentag($tag);
			return htmllink_tag($params{page}, $params{destpage}, $tag);
		}
	}
	grep {
		$_ ne 'page' && $_ ne 'destpage' && $_ ne 'preview'
	} keys %params);
}

sub pagetemplate (@) {
	my %params=@_;
	my $page=$params{page};
	my $destpage=$params{destpage};
	my $template=$params{template};

	my $tags = $typedlinks{$page}{tag};

	$template->param(tags => [
		map { 
			link => htmllink_tag($page, $destpage, $_, rel => "tag")
		}, sort keys %$tags
	]) if defined $tags && %$tags && $template->query(name => "tags");

	if ($template->query(name => "categories")) {
		# It's an rss/atom template. Add any categories.
		if (defined $tags && %$tags) {
			$template->param(categories => [map { category => $_ },
				sort keys %$tags]);
		}
	}
}

package IkiWiki::PageSpec;

sub match_tagged ($$;@) {
	my $page=shift;
	my $glob=IkiWiki::Plugin::tag::taglink(shift);
	return match_link($page, $glob, linktype => 'tag', @_);
}

1

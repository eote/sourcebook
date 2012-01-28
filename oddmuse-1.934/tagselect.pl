# Copyright (C) 2005  Fletcher T. Penney <fletcher@freeshell.org>
# Copyright (c) 2007  Alexander Uvizhev <uvizhe@yandex.ru>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA

$ModulesDescription .= '<p>$Id: tagselect.pl,v 0.1 2009/09/13 </p>';

use vars qw($TagFormPage
            $TagMark 
        $TagClass 
        $TagString 
        $TagSelectTitle 
        $TagDisplaySummary $TagDisplaySummaryAsTitle
        $DisplayNumberofPages $DisplayNumberofPagesAsTitle );

$TagFormPage = "Liste des tags" unless defined $TagFormPage;

# Page tags are identified by this mark (input mark)
$TagMark = "Tags:" unless defined $TagMark;

# Page tags enclosed in DIV block of this class
$TagClass = "tags" unless defined $TagClass;

# This string precedes tags on page (output mark)
$TagString = "Tags: " unless defined $TagString;

# If set to 1, the summary of the page is displayed 
# near the link in the page with the result of the 
# tagselect action.

$TagDisplaySummary = 1 unless defined $TagDisplaySummary;

# or as title of the link

$TagDisplaySummaryAsTitle = 1 unless defined $TagDisplaySummaryAsTitle;

# If set to 1, the number of pages corresponding to each tag
# is shown near the name of the tag in the form.

$DisplayNumberofPages = 1 unless defined $DisplayNumberofPages;

# idem as a title. 

$DisplayNumberofPagesAsTitle = 1 unless defined $DisplayNumberofPagesAsTitle;

$Action{tagform} = \&DoTagForm;

$Action{tagselect} = \&DoTagSelect;

$TagSelectTitle = "Pages avec le tag «%s»";

push (@MyRules, \&TagRule);

my $TagList = {};
my $PagesTags = {};

sub TagRule { # Process page tags on a page

    if ( m/\G$TagMark\s*(.*)/gc) {  # find page tags
        my @tags = split /,\s*/, $1;  # push them in array
        @tags = map {                 # and generate html output:
            qq{<a href="$ScriptName?action=tagselect;tag=$_">$_</a>};  # each tag is a link to search all pages with that tag
        } @tags;
        my $tags = join ', ', @tags;
        return qq{<div class="$TagClass">$TagString$tags</div>}; # tags are put in DIV block
    }
    return undef;
}

sub DoTagSelect {

    # my $searchedtag = GetParam('tag');  # get tag parameter
    my @searchedtags = @{$q->{'tag'}};
    my $header = Ts($TagSelectTitle, join('+',@searchedtags));  # modify page title with requested tag
    print GetHeader('',$header,'');  # print title

    print '<div class="content">';
    
    CreateTagTrees();

    my $result = "<ul>";
    foreach $p (sort keys %{$PagesTags}) {
        my $title = NormalToFree($p);
        my $ok = 0;
        my $summaryastext = $TagDisplaySummary ? '<span class="summary">' . $PagesTags->{$p}->{$summary} . '</span>' : ""; 
        my $summaryastitle = $TagDisplaySummaryAsTitle ?  'title="' .  $PagesTags->{$p}->{$summary} . '"' : ""; 
        my $numberoftags = @searchedtags;
        foreach $e (@searchedtags) {
            if (defined $PagesTags->{$p}->{$e}) {
                $ok += 1;
            }
        }
        if ($ok == $numberoftags){ 
           $result .= "<li><a $summaryastitle href=\"$FullUrl/$p\">$title</a> $summaryastext </li>";
        }
    }
    $result .= "</ul>";

    print $result;

    print '</div>';
    
    PrintFooter();

}


sub DoTagForm {
    
    print GetHeader('',$TagFormPage,'');
    
    CreateTagTrees();

    print '<div class="content">';

    TagForm();
    
    print '</div>';
    
    PrintFooter();
}


sub CreateTagTrees {
    my @pages = AllPagesList();
    
    local %Page;
    local $OpenPageName='';
    
    foreach my $page (@pages) {
        OpenPage($page);
        my @tags = GetTags($Page{text});
        my $page = FreeToNormal($page);
        
        my $count = @tags;
        if ($count != 0) {
                	
            foreach $t (@tags) {
                $TagList->{$t}->{$page} = 1;
                $PagesTags->{$page}->{$t} = 1;
                $PagesTags->{$page}->{$summary} = $Page{summary};
            }
        }
    }
}

sub TagForm {
    $form = '<form class="tagsform" action="' . $ScriptName . '">';
    foreach $tag (sort keys %$TagList) {
        my $n = keys %{$TagList->{$tag}};
        my $numberofpages = $DisplayNumberofPages ? "($n)" : ""; 
	my $title = $DisplayNumberofPagesAsTitle ? 'title="' . $n .  ' page(s)"' : "" ;

        $form .= '<div class="tag" '. $title . '><input type="checkbox" name="tag" value="' . $tag . '" />';
    $form .= "$tag $numberofpages</div>";
        #$form .= '<input type="checkbox" name="' . $tag . '" value="' . $tag .  '" /> $tag';
    }
    $form .= '<div class="tagbuttons"><input type="submit" value="envoyer" /><input type="reset" /></div>';
    $form .= '<div><input type="hidden" name="action" value="tagselect" /></div>';
    $form .= '</form>';
    print $form;
}


sub GetTags {
    my $text = shift;
    my @tags;

    # strip [[.*?]] bits, then split on spaces

    if ($text =~ /^$TagMark\s*(.*)$/m) {
        my $tagstring = $1;
        @tags = split /,\s*/, $tagstring;
    } else {
        return;
    }
    
    return @tags;
}


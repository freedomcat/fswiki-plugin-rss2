###############################################################################
#
# <p>�ʰ�RSS�꡼�����ץ饰����</p>
# <p>WEB�ե����ɤ�URI����ꤹ��ȡ�Wiki�ڡ�����˥ե����ɤ����Ƥ����ɽ�����ޤ���</p>
# <pre>
# {{rss (WEB�ե�����URI),(ɽ�����),(����å���ͭ������[ʬ]),(ʸ����)}}
# </pre>
# <dl>
# <dt>WEB�ե�����URI</dt><dd>RSS�ե����ɤ�URL����ꤷ�ޤ���</dd>
# <dt>ɽ�����</dt><dd>RSS�ե����ɤ������ޤ�륨��ȥ��ɽ�������������̵�������20���</dd>
# <dt>����å���ͭ������</dt><dd>RSS����򥭥�å��夹��ͭ�����֡�̵�������60ʬ��</dd>
# <dt>ʸ����</dt><dd>����800�Х���(����400ʸ��)�Ȥ���.0�Х��Ȼ���ξ��,dt/dd/dl�ǤϤʤ�ul/li�ǥ����ȥ�Τߥꥹ��ɽ�����ޤ�.</dd>
# </dl>
# <p>AutoDiscovery���ɤ߼��Ͻ���ޤ���
# �ޤ����ե����륷���ƥ���./log/*/(URL���󥳡��ɺѤ�WEB�ե�����).rss��XML�򥭥�å��夷�ޤ���
# �ե����ɤι��ɤ�ߤ᤿����FTP���եȤʤɤǺ�����Ƥ���������
# </p>
#
###############################################################################
package plugin::rss2::Aggregater;
use strict;
use XML::TreePP;
use XML::FeedPP;
#==============================================================================
# ���󥹥ȥ饯��
#==============================================================================
sub new {
	my $class = shift;
	my $self = {};
	return bless $self,$class;
}

#==============================================================================
# �ѥ饰��ե᥽�å�
#==============================================================================
sub paragraph {
	my $self = shift;
	my $wiki = shift;
	my $url  = shift;
	my $limit= shift;
	my $chache_time = shift;
	my $len  = shift;

	if(!defined($limit)){ $limit = 20; }
	if(!defined($chache_time)){ $chache_time = 60; }
	if($chache_time < 10) { $chache_time = 10; } # ����10ʬ�ϥ���å��夹�롣
	if($len > 800) { $len = 800; } # 800�Х��Ȱʲ��ˤ��롣

	my $buf;
	if($url eq '') {
		return &Util::paragraph_error("RSS��URL�����ꤵ��Ƥ��ޤ���");
	}
	my $filename = $url;
	my $cache = &Util::url_encode($filename);
	$cache = $wiki->config('log_dir')."/".&Util::md5($cache).".rss";

	my $readflag = 0;
	if(-e $cache){
		my @status = stat($cache);
		if($status[9]+($chache_time * 60) > time()){
			$readflag = 1;
		}
	}

	my $content = "";
	if($readflag==0){
		$content = &Util::get_response($wiki,$url) or return &Util::paragraph_error($!);

		open(RSS,">$cache") or return &Util::error($!);
		print RSS $content;
		close(RSS);

	} else {
		open(RSS,$cache) or return &Util::error($!);
		while(<RSS>){ $content .= $_; }
		close(RSS);
	}

	if($content !~ /<(\?xml|rss) version/i){
=pod
#	Auto-Discovery�ʤ���ưʲ����ͤʵ��ҡˤ�Ƚ�̤Ǥ���С��饤�֥֥å��ޡ�����WEB�ե����ɡˤߤ����˼����Ǥ�����������
#	<link rel="alternate" type="application/rss+xml" title="RSS" href="index.cgi?action=RSS">
#	<link rel="alternate" type="application/rss+xml" title="RSS1.0" href="?action=RSS10">
#	<link rel="alternate" type="application/rss+xml" title="RSS2.0" href="?action=RSS20">
#	<link rel="alternate" type="application/atom+xml" title="Atom0.3" href="?action=ATOM">
=cut
		return &Util::paragraph_error("XML�ե�����ǤϤ���ޤ���");
	}

	my $rss_tmpl = <<'EOM';
<h2><a href="<!--TMPL_VAR NAME="FEED_LINK"-->"><!--TMPL_VAR NAME="FEED_TITLE"--></a></h2>
<!--TMPL_IF NAME="FEED_COMMENT"-->
	<dl>
	<!--TMPL_LOOP NAME="ENTRY"-->
	<dt><a href="<!--TMPL_VAR NAME="ITEM_LINK"-->"><!--TMPL_VAR NAME="ITEM_TITLE"--></a></dt>
	<dd><!--TMPL_VAR NAME="ITEM_COMMENT"--></dd>
	<!--/TMPL_LOOP-->
	</dl>
<!--TMPL_ELSE-->
	<ul>
	<!--TMPL_LOOP NAME="ENTRY"-->
	<li><a href="<!--TMPL_VAR NAME="ITEM_LINK"-->"><!--TMPL_VAR NAME="ITEM_TITLE"--></a></li>
	<!--/TMPL_LOOP-->
	</ul>
<!--/TMPL_IF-->
EOM

	my $tpp = XML::TreePP->new();
	$tpp->set(force_array => [ "item","entry" ]);
	my $tree = $tpp->parse( $content );

	my $ver = "RSS1.0";
	if(defined($tree->{"rss"})){
		$ver = "RSS".$tree->{"rss"}->{"-version"};
#		$buf .= "DublinCore�⥸�塼��Ǥ���<br>" if(defined($tree->{"rdf:RDF"}->{"-xmlns:dc"}));
#		$buf .= "Syndication�⥸�塼��Ǥ���<br>" if(defined($tree->{"rdf:RDF"}->{"-xmlns:sy"}));
#		$buf .= "Content�⥸�塼��Ǥ���<br>" if(defined($tree->{"rdf:RDF"}->{"-xmlns:content"}));
	}elsif(defined($tree->{"feed"})){
		$ver = "ATOM".$tree->{"feed"}->{"-version"};
	}

	my (%hash,@entries,$cnt);
	$cnt=1;

	if( $len==0 ){
		$hash{'FEED_COMMENT'} = 0;
	} else {
		$hash{'FEED_COMMENT'} = 1;
	}
	if($ver eq 'RSS1.0'){
		$hash{'FEED_TITLE'} = $tree->{"rdf:RDF"}->{"channel"}->{"title"};
		$hash{'FEED_LINK'}  = $tree->{"rdf:RDF"}->{"channel"}->{"link"};
		$hash{'FEED_DESC'}  = &Util::delete_tag($tree->{"rdf:RDF"}->{"channel"}->{"description"});
		foreach (@{ $tree->{"rdf:RDF"}->{"item"} }){
			if($cnt>$limit){ last; }
			my $desc = &Util::delete_tag($_->{"description"});
			$desc = &Util::delete_tag($_->{"dc:description"}) if($desc eq '' && defined($tree->{"rdf:RDF"}->{"-xmlns:dc"}));
			
			push( @entries, {
				'ITEM_TITLE'   => $_->{title},
				'ITEM_LINK'    => $_->{link},
				'ITEM_COMMENT' => &_cut_by_bytelength($desc, $len)
			} );
			$cnt++;
		}

	}elsif($ver eq 'RSS2.0' || $ver eq 'RSS0.91'){
		$hash{'FEED_TITLE'} = $tree->{"rss"}->{"channel"}->{"title"};
		$hash{'FEED_LINK'}  = $tree->{"rss"}->{"channel"}->{"link"};
		$hash{'FEED_DESC'}  = &Util::delete_tag($tree->{"rss"}->{"channel"}->{"description"});
		foreach (@{ $tree->{"rss"}->{"channel"}->{"item"} }){
			if($cnt>$limit){ last; }
			my $desc = &Util::delete_tag($_->{description});

			push( @entries, {
				'ITEM_TITLE'   => $_->{"title"},
				'ITEM_LINK'    => $_->{"link"},
				'ITEM_COMMENT' => &_cut_by_bytelength($desc, $len)
			} );
			$cnt++;
		}

	}elsif( $ver eq 'ATOM0.3'){
		$hash{'FEED_TITLE'} = $tree->{"feed"}->{"title"}->{"#text"};
		$hash{'FEED_LINK'}  = $tree->{"feed"}->{"link"}->{"-href"};
		$hash{'FEED_DESC'}  = $tree->{"feed"}->{"modified"};
		foreach (@{ $tree->{"feed"}->{"entry"} }){
			if($cnt>$limit){ last; }
			##
			my $desc = &Util::delete_tag($_->{sammary}->{"#text"});
			$desc = &Util::delete_tag($_->{content}->{"#text"}) if($desc eq '');

			push( @entries, {
				'ITEM_TITLE'   => $_->{title}->{"#text"},
				'ITEM_LINK'    => $_->{link}->{"-href"},
				'ITEM_COMMENT' => &_cut_by_bytelength($desc, $len)
			} );
			$cnt++;
		}
	}else{
		my $feed;
		$feed = XML::FeedPP::Atom->new( $url );
		$hash{'FEED_TITLE'} = $feed->title();
		$hash{'FEED_LINK'} = $feed->link();
		$hash{'FEED_DESC'} = $feed->description();
		foreach my $item ( $feed->get_item() ){
			if($cnt>$limit){ last; }
			my $desc = &Util::delete_tag( $item->description() );
			$desc = &Util::delete_tag($item->description() ) if($desc eq '');
			push( @entries, {
				'ITEM_TITLE'	=> $item->title(),
				'ITEM_LINK'		=> $item->link(),
				'ITEM_COMMENT' => &_cut_by_bytelength($desc, $len)
			} );
			$cnt++;
		} 
	}

	$hash{'ENTRY'} = \@entries;

	my $tmpl = HTML::Template->new( scalarref => \$rss_tmpl, die_on_bad_params => 0);
	$tmpl->param(%hash);
	$buf = $tmpl->output();
	&Jcode::convert(\$buf ,'euc','utf8');
	return $buf;

}

#	from "IndexCalendarHandler.pm"
#===========================================================
# ����ΥХ��ȿ���ʸ��������
#===========================================================
sub _cut_by_bytelength{
	my $str = shift;
	my $len = shift;

	if (length($str) <= $len){ return $str; }

	# TreePP ��������UTF-8�ʤΤǡ�̵������EUC���Ѵ����Ƥ��롣
	#	���ܸ�ν����Ϥ�äȥ��ޡ��Ȥ˽����Ϥ���
	&Jcode::convert(\$str ,'euc');
	$str = substr($str,0,$len + 1 - 3);    #...�Ѥ�;ʬ��3�Х��Ⱥ��
	#EUC��2byteʸ����������ڤ�Ƥ����顢�⤦1�Х��Ⱥ��
	if ($str =~ /\x8F$/ or $str =~ tr/\x8E\xA1-\xFE// % 2) {
	    $str = substr($str, 0, length($str)-1);
	}
	&Jcode::convert(\$str ,'utf8');

	return $str.'...';
}
#-- Thank you

1;

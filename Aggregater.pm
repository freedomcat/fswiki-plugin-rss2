###############################################################################
#
# <p>簡易RSSリーダ・プラグイン</p>
# <p>WEBフィードのURIを指定すると、Wikiページ内にフィードの内容を一覧表示します。</p>
# <pre>
# {{rss (WEBフィードURI),(表示件数),(キャッシュ有効時間[分]),(文字数)}}
# </pre>
# <dl>
# <dt>WEBフィードURI</dt><dd>RSSフィードのURLを指定します。</dd>
# <dt>表示件数</dt><dd>RSSフィードに埋め込まれるエントリの表示最大数を指定（無指定時は20件）</dd>
# <dt>キャッシュ有効時間</dt><dd>RSS情報をキャッシュする有効時間（無指定時は60分）</dd>
# <dt>文字数</dt><dd>最大800バイト(全角400文字)とする.0バイト指定の場合,dt/dd/dlではなくul/liでタイトルのみリスト表示します.</dd>
# </dl>
# <p>AutoDiscoveryの読み取りは出来ません。
# また、ファイルシステム上の./log/*/(URLエンコード済みWEBフィード).rssにXMLをキャッシュします。
# フィードの購読を止めた時はFTPソフトなどで削除してください。
# </p>
#
###############################################################################
package plugin::rss2::Aggregater;
use strict;
use XML::TreePP;
use XML::FeedPP;
#==============================================================================
# コンストラクタ
#==============================================================================
sub new {
	my $class = shift;
	my $self = {};
	return bless $self,$class;
}

#==============================================================================
# パラグラフメソッド
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
	if($chache_time < 10) { $chache_time = 10; } # 最低10分はキャッシュする。
	if($len > 800) { $len = 800; } # 800バイト以下にする。

	my $buf;
	if($url eq '') {
		return &Util::paragraph_error("RSSのURLが指定されていません。");
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
#	Auto-Discovery（せめて以下の様な記述）を判別できれば、ライブブックマーク（WEBフィード）みたいに実装できそうだが…
#	<link rel="alternate" type="application/rss+xml" title="RSS" href="index.cgi?action=RSS">
#	<link rel="alternate" type="application/rss+xml" title="RSS1.0" href="?action=RSS10">
#	<link rel="alternate" type="application/rss+xml" title="RSS2.0" href="?action=RSS20">
#	<link rel="alternate" type="application/atom+xml" title="Atom0.3" href="?action=ATOM">
=cut
		return &Util::paragraph_error("XMLファイルではありません。");
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
#		$buf .= "DublinCoreモジュールです。<br>" if(defined($tree->{"rdf:RDF"}->{"-xmlns:dc"}));
#		$buf .= "Syndicationモジュールです。<br>" if(defined($tree->{"rdf:RDF"}->{"-xmlns:sy"}));
#		$buf .= "Contentモジュールです。<br>" if(defined($tree->{"rdf:RDF"}->{"-xmlns:content"}));
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
# 指定のバイト数で文字列を確保
#===========================================================
sub _cut_by_bytelength{
	my $str = shift;
	my $len = shift;

	if (length($str) <= $len){ return $str; }

	# TreePP の内部がUTF-8なので、無理矢理EUCに変換している。
	#	日本語の処理はもっとスマートに出来るはず。
	&Jcode::convert(\$str ,'euc');
	$str = substr($str,0,$len + 1 - 3);    #...用に余分に3バイト削る
	#EUCで2byte文字が途中で切れていたら、もう1バイト削る
	if ($str =~ /\x8F$/ or $str =~ tr/\x8E\xA1-\xFE// % 2) {
	    $str = substr($str, 0, length($str)-1);
	}
	&Jcode::convert(\$str ,'utf8');

	return $str.'...';
}
#-- Thank you

1;

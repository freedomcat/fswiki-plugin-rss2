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

	my $rss_tmpl = <<'EOM';
<h2><a href="<!--TMPL_VAR NAME="FEED_LINK"-->"><!--TMPL_VAR NAME="FEED_TITLE"--></a></h2>
<!--TMPL_IF NAME="FEED_COMMENT"-->
	<dl>
	<!--TMPL_LOOP NAME="ENTRY"-->
	<dt><!--TMPL_VAR NAME="ITEM_DATE"--><a href="<!--TMPL_VAR NAME="ITEM_LINK"-->"><!--TMPL_VAR NAME="ITEM_TITLE"--></a></dt>
	<dd><!--TMPL_VAR NAME="ITEM_COMMENT"--></dd>
	<!--/TMPL_LOOP-->
	</dl>
<!--TMPL_ELSE-->
	<ul>
	<!--TMPL_LOOP NAME="ENTRY"-->
	<li><!--TMPL_VAR NAME="ITEM_DATE"--><a href="<!--TMPL_VAR NAME="ITEM_LINK"-->"><!--TMPL_VAR NAME="ITEM_TITLE"--></a></li>
	<!--/TMPL_LOOP-->
	</ul>
<!--/TMPL_IF-->
EOM

	my (%hash,@entries,$cnt);
	$cnt=1;

	if( $len==0 ){
		$hash{'FEED_COMMENT'} = 0;
	} else {
		$hash{'FEED_COMMENT'} = 1;
	}
	my $feed = XML::FeedPP->new( $url );
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
			'ITEM_DATE'		=> &_encode_by_YYYYMMDDhhmm($item->pubDate()),

			'ITEM_COMMENT' => &_cut_by_bytelength($desc, $len)
		} );
		$cnt++;
	}

	$hash{'ENTRY'} = \@entries;

	my $tmpl = HTML::Template->new( scalarref => \$rss_tmpl, die_on_bad_params => 0);
	$tmpl->param(%hash);
	$buf = $tmpl->output();
	&Jcode::convert(\$buf ,'euc','utf8');
	return $buf;

}


#===========================================================
# pubDateの日付を編集 
#===========================================================
sub _encode_by_YYYYMMDDhhmm{
	my $date = shift;

	if ($date =~ /^(\d{4})(?:-(\d{2})(?:-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d))?)?(Z|([+-]\d{2}):(\d{2}))?)?)?)?$/) {

		my ($year, $month, $day, $hour, $min, $sec, $wday) = ($1, ($2 ? $2 : 1), ($3 ? $3 : 1), $4, $5, $6);
	    my $offset = (abs($9) * 60 + $10) * ($9 >= 0 ? 60 : -60) if ($8);
		my $time   = ($8) ? &Time::Local::timegm($sec, $min, $hour, $day, $month - 1, $year) - $offset
			: &Time::Local::timelocal($sec, $min, $hour, $day, $month - 1, $year) - $offset;

		($sec, $min, $hour, $day, $month, $year, $wday) = localtime($time);
		#$wday = (qw(Sun Mon Thu Wed Tue Fir Sat))[$wday];
		$wday = (qw(日 月 火 水 木 金 土))[$wday];
	   # $date = sprintf('[%04d-%02d-%02d (%s) %02d:%02d:%02d] ', $year + 1900, $month + 1, $day, $wday, $hour, $min, $sec);
	    $date = sprintf('%2d月%2d日 (%s) %02d:%02d ',  $month + 1, $day, $wday, $hour, $min);
	}
	&Jcode::convert(\$date ,'utf8');
	return $date;
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

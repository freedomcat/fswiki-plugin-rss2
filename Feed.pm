###############################################################################
#
# <p>RSSフィード生成機能を提供します。</p>
# <p>RSSフィードの表示は、<strong>RSS10</strong>、<strong>RSS20</strong>、<strong>ATOM</strong>となります。パラグラフプラグインで実装しました。</p>
# <pre>
#  {{feed (RSS),(グループ),(更新時間[秒])}}
# </pre>
# <dl>
# <dt>RSS</dt><dd>フィードの種類を<strong>RSS10</strong>、<strong>RSS20</strong>、<strong>ATOM</strong>で表記します(全て大文字)</dd>
# <dt>グループ</dt><dd>FSWikiのページ保存名を前方一致でグループ化します。</dd>
# <dt>更新時間</dt><dd>Feed用キャッシュを更新するタイミング。秒単位で指定(デフォルトは、1時間(3600)。10分以下(600)の指定は更新無し)。</dd>
# </dl>
# <p>更新時間は、サイドバーなどで利用するときに毎回更新されるのを抑止する目的で実装しています。</p>
# <p>AutoDiscovery機能は、サイドバーなどに記述した場合も有効です。API Wiki.head_infoを活用し、ヘッダ内に１行だけ追記する仕様の為です。</p>
#
###############################################################################
package plugin::rss2::Feed;
use strict;
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
sub inline {
	my ($self,$wiki,$feedtype,$group,$update) = @_;

	if($feedtype ne 'RSS10' && $feedtype ne 'RSS20' && $feedtype ne 'ATOM' ){
		return &Util::paragraph_error("RSSのバージョン指定が正しくありません。");
	}

	##	必要であれば、Feed用のキャッシュファイルを更新
	if($update eq '' || !Util::check_numeric($update)){
		$update = 3600;    # デフォルトは1時間
	}elsif($update < 600){ # ただし、10分以下の指定は更新不可とする。
		$update = 0;
	}
	my $file = &_get_cachefile_name($wiki,$feedtype,$update);
	#	ファイルが有るときは、更新秒に依存
	if(-e $file){
		if($update){
			if(time() - (stat($file))[9] > $update){
				&_make_rss( $wiki, $file );
			}
		}
	}else{
		my $cgi  = $wiki->get_CGI();
		$cgi->param('group',$group);
		$cgi->param('action',$feedtype);
		&_make_rss( $wiki, $file );
	}

	##	グループ指定時のAuto-Discovery の出力（メインページのみ有効）
	my $feed_uri = &_set_autodiscovery($wiki,$feedtype,$group);

	# Feedを出力
	return "[".$feedtype."\|". $feed_uri ."]";

}

#==============================================================================
# アクションハンドラ
#==============================================================================
sub do_action {
	my $self = shift;
	my $wiki = shift;
	my $cgi  = $wiki->get_CGI();
	my $feedtype = $cgi->param('action');
	my $group = $cgi->param('group');

	my $file = &_get_cachefile_name($wiki,$feedtype,$group);
	# キャッシュファイルが存在しない場合は作成
	unless(-e $file){
		&_make_rss( $wiki, $file );
	}

	# RSSをレスポンス
	print "Content-Type: application/xml;charset=utf-8\n\n";
	open(RSS,$file);
	binmode(RSS);
	while(<RSS>){
		print $_;
	}
	close(RSS);
	exit();
}

#==============================================================================
# フックメソッド
#==============================================================================
sub hook {
	my $self = shift;
	my $wiki = shift;
	my $hook = shift;
	
	my $cgi  = $wiki->get_CGI();
	my $uri = $wiki->config('server_host');
	if($uri eq ""){
		$uri = $wiki->get_CGI()->url(-path_info => 1);
	} else {
		$uri = $uri . $wiki->get_CGI->url(-absolute => 1) . $wiki->get_CGI()->path_info();
	}

	if($hook eq "initialize"){

		## Auto-Discovery(管理画面で選ぶ形でもよいかも)
		&_set_autodiscovery($wiki,"RSS10");
		&_set_autodiscovery($wiki,"RSS20");
		&_set_autodiscovery($wiki,"ATOM");

		##	グループ指定時のAuto-Discovery の出力（メインページ以外）
		#	常時表示の特別ページを調査、ヘッダに埋め込む
		my @pages = ('Header','Footer','Menu','Menu2','NaviTop','NaviBottom','NaviCI','NaviSearch');
		foreach (@pages){
			if($wiki->page_exists($_)){
				&_check_sp_pages($wiki,$wiki->get_page($_));
			}
		}

	} else {

		## Save & delete Chach update
		my $act = $cgi->param('action');
		$cgi->param('action',"RSS10");
			&_make_rss($wiki, &_get_cachefile_name($wiki,$cgi->param('action')) );
		$cgi->param('action',"RSS20");
			&_make_rss($wiki, &_get_cachefile_name($wiki,$cgi->param('action')) );
		$cgi->param('action',"ATOM");
			&_make_rss($wiki, &_get_cachefile_name($wiki,$cgi->param('action')) );
		$cgi->param('action',$act);

	}

}

#==============================================================================
# Feed用キャッシュファイル名取得
#==============================================================================
sub _get_cachefile_name {
	my ($wiki,$feedtype,$group) = @_;
	my $file;
	if($group eq ''){
		$file = $wiki->config('log_dir')."/feed_".$feedtype.".rss";
	} else {
		$file = $wiki->config('log_dir')."/feed_".$feedtype."_".&Util::url_encode($group) .".rss";
	}
	return $file;
}

#==============================================================================
# Feed用キャッシュファイル作成
#==============================================================================
#	hook,paragraphではファイル生成目的で利用され、
#	
sub _make_rss {
	my $wiki = shift;
	my $file = shift;

	my $cgi  = $wiki->get_CGI();
	my $group = $cgi->param('group');

	## Site Information
	my ( $site_title, $site_desc, $author);
	$site_title = $wiki->config('site_title');

	#	siteinfo (非公式公開パッチ)を適用時、サイトの概要説明を埋め込む
	$site_desc  = ( defined( $wiki->config('page_description') ) ) ?
	              $wiki->config('page_description'):
	              $wiki->config('site_title'). "の更新情報";

	$author     = ( defined( $wiki->config('admin_name'))) ?
	              $wiki->config('admin_name'):
	              "FreeStyle Wiki User";

	## Pages Information
	my ( $pagetitle_hash, $pagedesc_hash );
	if($wiki->is_installed('_ex_wikianchor'))
	{
		$pagetitle_hash = &Util::load_config_hash(undef,$wiki->config('log_dir')."/pagetitle.cache");
	}

	# URIを生成
	my ( $uri, $feedtype, $time );
	$uri = $wiki->config('server_host');
	if($uri eq ""){
		$uri = $wiki->get_CGI()->url(-path_info => 1);
	} else {
		$uri = $uri . $wiki->get_CGI->url(-absolute => 1) . $wiki->get_CGI()->path_info();
	}
	#	mod_rewrite
	#	$uri= './';

	$feedtype = "RDF"; # RSS1.0
	if   ($cgi->param('action') eq 'ATOM')  { $feedtype = "Atom"; }
	elsif($cgi->param('action') eq 'RSS20') { $feedtype = "RSS"; }
	$time = time();

	# Feedを生成
	my $feed = eval("XML::FeedPP::${feedtype}->new();");

	$feed->language   ( "ja-jp" );
	$feed->title      ( &Jcode::convert($site_title,'utf8') );
	$feed->link       ( $uri );
	$feed->description( &Jcode::convert($site_desc,'utf8') );
	$feed->pubDate    ( $time );
	$feed->copyright  ( &Jcode::convert($author,'utf8') );
#	$feed->image      ( $url, $title, $link, $description, $width, $height );

	# 更新情報をソートして読み込む
	my @list = $wiki->get_page_list({ -sort=>'last_modified', -permit=>'show' });


	my $cnt = 1;
	foreach my $page (@list) {
		# 公開されているページのみ
		next if($wiki->get_page_level($page)!=0);
		# typer氏のプラグイン提案による（BT/246）
		# グループ指定がある場合、マッチするかを確認
		if($group ne "" and !($page =~ /^\Q$group\E/)){ next; }
		

		# Wiki Source の処理
		my ( $content, $pagetitle, $pagedesc );

		$pagetitle = Util::escapeHTML($page);
		# 別途指定タイトルを優先利用
		if($wiki->is_installed('_ex_wikianchor') && $pagetitle_hash->{Util::escapeHTML($page)} ne ''){
			$pagetitle = $pagetitle_hash->{Util::escapeHTML($page)};
		}

		$content   = $wiki->get_page($page);
		$content   = &_get_excerpt( $content );
		$content   = &_escapeXML( $content );
		$content   = &_get_description($content);
		$pagedesc  = $content;

		# Feedに埋め込む
		my $item = $feed->add_item( $uri . '?page=' . &Util::url_encode($page) );

		$item->guid       ( $page.'/'.$wiki->get_last_modified($page) );
		$item->title      ( &Jcode::convert($pagetitle,'utf8') );
		$item->description( &Jcode::convert($pagedesc,'utf8') );
		$item->pubDate    ( $wiki->get_last_modified2($page) );
		my $item_author = { 'name' => &Jcode::convert($author,'utf8') };
		$item->set( %$item_author );

		# 表示数カウンタ(変更できるようにする)
		if($cnt > 20 ){ last; } else { $cnt++; }

	}
	$feed->to_file( $file );

}

#==============================================================================
# WikiPageソースから最初の見出しをplain textで返す
#==============================================================================
sub _get_description {
	my ($page_body) = @_;
	$page_body =~ s/[\r\n]//gmo;
	my $headline = &_ksubstr_euc($page_body,0,250);
	return $headline.((length($page_body)>length($headline))?"...":"");
}

sub _ksubstr_euc {
	my($str, $st, $en) = @_;
	my($klen) = 0;
	my($len) = length($str);
	my($cn, $string, $i);
	my($ksubstring) = '';
	for ($i = 0; $i < $len; $i++) {
		$string = substr($str, $i, 1);
		$cn = unpack("C", $string);
		if ($cn >= 0xA0 && $cn <= 0xFF || $cn == 0x8E) {
			$i++;
			$string .= substr($str, $i, 1);
		} elsif ($cn == 0x8F) { # 補助漢字
			$i++;
			$string .= substr($str, $i, 2);
			$i++;
		}
		if ($klen >= $st && $klen < $st + $en) { $ksubstring .= $string; }
		$klen++;
	}
	$ksubstring;
}

#==============================================================================
# 渡された文字列をXMLのエンティティに変換して返す
#==============================================================================
sub _escapeXML {
	my ($str) = @_;
	my %table = (
		'&' => '&amp;',
		'<' => '&lt;',
		'>' => '&gt;',
		"'" => '&apos;',
		'"' => '&quot;',
	);
	$str =~ s/([&<>\'\"])/$table{$1}/go;
	return $str;
}

#-- from TrackBack plugin(SendPingHandler.pm)
#===========================================================
# ページ本文より要約を抜き出す
#===========================================================
sub _get_excerpt {
    my $page_body = shift;

	#コメント行を除去
	$page_body =~ s|^//.*$||mg;

	# ブラケットアンカーを除去
	$page_body =~ s/^\[{1}(.*)|(.*)\]{1}/$1/mg;
	$page_body =~ s/^\[{2}(.*)|(.*)\]{2}/$1/mg;

	$page_body =~ s/\'{2}(.*)\'{2}/$1/mg;
	$page_body =~ s/\'{3}(.*)\'{3}/$1/mg;

	
	$page_body =~ s/\_{2}(.*)\_{2}/$1/mg;
	$page_body =~ s/(\={2}.*\={2})//mg;

    # プラグインを除去
    $page_body =~ s/{{((.|\s)+?)}}//g;

    # 見出し
    $page_body =~ s/^!{1,3}//mg;
    # 項目
    $page_body =~ s/^\*{1,3}//mg;
    # 番号付き項目
    $page_body =~ s/^\+{1,3}//mg;
    # 水平線
    $page_body =~ s/^-{4}$//mg;
    # 引用
    $page_body =~ s/^""//mg;
    # PRE
    $page_body =~ s/^(\s|\t)//mg;

    # 改行を除去
    $page_body =~ s/^\n+//g;
    $page_body =~ s/\n/ /g;

	return $page_body;
}

#==============================================================================
# 特別ページに関するプラグイン利用状況取得
#==============================================================================
#	特別ページでの利用状況を毎回取得するのではなく
#	キャッシュファイル化して高速化するのも良いかも。
sub _check_sp_pages {
	my $wiki   = shift;
	my $source = shift;

	foreach my $line (split(/\n/,$source)){

		if(index($line," ")!=0 && index($line,"\t")!=0 && index($line,"//")!=0){
			while($line =~ /{{(feed\s+(.+?)\s*)}}/g){
				my $plugin = $wiki->parse_inline_plugin($1);
				&_set_autodiscovery($wiki,$plugin->{args}->[0],$plugin->{args}->[1]);
			}
		}

	}
	return '';

}

sub _set_autodiscovery {
	my ($wiki,$feedtype,$group) = @_;

	my ($uri,$feed_uri,$feed_ad);
	$uri = $wiki->config('server_host');
	if($uri eq ""){
		$uri = $wiki->get_CGI()->url(-path_info => 1);
	} else {
		$uri = $uri . $wiki->get_CGI->url(-absolute => 1) . $wiki->get_CGI()->path_info();
	}
#	mod_rewrite 対応案
#	$uri = './';

	$feed_uri = $uri . "?action=".$feedtype;
	if($group ne ''){
		$feed_uri .= "&amp;group=".$group;
		$group = ' '.$group;
	}

	##	Auto-Discovery の出力
	if($feedtype eq 'RSS10'){
		$feed_ad = "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS1.0".$group."\" href=\"".$feed_uri."\">";
	}
	elsif($feedtype eq 'RSS20'){
		$feed_ad = "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS2.0".$group."\" href=\"".$feed_uri."\">";
	}
	elsif($feedtype eq 'ATOM'){
		$feed_ad = "<link rel=\"alternate\" type=\"application/atom+xml\" title=\"Atom0.3".$group."\" href=\"".$feed_uri."\">";
	}
	if($feed_ad ne ''){
		$wiki->add_head_info($feed_ad);
	}
	return $feed_uri;
}

1;

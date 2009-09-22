###############################################################################
#
# <p>RSS�ե�����������ǽ���󶡤��ޤ���</p>
# <p>RSS�ե����ɤ�ɽ���ϡ�<strong>RSS10</strong>��<strong>RSS20</strong>��<strong>ATOM</strong>�Ȥʤ�ޤ����ѥ饰��եץ饰����Ǽ������ޤ�����</p>
# <pre>
#  {{feed (RSS),(���롼��),(��������[��])}}
# </pre>
# <dl>
# <dt>RSS</dt><dd>�ե����ɤμ����<strong>RSS10</strong>��<strong>RSS20</strong>��<strong>ATOM</strong>��ɽ�����ޤ�(������ʸ��)</dd>
# <dt>���롼��</dt><dd>FSWiki�Υڡ�����¸̾���������פǥ��롼�ײ����ޤ���</dd>
# <dt>��������</dt><dd>Feed�ѥ���å���򹹿����륿���ߥ󥰡���ñ�̤ǻ���(�ǥե���Ȥϡ�1����(3600)��10ʬ�ʲ�(600)�λ���Ϲ���̵��)��</dd>
# </dl>
# <p>�������֤ϡ������ɥС��ʤɤ����Ѥ���Ȥ�����󹹿������Τ��޻ߤ�����Ū�Ǽ������Ƥ��ޤ���</p>
# <p>AutoDiscovery��ǽ�ϡ������ɥС��ʤɤ˵��Ҥ�������ͭ���Ǥ���API Wiki.head_info����Ѥ����إå���ˣ��Ԥ����ɵ�������ͤΰ٤Ǥ���</p>
#
###############################################################################
package plugin::rss2::Feed;
use strict;
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
sub inline {
	my ($self,$wiki,$feedtype,$group,$update) = @_;

	if($feedtype ne 'RSS10' && $feedtype ne 'RSS20' && $feedtype ne 'ATOM' ){
		return &Util::paragraph_error("RSS�ΥС��������꤬����������ޤ���");
	}

	##	ɬ�פǤ���С�Feed�ѤΥ���å���ե�����򹹿�
	if($update eq '' || !Util::check_numeric($update)){
		$update = 3600;    # �ǥե���Ȥ�1����
	}elsif($update < 600){ # ��������10ʬ�ʲ��λ���Ϲ����ԲĤȤ��롣
		$update = 0;
	}
	my $file = &_get_cachefile_name($wiki,$feedtype,$update);
	#	�ե����뤬ͭ��Ȥ��ϡ������ä˰�¸
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

	##	���롼�׻������Auto-Discovery �ν��ϡʥᥤ��ڡ����Τ�ͭ����
	my $feed_uri = &_set_autodiscovery($wiki,$feedtype,$group);

	# Feed�����
	return "[".$feedtype."\|". $feed_uri ."]";

}

#==============================================================================
# ���������ϥ�ɥ�
#==============================================================================
sub do_action {
	my $self = shift;
	my $wiki = shift;
	my $cgi  = $wiki->get_CGI();
	my $feedtype = $cgi->param('action');
	my $group = $cgi->param('group');

	my $file = &_get_cachefile_name($wiki,$feedtype,$group);
	# ����å���ե����뤬¸�ߤ��ʤ����Ϻ���
	unless(-e $file){
		&_make_rss( $wiki, $file );
	}

	# RSS��쥹�ݥ�
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
# �եå��᥽�å�
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

		## Auto-Discovery(�������̤����ַ��Ǥ�褤����)
		&_set_autodiscovery($wiki,"RSS10");
		&_set_autodiscovery($wiki,"RSS20");
		&_set_autodiscovery($wiki,"ATOM");

		##	���롼�׻������Auto-Discovery �ν��ϡʥᥤ��ڡ����ʳ���
		#	���ɽ�������̥ڡ�����Ĵ�����إå���������
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
# Feed�ѥ���å���ե�����̾����
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
# Feed�ѥ���å���ե��������
#==============================================================================
#	hook,paragraph�Ǥϥե�����������Ū�����Ѥ��졢
#	
sub _make_rss {
	my $wiki = shift;
	my $file = shift;

	my $cgi  = $wiki->get_CGI();
	my $group = $cgi->param('group');

	## Site Information
	my ( $site_title, $site_desc, $author);
	$site_title = $wiki->config('site_title');

	#	siteinfo (����������ѥå�)��Ŭ�ѻ��������Ȥγ���������������
	$site_desc  = ( defined( $wiki->config('page_description') ) ) ?
	              $wiki->config('page_description'):
	              $wiki->config('site_title'). "�ι�������";

	$author     = ( defined( $wiki->config('admin_name'))) ?
	              $wiki->config('admin_name'):
	              "FreeStyle Wiki User";

	## Pages Information
	my ( $pagetitle_hash, $pagedesc_hash );
	if($wiki->is_installed('_ex_wikianchor'))
	{
		$pagetitle_hash = &Util::load_config_hash(undef,$wiki->config('log_dir')."/pagetitle.cache");
	}

	# URI������
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

	# Feed������
	my $feed = eval("XML::FeedPP::${feedtype}->new();");

	$feed->language   ( "ja-jp" );
	$feed->title      ( &Jcode::convert($site_title,'utf8') );
	$feed->link       ( $uri );
	$feed->description( &Jcode::convert($site_desc,'utf8') );
	$feed->pubDate    ( $time );
	$feed->copyright  ( &Jcode::convert($author,'utf8') );
#	$feed->image      ( $url, $title, $link, $description, $width, $height );

	# ��������򥽡��Ȥ����ɤ߹���
	my @list = $wiki->get_page_list({ -sort=>'last_modified', -permit=>'show' });


	my $cnt = 1;
	foreach my $page (@list) {
		# ��������Ƥ���ڡ����Τ�
		next if($wiki->get_page_level($page)!=0);
		# typer��Υץ饰������Ƥˤ���BT/246��
		# ���롼�׻��꤬�����硢�ޥå����뤫���ǧ
		if($group ne "" and !($page =~ /^\Q$group\E/)){ next; }
		

		# Wiki Source �ν���
		my ( $content, $pagetitle, $pagedesc );

		$pagetitle = Util::escapeHTML($page);
		# ���ӻ��꥿���ȥ��ͥ������
		if($wiki->is_installed('_ex_wikianchor') && $pagetitle_hash->{Util::escapeHTML($page)} ne ''){
			$pagetitle = $pagetitle_hash->{Util::escapeHTML($page)};
		}

		$content   = $wiki->get_page($page);
		$content   = &_get_excerpt( $content );
		$content   = &_escapeXML( $content );
		$content   = &_get_description($content);
		$pagedesc  = $content;

		# Feed��������
		my $item = $feed->add_item( $uri . '?page=' . &Util::url_encode($page) );

		$item->guid       ( $page.'/'.$wiki->get_last_modified($page) );
		$item->title      ( &Jcode::convert($pagetitle,'utf8') );
		$item->description( &Jcode::convert($pagedesc,'utf8') );
		$item->pubDate    ( $wiki->get_last_modified2($page) );
		my $item_author = { 'name' => &Jcode::convert($author,'utf8') };
		$item->set( %$item_author );

		# ɽ����������(�ѹ��Ǥ���褦�ˤ���)
		if($cnt > 20 ){ last; } else { $cnt++; }

	}
	$feed->to_file( $file );

}

#==============================================================================
# WikiPage����������ǽ�θ��Ф���plain text���֤�
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
		} elsif ($cn == 0x8F) { # �������
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
# �Ϥ��줿ʸ�����XML�Υ���ƥ��ƥ����Ѵ������֤�
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
# �ڡ�����ʸ��������ȴ���Ф�
#===========================================================
sub _get_excerpt {
    my $page_body = shift;

	#�����ȹԤ����
	$page_body =~ s|^//.*$||mg;

	# �֥饱�åȥ��󥫡������
	$page_body =~ s/^\[{1}(.*)|(.*)\]{1}/$1/mg;
	$page_body =~ s/^\[{2}(.*)|(.*)\]{2}/$1/mg;

	$page_body =~ s/\'{2}(.*)\'{2}/$1/mg;
	$page_body =~ s/\'{3}(.*)\'{3}/$1/mg;

	
	$page_body =~ s/\_{2}(.*)\_{2}/$1/mg;
	$page_body =~ s/(\={2}.*\={2})//mg;

    # �ץ饰��������
    $page_body =~ s/{{((.|\s)+?)}}//g;

    # ���Ф�
    $page_body =~ s/^!{1,3}//mg;
    # ����
    $page_body =~ s/^\*{1,3}//mg;
    # �ֹ��դ�����
    $page_body =~ s/^\+{1,3}//mg;
    # ��ʿ��
    $page_body =~ s/^-{4}$//mg;
    # ����
    $page_body =~ s/^""//mg;
    # PRE
    $page_body =~ s/^(\s|\t)//mg;

    # ���Ԥ����
    $page_body =~ s/^\n+//g;
    $page_body =~ s/\n/ /g;

	return $page_body;
}

#==============================================================================
# ���̥ڡ����˴ؤ���ץ饰�������Ѿ�������
#==============================================================================
#	���̥ڡ����Ǥ����Ѿ���������������ΤǤϤʤ�
#	����å���ե����벽���ƹ�®������Τ��ɤ����⡣
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
#	mod_rewrite �б���
#	$uri = './';

	$feed_uri = $uri . "?action=".$feedtype;
	if($group ne ''){
		$feed_uri .= "&amp;group=".$group;
		$group = ' '.$group;
	}

	##	Auto-Discovery �ν���
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

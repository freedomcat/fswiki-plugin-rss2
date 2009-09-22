###############################################################################
#
#	Feedが自動生成するキャッシュファイルを管理画面から削除します。
#
###############################################################################
package plugin::rss2::AdminFeedChche;
use strict;
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
sub do_action {
	my $self = shift;
	my $wiki = shift;
	my $cgi  = $wiki->get_CGI();
	my $buf;

	$wiki->set_title("RSS Feed用キャッシュの削除");
	$buf .= $self->_get_cache_list($wiki);
	if($cgi->param('delete') ne ''){
		$buf .= $self->_delete_ok($wiki);
	}else{
		$buf .= $self->_delete_check($wiki);
	}
	return $buf;
#	$wiki->redirectURL( $wiki->create_url({action => "LOGIN"}) );
}

sub _get_cache_list {
	my $self = shift;
	my $wiki = shift;

	my $buf;
	my @files = $self->list_file($wiki->config('log_dir'));
	foreach (@files){
		if($_ =~ /^feed_(.*)\.rss$/){
			#unlink($wiki->config('log_dir')."/".$_);
			$buf .= "<li>".&Util::url_decode($1)."</li>\n";
		}
	}
	return "<h2>RSS Feed用にキャッシュされたファイル</h2>\n".
		"<ul>".$buf."</ul>\n";
}

sub _delete_check {
	my ($self,$wiki) = @_;

	return <<"__HTML__";
<h2>RSS Feed用キャッシュファイルの削除</h2>
<p>feedプラグインで自動生成された全てのキャッシュファイルを削除します。</p>
<p>Wikiページにグループ化していた Feedを廃止した場合などにご利用下さい。</p>

<form class="admin" action="@{[$wiki->create_url()]}">
<feildset>
<legend>RSS Feed用キャッシュの削除</legend>
<p>rss2プラグインで自動生成されるキャッシュファイルを削除してよろしいですか？</p>
</feildset>
<p><input type="submit" name="delete" value="削除する">
<input type="hidden" name="action" value="REFRESH_FEED"></p>
</form>
__HTML__



}

sub _delete_ok {
	my $self = shift;
	my $wiki = shift;

	my @files = $self->list_file($wiki->config('log_dir'));
	foreach (@files){
		if($_ =~ /^feed_(.*)\.rss$/){
			unlink($wiki->config('log_dir')."/".$_);
		}
	}
	return <<"__HTML__";
<h2>RSS Feed用キャッシュファイルの削除</h2>
<p>全てのRSS Feed用キャッシュファイルを削除しました。</p>
__HTML__

}

sub list_file {
	my $self = shift;
	my $dir  = shift;
	my @list = ();
	opendir(DIR, $dir) or die $!;
	while(my $entry = readdir(DIR)) {
		my $type = -d $dir."/$entry" ? "dir" : "file";
		if($type eq "file"){
			push(@list,$entry);
		}
	}
	closedir(DIR);
	return sort(@list);
}

1;

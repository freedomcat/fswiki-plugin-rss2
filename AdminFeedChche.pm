###############################################################################
#
#	Feed����ư�������륭��å���ե������������̤��������ޤ���
#
###############################################################################
package plugin::rss2::AdminFeedChche;
use strict;
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
sub do_action {
	my $self = shift;
	my $wiki = shift;
	my $cgi  = $wiki->get_CGI();
	my $buf;

	$wiki->set_title("RSS Feed�ѥ���å���κ��");
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
	return "<h2>RSS Feed�Ѥ˥���å��夵�줿�ե�����</h2>\n".
		"<ul>".$buf."</ul>\n";
}

sub _delete_check {
	my ($self,$wiki) = @_;

	return <<"__HTML__";
<h2>RSS Feed�ѥ���å���ե�����κ��</h2>
<p>feed�ץ饰����Ǽ�ư�������줿���ƤΥ���å���ե�����������ޤ���</p>
<p>Wiki�ڡ����˥��롼�ײ����Ƥ��� Feed���ѻߤ������ʤɤˤ����Ѳ�������</p>

<form class="admin" action="@{[$wiki->create_url()]}">
<feildset>
<legend>RSS Feed�ѥ���å���κ��</legend>
<p>rss2�ץ饰����Ǽ�ư��������륭��å���ե�����������Ƥ�����Ǥ�����</p>
</feildset>
<p><input type="submit" name="delete" value="�������">
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
<h2>RSS Feed�ѥ���å���ե�����κ��</h2>
<p>���Ƥ�RSS Feed�ѥ���å���ե�����������ޤ�����</p>
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

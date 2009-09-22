############################################################
#
# RSS(RSS1.0,RSS2.0,Atom0.3)関連プラグイン
#
############################################################
package plugin::rss2::Install;
use strict;

sub install {
	my $wiki = shift;

	# メニューに追加
	$wiki->add_menu("RSS10",$wiki->create_url({ action=>"RSS10" }),50);
	$wiki->add_menu("RSS20",$wiki->create_url({ action=>"RSS20" }),50);
	$wiki->add_menu("ATOM" ,$wiki->create_url({ action=>"ATOM" }),50);

	# アクションハンドラ
	$wiki->add_handler("RSS10" ,"plugin::rss2::Feed");
	$wiki->add_handler("RSS20" ,"plugin::rss2::Feed");
	$wiki->add_handler("ATOM"  ,"plugin::rss2::Feed");

	# RSS auto-discovery 出力
	$wiki->add_hook("initialize" ,"plugin::rss2::Feed");
	$wiki->add_hook("save_after" ,"plugin::rss2::Feed");
	$wiki->add_hook("delete"     ,"plugin::rss2::Feed");

	# RSS Feedを出力
	$wiki->add_inline_plugin("feed" ,"plugin::rss2::Feed" ,"WIKI");

	# Aggregater（簡易版）
	$wiki->add_paragraph_plugin("rss" ,"plugin::rss2::Aggregater" ,"HTML");

	$wiki->add_user_menu("Feed用キャッシュの削除" ,$wiki->create_url({action=>"REFRESH_FEED"}) ,"100",
							"rss2プラグインで自動生成するFeed用キャッシュを削除します。");
	$wiki->add_user_handler("REFRESH_FEED" ,"plugin::rss2::AdminFeedChche");

}

1;

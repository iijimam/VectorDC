Class Test.DCTool Extends %RegisteredObject
{

ClassMethod CollectDCContentsUrl(pUrl As %String) As %Status
{
 set status = $$$OK
 kill ^||dcurls,^||dccontents
 set reader=##class(%XML.Reader).%New()
 set httprequest=##class(%Net.HttpRequest).%New()
 // MYSSL should be set up
 set httprequest.SSLConfiguration="test"
 //pUrl = "https://jp.community.intersystems.com/sitemap.xml"
 set status=reader.OpenURL(pUrl,,httprequest)
 
 set doc = reader.Document
 // urlset
 set status = doc.MoveToFirstChild(1)
 // url
 set status = doc.MoveToFirstChild(1)
 set count = 0
 for {
	 // loc
	 set status = doc.MoveToFirstChild(1)
	 // text = url
	 kill text,Unescapetitle
	 set status = doc.GetText(.text)
	 if text [ "/post" {
		set title = $piece(text,"post/",2)
		set Unescapetitle=##class(%CSP.Page).UnescapeURL(title)
		set ^||dccontents($increment(count)) = text
		set ^||dcurls(Unescapetitle)=text
	 }	 
	 // url
	 set status = doc.MoveToParent(1)
	 // next url
	 set status = doc.MoveToNextSibling(1)
	 if 'status quit	 
 }
 set ^||dccontents = count
 quit status
}

ClassMethod BuildDCContentsDB() As %Status
{
 set status = $$$OK
 
 if '$data(^||dccontents) {
	 write "contents url not setup",!
	 write "run ##class(DC.Tools).CollectDCContentsUrl() first",!
	 quit $$$OK
 }
 
 set start = $piece($zts,",",2)
 do ##class(Test.DCTopic).%KillExtent()
 
 write "total # of contents = ",^||dccontents,!

 for i= 1:1:^||dccontents {
	 set url = $get(^||dccontents(i))
	 set protocol = $piece(url,":")
	 set https = $select(protocol="https":1,1:0)
	 set server = $piece(url,"/",3)
	 set httprequest = ##class(%Net.HttpRequest).%New()
	 set httprequest.Server = server
	 set httprequest.Port = 80
	 if https set httprequest.Port = 443
	 set httprequest.Https = https
	 set httprequest.SSLConfiguration = "test"
	 set unescapeurl=##class(%CSP.Page).UnescapeURL(url)
	 set status = httprequest.Get(unescapeurl)
	 set statuscode = httprequest.HttpResponse.StatusCode
	 
	 if statuscode = 200 {
		 write "number ",i, " is processing",!
		 set textstream = httprequest.HttpResponse.Data
		 set length = 1400000
		 set textdata = textstream.Read(.length,.status)
		 set contentdb = ##class(Test.DCTopic).%New()
		 //set contentdb=##class(Test.DCTopic).%OpenId(135)
		 set contentdb.url = unescapeurl
		 set title = $piece(url,"post/",2)
		 set contentdb.Title = ##class(%CSP.Page).UnescapeURL(title)
		 set contentdb.Text = ##class(%CSP.Page).UnescapeHTML(textdata)
		 set contentdb.Length=$length(contentdb.Text)
		 set status = contentdb.%Save()
	 }
 } 
 set end = $piece($zts,",",2)
 write "elapsed time = ",end - start,!
 kill ^||dccontents
 quit status
}

ClassMethod Diff(url As %String = "https://jp.community.intersystems.com/sitemap.xml") As %Status
{
	#dim ex As %Exception.AbstractException
	set status=$$$OK
	try {
		//現在公開のURLが取れる ^||dccontents(cn)=dcurl と ^||dcurls(title)=dcurl
		set status=..CollectDCContentsUrl(url)

		//ありなし確認
		set title=""
		for {
			kill dcurl
			set title=$Order(^||dcurls(title),1,dcurl)
			if title=""  { 
				quit
			}
			if ##class(Test.DCTopic).TitleIdxExists(title)=0 {
				write "存在しないタイトル>> ",title,"-",dcurl,!
				set protocol = $piece(dcurl,":")
				set https = $select(protocol="https":1,1:0)
				set server = $piece(dcurl,"/",3)
				set httprequest = ##class(%Net.HttpRequest).%New()
				set httprequest.Server = server
				set httprequest.Port = 80
				if https set httprequest.Port = 443
				set httprequest.Https = https
				set httprequest.SSLConfiguration = "test"
				set status = httprequest.Get(dcurl)
				set statuscode = httprequest.HttpResponse.StatusCode
	 			if statuscode'=200 {
					quit
				}
				write "url ",dcurl, " is processing",!
				set textstream = httprequest.HttpResponse.Data
				set length = 1400000
				set textdata = textstream.Read(.length,.status)
				set contentdb = ##class(Test.DCTopic).%New()
				set contentdb.url = ##class(%CSP.Page).UnescapeURL(dcurl)
				set title = $piece(dcurl,"post/",2)
				set contentdb.Title = ##class(%CSP.Page).UnescapeURL(title)
				set contentdb.Text = ##class(%CSP.Page).UnescapeHTML(textdata)
				set contentdb.Length=$length(contentdb.Text)
				set status = contentdb.%Save()
				write "Title=",contentdb.Title," ID = ",contentdb.%Id(),!!
				if '$Data(^||difffirstid) {
					set ^||difffirstid=contentdb.%Id()
				}
			}
		}
	}
	catch ex {
			set status=ex.AsStatus()
		}
	return status
}

ClassMethod CopyData(flg As %Integer = 0)
{
	set start=$ZH
	set sql1="select ID,Text2,Title,url from Test.DCTopic"
	if flg=0 {
		/*EMBEDDING型を使った場合
		TextVector EMBEDDING('my-sentenceTransformer-config','Text2') と定義していると
		Text2に値を入れる→Text2のEmbedding後 TextVectorに値を登録してくれる　便利
		*/
		set sql2="insert into EmbeddingTest.DCTopic (Text2,Title,url) VALUES(?,?,?)"
	}
	elseif flg=1 {
		/*SentenceTransformersを使ったとき
		フィールド 'EmbeddingTest.DCTopic.TextVector' (値 'D0E913C443D34BC6ADA754BD3FA334FF@$vector') の妥当性検証が失敗しました
		と出たので、TextVectorの型をEMBEDDINGからVECTORに変更したらうまくいった
		カラムの定義：TextVector VECTOR(DOUBLE,384)
		*/
		set sql2="insert into EmbeddingTest.DCTopic (Text2,Title,url,TextVector) VALUES(?,?,?,TO_VECTOR(EMBEDDING(?,'my-sentenceTransformer-config'),DOUBLE,384))"
	}
	set stmt1=##class(%SQL.Statement).%New()
	set st=stmt1.%Prepare(sql1)
	set rset=stmt1.%Execute()
	
	set stmt2=##class(%SQL.Statement).%New()
	set st=stmt2.%Prepare(sql2)
	set i=0
	if flg=0 {
		while rset.%Next() {
			set rset2=stmt2.%Execute(rset.Text2,rset.Title,rset.url)
			set i=i+1
			write:$Extract(i,*)=0 i,"件処理しました",!
		}
	}
	elseif flg=1 {
		while rset.%Next() {
			set rset2=stmt2.%Execute(rset.Text2,rset.Title,rset.url,rset.Text2)
			set i=i+1
			write:$Extract(i,*)=0 i,"件処理しました",!
		}
	}
	set end=$ZH
	write "処理時間：",end-start,!
}

}

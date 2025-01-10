Class Test.DCTopic Extends %Persistent
{

Property Text As %String(MAXLEN = 3000000);

Property Text2 As %String(MAXLEN = 3000000);

Property url As %String(MAXLEN = 1000);

Property Title As %String(MAXLEN = 1000);

Property TextVector As %Vector(DATATYPE = "DOUBLE", LEN = 384);

Property Length As %Integer;

Index LengthIdx On Length;

Index TitleIdx On Title;

Index urlIdx On url;

// Index TextIndex On (Text) As %iFind.Index.Basic(INDEXOPTION = 0, LANGUAGE = "ja", LOWER = 1);

ClassMethod translate(in As %String) As %String(MAXLEN=300000)
{
    quit $TRANSLATE(in," '[]")
}

/// 引数：全件実行する場合はデフォルトの1、指定ID以降を実行する場合は第１引数０、第2引数に開始ID指定
ClassMethod UpdateNonTagText(all As %Boolean = 1, id As %Integer = "")
{
    if all=1 {
        set rset1=##class(%SQL.Statement).%ExecDirect(.stmtdirect,"select ID,Text from Test.DCTopic")
    }
    else {
        set sql="select ID,Text from Test.DCTopic where ID>"_(id-1)
        set rset1=##class(%SQL.Statement).%ExecDirect(.stmtdirect,sql) 
    }
    set stmt=##class(%SQL.Statement).%New()
    set status=stmt.%Prepare("Update Test.DCTopic set Text2=? where ID=?")

    while rset1.%Next() {
        #; タイトル以降を取る
        set intext=$piece(rset1.Text,"<h1 class=""page-header""",2)
        if intext [ "id=""page-title"">" {
            set intext=$piece(intext,"id=""page-title""",2)
        }
        if intext [ "id=""page-title"" itemprop=""headline"">" {
            set intext=$piece(intext,"id=""page-title"" itemprop=""headline"">",2)
        }
        if intext [	"id=""page-title"" itemprop=""name"">" {
           set intext=$piece(intext,"id=""page-title"" itemprop=""name"">",2) 
        }
        set removehtml=##class(Test.DCTopic).RemoveTags(intext)
        #; フッター削除
        set footer1="TEAMフォロー"
        set removehtml=$piece(removehtml,footer1,1)
        set footer2="STAFFフォロー"
        if removehtml [ footer2 {
            set removehtml=$piece(removehtml,footer2,1)
        }
        set footer3="プライバシーと規約保証"
        if removehtml [ footer3 {
            set removehtml=$piece(removehtml,footer3,1)
        }
        set footer4=".フォロー"
        if removehtml [ footer4 {
            set removehtml=$piece(removehtml,footer4,1)
        }
        // 先頭文字が>なら削除
        if $extract(removehtml,1)= ">" {
            set removehtml=$Extract(removehtml,2,*)
        }
        set upresult=stmt.%Execute(removehtml,rset1.%Get("ID"))
        write rset1.%Get("ID"),"-"
    }
}

/// 引数：全件実行する場合はデフォルトの1、指定ID以降を実行する場合は第１引数０、第2引数に開始ID指定
ClassMethod storeVectore(all As %Boolean = 1, id As %Integer = "") [ Language = python ]
{
    import iris
    import time
    start = time.time()  # 現在時刻（処理開始前）を取得

    if all==1 :
        stmt1=iris.sql.prepare("select ID,Text2 from Test.DCTopic")
    else :
        sql="select ID,Text2 from Test.DCTopic where ID > "+str(id-1)
        stmt1=iris.sql.prepare(sql)
    rset=stmt1.execute()
    #stmt2=iris.sql.prepare("Update Test.DCTopic set TextVector2=TO_VECTOR(?) where ID=?")
    stmt2=iris.sql.prepare("Update Test.DCTopic set TextVector=TO_VECTOR(?,DOUBLE, 384) where ID=?")
    for cn,reco in enumerate(rset):
        print(cn)
        vectortext=iris.cls("Test.DCTopic").getVector(reco[1])
        #print(vectortext)
        stmt2.execute(vectortext,reco[0])

    end = time.time()  # 現在時刻（処理完了後）を取得
    time_diff = end - start  # 処理完了後の時刻から処理開始前の時刻を減算する
    print(f"ベクトル化にかかった時間>> {time_diff}")  # 処理にかかった時間データを使用
}

ClassMethod getVector(text As %String(MAXLEN=300000)) [ Language = python ]
{
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer('stsb-xlm-r-multilingual')
    embeddings = model.encode(text,normalize_embeddings=True)
    # convert the embeddings to a string
    embeddings_list = [str(embedding.tolist()) for embedding in embeddings]
    embedstr=str(embeddings_list)
    return embedstr.replace('\'','')
}

ClassMethod Search(question As %String = "IRISとPythonの組み合わせ方")
{
    set start=$ZH
    set questionv=..getVector(question)
    //set sql="SELECT TOP 10 ID,Title,url,TextVector from Test.DCTopic Order by VECTOR_DOT_PRODUCT(TextVector, TO_VECTOR(?, DOUBLE, 384)) Desc"
    set sql="SELECT TOP 10 VECTOR_DOT_PRODUCT(TextVector, TO_VECTOR(?, DOUBLE, 384)) as sim, Title,url from Test.DCTopic Order By sim Desc"
    set stmt=##class(%SQL.Statement).%New()
    set status=stmt.%Prepare(sql)
    if $$$ISERR(status) {
        do $system.OBJ.DisplayError(status)
        return
    }
    set rset=stmt.%Execute(questionv)
    while rset.%Next() {
        write rset.%Get("sim")," - ",rset.Title," - ",rset.url,!
        //write rset.ID,"-",rset.Title," - ",rset.url,!
    }
    set end=$ZH
    write "検索時間：",end-start,!
}

ClassMethod Search2(question As %String = "IRISとPythonの組み合わせ方")
{
    set start=$ZH
    set questionv=..getVector(question)
    //set sql="SELECT TOP 10 ID,Title,url,TextVector from Test.DCTopic Order by VECTOR_DOT_PRODUCT(TextVector, TO_VECTOR(?, DOUBLE, 384)) Desc"
    set sql="SELECT TOP 10 VECTOR_COSINE(TextVector, TO_VECTOR(?, DOUBLE, 384)) as sim, Title,url from EmbeddingTest.DCTopic Order By sim Desc"
    set stmt=##class(%SQL.Statement).%New()
    set status=stmt.%Prepare(sql)
    if $$$ISERR(status) {
        do $system.OBJ.DisplayError(status)
        return
    }
    set rset=stmt.%Execute(questionv)
    while rset.%Next() {
        write rset.%Get("sim")," - ",rset.Title," - ",rset.url,!
        //write rset.ID,"-",rset.Title," - ",rset.url,!
    }
    set end=$ZH
    write "検索時間：",end-start,!
}

ClassMethod RemoveTags(intext As %String(MAXLEN=300000)) As %String(MAXLEN=300000) [ Language = python ]
{
from bs4 import BeautifulSoup, Comment
def preprocessing(soup):
    # コメントタグの除去
    for comment in soup(text=lambda x: isinstance(x, Comment)):
        comment.extract()

    # scriptタグの除去
    for script in soup.find_all('script', src=False):
        script.decompose()

    # styleタグの除去
    for style in soup.find_all('style', src=False):
        style.decompose()

    return soup

soup = BeautifulSoup(intext, 'lxml')
soup2 = preprocessing(soup)
return soup2.text
}

Storage Default
{
<Data name="DCTopicDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Text</Value>
</Value>
<Value name="3">
<Value>Text2</Value>
</Value>
<Value name="4">
<Value>url</Value>
</Value>
<Value name="5">
<Value>Title</Value>
</Value>
<Value name="6">
<Value>TextVector</Value>
</Value>
<Value name="7">
<Value>TextVector2</Value>
</Value>
<Value name="8">
<Value>Length</Value>
</Value>
</Data>
<DataLocation>^Test.DCTopicD</DataLocation>
<DefaultData>DCTopicDefaultData</DefaultData>
<IdLocation>^Test.DCTopicD</IdLocation>
<IndexLocation>^Test.DCTopicI</IndexLocation>
<StreamLocation>^Test.DCTopicS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

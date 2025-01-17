# DCの記事を使ってVectorSearchできるコンテナ(2025.1版)

2025/1/8時点のDC登録記事 1547件をベクトル化しデータを用意しています。

DC記事の取り込みまでのステップは佐藤大先生のサンプルコードを使っています。
[ありがたいコード](https://github.com/Intersystems-jp/dcfulltextsearch/blob/main/src/DC/Tools.cls)


## コンテナの中身

製品版IRIS／WebGateway用イメージを使用しているため、iris.keyが必要です。

コンテナではUSERネームスペースを使用しています。

DCから記事を読み込み、ベクトル化した状態のテーブル **[Test.DCTopic](/src/Test/DCTopic.cls)** を用意しています。

カラム名|内容
--|--
Text|オリジナルテキスト（HTMLタグ入り）
Text2|HTMLタグやヘッダ、フッターを取り除いたもの（まだ修正の余地あり）
url|DC記事のURL
Title|DC記事のタイトル
Length|Textの長さ
TextVector|Text2のベクトル


>ベクトル化したテーブルデータのエクスポートファイルもありますが大きいためリポジトリに置けませんでした。

## 検索方法

[Test.DCTopicクラス](/src/Test/DCTopic.cls)の[Search()](/src/Test/DCTopic.cls#L120)メソッドを使ってください。

第1引数に検索キーを指定できます。（Top 10件出します）

例（引数を指定しないと「IRISとPythonの組み合わせ方」をキーに指定して検索します）
```
docker exec -it iriscon1 bash
iris session iris
do ##class(Test.DCTopic).Search("データベースの配置について")
```
以下、結果
```USER>do ##class(Test.DCTopic).Search("データベースの配置について")
.33479103655693770447 - deepsee-データベース、ネームスペース、マッピング（25） - https://jp.community.intersystems.com/post/deepsee-データベース、ネームスペース、マッピング（25）
.32879918696159737834 - deepsee-データベース、ネームスペース、マッピング（45） - https://jp.community.intersystems.com/post/deepsee-データベース、ネームスペース、マッピング（45）
.32092957097771912522 - データ変更の追跡-監査ログ（12） - https://jp.community.intersystems.com/post/データ変更の追跡-監査ログ（12）
.31992650855301113521 - deepsee-データベース、ネームスペース、マッピング（35） - https://jp.community.intersystems.com/post/deepsee-データベース、ネームスペース、マッピング（35）
.31818959867246782158 - tableau-と-power-bi-での開発方法 - https://jp.community.intersystems.com/post/tableau-と-power-bi-での開発方法
.31701196784144003437 - rdbにおけるentity-attribute-valueeavモデル。-グローバル変数はテーブルでエミュレートする必要がありますか？-パート1 - https://jp.community.intersystems.com/post/rdbにおけるentity-attribute-valueeavモデル。-グローバル変数はテーブルでエミュレートする必要がありますか？-パート1
.31522301702223026742 - sequence-関数について - https://jp.community.intersystems.com/post/sequence-関数について
.30975993633032911089 - list-のフォーマットとdynamicarray-、dynamicobject-クラス - https://jp.community.intersystems.com/post/list-のフォーマットとdynamicarray-、dynamicobject-クラス
.30830816279098438581 - データベース-xxxenstemp、xxxsecondary-について - https://jp.community.intersystems.com/post/データベース-xxxenstemp、xxxsecondary-について
.30702276544903056576 - 現在実行中のコードの位置どの行を実行中かを知る方法 - https://jp.community.intersystems.com/post/現在実行中のコードの位置どの行を実行中かを知る方法
検索時間：3.853072
```

## 1/8以降の差分を取る方法

### 1. テーブルに存在する記事なのかチェック

以下実行で、^||dcurls(title)=dcurl　が設定される
```
iris session iris
do ##class(Test.DCTool).Diff()
```
現在の Test.DCTopicテーブルに存在しないタイトルの情報が登録されると対象IDと内容を表示。

^||difffirstid にベクトル化しないといけない最初のレコードIDが設定されます。

### 2. 差分チェックで発券した最初のレコードID以降のデータのHTMLタグの削除実行

^||difffirstidをキーに以下実行（第1引数に0を指定します。デフォルト設定:1の場合、テーブル全件処理します）。

```
set status=##class(Test.DCTopic).UpdateNonTagText(0,^||difffirstid)
```

### 3. 対象レコードのベクトル化

^||difffirstidをキーに以下実行（第1引数に0を指定します。デフォルト設定:1の場合、テーブル全件処理します）。
```
do ##class(Test.DCTopic).storeVectore(0,||difffirstid)
```

## コンテナ開始手順

### 1. コンテナビルド

**※ビルド前にIRISとWebGateway用イメージを用意し、[Dockerfile](/Dockerfile)と[docker-compose.yml](/docker-compose.yml)のイメージ：タグ名の指定を適宜変更してください。また、iris.keyをクローンしたディレクトリ直下に配置してから実行してください**

```
docker compose build
```
または
```
docker-compose build
```
### 2. コンテナUp

```
docker compose up -d
```
または
```
docker-compose up -d
```

### 3. コンテナ停止

```
docker compose stop
```
または
```
docker-compose stop
```
### 4. コンテナ破棄

```
docker compose down
```
または
```
docker-compose down
```

## DC取り込みからベクトル化までの流れ（使用してる処理）

### 1. PPGに読み込み対象URLをセットする

```
docker exec -it iriscon1 bash
iris session iris
set url="https://jp.community.intersystems.com/sitemap.xml"
write ##class(Test.DCTool).CollectDCContentsUrl(url)
```
実行後 ^||dccontentsグローバルができる（添え字カウント、右辺にURL）

### 2. 記事の内容取り込み

^||dccontentsを読みながらHTTPのGETで記事内容取得
```
do ##class(Test.DCTool).BuildDCContentsDB()
```
※ 2025年1月8日時点　1547件：elapsed time = 2370.834876979

ここで、Test.DCTopicテーブルの以下カラムが設定されます。

- url
- Title
- Text

### 3. HTMLタグなどを取り除く

Textカラムからベクトル化するのに不要なタグ類を取り除きます。

この処理にBeautifulSoup4とlxmlが必要なため、コンテナではビルド時に員スールしています。

```
do ##class(Test.DCTopic).UpdateNonTagText()
```
ここで、Text2カラムがセットされます。

### 4. Text2のベクトル化

**1/8時点の件数（1547件）で4771.130125284195秒（約80分）かかります。**

全件ベクトル化
```
do ##class(Test.DCTopic).storeVectore()
```

# Embedding typeのカラムを作成する

Embeddingの構成設定は、SQL文を実行したネームスペースに保存される

## Embedding configurationを作成する：OpenAI編
https://docs.intersystems.com/iris20251/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_vecsearch#GSQL_vecsearch_insembed_embedconfig

**Docのまんまで動く**

```
INSERT INTO %Embedding.Config (Name, Configuration, EmbeddingClass, VectorLength, Description)
  VALUES ('my-opanai-config', 
          '{"apiKey":"<api key>", 
            "sslConfig": "test", 
            "modelName": "text-embedding-3-small"}',
          '%Embedding.OpenAI', 
          1536,  
          'a small embedding model provided by OpenAI') 
```

Test.DCTopicのText2,url,Titleを持つテーブルを新規で作成

```
CREATE TABLE EmbeddingTest.DCTopic (
  Text2 VARCHAR(3000000),
  url VARCHAR(1000),
  Title VARCHAR(1000),
  TextVector EMBEDDING('my-opanai-config','Text2')
)
```
Test.DCTopic.clsのText2,url,TitleをTest.EmbeddingTest.DCTopicにコピーする

```
do ##class(Test.DCTool).CopyData()
```
Text2をInsertすると自動的にEmbeddingを行ってTextVectorに入れてくれる
(OpenAIを使うので途中で強制終了して以下実行してみる 最初18件までのデータで試す)

```
SELECT TOP 5 ID,Title,url FROM EmbeddingTest.DCTopic
    ORDER BY VECTOR_DOT_PRODUCT(TextVector, 
                              EMBEDDING(?)) DESC
```

例）
```
SELECT TOP 5 ID,Title,url FROM EmbeddingTest.DCTopic
    ORDER BY VECTOR_DOT_PRODUCT(TextVector, 
                              EMBEDDING('リレーショナルDBとの違い')) DESC

```

## Embedding configurationを作成する：SentenceTransform編

事前にsentence_transformersをpipしておく必要あり

指定するConfigurationの内容は、%Embedding.SentenceTransformersのIsValidConfig()の説明文にあり

>Validates %Embedding.Config's Configuration property. { "modelName" : , "hfCachePath" : , "hfToken" : , "checkTokenCount": , "maxTokens": "pythonPath": } Also checks if the python package 'sentence_transformers' is installed.

modelNameだけだと hfCachePathがないと怒られる。

クラス定義の説明文に以下あり
> "modelName" : <Name of sentence_transformers model>,
> "hfCachePath" : <Path to cache folder where models will be downloaded>, 
> "hfToken" : <Optional token to access gated hugging face models>, 
> "checkTokenCount": <Optional, whether to check token count of input>, 
> "maxTokens": <Optional, token threshold for input>
> "pythonPath": <Optional, path to use to retrieve python packages>}

hfCachePathは、https://note.com/ozzybot8/n/n21b84ccb0b42　を参考に調査

https://usconfluence.iscinternal.com/pages/viewpage.action?pageId=858357014


```
INSERT INTO %Embedding.Config (Name, Configuration, EmbeddingClass, VectorLength, Description)
  VALUES ('my-sentenceTransformer-config', 
          '{"modelName": "sentence-transformers/stsb-xlm-r-multilingual",
          "hfCachePath": "/home/irisowner/.cache/huggingface/hub/models--sentence-transformers--stsb-xlm-r-multilingual"}',
          '%Embedding.SentenceTransformers', 
          384,  
          'a multi language model provided by SentenceTransformers') 
```
Test.DCTopicのText2,url,Titleを持つテーブルを新規で作成

```
CREATE TABLE EmbeddingTest.DCTopic (
  Text2 VARCHAR(3000000),
  url VARCHAR(1000),
  Title VARCHAR(1000),
  TextVector EMBEDDING('my-sentenceTransformer-config','Text2')
)
```

この定義で作成し、INSERTでテストすると、これが出てる
```
USER>w rset2.%Message
フィールド 'EmbeddingTest.DCTopic.TextVector' (値 'D0E913C443D34BC6ADA754BD3FA334FF@$vector') の妥当性検証が失敗しました
```

ということで、EMBEDDINGではなく、VECTOR型で定義する
（https://usconfluence.iscinternal.com/pages/viewpage.action?pageId=858357014　の下の方にあり）

```
CREATE TABLE EmbeddingTest.DCTopic (
  Text2 VARCHAR(3000000),
  url VARCHAR(1000),
  Title VARCHAR(1000),
  TextVector VECTOR(DOUBLE,384)
)
```

EMBEDDINGのタイプを使わないので、Text2に値を入れると勝手にTextVectorに入るわけではない。
なので、VECTOR型の入れ方通り　TO_VECTOR(?,DOUBLE, 384)　が必要。
EMBEDDINGは構成したモデルを使ってEMBEDDING関数が使えるので長いけど以下のようにかける。（INSERTの例）

```
insert into EmbeddingTest.DCTopic (TextVector) VALUES(TO_VECTOR(EMBEDDING(?,'my-sentenceTransformer-config'),DOUBLE,384))
```


Test.DCTopic.clsのText2,url,TitleをTest.EmbeddingTest.DCTopicにコピーして実行してみる

```
do ##class(Test.DCTool).CopyData(1)
```
処理時間：9556.6206

Embedded Pythonで自分でSentenceTransformersのモデルにEmbeddingさせるほうが倍早い

ということで、検索テスト
```
docker exec -it iriscon1 bash
iris session iris
do ##class(Test.DCTopic).Search2("データベースの配置について")
```
自分でSentenceTransformersを使ったものと若干結果が違う。

Embeddingタイプを使うとき以下のnormalize_embeddings=Trueを指定する項目が見当たらないのでデフォルトのまま利用
そのせい？
```
embeddings = model.encode(text,normalize_embeddings=True)
```

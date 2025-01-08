ARG IMAGE=intersystems/iris:2025.1.0L.172.0
FROM $IMAGE

USER root
WORKDIR /opt/src
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/src
USER ${ISC_PACKAGE_MGRUSER}

# ビルド中に実行したいスクリプトがあるファイルをコンテナにコピーしています
COPY iris.script .
COPY requirements.txt .
COPY src .
#COPY data .
COPY iris.key ${ISC_PACKAGE_INSTALLDIR}/mgr/iris.key

# IRISを開始し、IRISにログインし、iris.scriptに記載のコマンドを実行しています
RUN iris start IRIS \
    && iris session IRIS < iris.script \
    && pip install -r requirements.txt --break-system-packages \
    && iris stop IRIS quietly
FROM openjdk:8-jdk-alpine
MAINTAINER Levon.yao <levon.yao@linksame.cn>, Linksame Team


# Patch APK Mirror to LINKSAME
RUN echo "http://mirrors.ustc.edu.cn/alpine/v3.3/main/" > /etc/apk/repositories

RUN apk add --no-cache gnupg
# see https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/KEYS
# see also "update.sh" (https://github.com/docker-library/tomcat/blob/master/update.sh)
ENV GPG_KEYS 05AB33110949707C93A279E3D3EFE6B686867BA6 07E48665A34DCAFAE522E5E6266191C37C037D42 47309207D818FFD8DCD3F83F1931D684307A10A5 541FBE7D8F78B25E055DDEE13C370389288584E7 61B832AC2F1C5A90F0F9B00A1C506407564C17A3 713DA88BE50911535FE716F5208B0AB1D63011C7 79F7026C690BAA50B92CD8B66A3AD3F4F22C4FED 9BA44C2621385CB966EBA586F72C284D731FABEE A27677289986DB50844682F8ACB77FC2E86E29AC A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 F3A04C595DB5B6A5F1ECA43E3B7BBB100D811BBE F7DA48BB64BCB84ECBA7EE6935CD23C10D498E23
RUN set -ex; \
	for key in $GPG_KEYS; do \
		gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done

ENV MAVEN_HOME=/usr/share/maven
RUN apk --no-cache add ca-certificates openssl &&  update-ca-certificates
RUN cd /tmp \
     && wget https://archive.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz \
     && wget https://archive.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz.sha1 \
     && echo -e "$(cat apache-maven-3.3.9-bin.tar.gz.sha1)  apache-maven-3.3.9-bin.tar.gz" | sha1sum -c - \
     && tar zxf apache-maven-3.3.9-bin.tar.gz \
     && rm -rf apache-maven-3.3.9-bin.tar.gz \
     && rm -rf *.sha1 \
     && mv ./apache-maven-3.3.9 /usr/share/maven \
     && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV PATH /usr/local/bin:$PATH
ENV LANG C.UTF-8

     # install ca-certificates so that HTTPS works consistently
     # the other runtime dependencies for Python are installed later
     RUN apk add --no-cache ca-certificates

     ENV GPG_KEY 8417157EDBE73D9EAC1E539B126EB563A74B06BF
     ENV PYTHON_VERSION 2.6.9

     # if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
     ENV PYTHON_PIP_VERSION 9.0.1

     COPY python-2.6-internal-expat.patch /python-2.6-internal-expat.patch
     COPY python-2.6-posix-module.patch /python-2.6-posix-module.patch

     RUN set -ex \
         && apk add --no-cache --virtual .fetch-deps \
             openssl \
             gnupg \
             tar \
             xz \
         \
         && wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
         && wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
         && export GNUPGHOME="$(mktemp -d)" \
         && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
         && gpg --batch --verify python.tar.xz.asc python.tar.xz \
         && rm -r "$GNUPGHOME" python.tar.xz.asc \
         && mkdir -p /usr/src/python \
         && tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
         && rm python.tar.xz \
         \
         && apk add --no-cache --virtual .build-deps  \
             gcc \
             libc-dev \
             linux-headers \
             make \
             openssl \
             readline-dev \
             tcl-dev \
             tk \
             tk-dev \
             expat-dev \
             openssl-dev \
             zlib-dev \
             ncurses-dev \
             bzip2-dev \
             gdbm-dev \
             sqlite-dev \
             libffi-dev \
     # add build deps before removing fetch deps in case there's overlap
         && apk del .fetch-deps \
         \
         && cd /usr/src/python \
         && mv /python-2.6-internal-expat.patch python-2.6-internal-expat.patch \
         && mv /python-2.6-posix-module.patch python-2.6-posix-module.patch \
         && ls -la \
         && patch -p1 < python-2.6-internal-expat.patch \
         && patch -p1 < python-2.6-posix-module.patch \
         && ./configure --prefix=/usr \
         --enable-shared \
         --with-threads \
         --with-system-ffi \
         --enable-unicode=ucs4 \
         && make -j$(getconf _NPROCESSORS_ONLN) \
         && make install \
         && ln -s /usr/bin/python2.6 /usr/bin/python2 \
         \
             && wget -O /tmp/get-pip.py 'https://bootstrap.pypa.io/get-pip.py' \
             && python2 /tmp/get-pip.py "pip==$PYTHON_PIP_VERSION" \
             && rm /tmp/get-pip.py \
     # we use "--force-reinstall" for the case where the version of pip we're trying to install is the same as the version bundled with Python
     # ("Requirement already up-to-date: pip==8.1.2 in /usr/local/lib/python3.6/site-packages")
     # https://github.com/docker-library/python/pull/143#issuecomment-241032683
         && pip install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
     # then we use "pip list" to ensure we don't have more than one pip version installed
     # https://github.com/docker-library/python/pull/100
         && [ "$(pip list |tac|tac| awk -F '[ ()]+' '$1 == "pip" { print $2; exit }')" = "$PYTHON_PIP_VERSION" ] \
         \
         && find /usr/local -depth \
             \( \
                 \( -type d -a -name test -o -name tests \) \
                 -o \
                 \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
             \) -exec rm -rf '{}' + \
         && runDeps="$( \
             scanelf --needed --nobanner --recursive /usr/local \
                 | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
                 | sort -u \
                 | xargs -r apk info --installed \
                 | sort -u \
         )" \
         && apk add --virtual .python-rundeps $runDeps \
         && apk del .build-deps \
         && rm -rf /usr/src/python ~/.cache

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR
ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.5.14

# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
ENV TOMCAT_TGZ_URL https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
# not all the mirrors actually carry the .asc files :'(
ENV TOMCAT_ASC_URL https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz.asc


RUN set -x \
	\
	&& apk add --no-cache --virtual .fetch-deps \
		ca-certificates \
		tar \
		openssl \
	&& wget -O tomcat.tar.gz "$TOMCAT_TGZ_URL" \
	&& wget -O tomcat.tar.gz.asc "$TOMCAT_ASC_URL" \
	&& gpg --batch --verify tomcat.tar.gz.asc tomcat.tar.gz \
	&& tar -xvf tomcat.tar.gz --strip-components=1 \
	&& rm bin/*.bat \
	&& rm tomcat.tar.gz* \
	\
	&& nativeBuildDir="$(mktemp -d)" \
	&& tar -xvf bin/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1 \
	&& apk add --no-cache --virtual .native-build-deps \
		apr-dev \
		gcc \
		libc-dev \
		make \
		"openjdk${JAVA_VERSION%%[-~bu]*}"="$JAVA_ALPINE_VERSION" \
		openssl-dev \
	&& ( \
		export CATALINA_HOME="$PWD" \
		&& cd "$nativeBuildDir/native" \
		&& ./configure \
			--libdir="$TOMCAT_NATIVE_LIBDIR" \
			--prefix="$CATALINA_HOME" \
			--with-apr="$(which apr-1-config)" \
			--with-java-home="$(docker-java-home)" \
			--with-ssl=yes \
		&& make -j$(getconf _NPROCESSORS_ONLN) \
		&& make install \
	) \
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive "$TOMCAT_NATIVE_LIBDIR" \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .tomcat-native-rundeps $runDeps \
	&& apk del .fetch-deps .native-build-deps \
	&& rm -rf "$nativeBuildDir" \
	&& rm bin/tomcat-native.tar.gz

# verify Tomcat Native is working properly
RUN set -e \
	&& nativeLines="$(catalina.sh configtest 2>&1)" \
	&& nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" \
	&& nativeLines="$(echo "$nativeLines" | sort -u)" \
	&& if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2; then \
		echo >&2 "$nativeLines"; \
		exit 1; \
	fi

EXPOSE 8080
CMD ["catalina.sh", "run"]

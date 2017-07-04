FROM sunahwk2100/tomcat:8.7
MAINTAINER Levon.yao <levon.yao@linksame.cn>, Linksame Team

# Patch APK Mirror to LINKSAME
RUN echo "http://mirrors.ustc.edu.cn/alpine/v3.3/main/" > /etc/apk/repositories

COPY server.xml  /usr/local/tomcat/conf/

EXPOSE 80
CMD ["catalina.sh", "run"]

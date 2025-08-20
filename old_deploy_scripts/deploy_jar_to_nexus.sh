mvn org.apache.maven.plugins:maven-deploy-plugin:2.8.2:deploy-file \
 -DgroupId=com.alipay \
 -DartifactId=alipay-sdk-java \
 -Dversion=$1 \
 -DgeneratePom=true \
 -Dpackaging=jar \
 -DrepositoryId=thirdparty \
 -Durl=http://10.0.0.59:8081/nexus/content/repositories/thirdparty \
 -Dfile=$2 \
 -Dsources=$3 \

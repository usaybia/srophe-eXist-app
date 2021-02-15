# Specify the eXist-db image with preloaded data app as a base image
FROM ghcr.io/usaybia/usaybia-data:latest

# Exist autodeploy directory
ENV autodeploy=/exist/autodeploy/

# Grab remote .xar files and put them in autodeploy
ADD http://exist-db.org:8098/exist/apps/public-repo/public/shared-resources-0.4.2.xar ${autodeploy}
ADD http://exist-db.org:8098/exist/apps/public-repo/public/exist-sparql-0.1-SNAPSHOT.xar ${autodeploy}
# Need to check on the following, whether they are still needed and whether to deploy them here:
# ADD https://exist-db.org/exist/apps/public-repo/public/functx-1.0.xar ${autodeploy}
# ADD http://exist-db.org/exist/apps/public-repo/public/expath-crypto-exist-lib-0.6.xar ${autodeploy}

# Copy built eXist package to autodeploy 
COPY build/*.xar ${autodeploy}

# OPTIONAL: Copy custom conf.xml to WEB-INF.
COPY conf/conf.xml /exist/etc

#EXPOSE 8080 8443
EXPOSE 8080 8443

# Start eXist-db
CMD [ "java", "-jar", "start.jar", "jetty" ]

# Copyright (c) 2016-present Sonatype, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM registry.access.redhat.com/ubi8/ubi

LABEL name="Nexus Repository Manager" \
      maintainer="Sonatype <support@sonatype.com>" \
      vendor=Sonatype \
      version="3.38.0-01" \
      release="3.38.0" \
      url="https://sonatype.com" \
      summary="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      description="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      run="docker run -d --name NAME \
          -p 8081:8081 \
          IMAGE" \
      stop="docker stop NAME" \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image" \
      io.k8s.description="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      io.k8s.display-name="Nexus Repository Manager" \
      io.openshift.expose-services="8081:8081" \
      io.openshift.tags="Sonatype,Nexus,Repository Manager"

ARG NEXUS_VERSION=3.38.0-01
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz
ARG NEXUS_DOWNLOAD_SHA256_HASH=d7ee5e2d7233ac8cfd4e9cc1e97d88313d24d662509d446784be5a50f677cc6f

# configure nexus runtime
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=${SONATYPE_DIR}/nexus \
    NEXUS_DATA=/nexus-data \
    NEXUS_CONTEXT='' \
    SONATYPE_WORK=${SONATYPE_DIR}/sonatype-work \
    DOCKER_TYPE='3x-docker'

ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION="release-0.5.20210628-162332.70a6cb6"
ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL="https://github.com/sonatype/chef-nexus-repository-manager/releases/download/${NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION}/chef-nexus-repository-manager.tar.gz"

ADD solo.json.erb /var/chef/solo.json.erb

# Install using chef-solo
# Chef version locked to avoid needing to accept the EULA on behalf of whomever builds the image
RUN yum install -y --disableplugin=subscription-manager hostname procps \
    && curl -L https://omnitruck.chef.io/install.sh | bash -s -- -v 14.12.9 \
    && /opt/chef/embedded/bin/erb /var/chef/solo.json.erb > /var/chef/solo.json \
    && chef-solo \
       --recipe-url ${NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL} \
       --json-attributes /var/chef/solo.json \
    && rpm -qa *chef* | xargs rpm -e \
    && rm -rf /etc/chef \
    && rm -rf /opt/chefdk \
    && rm -rf /var/cache/yum \
    && rm -rf /var/chef \
    && yum clean all
    
# download and install openjdk 8
RUN curl -O https://vault.centos.org/8.3.2011/AppStream/x86_64/os/Packages/java-1.8.0-openjdk-headless-1.8.0.282.b08-2.el8_3.x86_64.rpm \
    && yum localinstall -y --disableplugin=subscription-manager java-1.8.0-openjdk-headless-1.8.0.282.b08-2.el8_3.x86_64.rpm \
    && rm -rf java-1.8.0-openjdk-headless-1.8.0.282.b08-2.el8_3.x86_64.rpm

VOLUME ${NEXUS_DATA}

EXPOSE 8081
USER nexus

ENV INSTALL4J_ADD_VM_PARAMS="-Xms2703m -Xmx2703m -XX:MaxDirectMemorySize=2703m -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

CMD ["sh", "-c", "${SONATYPE_DIR}/start-nexus-repository-manager.sh"]

FROM wso2/wso2am:4.7.0

LABEL maintainer="Saber Nciri <saber.nciri@esprim.tn>"
LABEL version="1.0.0"
LABEL description="WSO2 API Manager 4.7.0 - Custom image - Inetum Tunisie"
LABEL org.opencontainers.image.source="https://github.com/WSO2-Project/wso2-apim-app"

USER root

# Copy Admin Portal UI customizations
COPY ui-customization/admin/site/public/ \
     /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/admin/site/public/

# Copy Developer Portal UI customizations (uncomment when ready)
# COPY ui-customization/devportal/site/public/ \
#      /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/devportal/site/public/

# Copy custom deployment.toml (uncomment when ready)
# COPY conf/deployment.toml \
#      /home/wso2carbon/wso2am-4.7.0/repository/conf/deployment.toml

USER wso2carbon

EXPOSE 9443 8243 8280 9611 9711
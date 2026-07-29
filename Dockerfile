



FROM wso2/wso2am:4.7.0

LABEL maintainer="Saber Nciri <sab4r>"
LABEL version="1.0.0"
LABEL description="WSO2 API Manager 4.7.0 - Custom image - Inetum Tunisie"
LABEL org.opencontainers.image.source="https://github.com/WSO2-Project/wso2-apim-app"

USER root

# Copy custom deployment.toml (uncomment when ready)
# COPY conf/deployment.toml /home/wso2carbon/wso2am-4.7.0/repository/conf/deployment.toml

# Copy UI customizations (uncomment when ready)
# COPY ui-customization/devportal/dist/ \
#      /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/devportal/

 COPY ui-customization/admin/dist/ \
      /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/admin/

USER wso2carbon

EXPOSE 9443 8243 8280 9611 9711

#9443 → interface web (Publisher, DevPortal, Admin)
#8243 → Gateway HTTPS
#8280 → Gateway HTTP
#9611 et 9711 → ports de streaming des événements (analytics)
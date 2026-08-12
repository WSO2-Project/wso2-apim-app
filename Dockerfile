# ================================================================
# Stage 1: Extract the full, untouched webapps from the base image
# ================================================================
FROM wso2/wso2am:4.7.0 AS webapps-source

# ================================================================
# Stage 2: Build all 3 portals with overrides layered on top
# ================================================================
FROM node:22 AS ui-build

LABEL maintainer="Saber Nciri <saber.nciri@esprim.tn>"
LABEL version="1.0.0"
LABEL description="WSO2 API Manager 4.7.0 - Custom image - Inetum Tunisie"
LABEL org.opencontainers.image.source="https://github.com/WSO2-Project/wso2-apim-app"

WORKDIR /build/webapps

# --- 2a. Copy the original source tree from the base WSO2 image ---
COPY --from=webapps-source \
    /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/ \
    /build/webapps/

# --- 2b. Install monorepo dependencies ---
# npm install at root handles everything if npm workspaces are configured
RUN npm install

# lerna bootstrap fallback — runs only if the script exists (older WSO2 versions)
RUN if grep -q '"bootstrap"' package.json 2>/dev/null; then npm run bootstrap; fi

# --- 2c. Layer your override files on top of the source ---
# Only override/ comes from your app repo. source/ stays untouched.
COPY ui-customization/devportal/override/ /build/webapps/devportal/override/
COPY ui-customization/publisher/override/ /build/webapps/publisher/override/
COPY ui-customization/admin/override/     /build/webapps/admin/override/

# --- 2d. Production builds for all three portals ---
RUN cd /build/webapps/devportal && npm run build:prod
RUN cd /build/webapps/publisher && npm run build:prod
RUN cd /build/webapps/admin     && npm run build:prod

# ================================================================
# Stage 3: Final runtime image
# ================================================================
FROM wso2/wso2am:4.7.0

USER root

# --- Devportal artifacts ---
COPY --from=ui-build /build/webapps/devportal/site/public/dist/ \
     /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/devportal/site/public/dist/
COPY --from=ui-build /build/webapps/devportal/site/public/pages/index.jsp \
     /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/devportal/site/public/pages/index.jsp

# --- Publisher artifacts ---
COPY --from=ui-build /build/webapps/publisher/site/public/dist/ \
     /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/publisher/site/public/dist/
COPY --from=ui-build /build/webapps/publisher/site/public/pages/index.jsp \
     /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/publisher/site/public/pages/index.jsp

# --- Admin artifacts ---
COPY --from=ui-build /build/webapps/admin/site/public/dist/ \
     /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/admin/site/public/dist/
COPY --from=ui-build /build/webapps/admin/site/public/pages/index.jsp \
     /home/wso2carbon/wso2am-4.7.0/repository/deployment/server/webapps/admin/site/public/pages/index.jsp

USER wso2carbon

EXPOSE 9443 8243 8280 9611 9711
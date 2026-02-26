# -------------------------------------------------                                                             
# 1️⃣ Multi‑stage: bring in Tailscale binaries (unchanged)                                                       
# -------------------------------------------------                                                             
FROM tailscale/tailscale:stable AS tailscale                                                                    
                                                                                                             
# -------------------------------------------------                                                             
# 2️⃣ Base image for OpenClaw (Ubuntu Noble)                                                                     
# -------------------------------------------------                                                             
FROM ubuntu:noble                                                                                               
                                                                                                             
# Use bash for the shell                                                                                        
SHELL ["/bin/bash", "-o", "pipe                                                                                 
SHELL ["/bin/bash", "-o", "pipefail", "-c"]                                                                     
                                                                                                             
# Copy Tailscale binaries from the stage above                                                                  
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/real_tailscale                                    
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled                                       
COPY --from=tailscale /usr/local/bin/containerboot /usr/local/bin/containerboot                                 
                                                                                                             
ARG TARGETARCH=amd64                                                                                            
ARG OPENCLAW_VERSION=2026.2.9                                                                                   
ARG S6_OVERLAY_VERSION=3.2.1.0                                                                                  
ARG NODE_MAJOR=24                                                                                               
ARG RESTIC_VERSION=0.17.3                                                                                       
ARG NGROK_VERSION=3                                                                                             
ARG YQ_VERSION=4.44.3                                                                                           
ARG NVM_VERSION=0.40.4                                                                                          
ARG OPENCLAW_STATE_DIR=/data/.openclaw                                                                          
ARG OPENCLAW_WORKSPACE_DIR=/data/workspace                                                                      
                                                                                                             
ENV OPENCLAW_STATE_DIR=${OPENCLAW_STATE_DIR}                                                                    
ENV OPENCLAW_WORKSPACE_DIR=${OPENCLAW_WORKSPACE_DIR}                                                            
ENV NODE_ENV=production                                                                                         
ENV DEBIAN_FRONTEND=noninteractive                                                                              
ENV S6_KEEP_ENV=1                                                                                               
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2                                                                              
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0                                                                          
ENV S6_LOGGING=0                                                                                                
                                                                                                             
# -------------------------------------------------                                                             
# 3️⃣ Install OS packages + Chromium + other tools                                                               
# -------------------------------------------------                                                             
RUN set -eux; \                                                                                                 
apt-get update; \                                                                                             
apt-get install -y --no-install-recommends \                                                                  
 ca-certificates \                                                                                           
 wget \                                                                                                      
 unzip \                                                                                                     
 vim \                                                                                                       
 curl \                                                                                                      
 git \                                                                                                       
 gh \                                                                                                        
 gnupg \                                                                                                     
 ssh-import-id \                                                                                             
 openssl \                                                                                                   
 jq \                                                                                                        
 sudo \                                                                                                      
 bzip2 \                                                                                                     
 openssh-server \                                                                                            
 cron \                                                                                                      
 build-essential \                                                                                           
 procps \                                                                                                    
 xz-utils; \                                                                                                 
\                                                                                                             
# ----> NEW: Chromium & runtime dependencies <----                                                            
apt-get install -y --no-install-recommends \                                                                  
 chromium-browser \                                                                                          
 fonts-liberation \                                                                                          
 libasound2 \                                                                                                
 libatk-bridge2.0-0 \                                                                                        
 libatk1.0-0 \                                                                                               
 libc6 \                                                                                                     
 libdrm2 \                                                                                                   
 libgconf-2-4 \                                                                                              
 libgbm1 \                                                                                                   
 libgtk-3-0 \                                                                                                
 libnspr4 \                                                                                                  
 libnss3 \                                                                                                   
 libx11-6 \                                                                                                  
 libxcomposite1 \                                                                                            
 libxdamage1 \                                                                                               
 libxrandr2 \                                                                                                
 libxshmfence1 \                                                                                             
 xdg-utils; \                                                                                                
\                                                                                                             
# ----> Restic --------------------------------------------------                                             
RESTIC_ARCH="$( [ \"$TARGETARCH\" = \"arm64\" ] && echo arm64 || echo amd64 )"; \                             
wget -q -O /tmp/restic.bz2 \                                                                                  
                                                                                                             
https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_${RESTIC_ARC 
H}.bz2; \                                                                                                         
bunzip2 /tmp/restic.bz2; \                                                                                    
mv /tmp/restic /usr/local/bin/restic; \                                                                       
chmod +x /usr/local/bin/restic; \                                                                             
\                                                                                                             
# ----> Ngrok ---------------------------------------------------                                             
mkdir -p /etc/apt/keyrings; \                                                                                 
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \                                                    
 | gpg --dearmor -o /etc/apt/keyrings/ngrok.gpg; \                                                           
echo "deb [signed-by=/etc/apt/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main" \         
 > /etc/apt/sources.list.d/ngrok.list; \                                                                     
apt-get update && apt-get install -y ngrok; \                                                                 
\                                                                                                             
# ----> yq -------------------------------------------------------                                            
YQ_ARCH="$( [ \"$TARGETARCH\" = \"arm64\" ] && echo arm64 || echo amd64 )"; \                                 
wget -q -O /usr/local/bin/yq \                                                                                
 https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${YQ_ARCH}; \                     
chmod +x /usr/local/bin/yq; \                                                                                 
\                                                                                                             
# ----> s6‑overlay -----------------------------------------------                                            
S6_ARCH="$( [ \"$TARGETARCH\" = \"arm64\" ] && echo aarch64 || echo x86_64 )"; \                              
wget -O /tmp/s6-overlay-noarch.tar.xz \                                                                       
                                                                                                             
https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz;  
\                                                                                                                 
wget -O /tmp/s6-overlay-arch.tar.xz \                                                                         
                                                                                                             
https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar. 
xz; \                                                                                                             
tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \                                                               
tar -C / -Jxpf /tmp/s6-overlay-arch.tar.xz; \                                                                 
rm /tmp/s6-overlay-*.tar.xz; \                                                                                
\                                                                                                             
# ----> SSH setup ------------------------------------------------                                            
mkdir -p /run/sshd; \                                                                                         
\                                                                                                             
# ----> Cleanup ---------------------------------------------------                                           
apt-get clean; \                                                                                              
rm -rf /var/lib/                                                                                              
rm -rf /var/lib/apt/lists/*                                                                                   
                                                                                                             
# -------------------------------------------------                                                             
# 4️⃣ Overlay any files you ship in rootfs/ (unchanged)                                                          
# -------------------------------------------------                                                             
COPY rootfs/ /                                                                                                  
                                                                                                             
# -------------------------------------------------                                                             
# 5️⃣ Apply permissions from the overlay (unchanged)                                                             
# -------------------------------------------------                                                             
RUN source /etc/s6-overlay/lib/env-utils.sh && apply_permissions                                                
                                                                                                             
# -------------------------------------------------                                                             
# 6️⃣ Create the non‑root OpenClaw user (unchanged)                                                              
# -------------------------------------------------                                                             
RUN useradd -m -s /bin/bash openclaw \                                                                          
&& mkdir -p "${OPENCLAW_STATE_DIR}" "${OPENCLAW_WORKSPACE_DIR}" \                                             
&& ln -s ${OPENCLAW_STATE_DIR} /home/openclaw/.openclaw \                                                     
&& chown -R openclaw:openclaw /data \                                                                         
&& chown -R openclaw:openclaw /home/openclaw                                                                  
                                                                                                             
# Homebrew, nvm, node, pnpm, OpenClaw (unchanged)                                                               
RUN mkdir -p /home/openclaw/.local/share/pnpm && chown -R openclaw:openclaw /home/openclaw/.local               
                                                                                                             
USER openclaw                                                                                                   
                                                                                                             
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL                                                                 
https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true                                      
                                                                                                             
RUN export SHELL=/bin/bash && export NVM_DIR="$HOME/.nvm" \                                                     
&& curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \                          
&& . "$NVM_DIR/nvm.sh" \                                                                                      
&& nvm install --lts \                                                                                        
&& nvm use --lts \                                                                                            
&& nvm alias default lts/* \                                                                                  
&& npm install -g pnpm \                                                                                      
&& pnpm setup \                                                                                               
&& export PNPM_HOME="/home/openclaw/.local/share/pnpm" \                                                      
&& export PATH="$PNPM_HOME:$PATH" \                                                                           
&& pnpm add -g "openclaw@${OPENCLAW_VERSION}"                                                                 
                                                                                                             
USER root                                                                                                       
                                                                                                             
# Fix ownership for any stray ubuntu home (if present)                                                          
RUN if [ -d /home/ubuntu ]; then chown -R ubuntu:ubuntu /home/ubuntu; fi                                        
                                                                                                             
# Save package selections for restore capability                                                                
RUN dpkg --get-selections > /etc/openclaw/dpkg-selections                                                       
                                                                                                             
# -------------------------------------------------                                                             
# 7️⃣ s6‑overlay init (unchanged)                                                                                
# -------------------------------------------------                                                             
ENTRYPOINT ["/init"]                                                                                            

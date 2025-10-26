#!/bin/bash
set -euxo pipefail

# Install nginx (works for AL2023 or AL2)
if command -v dnf >/dev/null 2>&1; then
  dnf -y update
  dnf -y install nginx
else
  yum -y update
  yum -y install nginx
fi

# Get instance metadata (IMDSv2)
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
META="-H X-aws-ec2-metadata-token:${TOKEN}"
LOCAL_IP=$(curl -s ${META} http://169.254.169.254/latest/meta-data/local-ipv4 || hostname -I | awk '{print $1}')
HOSTNAME_FQDN=$(hostname -f)

# Prepare simple web page
cat >/usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html>
  <head><title>ASG Demo</title></head>
  <body style="font-family: sans-serif;">
    <h1>NGINX on port 8080</h1>
    <p><b>Hostname:</b> ${HOSTNAME_FQDN}</p>
    <p><b>IP:</b> ${LOCAL_IP}</p>
    <p>Healthcheck at <code>/health</code></p>
  </body>
</html>
EOF

# Minimal nginx server on 8080 with /health endpoint
cat >/etc/nginx/conf.d/asg.conf <<'EOF'
server {
    listen 8080 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location /health {
        add_header Content-Type text/plain;
        return 200 'OK';
    }
}
EOF

# Ensure default server doesn't conflict on 80
if [ -f /etc/nginx/nginx.conf ]; then
  sed -i 's/listen       80 default_server;/# listen 80 default_server;/' /etc/nginx/nginx.conf || true
  sed -i 's/listen       \[::\]:80 default_server;/# listen [::]:80 default_server;/' /etc/nginx/nginx.conf || true
fi

# Start & enable nginx
systemctl enable nginx
systemctl restart nginx


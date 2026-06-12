FROM nginx:1.27-alpine

# Static workflow slide deck. No build step; nginx serves the single HTML file.
COPY e2e-workflow-slides.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

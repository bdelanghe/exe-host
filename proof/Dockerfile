FROM busybox:1.36
COPY www/ /www/
RUN chmod +x /www/cgi-bin/now
EXPOSE 8080
CMD ["httpd", "-f", "-v", "-p", "8080", "-h", "/www"]

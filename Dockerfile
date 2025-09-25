FROM ghcr.io/imputnet/yt-session-generator:latest

COPY ./docker/scripts/startup-webserver.sh /app/startup-webserver.sh
RUN chmod +x /app/startup-webserver.sh

WORKDIR /app
# Optional: EXPOSE the port you intend to use internally
EXPOSE 8080 
CMD [ "./startup-webserver.sh" ]

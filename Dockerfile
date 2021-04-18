FROM avapolos/apache

RUN apk add postgresql-bdr-client

WORKDIR /app/public

VOLUME [ /app/moodledata ]

COPY . ./

RUN mv ./docker-entrypoint.sh / && chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

CMD [ "httpd", "-D",  "FOREGROUND" ]

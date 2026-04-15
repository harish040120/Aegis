FROM postgres:14-alpine
ENV POSTGRES_DB=aegis_intelligence
ENV POSTGRES_USER=aegis_admin
ENV POSTGRES_PASSWORD=aegis_secure_pass
COPY aegis_schema.sql /docker-entrypoint-initdb.d/01_schema.sql
EXPOSE 5432
CMD ["postgres"]

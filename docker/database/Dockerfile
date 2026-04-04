# PostgreSQL Database
FROM postgres:14-alpine

ENV POSTGRES_DB=aegis_intelligence
ENV POSTGRES_USER=aegis_admin
ENV POSTGRES_PASSWORD=aegis_secure_pass

COPY init_db.sql /docker-entrypoint-initdb.d/
COPY seed_workers.sql /docker-entrypoint-initdb.d/

EXPOSE 5432

CMD ["postgres"]
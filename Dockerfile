FROM neo4j:3.5.5

COPY ./docker-entrypoint.sh /
COPY ./files/*.jar /var/lib/neo4j/plugins/

RUN chmod 755 /docker-entrypoint.sh && \
    echo 'dbms.security.procedures.unrestricted=algo.*' >> /var/lib/neo4j/conf/neo4j.conf

ENV NEO4J_EDITION community

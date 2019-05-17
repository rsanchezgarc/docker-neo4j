FROM neo4j:3.5.5

COPY ./docker-entrypoint.sh /
COPY ./files/*.jar /var/lib/neo4j/plugins/

# Our cypher-runner.
# Expected by and employed by our 'load-neo4j' strategy.
# The user puts their cypher commands into the file
# /cypher-runner/cypher.script and the runner runs them (driven by the loader)
COPY cypher-runner.sh /cypher-runner/

RUN chmod 755 /cypher-runner/cypher-runner.sh && \
    chmod 755 /docker-entrypoint.sh && \
    echo 'dbms.security.procedures.unrestricted=algo.*,apoc.*' >> /var/lib/neo4j/conf/neo4j.conf

ENV NEO4J_EDITION community

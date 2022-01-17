# The InformaticsMatters neo4j container image
A specialised build of neo4j used by a number of InformaticsMatters projects.

>   **WARNING: DO NOT USE THIS BRANCH**
 
>   Our implementation is sensitive to the underlying neo4j image. Development
    therefore takes place on branches aligned with the corresponding neo4j
    version number. At the time of writing active branches are `3.5.25`,
    `4.2.1` and `4.4.2`.
    
## General considerations

These considerations should apply to any branch or deployment.

### Memory
Depending on the size of the graph database and the amount of memory on your machine you may want to configure
the memory utilisation with something like this in the `environment` section of the `docker-compose.yml` file:
```
    NEO4J_dbms_memory_pagecache_size: 20G
    NEO4J_dbms_memory_heap_initial__size: 8G
    NEO4J_dbms_memory_heap_max__size: 20G
```

### Monitoring
If you want to monitor memory usage add this in the `environment` section of the `docker-compose.yml` file:  
```
    NEO4J_dbms_jvm_additional: '-XX:NativeMemoryTracking=detail'
```
See here for more details: https://neo4j.com/developer/kb/understanding-memory-consumption/#_monitoring


---

spring.datasource.url=jdbc:postgresql://${db_endpoint}/petclinic
spring.datasource.username=petclinic
spring.datasource.password=petclinic
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect

# Web
spring.thymeleaf.mode=HTML

# JPA
spring.jpa.hibernate.ddl-auto=none
spring.jpa.open-in-view=true

# Internationalization
spring.messages.basename=messages/messages

# Actuator
management.endpoints.web.exposure.include=*

# Logging
logging.level.org.springframework=INFO

# Maximum time static resources should be cached
spring.web.resources.cache.cachecontrol.max-age=12h

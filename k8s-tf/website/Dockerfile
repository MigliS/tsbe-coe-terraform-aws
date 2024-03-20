# Use latest nginx image
FROM nginx:latest

# Remove default index.html file
RUN rm /usr/share/nginx/html/index.html

# Copy website contents to the container
COPY ./files/ /usr/share/nginx/html

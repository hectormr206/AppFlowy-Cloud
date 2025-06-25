    # Usar la imagen oficial de Nginx como base
    FROM nginx:latest

    # Eliminar la configuración por defecto de Nginx
    RUN rm /etc/nginx/conf.d/default.conf

    # Copiar nuestro archivo de configuración personalizado al lugar correcto dentro de la imagen
    COPY nginx/nginx.conf /etc/nginx/nginx.conf

    # Exponer el puerto 80 (el puerto estándar de Nginx)
    EXPOSE 80

    # El comando para iniciar Nginx en primer plano
    CMD ["nginx", "-g", "daemon off;"]
FROM python:3.11
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /usr/src/django-admin-example
COPY django-admin-example/ .
RUN pip install --no-cache-dir -r requirements.txt
RUN python manage.py collectstatic --noinput
EXPOSE 8080
USER 1000:1000
ENV GUNICORN_CMD_ARGS="--bind=0.0.0.0:8080 --access-logfile -"
CMD ["gunicorn", "django_admin_example.wsgi:application"]
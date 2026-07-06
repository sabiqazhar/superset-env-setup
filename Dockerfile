FROM apache/superset:6.0.0

USER root

COPY docker/requirements.txt /tmp/requirements.txt

RUN . /app/.venv/bin/activate && \
  uv pip install -r /tmp/requirements.txt

COPY docker/pythonpath/superset_config.py /app/pythonpath/

COPY docker/helsaBI.png /app/superset/static/assets/images/superset-logo-horiz.png

USER superset

CMD ["/app/docker/entrypoints/run-server.sh"]

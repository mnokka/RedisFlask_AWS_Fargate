
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .

RUN pip3 install --no-cache-dir -r requirements.txt

COPY flask_server.py /app/
COPY db.json /app/
COPY competitor.json /app/

ENV FLASK_APP=flask_server.py

ENV FLASK_ENV=development

EXPOSE 5000

CMD ["flask", "run", "--host=0.0.0.0"]

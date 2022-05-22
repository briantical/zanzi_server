FROM python:3.9

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# set work directory
WORKDIR /home

RUN pip install --no-cache-dir  pipenv==2022.4.21

# install dependencies
COPY Pipfile /home/
COPY Pipfile.lock /home/

ENV PIPENV_VENV_IN_PROJECT=1
RUN pipenv install --system

# copy project
COPY . /home/
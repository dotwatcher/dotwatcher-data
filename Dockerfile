FROM python:3.6-slim-stretch as csvbuilder

# This one uses csvs-to-sqlite to compile the DB, and then uses datasette

# inspect to generate inspect-data.json Compiling pandas takes way too long

# under alpine so we use slim-stretch for this one instead.

RUN apt-get update && apt-get install -y python3-dev gcc

COPY *.csv csvs/

RUN pip install csvs-to-sqlite datasette

RUN csvs-to-sqlite csvs/results.csv data.db -f "Event" -f "Rider"

ADD metadata.json metadata.json

RUN datasette inspect data.db --inspect-file inspect-data.json

FROM python:3.6-alpine as buildit

# This one installs and compiles Datasette + its dependencies

RUN apk add --no-cache gcc python3-dev musl-dev alpine-sdk

RUN pip install uvloop

RUN pip install datasette

# Can clean up a lot of space by deleting rogue .c files etc:

RUN find /usr/local/lib/python3.6 -name '*.c' -delete

RUN find /usr/local/lib/python3.6 -name '*.pxd' -delete

RUN find /usr/local/lib/python3.6 -name '*.pyd' -delete

# Cleaning up __pycache__ gains more space

RUN find /usr/local/lib/python3.6 -name '__pycache__' | xargs rm -r

FROM python:3.6-alpine

# This one builds the final container, copying from the previous steps

COPY --from=buildit /usr/local/lib/python3.6 /usr/local/lib/python3.6

COPY --from=buildit /usr/local/bin/datasette /usr/local/bin/datasette

COPY --from=csvbuilder inspect-data.json inspect-data.json

COPY --from=csvbuilder data.db data.db

EXPOSE 8001

CMD ["datasette", "serve", "data.db", "--host", "0.0.0.0", "--cors", "--inspect-file", "inspect-data.json"]

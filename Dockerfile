FROM node:6.10
RUN mkdir /code
WORKDIR /code
ADD package.json /code/
RUN npm install
ADD . /code/
ENV PORT 80
EXPOSE 80

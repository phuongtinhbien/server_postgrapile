# server_postgrapile

run install lib
:- npm install
run start server
:- npm start

export schema:
:- apollo-codegen download-schema https://api.github.com/graphql --output schema.json

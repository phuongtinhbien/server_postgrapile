const { postgraphile} = require("postgraphile");
const { createServer } = require("http");
const express = require("express");
const app = express();
const rawHTTPServer = createServer(app);

const databaseUrl = "postgres://postgres:admin@127.0.0.1/laundry_schema"
const postgraphileOptions = {
  simpleSubscriptions: true,
  graphiql: true,
  websocketMiddlewares: 
  [
    // Add whatever middlewares you need here, note that
    // they should only manipulate properties on req/res,
    // they must not sent response data. e.g.:
    //
    //   require('express-session')(),
    //   require('passport').initialize(),
    //   require('passport').session(),
  ]
};

const postgraphileMiddleware = postgraphile(
  databaseUrl,
  "public",
  postgraphileOptions
);

app.use(postgraphileMiddleware);

rawHTTPServer.listen(parseInt(process.env.PORT, 10) || 3000);
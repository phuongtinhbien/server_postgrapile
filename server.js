require('dotenv').config();
const { postgraphile} = require("postgraphile");
const { createServer } = require("http");
const express = require("express");
const bodyParser = require('body-parser');
const PostGraphileConnectionFilterPlugin = require("postgraphile-plugin-connection-filter");
const app = express();
const rawHTTPServer = createServer(app);

// const databaseUrl = "postgres://postgres:admin@127.0.0.1/luandry_schema_21092018";
// const postgraphileOptions = {
//   simpleSubscriptions: true,
//   graphiql: true,
//   watchPg: true,
//   jwtPgTypeIdentifier: `${process.env.POSTGRAPHILE_SCHEMA}.jwt`,
//   jwtSecret: process.env.JWT_SECRET,
//   pgDefaultRole: process.env.POSTGRAPHILE_DEFAULT_ROLE,
//   appendPlugins: [PostGraphileConnectionFilterPlugin],
  
// };

const postgresConfig = {
  user: process.env.POSTGRES_USERNAME,
  password: process.env.POSTGRES_PASSWORD,
  host: process.env.POSTGRES_HOST,
  port: process.env.POSTGRES_PORT,
  database: process.env.POSTGRES_DATABASE
}
// const postgraphileMiddleware = postgraphile(
//   databaseUrl,
//   "public",
//   postgraphileOptions,
// );

app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  next();
});
app.use(bodyParser.json());

app.use(
  bodyParser.urlencoded({
    extended: true
   })
);

app.use(postgraphile(
  postgresConfig,
  ['auth_public','public'], {
    graphiql: true,
    watchPg: true,
    // schemaName:['auth_public','public'],
    jwtPgTypeIdentifier: `${process.env.POSTGRAPHILE_SCHEMA}.jwt`,
    jwtSecret: process.env.JWT_SECRET,
    pgDefaultRole: process.env.POSTGRAPHILE_DEFAULT_ROLE
  }))

// app.use(postgraphileMiddleware);

app.use(function (req, res, next) {
  var err = new Error('Not Found');
  err.status = 404;
  next(err);
});

app.use(function (err, req, res, next) {
  res.send('Error! ', err.message, ' ', (req.app.get('env') === 'development' ? err : {}));
});
app.listen(5000,(err)=>{
    if (err)
      console.log(err);
    else
      console.log("successfully!!!");
});
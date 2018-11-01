require('dotenv').config();
const { createServer } = require("http");
const express = require("express");
const bodyParser = require('body-parser');
const app = express();
const fs = require("fs");
const path = require("path");
const { postgraphile} = require("postgraphile");
const PostGraphileUploadFieldPlugin = require("postgraphile-plugin-upload-field");
const PostGraphileConnectionFilterPlugin = require("postgraphile-plugin-connection-filter");
const { graphqlUploadExpress } = require("graphql-upload");


const postgresConfig = {
  user: process.env.POSTGRES_USERNAME,
  password: process.env.POSTGRES_PASSWORD,
  host: process.env.POSTGRES_HOST,
  port: process.env.POSTGRES_PORT,
  database: process.env.POSTGRES_DATABASE
}
const UPLOAD_DIR_NAME = "uploads";

// Serve uploads as static resources
app.use(`/${UPLOAD_DIR_NAME}`, express.static(path.resolve(UPLOAD_DIR_NAME)));

// Attach multipart request handling middleware
app.use(graphqlUploadExpress());

app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization");
  res.header("Authorization" , "Bearer <token>");
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
    enableCors: true,
    appendPlugins: [PostGraphileConnectionFilterPlugin],
    graphileBuildOptions: {
      uploadFieldDefinitions: [
        {
          match: ({ schema, table, column, tags }) =>
            column === "header_image_file",
          resolve: resolveUpload
        }
      ]
    },
    jwtPgTypeIdentifier: `${process.env.POSTGRAPHILE_SCHEMA}.jwt`,
    jwtSecret: process.env.JWT_SECRET,
    jwtVerifyOptions:{
      maxAge:999999999999999999999999
    },
    pgDefaultRole: process.env.POSTGRAPHILE_DEFAULT_ROLE,

  }));

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

async function resolveUpload(upload) {
  const { filename, mimetype, encoding, createReadStream } = upload;
  const stream = createReadStream();
  // Save file to the local filesystem
  const { id, filepath } = await saveLocal({ stream, filename });
  // Return metadata to save it to Postgres
  return filepath;
}

function saveLocal({ stream, filename }) {
  const timestamp = new Date().toISOString().replace(/\D/g, "");
  const id = `${timestamp}_${filename}`;
  const filepath = path.join(UPLOAD_DIR_NAME, id);
  const fsPath = path.join(process.cwd(), filepath);
  return new Promise((resolve, reject) =>
    stream
      .on("error", error => {
        if (stream.truncated)
          // Delete the truncated file
          fs.unlinkSync(fsPath);
        reject(error);
      })
      .on("end", () => resolve({ id, filepath }))
      .pipe(fs.createWriteStream(fsPath))
  );
}
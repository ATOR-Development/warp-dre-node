const Koa = require('koa');
const cors = require('@koa/cors');
const bodyParser = require('koa-bodyparser');
const compress = require('koa-compress');
const zlib = require('zlib');
const router = require('./router');
const { logConfig, config } = require('./config');
const { createNodeDbTables, connect } = require('./db/nodeDb');

const logger = require('./logger')('listener');
const exitHook = require('async-exit-hook');
const { pgClient, warp } = require('./warp');
const { Queue } = require('bullmq');
let port = 8080;

let nodeDb;

async function runListener() {
  logger.info('🚀🚀🚀 Starting listener node');
  await logConfig();

  nodeDb = connect();
  await pgClient.open();

  await createNodeDbTables(nodeDb);

  const app = new Koa();
  app
    .use(corsConfig())
    .use(compress(compressionSettings))
    .use(bodyParser())
    .use(router.routes())
    .use(router.allowedMethods())
    .use(async (ctx, next) => {
      await next();
      ctx.redirect('/status');
    });
  app.context.nodeDb = nodeDb;
  app.context.registerQueue = new Queue('register', {
    connection: config.bullMqConnection,
    defaultJobOptions: {
      removeOnComplete: {
        age: 3600
      },
      removeOnFail: true
    }
  });
  app.listen(port);
}

runListener().catch((e) => {
  logger.error(e);
});

const compressionSettings = {
  threshold: 2048,
  deflate: false,
  br: {
    params: {
      [zlib.constants.BROTLI_PARAM_QUALITY]: 4
    }
  }
};

function corsConfig() {
  return cors({
    async origin() {
      return '*';
    }
  });
}

// Graceful shutdown
async function cleanup(callback) {
  logger.info('Interrupted');
  await warp.close();
  await nodeDb.end();
  logger.info('Clean up finished');
  callback();
}

exitHook(cleanup);

const { NlpExtension } = require("warp-contracts-plugin-nlp");
const { EthersExtension } = require("warp-contracts-plugin-ethers");
const { VM2Plugin } = require("warp-contracts-plugin-vm2");
const { VRFPlugin } = require("warp-contracts-plugin-vrf");
const { LmdbCache } = require("warp-contracts-lmdb");
const { SqliteContractCache } = require("warp-contracts-sqlite");
const { defaultCacheOptions, LoggerFactory, WarpFactory } = require("warp-contracts");
const stringify = require("safe-stable-stringify");
const fs = require("fs");
const { EvmSignatureVerificationServerPlugin } = require('warp-contracts-plugin-signature/server');
const { JWTVerifyPlugin } = require("@othent/warp-contracts-plugin-jwt-verify");

(async function() {


// N2eWCCU5ng8AgYcKIbqCT7xn3eLJWlZvnUoqwK7tyZU
// 000001207142,0000000000000,a53b31607b8bfb30223a53799e7e71ade1518780b335a0d59bf6bf667fd15e2a
  LoggerFactory.INST.logLevel("debug");
  LoggerFactory.INST.logLevel("debug", 'WarpGatewayInteractionsLoader');
  const contractTxId = "KTzTXT_ANmF84fWEKHzWURD1LWd9QaFR9yfYUwH2Lxw";

  const warp = WarpFactory.forMainnet()
    .useStateCache(
      new SqliteContractCache(
        {
          ...defaultCacheOptions,
          dbLocation: `./cache/warp/sqlite/state`
        },
        {
          maxEntriesPerContract: 1000
        }
      )
    )
    .useContractCache(
      new LmdbCache(
        {
          ...defaultCacheOptions,
          dbLocation: `./cache/warp/lmdb/contract`
        },
        {
          minEntriesPerContract: 1,
          maxEntriesPerContract: 5
        }
      ),
      new LmdbCache(
        {
          ...defaultCacheOptions,
          dbLocation: `./cache/warp/lmdb/source`
        },
        {
          minEntriesPerContract: 1,
          maxEntriesPerContract: 5
        }
      )
    )
    .useKVStorageFactory(
      (contractTxId) =>
        new LmdbCache(
          {
            ...defaultCacheOptions,
            dbLocation: `./cache/warp/kv/lmdb/${contractTxId}`
          },
          {
            minEntriesPerContract: 3,
            maxEntriesPerContract: 10
          }
        )
    )
    .use(new NlpExtension())
    .use(new EvmSignatureVerificationServerPlugin())
    .use(new EthersExtension())
    .use(new VM2Plugin())
    .use(new VRFPlugin())
    .use(new JWTVerifyPlugin());
// .use(new JWTVerifyPlugin());


  const contract = warp.contract(contractTxId)
    .setEvaluationOptions({
      allowBigInt: true,
      internalWrites: true,
      maxCallDepth: 666,
      maxInteractionEvaluationTimeSeconds: 20000,
      unsafeClient: "skip",
      cacheEveryNInteractions: 2000
    });

  // 7fab3f8322b90215d2b58954e5959cf44bdbcaa0b4fd8faee669139da0f0a805
  // 7fab3f8322b90215d2b58954e5959cf44bdbcaa0b4fd8faee669139da0f0a805
  const evalResult = await contract.readState("000001224477,0000000000000,fd7720284ef5d4bacc63c1da050033f631c61bbb30486891191db6678615e7d8");
  // const evalResult = await contract.readState("000001207142,0000000000000,a53b31607b8bfb30223a53799e7e71ade1518780b335a0d59bf6bf667fd15e2a");
  const evalState = evalResult.cachedValue.state;
  const sortKey = evalResult.sortKey;

  console.log(`SortKey: ${sortKey}`);

  fs.writeFileSync(`u_${Date.now()}.json`, JSON.stringify(evalResult, null ,2));

  // console.dir(evalResult, { depth: null });
  // console.dir(contract.getCallStack(), { depth: null });




})();
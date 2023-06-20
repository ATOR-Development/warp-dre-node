const Router = require('@koa/router');
const contract = require('./routes/contract');
const status = require('./routes/status');
const contractViewState = require('./routes/contractViewState');
const blacklisted = require('./routes/blacklisted');
const cached = require('./routes/cached');
const errors = require('./routes/errors');
const scheduleSync = require('./routes/scheduleSync');
const kv = require('./routes/kv');
const eraseContract = require('./routes/eraseContract');
const validity = require('./routes/validity');

const router = new Router();

router.get('/contract', contract);
router.get('/contract/view-state', contractViewState);
router.get('/status', status);
router.get('/blacklist', blacklisted);
router.get('/cached', cached);
router.get('/errors', errors);
router.get('/sync', scheduleSync);
router.get('/kv', kv);
router.get('/validity', validity);
router.delete('/contract/:id', eraseContract);

module.exports = router;

require("dotenv").config()

// const { Client } = require('mysql');
const mysql2 = require('mysql2/promise');
const dbClient = mysql2.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    database: process.env.DB_DATABASE,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
})

// const dbClient = new Client({
//     user: process.env.DB_USER,
//     host: process.env.DB_HOST,
//     database: process.env.DB_DATABASE,
//     password: process.env.DB_PASSWORD,
//     port: process.env.DB_PORT,
// });

// dbClient.connect();

const getRunCount = async(id) => {
    const query = `SELECT RunCount FROM cointransaction WHERE Id = ${id} LIMIT 1`;
    const res = await dbClient
        .query(query);
    const rows = res.rows;
    if (res[0].length > 0) return res[0][0].RunCount;
    return 100;
}

const getFastestTx = async() => {
    const query = `SELECT * FROM cointransaction WHERE Type = 7 ORDER BY Id LIMIT 1`;
    const res = await dbClient
        .query(query);
    if (res[0].length > 0) return res[0][0];
    return null;
}

const getFastestFailedTx = async() => {
    const update_at = new Date().getTime() - 60 * process.env.RE_RUN_TIME_RANGE * 1000;
    const query = `SELECT * FROM cointransaction WHERE Type = 8 and RunCount < ${process.env.MAX_RUN_COUNT} and CreationDate < ${update_at} ORDER BY Id LIMIT 1`;
    const res = await dbClient
        .query(query);
    if (res[0].length > 0) return res[0][0];
    return null;
}

const getFastestPrevTxWithWalletAddress = async(id, walletAddress) => {
    const query = `SELECT * FROM cointransaction WHERE (Type = 8 or Type = 7) and RunCount < ${process.env.MAX_RUN_COUNT} and Id < ${id} and WalletAddress = '${walletAddress}' ORDER BY Id LIMIT 1`;
    const res = await dbClient
        .query(query);
    if (res[0].length > 0) return res[0][0];
    return null;
}

const runWithdraw = async(id, runCount = null) => {
    const update_at = new Date().getTime();
    console.log('===id', id)
    const run_count = runCount == null ? await getRunCount(id) : runCount;
    const query = `UPDATE cointransaction` +
        ` SET Type = 8 , RunCount = ${run_count + 1}, CreationDate = ${update_at}` +
        ` WHERE Id = ${id}`;
    if (await runQuery(query)) {
        console.log('runWithdraw: ', id)
    }
    return true;
}

const runQuery = async(query) => {
    let is_success = false;
    await dbClient
        .query(query)
        .then(res => {
            // console.log('query success');
            is_success = true;
        })
        .catch(err => {
            console.error(err);
        })
        .finally((res) => {
            // console.log('====: ', res);
            // dbClient.end();
        });
    return is_success;
}

module.exports = {
    getRunCount,
    getFastestTx,
    getFastestFailedTx,
    runWithdraw,
    runQuery,
    getFastestPrevTxWithWalletAddress
}
const express = require("express");
const cors = require("cors");
const app = express();

const { ethers } = require("hardhat");
require("dotenv").config()

const { admins } = require("./config");

const RPC_URL = process.env.RPC_URL;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const { createAlchemyWeb3 } = require("@alch/alchemy-web3");
const web3 = createAlchemyWeb3(RPC_URL);
const abi = require("./abi/metachessGame.json");
const contract = new web3.eth.Contract(abi, CONTRACT_ADDRESS);
const BN = ethers.BigNumber;
const Decimals = BN.from(18);
const OneToken = BN.from(10).pow(Decimals);

const {
    getRunCount,
    getFastestTx,
    getFastestFailedTx,
    runWithdraw,
    getFastestPrevTxWithWalletAddress,
    runQuery
} = require('./db');


let admin_nonce = {
    admin_0_nonce: 0,
    admin_1_nonce: 0
}

async function processTransaction(data, adminIndex) {
    try {
        const admin = admins[adminIndex];
        let nonce = await web3.eth.getTransactionCount(admin.publicKey, "latest") //get latest nonce
        const key = 'admin_' + adminIndex + '_nonce';
        let db_nonce = admin_nonce[key];
        nonce = nonce > db_nonce ? nonce : db_nonce;
        const tx = {
            from: admin.publicKey,
            to: CONTRACT_ADDRESS,
            nonce: nonce,
            gas: 10000000,
            data: data,
        }
        const signedTx = await web3.eth.accounts.signTransaction(tx, admin.privateKey)
        web3.eth.sendSignedTransaction(
            signedTx.rawTransaction,
            function(err, hash) {
                if (!err) {
                    console.log("=== BSC Transaction Hash ==== : ", hash);
                } else {
                    console.log("Something went wrong when submitting your transaction 1:", err.toString());
                }
            }
        );
        admin_nonce[key] = Number(nonce) + 1;
        console.log(key, nonce)
    } catch (err) {
        console.log("Something went wrong when submitting your transaction 2:", err.toString());
        return err.toString();
    }
    return ''
}

const withdraw = async(data, adminIndex) => {
    const _data = data;
    console.log(data)
    try {
        // const userInfo = await contract.methods.users(_data.WalletAddress).call();
        // if (userInfo.lastWithdrawId < data.Id) {
        const withdrawFunction = await contract.methods.withdrawToUser(_data.Id, _data.WalletAddress, OneToken.mul(_data.Amount)).encodeABI();
        await processTransaction(withdrawFunction, adminIndex);
        // }
    } catch (err) {
        console.log("mintWCSPR:", err.toString());
        return err.toString();
    }
}

const runWithdrawTx = async() => {
    try {
        const data = await getFastestTx();
        if (data == null) return;
        const prevTx = await getFastestPrevTxWithWalletAddress(data.Id, data.WalletAddress);
        if (prevTx !== null) return;
        const inputData = {
            Id: data.Id,
            WalletAddress: data.WalletAddress,
            Amount: data.Amount * (-1)
        }
        await runWithdraw(data.Id);
        await withdraw(inputData, 0);
    } catch (err) {
        console.log('runWithdrawTx Error');
    }
}

const runFailedTx = async() => {
    try {
        const data = await getFastestFailedTx();
        if (data == null) return;
        const inputData = {
            Id: data.Id,
            WalletAddress: data.WalletAddress,
            Amount: data.Amount * (-1)
        }
        console.log("====failedTx Again Start=====")
        await runWithdraw(data.Id, data.RunCount);
        await withdraw(inputData, 0);
        console.log("====failedTx Again End=====")
    } catch (err) {
        console.log('runBSCMint Error');
    }
}

const BscMintInterval = setInterval(runWithdrawTx, Number(process.env.BSC_MINT_TIME) * 1000);
const BscMintFailedTxInterval = setInterval(runFailedTx, Number(process.env.BSC_MINT_FAILED_TX_TIME) * 1000);
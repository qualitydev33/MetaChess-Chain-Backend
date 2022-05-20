async function main() {
  // We get the contract to deploy
  const MetaChess = await ethers.getContractFactory("MetaChess");
  const metaChess = await MetaChess.deploy();

  console.log("metaChess deployed to:", metaChess.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

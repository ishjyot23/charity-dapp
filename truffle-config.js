module.exports = {
networks: {
// Ganache GUI (default — use this for development)
development: {
host: '127.0.0.1',
port: 7545, // Ganache GUI default
network_id: '*',
},
// Ganache CLI (if using npx ganache instead)
ganache_cli: {
host: '127.0.0.1',
port: 8545,
network_id: '*',
},
},
compilers: {
solc: {
version: '0.8.19',
settings: { optimizer: { enabled: true, runs: 200 } },
},
},
};
